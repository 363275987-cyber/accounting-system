import { supabase, withTimeout } from './supabase'
import { applyAccountBalanceDelta } from './accountBalance'

function isMissingRpc(error) {
  return ['PGRST202', 'PGRST203', '42883'].includes(error?.code) ||
    /function .* does not exist/i.test(error?.message || '')
}

function isMissingColumn(error) {
  return ['PGRST204', '42703'].includes(error?.code) ||
    /column .* does not exist/i.test(error?.message || '') ||
    /Could not find the .* column/i.test(error?.message || '')
}

function extractFeeExpenseId(feeDetail) {
  if (Array.isArray(feeDetail)) {
    const matched = feeDetail.find(item => item?.fee_expense_id)
    return matched?.fee_expense_id || null
  }
  return feeDetail?.fee_expense_id || null
}

async function setWithdrawalFeeExpenseStatus(expenseId, status, extraNote = '') {
  if (!expenseId) return
  const lookupRes = await withTimeout(
    supabase.from('expenses').select('note').eq('id', expenseId).single(),
    10000,
    '读取提现手续费'
  )
  if (lookupRes.error) throw lookupRes.error

  const baseNote = lookupRes.data?.note || ''
  const nextNote = extraNote
    ? [baseNote, extraNote].filter(Boolean).join(' | ')
    : baseNote

  const updateRes = await withTimeout(
    supabase
      .from('expenses')
      .update({
        status,
        note: nextNote || null,
      })
      .eq('id', expenseId),
    10000,
    status === 'cancelled' ? '撤销提现手续费' : '恢复提现手续费'
  )
  if (updateRes.error) throw updateRes.error
}

async function insertWithdrawalRecord(payload) {
  const insertRes = await withTimeout(
    supabase
      .from('withdrawals')
      .insert(payload)
      .select('id')
      .single(),
    10000,
    '写入提现记录'
  )

  if (insertRes.error && isMissingColumn(insertRes.error) && Object.prototype.hasOwnProperty.call(payload, 'store_name')) {
    const fallbackPayload = { ...payload }
    delete fallbackPayload.store_name

    const fallbackRes = await withTimeout(
      supabase
        .from('withdrawals')
        .insert(fallbackPayload)
        .select('id')
        .single(),
      10000,
      '写入提现记录'
    )
    if (fallbackRes.error) throw fallbackRes.error
    return fallbackRes.data
  }

  if (insertRes.error) throw insertRes.error
  return insertRes.data
}

async function markWithdrawalReverted(withdrawalId, remark, reason) {
  const nextRemark = [remark, reason].filter(Boolean).join(' | ') || null
  const baseUpdate = {
    status: 'failed',
    remark: nextRemark,
  }

  const updateRes = await withTimeout(
    supabase
      .from('withdrawals')
      .update({
        ...baseUpdate,
        deleted_at: new Date().toISOString(),
      })
      .eq('id', withdrawalId),
    10000,
    '标记提现撤销'
  )

  if (updateRes.error && isMissingColumn(updateRes.error)) {
    const fallbackRes = await withTimeout(
      supabase
        .from('withdrawals')
        .update(baseUpdate)
        .eq('id', withdrawalId),
      10000,
      '标记提现撤销'
    )
    if (fallbackRes.error) throw fallbackRes.error
    return
  }

  if (updateRes.error) throw updateRes.error
}

export async function createStoreWithdrawalWithFallback({
  storeId,
  toAccountId,
  amount,
  feeAmount = 0,
  feeRemark = '',
  remark = '',
  storeName = '',
}) {
  const actualArrival = Number(amount || 0)
  const normalizedFee = Math.max(0, Number(feeAmount || 0))
  const totalDeduct = actualArrival + normalizedFee

  if (!storeId) throw new Error('未指定店铺账户')
  if (!toAccountId) throw new Error('未指定到账账户')
  if (actualArrival <= 0) throw new Error('到账金额必须大于 0')

  const { data, error } = await withTimeout(
    supabase.rpc('create_store_withdrawal', {
      p_store_id: storeId,
      p_to_account_id: toAccountId,
      p_actual_arrival: actualArrival,
      p_fee_amount: normalizedFee,
      p_fee_remark: feeRemark,
      p_remark: remark,
      p_store_name: storeName,
    }),
    10000,
    '创建店铺提现'
  )
  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const storeBalanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', storeId).single(),
    10000,
    '读取店铺余额'
  )
  if (storeBalanceRes.error) throw storeBalanceRes.error
  const oldStoreBalance = Number(storeBalanceRes.data?.balance || 0)
  if (totalDeduct > oldStoreBalance + 0.0001) {
    throw new Error(`店铺余额不足：当前 ¥${oldStoreBalance.toFixed(2)}，本次需扣 ¥${totalDeduct.toFixed(2)}`)
  }

  const targetBalanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', toAccountId).single(),
    10000,
    '读取到账账户余额'
  )
  if (targetBalanceRes.error) throw targetBalanceRes.error
  const oldTargetBalance = Number(targetBalanceRes.data?.balance || 0)

  let storeBalanceResult = null
  let targetBalanceResult = null
  let feeExpenseId = null

  try {
    storeBalanceResult = await applyAccountBalanceDelta({
      accountId: storeId,
      delta: -totalDeduct,
      reason: '店铺提现扣款',
      refType: 'withdrawal',
    })
    targetBalanceResult = await applyAccountBalanceDelta({
      accountId: toAccountId,
      delta: actualArrival,
      reason: '店铺提现到账',
      refType: 'withdrawal',
    })

    if (normalizedFee > 0) {
      const { data: sessionData } = await supabase.auth.getSession()
      const userId = sessionData?.session?.user?.id
      const feeNote = feeRemark || `${storeName || ''} 提现手续费`
      const nowIso = new Date().toISOString()
      const feeExpenseRes = await withTimeout(
        supabase
          .from('expenses')
          .insert({
            amount: normalizedFee,
            category: 'platform_fee',
            payee: storeName || '提现',
            note: feeNote,
            status: 'paid',
            account_id: storeId,
            created_by: userId,
            approver_id: userId,
            approved_at: nowIso,
            paid_at: nowIso,
          })
          .select('id')
          .single(),
        10000,
        '写入提现手续费'
      )
      if (feeExpenseRes.error) throw feeExpenseRes.error
      feeExpenseId = feeExpenseRes.data?.id || null
    }

    const feeDetail = normalizedFee > 0
      ? [{ amount: normalizedFee, label: feeRemark || '手续费', fee_expense_id: feeExpenseId }]
      : []

    const withdrawal = await insertWithdrawalRecord({
      account_id: storeId,
      to_account_id: toAccountId,
      amount: totalDeduct,
      actual_arrival: actualArrival,
      fee_detail: feeDetail,
      store_name: storeName || null,
      remark: remark || null,
      status: 'completed',
      withdrawn_at: new Date().toISOString(),
    })

    return {
      withdrawal_id: withdrawal.id,
      fee_expense_id: feeExpenseId,
      total_deduct: totalDeduct,
      actual_arrival: actualArrival,
      store_old_balance: oldStoreBalance,
      store_new_balance: Number(storeBalanceResult?.new_balance || oldStoreBalance - totalDeduct),
      to_old_balance: oldTargetBalance,
      to_new_balance: Number(targetBalanceResult?.new_balance || oldTargetBalance + actualArrival),
    }
  } catch (error) {
    if (feeExpenseId) {
      try {
        await setWithdrawalFeeExpenseStatus(feeExpenseId, 'cancelled', '[系统回滚] 提现创建失败')
      } catch (feeRollbackError) {
        console.warn('[createStoreWithdrawalWithFallback] 手续费回滚失败:', feeRollbackError)
      }
    }
    if (targetBalanceResult) {
      try {
        await applyAccountBalanceDelta({
          accountId: toAccountId,
          delta: -actualArrival,
          reason: '店铺提现失败回滚',
          refType: 'withdrawal',
        })
      } catch (targetRollbackError) {
        console.warn('[createStoreWithdrawalWithFallback] 到账账户回滚失败:', targetRollbackError)
      }
    }
    if (storeBalanceResult) {
      try {
        await applyAccountBalanceDelta({
          accountId: storeId,
          delta: totalDeduct,
          reason: '店铺提现失败回滚',
          refType: 'withdrawal',
        })
      } catch (storeRollbackError) {
        console.warn('[createStoreWithdrawalWithFallback] 店铺余额回滚失败:', storeRollbackError)
      }
    }
    throw error
  }
}

export async function revertStoreWithdrawalWithFallback(withdrawalId, reason = '') {
  if (!withdrawalId) throw new Error('未指定提现记录')

  const { data, error } = await withTimeout(
    supabase.rpc('revert_withdrawal', {
      p_id: withdrawalId,
      p_reason: reason || null,
    }),
    10000,
    '撤销店铺提现'
  )
  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const withdrawalRes = await withTimeout(
    supabase.from('withdrawals').select('*').eq('id', withdrawalId).single(),
    10000,
    '读取提现记录'
  )
  if (withdrawalRes.error || !withdrawalRes.data) {
    throw withdrawalRes.error || new Error('提现记录不存在')
  }

  const withdrawal = withdrawalRes.data
  if (withdrawal.deleted_at) throw new Error('这笔提现已经撤销过了')
  if (withdrawal.status && withdrawal.status !== 'completed') {
    throw new Error(`当前状态不允许撤销：${withdrawal.status}`)
  }

  const actualArrival = Number(withdrawal.actual_arrival || 0)
  const totalDeduct = Number(withdrawal.amount || 0)
  const feeExpenseId = extractFeeExpenseId(withdrawal.fee_detail)
  const revertReason = reason || '[系统撤销] 店铺提现已撤回'

  const targetBalanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', withdrawal.to_account_id).single(),
    10000,
    '读取到账账户余额'
  )
  if (targetBalanceRes.error) throw targetBalanceRes.error
  const oldTargetBalance = Number(targetBalanceRes.data?.balance || 0)
  if (oldTargetBalance + 0.0001 < actualArrival) {
    throw new Error(`到账账户余额不足，无法撤销：当前 ¥${oldTargetBalance.toFixed(2)}，需要扣回 ¥${actualArrival.toFixed(2)}`)
  }

  const storeBalanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', withdrawal.account_id).single(),
    10000,
    '读取店铺余额'
  )
  if (storeBalanceRes.error) throw storeBalanceRes.error
  const oldStoreBalance = Number(storeBalanceRes.data?.balance || 0)

  let targetBalanceResult = null
  let storeBalanceResult = null
  let feeCancelled = false

  try {
    targetBalanceResult = await applyAccountBalanceDelta({
      accountId: withdrawal.to_account_id,
      delta: -actualArrival,
      reason: '撤销店铺提现扣回',
      refType: 'withdrawal',
      refId: withdrawalId,
    })
    storeBalanceResult = await applyAccountBalanceDelta({
      accountId: withdrawal.account_id,
      delta: totalDeduct,
      reason: '撤销店铺提现回补',
      refType: 'withdrawal',
      refId: withdrawalId,
    })

    if (feeExpenseId) {
      await setWithdrawalFeeExpenseStatus(feeExpenseId, 'cancelled', '[系统撤销] 对应提现已撤销')
      feeCancelled = true
    }

    await markWithdrawalReverted(withdrawalId, withdrawal.remark, revertReason)

    return {
      withdrawal_id: withdrawalId,
      fee_expense_id: feeExpenseId,
      actual_arrival: actualArrival,
      total_deduct: totalDeduct,
      store_old_balance: oldStoreBalance,
      store_new_balance: Number(storeBalanceResult?.new_balance || oldStoreBalance + totalDeduct),
      to_old_balance: oldTargetBalance,
      to_new_balance: Number(targetBalanceResult?.new_balance || oldTargetBalance - actualArrival),
    }
  } catch (error) {
    if (feeCancelled && feeExpenseId) {
      try {
        await setWithdrawalFeeExpenseStatus(feeExpenseId, 'paid', '[系统回滚] 提现撤销未完成')
      } catch (feeRollbackError) {
        console.warn('[revertStoreWithdrawalWithFallback] 手续费恢复失败:', feeRollbackError)
      }
    }
    if (storeBalanceResult) {
      try {
        await applyAccountBalanceDelta({
          accountId: withdrawal.account_id,
          delta: -totalDeduct,
          reason: '撤销店铺提现失败回滚',
          refType: 'withdrawal',
          refId: withdrawalId,
        })
      } catch (storeRollbackError) {
        console.warn('[revertStoreWithdrawalWithFallback] 店铺余额回滚失败:', storeRollbackError)
      }
    }
    if (targetBalanceResult) {
      try {
        await applyAccountBalanceDelta({
          accountId: withdrawal.to_account_id,
          delta: actualArrival,
          reason: '撤销店铺提现失败回滚',
          refType: 'withdrawal',
          refId: withdrawalId,
        })
      } catch (targetRollbackError) {
        console.warn('[revertStoreWithdrawalWithFallback] 到账账户回滚失败:', targetRollbackError)
      }
    }
    throw error
  }
}

export async function createStoreDepositWithFallback({
  storeId,
  amount,
  depositDate = null,
  note = '',
}) {
  const normalizedAmount = Number(amount || 0)
  const normalizedDate = depositDate || new Date().toISOString()

  if (!storeId) throw new Error('未指定店铺账户')
  if (normalizedAmount <= 0) throw new Error('入账金额必须大于 0')

  const { data, error } = await withTimeout(
    supabase.rpc('create_store_deposit', {
      p_store_id: storeId,
      p_amount: normalizedAmount,
      p_deposit_date: normalizedDate,
      p_note: note || null,
    }),
    10000,
    '创建店铺入账'
  )
  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const balanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', storeId).single(),
    10000,
    '读取店铺余额'
  )
  if (balanceRes.error) throw balanceRes.error
  const oldBalance = Number(balanceRes.data?.balance || 0)

  const insertRes = await withTimeout(
    supabase
      .from('store_deposits')
      .insert({
        account_id: storeId,
        amount: normalizedAmount,
        deposit_date: normalizedDate,
        note: note || null,
        status: 'completed',
      })
      .select('id')
      .single(),
    10000,
    '写入店铺入账记录'
  )
  if (insertRes.error) throw insertRes.error

  try {
    const balanceResult = await applyAccountBalanceDelta({
      accountId: storeId,
      delta: normalizedAmount,
      reason: '店铺入账',
      refType: 'store_deposit',
      refId: insertRes.data.id,
    })

    return {
      deposit_id: insertRes.data.id,
      amount: normalizedAmount,
      store_old_balance: oldBalance,
      store_new_balance: Number(balanceResult?.new_balance || oldBalance + normalizedAmount),
      deposit_date: normalizedDate,
    }
  } catch (balanceError) {
    await supabase.from('store_deposits').delete().eq('id', insertRes.data.id)
    throw balanceError
  }
}

export async function revertStoreDepositWithFallback(depositId, reason = '') {
  if (!depositId) throw new Error('未指定入账记录')

  const { data, error } = await withTimeout(
    supabase.rpc('revert_store_deposit', {
      p_id: depositId,
      p_reason: reason || null,
    }),
    10000,
    '撤销店铺入账'
  )
  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const depositRes = await withTimeout(
    supabase.from('store_deposits').select('*').eq('id', depositId).single(),
    10000,
    '读取店铺入账记录'
  )
  if (depositRes.error || !depositRes.data) throw depositRes.error || new Error('入账记录不存在')
  const deposit = depositRes.data

  if (deposit.deleted_at) throw new Error('这笔入账已经撤销过了')
  if (deposit.status && deposit.status !== 'completed') {
    throw new Error(`当前状态不允许撤销：${deposit.status}`)
  }

  const balanceRes = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', deposit.account_id).single(),
    10000,
    '读取店铺余额'
  )
  if (balanceRes.error) throw balanceRes.error
  const oldBalance = Number(balanceRes.data?.balance || 0)
  const amount = Number(deposit.amount || 0)

  if (oldBalance + 0.0001 < amount) {
    throw new Error(`店铺余额不足，无法撤销入账：当前 ¥${oldBalance.toFixed(2)}，需要扣回 ¥${amount.toFixed(2)}`)
  }

  const balanceResult = await applyAccountBalanceDelta({
    accountId: deposit.account_id,
    delta: -amount,
    reason: '撤销店铺入账',
    refType: 'store_deposit',
    refId: depositId,
  })

  try {
    const baseUpdate = {
      status: 'cancelled',
      note: [deposit.note, reason || '[系统撤销] 店铺入账已撤回'].filter(Boolean).join(' | ') || null,
    }

    const updateRes = await withTimeout(
      supabase
        .from('store_deposits')
        .update({
          ...baseUpdate,
          deleted_at: new Date().toISOString(),
        })
        .eq('id', depositId),
      10000,
      '标记店铺入账撤销'
    )

    if (updateRes.error && isMissingColumn(updateRes.error)) {
      const fallbackRes = await withTimeout(
        supabase.from('store_deposits').update(baseUpdate).eq('id', depositId),
        10000,
        '标记店铺入账撤销'
      )
      if (fallbackRes.error) throw fallbackRes.error
    } else if (updateRes.error) {
      throw updateRes.error
    }

    return {
      deposit_id: depositId,
      amount,
      store_old_balance: oldBalance,
      store_new_balance: Number(balanceResult?.new_balance || oldBalance - amount),
    }
  } catch (updateError) {
    await applyAccountBalanceDelta({
      accountId: deposit.account_id,
      delta: amount,
      reason: '撤销店铺入账失败回滚',
      refType: 'store_deposit',
      refId: depositId,
    })
    throw updateError
  }
}

export async function createAccountTransferWithFallback({
  fromAccountId,
  toAccountId,
  amount,
  fee = 0,
  feeMode = 'from_balance',
  note = null,
  transferDate = null,
}) {
  const normalizedAmount = Number(amount || 0)
  const normalizedFee = Number(fee || 0)
  const normalizedFeeMode = normalizedFee > 0 ? feeMode : 'from_balance'
  const transferAt = transferDate || new Date().toISOString()

  const { data, error } = await withTimeout(
    supabase.rpc('create_account_transfer', {
      p_from_account_id: fromAccountId,
      p_to_account_id: toAccountId,
      p_amount: normalizedAmount,
      p_fee: normalizedFee,
      p_fee_mode: normalizedFeeMode,
      p_note: note,
      p_transfer_date: transferAt,
    }),
    10000,
    '创建转账'
  )

  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const totalDebit = normalizedAmount + (normalizedFeeMode === 'from_balance' ? normalizedFee : 0)
  const actualCredit = normalizedAmount - (normalizedFeeMode === 'from_amount' ? normalizedFee : 0)

  const fromBalance = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', fromAccountId).single(),
    10000,
    '读取转出账户余额'
  )
  if (fromBalance.error) throw fromBalance.error
  const toBalance = await withTimeout(
    supabase.from('accounts').select('balance').eq('id', toAccountId).single(),
    10000,
    '读取转入账户余额'
  )
  if (toBalance.error) throw toBalance.error

  if (Number(fromBalance.data?.balance || 0) < totalDebit) {
    throw new Error(`余额不足：当前 ¥${Number(fromBalance.data?.balance || 0).toFixed(2)}，需要 ¥${totalDebit.toFixed(2)}`)
  }

  const { data: inserted, error: insertError } = await withTimeout(
    supabase
      .from('account_transfers')
      .insert({
        from_account_id: fromAccountId,
        to_account_id: toAccountId,
        amount: normalizedAmount,
        fee: normalizedFee,
        fee_mode: normalizedFeeMode,
        note,
        transfer_date: transferAt,
      })
      .select('id')
      .single(),
    10000,
    '写入转账记录'
  )
  if (insertError) throw insertError

  try {
    await applyAccountBalanceDelta({
      accountId: fromAccountId,
      delta: -totalDebit,
      reason: '创建转账扣款',
      refType: 'transfer',
      refId: inserted.id,
    })
    await applyAccountBalanceDelta({
      accountId: toAccountId,
      delta: actualCredit,
      reason: '创建转账到账',
      refType: 'transfer',
      refId: inserted.id,
    })
  } catch (balanceError) {
    await supabase.from('account_transfers').delete().eq('id', inserted.id)
    throw balanceError
  }

  return {
    transfer_id: inserted.id,
    from_account_id: fromAccountId,
    to_account_id: toAccountId,
    amount: normalizedAmount,
    fee: normalizedFee,
    fee_mode: normalizedFeeMode,
    note,
    transfer_date: transferAt,
    from_old_balance: Number(fromBalance.data?.balance || 0),
    from_new_balance: Number(fromBalance.data?.balance || 0) - totalDebit,
    to_old_balance: Number(toBalance.data?.balance || 0),
    to_new_balance: Number(toBalance.data?.balance || 0) + actualCredit,
    total_debit: totalDebit,
    actual_credit: actualCredit,
  }
}

export async function processRefundWithFallback(refundId) {
  const { data, error } = await withTimeout(
    supabase.rpc('process_refund', { p_refund_id: refundId }),
    10000,
    '审批退款'
  )
  if (error && !isMissingRpc(error)) throw error
  if (!error) return data

  const refundRes = await withTimeout(
    supabase.from('refunds').select('*').eq('id', refundId).single(),
    10000,
    '读取退款记录'
  )
  if (refundRes.error || !refundRes.data) throw refundRes.error || new Error('退款记录不存在')
  const refund = refundRes.data

  const approveRes = await withTimeout(
    supabase
      .from('refunds')
      .update({
        status: 'completed',
        approved_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
      })
      .eq('id', refundId),
    10000,
    '更新退款状态'
  )
  if (approveRes.error) throw approveRes.error

  let accountNewBalance = null
  let accountOldBalance = null
  if (refund.refund_from_account_id) {
    const balanceResult = await applyAccountBalanceDelta({
      accountId: refund.refund_from_account_id,
      delta: -Number(refund.refund_amount || 0),
      reason: '退款审批扣款',
      refType: 'refund',
      refId: refundId,
    })
    accountOldBalance = balanceResult.old_balance
    accountNewBalance = balanceResult.new_balance
  }

  let orderStatus = null
  if (refund.order_id) {
    const refundRowsRes = await withTimeout(
      supabase
        .from('refunds')
        .select('refund_amount')
        .eq('order_id', refund.order_id)
        .eq('status', 'completed')
        .is('deleted_at', null),
      10000,
      '统计订单退款'
    )
    if (refundRowsRes.error) throw refundRowsRes.error

    const orderRes = await withTimeout(
      supabase.from('orders').select('amount, payment_amount').eq('id', refund.order_id).single(),
      10000,
      '读取订单金额'
    )
    if (orderRes.error) throw orderRes.error

    const totalRefunded = (refundRowsRes.data || []).reduce((sum, item) => sum + Number(item.refund_amount || 0), 0)
    const orderAmount = Number(orderRes.data?.payment_amount ?? orderRes.data?.amount ?? 0)
    orderStatus = totalRefunded >= orderAmount ? 'refunded' : 'partially_refunded'

    const orderUpdateRes = await withTimeout(
      supabase.from('orders').update({ status: orderStatus }).eq('id', refund.order_id),
      10000,
      '更新订单退款状态'
    )
    if (orderUpdateRes.error) throw orderUpdateRes.error
  }

  return {
    refund_id: refund.id,
    order_id: refund.order_id,
    refund_amount: refund.refund_amount,
    refund_from_account_id: refund.refund_from_account_id,
    account_old_balance: accountOldBalance,
    account_new_balance: accountNewBalance,
    order_status: orderStatus,
  }
}
