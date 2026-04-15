-- ============================================================
-- other_income: 其他收入记录表（打赏、广告、赞助、利息等）
-- 在 Supabase SQL Editor 中执行本文件
-- ============================================================

CREATE TABLE IF NOT EXISTS public.other_income (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
  category    TEXT NOT NULL DEFAULT 'other_income',   -- tips/ad_revenue/sponsorship/interest_income/subsidy/other_income
  description TEXT,                                    -- 备注说明
  account_id  UUID REFERENCES public.accounts(id),     -- 收款账户（可选）
  recorded_by UUID REFERENCES auth.users(id),          -- 记录人
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  deleted_at  TIMESTAMPTZ                              -- 软删除
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_other_income_created_at ON public.other_income(created_at);
CREATE INDEX IF NOT EXISTS idx_other_income_category   ON public.other_income(category);
CREATE INDEX IF NOT EXISTS idx_other_income_deleted_at ON public.other_income(deleted_at);

-- RLS
ALTER TABLE public.other_income ENABLE ROW LEVEL SECURITY;

-- 允许已登录用户读取
CREATE POLICY "other_income_select" ON public.other_income
  FOR SELECT TO authenticated
  USING (true);

-- 允许已登录用户插入
CREATE POLICY "other_income_insert" ON public.other_income
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 允许已登录用户更新（仅自己录入的，或管理员）
CREATE POLICY "other_income_update" ON public.other_income
  FOR UPDATE TO authenticated
  USING (true);

-- 允许已登录用户删除（软删除）
CREATE POLICY "other_income_delete" ON public.other_income
  FOR DELETE TO authenticated
  USING (true);

-- updated_at 自动更新触发器
CREATE OR REPLACE FUNCTION public.update_other_income_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_other_income_updated_at
  BEFORE UPDATE ON public.other_income
  FOR EACH ROW
  EXECUTE FUNCTION public.update_other_income_updated_at();
