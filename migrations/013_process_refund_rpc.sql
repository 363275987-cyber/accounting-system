-- 013: 退款审批事务 RPC 收口
-- 目标：
-- 1. 退款审批时，数据库侧一次性完成 状态流转 + 扣账户余额 + 更新订单状态
-- 2. 消除前端 fallback 手工扣余额导致的多口径问题

CREATE OR REPLACE FUNCTION public.process_refund(p_refund_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role text;
  v_refund public.refunds%ROWTYPE;
  v_order_amount numeric;
  v_total_refunded numeric;
  v_new_status text;
  v_old_balance numeric;
  v_new_balance numeric;
BEGIN
  SELECT role INTO v_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_role NOT IN ('admin', 'finance') THEN
    RAISE EXCEPTION 'Permission denied'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
  INTO v_refund
  FROM public.refunds
  WHERE id = p_refund_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '退款记录不存在';
  END IF;

  IF v_refund.status <> 'pending' THEN
    RAISE EXCEPTION '退款已处理，当前状态：%', v_refund.status;
  END IF;

  IF v_refund.refund_from_account_id IS NOT NULL THEN
    SELECT balance INTO v_old_balance
    FROM public.accounts
    WHERE id = v_refund.refund_from_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION '退款账户不存在';
    END IF;

    IF COALESCE(v_old_balance, 0) < COALESCE(v_refund.refund_amount, 0) THEN
      RAISE EXCEPTION '退款账户余额不足：当前 %.2f，需要 %.2f', COALESCE(v_old_balance, 0), COALESCE(v_refund.refund_amount, 0);
    END IF;

    UPDATE public.accounts
    SET balance = COALESCE(balance, 0) - COALESCE(v_refund.refund_amount, 0)
    WHERE id = v_refund.refund_from_account_id
    RETURNING balance INTO v_new_balance;
  END IF;

  UPDATE public.refunds
  SET
    status = 'completed',
    approved_by = COALESCE(approved_by, auth.uid()),
    approved_at = COALESCE(approved_at, NOW()),
    completed_at = COALESCE(completed_at, NOW())
  WHERE id = p_refund_id;

  IF v_refund.order_id IS NOT NULL THEN
    SELECT COALESCE(payment_amount, amount, 0)
    INTO v_order_amount
    FROM public.orders
    WHERE id = v_refund.order_id;

    SELECT COALESCE(SUM(refund_amount), 0)
    INTO v_total_refunded
    FROM public.refunds
    WHERE order_id = v_refund.order_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    v_new_status := CASE
      WHEN v_total_refunded >= COALESCE(v_order_amount, 0) THEN 'refunded'
      ELSE 'partially_refunded'
    END;

    UPDATE public.orders
    SET status = v_new_status
    WHERE id = v_refund.order_id;
  END IF;

  RETURN jsonb_build_object(
    'refund_id', v_refund.id,
    'order_id', v_refund.order_id,
    'refund_amount', v_refund.refund_amount,
    'refund_from_account_id', v_refund.refund_from_account_id,
    'account_old_balance', v_old_balance,
    'account_new_balance', v_new_balance,
    'order_status', v_new_status
  );
END;
$$;
