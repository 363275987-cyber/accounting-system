-- 创建 settle_monthly_balances 函数（手动结算用）
-- 被 Balance.vue 的手动结算功能调用

CREATE OR REPLACE FUNCTION settle_monthly_balances(settlement_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_period TEXT;
  v_results JSONB := '[]'::JSONB;
  v_acc_id UUID;
  v_acc_code TEXT;
  v_ip_code TEXT;
  v_short_name TEXT;
  v_opening DECIMAL(12,2);
  v_closing DECIMAL(12,2);
  v_income DECIMAL(12,2);
  v_expense DECIMAL(12,2);
  v_refund DECIMAL(12,2);
  v_transfer_in DECIMAL(12,2);
  v_transfer_out DECIMAL(12,2);
  v_fee DECIMAL(12,2);
  v_admin_adj DECIMAL(12,2);
  v_start_date DATE;
  v_end_date DATE;
  v_existing_id UUID;
  v_prev_period TEXT;
  v_prev_closing DECIMAL(12,2);
  v_user_id UUID;
BEGIN
  v_period := to_char(settlement_date, 'YYYY-MM');
  v_start_date := (v_period || '-01')::DATE;
  v_end_date := (v_period || '-01')::DATE + interval '1 month';

  -- 获取当前操作用户
  v_user_id := auth.uid();

  FOR v_acc_id, v_acc_code, v_ip_code, v_short_name IN
    SELECT id, code, ip_code, COALESCE(short_name, code)
    FROM accounts
    WHERE status = 'active'
    ORDER BY ip_code, sequence, code
  LOOP
    -- 获取期初余额：优先用上月快照的期末，否则用账户的 opening_balance
    v_prev_period := to_char((v_period || '-01')::DATE - interval '1 month', 'YYYY-MM');
    SELECT closing_balance INTO v_prev_closing
    FROM balance_snapshots
    WHERE account_id = v_acc_id AND period = v_prev_period AND status = 'confirmed'
    LIMIT 1;

    IF v_prev_closing IS NOT NULL THEN
      v_opening := v_prev_closing;
    ELSE
      SELECT COALESCE(opening_balance, 0) INTO v_opening
      FROM accounts WHERE id = v_acc_id;
    END IF;

    -- 计算本月各项
    SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
    FROM orders
    WHERE account_id = v_acc_id
      AND status IN ('completed', 'partially_refunded')
      AND created_at >= v_start_date AND created_at < v_end_date;

    SELECT COALESCE(SUM(amount), 0) INTO v_expense
    FROM expenses
    WHERE account_id = v_acc_id AND status = 'paid'
      AND paid_at >= v_start_date AND paid_at < v_end_date;

    SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
    FROM refunds
    WHERE refund_to_account_id = v_acc_id AND status = 'completed'
      AND completed_at >= v_start_date AND completed_at < v_end_date;

    SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
      WHERE status = 'completed' AND to_account_id = v_acc_id
      AND created_at >= v_start_date AND created_at < v_end_date;

    SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
      WHERE status = 'completed' AND from_account_id = v_acc_id
      AND created_at >= v_start_date AND created_at < v_end_date;

    SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
      WHERE status = 'completed' AND from_account_id = v_acc_id
      AND created_at >= v_start_date AND created_at < v_end_date;

    -- 获取现有的管理调整
    SELECT COALESCE(admin_adjustment, 0) INTO v_admin_adj
    FROM balance_snapshots
    WHERE account_id = v_acc_id AND period = v_period
    LIMIT 1;

    -- 期末余额
    v_closing := v_opening + v_income - v_expense - v_refund + v_transfer_in - v_transfer_out - v_fee + v_admin_adj;

    -- 检查是否已有快照记录
    SELECT id INTO v_existing_id
    FROM balance_snapshots
    WHERE account_id = v_acc_id AND period = v_period
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      -- 更新现有快照（保留 actual_balance、diff_reason、reconciled_by 等对账字段）
      UPDATE balance_snapshots SET
        opening_balance = v_opening,
        total_income = v_income,
        total_expense = v_expense,
        total_refund = v_refund,
        transfer_in = v_transfer_in,
        transfer_out = v_transfer_out,
        transfer_fee = v_fee,
        closing_balance = v_closing,
        status = 'open',
        settlement_date = settlement_date,
        updated_at = NOW()
      WHERE id = v_existing_id;
    ELSE
      -- 创建新快照
      INSERT INTO balance_snapshots (
        account_id, period, opening_balance,
        total_income, total_expense, total_refund,
        transfer_in, transfer_out, transfer_fee,
        admin_adjustment, closing_balance, status, settlement_date
      ) VALUES (
        v_acc_id, v_period, v_opening,
        v_income, v_expense, v_refund,
        v_transfer_in, v_transfer_out, v_fee,
        v_admin_adj, v_closing, 'open', settlement_date
      );
    END IF;

    -- 更新账户的 opening_balance 为本次结算的期末余额（下月期初 = 本月期末）
    UPDATE accounts SET opening_balance = v_closing WHERE id = v_acc_id;

    -- 收集结果
    v_results := v_results || jsonb_build_object(
      'account_id', v_acc_id,
      'account_code', v_acc_code,
      'opening_balance', v_opening,
      'closing_balance', v_closing
    );
  END LOOP;

  RETURN v_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 同时创建 generate_monthly_snapshots 函数（如果不存在）
CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS VOID AS $$
DECLARE
  v_period TEXT;
  v_settlement_date DATE;
BEGIN
  v_period := to_char(NOW(), 'YYYY-MM');
  v_settlement_date := (v_period || '-01')::DATE + interval '1 month' - interval '1 day';
  PERFORM settle_monthly_balances(v_settlement_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
