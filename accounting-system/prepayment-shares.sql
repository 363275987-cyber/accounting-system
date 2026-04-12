-- ============================================================
-- 货款预付 & 股东垫资 功能 SQL（适配已有表结构）
-- ============================================================

-- ─── 功能一：货款预付 ───
-- orders 表的 total_amount, prepaid_amount, expected_delivery_date 字段已存在，无需额外操作

-- ─── 功能二：股东垫资 - 适配现有表结构 ───

-- shareholder_loans 已有结构:
--   id, shareholder_id(uuid->profiles), loan_amount, annual_rate, start_date, end_date, status, note, created_at, updated_at
-- 需要添加: created_by 字段

ALTER TABLE shareholder_loans ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);

-- loan_repayments 已有结构:
--   id, loan_id, repayment_amount, interest_amount, repayment_date, note, created_at
-- 需要添加: created_by, principal_amount(区分本金)

ALTER TABLE loan_repayments ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id);
-- repayment_amount 重命名逻辑：已有 repayment_amount 作为总还款额
-- 我们新增 principal_amount 用于区分本金和利息
ALTER TABLE loan_repayments ADD COLUMN IF NOT EXISTS principal_amount numeric DEFAULT 0;

-- 先更新函数
CREATE OR REPLACE FUNCTION calculate_loan_interest(
  p_loan_id uuid,
  p_as_of_date date DEFAULT CURRENT_DATE
) RETURNS numeric AS $$
DECLARE
  v_loan shareholder_loans%ROWTYPE;
  v_days integer;
  v_interest numeric;
  v_total_repaid_interest numeric;
BEGIN
  SELECT * INTO v_loan FROM shareholder_loans WHERE id = p_loan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION '垫资记录不存在';
  END IF;

  v_days := GREATEST(0, p_as_of_date - v_loan.start_date);
  v_interest := v_loan.loan_amount * (v_loan.annual_rate / 100.0) / 365.0 * v_days;

  SELECT COALESCE(SUM(lr.interest_amount), 0) INTO v_total_repaid_interest
  FROM loan_repayments lr
  WHERE lr.loan_id = p_loan_id;

  v_interest := GREATEST(0, v_interest - v_total_repaid_interest);
  RETURN ROUND(v_interest, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 创建视图（在函数之后）
DROP VIEW IF EXISTS shareholder_loan_summary;
CREATE VIEW shareholder_loan_summary AS
SELECT
  sl.id,
  sl.shareholder_id,
  p.name AS shareholder_name,
  sl.loan_amount,
  sl.annual_rate AS annual_interest_rate,
  sl.start_date AS loan_date,
  sl.end_date,
  sl.status,
  sl.note,
  sl.created_at,
  COALESCE(SUM(lr.principal_amount), 0) AS repaid_principal,
  COALESCE(SUM(lr.interest_amount), 0) AS repaid_interest,
  COALESCE(SUM(lr.principal_amount + lr.interest_amount), 0) AS repaid_total,
  (sl.loan_amount - COALESCE(SUM(lr.principal_amount), 0)) AS remaining_principal,
  calculate_loan_interest(sl.id, CURRENT_DATE) AS outstanding_interest
FROM shareholder_loans sl
LEFT JOIN loan_repayments lr ON lr.loan_id = sl.id
LEFT JOIN profiles p ON p.id = sl.shareholder_id
GROUP BY sl.id, p.name
ORDER BY sl.start_date DESC;

COMMENT ON VIEW shareholder_loan_summary IS '股东垫资汇总视图（含已还/未还金额）';

-- ─── RLS 策略 ───
ALTER TABLE shareholder_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_repayments ENABLE ROW LEVEL SECURITY;

-- 删除可能冲突的旧策略
DO $$ BEGIN
  DROP POLICY IF EXISTS "Anyone authenticated can read shareholder_loans" ON shareholder_loans;
  DROP POLICY IF EXISTS "Admin and finance can insert shareholder_loans" ON shareholder_loans;
  DROP POLICY IF EXISTS "Admin and finance can update shareholder_loans" ON shareholder_loans;
  DROP POLICY IF EXISTS "Admin and finance can delete shareholder_loans" ON shareholder_loans;
  DROP POLICY IF EXISTS "Anyone authenticated can read loan_repayments" ON loan_repayments;
  DROP POLICY IF EXISTS "Admin and finance can insert loan_repayments" ON loan_repayments;
  DROP POLICY IF EXISTS "Admin and finance can update loan_repayments" ON loan_repayments;
  DROP POLICY IF EXISTS "Admin and finance can delete loan_repayments" ON loan_repayments;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 股东垫资 RLS
CREATE POLICY "Anyone authenticated can read shareholder_loans"
  ON shareholder_loans FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admin and finance can insert shareholder_loans"
  ON shareholder_loans FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

CREATE POLICY "Admin and finance can update shareholder_loans"
  ON shareholder_loans FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

CREATE POLICY "Admin and finance can delete shareholder_loans"
  ON shareholder_loans FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

-- 还款记录 RLS
CREATE POLICY "Anyone authenticated can read loan_repayments"
  ON loan_repayments FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admin and finance can insert loan_repayments"
  ON loan_repayments FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

CREATE POLICY "Admin and finance can update loan_repayments"
  ON loan_repayments FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

CREATE POLICY "Admin and finance can delete loan_repayments"
  ON loan_repayments FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

-- 视图 RLS
ALTER VIEW shareholder_loan_summary SET (security_barrier = true);
