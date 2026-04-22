import { supabase } from './supabase'
import { dayEnd, dayStart } from '../utils/dateRange'

export const ACCOUNT_FLOW_META = {
  order: {
    label: '订单',
    chipClass: 'bg-green-100 text-green-700',
    ledgerLabel: '收入',
    ledgerClass: 'bg-green-50 text-green-700',
  },
  expense: {
    label: '支出',
    chipClass: 'bg-red-100 text-red-600',
    ledgerLabel: '支出',
    ledgerClass: 'bg-red-50 text-red-700',
  },
  refund: {
    label: '退款',
    chipClass: 'bg-orange-100 text-orange-600',
    ledgerLabel: '退款',
    ledgerClass: 'bg-orange-50 text-orange-700',
  },
  transfer_in: {
    label: '转入',
    chipClass: 'bg-blue-100 text-blue-700',
    ledgerLabel: '转入',
    ledgerClass: 'bg-blue-50 text-blue-700',
  },
  transfer_out: {
    label: '转出',
    chipClass: 'bg-blue-50 text-blue-500',
    ledgerLabel: '转出',
    ledgerClass: 'bg-orange-50 text-orange-700',
  },
  withdrawal_in: {
    label: '提现到账',
    chipClass: 'bg-teal-100 text-teal-700',
    ledgerLabel: '提现到账',
    ledgerClass: 'bg-teal-50 text-teal-700',
  },
  withdrawal_out: {
    label: '店铺提现',
    chipClass: 'bg-purple-100 text-purple-700',
    ledgerLabel: '店铺提现',
    ledgerClass: 'bg-purple-50 text-purple-700',
  },
  store_deposit: {
    label: '店铺入账',
    chipClass: 'bg-emerald-100 text-emerald-700',
    ledgerLabel: '店铺入账',
    ledgerClass: 'bg-emerald-50 text-emerald-700',
  },
  adjust_in: {
    label: '调整入账',
    chipClass: 'bg-amber-100 text-amber-700',
    ledgerLabel: '调整入账',
    ledgerClass: 'bg-amber-50 text-amber-700',
  },
  adjust_out: {
    label: '调整扣减',
    chipClass: 'bg-amber-100 text-amber-700',
    ledgerLabel: '调整扣减',
    ledgerClass: 'bg-amber-50 text-amber-700',
  },
  loan_in: {
    label: '股东借入',
    chipClass: 'bg-indigo-100 text-indigo-700',
    ledgerLabel: '股东借入',
    ledgerClass: 'bg-indigo-50 text-indigo-700',
  },
  repay_out: {
    label: '借款还出',
    chipClass: 'bg-indigo-50 text-indigo-500',
    ledgerLabel: '借款还出',
    ledgerClass: 'bg-indigo-50 text-indigo-700',
  },
  dividend_out: {
    label: '分红',
    chipClass: 'bg-rose-100 text-rose-600',
    ledgerLabel: '分红',
    ledgerClass: 'bg-rose-50 text-rose-700',
  },
}

function flowMeta(type) {
  return ACCOUNT_FLOW_META[type] || {
    label: type,
    chipClass: 'bg-gray-100 text-gray-600',
    ledgerLabel: type,
    ledgerClass: 'bg-gray-100 text-gray-600',
  }
}

export function getAccountFlowTypeLabel(type) {
  return flowMeta(type).label
}

export function getAccountFlowTypeClass(type) {
  return flowMeta(type).chipClass
}

function buildTimestampOr(primaryField, fallbackField, fromIso, toIso) {
  return `and(${primaryField}.gte.${fromIso},${primaryField}.lte.${toIso}),and(${primaryField}.is.null,${fallbackField}.gte.${fromIso},${fallbackField}.lte.${toIso})`
}

function byNewest(a, b) {
  return new Date(b.flow_at) - new Date(a.flow_at)
}

function toLedgerRecord(flow) {
  const meta = flowMeta(flow.type)
  const detail = [flow.summary, flow.sub].filter(Boolean).join(' · ')
  return {
    id: flow.key,
    created_at: flow.flow_at,
    type: flow.type,
    typeLabel: meta.ledgerLabel,
    typeClass: meta.ledgerClass,
    amount: flow.direction === 'in' ? Number(flow.abs_amount || 0) : -Number(flow.abs_amount || 0),
    detail,
  }
}

async function loadIncomingFlows(accountId, fromIso, toIso) {
  const tasks = []

  tasks.push(
    supabase
      .from('orders')
      .select('id, order_no, customer_name, amount, payment_amount, paid_at, created_at, note, status')
      .eq('account_id', accountId)
      .is('deleted_at', null)
      .in('status', ['completed', 'partially_refunded'])
      .or(buildTimestampOr('paid_at', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `order-${row.id}`,
          type: 'order',
          direction: 'in',
          flow_at: row.paid_at || row.created_at,
          abs_amount: Number(row.payment_amount ?? row.amount ?? 0),
          summary: `${row.order_no || '—'} · ${row.customer_name || ''}`.trim(),
          sub: row.note || '',
          editable: true,
          table: 'orders',
          id: row.id,
          amountField: 'amount',
          dateField: row.paid_at ? 'paid_at' : 'created_at',
          noteField: 'note',
          balanceSync: 'order',
          primaryAcc: accountId,
          sourceRoute: { name: 'Orders' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('account_transfers')
      .select('id, amount, fee, from_account_id, to_account_id, transfer_date, created_at, note, from_account:from_account_id(short_name,code)')
      .eq('to_account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .or(buildTimestampOr('transfer_date', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `trin-${row.id}`,
          type: 'transfer_in',
          direction: 'in',
          flow_at: row.transfer_date || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: `从 ${row.from_account?.short_name || row.from_account?.code || '—'} 转入`,
          sub: row.note || '',
          editable: true,
          table: 'account_transfers',
          id: row.id,
          amountField: 'amount',
          dateField: row.transfer_date ? 'transfer_date' : 'created_at',
          noteField: 'note',
          balanceSync: 'transfer',
          primaryAcc: row.to_account_id,
          secondaryAcc: row.from_account_id,
          sourceRoute: { name: 'Transfers' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('withdrawals')
      .select('id, amount, actual_arrival, fee_detail, account_id, to_account_id, withdrawn_at, created_at, remark, store_name, account:account_id(short_name,code)')
      .eq('to_account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .or(buildTimestampOr('withdrawn_at', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `wdin-${row.id}`,
          type: 'withdrawal_in',
          direction: 'in',
          flow_at: row.withdrawn_at || row.created_at,
          abs_amount: Number(row.actual_arrival ?? row.amount ?? 0),
          summary: `${row.account?.short_name || row.store_name || '店铺'} 提现到账`,
          sub: row.remark || '',
          editable: true,
          table: 'withdrawals',
          id: row.id,
          amountField: 'actual_arrival',
          dateField: row.withdrawn_at ? 'withdrawn_at' : 'created_at',
          noteField: 'remark',
          balanceSync: 'withdrawal',
          primaryAcc: row.to_account_id,
          secondaryAcc: row.account_id,
          _old_amount: Number(row.amount || 0),
          _old_actual: Number(row.actual_arrival ?? row.amount ?? 0),
          sourceRoute: { name: 'Ecommerce', query: { store: row.account_id, detail: '1' } },
        }))
      })
  )

  tasks.push(
    supabase
      .from('store_deposits')
      .select('id, amount, deposit_date, created_at, note, account_id')
      .eq('account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .gte('deposit_date', fromIso)
      .lte('deposit_date', toIso)
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `dep-${row.id}`,
          type: 'store_deposit',
          direction: 'in',
          flow_at: row.deposit_date || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: `财务入账${row.note ? `：${row.note}` : ''}`,
          sub: '',
          editable: true,
          table: 'store_deposits',
          id: row.id,
          amountField: 'amount',
          dateField: 'deposit_date',
          noteField: 'note',
          balanceSync: 'deposit',
          primaryAcc: accountId,
          sourceRoute: { name: 'Ecommerce', query: { store: accountId, detail: '1' } },
        }))
      })
  )

  tasks.push(
    supabase
      .from('manual_adjustments')
      .select('id, amount, adjustment_date, created_at, note')
      .eq('account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .gt('amount', 0)
      .gte('adjustment_date', fromIso)
      .lte('adjustment_date', toIso)
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `adj-${row.id}`,
          type: 'adjust_in',
          direction: 'in',
          flow_at: row.adjustment_date || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: row.note || '手动调整',
          sub: '',
          editable: true,
          table: 'manual_adjustments',
          id: row.id,
          amountField: 'amount',
          dateField: 'adjustment_date',
          noteField: 'note',
          balanceSync: 'adjust',
          primaryAcc: accountId,
        }))
      })
  )

  tasks.push(
    supabase
      .from('shareholder_loans')
      .select('id, loan_amount, start_date, created_at, receive_account_id')
      .eq('receive_account_id', accountId)
      .is('deleted_at', null)
      .gte('start_date', fromIso.slice(0, 10))
      .lte('start_date', toIso.slice(0, 10))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `loan-${row.id}`,
          type: 'loan_in',
          direction: 'in',
          flow_at: row.start_date || row.created_at,
          abs_amount: Number(row.loan_amount || 0),
          summary: '股东借款入账',
          sub: '',
          editable: false,
          table: 'shareholder_loans',
          id: row.id,
          sourceRoute: { name: 'ShareholderLoans' },
        }))
      })
  )

  const results = await Promise.all(tasks)
  return results.flat()
}

async function loadOutgoingFlows(accountId, fromIso, toIso) {
  const tasks = []

  tasks.push(
    supabase
      .from('expenses')
      .select('id, amount, payee, category, paid_at, created_at, note, status')
      .eq('account_id', accountId)
      .eq('status', 'paid')
      .is('deleted_at', null)
      .or(buildTimestampOr('paid_at', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `exp-${row.id}`,
          type: 'expense',
          direction: 'out',
          flow_at: row.paid_at || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: `${row.category || ''} · ${row.payee || ''}`.trim().replace(/^·\s*/, ''),
          sub: row.note || '',
          editable: true,
          table: 'expenses',
          id: row.id,
          amountField: 'amount',
          dateField: row.paid_at ? 'paid_at' : 'created_at',
          noteField: 'note',
          balanceSync: 'expense',
          primaryAcc: accountId,
          sourceRoute: { name: 'Expenses' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('refunds')
      .select('id, refund_no, refund_amount, reason, refund_from_account_id, paid_at, created_at, note, status')
      .eq('refund_from_account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .or(buildTimestampOr('paid_at', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `rfnd-${row.id}`,
          type: 'refund',
          direction: 'out',
          flow_at: row.paid_at || row.created_at,
          abs_amount: Number(row.refund_amount || 0),
          summary: `${row.refund_no || '—'} · ${row.reason || ''}`.trim(),
          sub: row.note || '',
          editable: true,
          table: 'refunds',
          id: row.id,
          amountField: 'refund_amount',
          dateField: row.paid_at ? 'paid_at' : 'created_at',
          noteField: 'note',
          balanceSync: 'refund',
          primaryAcc: accountId,
          sourceRoute: { name: 'Orders' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('account_transfers')
      .select('id, amount, fee, from_account_id, to_account_id, transfer_date, created_at, note, to_account:to_account_id(short_name,code)')
      .eq('from_account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .or(buildTimestampOr('transfer_date', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `trout-${row.id}`,
          type: 'transfer_out',
          direction: 'out',
          flow_at: row.transfer_date || row.created_at,
          abs_amount: Number(row.amount || 0) + Number(row.fee || 0),
          summary: `转出到 ${row.to_account?.short_name || row.to_account?.code || '—'}${Number(row.fee) > 0 ? `（含手续费 ¥${row.fee}）` : ''}`,
          sub: row.note || '',
          editable: true,
          table: 'account_transfers',
          id: row.id,
          amountField: 'amount',
          dateField: row.transfer_date ? 'transfer_date' : 'created_at',
          noteField: 'note',
          balanceSync: 'transfer_out',
          primaryAcc: row.from_account_id,
          secondaryAcc: row.to_account_id,
          _fee: Number(row.fee || 0),
          sourceRoute: { name: 'Transfers' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('withdrawals')
      .select('id, amount, actual_arrival, fee_detail, account_id, to_account_id, withdrawn_at, created_at, remark, store_name, to_account:to_account_id(short_name,code)')
      .eq('account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .or(buildTimestampOr('withdrawn_at', 'created_at', fromIso, toIso))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `wdout-${row.id}`,
          type: 'withdrawal_out',
          direction: 'out',
          flow_at: row.withdrawn_at || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: `提现到 ${row.to_account?.short_name || row.to_account?.code || '—'}`,
          sub: row.remark || '',
          editable: true,
          table: 'withdrawals',
          id: row.id,
          amountField: 'amount',
          dateField: row.withdrawn_at ? 'withdrawn_at' : 'created_at',
          noteField: 'remark',
          balanceSync: 'withdrawal_out',
          primaryAcc: row.account_id,
          secondaryAcc: row.to_account_id,
          _old_actual: Number(row.actual_arrival ?? row.amount ?? 0),
          sourceRoute: { name: 'Ecommerce', query: { store: row.account_id, detail: '1' } },
        }))
      })
  )

  tasks.push(
    supabase
      .from('manual_adjustments')
      .select('id, amount, adjustment_date, created_at, note')
      .eq('account_id', accountId)
      .eq('status', 'completed')
      .is('deleted_at', null)
      .lt('amount', 0)
      .gte('adjustment_date', fromIso)
      .lte('adjustment_date', toIso)
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `adjn-${row.id}`,
          type: 'adjust_out',
          direction: 'out',
          flow_at: row.adjustment_date || row.created_at,
          abs_amount: Math.abs(Number(row.amount || 0)),
          summary: row.note || '手动调整',
          sub: '',
          editable: true,
          table: 'manual_adjustments',
          id: row.id,
          amountField: 'amount',
          dateField: 'adjustment_date',
          noteField: 'note',
          balanceSync: 'adjust_neg',
          primaryAcc: accountId,
        }))
      })
  )

  tasks.push(
    supabase
      .from('loan_repayments')
      .select('id, repayment_amount, repayment_date, created_at, account_id')
      .eq('account_id', accountId)
      .is('deleted_at', null)
      .gte('repayment_date', fromIso.slice(0, 10))
      .lte('repayment_date', toIso.slice(0, 10))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `repay-${row.id}`,
          type: 'repay_out',
          direction: 'out',
          flow_at: row.repayment_date || row.created_at,
          abs_amount: Number(row.repayment_amount || 0),
          summary: '股东借款还款',
          sub: '',
          editable: false,
          table: 'loan_repayments',
          id: row.id,
          sourceRoute: { name: 'ShareholderLoans' },
        }))
      })
  )

  tasks.push(
    supabase
      .from('dividends')
      .select('id, amount, pay_date, created_at, account_id')
      .eq('account_id', accountId)
      .is('deleted_at', null)
      .gte('pay_date', fromIso.slice(0, 10))
      .lte('pay_date', toIso.slice(0, 10))
      .then(({ data, error }) => {
        if (error) throw error
        return (data || []).map((row) => ({
          key: `div-${row.id}`,
          type: 'dividend_out',
          direction: 'out',
          flow_at: row.pay_date || row.created_at,
          abs_amount: Number(row.amount || 0),
          summary: '股东分红',
          sub: '',
          editable: false,
          table: 'dividends',
          id: row.id,
          sourceRoute: { name: 'Dividends' },
        }))
      })
  )

  const results = await Promise.all(tasks)
  return results.flat()
}

export async function loadAccountFlows({ accountId, from, to, direction }) {
  const fromIso = dayStart(from) || '1970-01-01T00:00:00+08:00'
  const toIso = dayEnd(to) || '2999-12-31T23:59:59.999+08:00'
  if (!accountId) return []

  const flowList = direction === 'out'
    ? await loadOutgoingFlows(accountId, fromIso, toIso)
    : await loadIncomingFlows(accountId, fromIso, toIso)

  return flowList.sort(byNewest)
}

export async function loadAccountLedgerRecords({ accountId, dateFrom, dateTo }) {
  if (!accountId) return []

  const [incoming, outgoing] = await Promise.all([
    loadAccountFlows({ accountId, from: dateFrom, to: dateTo, direction: 'in' }),
    loadAccountFlows({ accountId, from: dateFrom, to: dateTo, direction: 'out' }),
  ])

  return [...incoming, ...outgoing]
    .map(toLedgerRecord)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
}

export async function loadAccountDrilldown({ accountId, from, to }) {
  if (!accountId) {
    return { orders: [], expenses: [], refunds: [], transfers: [] }
  }

  const [incoming, outgoing] = await Promise.all([
    loadAccountFlows({ accountId, from, to, direction: 'in' }),
    loadAccountFlows({ accountId, from, to, direction: 'out' }),
  ])

  return {
    orders: incoming.filter((item) => item.type === 'order'),
    expenses: outgoing.filter((item) => item.type === 'expense'),
    refunds: outgoing.filter((item) => item.type === 'refund'),
    transfers: [...incoming, ...outgoing]
      .filter((item) => item.type === 'transfer_in' || item.type === 'transfer_out')
      .sort(byNewest),
  }
}
