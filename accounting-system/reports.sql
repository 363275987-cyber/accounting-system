-- ================================================================
-- 报表系统 & 校验机制 - 数据库变更
-- ================================================================

-- 1. 平台收入表增加校验字段
ALTER TABLE platform_revenues 
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending_review',
  ADD COLUMN IF NOT EXISTS reviewed_by uuid,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

-- 为 status 创建索引
CREATE INDEX IF NOT EXISTS idx_platform_revenues_status ON platform_revenues(status);

-- 将现有已验证的记录状态设为 confirmed
UPDATE platform_revenues SET status = 'confirmed' WHERE verified_by IS NOT NULL AND status = 'pending_review';

-- ================================================================
-- 2. 报表 RPC 函数
-- ================================================================

-- 2.1 收支报表
CREATE OR REPLACE FUNCTION income_expense_report(start_date timestamptz, end_date timestamptz)
RETURNS JSON AS $$
DECLARE
  v_income NUMERIC := 0;
  v_expense NUMERIC := 0;
  v_refund NUMERIC := 0;
  v_net NUMERIC := 0;
  v_rate NUMERIC := 0;
  v_daily JSONB := '[]'::JSONB;
  v_category JSONB := '[]'::JSONB;
BEGIN
  -- 总收入
  SELECT COALESCE(SUM(amount), 0) INTO v_income
  FROM orders
  WHERE status IN ('completed', 'partially_refunded')
    AND deleted_at IS NULL
    AND created_at >= start_date AND created_at < end_date;

  -- 总支出
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE status IN ('approved', 'paid')
    AND deleted_at IS NULL
    AND created_at >= start_date AND created_at < end_date;

  -- 总退款
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds
  WHERE status = 'completed'
    AND deleted_at IS NULL
    AND created_at >= start_date AND created_at < end_date;

  v_net := v_income - v_expense - v_refund;
  IF v_income > 0 THEN v_rate := ROUND((v_net / v_income) * 100, 2); END IF;

  -- 按日聚合
  SELECT jsonb_agg(row_to_json(t)) INTO v_daily FROM (
    SELECT 
      to_char(d, 'YYYY-MM-DD') AS date,
      COALESCE((SELECT SUM(amount) FROM orders WHERE status IN ('completed','partially_refunded') AND deleted_at IS NULL AND created_at >= d AND created_at < d + interval '1 day'), 0) AS income,
      COALESCE((SELECT SUM(amount) FROM expenses WHERE status IN ('approved','paid') AND deleted_at IS NULL AND created_at >= d AND created_at < d + interval '1 day'), 0) AS expense
    FROM generate_series(start_date::date, (end_date - interval '1 day')::date, interval '1 day') AS d
  ) t;

  -- 按产品分类汇总
  SELECT jsonb_agg(row_to_json(t)) INTO v_category FROM (
    SELECT 
      product_category,
      COUNT(*) AS order_count,
      SUM(amount) AS total_amount
    FROM orders
    WHERE status IN ('completed', 'partially_refunded')
      AND deleted_at IS NULL
      AND created_at >= start_date AND created_at < end_date
    GROUP BY product_category
    ORDER BY total_amount DESC
  ) t;

  RETURN json_build_object(
    'total_income', v_income,
    'total_expense', v_expense,
    'total_refund', v_refund,
    'net_profit', v_net,
    'profit_rate', v_rate,
    'daily', v_daily,
    'category_summary', v_category
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.2 产品销售报表
CREATE OR REPLACE FUNCTION product_sales_report(start_date timestamptz, end_date timestamptz)
RETURNS JSON AS $$
DECLARE
  v_total_qty INT := 0;
  v_total_revenue NUMERIC := 0;
  v_total_cost NUMERIC := 0;
  v_gross_profit NUMERIC := 0;
  v_margin NUMERIC := 0;
  v_products JSONB := '[]'::JSONB;
BEGIN
  SELECT 
    COALESCE(SUM(oi.quantity), 0),
    COALESCE(SUM(o.amount), 0),
    COALESCE(SUM(oi.subtotal), 0)
  INTO v_total_qty, v_total_revenue, v_total_cost
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.status IN ('completed', 'partially_refunded')
    AND o.deleted_at IS NULL
    AND o.created_at >= start_date AND o.created_at < end_date;

  v_gross_profit := v_total_revenue - v_total_cost;
  IF v_total_revenue > 0 THEN v_margin := ROUND((v_gross_profit / v_total_revenue) * 100, 2); END IF;

  -- 各产品详情
  SELECT jsonb_agg(row_to_json(t)) INTO v_products FROM (
    SELECT 
      oi.product_name,
      o.product_category,
      SUM(oi.quantity) AS quantity,
      SUM(o.amount) AS revenue,
      SUM(oi.subtotal) AS cost,
      SUM(o.amount) - SUM(oi.subtotal) AS profit
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    WHERE o.status IN ('completed', 'partially_refunded')
      AND o.deleted_at IS NULL
      AND o.created_at >= start_date AND o.created_at < end_date
    GROUP BY oi.product_name, o.product_category
    ORDER BY revenue DESC
    LIMIT 20
  ) t;

  RETURN json_build_object(
    'total_quantity', v_total_qty,
    'total_revenue', v_total_revenue,
    'total_cost', v_total_cost,
    'gross_profit', v_gross_profit,
    'gross_margin', v_margin,
    'products', v_products
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.3 销售业绩报表
CREATE OR REPLACE FUNCTION sales_performance_report(start_date timestamptz, end_date timestamptz)
RETURNS JSON AS $$
DECLARE
  v_total_orders INT := 0;
  v_total_amount NUMERIC := 0;
  v_total_commission NUMERIC := 0;
  v_performers JSONB := '[]'::JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO v_performers FROM (
    SELECT 
      p.id AS user_id,
      COALESCE(p.name, p.nickname, '未知') AS user_name,
      p.role,
      COUNT(DISTINCT o.id) AS order_count,
      SUM(o.amount) AS total_amount,
      COALESCE(SUM(cr.commission_amount), 0) AS commission
    FROM orders o
    LEFT JOIN profiles p ON p.id = COALESCE(o.sales_id, o.creator_id)
    LEFT JOIN commission_records cr ON cr.source_type = 'order' AND cr.source_id = o.id
      AND cr.period >= to_char(start_date, 'YYYY-MM') AND cr.period <= to_char(end_date, 'YYYY-MM')
    WHERE o.status IN ('completed', 'partially_refunded')
      AND o.deleted_at IS NULL
      AND o.created_at >= start_date AND o.created_at < end_date
    GROUP BY p.id, p.name, p.nickname, p.role
    ORDER BY total_amount DESC
  ) t;

  SELECT COALESCE(SUM(x.order_count), 0), COALESCE(SUM(x.total_amount), 0), COALESCE(SUM(x.commission), 0)
  INTO v_total_orders, v_total_amount, v_total_commission
  FROM jsonb_to_recordset(v_performers) AS x(order_count int, total_amount numeric, commission numeric);

  RETURN json_build_object(
    'total_orders', v_total_orders,
    'total_amount', v_total_amount,
    'total_commission', v_total_commission,
    'performers', v_performers
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.4 账户余额汇总
CREATE OR REPLACE FUNCTION account_balance_report(as_of_date timestamptz DEFAULT NOW())
RETURNS JSON AS $$
DECLARE
  v_total_balance NUMERIC := 0;
  v_accounts JSONB := '[]'::JSONB;
  v_platform_summary JSONB := '[]'::JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO v_accounts FROM (
    SELECT 
      a.id,
      a.code,
      a.platform,
      a.bank_name,
      a.account_holder,
      a.ecommerce_platform,
      COALESCE(a.opening_balance, 0) AS balance,
      p.name AS owner_name
    FROM accounts a
    LEFT JOIN profiles p ON p.id = a.owner_id
    WHERE a.status = 'active'
    ORDER BY a.platform, a.code
  ) t;

  SELECT COALESCE(SUM(x.balance), 0) INTO v_total_balance
  FROM jsonb_to_recordset(v_accounts) AS x(balance numeric);

  SELECT jsonb_agg(row_to_json(t)) INTO v_platform_summary FROM (
    SELECT 
      COALESCE(platform, 'other') AS platform,
      SUM(COALESCE(balance, 0)) AS total
    FROM (
      SELECT 
        CASE WHEN ecommerce_platform IS NOT NULL AND ecommerce_platform != '' THEN ecommerce_platform ELSE platform END AS platform,
        COALESCE(opening_balance, 0) AS balance
      FROM accounts WHERE status = 'active'
    ) sub
    GROUP BY COALESCE(platform, 'other')
    ORDER BY total DESC
  ) t;

  RETURN json_build_object(
    'total_balance', v_total_balance,
    'accounts', v_accounts,
    'platform_summary', v_platform_summary,
    'as_of_date', as_of_date
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.5 提成报表
CREATE OR REPLACE FUNCTION commission_report(start_date timestamptz, end_date timestamptz)
RETURNS JSON AS $$
DECLARE
  v_total_commission NUMERIC := 0;
  v_paid_commission NUMERIC := 0;
  v_pending_commission NUMERIC := 0;
  v_details JSONB := '[]'::JSONB;
  v_summary JSONB := '[]'::JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO v_details FROM (
    SELECT 
      cr.id,
      cr.user_id,
      COALESCE(p.name, p.nickname, '未分配') AS user_name,
      cr.period,
      cr.source_type,
      cr.source_label,
      cr.base_amount,
      cr.rate,
      cr.commission_amount,
      cr.status,
      cr.note,
      cr.created_at
    FROM commission_records cr
    LEFT JOIN profiles p ON p.id = cr.user_id
    WHERE cr.period >= to_char(start_date, 'YYYY-MM')
      AND cr.period <= to_char(end_date, 'YYYY-MM')
    ORDER BY cr.period, cr.created_at
  ) t;

  SELECT jsonb_agg(row_to_json(t)) INTO v_summary FROM (
    SELECT 
      cr.user_id,
      COALESCE(p.name, p.nickname, '未分配') AS user_name,
      cr.period,
      SUM(cr.commission_amount) AS total_commission,
      SUM(CASE WHEN cr.status = 'paid' THEN cr.commission_amount ELSE 0 END) AS paid,
      SUM(CASE WHEN cr.status != 'paid' THEN cr.commission_amount ELSE 0 END) AS pending,
      COUNT(*) AS record_count
    FROM commission_records cr
    LEFT JOIN profiles p ON p.id = cr.user_id
    WHERE cr.period >= to_char(start_date, 'YYYY-MM')
      AND cr.period <= to_char(end_date, 'YYYY-MM')
    GROUP BY cr.user_id, p.name, p.nickname, cr.period
    ORDER BY cr.period, total_commission DESC
  ) t;

  SELECT 
    COALESCE(SUM(x.total_commission), 0),
    COALESCE(SUM(x.paid), 0),
    COALESCE(SUM(x.pending), 0)
  INTO v_total_commission, v_paid_commission, v_pending_commission
  FROM jsonb_to_recordset(v_summary) AS x(total_commission numeric, paid numeric, pending numeric);

  RETURN json_build_object(
    'total_commission', v_total_commission,
    'paid_commission', v_paid_commission,
    'pending_commission', v_pending_commission,
    'details', v_details,
    'summary', v_summary
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.6 现金流报表
CREATE OR REPLACE FUNCTION cashflow_report(start_date timestamptz, end_date timestamptz)
RETURNS JSON AS $$
DECLARE
  v_net_inflow NUMERIC := 0;
  v_net_outflow NUMERIC := 0;
  v_net_cashflow NUMERIC := 0;
  v_daily JSONB := '[]'::JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(t)) INTO v_daily FROM (
    SELECT 
      to_char(d, 'YYYY-MM-DD') AS date,
      COALESCE((SELECT SUM(amount) FROM orders WHERE status IN ('completed','partially_refunded') AND deleted_at IS NULL AND created_at >= d AND created_at < d + interval '1 day'), 0) AS inflow,
      COALESCE(
        (SELECT SUM(amount) FROM expenses WHERE status IN ('approved','paid') AND deleted_at IS NULL AND created_at >= d AND created_at < d + interval '1 day'), 0
      ) + COALESCE(
        (SELECT SUM(refund_amount) FROM refunds WHERE status = 'completed' AND deleted_at IS NULL AND created_at >= d AND created_at < d + interval '1 day'), 0
      ) AS outflow
    FROM generate_series(start_date::date, (end_date - interval '1 day')::date, interval '1 day') AS d
  ) t;

  SELECT 
    COALESCE(SUM((x.data->>'inflow')::numeric), 0),
    COALESCE(SUM((x.data->>'outflow')::numeric), 0)
  INTO v_net_inflow, v_net_outflow
  FROM jsonb_array_elements(v_daily) AS x(data);

  v_net_cashflow := v_net_inflow - v_net_outflow;

  RETURN json_build_object(
    'net_inflow', v_net_inflow,
    'net_outflow', v_net_outflow,
    'net_cashflow', v_net_cashflow,
    'daily', v_daily
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.7 异常交易检测 RPC
CREATE OR REPLACE FUNCTION detect_anomalies()
RETURNS JSON AS $$
DECLARE
  v_large_expenses JSONB := '[]'::JSONB;
  v_large_income JSONB := '[]'::JSONB;
  v_balance_changes JSONB := '[]'::JSONB;
  v_audit_anomalies JSONB := '[]'::JSONB;
  v_avg_income NUMERIC := 0;
  v_threshold NUMERIC := 0;
BEGIN
  -- 计算近30天平均日收入
  SELECT COALESCE(AVG(daily_sum), 0) INTO v_avg_income FROM (
    SELECT SUM(amount) AS daily_sum
    FROM orders
    WHERE status IN ('completed', 'partially_refunded')
      AND deleted_at IS NULL
      AND created_at >= NOW() - interval '30 days'
    GROUP BY created_at::date
  ) t;

  v_threshold := v_avg_income * 3;

  -- 今日大额支出 (>=10万)
  SELECT jsonb_agg(row_to_json(t)) INTO v_large_expenses FROM (
    SELECT id, amount, payee, category, note, created_at
    FROM expenses
    WHERE amount >= 100000
      AND deleted_at IS NULL
      AND created_at >= CURRENT_DATE
    ORDER BY amount DESC
    LIMIT 20
  ) t;

  -- 今日超出平均值3倍的收入
  SELECT jsonb_agg(row_to_json(t)) INTO v_large_income FROM (
    SELECT id, amount, customer_name, product_category, created_at
    FROM orders
    WHERE status IN ('completed', 'partially_refunded')
      AND deleted_at IS NULL
      AND amount > GREATEST(v_threshold, 50000)
      AND created_at >= CURRENT_DATE
    ORDER BY amount DESC
    LIMIT 20
  ) t;

  -- 近7天余额大幅变动（使用audit_logs检测）
  SELECT jsonb_agg(row_to_json(t)) INTO v_audit_anomalies FROM (
    SELECT id, user_id, action, table_name, record_id, created_at
    FROM audit_logs
    WHERE created_at >= NOW() - interval '3 days'
      AND action IN ('DELETE', 'UPDATE')
      AND table_name IN ('orders', 'expenses', 'accounts', 'platform_revenues')
    ORDER BY created_at DESC
    LIMIT 20
  ) t;

  RETURN json_build_object(
    'avg_daily_income', v_avg_income,
    'threshold', v_threshold,
    'large_expenses', v_large_expenses,
    'large_income', v_large_income,
    'audit_anomalies', v_audit_anomalies
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================================
-- 3. 更新 platform_revenues 的默认值（新记录自动为 pending_review）
-- ================================================================
ALTER TABLE platform_revenues ALTER COLUMN status SET DEFAULT 'pending_review';
