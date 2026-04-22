// ══════════════════════════════════════════════════════════
// 店铺提现 共享业务逻辑
// 一次提现 = 事务优先 / 前端兼容兜底：
//   1) 优先走数据库 RPC（单事务）
//   2) 若线上库尚未迁移，则退回前端兼容流程
//   3) 无论哪条路，最终都产出同一套余额结果 + 日志
//
// 给调用者：Ecommerce.vue / Expenses.vue 智能记账里的"店铺提现"卡片
// 两端共用这把刀，数值/余额/手续费一致，单点修改
// ══════════════════════════════════════════════════════════

import { supabase } from './supabase'
import { createStoreWithdrawalWithFallback } from './financeTransactions'
import { logOperation } from '../utils/operationLogger'

/**
 * 执行一次店铺提现
 * @param {Object} params
 * @param {string} params.storeId          店铺账户 id（必填）
 * @param {string} params.storeName        店铺简称（用于 payee/日志）
 * @param {string} params.toAccountId      到账账户 id（必填）
 * @param {string} [params.toAccountName]  到账账户简称（仅用于日志文案）
 * @param {number} params.amount           实际到账金额（必填，>0）
 * @param {number} [params.feeAmount]      手续费金额，默认 0
 * @param {string} [params.feeRemark]      手续费备注，默认"手续费"
 * @param {string} [params.remark]         整笔提现备注
 * @returns {Promise<{
 *   totalDeduct: number,
 *   oldStoreBalance: number,
 *   newStoreBalance: number,
 *   oldTargetBalance: number,
 *   newTargetBalance: number,
 *   withdrawalId: string | null,
 * }>}
 */
export async function performStoreWithdrawal({
  storeId,
  storeName,
  toAccountId,
  toAccountName = '',
  amount,
  feeAmount = 0,
  feeRemark = '',
  remark = '',
}) {
  if (!storeId) throw new Error('未指定店铺账户')
  if (!toAccountId) throw new Error('未指定到账账户')
  const arriveAmount = Number(amount) || 0
  if (arriveAmount <= 0) throw new Error('到账金额必须大于 0')
  const fee = Number(feeAmount) || 0
  const result = await createStoreWithdrawalWithFallback({
    storeId,
    toAccountId,
    amount: arriveAmount,
    feeAmount: fee,
    feeRemark,
    remark,
    storeName,
  })

  const totalDeduct = Number(result?.total_deduct || arriveAmount + fee)
  const oldStoreBalance = Number(result?.store_old_balance || 0)
  const newStoreBalance = Number(result?.store_new_balance || 0)
  const oldTargetBalance = Number(result?.to_old_balance || 0)
  const newTargetBalance = Number(result?.to_new_balance || 0)
  const withdrawalId = result?.withdrawal_id || null

  // ── 5. 操作日志（双端） ─────────────────────────────
  const remarkText = remark ? `（${remark}）` : ''
  const feeText = fee > 0 ? `，手续费 ¥${fee.toFixed(2)}` : ''
  const targetLabel = toAccountName || ''
  try {
    await logOperation({
      action: 'ecommerce_withdrawal',
      module: '电商提现',
      description: `电商提现：${storeName || ''} → ¥${arriveAmount.toFixed(2)} 到 ${targetLabel}${feeText}${remarkText}`,
      amount: -totalDeduct,
      accountId: storeId,
      accountName: storeName || '',
      balanceBefore: oldStoreBalance,
      balanceAfter: newStoreBalance,
      detail: {
        type: 'store_deduct',
        withdrawAmount: arriveAmount,
        feeAmount: fee,
        feeRemark,
        toAccount: targetLabel,
        remark,
        withdrawalId,
      },
    })
    await logOperation({
      action: 'ecommerce_withdrawal_income',
      module: '电商提现',
      description: `电商提现到账：${targetLabel} ← ${storeName || ''} ¥${arriveAmount.toFixed(2)}${remarkText}`,
      amount: arriveAmount,
      accountId: toAccountId,
      accountName: targetLabel,
      balanceBefore: oldTargetBalance,
      balanceAfter: newTargetBalance,
      detail: {
        type: 'account_income',
        fromStore: storeName || '',
        fromStoreId: storeId,
        remark,
        withdrawalId,
      },
    })
  } catch {
    // 日志失败不阻断主流程
  }

  // ── 6. 首次提现自动记忆默认到账账户 ─────────────────
  // 店铺之前从未设过默认提现账户 → 把这次选的账户写入 default_withdraw_account_id
  // 新字段查询失败（schema cache 未同步等）时静默跳过，不影响主流程
  let defaultTargetSaved = false
  try {
    const { data: metaRow, error: metaErr } = await supabase
      .from('accounts')
      .select('default_withdraw_account_id')
      .eq('id', storeId)
      .single()
    if (!metaErr && metaRow && !metaRow.default_withdraw_account_id) {
      const { error: dfErr } = await supabase
        .from('accounts')
        .update({ default_withdraw_account_id: toAccountId })
        .eq('id', storeId)
      if (!dfErr) defaultTargetSaved = true
    }
  } catch {
    // 记忆失败不影响主流程
  }

  return {
    totalDeduct,
    oldStoreBalance,
    newStoreBalance,
    oldTargetBalance,
    newTargetBalance,
    withdrawalId,
    defaultTargetSaved,
  }
}
