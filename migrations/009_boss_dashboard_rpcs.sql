-- ═══════════════════════════════════════════════════════════════
-- 老板看板数据聚合 RPC(高性能,一次查询一张卡片)
-- ═══════════════════════════════════════════════════════════════

-- 核心指标:收入/支出/退款/分红/净利润/订单数
CREATE OR REPLACE FUNCTION public.get_boss_summary(p_from timestamptz, p_to timestamptz)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'income_total', (
      SELECT COALESCE(SUM(amount), 0)::numeric
      FROM orders
      WHERE deleted_at IS NULL AND status IN ('completed','partially_refunded')
        AND COALESCE(paid_at, created_at) >= p_from
        AND COALESCE(paid_at, created_at) <= p_to
    ),
    'orders_count', (
      SELECT COUNT(*)::int FROM orders
      WHERE deleted_at IS NULL AND status IN ('completed','partially_refunded')
        AND COALESCE(paid_at, created_at) >= p_from
        AND COALESCE(paid_at, created_at) <= p_to
    ),
    'expense_total', (
      SELECT COALESCE(SUM(amount), 0)::numeric
      FROM expenses
      WHERE deleted_at IS NULL AND status = 'paid'
        AND COALESCE(paid_at, created_at) >= p_from
        AND COALESCE(paid_at, created_at) <= p_to
    ),
    'refund_total', (
      SELECT COALESCE(SUM(refund_amount), 0)::numeric
      FROM refunds
      WHERE deleted_at IS NULL AND status = 'completed'
        AND COALESCE(paid_at, created_at) >= p_from
        AND COALESCE(paid_at, created_at) <= p_to
    ),
    'dividend_total', (
      SELECT COALESCE(SUM(amount), 0)::numeric
      FROM dividends
      WHERE deleted_at IS NULL AND COALESCE(status,'paid') = 'paid'
        AND pay_date >= p_from::date AND pay_date <= p_to::date
    )
  );
$$;
GRANT EXECUTE ON FUNCTION public.get_boss_summary(timestamptz, timestamptz) TO authenticated;

-- 近 30 天每日收支
CREATE OR REPLACE FUNCTION public.get_cash_flow_daily(p_days int DEFAULT 30)
RETURNS TABLE(flow_date date, income numeric, expense numeric, net numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH dates AS (
    SELECT generate_series(
      (CURRENT_DATE - (p_days - 1))::date,
      CURRENT_DATE,
      '1 day'::interval
    )::date AS d
  ),
  daily_income AS (
    SELECT COALESCE(paid_at, created_at)::date AS d, SUM(amount) AS total
    FROM orders
    WHERE deleted_at IS NULL AND status IN ('completed','partially_refunded')
      AND COALESCE(paid_at, created_at) >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  ),
  daily_expense AS (
    SELECT COALESCE(paid_at, created_at)::date AS d, SUM(amount) AS total
    FROM expenses
    WHERE deleted_at IS NULL AND status = 'paid'
      AND COALESCE(paid_at, created_at) >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  )
  SELECT
    dates.d,
    COALESCE(di.total, 0)::numeric AS income,
    COALESCE(de.total, 0)::numeric AS expense,
    (COALESCE(di.total, 0) - COALESCE(de.total, 0))::numeric AS net
  FROM dates
  LEFT JOIN daily_income di ON di.d = dates.d
  LEFT JOIN daily_expense de ON de.d = dates.d
  ORDER BY dates.d;
$$;
GRANT EXECUTE ON FUNCTION public.get_cash_flow_daily(int) TO authenticated;

-- 店铺销售 Top 5
CREATE OR REPLACE FUNCTION public.get_top_stores(p_from timestamptz, p_to timestamptz, p_limit int DEFAULT 5)
RETURNS TABLE(account_id uuid, short_name text, platform text, sales numeric, orders_count int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    a.id,
    a.short_name,
    a.ecommerce_platform,
    COALESCE(SUM(o.amount), 0)::numeric AS sales,
    COUNT(o.id)::int AS orders_count
  FROM accounts a
  JOIN orders o ON o.account_id = a.id
    AND o.deleted_at IS NULL
    AND o.status IN ('completed','partially_refunded')
    AND COALESCE(o.paid_at, o.created_at) >= p_from
    AND COALESCE(o.paid_at, o.created_at) <= p_to
  WHERE a.category = 'ecommerce' AND a.status <> 'deleted'
  GROUP BY a.id, a.short_name, a.ecommerce_platform
  ORDER BY sales DESC
  LIMIT p_limit;
$$;
GRANT EXECUTE ON FUNCTION public.get_top_stores(timestamptz, timestamptz, int) TO authenticated;

-- 近期大额动态(收入 + 支出混合,按时间倒序)
CREATE OR REPLACE FUNCTION public.get_recent_big_events(p_threshold numeric DEFAULT 1000, p_limit int DEFAULT 10)
RETURNS TABLE(kind text, event_at timestamptz, amount numeric, label text, account_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  (
    SELECT 'income'::text AS kind,
           COALESCE(o.paid_at, o.created_at) AS event_at,
           o.amount::numeric,
           COALESCE(o.customer_name, o.order_no, '订单') AS label,
           COALESCE(a.short_name, '') AS account_name
    FROM orders o
    LEFT JOIN accounts a ON a.id = o.account_id
    WHERE o.deleted_at IS NULL
      AND o.status IN ('completed','partially_refunded')
      AND o.amount >= p_threshold
    ORDER BY event_at DESC
    LIMIT p_limit
  )
  UNION ALL
  (
    SELECT 'expense'::text AS kind,
           COALESCE(e.paid_at, e.created_at) AS event_at,
           (-e.amount)::numeric,
           COALESCE(e.payee, e.category, '支出') AS label,
           COALESCE(a.short_name, '') AS account_name
    FROM expenses e
    LEFT JOIN accounts a ON a.id = e.account_id
    WHERE e.deleted_at IS NULL AND e.status = 'paid'
      AND e.amount >= p_threshold
    ORDER BY event_at DESC
    LIMIT p_limit
  )
  ORDER BY event_at DESC
  LIMIT p_limit;
$$;
GRANT EXECUTE ON FUNCTION public.get_recent_big_events(numeric, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
