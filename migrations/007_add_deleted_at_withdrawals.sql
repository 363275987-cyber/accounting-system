-- ============================================================
-- 007: 为 withdrawals / account_transfers 补充 deleted_at 字段（支持软删）
-- 背景：数据初始化页要清空这两类流水；原表分别建于 002 / 003，migration 005
-- 补 deleted_at 时唯独漏了这两张表，导致初始化无法处理。
-- ============================================================

ALTER TABLE withdrawals       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE account_transfers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 活跃记录索引（过滤 deleted_at IS NULL 的常用查询）
CREATE INDEX IF NOT EXISTS idx_withdrawals_active
  ON withdrawals(created_at DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_account_transfers_active
  ON account_transfers(created_at DESC)
  WHERE deleted_at IS NULL;
