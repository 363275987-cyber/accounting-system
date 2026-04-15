-- ============================================================
-- salaries: 工资发放记录表
-- 在 Supabase SQL Editor 中执行本文件
-- ============================================================

CREATE TABLE IF NOT EXISTS public.salaries (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  employee_name   TEXT NOT NULL,                           -- 员工姓名
  position        TEXT,                                     -- 职位
  base_salary     NUMERIC(12,2) DEFAULT 0,                 -- 基本工资
  bonus           NUMERIC(12,2) DEFAULT 0,                 -- 奖金/绩效
  deduction       NUMERIC(12,2) DEFAULT 0,                 -- 扣款
  actual_amount   NUMERIC(12,2) NOT NULL,                  -- 实发金额
  pay_month       TEXT NOT NULL,                            -- 发放月份 e.g. '2026-04'
  pay_date        DATE,                                     -- 实际发放日期
  account_id      UUID REFERENCES public.accounts(id),      -- 付款账户
  note            TEXT,                                     -- 备注
  recorded_by     UUID REFERENCES auth.users(id),           -- 记录人
  created_at      TIMESTAMPTZ DEFAULT now(),
  deleted_at      TIMESTAMPTZ                               -- 软删除
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_salaries_pay_month   ON public.salaries(pay_month);
CREATE INDEX IF NOT EXISTS idx_salaries_employee    ON public.salaries(employee_name);
CREATE INDEX IF NOT EXISTS idx_salaries_deleted_at  ON public.salaries(deleted_at);

-- RLS
ALTER TABLE public.salaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "salaries_select" ON public.salaries
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "salaries_insert" ON public.salaries
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "salaries_update" ON public.salaries
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "salaries_delete" ON public.salaries
  FOR DELETE TO authenticated USING (true);
