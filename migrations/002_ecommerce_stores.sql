-- 电商店铺系统 - 数据库迁移
-- 执行日期: 2026-04-01

-- 1. accounts 表新增 withdrawal_account_id（绑定提现到账账户）
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS withdrawal_account_id UUID REFERENCES accounts(id);

-- 2. 补齐现有抖音/快手/视频号店铺的 ecommerce_platform 字段
UPDATE accounts SET ecommerce_platform = 'douyin' WHERE platform = 'douyin' AND ecommerce_platform IS NULL;
UPDATE accounts SET ecommerce_platform = 'kuaishou' WHERE platform = 'kuaishou' AND ecommerce_platform IS NULL;
UPDATE accounts SET ecommerce_platform = 'shipinhao' WHERE platform = 'shipinhao' AND ecommerce_platform IS NULL;

-- 3. 创建 withdrawals（提现记录）表
CREATE TABLE IF NOT EXISTS withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id),
  to_account_id UUID NOT NULL REFERENCES accounts(id),
  amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  fee_detail JSONB DEFAULT '{}',
  actual_arrival NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  withdrawn_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  remark TEXT,
  created_by UUID REFERENCES auth.users(id)
);

-- 4. 索引
CREATE INDEX IF NOT EXISTS withdrawals_account_id_idx ON withdrawals(account_id);
CREATE INDEX IF NOT EXISTS withdrawals_created_at_idx ON withdrawals(created_at DESC);

-- 5. RLS
ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "withdrawals_select" ON withdrawals FOR SELECT USING (true);
CREATE POLICY "withdrawals_insert" ON withdrawals FOR INSERT WITH CHECK (true);
CREATE POLICY "withdrawals_update" ON withdrawals FOR UPDATE USING (true);
CREATE POLICY "withdrawals_delete" ON withdrawals FOR DELETE USING (true);

-- 6. 电商日统计视图
CREATE OR REPLACE VIEW v_ecommerce_daily AS
SELECT
  a.id AS account_id,
  a.short_name AS store_name,
  a.platform,
  a.ecommerce_platform,
  a.settlement_days,
  DATE(o.order_time) AS order_date,
  COUNT(o.id) FILTER (WHERE o.status IN ('completed', 'partially_refunded')) AS order_count,
  COALESCE(SUM(o.payment_amount) FILTER (WHERE o.status IN ('completed', 'partially_refunded')), 0) AS sales_amount,
  COALESCE(SUM(r.refund_amount) FILTER (WHERE r.status = 'completed'), 0) AS refund_amount,
  COALESCE(SUM(
    CASE WHEN o.status IN ('completed', 'partially_refunded') THEN o.actual_income ELSE 0 END
  ) -
  COALESCE(SUM(r.refund_amount) FILTER (WHERE r.status = 'completed'), 0), 0) AS net_income
FROM accounts a
LEFT JOIN orders o ON o.account_id = a.id AND o.deleted_at IS NULL
LEFT JOIN refunds r ON r.order_id = o.id AND r.status = 'completed' AND r.deleted_at IS NULL
WHERE a.ecommerce_platform IS NOT NULL AND a.status = 'active'
GROUP BY a.id, a.short_name, a.platform, a.ecommerce_platform, a.settlement_days, DATE(o.order_time);

-- 7. 可提现金额计算 RPC
CREATE OR REPLACE FUNCTION get_withdrawable_amount(p_account_id UUID)
RETURNS NUMERIC(12,2) AS $$
DECLARE
  v_settlement_days INT;
  v_result NUMERIC(12,2);
BEGIN
  SELECT COALESCE(settlement_days, 15) INTO v_settlement_days
  FROM accounts WHERE id = p_account_id;

  SELECT COALESCE(SUM(actual_income), 0) INTO v_result
  FROM orders
  WHERE account_id = p_account_id
    AND status IN ('completed', 'partially_refunded')
    AND deleted_at IS NULL
    AND order_time IS NOT NULL
    AND order_time + (v_settlement_days || ' days')::INTERVAL <= CURRENT_DATE;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- 8. 执行提现 RPC
CREATE OR REPLACE FUNCTION execute_withdrawal(
  p_account_id UUID,
  p_to_account_id UUID,
  p_amount NUMERIC(12,2),
  p_fee_detail JSONB DEFAULT '{}',
  p_remark TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_actual_arrival NUMERIC(12,2);
  v_new_balance NUMERIC(12,2);
  v_to_balance NUMERIC(12,2);
  v_wid UUID;
BEGIN
  v_actual_arrival := p_amount - (
    COALESCE((p_fee_detail->>'technical_fee')::NUMERIC, 0) +
    COALESCE((p_fee_detail->>'payment_fee')::NUMERIC, 0) +
    COALESCE((p_fee_detail->>'withdraw_fee')::NUMERIC, 0) +
    COALESCE((p_fee_detail->>'other_fee')::NUMERIC, 0)
  );

  -- 扣减店铺余额
  UPDATE accounts SET balance = balance - p_amount, updated_at = NOW()
  WHERE id = p_account_id RETURNING balance INTO v_new_balance;

  -- 增加到账账户余额
  UPDATE accounts SET balance = balance + v_actual_arrival, updated_at = NOW()
  WHERE id = p_to_account_id RETURNING balance INTO v_to_balance;

  -- 插入提现记录
  INSERT INTO withdrawals (account_id, to_account_id, amount, fee_detail, actual_arrival, status, withdrawn_at, remark)
  VALUES (p_account_id, p_to_account_id, p_amount, p_fee_detail, v_actual_arrival, 'completed', NOW(), p_remark)
  RETURNING id INTO v_wid;

  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_wid,
    'actual_arrival', v_actual_arrival,
    'store_balance', v_new_balance,
    'to_balance', v_to_balance
  );
END;
$$ LANGUAGE plpgsql;
