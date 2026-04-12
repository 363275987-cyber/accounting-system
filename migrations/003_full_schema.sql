-- ============================================================================
-- 完整数据库 Schema - 台球公司账目管理系统
-- 生成时间：2026-04-01
-- 说明：此文件为记录性质，不应直接执行
--       使用 CREATE TABLE IF NOT EXISTS，执行不会破坏现有数据
-- ============================================================================

-- ============================================================================
-- 1. 用户资料表
-- ============================================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'sales' CHECK (role IN ('sales', 'cs', 'finance', 'manager', 'admin', 'hr', 'coach')),
  ip_code TEXT,                    -- IP简称，如"楠"
  department TEXT,                 -- 所属部门
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. 收款账户表
-- ============================================================================
CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,       -- 账户标识，如"楠一微信"
  short_name TEXT,                 -- 简称/展示名
  real_name TEXT,                  -- 实名（实名认证）
  ip_code TEXT NOT NULL,           -- IP简称
  sequence INT NOT NULL,           -- 序号（排序用）
  platform TEXT NOT NULL CHECK (platform IN ('wechat', 'alipay', 'bank', 'taobao', 'douyin', 'kuaishou', 'cash', 'other')),
  bank_name TEXT,                  -- 银行名称（银行卡类）
  account_no TEXT,                 -- 银行账号/公户号
  account_holder TEXT,             -- 户名/主体名
  owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- 负责人（客服/销售）
  balance DECIMAL(12,2) DEFAULT 0,
  opening_balance DECIMAL(12,2) DEFAULT 0,  -- 期初余额（创建账户时设置）
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
  category TEXT CHECK (category IN ('personal', 'company')),  -- 账户分类：个人/公司
  ecommerce_platform TEXT,         -- 电商平台标识（非空表示电商店铺账户）
  store_name TEXT,                 -- 店铺名称（电商账户）
  settlement_days INT DEFAULT 0,   -- 结算周期（天）
  withdrawal_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,  -- 提现目标账户
  cert_phone TEXT,                 -- 实名认证手机号
  id_number TEXT,                  -- 身份证号（加密存储）
  payment_alias TEXT,              -- 付款别名（转账时显示的名称，如"南113珊"）
  note TEXT,
  deleted_at TIMESTAMPTZ,          -- 软删除标记
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. 渠道分配表
-- ============================================================================
CREATE TABLE IF NOT EXISTS channel_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  sales_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_at TIMESTAMPTZ,          -- 释放时间
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'released')),
  note TEXT
);
CREATE INDEX IF NOT EXISTS idx_ca_account ON channel_assignments(account_id);
CREATE INDEX IF NOT EXISTS idx_ca_sales ON channel_assignments(sales_id);
CREATE INDEX IF NOT EXISTS idx_ca_status ON channel_assignments(status);

-- ============================================================================
-- 4. 订单表（含电商字段）
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no TEXT UNIQUE NOT NULL DEFAULT 'ORD' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || lpad(floor(random()*100000)::TEXT, 5, '0'),
  account_id UUID REFERENCES accounts(id),
  account_code TEXT NOT NULL,       -- 冗余字段，方便查询和筛选
  creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  sales_id UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- 实际业绩归属销售
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  customer_address TEXT,
  product_category TEXT NOT NULL CHECK (product_category IN ('cue', 'accessory', 'recording_course', 'offline_camp', 'other')),
  product_name TEXT NOT NULL,
  amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled', 'refunded', 'partially_refunded')),
  order_source TEXT DEFAULT 'sales_guided' CHECK (order_source IN ('sales_guided', 'organic', 'cs_service')),
  tags JSONB DEFAULT '[]',
  note TEXT,
  -- 电商字段（001_ecommerce_orders.sql 添加）
  external_order_no TEXT,          -- 平台外部订单号
  platform_type TEXT,              -- 平台类型：douyin/kuaishou/shipinhao 等
  platform_store TEXT,             -- 平台店铺名称
  sku_code TEXT,                   -- SKU 编码
  quantity INT DEFAULT 1,          -- 商品数量（电商订单）
  payment_amount NUMERIC DEFAULT 0, -- 实付金额（买家支付）
  freight NUMERIC DEFAULT 0,       -- 运费
  platform_fee NUMERIC DEFAULT 0,  -- 平台手续费/扣点
  actual_income NUMERIC DEFAULT 0, -- 实际收入（payment_amount - platform_fee - freight）
  order_time TIMESTAMPTZ,          -- 平台订单时间
  shipped_at TIMESTAMPTZ,          -- 发货时间
  completed_at TIMESTAMPTZ,        -- 完成时间
  store_name TEXT,                 -- 店铺名称（冗余）
  deleted_at TIMESTAMPTZ,          -- 软删除标记
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS orders_platform_external_no_uniq
  ON orders (platform_type, external_order_no)
  WHERE external_order_no IS NOT NULL AND platform_type IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_orders_account ON orders(account_id);
CREATE INDEX IF NOT EXISTS idx_orders_account_code ON orders(account_code);
CREATE INDEX IF NOT EXISTS idx_orders_creator ON orders(creator_id);
CREATE INDEX IF NOT EXISTS idx_orders_sales ON orders(sales_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_category ON orders(product_category);

-- ============================================================================
-- 5. 支出表
-- ============================================================================
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('salary', 'rent', 'equipment', 'marketing', 'tax', 'daily', 'shipping', 'platform_fee', 'refund', 'other')),
  amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
  payee TEXT NOT NULL,
  account_id UUID REFERENCES accounts(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'rejected')),
  approval_required BOOLEAN GENERATED ALWAYS AS (CASE WHEN amount > 2000 THEN TRUE ELSE FALSE END) STORED,
  approver_id UUID REFERENCES profiles(id),
  receipt_url TEXT,
  note TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ
);

-- ============================================================================
-- 6. 支出类别表
-- ============================================================================
CREATE TABLE IF NOT EXISTS expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 7. 退款记录表（含电商退款字段）
-- ============================================================================
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  refund_no TEXT UNIQUE NOT NULL DEFAULT 'REF' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || lpad(floor(random()*10000)::TEXT, 4, '0'),
  refund_amount DECIMAL(12,2) NOT NULL CHECK (refund_amount > 0),
  reason TEXT NOT NULL DEFAULT '客户退货',
  refund_to_account_id UUID REFERENCES accounts(id),
  refund_from_account_id UUID REFERENCES accounts(id),
  refund_channel TEXT CHECK (refund_channel IN ('original', 'wechat', 'alipay', 'bank', 'cash', 'other')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  note TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  -- 电商退款字段
  platform_type TEXT,              -- 电商平台类型
  deleted_at TIMESTAMPTZ,          -- 软删除标记
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS refunds_refund_no_uniq
  ON refunds (refund_no)
  WHERE refund_no IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_refunds_order ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_date ON refunds(created_at DESC);

-- ============================================================================
-- 8. 账户转账表
-- ============================================================================
CREATE TABLE IF NOT EXISTS account_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_account_id UUID NOT NULL REFERENCES accounts(id),
  to_account_id UUID NOT NULL REFERENCES accounts(id),
  amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
  fee DECIMAL(12,2) DEFAULT 0,
  note TEXT,
  created_by UUID NOT NULL REFERENCES profiles(id),
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 9. 平台收入表
-- ============================================================================
CREATE TABLE IF NOT EXISTS platform_revenues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL CHECK (platform IN ('douyin', 'kuaishou', 'wechat_video', 'taobao', 'other')),
  period TEXT NOT NULL,           -- 如 "2026-03"
  total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
  settled_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  pending_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  fee_rate DECIMAL(5,2) DEFAULT 0,  -- 费率%
  fee_amount DECIMAL(12,2) DEFAULT 0,
  data_source TEXT DEFAULT 'manual' CHECK (data_source IN ('manual', 'api')),
  source_url TEXT,
  recorded_by UUID REFERENCES profiles(id),
  verified_by UUID REFERENCES profiles(id),
  verified_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(platform, period)
);

-- ============================================================================
-- 10. 销售目标表
-- ============================================================================
CREATE TABLE IF NOT EXISTS sales_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  period_type TEXT NOT NULL CHECK (period_type IN ('monthly', 'quarterly')),
  period_value TEXT NOT NULL,
  target_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  target_orders INT NOT NULL DEFAULT 0,
  actual_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  actual_orders INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'achieved', 'missed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, period_type, period_value)
);

-- ============================================================================
-- 11. 系统设置表
-- ============================================================================
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 12. 审计日志表
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  table_name TEXT,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 13. 操作日志表（应用层日志，区别于 audit_logs）
-- ============================================================================
CREATE TABLE IF NOT EXISTS operation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  user_name TEXT,
  action TEXT NOT NULL,           -- 操作类型：create_order, delete_order, pay_expense, transfer, refund, manual_balance 等
  module TEXT NOT NULL,            -- 模块：订单, 支出, 转账, 退款, 账户 等
  description TEXT NOT NULL,       -- 人类可读的中文描述
  detail JSONB DEFAULT '{}',       -- 结构化详情
  amount DECIMAL(12,2),            -- 涉及金额
  account_id UUID,                 -- 涉及账户ID
  account_name TEXT,               -- 涉及账户名称
  balance_before DECIMAL(12,2),    -- 操作前余额
  balance_after DECIMAL(12,2),     -- 操作后余额
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 14. 余额变更审批日志表
-- ============================================================================
CREATE TABLE IF NOT EXISTS balance_change_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  account_name TEXT NOT NULL,
  old_balance DECIMAL(12,2) NOT NULL,
  new_balance DECIMAL(12,2) NOT NULL,
  requested_by UUID REFERENCES profiles(id),
  requested_by_name TEXT,
  approved_by UUID REFERENCES profiles(id),
  approved_by_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reason TEXT,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 15. 账户余额快照表
-- ============================================================================
CREATE TABLE IF NOT EXISTS balance_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  period TEXT NOT NULL,                  -- 格式 "2026-03"
  opening_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_income DECIMAL(12,2) NOT NULL DEFAULT 0,     -- 本月订单收入
  total_expense DECIMAL(12,2) NOT NULL DEFAULT 0,    -- 本月支出
  total_refund DECIMAL(12,2) NOT NULL DEFAULT 0,     -- 本月退款
  transfer_in DECIMAL(12,2) NOT NULL DEFAULT 0,       -- 转入
  transfer_out DECIMAL(12,2) NOT NULL DEFAULT 0,      -- 转出
  transfer_fee DECIMAL(12,2) NOT NULL DEFAULT 0,       -- 手续费
  closing_balance DECIMAL(12,2) NOT NULL DEFAULT 0,    -- 期末余额
  admin_adjustment DECIMAL(12,2) NOT NULL DEFAULT 0,  -- admin手动调整
  admin_reason TEXT,                          -- 调整原因
  confirmed_by UUID REFERENCES profiles(id),
  confirmed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'confirmed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(account_id, period)
);

-- ============================================================================
-- 16. 产品表（SPU）
-- ============================================================================
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  spu_code TEXT,                  -- SPU 编号（如 SP-001）
  category TEXT,                  -- 产品分类（cue, accessory 等）
  brand TEXT,                     -- 品牌
  image TEXT,                     -- 产品图片URL
  cost_price DECIMAL(12,2) DEFAULT 0,   -- 成本价
  retail_price DECIMAL(12,2) DEFAULT 0,  -- 零售价
  unit TEXT DEFAULT '件',         -- 单位
  description TEXT,               -- 产品描述
  product_type TEXT DEFAULT 'single' CHECK (product_type IN ('single', 'bundle')),  -- 单品/套装
  min_stock INT DEFAULT 0,        -- 最低库存预警值
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'discontinued')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 17. 产品 SKU 表
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_skus (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku_code TEXT NOT NULL,          -- SKU 编码（唯一，用于订单导入匹配）
  specs TEXT,                     -- 规格描述（如"红色-L"）
  cost_price DECIMAL(12,2) DEFAULT 0,
  retail_price DECIMAL(12,2) DEFAULT 0,
  stock INT DEFAULT 0,            -- 库存数量
  barcode TEXT,                   -- 条形码
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(product_id, sku_code)
);

-- ============================================================================
-- 18. 套装明细表
-- ============================================================================
CREATE TABLE IF NOT EXISTS bundle_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bundle_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,  -- 套装产品ID
  sku_id UUID REFERENCES product_skus(id) ON DELETE SET NULL,          -- 子SKU ID
  quantity INT NOT NULL DEFAULT 1,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 19. 产品套装表（赠品套装系统）
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_bundles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  main_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT,                      -- 套装名称
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(main_product_id)
);

-- ============================================================================
-- 20. 产品套装明细表（赠品套装系统）
-- ============================================================================
CREATE TABLE IF NOT EXISTS product_bundle_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bundle_id UUID NOT NULL REFERENCES product_bundles(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity INT NOT NULL DEFAULT 1,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 21. 仓库表
-- ============================================================================
CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  address TEXT,
  is_active BOOLEAN DEFAULT true,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 22. 库存表
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku_id UUID REFERENCES product_skus(id) ON DELETE SET NULL,
  quantity INT NOT NULL DEFAULT 0,
  min_stock INT DEFAULT 0,        -- 最低库存预警
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(warehouse_id, product_id)
);

-- ============================================================================
-- 23. 库存操作日志表
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id UUID NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  change_type TEXT NOT NULL CHECK (change_type IN ('in', 'out', 'adjust', 'transfer_in', 'transfer_out', 'ship_deduct', 'return_add')),
  quantity INT NOT NULL,
  note TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 24. 供应商表
-- ============================================================================
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  contact_person TEXT,
  contact_phone TEXT,
  address TEXT,
  bank_name TEXT,
  bank_account TEXT,
  note TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 25. 采购订单表
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no TEXT UNIQUE NOT NULL,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  supplier_name TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'completed', 'cancelled')),
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  deposit_amount DECIMAL(12,2) DEFAULT 0,
  deposit_paid DECIMAL(12,2) DEFAULT 0,
  contract_no TEXT,               -- 合同编号
  contract_note TEXT,             -- 合同备注
  expected_arrival_date DATE,     -- 预计到货日期
  actual_arrival_date DATE,       -- 实际到货日期
  balance_due_date DATE,          -- 尾款到期日
  note TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 26. 采购订单明细表
-- ============================================================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  category TEXT,
  quantity INT NOT NULL,
  unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
  received_quantity INT DEFAULT 0, -- 已收货数量
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 27. 客户表
-- ============================================================================
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL,
  name TEXT,
  address TEXT,
  tags TEXT[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'vip')),
  is_student BOOLEAN DEFAULT false,
  lesson_count INT DEFAULT 0,
  total_amount DECIMAL(12,2) DEFAULT 0,
  order_count INT DEFAULT 0,
  last_order_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(phone)
);

-- ============================================================================
-- 28. 客服号表
-- ============================================================================
CREATE TABLE IF NOT EXISTS service_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,       -- 客服号编号
  wechat_name TEXT,                -- 微信名
  verified_name TEXT,              -- 实名
  id_number TEXT,                  -- 身份证号
  bank_name TEXT,                  -- 银行名
  bank_card_number TEXT,           -- 银行卡号
  bank_phone TEXT,                 -- 银行预留手机
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'used')),
  sales_id UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- 分配给的销售
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 29. 股东垫资表
-- ============================================================================
CREATE TABLE IF NOT EXISTS shareholder_loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shareholder_name TEXT NOT NULL,   -- 股东姓名
  principal DECIMAL(12,2) NOT NULL, -- 本金
  interest_rate DECIMAL(5,2) DEFAULT 0, -- 年利率%
  interest_method TEXT DEFAULT 'simple' CHECK (interest_method IN ('simple', 'compound')),
  loan_date DATE NOT NULL,          -- 借款日期
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'repaid', 'partial')),
  note TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 30. 垫资还款记录表
-- ============================================================================
CREATE TABLE IF NOT EXISTS loan_repayments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES shareholder_loans(id) ON DELETE CASCADE,
  repayment_date DATE NOT NULL,
  principal_amount DECIMAL(12,2) NOT NULL DEFAULT 0,  -- 还本金
  interest_amount DECIMAL(12,2) NOT NULL DEFAULT 0,   -- 还利息
  total_amount DECIMAL(12,2) NOT NULL,                  -- 还款总额
  note TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- updated_at 自动更新触发器函数
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 自动创建 profile 触发器
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, name, role, status)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
          COALESCE(NEW.raw_user_meta_data->>'role', 'sales'), 'active');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 应用 updated_at 触发器到各表
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'profiles', 'accounts', 'sales_targets', 'platform_revenues',
    'system_settings', 'products', 'product_skus', 'warehouses',
    'inventory', 'suppliers', 'purchase_orders', 'customers',
    'service_numbers', 'shareholder_loans', 'expense_categories'
  ])
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON %I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()', t);
  END LOOP;
END $$;

-- 余额快照自动计算触发器
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

  SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
  FROM orders
  WHERE status IN ('completed', 'partially_refunded')
    AND created_at >= v_period || '-01'
    AND created_at < (v_period || '-01')::date + interval '1 month';

  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE status = 'paid'
    AND paid_at >= v_period || '-01'
    AND paid_at < (v_period || '-01')::date + interval '1 month';

  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds
  WHERE status = 'completed'
    AND completed_at >= v_period || '-01'
    AND completed_at < (v_period || '-01')::date + interval '1 month';

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

DROP TRIGGER IF EXISTS set_balance_metrics ON balance_snapshots;
CREATE TRIGGER set_balance_metrics BEFORE INSERT OR UPDATE ON balance_snapshots
  FOR EACH ROW EXECUTE FUNCTION calculate_closing_balance();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- 账户当前分配状态
CREATE OR REPLACE VIEW v_account_assignments AS
SELECT
  a.id AS account_id,
  a.code AS account_code,
  a.ip_code,
  a.platform,
  a.balance,
  ca.sales_id,
  p.name AS sales_name,
  ca.assigned_at,
  ca.status AS assignment_status
FROM accounts a
LEFT JOIN channel_assignments ca ON ca.account_id = a.id AND ca.status = 'active'
LEFT JOIN profiles p ON p.id = ca.sales_id
WHERE a.status = 'active';

-- 月度业绩汇总
CREATE OR REPLACE VIEW v_monthly_performance AS
SELECT
  DATE_TRUNC('month', o.created_at)::TEXT AS month,
  COALESCE(o.sales_id, o.creator_id) AS user_id,
  p.name AS user_name,
  p.role AS user_role,
  COUNT(o.id) AS total_orders,
  SUM(o.amount) AS total_amount,
  AVG(o.amount) AS avg_order_amount,
  COUNT(DISTINCT o.account_code) AS channels_used,
  SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END) AS completed_amount
FROM orders o
LEFT JOIN profiles p ON p.id = COALESCE(o.sales_id, o.creator_id)
WHERE o.status IN ('completed', 'partially_refunded')
GROUP BY 1, 2, 3, 4
HAVING SUM(o.amount) > 0
ORDER BY 1 DESC, 5 DESC;

-- 退款月度汇总
CREATE OR REPLACE VIEW v_monthly_refunds AS
SELECT
  DATE_TRUNC('month', r.created_at)::TEXT AS month,
  r.refund_to_account_id,
  a.code AS account_code,
  COUNT(r.id) AS refund_count,
  SUM(r.refund_amount) AS total_refunded
FROM refunds r
LEFT JOIN accounts a ON a.id = r.refund_to_account_id
WHERE r.status = 'completed'
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 5 DESC;

-- 电商销售日汇总视图
-- 从 orders 表按日、平台维度汇总电商订单数据
CREATE OR REPLACE VIEW v_ecommerce_daily AS
SELECT
  DATE(o.order_time) AS order_date,
  o.platform_type,
  o.platform_store,
  COUNT(o.id) AS order_count,
  SUM(o.quantity) AS total_quantity,
  SUM(o.payment_amount) AS total_payment,
  SUM(o.freight) AS total_freight,
  SUM(o.platform_fee) AS total_platform_fee,
  SUM(o.actual_income) AS total_actual_income,
  COUNT(DISTINCT o.external_order_no) AS unique_orders
FROM orders o
WHERE o.platform_type IS NOT NULL
  AND o.status NOT IN ('cancelled')
  AND o.deleted_at IS NULL
GROUP BY 1, 2, 3;

-- 库存汇总视图
CREATE OR REPLACE VIEW inventory_view AS
SELECT
  i.id,
  i.warehouse_id,
  w.name AS warehouse_name,
  i.product_id,
  p.name AS product_name,
  p.category,
  p.brand,
  p.unit,
  p.image,
  p.min_stock AS product_min_stock,
  i.quantity,
  i.min_stock,
  CASE
    WHEN i.quantity <= 0 THEN 'out_of_stock'
    WHEN i.quantity <= COALESCE(i.min_stock, p.min_stock, 0) THEN 'low_stock'
    ELSE 'normal'
  END AS stock_status
FROM inventory i
JOIN warehouses w ON w.id = i.warehouse_id
JOIN products p ON p.id = i.product_id;

-- 股东垫资汇总视图
CREATE OR REPLACE VIEW shareholder_loan_summary AS
SELECT
  sl.*,
  COALESCE(
    (SELECT SUM(lr.principal_amount) FROM loan_repayments lr WHERE lr.loan_id = sl.id),
    0
  ) AS repaid_principal,
  COALESCE(
    (SELECT SUM(lr.interest_amount) FROM loan_repayments lr WHERE lr.loan_id = sl.id),
    0
  ) AS repaid_interest,
  COALESCE(
    (SELECT SUM(lr.total_amount) FROM loan_repayments lr WHERE lr.loan_id = sl.id),
    0
  ) AS total_repaid
FROM shareholder_loans sl;

-- ============================================================================
-- RPC FUNCTIONS
-- ============================================================================

-- 原子更新账户余额
CREATE OR REPLACE FUNCTION increment_balance(acct_id UUID, delta DECIMAL)
RETURNS JSONB AS $$
DECLARE
  old_bal DECIMAL(12,2);
  new_bal DECIMAL(12,2);
BEGIN
  UPDATE accounts SET balance = balance + delta WHERE id = acct_id RETURNING balance INTO new_bal;
  old_bal := new_bal - delta;
  RETURN jsonb_build_object('old_balance', old_bal, 'new_balance', new_bal);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 通过 SKU 编码匹配产品（用于订单导入）
CREATE OR REPLACE FUNCTION match_product_by_sku_code(p_sku_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_sku RECORD;
  v_product RECORD;
BEGIN
  SELECT * INTO v_sku FROM product_skus WHERE sku_code = p_sku_code AND status = 'active' LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_null(); END IF;
  SELECT * INTO v_product FROM products WHERE id = v_sku.product_id LIMIT 1;
  RETURN jsonb_build_object(
    'sku_id', v_sku.id,
    'sku_code', v_sku.sku_code,
    'specs', v_sku.specs,
    'product_id', v_product.id,
    'product_name', v_product.name,
    'category', v_product.category,
    'brand', v_product.brand,
    'cost_price', v_product.cost_price,
    'retail_price', v_product.retail_price
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取待处理数量（pending orders + pending refunds + pending expenses）
CREATE OR REPLACE FUNCTION get_pending_count()
RETURNS JSONB AS $$
DECLARE
  v_orders INT;
  v_refunds INT;
  v_expenses INT;
BEGIN
  SELECT COUNT(*) INTO v_orders FROM orders WHERE status = 'pending' AND deleted_at IS NULL;
  SELECT COUNT(*) INTO v_refunds FROM refunds WHERE status = 'pending' AND deleted_at IS NULL;
  SELECT COUNT(*) INTO v_expenses FROM expenses WHERE status = 'pending';
  RETURN jsonb_build_object(
    'pending_orders', v_orders,
    'pending_refunds', v_refunds,
    'pending_expenses', v_expenses,
    'total', v_orders + v_refunds + v_expenses
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取客户统计信息
CREATE OR REPLACE FUNCTION get_customer_summary()
RETURNS JSONB AS $$
DECLARE
  v_total INT;
  v_new_month INT;
  v_active_30d INT;
  v_avg_amount DECIMAL;
BEGIN
  SELECT COUNT(*) INTO v_total FROM customers;
  SELECT COUNT(*) INTO v_new_month FROM customers WHERE created_at >= DATE_TRUNC('month', NOW());
  SELECT COUNT(*) INTO v_active_30d FROM customers WHERE last_order_at >= NOW() - INTERVAL '30 days';
  SELECT COALESCE(AVG(total_amount), 0) INTO v_avg_amount FROM customers;
  RETURN jsonb_build_object(
    'total_customers', v_total,
    'new_this_month', v_new_month,
    'active_30d', v_active_30d,
    'avg_amount', v_avg_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取客户列表（支持搜索和分页）
CREATE OR REPLACE FUNCTION get_customer_stats(
  p_search TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_tag TEXT DEFAULT NULL,
  p_limit INT DEFAULT 200,
  p_offset INT DEFAULT 0
)
RETURNS TABLE(
  id UUID, phone TEXT, name TEXT, address TEXT, tags TEXT[],
  status TEXT, is_student BOOLEAN, lesson_count INT,
  total_amount DECIMAL, order_count INT, last_order_at TIMESTAMPTZ,
  note TEXT, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT c.*
  FROM customers c
  WHERE (p_search IS NULL OR c.phone ILIKE '%' || p_search || '%' OR c.name ILIKE '%' || p_search || '%')
    AND (p_status IS NULL OR c.status = p_status)
    AND (p_tag IS NULL OR p_tag = ANY(c.tags))
  ORDER BY c.last_order_at DESC NULLS LAST, c.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 同步客户表（从订单数据）
CREATE OR REPLACE FUNCTION sync_customers_from_orders()
RETURNS VOID AS $$
BEGIN
  INSERT INTO customers (phone, name, total_amount, order_count, last_order_at, created_at, updated_at)
  SELECT
    o.customer_phone,
    o.customer_name,
    SUM(o.amount),
    COUNT(o.id),
    MAX(o.created_at),
    MIN(o.created_at),
    NOW()
  FROM orders o
  WHERE o.customer_phone IS NOT NULL
    AND o.customer_phone != ''
    AND o.deleted_at IS NULL
    AND o.status IN ('completed', 'partially_refunded')
    AND NOT EXISTS (SELECT 1 FROM customers c WHERE c.phone = o.customer_phone)
  GROUP BY o.customer_phone, o.customer_name
  ON CONFLICT (phone) DO UPDATE SET
    total_amount = EXCLUDED.total_amount,
    order_count = EXCLUDED.order_count,
    last_order_at = EXCLUDED.last_order_at,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取客服号列表
CREATE OR REPLACE FUNCTION get_service_numbers()
RETURNS TABLE(
  id UUID, code TEXT, wechat_name TEXT, verified_name TEXT,
  status TEXT, sales_id UUID, note TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT sn.id, sn.code, sn.wechat_name, sn.verified_name, sn.status, sn.sales_id, sn.note
  FROM service_numbers sn
  WHERE sn.status = 'active'
  ORDER BY sn.code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 批量创建客服号
CREATE OR REPLACE FUNCTION batch_create_service_numbers(
  p_prefix TEXT DEFAULT '南',
  p_start INT DEFAULT 1,
  p_count INT DEFAULT 100,
  p_sales_id UUID DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
  v_created INT := 0;
  v_code TEXT;
  v_i INT;
BEGIN
  FOR v_i IN p_start..(p_start + p_count - 1) LOOP
    v_code := p_prefix || LPAD(v_i::TEXT, 3, '0');
    INSERT INTO service_numbers (code, sales_id, note, status)
    VALUES (v_code, p_sales_id, p_note, 'active')
    ON CONFLICT (code) DO NOTHING;
    IF FOUND THEN v_created := v_created + 1; END IF;
  END LOOP;
  RETURN v_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 库存统计
CREATE OR REPLACE FUNCTION get_inventory_stats()
RETURNS JSONB AS $$
DECLARE
  v_total_stock INT;
  v_total_products INT;
  v_total_warehouses INT;
  v_low_stock INT;
BEGIN
  SELECT COALESCE(SUM(quantity), 0) INTO v_total_stock FROM inventory;
  SELECT COUNT(DISTINCT product_id) INTO v_total_products FROM inventory WHERE quantity > 0;
  SELECT COUNT(*) INTO v_total_warehouses FROM warehouses WHERE is_active = true;
  SELECT COUNT(*) INTO v_low_stock FROM inventory_view WHERE stock_status = 'low_stock';
  RETURN jsonb_build_object(
    'total_stock', v_total_stock,
    'total_products', v_total_products,
    'total_warehouses', v_total_warehouses,
    'low_stock', v_low_stock
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 库存调整
CREATE OR REPLACE FUNCTION adjust_inventory(
  p_warehouse_id UUID,
  p_product_id UUID,
  p_quantity INT,
  p_change_type TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_new_qty INT;
BEGIN
  INSERT INTO inventory (warehouse_id, product_id, quantity)
  VALUES (p_warehouse_id, p_product_id, 0)
  ON CONFLICT (warehouse_id, product_id) DO NOTHING;

  UPDATE inventory SET quantity =
    CASE
      WHEN p_change_type IN ('in', 'transfer_in', 'return_add') THEN quantity + p_quantity
      WHEN p_change_type IN ('out', 'transfer_out', 'ship_deduct') THEN quantity - p_quantity
      WHEN p_change_type = 'adjust' THEN p_quantity
    END
  WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id
  RETURNING quantity INTO v_new_qty;

  INSERT INTO inventory_logs (warehouse_id, product_id, change_type, quantity, note)
  VALUES (p_warehouse_id, p_product_id, p_change_type, p_quantity, p_note);

  RETURN jsonb_build_object('new_quantity', v_new_qty);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 仓库间库存调拨
CREATE OR REPLACE FUNCTION transfer_stock(
  p_from_wh UUID,
  p_to_wh UUID,
  p_product_id UUID,
  p_quantity INT,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_from_qty INT;
  v_to_result JSONB;
BEGIN
  SELECT quantity INTO v_from_qty FROM inventory
    WHERE warehouse_id = p_from_wh AND product_id = p_product_id;
  IF v_from_qty < p_quantity THEN
    RAISE EXCEPTION '库存不足：当前 %，需要 %', v_from_qty, p_quantity;
  END IF;

  PERFORM adjust_inventory(p_from_wh, p_product_id, p_quantity, 'transfer_out', p_note || ' [调出]');
  v_to_result := adjust_inventory(p_to_wh, p_product_id, p_quantity, 'transfer_in', p_note || ' [调入]');
  RETURN v_to_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 发货扣库存
CREATE OR REPLACE FUNCTION ship_deduct_inventory(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_product_id UUID;
  v_qty INT;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN RAISE EXCEPTION '订单不存在'; END IF;

  -- 尝试通过 SKU 匹配产品
  IF v_order.sku_code IS NOT NULL THEN
    SELECT product_id INTO v_product_id FROM product_skus WHERE sku_code = v_order.sku_code LIMIT 1;
  END IF;

  -- 尝试通过产品名匹配
  IF v_product_id IS NULL THEN
    SELECT id INTO v_product_id FROM products WHERE name ILIKE '%' || v_order.product_name || '%' LIMIT 1;
  END IF;

  IF v_product_id IS NULL THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', '未匹配到产品');
  END IF;

  v_qty := COALESCE(v_order.quantity, 1);
  RETURN adjust_inventory(NULL, v_product_id, v_qty, 'ship_deduct',
    '发货扣减，订单 ' || COALESCE(v_order.order_no, v_order.external_order_no, p_order_id::TEXT));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 退款入库
CREATE OR REPLACE FUNCTION return_add_inventory(
  p_refund_id UUID,
  p_product_id UUID,
  p_quantity INT DEFAULT 1
)
RETURNS JSONB AS $$
BEGIN
  RETURN adjust_inventory(NULL, p_product_id, p_quantity, 'return_add',
    '退款入库，退款单 ' || p_refund_id::TEXT);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 生成采购订单编号
CREATE OR REPLACE FUNCTION generate_po_no()
RETURNS TEXT AS $$
BEGIN
  RETURN 'PO' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || lpad(floor(random()*10000)::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- 获取采购订单列表
CREATE OR REPLACE FUNCTION get_purchase_orders(
  p_status TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_limit INT DEFAULT 200
)
RETURNS TABLE(
  id UUID, order_no TEXT, supplier_id UUID, supplier_name TEXT,
  status TEXT, total_amount DECIMAL, deposit_amount DECIMAL, deposit_paid DECIMAL,
  contract_no TEXT, expected_arrival_date DATE, actual_arrival_date DATE,
  balance_due_date DATE, note TEXT, created_at TIMESTAMPTZ,
  created_by UUID, items JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    po.id, po.order_no, po.supplier_id, po.supplier_name,
    po.status, po.total_amount, po.deposit_amount, po.deposit_paid,
    po.contract_no, po.expected_arrival_date, po.actual_arrival_date,
    po.balance_due_date, po.note, po.created_at,
    po.created_by,
    COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
        'id', poi.id,
        'product_name', poi.product_name,
        'category', poi.category,
        'quantity', poi.quantity,
        'unit_cost', poi.unit_cost,
        'received_quantity', poi.received_quantity
      ))
      FROM purchase_order_items poi WHERE poi.purchase_order_id = po.id),
      '[]'::JSONB
    ) AS items
  FROM purchase_orders po
  WHERE (p_status IS NULL OR po.status = p_status)
    AND (p_search IS NULL OR po.order_no ILIKE '%' || p_search || '%'
         OR po.supplier_name ILIKE '%' || p_search || '%')
  ORDER BY po.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取采购订单详情
CREATE OR REPLACE FUNCTION get_purchase_order_detail(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_items JSONB;
BEGIN
  SELECT * INTO v_order FROM purchase_orders WHERE id = p_po_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', poi.id,
    'product_id', poi.product_id,
    'product_name', poi.product_name,
    'category', poi.category,
    'quantity', poi.quantity,
    'unit_cost', poi.unit_cost,
    'received_quantity', poi.received_quantity
  )), '[]'::JSONB) INTO v_items
  FROM purchase_order_items poi WHERE poi.purchase_order_id = p_po_id;

  RETURN jsonb_build_object(
    'id', v_order.id,
    'order_no', v_order.order_no,
    'supplier_id', v_order.supplier_id,
    'supplier_name', v_order.supplier_name,
    'status', v_order.status,
    'total_amount', v_order.total_amount,
    'deposit_amount', v_order.deposit_amount,
    'deposit_paid', v_order.deposit_paid,
    'contract_no', v_order.contract_no,
    'contract_note', v_order.contract_note,
    'expected_arrival_date', v_order.expected_arrival_date,
    'actual_arrival_date', v_order.actual_arrival_date,
    'balance_due_date', v_order.balance_due_date,
    'note', v_order.note,
    'created_at', v_order.created_at,
    'items', v_items
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取产品消耗统计（用于采购预测）
CREATE OR REPLACE FUNCTION get_product_consumption()
RETURNS TABLE(
  product_id UUID, product_name TEXT, category TEXT,
  total_consumed INT, days INT, daily_avg NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS product_id,
    p.name AS product_name,
    p.category,
    COALESCE(SUM(o.quantity), 0) AS total_consumed,
    GREATEST(1, EXTRACT(DAY FROM NOW() - MIN(o.created_at))::INT) AS days,
    ROUND(COALESCE(SUM(o.quantity), 0)::NUMERIC / GREATEST(1, EXTRACT(DAY FROM NOW() - MIN(o.created_at))::INT), 2) AS daily_avg
  FROM products p
  LEFT JOIN orders o ON o.product_name ILIKE '%' || p.name || '%'
    AND o.status IN ('completed', 'partially_refunded')
    AND o.deleted_at IS NULL
    AND o.created_at >= NOW() - INTERVAL '90 days'
  WHERE p.status = 'active'
  GROUP BY p.id, p.name, p.category
  ORDER BY total_consumed DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 每月自动生成余额快照
CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS VOID AS $$
DECLARE
  v_period TEXT := to_char(NOW(), 'YYYY-MM');
  v_prev TEXT := to_char((v_period || '-01')::date - interval '1 month', 'YYYY-MM');
BEGIN
  INSERT INTO balance_snapshots (account_id, period, opening_balance)
  SELECT
    a.id,
    v_period,
    COALESCE(
      (SELECT closing_balance FROM balance_snapshots WHERE account_id = a.id AND period = v_prev),
      a.balance
    )
  FROM accounts a
  WHERE a.status = 'active'
  ON CONFLICT (account_id, period) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 获取产品套装（含赠品）
CREATE OR REPLACE FUNCTION get_product_bundle(p_product_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_bundle RECORD;
  v_items JSONB;
BEGIN
  SELECT * INTO v_bundle FROM product_bundles WHERE main_product_id = p_product_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', pbi.id,
    'product_id', pbi.product_id,
    'product_name', p.name,
    'category', p.category,
    'brand', p.brand,
    'cost_price', p.cost_price,
    'retail_price', p.retail_price,
    'unit', p.unit,
    'quantity', pbi.quantity
  )), '[]'::JSONB) INTO v_items
  FROM product_bundle_items pbi
  JOIN products p ON p.id = pbi.product_id
  WHERE pbi.bundle_id = v_bundle.id;

  RETURN jsonb_build_object(
    'bundle_id', v_bundle.id,
    'name', v_bundle.name,
    'items', v_items
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 软删除订单
CREATE OR REPLACE FUNCTION delete_order(p_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE orders SET deleted_at = NOW() WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 退款时自动扣回余额
CREATE OR REPLACE FUNCTION refund_order_balance(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_old_bal DECIMAL(12,2);
  v_new_bal DECIMAL(12,2);
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'reason', '订单不存在'); END IF;
  IF v_order.account_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'reason', '无关联账户'); END IF;

  UPDATE accounts SET balance = balance - v_order.amount
  WHERE id = v_order.account_id
  RETURNING balance INTO v_new_bal;
  v_old_bal := v_new_bal + v_order.amount;

  RETURN jsonb_build_object('ok', true, 'old_balance', v_old_bal, 'new_balance', v_new_bal);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 计算股东垫资利息
CREATE OR REPLACE FUNCTION calculate_loan_interest(
  p_loan_id UUID,
  p_as_of_date DATE DEFAULT NULL
)
RETURNS DECIMAL AS $$
DECLARE
  v_loan RECORD;
  v_repaid_principal DECIMAL(12,2);
  v_days INT;
  v_interest DECIMAL(12,2);
BEGIN
  SELECT * INTO v_loan FROM shareholder_loans WHERE id = p_loan_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  SELECT COALESCE(SUM(principal_amount), 0) INTO v_repaid_principal
  FROM loan_repayments WHERE loan_id = p_loan_id;

  v_days := GREATEST(0, (COALESCE(p_as_of_date, CURRENT_DATE) - v_loan.loan_date));
  v_interest := (v_loan.principal - v_repaid_principal) * v_loan.interest_rate / 100 / 365 * v_days;
  RETURN ROUND(v_interest, 2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
