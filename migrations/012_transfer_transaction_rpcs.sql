-- 012: 转账事务 RPC 收口
-- 目标：
-- 1. 创建转账时，在数据库侧一次性完成 账户校验 + 双边余额变更 + 记录落表
-- 2. 删除转账时，按 fee_mode 对称回滚，避免内扣/外扣口径不一致

ALTER TABLE public.account_transfers
  ADD COLUMN IF NOT EXISTS fee_mode text;

ALTER TABLE public.account_transfers
  DROP CONSTRAINT IF EXISTS account_transfers_fee_mode_check;

ALTER TABLE public.account_transfers
  ADD CONSTRAINT account_transfers_fee_mode_check
  CHECK (fee_mode IS NULL OR fee_mode IN ('from_balance', 'from_amount'));

UPDATE public.account_transfers
SET fee_mode = COALESCE(fee_mode, 'from_balance')
WHERE fee_mode IS NULL;

CREATE OR REPLACE FUNCTION public.create_account_transfer(
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_fee numeric DEFAULT 0,
  p_fee_mode text DEFAULT 'from_balance',
  p_note text DEFAULT NULL,
  p_transfer_date timestamptz DEFAULT NOW(),
  p_created_by uuid DEFAULT auth.uid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
  v_from_balance numeric;
  v_to_balance numeric;
  v_total_debit numeric;
  v_actual_credit numeric;
  v_fee_mode text;
  v_transfer public.account_transfers%ROWTYPE;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_role NOT IN ('admin', 'finance') THEN
    RAISE EXCEPTION 'Permission denied'
      USING ERRCODE = '42501';
  END IF;

  IF p_from_account_id IS NULL OR p_to_account_id IS NULL THEN
    RAISE EXCEPTION '缺少转入/转出账户';
  END IF;

  IF p_from_account_id = p_to_account_id THEN
    RAISE EXCEPTION '不能转给自己';
  END IF;

  IF COALESCE(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION '转账金额必须大于 0';
  END IF;

  IF COALESCE(p_fee, 0) < 0 THEN
    RAISE EXCEPTION '手续费不能小于 0';
  END IF;

  v_fee_mode := CASE
    WHEN p_fee_mode IN ('from_balance', 'from_amount') THEN p_fee_mode
    ELSE 'from_balance'
  END;

  SELECT balance INTO v_from_balance
  FROM public.accounts
  WHERE id = p_from_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '转出账户不存在';
  END IF;

  SELECT balance INTO v_to_balance
  FROM public.accounts
  WHERE id = p_to_account_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '转入账户不存在';
  END IF;

  v_total_debit := p_amount + CASE WHEN v_fee_mode = 'from_balance' THEN COALESCE(p_fee, 0) ELSE 0 END;
  v_actual_credit := p_amount - CASE WHEN v_fee_mode = 'from_amount' THEN COALESCE(p_fee, 0) ELSE 0 END;

  IF v_actual_credit < 0 THEN
    RAISE EXCEPTION '手续费不能大于转账金额';
  END IF;

  IF COALESCE(v_from_balance, 0) < v_total_debit THEN
    RAISE EXCEPTION '余额不足：当前 %.2f，需要 %.2f', COALESCE(v_from_balance, 0), v_total_debit;
  END IF;

  UPDATE public.accounts
  SET balance = COALESCE(balance, 0) - v_total_debit
  WHERE id = p_from_account_id;

  UPDATE public.accounts
  SET balance = COALESCE(balance, 0) + v_actual_credit
  WHERE id = p_to_account_id;

  INSERT INTO public.account_transfers (
    from_account_id,
    to_account_id,
    amount,
    fee,
    fee_mode,
    note,
    created_by,
    status,
    transfer_date
  )
  VALUES (
    p_from_account_id,
    p_to_account_id,
    p_amount,
    COALESCE(p_fee, 0),
    v_fee_mode,
    p_note,
    p_created_by,
    'completed',
    COALESCE(p_transfer_date, NOW())
  )
  RETURNING * INTO v_transfer;

  RETURN jsonb_build_object(
    'transfer_id', v_transfer.id,
    'from_account_id', v_transfer.from_account_id,
    'to_account_id', v_transfer.to_account_id,
    'amount', v_transfer.amount,
    'fee', v_transfer.fee,
    'fee_mode', v_transfer.fee_mode,
    'note', v_transfer.note,
    'status', v_transfer.status,
    'transfer_date', v_transfer.transfer_date,
    'created_at', v_transfer.created_at,
    'from_old_balance', COALESCE(v_from_balance, 0),
    'from_new_balance', COALESCE(v_from_balance, 0) - v_total_debit,
    'to_old_balance', COALESCE(v_to_balance, 0),
    'to_new_balance', COALESCE(v_to_balance, 0) + v_actual_credit,
    'total_debit', v_total_debit,
    'actual_credit', v_actual_credit
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.batch_delete_transfers(p_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
  v_count int;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_role NOT IN ('admin', 'finance') THEN
    RAISE EXCEPTION 'Permission denied'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.accounts a
  SET balance = COALESCE(a.balance, 0)
    + t.amount
    + CASE WHEN COALESCE(t.fee_mode, 'from_balance') = 'from_balance' THEN COALESCE(t.fee, 0) ELSE 0 END
  FROM unnest(p_ids) AS x(id)
  JOIN public.account_transfers t ON t.id = x.id
    AND t.deleted_at IS NULL
    AND t.from_account_id IS NOT NULL
    AND t.amount > 0
  WHERE a.id = t.from_account_id;

  UPDATE public.accounts a
  SET balance = COALESCE(a.balance, 0)
    - t.amount
    + CASE WHEN COALESCE(t.fee_mode, 'from_balance') = 'from_amount' THEN COALESCE(t.fee, 0) ELSE 0 END
  FROM unnest(p_ids) AS x(id)
  JOIN public.account_transfers t ON t.id = x.id
    AND t.deleted_at IS NULL
    AND t.to_account_id IS NOT NULL
    AND t.amount > 0
  WHERE a.id = t.to_account_id;

  UPDATE public.account_transfers
  SET deleted_at = NOW()
  WHERE id = ANY(p_ids) AND deleted_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_count, 'total', array_length(p_ids, 1));
END;
$$;
