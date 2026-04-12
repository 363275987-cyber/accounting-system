-- 台球公司账目管理系统 - 安全版 SQL（可在现有 Supabase 项目上执行）
-- 不会破坏已有的台球训练记录数据
-- 在 Supabase SQL Editor 中执行
-- 更新日期：2026-03-28

-- ============================
-- 1. profiles 表兼容处理
-- ============================
-- 如果 profiles 表已存在，只添加缺失的列；如果不存在，创建新表
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles' AND table_schema = 'public') THEN
    -- 表已存在，添加缺失的列（IF NOT EXISTS 风格）
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
      ALTER TABLE profiles ADD COLUMN role TEXT NOT NULL DEFAULT 'sales' CHECK (role IN ('sales', 'cs', 'finance', 'manager', 'admin', 'hr', 'coach'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'ip_code') THEN
      ALTER TABLE profiles ADD COLUMN ip_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'department') THEN
      ALTER TABLE profiles ADD COLUMN department TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'phone') THEN
      ALTER TABLE profiles ADD COLUMN phone TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'status') THEN
      ALTER TABLE profiles ADD COLUMN status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'updated_at') THEN
      ALTER TABLE profiles ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
    RAISE NOTICE 'profiles 表已存在，已添加缺失列';
  ELSE
    -- 表不存在，创建新表
    CREATE TABLE profiles (
      id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'sales' CHECK (role IN ('sales', 'cs', 'finance', 'manager', 'admin', 'hr', 'coach')),
      ip_code TEXT,
      department TEXT,
      phone TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );
    RAISE NOTICE 'profiles 表已创建';
  END IF;
END $$;

-- 确保有 created_at 列
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'created_at') THEN
    ALTER TABLE profiles ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
  END IF;
END $$;

-- RLS 策略（用 DO 块避免重复创建报错）
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "acct_users_read_own" ON profiles FOR SELECT USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_finance_admin_read_all" ON profiles FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_users_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_admin_manage_all" ON profiles FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 自动创建 profile 触发器（使用独立函数名避免冲突）
CREATE OR REPLACE FUNCTION acct_handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- 只在 profiles 表没有该用户时插入
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    INSERT INTO profiles (id, name, role, status)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
            COALESCE(NEW.raw_user_meta_data->>'role', 'sales'), 'active');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS acct_on_auth_user_created ON auth.users;
CREATE TRIGGER acct_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION acct_handle_new_user();

-- ============================
-- 2. 收款账户表
-- ============================
CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  ip_code TEXT NOT NULL,
  sequence INT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('wechat', 'alipay', 'bank', 'taobao', 'douyin', 'kuaishou', 'cash', 'other')),
  bank_name TEXT,
  account_no TEXT,
  account_holder TEXT,
  owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  balance DECIMAL(12,2) DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "acct_finance_admin_accounts" ON accounts FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_sales_read_accounts" ON accounts FOR SELECT USING (status = 'active');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 3. 渠道分配表
-- ============================
CREATE TABLE IF NOT EXISTS channel_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  sales_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'released')),
  note TEXT
);

ALTER TABLE channel_assignments ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "acct_ca_full" ON channel_assignments FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_ca_read_own" ON channel_assignments FOR SELECT USING (
    sales_id = auth.uid() OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_ca_account ON channel_assignments(account_id);
CREATE INDEX IF NOT EXISTS idx_ca_sales ON channel_assignments(sales_id);
CREATE INDEX IF NOT EXISTS idx_ca_status ON channel_assignments(status);

-- ============================
-- 4. 订单表
-- ============================
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no TEXT UNIQUE NOT NULL DEFAULT 'ORD' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || lpad(floor(random()*100000)::TEXT, 5, '0'),
  account_id UUID REFERENCES accounts(id),
  account_code TEXT NOT NULL,
  creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  sales_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
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
DO $$ BEGIN
  CREATE POLICY "acct_orders_read_own" ON orders FOR SELECT USING (
    creator_id = auth.uid() OR sales_id = auth.uid() OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_orders_create" ON orders FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('sales', 'cs', 'finance', 'admin'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_orders_update" ON orders FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
    OR creator_id = auth.uid()
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_orders_delete" ON orders FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_orders_account ON orders(account_id);
CREATE INDEX IF NOT EXISTS idx_orders_account_code ON orders(account_code);
CREATE INDEX IF NOT EXISTS idx_orders_creator ON orders(creator_id);
CREATE INDEX IF NOT EXISTS idx_orders_sales ON orders(sales_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_category ON orders(product_category);

-- ============================
-- 5. 支出表
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
DO $$ BEGIN
  CREATE POLICY "acct_expenses_full" ON expenses FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_expenses_create" ON expenses FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 6. 账户转账表
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
DO $$ BEGIN
  CREATE POLICY "acct_transfers_full" ON account_transfers FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 7. 平台收入表
-- ============================
CREATE TABLE IF NOT EXISTS platform_revenues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL CHECK (platform IN ('douyin', 'kuaishou', 'wechat_video', 'taobao', 'other')),
  period TEXT NOT NULL,
  total_revenue DECIMAL(12,2) NOT NULL DEFAULT 0,
  settled_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  pending_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  fee_rate DECIMAL(5,2) DEFAULT 0,
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
DO $$ BEGIN
  CREATE POLICY "acct_platforms_full" ON platform_revenues FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

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
DO $$ BEGIN
  CREATE POLICY "acct_targets_read" ON sales_targets FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_targets_manage" ON sales_targets FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 9. 系统设置表
-- ============================
CREATE TABLE IF NOT EXISTS system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "acct_settings_admin" ON system_settings FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_settings_read" ON system_settings FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

INSERT INTO system_settings (key, value) VALUES
  ('approval_threshold', '2000'),
  ('platform_fee_rates', '{"douyin": 5, "kuaishou": 5, "wechat_video": 5, "taobao": 3}'),
  ('default_currency', '"CNY"')
ON CONFLICT (key) DO NOTHING;

-- ============================
-- 10. 操作日志表
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
DO $$ BEGIN
  CREATE POLICY "acct_logs_read" ON audit_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_logs_insert" ON audit_logs FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 11. 退款记录表
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
DO $$ BEGIN
  CREATE POLICY "acct_refunds_full" ON refunds FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_refunds_read_own" ON refunds FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders o WHERE o.id = refunds.order_id
      AND (o.creator_id = auth.uid() OR o.sales_id = auth.uid())
    ) OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_refunds_order ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_date ON refunds(created_at DESC);

-- ============================
-- 12. 余额快照表
-- ============================
CREATE TABLE IF NOT EXISTS balance_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  period TEXT NOT NULL,
  opening_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_income DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_expense DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_refund DECIMAL(12,2) NOT NULL DEFAULT 0,
  transfer_in DECIMAL(12,2) NOT NULL DEFAULT 0,
  transfer_out DECIMAL(12,2) NOT NULL DEFAULT 0,
  transfer_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
  closing_balance DECIMAL(12,2) NOT NULL DEFAULT 0,
  admin_adjustment DECIMAL(12,2) NOT NULL DEFAULT 0,
  admin_reason TEXT,
  confirmed_by UUID REFERENCES profiles(id),
  confirmed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'confirmed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(account_id, period)
);

ALTER TABLE balance_snapshots ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "acct_snapshots_full" ON balance_snapshots FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "acct_snapshots_read" ON balance_snapshots FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('finance', 'admin', 'manager'))
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 13. updated_at 自动更新
-- ============================
CREATE OR REPLACE FUNCTION acct_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON sales_targets FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON platform_revenues FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER set_updated_at BEFORE UPDATE ON balance_snapshots FOR EACH ROW EXECUTE FUNCTION acct_update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================
-- 14. 余额自动计算函数
-- ============================
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
  FROM orders WHERE status IN ('completed', 'partially_refunded')
    AND created_at >= v_period || '-01' AND created_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_expense
  FROM expenses WHERE status = 'paid'
    AND paid_at >= v_period || '-01' AND paid_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
  FROM refunds WHERE status = 'completed'
    AND completed_at >= v_period || '-01' AND completed_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in FROM account_transfers
    WHERE status = 'completed' AND to_account_id = NEW.account_id
    AND created_at >= v_period || '-01' AND created_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(amount), 0) INTO v_transfer_out FROM account_transfers
    WHERE status = 'completed' AND from_account_id = NEW.account_id
    AND created_at >= v_period || '-01' AND created_at < (v_period || '-01')::date + interval '1 month';
  SELECT COALESCE(SUM(fee), 0) INTO v_fee FROM account_transfers
    WHERE status = 'completed' AND from_account_id = NEW.account_id
    AND created_at >= v_period || '-01' AND created_at < (v_period || '-01')::date + interval '1 month';
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

DO $$ BEGIN
  CREATE TRIGGER set_balance_metrics BEFORE INSERT OR UPDATE ON balance_snapshots
    FOR EACH ROW EXECUTE FUNCTION calculate_closing_balance();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 每月自动生成快照
CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS VOID AS $$
DECLARE
  v_period TEXT := to_char(NOW(), 'YYYY-MM');
  v_prev TEXT := to_char((v_period || '-01')::date - interval '1 month', 'YYYY-MM');
BEGIN
  INSERT INTO balance_snapshots (account_id, period, opening_balance)
  SELECT a.id, v_period,
    COALESCE((SELECT closing_balance FROM balance_snapshots WHERE account_id = a.id AND period = v_prev), a.balance)
  FROM accounts a WHERE a.status = 'active'
  ON CONFLICT (account_id, period) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================
-- 15. 视图
-- ============================
CREATE OR REPLACE VIEW v_account_assignments AS
SELECT a.id AS account_id, a.code AS account_code, a.ip_code, a.platform, a.balance,
  ca.sales_id, p.name AS sales_name, ca.assigned_at, ca.status AS assignment_status
FROM accounts a
LEFT JOIN channel_assignments ca ON ca.account_id = a.id AND ca.status = 'active'
LEFT JOIN profiles p ON p.id = ca.sales_id
WHERE a.status = 'active';

CREATE OR REPLACE VIEW v_monthly_performance AS
SELECT DATE_TRUNC('month', o.created_at)::TEXT AS month,
  COALESCE(o.sales_id, o.creator_id) AS user_id, p.name AS user_name, p.role AS user_role,
  COUNT(o.id) AS total_orders, SUM(o.amount) AS total_amount,
  AVG(o.amount) AS avg_order_amount, COUNT(DISTINCT o.account_code) AS channels_used,
  SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END) AS completed_amount
FROM orders o LEFT JOIN profiles p ON p.id = COALESCE(o.sales_id, o.creator_id)
WHERE o.status IN ('completed', 'partially_refunded')
GROUP BY 1, 2, 3, 4 HAVING SUM(o.amount) > 0
ORDER BY 1 DESC, 5 DESC;

-- ============================
-- 16. 创建测试管理员账号
-- ============================
-- 密码：Admin@123456（请登录后立即修改）
INSERT INTO auth.users (instance_id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  'admin@billiards.com',
  crypt('Admin@123456', gen_salt('bf')),
  NOW(),
  '{"name": "系统管理员", "role": "admin"}'::jsonb,
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
)
ON CONFLICT DO NOTHING;

-- 确保 profiles 表中有管理员记录
INSERT INTO profiles (id, name, role, status)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'admin@billiards.com' LIMIT 1),
  '系统管理员', 'admin', 'active'
)
ON CONFLICT (id) DO UPDATE SET role = 'admin', name = '系统管理员', status = 'active';

-- 创建测试财务账号（密码同上）
INSERT INTO auth.users (instance_id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'finance@billiards.com',
  crypt('Admin@123456', gen_salt('bf')),
  NOW(),
  '{"name": "财务测试", "role": "finance"}'::jsonb,
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
)
ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, name, role, status)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'finance@billiards.com' LIMIT 1),
  '财务测试', 'finance', 'active'
)
ON CONFLICT (id) DO UPDATE SET role = 'finance', name = '财务测试', status = 'active';

-- 创建测试销售账号
INSERT INTO auth.users (instance_id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000002',
  'sales@billiards.com',
  crypt('Admin@123456', gen_salt('bf')),
  NOW(),
  '{"name": "销售测试", "role": "sales"}'::jsonb,
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
)
ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, name, role, status)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'sales@billiards.com' LIMIT 1),
  '销售测试', 'sales', 'active'
)
ON CONFLICT (id) DO UPDATE SET role = 'sales', name = '销售测试', status = 'active';
