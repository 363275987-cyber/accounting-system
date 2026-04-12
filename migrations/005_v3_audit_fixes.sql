-- ============================================================
-- V3 审计修复补丁 — 2024-04
-- 包含：缺失表、约束、审计日志、软删除统一、RPC 函数补齐
-- ============================================================

-- ============================================================
-- 1. 缺失的表
-- ============================================================

-- 提成规则配置
CREATE TABLE IF NOT EXISTS commission_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  rule_type TEXT NOT NULL DEFAULT 'percentage',  -- percentage / fixed / tiered
  base_rate NUMERIC(5,4) DEFAULT 0,              -- 基础比例 (0-1)
  min_amount NUMERIC(14,2) DEFAULT 0,
  max_amount NUMERIC(14,2),
  product_category TEXT,                          -- 适用产品类别（NULL=全部）
  conditions JSONB DEFAULT '{}',                  -- 附加条件
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 提成记录
CREATE TABLE IF NOT EXISTS commission_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  sales_id UUID REFERENCES profiles(id),
  rule_id UUID REFERENCES commission_rules(id),
  order_amount NUMERIC(14,2) NOT NULL,
  commission_amount NUMERIC(14,2) NOT NULL,
  commission_rate NUMERIC(5,4),
  status TEXT NOT NULL DEFAULT 'pending',         -- pending / approved / paid / rejected
  period TEXT,                                     -- 结算周期 e.g. '2024-04'
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 销售分组
CREATE TABLE IF NOT EXISTS sales_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  leader_id UUID REFERENCES profiles(id),
  members UUID[] DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 审计日志
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,                    -- insert / update / delete
  table_name TEXT NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  performed_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 2. 数据库约束
-- ============================================================

-- 金额必须为正数
DO $$ BEGIN
  ALTER TABLE orders ADD CONSTRAINT chk_orders_amount_positive CHECK (amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE expenses ADD CONSTRAINT chk_expenses_amount_positive CHECK (amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE refunds ADD CONSTRAINT chk_refunds_amount_positive CHECK (refund_amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE account_transfers ADD CONSTRAINT chk_transfers_amount_positive CHECK (amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 转账不能转给自己
DO $$ BEGIN
  ALTER TABLE account_transfers ADD CONSTRAINT chk_transfers_no_self CHECK (from_account_id != to_account_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 提成比例 0-1
DO $$ BEGIN
  ALTER TABLE commission_rules ADD CONSTRAINT chk_commission_rate_range CHECK (base_rate >= 0 AND base_rate <= 1);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 订单号唯一（允许 NULL）
DO $$ BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_order_no_unique ON orders(order_no) WHERE order_no IS NOT NULL;
EXCEPTION WHEN duplicate_table THEN NULL; END $$;

-- 状态枚举约束
DO $$ BEGIN
  ALTER TABLE orders ADD CONSTRAINT chk_orders_status CHECK (status IN ('pending', 'completed', 'cancelled', 'partially_refunded', 'refunded'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE expenses ADD CONSTRAINT chk_expenses_status CHECK (status IN ('pending', 'approved', 'rejected', 'paid', 'cancelled'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE refunds ADD CONSTRAINT chk_refunds_status CHECK (status IN ('pending', 'processing', 'completed', 'rejected', 'cancelled'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ============================================================
-- 3. 统一软删除：给缺少 deleted_at 的表加上
-- ============================================================

ALTER TABLE refunds ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE commission_records ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 补缺失字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_no TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(14,2) DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS invoice_no TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(14,2) DEFAULT 0;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE refunds ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE refunds ADD COLUMN IF NOT EXISTS refund_method TEXT DEFAULT 'original';


-- ============================================================
-- 4. 审计日志触发器
-- ============================================================

CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  IF TG_OP = 'DELETE' THEN
    INSERT INTO audit_logs (action, table_name, record_id, old_data, performed_by)
    VALUES ('delete', TG_TABLE_NAME, OLD.id, to_jsonb(OLD), v_user_id);
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD IS DISTINCT FROM NEW THEN
      INSERT INTO audit_logs (action, table_name, record_id, old_data, new_data, performed_by)
      VALUES ('update', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW), v_user_id);
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs (action, table_name, record_id, new_data, performed_by)
    VALUES ('insert', TG_TABLE_NAME, NEW.id, to_jsonb(NEW), v_user_id);
    RETURN NEW;
  END IF;
END;
$$;

-- 给关键财务表挂审计触发器
DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'orders', 'expenses', 'refunds', 'accounts', 'account_transfers',
    'commission_records'
  ])
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_%s ON %I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit_%s AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_trigger_func()',
      t, t
    );
  END LOOP;
END;
$$;


-- ============================================================
-- 5. updated_at 自动更新触发器
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'orders', 'expenses', 'refunds', 'accounts', 'account_transfers',
    'commission_rules', 'commission_records', 'sales_groups',
    'products'
  ])
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_updated_at_%s ON %I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_updated_at_%s BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION update_updated_at()',
      t, t
    );
  END LOOP;
END;
$$;


-- ============================================================
-- 6. 退款累计金额校验触发器（数据库级兜底）
-- ============================================================

CREATE OR REPLACE FUNCTION check_refund_amount_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_amount NUMERIC;
  v_total_refunded NUMERIC;
BEGIN
  SELECT amount INTO v_order_amount FROM orders WHERE id = NEW.order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '关联订单不存在';
  END IF;

  IF NEW.refund_amount <= 0 THEN
    RAISE EXCEPTION '退款金额必须大于 0';
  END IF;

  SELECT COALESCE(SUM(refund_amount), 0) INTO v_total_refunded
  FROM refunds
  WHERE order_id = NEW.order_id
    AND status IN ('pending', 'processing', 'completed')
    AND deleted_at IS NULL
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID);

  IF v_total_refunded + NEW.refund_amount > v_order_amount THEN
    RAISE EXCEPTION '累计退款金额（% + %）超过订单金额（%）',
      v_total_refunded, NEW.refund_amount, v_order_amount;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_refund_limit ON refunds;
CREATE TRIGGER trg_check_refund_limit
  BEFORE INSERT OR UPDATE OF refund_amount ON refunds
  FOR EACH ROW
  EXECUTE FUNCTION check_refund_amount_limit();


-- ============================================================
-- 7. 补齐前端调用的 RPC 函数
-- ============================================================

-- 7a. calculate_commission — 计算提成
CREATE OR REPLACE FUNCTION calculate_commission(
  p_order_id UUID,
  p_sales_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_rule RECORD;
  v_commission NUMERIC;
  v_result JSONB;
BEGIN
  -- 验证调用者角色
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager')
  ) THEN
    RAISE EXCEPTION '无权执行此操作';
  END IF;

  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '订单不存在';
  END IF;

  -- 查找适用的提成规则
  SELECT * INTO v_rule FROM commission_rules
  WHERE status = 'active'
    AND (product_category IS NULL OR product_category = v_order.product_category)
  ORDER BY product_category NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('commission', 0, 'message', '未找到适用的提成规则');
  END IF;

  v_commission := ROUND(v_order.amount * v_rule.base_rate, 2);

  -- 插入提成记录
  INSERT INTO commission_records (order_id, sales_id, rule_id, order_amount, commission_amount, commission_rate, status)
  VALUES (p_order_id, p_sales_id, v_rule.id, v_order.amount, v_commission, v_rule.base_rate, 'pending');

  RETURN jsonb_build_object(
    'commission', v_commission,
    'rate', v_rule.base_rate,
    'rule_name', v_rule.name
  );
END;
$$;


-- 7b. monthly_settle — 月度结算（补全版）
-- 注：如果 settle_monthly_balances 已存在（从 add-settle-function.sql），此处不覆盖
-- 此函数用于前端调用的 monthly_settle 名称
CREATE OR REPLACE FUNCTION monthly_settle(
  p_month TEXT  -- '2024-04' 格式
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_settlement_date DATE;
  v_result JSONB;
BEGIN
  -- 验证调用者角色
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance')
  ) THEN
    RAISE EXCEPTION '无权执行月度结算';
  END IF;

  v_settlement_date := (p_month || '-01')::DATE + INTERVAL '1 month' - INTERVAL '1 day';

  -- 调用已有的 settle_monthly_balances 函数
  SELECT settle_monthly_balances(v_settlement_date) INTO v_result;

  RETURN COALESCE(v_result, jsonb_build_object('status', 'ok', 'month', p_month));
END;
$$;


-- 7c. 状态转换触发器（防止非法状态跳转）

CREATE OR REPLACE FUNCTION check_expense_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  -- 合法状态转换
  IF (OLD.status = 'pending'  AND NEW.status IN ('approved', 'rejected', 'cancelled')) OR
     (OLD.status = 'approved' AND NEW.status IN ('paid', 'cancelled')) OR
     (OLD.status = 'rejected' AND NEW.status IN ('pending', 'cancelled'))
  THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION '支出状态不允许从 % 变为 %', OLD.status, NEW.status;
END;
$$;

DROP TRIGGER IF EXISTS trg_expense_status ON expenses;
CREATE TRIGGER trg_expense_status
  BEFORE UPDATE OF status ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION check_expense_status_transition();


CREATE OR REPLACE FUNCTION check_refund_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  IF (OLD.status = 'pending'    AND NEW.status IN ('processing', 'completed', 'rejected', 'cancelled')) OR
     (OLD.status = 'processing' AND NEW.status IN ('completed', 'cancelled')) OR
     (OLD.status = 'rejected'   AND NEW.status IN ('pending', 'cancelled'))
  THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION '退款状态不允许从 % 变为 %', OLD.status, NEW.status;
END;
$$;

DROP TRIGGER IF EXISTS trg_refund_status ON refunds;
CREATE TRIGGER trg_refund_status
  BEFORE UPDATE OF status ON refunds
  FOR EACH ROW
  EXECUTE FUNCTION check_refund_status_transition();


-- ============================================================
-- 8. 索引优化
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_account_id ON orders(account_id);
CREATE INDEX IF NOT EXISTS idx_expenses_status ON expenses(status);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refunds_order_id ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON refunds(status);
CREATE INDEX IF NOT EXISTS idx_commission_records_sales_id ON commission_records(sales_id);
CREATE INDEX IF NOT EXISTS idx_commission_records_period ON commission_records(period);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
