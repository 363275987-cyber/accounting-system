// ══════════════════════════════════════════════════════════
// 店铺提现 共享业务逻辑
// 一次提现 = 5 步：
//   1) 读 + 更新 店铺(源)账户余额（底线 0）
//   2) 读 + 更新 目标账户余额
//   3) 若手续费 > 0：写 expenses 一条（电商手续费）
//   4) 写 withdrawals 明细
//   5) 写双端 operation log（调用方提供 logger 即可）
//
// 给调用者：Ecommerce.vue / Expenses.vue 智能记账里的"店铺提现"卡片
// 两端共用这把刀，数值/余额/手续费一致，单点修改
// ══════════════════════════════════════════════════════════

import { supabase } from './supabase'
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
  const totalDeduct = arriveAmount + fee

  // ── 1. 店铺余额扣款（底线 0）─────────────────────────
  // 顺便读出 default_withdraw_account_id，用于"第一次提现自动记默认"
  const { data: storeAcc, error: e1 } = await supabase
    .from('accounts')
    .select('balance, default_withdraw_account_id')
    .eq('id', storeId)
    .single()
  if (e1) throw new Error('读取店铺余额失败: ' + (e1.message || ''))

  const oldStoreBalance = Number(storeAcc.balance || 0)
  const newStoreBalance = Math.max(0, oldStoreBalance - totalDeduct)
  const { error: e2 } = await supabase
    .from('accounts')
    .update({ balance: newStoreBalance })
    .eq('id', storeId)
  if (e2) throw new Error('更新店铺余额失败: ' + (e2.message || ''))

  // ── 2. 目标账户加钱 ────────────────────────────────
  const { data: targetAcc, error: e3 } = await supabase
    .from('accounts')
    .select('balance')
    .eq('id', toAccountId)
    .single()
  if (e3) throw new Error('读取到账账户余额失败: ' + (e3.message || ''))

  const oldTargetBalance = Number(targetAcc.balance || 0)
  const newTargetBalance = oldTargetBalance + arriveAmount
  const { error: e4 } = await supabase
    .from('accounts')
    .update({ balance: newTargetBalance })
    .eq('id', toAccountId)
  if (e4) throw new Error('更新到账账户余额失败: ' + (e4.message || ''))

  // ── 3. 手续费记支出 ────────────────────────────────
  if (fee > 0) {
    try {
      const { data: { session } } = await supabase.auth.getSession()
      const userId = session?.user?.id
      const feeNote = feeRemark || `${storeName || ''} 提现手续费`
      const nowIso = new Date().toISOString()
      await supabase.from('expenses').insert({
        amount: fee,
        category: '电商手续费',
        payee: storeName || '提现',
        note: feeNote,
        status: 'paid',
        account_id: storeId,
        created_by: userId,
        approver_id: userId,
        approved_at: nowIso,
        paid_at: nowIso,
      })
    } catch (feeErr) {
      console.warn('[storeWithdrawal] 手续费支出写入失败:', feeErr)
      // 手续费记账失败不回滚主流程（与旧逻辑保持一致）
    }
  }

  // ── 4. withdrawals 明细 ───────────────────────────
  try {
    await supabase.from('withdrawals').insert({
      account_id: storeId,
      to_account_id: toAccountId,
      amount: totalDeduct,
      actual_arrival: arriveAmount,
      fee_detail: fee > 0 ? [{ amount: fee, label: feeRemark || '手续费' }] : [],
      store_name: storeName || '',
      remark: remark || '',
      status: 'completed',
    })
  } catch (wErr) {
    console.warn('[storeWithdrawal] withdrawals 明细写入失败:', wErr)
  }

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
      },
    })
  } catch (_) {
    // 日志失败不阻断主流程
  }

  // ── 6. 首次提现自动记忆默认到账账户 ─────────────────
  // 店铺之前从未设过默认提现账户 → 把这次选的账户写入 default_withdraw_account_id
  let defaultTargetSaved = false
  if (!storeAcc.default_withdraw_account_id) {
    try {
      const { error: dfErr } = await supabase
        .from('accounts')
        .update({ default_withdraw_account_id: toAccountId })
        .eq('id', storeId)
      if (!dfErr) defaultTargetSaved = true
    } catch (_) {
      // 记忆失败不影响主流程
    }
  }

  return {
    totalDeduct,
    oldStoreBalance,
    newStoreBalance,
    oldTargetBalance,
    newTargetBalance,
    defaultTargetSaved,
  }
}
