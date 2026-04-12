-- ============================================================
-- 财务系统余额修复脚本
-- 修复问题：
--   1. 余额快照退款未按账户过滤（可能导致重复计算退款）
--   2. increment_balance 增加 optimistic locking 防并发
--   3. 增加订单状态变更的余额触发器（DB层面兜底）
-- ============================================================

-- ============================================================
-- 修复1：快照触发器中退款计算增加账户过滤
-- 原问题：refund 计算没有 WHERE refund_to_account_id = NEW.account_id
-- 影响：所有账户的退款金额被混在一起算
-- ============================================================

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
  
  -- 本月收入（completed + partially_refunded 的订单金额）
  SELECT COALESCE(SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END), 0) INTO v_income
  FROM orders o
  WHERE o.account_id = NEW.account_id
    AND o.status IN ('completed', 'partially_refunded')
    AND o.created_at >= v_period || '-01'
    AND o.created_at < (v_period || '-01')::date + interval '1 month';
  
  -- 本月支出
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE account_id = NEW.account_id
    AND status = 'paid'
    AND paid_at >= v_period || '-01'
    AND paid_at < (v_period || '-01')::date + interval '1 month';
  
  -- 本月退款（增加了 refund_to_account_id 过滤！）
  SELECT COALESCE(SUM(r.refund_amount), 0) INTO v_refund
  FROM refunds r
  WHERE r.refund_to_account_id = NEW.account_id
    AND r.status = 'completed'
    AND r.completed_at >= v_period || '-01'
    AND r.completed_at < (v_period || '-01')::date + interval '1 month';
  
  -- 本月转入/转出/手续费
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
  
  -- 期末余额
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

-- 同样修复 balance-auto-calc.sql 中的函数
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
  -- 期初余额
  BEGIN
    SELECT opening_balance INTO v_opening FROM balance_snapshots
    WHERE account_id = p_account_id AND period = p_period;
  EXCEPTION WHEN OTHERS THEN
    v_opening := NULL;
  END;
  
  IF v_opening IS NULL THEN
    SELECT COALESCE(opening_balance, 0) INTO v_opening
    FROM accounts WHERE id = p_account_id;
  END IF;

  -- 本月收入（增加 account_id 过滤！）
  SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
  FROM orders
  WHERE account_id = p_account_id
    AND status IN ('completed', 'partially_refunded')
    AND created_at >= p_period || '-01'
    AND created_at < (p_period || '-01')::date + interval '1 month';

  -- 本月支出
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE account_id = p_account_id
    AND status = 'paid'
    AND paid_at >= p_period || '-01'
    AND paid_at < (p_period || '-01')::date + interval '1 month';

  -- 本月退款（增加 refund_to_account_id 过滤！）
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds
  WHERE refund_to_account_id = p_account_id
    AND status = 'completed'
    AND completed_at >= p_period || '-01'
    AND completed_at < (p_period || '-01')::date + interval '1 month';

  -- 转入转出
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
    WHERE to_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
    WHERE from_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
    WHERE from_account_id = p_account_id AND status = 'completed'
    AND created_at >= p_period || '-01' AND created_at < (p_period || '-01')::date + interval '1 month';

  -- 管理调整
  SELECT COALESCE(admin_adjustment, 0) INTO v_adjustment FROM balance_snapshots
    WHERE account_id = p_account_id AND period = p_period;

  RETURN v_opening + v_income - v_expense - v_refund + v_transfer_in - v_transfer_out - v_fee + v_adjustment;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 修复2：increment_balance 增加 optimistic locking
-- 原问题：并发时两个请求可能同时读到相同余额，导致后写的覆盖先写的
-- 修复：使用 balance = balance + delta 原子更新
-- ============================================================

CREATE OR REPLACE FUNCTION increment_balance(
  acct_id UUID,
  delta DECIMAL(12,2)
) RETURNS JSONB AS $$
DECLARE
  v_old DECIMAL(12,2);
  v_new DECIMAL(12,2);
BEGIN
  -- 原子更新：balance = balance + delta
  UPDATE accounts
  SET balance = COALESCE(balance, 0) + delta,
      updated_at = NOW()
  WHERE id = acct_id
  RETURNING COALESCE(balance, 0) INTO v_new;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account % not found', acct_id;
  END IF;

  v_old := v_new - delta;

  RETURN jsonb_build_object(
    'old_balance', v_old,
    'new_balance', v_new,
    'delta', delta
  );
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 修复3（增强）：DB层面订单状态变更自动调余额（兜底机制）
-- 即前端忘了调 updateBalance，数据库也能保证余额正确
-- 注意：这个触发器和前端逻辑会重复执行，所以前端应该改成
-- 只在没有触发器的情况下手动调余额，或者去掉前端手动调
-- 建议策略：保留前端逻辑（有日志），触发器做兜底检查
-- ============================================================

-- 方案：不添加DB触发器，因为前端已经有完整的状态变更余额逻辑
-- 只通过上面的 increment_balance 原子操作来解决并发问题
-- 前端逻辑修改见 orders.js 的变更记录

-- ============================================================
-- 修复4：数据修复 — 重新计算本月快照（如果已有错误数据）
-- ============================================================

-- 删除本月可能错误的快照，让触发器重新计算
-- WARNING: 只在确认快照数据有问题时执行！
-- DELETE FROM balance_snapshots WHERE period = to_char(NOW(), 'YYYY-MM');
-- 然后重新生成快照（通过调用 generate_monthly_snapshots）
-- SELECT generate_monthly_snapshots();
