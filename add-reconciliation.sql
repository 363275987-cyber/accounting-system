-- ============================================================
-- 对账功能增强
-- 在 balance_snapshots 表上增加对账字段
-- ============================================================

-- 1. 增加对账字段
ALTER TABLE balance_snapshots
  ADD COLUMN IF NOT EXISTS actual_balance DECIMAL(12,2),
  ADD COLUMN IF NOT EXISTS balance_diff DECIMAL(12,2) GENERATED ALWAYS AS 
    (COALESCE(actual_balance, 0) - COALESCE(closing_balance, 0)) STORED,
  ADD COLUMN IF NOT EXISTS diff_reason TEXT,
  ADD COLUMN IF NOT EXISTS reconciled_by UUID REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS reconciled_at TIMESTAMPTZ;

COMMENT ON COLUMN balance_snapshots.actual_balance IS '对账：实际余额（从银行APP/微信钱包填入）';
COMMENT ON COLUMN balance_snapshots.balance_diff IS '对账差额 = 实际余额 - 计算余额，0表示一致';
COMMENT ON COLUMN balance_snapshots.diff_reason IS '对账：差额原因说明';
COMMENT ON COLUMN balance_snapshots.reconciled_by IS '对账操作人';
COMMENT ON COLUMN balance_snapshots.reconciled_at IS '对账时间';

-- 2. 增加对账明细视图：每个账户每月的收支明细汇总（用于对账时展开查看）
CREATE OR REPLACE VIEW v_reconciliation_detail AS
SELECT 
  bs.id AS snapshot_id,
  bs.account_id,
  a.code AS account_code,
  a.short_name AS account_name,
  a.ip_code,
  bs.period,
  bs.opening_balance,
  bs.total_income,
  bs.total_expense,
  bs.total_refund,
  bs.transfer_in,
  bs.transfer_out,
  bs.transfer_fee,
  bs.admin_adjustment,
  bs.admin_reason,
  bs.closing_balance,
  bs.actual_balance,
  bs.balance_diff,
  bs.diff_reason,
  CASE 
    WHEN bs.actual_balance IS NULL THEN 'pending'
    WHEN ABS(bs.balance_diff) < 0.01 THEN 'matched'
    ELSE 'mismatch'
  END AS reconciliation_status,
  bs.reconciled_at,
  COALESCE(
    (SELECT p.name FROM profiles p WHERE p.id = bs.reconciled_by),
    '未对账'
  ) AS reconciled_by_name
FROM balance_snapshots bs
LEFT JOIN accounts a ON a.id = bs.account_id
ORDER BY a.ip_code, a.code;

-- 3. 对账状态索引
CREATE INDEX IF NOT EXISTS idx_bs_reconciliation ON balance_snapshots(period, account_id);

-- 4. 各账户每月订单明细（对账时展开查看具体是哪些订单）
-- 这个不需要建视图，直接在前端按条件查就行：
-- SELECT * FROM orders WHERE account_id = ? AND status IN ('completed','partially_refunded') 
--   AND created_at >= '2026-03-01' AND created_at < '2026-04-01'
--   ORDER BY created_at DESC
