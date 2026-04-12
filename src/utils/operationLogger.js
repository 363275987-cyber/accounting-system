import { supabase } from '../lib/supabase'

/**
 * 记录操作日志（尽力而为，失败不影响主流程）
 * @param {Object} params
 * @param {string} params.action - 操作类型：create_order, delete_order, pay_expense, transfer, refund 等
 * @param {string} params.module - 模块：订单, 支出, 转账, 退款
 * @param {string} params.description - 人类可读的中文描述
 * @param {Object} [params.detail={}] - 结构化详情
 * @param {number|null} [params.amount=null] - 涉及金额
 * @param {string|null} [params.accountId=null] - 涉及账户ID
 * @param {string|null} [params.accountName=null] - 涉及账户名称
 * @param {number|null} [params.balanceBefore=null] - 操作前余额
 * @param {number|null} [params.balanceAfter=null] - 操作后余额
 */
export async function logOperation({
  action,
  module,
  description,
  detail = {},
  amount = null,
  accountId = null,
  accountName = null,
  balanceBefore = null,
  balanceAfter = null,
}) {
  try {
    const { data: { session } } = await supabase.auth.getSession()
    // 从 profiles 表获取真实姓名
    let userName = session?.user?.user_metadata?.full_name || ''
    if (!userName && session?.user?.id) {
      const { data: profile } = await supabase.from('profiles').select('name, phone').eq('id', session.user.id).single()
      if (profile) {
        userName = profile.name || profile.phone || ''
      }
    }
    if (!userName) userName = session?.user?.email || '未知'
    await supabase.from('operation_logs').insert({
      user_id: session?.user?.id,
      user_name: userName,
      action,
      module,
      description,
      detail,
      amount,
      account_id: accountId,
      account_name: accountName,
      balance_before: balanceBefore,
      balance_after: balanceAfter,
    })
  } catch (e) {
    console.warn('日志记录失败:', e)
  }
}

/**
 * 获取账户当前余额（用于记录 balance_before / balance_after）
 */
export async function getAccountBalance(accountId) {
  if (!accountId) return null
  try {
    const { data } = await supabase
      .from('accounts')
      .select('balance, code, short_name')
      .eq('id', accountId)
      .single()
    return data ? { balance: Number(data.balance || 0), name: data.short_name || data.code } : null
  } catch (e) {
    return null
  }
}

/**
 * 格式化金额为中文描述
 */
export function formatMoneyStr(amount) {
  if (amount == null) return ''
  return `¥${Number(amount).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
