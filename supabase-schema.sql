-- 台球公司账目管理系统 - 数据库初始化脚本 v2
-- 在 Supabase SQL Editor 中执行
-- 更新日期：2026-03-27

-- ============================
-- 0. 清理旧表（如果需要重建）
-- ============================
-- DROP TABLE IF EXISTS audit_logs CASCADE;
-- DROP TABLE IF EXISTS sales_targets CASCADE;
-- DROP TABLE IF EXISTS platform_revenues CASCADE;
-- DROP TABLE IF EXISTS expenses CASCADE;
-- DROP TABLE IF EXISTS orders CASCADE;
-- DROP TABLE IF EXISTS channel_assignments CASCADE;
-- DROP TABLE IF EXISTS accounts CASCADE;
-- DROP TABLE IF EXISTS profiles CASCADE;

-- ============================
-- 1. 用户资料表
-- ============================
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

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Finance and admin can read all profiles" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admin can manage all profiles" ON profiles FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- 自动创建 profile
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

-- ============================
-- 2. 收款账户表
-- ============================
CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,       -- 账户标识，如"楠一微信"
  ip_code TEXT NOT NULL,           -- IP简称
  sequence INT NOT NULL,           -- 序号
  platform TEXT NOT NULL CHECK (platform IN ('wechat', 'alipay', 'bank', 'taobao', 'douyin', 'kuaishou', 'cash', 'other')),
  bank_name TEXT,                  -- 银行名称（银行卡类）
  account_no TEXT,                 -- 银行账号/公户号
  account_holder TEXT,             -- 户名/主体名
  owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- 负责人（客服/销售）
  balance DECIMAL(12,2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON accounts FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
);
CREATE POLICY "Sales read active accounts" ON accounts FOR SELECT USING (
  status = 'active'
);

-- ============================
-- 3. 渠道分配表（新增）
-- ============================
-- 销售与客服号的分配关系（客服号会定期重新分配）
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

ALTER TABLE channel_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON channel_assignments FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Sales read own assignments" ON channel_assignments FOR SELECT USING (
  sales_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

-- 渠道分配历史索引
CREATE INDEX idx_ca_account ON channel_assignments(account_id);
CREATE INDEX idx_ca_sales ON channel_assignments(sales_id);
CREATE INDEX idx_ca_status ON channel_assignments(status);

-- ============================
-- 4. 订单表（更新）
-- ============================
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales read own orders" ON orders FOR SELECT USING (
  creator_id = auth.uid() OR sales_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Sales create orders" ON orders FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sales', 'cs', 'finance', 'admin'))
);
CREATE POLICY "Finance update orders" ON orders FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
  OR creator_id = auth.uid()
);
CREATE POLICY "Finance delete orders" ON orders FOR DELETE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE INDEX idx_orders_account ON orders(account_id);
CREATE INDEX idx_orders_account_code ON orders(account_code);
CREATE INDEX idx_orders_creator ON orders(creator_id);
CREATE INDEX idx_orders_sales ON orders(sales_id);
CREATE INDEX idx_orders_date ON orders(created_at DESC);
CREATE INDEX idx_orders_category ON orders(product_category);

-- ============================
-- 5. 支出表（更新）
-- ============================
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

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON expenses FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Finance create" ON expenses FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

-- ============================
-- 6. 账户转账表（新增）
-- ============================
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

ALTER TABLE account_transfers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON account_transfers FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
);

-- ============================
-- 7. 平台收入表
-- ============================
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

ALTER TABLE platform_revenues ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin access" ON platform_revenues FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

-- ============================
-- 8. 销售目标表
-- ============================
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

ALTER TABLE sales_targets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own targets" ON sales_targets FOR SELECT USING (
  user_id = auth.uid() OR
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Admin manage targets" ON sales_targets FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
);

-- ============================
-- 9. 系统设置表（新增）
-- ============================
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admin full access" ON system_settings FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Finance read settings" ON system_settings FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

-- 默认设置
INSERT INTO system_settings (key, value) VALUES
  ('approval_threshold', '2000'),
  ('platform_fee_rates', '{"douyin": 5, "kuaishou": 5, "wechat_video": 5, "taobao": 3}'),
  ('default_currency', '"CNY"')
ON CONFLICT (key) DO NOTHING;

-- ============================
-- 10. 操作日志表（审计）
-- ============================
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

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin read logs" ON audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
);
CREATE POLICY "System insert logs" ON audit_logs FOR INSERT WITH CHECK (true);

-- ============================
-- 11. updated_at 自动更新触发器
-- ============================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON profiles;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON accounts;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON sales_targets;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON sales_targets FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON platform_revenues;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON platform_revenues FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS set_updated_at ON system_settings;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================
-- 12. 有用的视图
-- ============================
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
  COUNT(DISTINCT o.account_code) AS channels_used
FROM orders o
LEFT JOIN profiles p ON p.id = COALESCE(o.sales_id, o.creator_id)
WHERE o.status = 'completed'
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC, 5 DESC;

-- ============================
-- 13. 退款记录表（V2）
-- ============================
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
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON refunds FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);
CREATE POLICY "Sales read own refunds" ON refunds FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM orders o WHERE o.id = refunds.order_id 
    AND (o.creator_id = auth.uid() OR o.sales_id = auth.uid())
  ) OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

CREATE INDEX idx_refunds_order ON refunds(order_id);
CREATE INDEX idx_refunds_status ON refunds(status);
CREATE INDEX idx_refunds_date ON refunds(created_at DESC);

-- 更新月度业绩视图，排除退款订单
DROP VIEW IF EXISTS v_monthly_performance;
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

-- ============================
-- 14. 账户余额快照表（V2）
-- ============================
-- 每月自动记录各账户期初余额，用于自动计算
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
  closing_balance DECIMAL(12,2) NOT NULL DEFAULT 0,    -- 期末余额 = 开 + 收 - 支 - 退 + 转入 - 转出 - 费
  admin_adjustment DECIMAL(12,2) NOT NULL DEFAULT 0, -- admin手动调整
  admin_reason TEXT,                          -- 调整原因
  confirmed_by UUID REFERENCES profiles(id),
  confirmed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'confirmed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(account_id, period)
);

ALTER TABLE balance_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Finance and admin full access" ON balance_snapshots FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
);
CREATE POLICY "Manager read snapshots" ON balance_snapshots FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
);

-- 每月自动计算余额的函数
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
  -- 从 NEW 记录中获取 period
  v_period := NEW.period;
  
  -- 计算本月收入（已完成的订单，排除完全退款）
  SELECT COALESCE(SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END), 0) INTO v_income
  FROM orders
  WHERE status IN ('completed', 'partially_refunded')
    AND created_at >= v_period || '-01'
    AND created_at < (v_period || '-01')::date + interval '1 month';
  
  -- 计算本月支出（已付款）
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses
  WHERE status = 'paid'
    AND paid_at >= v_period || '-01'
    AND paid_at < (v_period || '-01')::date + interval '1 month';
  
  -- 计算本月退款
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds
  WHERE status = 'completed'
    AND completed_at >= v_period || '-01'
    AND completed_at < (v_period || '-01')::date + interval '1 month';
  
  -- 计算本月转入/转出
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
  
  -- 计算期末余额
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

CREATE TRIGGER set_balance_metrics BEFORE INSERT OR UPDATE ON balance_snapshots
  FOR EACH ROW EXECUTE FUNCTION calculate_closing_balance();

-- 每月1号自动创建快照的函数（通过 cron 调用）
CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS VOID AS $$
DECLARE
  v_period TEXT := to_char(NOW(), 'YYYY-MM');
  v_prev TEXT := to_char((v_period || '-01')::date - interval '1 month', 'YYYY-MM');
BEGIN
  -- 为每个活跃账户创建本月快照
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

-- 更新 v_monthly_performance 视图，加入退款扣除
DROP VIEW IF EXISTS v_monthly_performance;
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
