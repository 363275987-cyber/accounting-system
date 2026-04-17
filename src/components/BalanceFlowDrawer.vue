<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-black/30 z-50 flex justify-end" @click.self="$emit('close')">
      <div class="bg-white w-full max-w-2xl h-full shadow-2xl flex flex-col">
        <!-- Header -->
        <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <div>
            <h2 class="font-bold text-gray-800">
              {{ accountName }}
              <span class="ml-2 text-sm font-normal"
                :class="direction === 'in' ? 'text-green-600' : 'text-red-500'">
                {{ direction === 'in' ? '本期增加' : '本期减少' }}明细
              </span>
            </h2>
            <p class="text-xs text-gray-500 mt-0.5">{{ from }} ~ {{ to }} · 共 {{ flows.length }} 笔 · 合计 {{ direction === 'in' ? '+' : '-' }}{{ formatMoney(total) }}</p>
          </div>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto px-5 py-4 pb-24">
          <div v-if="loading" class="text-center py-12 text-gray-500">加载中…</div>
          <div v-else-if="flows.length === 0" class="text-center py-12 text-gray-400">
            <div class="text-3xl mb-2">📭</div>
            <p>该期间没有{{ direction === 'in' ? '增加' : '减少' }}流水</p>
          </div>
          <div v-else class="space-y-2">
            <div v-for="f in flows" :key="f.key"
              class="border border-gray-100 rounded-lg p-3 hover:bg-gray-50 transition">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="text-xs px-2 py-0.5 rounded-full shrink-0" :class="typeClass(f.type)">{{ typeLabel(f.type) }}</span>
                    <span class="text-xs text-gray-500">{{ formatDate(f.flow_at, 'datetime') }}</span>
                  </div>
                  <div class="text-sm text-gray-700 truncate">{{ f.summary }}</div>
                  <div v-if="f.sub" class="text-xs text-gray-400 mt-0.5 truncate">{{ f.sub }}</div>
                </div>
                <div class="shrink-0 text-right">
                  <div class="font-semibold"
                    :class="direction === 'in' ? 'text-green-600' : 'text-red-500'">
                    {{ direction === 'in' ? '+' : '-' }}{{ formatMoney(f.abs_amount) }}
                  </div>
                  <div class="mt-1 flex items-center gap-1 justify-end">
                    <button v-if="f.editable" @click="startEdit(f)"
                      class="text-xs px-2 py-0.5 border border-gray-200 rounded hover:bg-gray-100 cursor-pointer">✏️ 改</button>
                    <button v-if="f.sourceRoute" @click="gotoSource(f)"
                      class="text-xs px-2 py-0.5 border border-blue-200 text-blue-600 rounded hover:bg-blue-50 cursor-pointer">↗ 源页</button>
                    <button v-if="f.type === 'adjust_in' || f.type === 'adjust_out'" @click="revertAdjustment(f)"
                      class="text-xs px-2 py-0.5 border border-red-200 text-red-500 rounded hover:bg-red-50 cursor-pointer">撤销</button>
                  </div>
                </div>
              </div>

              <!-- Inline edit -->
              <div v-if="editingKey === f.key" class="mt-3 pt-3 border-t border-gray-100 bg-amber-50/40 -mx-3 -mb-3 px-3 pb-3 rounded-b-lg">
                <div class="grid grid-cols-2 gap-2 mb-2">
                  <div>
                    <label class="text-[11px] text-gray-500">金额</label>
                    <input v-model.number="editBuf.amount" type="number" step="0.01"
                      class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                  </div>
                  <div>
                    <label class="text-[11px] text-gray-500">日期</label>
                    <input v-model="editBuf.date" type="date"
                      class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                  </div>
                </div>
                <div class="mb-2">
                  <label class="text-[11px] text-gray-500">备注</label>
                  <input v-model="editBuf.note" type="text"
                    class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                </div>
                <div class="flex items-center gap-2">
                  <button @click="saveEdit(f)" :disabled="saving"
                    class="px-3 py-1 bg-amber-500 text-white rounded text-xs hover:bg-amber-600 disabled:opacity-50 cursor-pointer">
                    {{ saving ? '保存中…' : '保存' }}
                  </button>
                  <button @click="cancelEdit" class="px-3 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 cursor-pointer">取消</button>
                  <span class="text-[11px] text-gray-400 ml-auto">仅改金额/日期/备注，其他字段请到源页改</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer: 补录流水 -->
        <div class="shrink-0 border-t border-gray-100 bg-gray-50/50 px-5 py-3">
          <button v-if="!showAddForm" @click="openAddForm"
            class="w-full py-2 text-sm border border-dashed border-gray-300 rounded-lg text-gray-500 hover:bg-white hover:border-blue-300 hover:text-blue-600 cursor-pointer transition">
            + 补录一条{{ direction === 'in' ? addLabelIn : '支出' }}
          </button>
          <div v-else class="bg-white border border-amber-200 rounded-lg p-3 space-y-2">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-medium text-gray-700">{{ direction === 'in' ? addLabelIn : '补录支出' }}</span>
              <button @click="showAddForm = false" class="text-xs text-gray-400 hover:text-gray-600 cursor-pointer">取消</button>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="text-[11px] text-gray-500">金额</label>
                <input v-model.number="addBuf.amount" type="number" step="0.01" min="0" placeholder="0.00"
                  class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
              </div>
              <div>
                <label class="text-[11px] text-gray-500">日期</label>
                <input v-model="addBuf.date" type="date"
                  class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
              </div>
            </div>
            <div v-if="direction === 'in' && accountCategory !== 'ecommerce'">
              <label class="text-[11px] text-gray-500">客户名（选填）</label>
              <input v-model="addBuf.customerName" type="text" placeholder="客户名"
                class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
            </div>
            <div v-if="direction === 'out'">
              <label class="text-[11px] text-gray-500">收款方（选填）</label>
              <input v-model="addBuf.payee" type="text" placeholder="收款方"
                class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
            </div>
            <div>
              <label class="text-[11px] text-gray-500">备注</label>
              <input v-model="addBuf.note" type="text"
                class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
            </div>
            <div class="flex items-center gap-2">
              <button @click="saveAdd" :disabled="addSaving || !addBuf.amount || addBuf.amount <= 0"
                class="px-3 py-1 bg-amber-500 text-white rounded text-xs hover:bg-amber-600 disabled:opacity-50 cursor-pointer">
                {{ addSaving ? '保存中…' : '保存补录' }}
              </button>
              <span class="text-[11px] text-gray-400 ml-auto">{{ addHint }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { formatMoney, formatDate, toast } from '../lib/utils'

const props = defineProps({
  accountId: { type: String, required: true },
  accountName: { type: String, default: '' },
  accountCategory: { type: String, default: '' },
  from: { type: String, required: true },        // 'YYYY-MM-DD'
  to:   { type: String, required: true },
  direction: { type: String, required: true },   // 'in' | 'out'
})
const emit = defineEmits(['close', 'updated'])
const router = useRouter()

const loading = ref(false)
const flows = ref([])
const total = computed(() => flows.value.reduce((s, f) => s + Number(f.abs_amount || 0), 0))

const editingKey = ref(null)
const editBuf = ref({ amount: 0, date: '', note: '' })
const saving = ref(false)

// 时间范围：from 00:00 到 to 23:59:59（按东八区）
const fromIso = computed(() => new Date(props.from + 'T00:00:00+08:00').toISOString())
const toIso   = computed(() => new Date(props.to   + 'T23:59:59+08:00').toISOString())

function typeLabel(t) {
  return {
    order: '订单',
    expense: '支出',
    refund: '退款',
    transfer_in: '转入',
    transfer_out: '转出',
    withdrawal_out: '店铺提现',
    withdrawal_in: '提现到账',
    store_deposit: '店铺入账',
    adjust_in: '调整入账',
    adjust_out: '调整扣减',
    loan_in: '股东借入',
    repay_out: '借款还出',
    dividend_out: '分红',
  }[t] || t
}
function typeClass(t) {
  return {
    order:           'bg-green-100 text-green-700',
    expense:         'bg-red-100 text-red-600',
    refund:          'bg-orange-100 text-orange-600',
    transfer_in:     'bg-blue-100 text-blue-700',
    transfer_out:    'bg-blue-50 text-blue-500',
    withdrawal_in:   'bg-teal-100 text-teal-700',
    withdrawal_out:  'bg-purple-100 text-purple-700',
    store_deposit:   'bg-emerald-100 text-emerald-700',
    adjust_in:       'bg-amber-100 text-amber-700',
    adjust_out:      'bg-amber-100 text-amber-700',
    loan_in:         'bg-indigo-100 text-indigo-700',
    repay_out:       'bg-indigo-50 text-indigo-500',
    dividend_out:    'bg-rose-100 text-rose-600',
  }[t] || 'bg-gray-100 text-gray-600'
}

async function loadFlows() {
  loading.value = true
  flows.value = []
  try {
    const acc = props.accountId
    const isIn = props.direction === 'in'
    const tasks = []

    if (isIn) {
      // 订单收入
      tasks.push(supabase.from('orders')
        .select('id, order_no, customer_name, amount, paid_at, created_at, note, status')
        .eq('account_id', acc)
        .is('deleted_at', null)
        .in('status', ['completed', 'partially_refunded'])
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'order-' + r.id, type: 'order',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `${r.order_no || '—'} · ${r.customer_name || ''}`.trim(),
          sub: r.note || '',
          editable: true, table: 'orders', id: r.id,
          amountField: 'amount', dateField: r.paid_at ? 'paid_at' : 'created_at', noteField: 'note',
          balanceSync: 'order', primaryAcc: acc,
          sourceRoute: { name: 'Orders' },
        }))))

      // 转账转入
      tasks.push(supabase.from('account_transfers')
        .select('id, amount, fee, from_account_id, to_account_id, transfer_date, created_at, note, from_account:from_account_id(short_name,code)')
        .eq('to_account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .or(`and(transfer_date.gte.${fromIso.value},transfer_date.lte.${toIso.value}),and(transfer_date.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'trin-' + r.id, type: 'transfer_in',
          flow_at: r.transfer_date || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `从 ${r.from_account?.short_name || r.from_account?.code || '—'} 转入`,
          sub: r.note || '',
          editable: true, table: 'account_transfers', id: r.id,
          amountField: 'amount', dateField: r.transfer_date ? 'transfer_date' : 'created_at', noteField: 'note',
          balanceSync: 'transfer', primaryAcc: r.to_account_id, secondaryAcc: r.from_account_id,
          sourceRoute: { name: 'Transfers' },
        }))))

      // 店铺提现到账
      tasks.push(supabase.from('withdrawals')
        .select('id, amount, actual_arrival, fee_detail, account_id, to_account_id, withdrawn_at, created_at, remark, store_name, account:account_id(short_name,code)')
        .eq('to_account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .or(`and(withdrawn_at.gte.${fromIso.value},withdrawn_at.lte.${toIso.value}),and(withdrawn_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'wdin-' + r.id, type: 'withdrawal_in',
          flow_at: r.withdrawn_at || r.created_at,
          abs_amount: Number(r.actual_arrival ?? r.amount ?? 0),
          summary: `${r.account?.short_name || r.store_name || '店铺'} 提现到账`,
          sub: r.remark || '',
          editable: true, table: 'withdrawals', id: r.id,
          amountField: 'actual_arrival', dateField: r.withdrawn_at ? 'withdrawn_at' : 'created_at', noteField: 'remark',
          balanceSync: 'withdrawal', primaryAcc: r.to_account_id, secondaryAcc: r.account_id,
          _old_amount: Number(r.amount || 0), _old_actual: Number(r.actual_arrival ?? r.amount ?? 0),
          sourceRoute: { name: 'Ecommerce', query: { store: r.account_id, detail: '1' } },
        }))))

      // 店铺入账（财务手动）
      tasks.push(supabase.from('store_deposits')
        .select('id, amount, deposit_date, created_at, note, account_id')
        .eq('account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .gte('deposit_date', fromIso.value).lte('deposit_date', toIso.value)
        .then(({ data }) => (data || []).map(r => ({
          key: 'dep-' + r.id, type: 'store_deposit',
          flow_at: r.deposit_date || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: '财务入账' + (r.note ? '：' + r.note : ''),
          sub: '',
          editable: true, table: 'store_deposits', id: r.id,
          amountField: 'amount', dateField: 'deposit_date', noteField: 'note',
          balanceSync: 'deposit', primaryAcc: acc,
          sourceRoute: { name: 'Ecommerce', query: { store: acc, detail: '1' } },
        }))))

      // 手动调整(amount > 0 入账方向)
      tasks.push(supabase.from('manual_adjustments')
        .select('id, amount, adjustment_date, created_at, note')
        .eq('account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .gt('amount', 0)
        .gte('adjustment_date', fromIso.value).lte('adjustment_date', toIso.value)
        .then(({ data }) => (data || []).map(r => ({
          key: 'adj-' + r.id, type: 'adjust_in',
          flow_at: r.adjustment_date || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: r.note || '手动调整',
          sub: '',
          editable: true, table: 'manual_adjustments', id: r.id,
          amountField: 'amount', dateField: 'adjustment_date', noteField: 'note',
          balanceSync: 'adjust', primaryAcc: acc,
        }))))

      // 股东借入(收到钱)
      tasks.push(supabase.from('shareholder_loans')
        .select('id, loan_amount, start_date, created_at, receive_account_id')
        .eq('receive_account_id', acc).is('deleted_at', null)
        .gte('start_date', fromIso.value.slice(0,10)).lte('start_date', toIso.value.slice(0,10))
        .then(({ data }) => (data || []).map(r => ({
          key: 'loan-' + r.id, type: 'loan_in',
          flow_at: r.start_date || r.created_at,
          abs_amount: Number(r.loan_amount || 0),
          summary: '股东借款入账',
          sub: '',
          editable: false, table: 'shareholder_loans', id: r.id,
          sourceRoute: { name: 'ShareholderLoans' },
        }))))
    } else {
      // 支出
      tasks.push(supabase.from('expenses')
        .select('id, amount, payee, category, paid_at, created_at, note, status')
        .eq('account_id', acc).eq('status', 'paid').is('deleted_at', null)
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'exp-' + r.id, type: 'expense',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `${r.category || ''} · ${r.payee || ''}`.trim().replace(/^·\s*/, ''),
          sub: r.note || '',
          editable: true, table: 'expenses', id: r.id,
          amountField: 'amount', dateField: r.paid_at ? 'paid_at' : 'created_at', noteField: 'note',
          balanceSync: 'expense', primaryAcc: acc,
          sourceRoute: { name: 'Expenses' },
        }))))

      // 退款（退给客户）
      tasks.push(supabase.from('refunds')
        .select('id, refund_no, refund_amount, reason, refund_from_account_id, paid_at, created_at, note, status')
        .eq('refund_from_account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'rfnd-' + r.id, type: 'refund',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.refund_amount || 0),
          summary: `${r.refund_no || '—'} · ${r.reason || ''}`.trim(),
          sub: r.note || '',
          editable: true, table: 'refunds', id: r.id,
          amountField: 'refund_amount', dateField: r.paid_at ? 'paid_at' : 'created_at', noteField: 'note',
          balanceSync: 'refund', primaryAcc: acc,
          sourceRoute: { name: 'Orders' },
        }))))

      // 转账转出
      tasks.push(supabase.from('account_transfers')
        .select('id, amount, fee, from_account_id, to_account_id, transfer_date, created_at, note, to_account:to_account_id(short_name,code)')
        .eq('from_account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .or(`and(transfer_date.gte.${fromIso.value},transfer_date.lte.${toIso.value}),and(transfer_date.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'trout-' + r.id, type: 'transfer_out',
          flow_at: r.transfer_date || r.created_at,
          abs_amount: Number(r.amount || 0) + Number(r.fee || 0),
          summary: `转出到 ${r.to_account?.short_name || r.to_account?.code || '—'}${Number(r.fee) > 0 ? `（含手续费 ¥${r.fee}）` : ''}`,
          sub: r.note || '',
          editable: true, table: 'account_transfers', id: r.id,
          amountField: 'amount', dateField: r.transfer_date ? 'transfer_date' : 'created_at', noteField: 'note',
          balanceSync: 'transfer_out', primaryAcc: r.from_account_id, secondaryAcc: r.to_account_id,
          _fee: Number(r.fee || 0),
          sourceRoute: { name: 'Transfers' },
        }))))

      // 店铺提现扣款
      tasks.push(supabase.from('withdrawals')
        .select('id, amount, actual_arrival, fee_detail, account_id, to_account_id, withdrawn_at, created_at, remark, store_name, to_account:to_account_id(short_name,code)')
        .eq('account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .or(`and(withdrawn_at.gte.${fromIso.value},withdrawn_at.lte.${toIso.value}),and(withdrawn_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'wdout-' + r.id, type: 'withdrawal_out',
          flow_at: r.withdrawn_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `提现到 ${r.to_account?.short_name || r.to_account?.code || '—'}`,
          sub: r.remark || '',
          editable: true, table: 'withdrawals', id: r.id,
          amountField: 'amount', dateField: r.withdrawn_at ? 'withdrawn_at' : 'created_at', noteField: 'remark',
          balanceSync: 'withdrawal_out', primaryAcc: r.account_id, secondaryAcc: r.to_account_id,
          _old_actual: Number(r.actual_arrival ?? r.amount ?? 0),
          sourceRoute: { name: 'Ecommerce', query: { store: r.account_id, detail: '1' } },
        }))))

      // 手动调整(amount < 0 扣减方向)
      tasks.push(supabase.from('manual_adjustments')
        .select('id, amount, adjustment_date, created_at, note')
        .eq('account_id', acc).eq('status', 'completed').is('deleted_at', null)
        .lt('amount', 0)
        .gte('adjustment_date', fromIso.value).lte('adjustment_date', toIso.value)
        .then(({ data }) => (data || []).map(r => ({
          key: 'adjn-' + r.id, type: 'adjust_out',
          flow_at: r.adjustment_date || r.created_at,
          abs_amount: Math.abs(Number(r.amount || 0)),
          summary: r.note || '手动调整',
          sub: '',
          editable: true, table: 'manual_adjustments', id: r.id,
          amountField: 'amount', dateField: 'adjustment_date', noteField: 'note',
          balanceSync: 'adjust_neg', primaryAcc: acc,
        }))))

      // 借款还款(公司还股东 → 出账)
      tasks.push(supabase.from('loan_repayments')
        .select('id, repayment_amount, repayment_date, created_at, account_id')
        .eq('account_id', acc).is('deleted_at', null)
        .gte('repayment_date', fromIso.value.slice(0,10)).lte('repayment_date', toIso.value.slice(0,10))
        .then(({ data }) => (data || []).map(r => ({
          key: 'repay-' + r.id, type: 'repay_out',
          flow_at: r.repayment_date || r.created_at,
          abs_amount: Number(r.repayment_amount || 0),
          summary: '股东借款还款',
          sub: '',
          editable: false, table: 'loan_repayments', id: r.id,
          sourceRoute: { name: 'ShareholderLoans' },
        }))))

      // 分红
      tasks.push(supabase.from('dividends')
        .select('id, amount, pay_date, created_at, account_id')
        .eq('account_id', acc).is('deleted_at', null)
        .gte('pay_date', fromIso.value.slice(0,10)).lte('pay_date', toIso.value.slice(0,10))
        .then(({ data }) => (data || []).map(r => ({
          key: 'div-' + r.id, type: 'dividend_out',
          flow_at: r.pay_date || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: '股东分红',
          sub: '',
          editable: false, table: 'dividends', id: r.id,
          sourceRoute: { name: 'Dividends' },
        }))))
    }

    const results = await Promise.all(tasks)
    flows.value = results.flat().sort((a, b) => new Date(b.flow_at) - new Date(a.flow_at))
  } catch (e) {
    console.error('[BalanceFlowDrawer] load failed:', e)
    toast('加载明细失败：' + (e.message || ''), 'error')
  } finally {
    loading.value = false
  }
}

function startEdit(f) {
  editingKey.value = f.key
  editBuf.value = {
    amount: f.abs_amount,
    date: (f.flow_at || '').slice(0, 10),
    note: f.sub || '',
  }
}
function cancelEdit() {
  editingKey.value = null
}
async function saveEdit(f) {
  if (saving.value) return
  saving.value = true
  try {
    const newAmt = Number(editBuf.value.amount)
    const oldAmt = Number(f.abs_amount)
    const delta = newAmt - oldAmt   // 金额增量

    // 1) 构造 patch
    const patch = {}
    // manual_adjustments 扣减方向：DB 里 amount 存负数，UI 展示绝对值
    if (f.balanceSync === 'adjust_neg') {
      patch[f.amountField] = -newAmt
    } else {
      patch[f.amountField] = newAmt
    }
    // withdrawal 特殊处理：改 actual_arrival 或 amount 时保持另一侧一致(保留 fee 不变)
    if (f.balanceSync === 'withdrawal') {
      // 改了 actual_arrival → amount = actual_arrival + fee
      const fee = Number(f._old_amount) - Number(f._old_actual)
      patch['amount'] = newAmt + fee
    } else if (f.balanceSync === 'withdrawal_out') {
      // 改了 amount → actual_arrival 同步增减(保留 fee)
      patch['actual_arrival'] = Number(f._old_actual) + delta
    }
    // 日期
    patch[f.dateField] = ['paid_at','created_at','transfer_date','withdrawn_at','deposit_date'].includes(f.dateField)
      ? new Date(editBuf.value.date + 'T00:00:00+08:00').toISOString()
      : editBuf.value.date
    patch[f.noteField] = editBuf.value.note || null

    // 2) 写 DB
    const { error } = await supabase.from(f.table).update(patch).eq('id', f.id)
    if (error) throw error

    // 3) 若金额变动，同步两侧 accounts.balance
    if (Math.abs(delta) > 0.0001) {
      const deltas = {}  // accountId → delta
      const add = (accId, d) => { if (!accId) return; deltas[accId] = (deltas[accId] || 0) + d }
      switch (f.balanceSync) {
        case 'order':        add(f.primaryAcc, +delta); break
        case 'expense':      add(f.primaryAcc, -delta); break
        case 'refund':       add(f.primaryAcc, -delta); break
        case 'transfer':     add(f.primaryAcc, +delta); add(f.secondaryAcc, -delta); break
        case 'transfer_out': add(f.primaryAcc, -delta); add(f.secondaryAcc, +delta); break
        case 'withdrawal':   add(f.primaryAcc, +delta); add(f.secondaryAcc, -delta); break
        case 'withdrawal_out': add(f.primaryAcc, -delta); add(f.secondaryAcc, +delta); break
        case 'deposit':      add(f.primaryAcc, +delta); break
        case 'adjust':       add(f.primaryAcc, +delta); break   // manual_adjust 入账：改金额 → 同方向同步
        case 'adjust_neg':   add(f.primaryAcc, -delta); break   // 出账方向：UI 显绝对值，DB 里是负数，delta 在绝对值上变化 → 余额反向
      }
      // 逐账户更新 balance（读-改-写）
      for (const [accId, d] of Object.entries(deltas)) {
        if (Math.abs(d) < 0.0001) continue
        const { data: row, error: re } = await supabase.from('accounts').select('balance').eq('id', accId).single()
        if (re) throw re
        const newBal = Number(row.balance || 0) + d
        const { error: ue } = await supabase.from('accounts').update({ balance: newBal }).eq('id', accId)
        if (ue) throw ue
      }
    }

    toast('已保存' + (Math.abs(delta) > 0.0001 ? '（余额已联动）' : ''), 'success')
    editingKey.value = null
    emit('updated')
    await loadFlows()
  } catch (e) {
    toast('保存失败：' + (e.message || ''), 'error')
  } finally {
    saving.value = false
  }
}

function gotoSource(f) {
  if (!f.sourceRoute) return
  router.push(f.sourceRoute)
}

async function revertAdjustment(f) {
  if (!confirm(`撤销这笔${f.type === 'adjust_in' ? '调整入账' : '调整扣减'}？该记录会被软删，账户余额同步回滚。`)) return
  try {
    const { error } = await supabase.rpc('revert_manual_adjustment', { p_id: f.id })
    if (error) throw error
    toast('已撤销', 'success')
    emit('updated')
    await loadFlows()
  } catch (e) {
    toast('撤销失败：' + (e.message || ''), 'error')
  }
}

// ========== 补录流水 ==========
const showAddForm = ref(false)
const addSaving = ref(false)
const addBuf = ref({ amount: null, date: '', customerName: '', payee: '', note: '' })

const addLabelIn = computed(() => props.accountCategory === 'ecommerce' ? '店铺入账' : '订单收入')
const addHint = computed(() => {
  if (props.direction === 'in') {
    return props.accountCategory === 'ecommerce' ? '写入 store_deposits' : '写入 orders (status=completed)'
  }
  return '写入 expenses (status=paid)'
})

function openAddForm() {
  addBuf.value = {
    amount: null,
    date: new Date().toISOString().slice(0, 10),
    customerName: '',
    payee: '',
    note: '',
  }
  showAddForm.value = true
}

async function saveAdd() {
  if (addSaving.value) return
  const amt = Number(addBuf.value.amount)
  if (amt <= 0) { toast('请填入大于 0 的金额', 'warning'); return }
  addSaving.value = true
  try {
    const isoDate = new Date(addBuf.value.date + 'T12:00:00+08:00').toISOString()
    const { data: { session } } = await supabase.auth.getSession()
    const userId = session?.user?.id

    if (props.direction === 'in') {
      if (props.accountCategory === 'ecommerce') {
        // 补录店铺入账
        const { error } = await supabase.from('store_deposits').insert({
          account_id: props.accountId,
          amount: amt,
          deposit_date: isoDate,
          note: addBuf.value.note || null,
          recorded_by: userId,
          status: 'completed',
        })
        if (error) throw error
        await adjustAccountBalance(props.accountId, +amt)
      } else {
        // 补录订单收入
        const { error } = await supabase.from('orders').insert({
          account_id: props.accountId,
          amount: amt,
          customer_name: addBuf.value.customerName || '补录',
          status: 'completed',
          paid_at: isoDate,
          note: addBuf.value.note || '（对账补录）',
        })
        if (error) throw error
        await adjustAccountBalance(props.accountId, +amt)
      }
    } else {
      // 补录支出
      const { error } = await supabase.from('expenses').insert({
        account_id: props.accountId,
        amount: amt,
        payee: addBuf.value.payee || '补录',
        status: 'paid',
        paid_at: isoDate,
        approved_at: isoDate,
        approver_id: userId,
        created_by: userId,
        note: addBuf.value.note || '（对账补录）',
      })
      if (error) throw error
      await adjustAccountBalance(props.accountId, -amt)
    }

    toast('补录成功', 'success')
    showAddForm.value = false
    emit('updated')
    await loadFlows()
  } catch (e) {
    toast('补录失败：' + (e.message || ''), 'error')
  } finally {
    addSaving.value = false
  }
}

async function adjustAccountBalance(accId, delta) {
  const { data: row, error } = await supabase.from('accounts').select('balance, category, balance_method').eq('id', accId).single()
  if (error) throw error
  // 店铺 manual 模式下，订单补录不改 balance（和普通订单导入逻辑对齐）
  if (row.category === 'ecommerce' && row.balance_method === 'manual' && delta > 0 && props.accountCategory !== 'ecommerce' /* 订单路径 */) {
    return
  }
  const newBal = Number(row.balance || 0) + delta
  const { error: ue } = await supabase.from('accounts').update({ balance: newBal }).eq('id', accId)
  if (ue) throw ue
}

onMounted(loadFlows)
watch(() => [props.accountId, props.from, props.to, props.direction], loadFlows)
</script>
