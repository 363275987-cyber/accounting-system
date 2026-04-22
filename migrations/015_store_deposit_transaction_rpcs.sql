-- ============================================================
-- 015: 店铺入账表结构补档 + 事务化创建 / 撤销
-- 背景：
-- store_deposits 已在前端被长期使用，但仓库中缺少正式 migration。
-- 这里补齐表结构，并给创建 / 撤销提供事务 RPC。
-- ============================================================

CREATE TABLE IF NOT EXISTS public.store_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount > 0),
  deposit_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled')),
  recorded_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

ALTER TABLE public.store_deposits ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "store_deposits_select" ON public.store_deposits FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "store_deposits_insert" ON public.store_deposits FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "store_deposits_update" ON public.store_deposits FOR UPDATE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "store_deposits_delete" ON public.store_deposits FOR DELETE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_store_deposits_account_date
  ON public.store_deposits(account_id, deposit_date DESC);

CREATE INDEX IF NOT EXISTS idx_store_deposits_active
  ON public.store_deposits(created_at DESC)
  WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.create_store_deposit(
  p_store_id UUID,
  p_amount NUMERIC(12,2),
  p_deposit_date TIMESTAMPTZ DEFAULT NOW(),
  p_note TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_old_balance NUMERIC(12,2);
  v_new_balance NUMERIC(12,2);
  v_amount NUMERIC(12,2);
  v_deposit_id UUID;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF COALESCE(v_role, '') NOT IN ('admin', 'finance', 'manager') THEN
    RAISE EXCEPTION '无权限创建店铺入账';
  END IF;

  v_amount := ROUND(COALESCE(p_amount, 0), 2);
  IF p_store_id IS NULL THEN
    RAISE EXCEPTION '店铺账户不能为空';
  END IF;
  IF v_amount <= 0 THEN
    RAISE EXCEPTION '入账金额必须大于 0';
  END IF;

  SELECT balance
  INTO v_old_balance
  FROM public.accounts
  WHERE id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '店铺账户不存在';
  END IF;

  INSERT INTO public.store_deposits (
    account_id,
    amount,
    deposit_date,
    note,
    status,
    recorded_by
  )
  VALUES (
    p_store_id,
    v_amount,
    COALESCE(p_deposit_date, NOW()),
    p_note,
    'completed',
    auth.uid()
  )
  RETURNING id INTO v_deposit_id;

  UPDATE public.accounts
  SET balance = balance + v_amount,
      updated_at = NOW()
  WHERE id = p_store_id
  RETURNING balance INTO v_new_balance;

  RETURN jsonb_build_object(
    'deposit_id', v_deposit_id,
    'amount', v_amount,
    'store_old_balance', v_old_balance,
    'store_new_balance', v_new_balance,
    'deposit_date', COALESCE(p_deposit_date, NOW())
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.revert_store_deposit(
  p_id UUID,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_deposit public.store_deposits%ROWTYPE;
  v_old_balance NUMERIC(12,2);
  v_new_balance NUMERIC(12,2);
  v_reason TEXT;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF COALESCE(v_role, '') NOT IN ('admin', 'finance', 'manager') THEN
    RAISE EXCEPTION '无权限撤销店铺入账';
  END IF;

  SELECT *
  INTO v_deposit
  FROM public.store_deposits
  WHERE id = p_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '入账记录不存在';
  END IF;

  IF v_deposit.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION '该入账已经撤销';
  END IF;

  IF COALESCE(v_deposit.status, '') <> 'completed' THEN
    RAISE EXCEPTION '当前状态不可撤销：%', v_deposit.status;
  END IF;

  SELECT balance
  INTO v_old_balance
  FROM public.accounts
  WHERE id = v_deposit.account_id
  FOR UPDATE;

  IF v_old_balance < COALESCE(v_deposit.amount, 0) THEN
    RAISE EXCEPTION '店铺余额不足，无法撤销入账';
  END IF;

  UPDATE public.accounts
  SET balance = balance - COALESCE(v_deposit.amount, 0),
      updated_at = NOW()
  WHERE id = v_deposit.account_id
  RETURNING balance INTO v_new_balance;

  v_reason := COALESCE(NULLIF(p_reason, ''), '[系统撤销] 店铺入账已撤回');

  UPDATE public.store_deposits
  SET status = 'cancelled',
      deleted_at = NOW(),
      note = CONCAT_WS(' | ', note, v_reason)
  WHERE id = p_id;

  RETURN jsonb_build_object(
    'deposit_id', p_id,
    'amount', COALESCE(v_deposit.amount, 0),
    'store_old_balance', v_old_balance,
    'store_new_balance', v_new_balance
  );
END;
$$;
