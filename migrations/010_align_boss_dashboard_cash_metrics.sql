-- ═══════════════════════════════════════════════════════════════
-- 对齐老板看板 RPC 与前端统一现金口径
-- 目标：
-- 1) get_boss_summary 与 financialMetrics.computeOverviewProfit 一致
-- 2) get_cash_flow_daily 把电商提现 / 其他收入 / 工资 / 转账手续费纳入现金流
-- 3) get_top_stores 统一使用订单实收(payment_amount 优先)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_boss_summary(p_from timestamptz, p_to timestamptz)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH private_orders AS (
    SELECT
      COALESCE(SUM(COALESCE(payment_amount, amount)), 0)::numeric AS private_income,
      COUNT(*)::int AS orders_count
    FROM orders
    WHERE deleted_at IS NULL
      AND status IN ('completed', 'partially_refunded')
      AND platform_type IS NULL
      AND created_at >= p_from
      AND created_at <= p_to
  ),
  paid_expenses AS (
    SELECT COALESCE(SUM(amount), 0)::numeric AS expense_sum
    FROM expenses
    WHERE deleted_at IS NULL
      AND status = 'paid'
      AND created_at >= p_from
      AND created_at <= p_to
  ),
  withdrawals_sum AS (
    SELECT COALESCE(SUM(actual_arrival), 0)::numeric AS ecommerce_income
    FROM withdrawals
    WHERE deleted_at IS NULL
      AND created_at >= p_from
      AND created_at <= p_to
  ),
  other_income_sum AS (
    SELECT COALESCE(SUM(amount), 0)::numeric AS other_income
    FROM other_income
    WHERE deleted_at IS NULL
      AND created_at >= p_from
      AND created_at <= p_to
  ),
  salary_cash AS (
    SELECT COALESCE(SUM(actual_amount), 0)::numeric AS salary_expense
    FROM salaries
    WHERE deleted_at IS NULL
      AND pay_date IS NOT NULL
      AND pay_date >= p_from::date
      AND pay_date <= p_to::date
  ),
  transfer_fee_sum AS (
    SELECT COALESCE(SUM(fee), 0)::numeric AS transfer_fees
    FROM account_transfers
    WHERE deleted_at IS NULL
      AND fee > 0
      AND transfer_date >= p_from
      AND transfer_date <= p_to
  ),
  refunds_sum AS (
    SELECT COALESCE(SUM(refund_amount), 0)::numeric AS refund_total
    FROM refunds
    WHERE deleted_at IS NULL
      AND status = 'completed'
      AND COALESCE(paid_at, created_at) >= p_from
      AND COALESCE(paid_at, created_at) <= p_to
  ),
  dividend_sum AS (
    SELECT COALESCE(SUM(amount), 0)::numeric AS dividend_total
    FROM dividends
    WHERE deleted_at IS NULL
      AND COALESCE(status, 'paid') = 'paid'
      AND pay_date >= p_from::date
      AND pay_date <= p_to::date
  )
  SELECT jsonb_build_object(
    'income_total', private_orders.private_income + withdrawals_sum.ecommerce_income + other_income_sum.other_income,
    'private_income', private_orders.private_income,
    'ecommerce_income', withdrawals_sum.ecommerce_income,
    'other_income', other_income_sum.other_income,
    'orders_count', private_orders.orders_count,
    'expense_total', paid_expenses.expense_sum + salary_cash.salary_expense + transfer_fee_sum.transfer_fees,
    'expense_sum', paid_expenses.expense_sum,
    'salary_expense', salary_cash.salary_expense,
    'transfer_fees', transfer_fee_sum.transfer_fees,
    'refund_total', refunds_sum.refund_total,
    'dividend_total', dividend_sum.dividend_total
  )
  FROM private_orders, paid_expenses, withdrawals_sum, other_income_sum, salary_cash, transfer_fee_sum, refunds_sum, dividend_sum;
$$;

GRANT EXECUTE ON FUNCTION public.get_boss_summary(timestamptz, timestamptz) TO authenticated;

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
  private_income AS (
    SELECT
      created_at::date AS d,
      SUM(COALESCE(payment_amount, amount))::numeric AS total
    FROM orders
    WHERE deleted_at IS NULL
      AND status IN ('completed', 'partially_refunded')
      AND platform_type IS NULL
      AND created_at >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  ),
  ecommerce_income AS (
    SELECT
      created_at::date AS d,
      SUM(actual_arrival)::numeric AS total
    FROM withdrawals
    WHERE deleted_at IS NULL
      AND created_at >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  ),
  other_income_daily AS (
    SELECT
      created_at::date AS d,
      SUM(amount)::numeric AS total
    FROM other_income
    WHERE deleted_at IS NULL
      AND created_at >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  ),
  paid_expenses AS (
    SELECT
      created_at::date AS d,
      SUM(amount)::numeric AS total
    FROM expenses
    WHERE deleted_at IS NULL
      AND status = 'paid'
      AND created_at >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  ),
  salary_cash AS (
    SELECT
      pay_date::date AS d,
      SUM(actual_amount)::numeric AS total
    FROM salaries
    WHERE deleted_at IS NULL
      AND pay_date IS NOT NULL
      AND pay_date >= (CURRENT_DATE - (p_days - 1))::date
    GROUP BY 1
  ),
  transfer_fees AS (
    SELECT
      transfer_date::date AS d,
      SUM(fee)::numeric AS total
    FROM account_transfers
    WHERE deleted_at IS NULL
      AND fee > 0
      AND transfer_date >= (CURRENT_DATE - (p_days - 1))::timestamptz
    GROUP BY 1
  )
  SELECT
    dates.d AS flow_date,
    (
      COALESCE(pi.total, 0) +
      COALESCE(ei.total, 0) +
      COALESCE(oi.total, 0)
    )::numeric AS income,
    (
      COALESCE(pe.total, 0) +
      COALESCE(sc.total, 0) +
      COALESCE(tf.total, 0)
    )::numeric AS expense,
    (
      COALESCE(pi.total, 0) +
      COALESCE(ei.total, 0) +
      COALESCE(oi.total, 0) -
      COALESCE(pe.total, 0) -
      COALESCE(sc.total, 0) -
      COALESCE(tf.total, 0)
    )::numeric AS net
  FROM dates
  LEFT JOIN private_income pi ON pi.d = dates.d
  LEFT JOIN ecommerce_income ei ON ei.d = dates.d
  LEFT JOIN other_income_daily oi ON oi.d = dates.d
  LEFT JOIN paid_expenses pe ON pe.d = dates.d
  LEFT JOIN salary_cash sc ON sc.d = dates.d
  LEFT JOIN transfer_fees tf ON tf.d = dates.d
  ORDER BY dates.d;
$$;

GRANT EXECUTE ON FUNCTION public.get_cash_flow_daily(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_top_stores(p_from timestamptz, p_to timestamptz, p_limit int DEFAULT 5)
RETURNS TABLE(account_id uuid, short_name text, platform text, sales numeric, orders_count int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    a.id,
    a.short_name,
    a.ecommerce_platform,
    COALESCE(SUM(COALESCE(o.payment_amount, o.amount)), 0)::numeric AS sales,
    COUNT(o.id)::int AS orders_count
  FROM accounts a
  JOIN orders o ON o.account_id = a.id
    AND o.deleted_at IS NULL
    AND o.status IN ('completed', 'partially_refunded')
    AND COALESCE(o.paid_at, o.created_at) >= p_from
    AND COALESCE(o.paid_at, o.created_at) <= p_to
  WHERE a.category = 'ecommerce'
    AND a.status <> 'deleted'
  GROUP BY a.id, a.short_name, a.ecommerce_platform
  ORDER BY sales DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_top_stores(timestamptz, timestamptz, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
