-- ============================================================
-- 014: 店铺提现改为数据库事务创建 / 撤销
-- 目标：
-- 1. 创建提现时，店铺扣款、到账账户加款、手续费支出、withdrawals 明细同事务完成
-- 2. 撤销提现时，双端余额回滚、手续费支出作废、withdrawals 软删同事务完成
-- 3. 给前端一个稳定 RPC，逐步淘汰多步串行写法
-- ============================================================

ALTER TABLE public.withdrawals
  ADD COLUMN IF NOT EXISTS store_name TEXT;

ALTER TABLE public.withdrawals
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.create_store_withdrawal(
  p_store_id UUID,
  p_to_account_id UUID,
  p_actual_arrival NUMERIC(12,2),
  p_fee_amount NUMERIC(12,2) DEFAULT 0,
  p_fee_remark TEXT DEFAULT NULL,
  p_remark TEXT DEFAULT NULL,
  p_store_name TEXT DEFAULT NULL,
  p_withdrawn_at TIMESTAMPTZ DEFAULT NOW()
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_store_balance NUMERIC(12,2);
  v_to_balance NUMERIC(12,2);
  v_store_new_balance NUMERIC(12,2);
  v_to_new_balance NUMERIC(12,2);
  v_actual_arrival NUMERIC(12,2);
  v_fee_amount NUMERIC(12,2);
  v_total_deduct NUMERIC(12,2);
  v_fee_expense_id UUID;
  v_fee_detail JSONB := '[]'::JSONB;
  v_withdrawal_id UUID;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF COALESCE(v_role, '') NOT IN ('admin', 'finance', 'manager') THEN
    RAISE EXCEPTION '无权限执行店铺提现';
  END IF;

  v_actual_arrival := ROUND(COALESCE(p_actual_arrival, 0), 2);
  v_fee_amount := ROUND(GREATEST(COALESCE(p_fee_amount, 0), 0), 2);
  v_total_deduct := v_actual_arrival + v_fee_amount;

  IF p_store_id IS NULL OR p_to_account_id IS NULL THEN
    RAISE EXCEPTION '提现账户不能为空';
  END IF;

  IF p_store_id = p_to_account_id THEN
    RAISE EXCEPTION '店铺提现不能转给自己';
  END IF;

  IF v_actual_arrival <= 0 THEN
    RAISE EXCEPTION '到账金额必须大于 0';
  END IF;

  SELECT balance
  INTO v_store_balance
  FROM public.accounts
  WHERE id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '店铺账户不存在';
  END IF;

  SELECT balance
  INTO v_to_balance
  FROM public.accounts
  WHERE id = p_to_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '到账账户不存在';
  END IF;

  IF v_store_balance < v_total_deduct THEN
    RAISE EXCEPTION '店铺余额不足：当前 %.2f，需要 %.2f', v_store_balance, v_total_deduct;
  END IF;

  UPDATE public.accounts
  SET balance = balance - v_total_deduct,
      updated_at = NOW()
  WHERE id = p_store_id
  RETURNING balance INTO v_store_new_balance;

  UPDATE public.accounts
  SET balance = balance + v_actual_arrival,
      updated_at = NOW()
  WHERE id = p_to_account_id
  RETURNING balance INTO v_to_new_balance;

  IF v_fee_amount > 0 THEN
    INSERT INTO public.expenses (
      category,
      amount,
      payee,
      account_id,
      status,
      approver_id,
      note,
      created_by,
      approved_at,
      paid_at
    )
    VALUES (
      'platform_fee',
      v_fee_amount,
      COALESCE(NULLIF(p_store_name, ''), '提现'),
      p_store_id,
      'paid',
      auth.uid(),
      COALESCE(NULLIF(p_fee_remark, ''), COALESCE(NULLIF(p_store_name, ''), '店铺') || ' 提现手续费'),
      auth.uid(),
      NOW(),
      NOW()
    )
    RETURNING id INTO v_fee_expense_id;

    v_fee_detail := jsonb_build_array(
      jsonb_build_object(
        'amount', v_fee_amount,
        'label', COALESCE(NULLIF(p_fee_remark, ''), '手续费'),
        'fee_expense_id', v_fee_expense_id
      )
    );
  END IF;

  INSERT INTO public.withdrawals (
    account_id,
    to_account_id,
    amount,
    fee_detail,
    actual_arrival,
    status,
    withdrawn_at,
    remark,
    created_by,
    store_name
  )
  VALUES (
    p_store_id,
    p_to_account_id,
    v_total_deduct,
    v_fee_detail,
    v_actual_arrival,
    'completed',
    COALESCE(p_withdrawn_at, NOW()),
    p_remark,
    auth.uid(),
    NULLIF(p_store_name, '')
  )
  RETURNING id INTO v_withdrawal_id;

  RETURN jsonb_build_object(
    'withdrawal_id', v_withdrawal_id,
    'fee_expense_id', v_fee_expense_id,
    'actual_arrival', v_actual_arrival,
    'total_deduct', v_total_deduct,
    'store_old_balance', v_store_balance,
    'store_new_balance', v_store_new_balance,
    'to_old_balance', v_to_balance,
    'to_new_balance', v_to_new_balance
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.revert_withdrawal(
  p_id UUID,
  p_reason TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_withdrawal public.withdrawals%ROWTYPE;
  v_store_balance NUMERIC(12,2);
  v_to_balance NUMERIC(12,2);
  v_store_new_balance NUMERIC(12,2);
  v_to_new_balance NUMERIC(12,2);
  v_fee_expense_id UUID;
  v_reason TEXT;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF COALESCE(v_role, '') NOT IN ('admin', 'finance', 'manager') THEN
    RAISE EXCEPTION '无权限撤销店铺提现';
  END IF;

  SELECT *
  INTO v_withdrawal
  FROM public.withdrawals
  WHERE id = p_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '提现记录不存在';
  END IF;

  IF v_withdrawal.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION '该提现已经撤销';
  END IF;

  IF COALESCE(v_withdrawal.status, '') <> 'completed' THEN
    RAISE EXCEPTION '当前状态不可撤销：%', v_withdrawal.status;
  END IF;

  SELECT balance
  INTO v_store_balance
  FROM public.accounts
  WHERE id = v_withdrawal.account_id
  FOR UPDATE;

  SELECT balance
  INTO v_to_balance
  FROM public.accounts
  WHERE id = v_withdrawal.to_account_id
  FOR UPDATE;

  IF v_to_balance < COALESCE(v_withdrawal.actual_arrival, 0) THEN
    RAISE EXCEPTION '到账账户余额不足，无法撤销';
  END IF;

  UPDATE public.accounts
  SET balance = balance - COALESCE(v_withdrawal.actual_arrival, 0),
      updated_at = NOW()
  WHERE id = v_withdrawal.to_account_id
  RETURNING balance INTO v_to_new_balance;

  UPDATE public.accounts
  SET balance = balance + COALESCE(v_withdrawal.amount, 0),
      updated_at = NOW()
  WHERE id = v_withdrawal.account_id
  RETURNING balance INTO v_store_new_balance;

  SELECT NULLIF(item->>'fee_expense_id', '')::UUID
  INTO v_fee_expense_id
  FROM jsonb_array_elements(COALESCE(v_withdrawal.fee_detail, '[]'::JSONB)) AS item
  WHERE item ? 'fee_expense_id'
  LIMIT 1;

  IF v_fee_expense_id IS NOT NULL THEN
    UPDATE public.expenses
    SET status = 'cancelled',
        note = CONCAT_WS(' | ', note, '[系统撤销] 对应提现已撤销')
    WHERE id = v_fee_expense_id;
  END IF;

  v_reason := COALESCE(NULLIF(p_reason, ''), '[系统撤销] 店铺提现已撤回');

  UPDATE public.withdrawals
  SET status = 'failed',
      deleted_at = NOW(),
      remark = CONCAT_WS(' | ', remark, v_reason)
  WHERE id = p_id;

  RETURN jsonb_build_object(
    'withdrawal_id', p_id,
    'fee_expense_id', v_fee_expense_id,
    'actual_arrival', COALESCE(v_withdrawal.actual_arrival, 0),
    'total_deduct', COALESCE(v_withdrawal.amount, 0),
    'store_old_balance', v_store_balance,
    'store_new_balance', v_store_new_balance,
    'to_old_balance', v_to_balance,
    'to_new_balance', v_to_new_balance
  );
END;
$$;
