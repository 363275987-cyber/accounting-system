-- ═══════════════════════════════════════════════════════════════
-- 008: 修 batch_delete_transfers 退回手续费
-- 之前只退回 amount,fee 部分永远丢失 → 余额不平衡
-- 假设 fee_mode='from_balance'(外扣,Transfers.vue 表单默认,99% 情况)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.batch_delete_transfers(p_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT role_in(auth.uid(), ARRAY['admin', 'finance']) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  -- 退回 from_account: amount + fee(外扣模式下手续费是从 from 扣的)
  UPDATE accounts a
  SET balance = COALESCE(a.balance, 0) + t.amount + COALESCE(t.fee, 0)
  FROM unnest(p_ids) AS x(id)
  JOIN account_transfers t ON t.id = x.id
    AND t.deleted_at IS NULL
    AND t.from_account_id IS NOT NULL
    AND t.amount > 0
  WHERE a.id = t.from_account_id;

  -- 扣回 to_account: amount(外扣模式下 to 原本只收到 amount)
  UPDATE accounts a
  SET balance = COALESCE(a.balance, 0) - t.amount
  FROM unnest(p_ids) AS x(id)
  JOIN account_transfers t ON t.id = x.id
    AND t.deleted_at IS NULL
    AND t.to_account_id IS NOT NULL
    AND t.amount > 0
  WHERE a.id = t.to_account_id;

  -- 软删除
  UPDATE account_transfers SET deleted_at = NOW()
  WHERE id = ANY(p_ids) AND deleted_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_count, 'total', array_length(p_ids, 1));
END;
$$;
