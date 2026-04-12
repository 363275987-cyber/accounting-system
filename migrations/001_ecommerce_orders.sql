-- 电商订单系统 - 数据库迁移
-- 在 Supabase SQL Editor 中执行

-- 1. 给 orders 表添加电商相关字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS external_order_no text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_type text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_store text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS sku_code text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_amount numeric default 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS freight numeric default 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_fee numeric default 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS actual_income numeric default 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_time timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shipped_at timestamptz;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- 2. 给 refunds 表添加电商相关字段（如果不存在）
ALTER TABLE refunds ADD COLUMN IF NOT EXISTS platform_type text;
ALTER TABLE refunds ADD COLUMN IF NOT EXISTS refund_no text;

-- 3. 给 orders 表的 platform_type + external_order_no 添加唯一索引（去重）
CREATE UNIQUE INDEX IF NOT EXISTS orders_platform_external_no_uniq
  ON orders (platform_type, external_order_no)
  WHERE external_order_no IS NOT NULL AND platform_type IS NOT NULL AND deleted_at IS NULL;

-- 4. 给 refunds 表的 refund_no 添加唯一索引（售后去重）
CREATE UNIQUE INDEX IF NOT EXISTS refunds_refund_no_uniq
  ON refunds (refund_no)
  WHERE refund_no IS NOT NULL AND deleted_at IS NULL;
