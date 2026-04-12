-- ============================================================
-- 财务系统 — 全部 SQL 变更（一次性执行）
-- 执行顺序：先修 → 再加 → 最后重建函数
-- ============================================================

-- ============================================================
-- 第一部分：余额修复
-- ============================================================

-- 1. 修复快照触发器：退款按账户过滤
CREATE OR REPLACE FUNCTION calculate_closing_balance()
RETURNS TRIGGER AS $$
DECLARE
  v_period TEXT;
  v_income DECIMAL(12,2);
  v_expense DECIMAL(12,2);
  v_refund DECIMAL(12,2);
  v_transfer_in DECIMAL(12,2);
  v_transfer_out DECIMAL(12,2);
  v_fee DECIMAL(12,2);
BEGIN
  v_period := NEW.period;
  
  SELECT COALESCE(SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END), 0) INTO v_income
  FROM orders o
  WHERE o.account_id = NEW.account_id
    AND o.status IN ('completed', 'partially_refunded')
    AND o.created_at >= v_period || '-01'
    AND o.created_at < (v_period || '-01')::date + interval '1 month';
  
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE account_id = NEW.account_id
    AND status = 'paid'
    AND paid_at >= v_period || '-01'
    AND paid_at < (v_period || '-01')::date + interval '1 month';
  
  SELECT COALESCE(SUM(r.refund_amount), 0) INTO v_refund
  FROM refunds r
  WHERE r.refund_to_account_id = NEW.account_id
    AND r.status = 'completed'
    AND r.completed_at >= v_period || '-01'
    AND r.completed_at < (v_period || '-01')::date + interval '1 month';
  
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
    WHERE status = 'completed' AND to_account_id = NEW.account_id
    AND created_at >= v_period || '-01'
    AND created_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
    WHERE status = 'completed' AND from_account_id = NEW.account_id
    AND created_at >= v_period || '-01'
    AND created_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
    WHERE status = 'completed' AND from_account_id = NEW.account_id
    AND created_at >= v_period || '-01'
    AND created_at < (v_period || '-01')::date + interval '1 month';
  
  NEW.closing_balance := NEW.opening_balance + v_income - v_expense - v_refund + v_transfer_in - v_transfer_out - v_fee + NEW.admin_adjustment;
  NEW.total_income := v_income;
  NEW.total_expense := v_expense;
  NEW.total_refund := v_refund;
  NEW.transfer_in := v_transfer_in;
  NEW.transfer_out := v_transfer_out;
  NEW.transfer_fee := v_fee;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. 修复 calc_account_monthly_balance 函数
CREATE OR REPLACE FUNCTION calc_account_monthly_balance(
  p_account_id UUID,
  p_period TEXT
) RETURNS DECIMAL(12,2) AS $$
DECLARE
  v_opening DECIMAL(12,2);
  v_income DECIMAL(12,2);
  v_expense DECIMAL(12,2);
  v_refund DECIMAL(12,2);
  v_transfer_in DECIMAL(12,2);
  v_transfer_out DECIMAL(12,2);
  v_fee DECIMAL(12,2);
  v_adjustment DECIMAL(12,2);
BEGIN
  BEGIN
    SELECT opening_balance INTO v_opening FROM balance_snapshots
    WHERE account_id = p_account_id AND period = p_period;
  EXCEPTION WHEN OTHERS THEN v_opening := NULL; END;
  IF v_opening IS NULL THEN
    SELECT COALESCE(opening_balance, 0) INTO v_opening FROM accounts WHERE id = p_account_id;
  END IF;

  SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
  FROM orders WHERE account_id = p_account_id
    AND status IN ('completed', 'partially_refunded')
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';

  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses WHERE account_id = p_account_id AND status = 'paid'
    AND paid_at >= p_period || '-01' AND paid_at < (p_period || '-01')::date + interval '1 month';

  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds WHERE refund_to_account_id = p_account_id AND status = 'completed'
    AND completed_at >= p_period || '-01' AND completed_at < (p_period || '-01')::date + interval '1 month';

  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
    WHERE to_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
    WHERE from_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
    WHERE from_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';

  SELECT COALESCE(admin_adjustment, 0) INTO v_adjustment FROM balance_snapshots
    WHERE account_id = p_account_id AND period = p_period;

  RETURN v_opening + v_income - v_expense - v_refund + v_transfer_in - v_transfer_out - v_fee + v_adjustment;
END;
$$ LANGUAGE plpgsql;

-- 3. increment_balance 改为原子操作
CREATE OR REPLACE FUNCTION increment_balance(
  acct_id UUID,
  delta DECIMAL(12,2)
) RETURNS JSONB AS $$
DECLARE
  v_old DECIMAL(12,2);
  v_new DECIMAL(12,2);
BEGIN
  UPDATE accounts SET balance = COALESCE(balance, 0) + delta, updated_at = NOW()
  WHERE id = acct_id RETURNING COALESCE(balance, 0) INTO v_new;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account % not found', acct_id; END IF;
  v_old := v_new - delta;
  RETURN jsonb_build_object('old_balance', v_old, 'new_balance', v_new, 'delta', delta);
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 第二部分：对账功能
-- ============================================================

-- 4. 增加对账字段
ALTER TABLE balance_snapshots
  ADD COLUMN IF NOT EXISTS actual_balance DECIMAL(12,2),
  ADD COLUMN IF NOT EXISTS balance_diff DECIMAL(12,2) GENERATED ALWAYS AS 
    (COALESCE(actual_balance, 0) - COALESCE(closing_balance, 0)) STORED,
  ADD COLUMN IF NOT EXISTS diff_reason TEXT,
  ADD COLUMN IF NOT EXISTS reconciled_by UUID REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS reconciled_at TIMESTAMPTZ;

-- 5. 对账状态索引
CREATE INDEX IF NOT EXISTS idx_bs_reconciliation ON balance_snapshots(period, account_id);


-- ============================================================
-- 第三部分：重建结算函数
-- ============================================================

-- 6. 先删再建（避免参数名冲突）
DROP FUNCTION IF EXISTS settle_monthly_balances(DATE);
DROP FUNCTION IF EXISTS generate_monthly_snapshots();

-- 7. 手动结算函数
CREATE OR REPLACE FUNCTION settle_monthly_balances(settlement_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_period TEXT;
  v_results JSONB := '[]'::JSONB;
  v_acc_id UUID;
  v_acc_code TEXT;
  v_start_date DATE;
  v_end_date DATE;
  v_existing_id UUID;
  v_prev_period TEXT;
  v_prev_closing DECIMAL(12,2);
  v_opening DECIMAL(12,2);
  v_income DECIMAL(12,2);
  v_expense DECIMAL(12,2);
  v_refund DECIMAL(12,2);
  v_transfer_in DECIMAL(12,2);
  v_transfer_out DECIMAL(12,2);
  v_fee DECIMAL(12,2);
  v_admin_adj DECIMAL(12,2);
  v_closing DECIMAL(12,2);
BEGIN
  v_period := to_char(settlement_date, 'YYYY-MM');
  v_start_date := (v_period || '-01')::DATE;
  v_end_date := v_start_date + interval '1 month';

  FOR v_acc_id, v_acc_code IN
    SELECT id, code FROM accounts WHERE status = 'active' ORDER BY ip_code, sequence, code
  LOOP
    v_prev_period := to_char(v_start_date - interval '1 month', 'YYYY-MM');
    SELECT closing_balance INTO v_prev_closing FROM balance_snapshots
      WHERE account_id = v_acc_id AND period = v_prev_period AND status = 'confirmed' LIMIT 1;
    IF v_prev_closing IS NOT NULL THEN v_opening := v_prev_closing;
    ELSE SELECT COALESCE(opening_balance, 0) INTO v_opening FROM accounts WHERE id = v_acc_id;
    END IF;

    SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
    FROM orders WHERE account_id = v_acc_id AND status IN ('completed', 'partially_refunded')
      AND created_at >= v_start_date AND created_at < v_end_date;
    SELECT COALESCE(SUM(amount), 0) INTO v_expense
    FROM expenses WHERE account_id = v_acc_id AND status = 'paid'
      AND paid_at >= v_start_date AND paid_at < v_end_date;
    SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
    FROM refunds WHERE refund_to_account_id = v_acc_id AND status = 'completed'
      AND completed_at >= v_start_date AND completed_at < v_end_date;
    SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
      WHERE status = 'completed' AND to_account_id = v_acc_id AND created_at >= v_start_date AND created_at < v_end_date;
    SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
      WHERE status = 'completed' AND from_account_id = v_acc_id AND created_at >= v_start_date AND created_at < v_end_date;
    SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
      WHERE status = 'completed' AND from_account_id = v_acc_id AND created_at >= v_start_date AND created_at < v_end_date;
    SELECT COALESCE(admin_adjustment, 0) INTO v_admin_adj FROM balance_snapshots
      WHERE account_id = v_acc_id AND period = v_period LIMIT 1;

    v_closing := v_opening + v_income - v_expense - v_refund + v_transfer_in - v_transfer_out - v_fee + v_admin_adj;

    SELECT id INTO v_existing_id FROM balance_snapshots WHERE account_id = v_acc_id AND period = v_period LIMIT 1;
    IF v_existing_id IS NOT NULL THEN
      UPDATE balance_snapshots SET opening_balance = v_opening, total_income = v_income, total_expense = v_expense,
        total_refund = v_refund, transfer_in = v_transfer_in, transfer_out = v_transfer_out, transfer_fee = v_fee,
        closing_balance = v_closing, status = 'open', settlement_date = settlement_date, updated_at = NOW()
      WHERE id = v_existing_id;
    ELSE
      INSERT INTO balance_snapshots (account_id, period, opening_balance, total_income, total_expense, total_refund,
        transfer_in, transfer_out, transfer_fee, admin_adjustment, closing_balance, status, settlement_date)
      VALUES (v_acc_id, v_period, v_opening, v_income, v_expense, v_refund, v_transfer_in, v_transfer_out, v_fee,
        v_admin_adj, v_closing, 'open', settlement_date);
    END IF;
    UPDATE accounts SET opening_balance = v_closing WHERE id = v_acc_id;
    v_results := v_results || jsonb_build_object('account_id', v_acc_id, 'account_code', v_acc_code, 'opening_balance', v_opening, 'closing_balance', v_closing);
  END LOOP;
  RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. 快捷生成函数
CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS VOID AS $$
BEGIN
  PERFORM settle_monthly_balances((to_char(NOW(), 'YYYY-MM') || '-01')::DATE + interval '1 month' - interval '1 day');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 第四部分：修复客户相关 RPC
-- ============================================================

-- 9. 修复 get_customer_detail（移除不存在的列：payment_method, total_amount, prepaid_amount, balance_due, deleted_at）
CREATE OR REPLACE FUNCTION get_customer_detail(p_customer_id uuid)
RETURNS JSON AS $$
DECLARE
  v_customer RECORD;
  v_orders json;
  v_refunds json;
  v_trend json;
BEGIN
  SELECT * INTO v_customer FROM customers WHERE id = p_customer_id;
  IF NOT FOUND THEN RETURN NULL::json; END IF;

  SELECT json_agg(row_to_json(o)) INTO v_orders
  FROM (
    SELECT o.id, o.order_no, o.product_category, o.product_name, o.amount,
      o.status, o.order_source, o.note, o.created_at
    FROM orders o WHERE o.customer_id = p_customer_id
    ORDER BY o.created_at DESC
  ) o;

  SELECT json_agg(row_to_json(r)) INTO v_refunds
  FROM (
    SELECT r.refund_no, r.refund_amount, r.reason, r.status, r.created_at,
      o.order_no, o.product_name
    FROM refunds r JOIN orders o ON o.id = r.order_id
    WHERE o.customer_id = p_customer_id
    ORDER BY r.created_at DESC
  ) r;

  SELECT json_agg(row_to_json(m)) INTO v_trend
  FROM (
    SELECT to_char(m.month, 'YYYY-MM') AS month,
      COALESCE(m.total_amount, 0)::numeric AS amount,
      COALESCE(m.count, 0)::int AS orders
    FROM (
      SELECT date_trunc('month', created_at) AS month,
        SUM(amount) AS total_amount, COUNT(*) AS count
      FROM orders WHERE customer_id = p_customer_id
        AND created_at >= now() - interval '12 months'
      GROUP BY date_trunc('month', created_at)
    ) m ORDER BY m.month
  ) m;

  RETURN json_build_object(
    'customer', to_jsonb(v_customer),
    'orders', COALESCE(v_orders, '[]'::json),
    'refunds', COALESCE(v_refunds, '[]'::json),
    'trend', COALESCE(v_trend, '[]'::json),
    'avg_order_amount', CASE WHEN v_customer.total_orders > 0
      THEN ROUND(v_customer.total_amount / v_customer.total_orders, 2) ELSE 0 END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. 修复 get_customer_stats（移除 deleted_at 引用）
DROP FUNCTION IF EXISTS get_customer_stats(text,text,text,int,int);
CREATE OR REPLACE FUNCTION get_customer_stats(
  p_search text DEFAULT '', p_status text DEFAULT '', p_tag text DEFAULT '',
  p_limit int DEFAULT 100, p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, phone text, name text, address text, source text,
  tags jsonb, status text, note text,
  total_orders int, total_amount numeric,
  first_order_at timestamptz, last_order_at timestamptz, created_at timestamptz,
  avg_amount numeric, recent_months int,
  top_products text[], refund_count int, refund_total numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.phone, c.name, c.address, c.source,
    c.tags, c.status, c.note,
    COALESCE(c.total_orders, 0)::int, COALESCE(c.total_amount, 0)::numeric,
    c.first_order_at, c.last_order_at, c.created_at,
    CASE WHEN c.total_orders > 0 THEN ROUND(c.total_amount / c.total_orders, 2) ELSE 0 END::numeric,
    (SELECT COUNT(DISTINCT date_trunc('month', o.created_at))
     FROM orders o WHERE o.customer_id = c.id
       AND o.created_at >= now() - interval '6 months')::int,
    (SELECT COALESCE(array_agg(sub.pn), ARRAY[]::text[]) FROM (SELECT product_name AS pn FROM orders o WHERE o.customer_id = c.id GROUP BY product_name ORDER BY COUNT(*) DESC LIMIT 3) sub)
     FROM (SELECT product_name, COUNT(*) count FROM orders o
           WHERE o.customer_id = c.id GROUP BY product_name ORDER BY count DESC LIMIT 3) sub)::text[],
    COALESCE((SELECT COUNT(*)::int FROM refunds r
      JOIN orders o ON o.id = r.order_id WHERE o.customer_id = c.id), 0)::int,
    COALESCE((SELECT COALESCE(SUM(refund_amount), 0) FROM refunds r
      JOIN orders o ON o.id = r.order_id WHERE o.customer_id = c.id), 0)::numeric
  FROM customers c
  WHERE (p_search = '' OR p_search IS NULL
     OR c.phone LIKE '%' || p_search || '%'
     OR c.name ILIKE '%' || p_search || '%')
    AND (p_status = '' OR p_status IS NULL OR c.status = p_status)
    AND (p_tag = '' OR p_tag IS NULL OR c.tags @> to_jsonb(p_tag::text))
  ORDER BY c.last_order_at DESC NULLS LAST, c.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. 修复 update_customer_stats（移除 deleted_at）
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS void AS $$
BEGIN
  UPDATE customers c SET
    total_orders = sub.cnt, total_amount = sub.total,
    first_order_at = sub.first_at, last_order_at = sub.last_at,
    updated_at = now()
  FROM (
    SELECT customer_id, COUNT(*) AS cnt,
      COALESCE(SUM(amount), 0) AS total,
      MIN(created_at) AS first_at, MAX(created_at) AS last_at
    FROM orders WHERE customer_id IS NOT NULL GROUP BY customer_id
  ) sub WHERE c.id = sub.customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
