import { supabase, withTimeout } from './supabase'

async function getAccountStoreSafe() {
  try {
    const { useAccountStore } = await import('../stores/accounts')
    return useAccountStore()
  } catch {
    return null
  }
}

async function loadAccountMeta(accountId) {
  const store = await getAccountStoreSafe()
  const cached = store?.accounts?.find((item) => item.id === accountId)
  if (cached) return cached

  const { data, error } = await withTimeout(
    supabase
      .from('accounts')
      .select('id, balance, category, balance_method, short_name, code')
      .eq('id', accountId)
      .single(),
    10000,
    '读取账户余额信息'
  )
  if (error) throw error
  return data
}

async function syncAccountBalanceCache(accountId, newBalance) {
  if (newBalance == null) return
  const store = await getAccountStoreSafe()
  const idx = store?.accounts?.findIndex((item) => item.id === accountId) ?? -1
  if (idx >= 0) {
    store.accounts[idx].balance = Number(newBalance)
  }
}

async function refreshAccountBalance(accountId) {
  const { data, error } = await withTimeout(
    supabase
      .from('accounts')
      .select('balance')
      .eq('id', accountId)
      .single(),
    10000,
    '刷新账户余额'
  )
  if (error) throw error
  await syncAccountBalanceCache(accountId, data.balance)
  return Number(data.balance || 0)
}

export async function applyAccountBalanceDelta({
  accountId,
  delta,
  reason = '账户余额变动',
  refType = 'account',
  refId = null,
  skipManualEcommerceIncome = false,
}) {
  const amountDelta = Number(delta || 0)
  if (!accountId) throw new Error('缺少账户 id')

  const account = await loadAccountMeta(accountId)
  const currentBalance = Number(account?.balance || 0)

  if (amountDelta === 0) {
    return {
      skipped: true,
      old_balance: currentBalance,
      new_balance: currentBalance,
      account,
    }
  }

  if (
    skipManualEcommerceIncome &&
    amountDelta > 0 &&
    account?.category === 'ecommerce' &&
    account?.balance_method === 'manual'
  ) {
    return {
      skipped: true,
      old_balance: currentBalance,
      new_balance: currentBalance,
      account,
    }
  }

  const { data, error } = await withTimeout(
    supabase.rpc('increment_balance', {
      p_account_id: accountId,
      p_delta: amountDelta,
      p_reason: reason,
      p_ref_type: refType,
      p_ref_id: refId,
    }),
    10000,
    '更新账户余额'
  )
  if (error) throw error

  let oldBalance = data?.old_balance
  let newBalance = data?.new_balance

  if (newBalance == null && typeof data === 'number') {
    newBalance = data
  }
  if (oldBalance == null) {
    oldBalance = currentBalance
  }
  if (newBalance == null) {
    newBalance = await refreshAccountBalance(accountId)
  } else {
    await syncAccountBalanceCache(accountId, newBalance)
  }

  return {
    skipped: false,
    old_balance: Number(oldBalance || 0),
    new_balance: Number(newBalance || 0),
    account,
  }
}
