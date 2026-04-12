-- ============================================================
-- 006: 添加 orders 表缺失字段 + 修复约束
-- ============================================================

-- 客服号编码
ALTER TABLE orders ADD COLUMN IF NOT EXISTS service_number_code TEXT;

-- 分成销售（共享业绩）
ALTER TABLE orders ADD COLUMN IF NOT EXISTS shared_sales_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 支付方式
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT;

-- 电商店铺名
ALTER TABLE orders ADD COLUMN IF NOT EXISTS platform_store TEXT;

-- 放宽 account_code 约束（允许为空）
ALTER TABLE orders ALTER COLUMN account_code DROP NOT NULL;
ALTER TABLE orders ALTER COLUMN account_code SET DEFAULT '';

-- order_no 自动生成函数
CREATE OR REPLACE FUNCTION generate_order_no()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN 'ORD' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || lpad(floor(random()*100000)::TEXT, 5, '0');
END;
$$;

ALTER TABLE orders ALTER COLUMN order_no DROP NOT NULL;
ALTER TABLE orders ALTER COLUMN order_no SET DEFAULT generate_order_no();

-- 索引
CREATE INDEX IF NOT EXISTS idx_orders_service_number_code ON orders(service_number_code);
CREATE INDEX IF NOT EXISTS idx_orders_shared_sales_id ON orders(shared_sales_id);
