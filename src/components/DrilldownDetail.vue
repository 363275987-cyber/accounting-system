<template>
  <div class="space-y-4">
    <!-- 订单收入明细 -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-sm font-medium text-green-700">📦 订单收入明细（{{ orders.length }} 笔）</h3>
        <span class="text-sm font-bold text-green-600">合计 ¥{{ totalOrders.toLocaleString() }}</span>
      </div>
      <div v-if="ordersLoading" class="text-center text-gray-500 py-3 text-sm">加载中...</div>
      <div v-else-if="orders.length === 0" class="text-center text-gray-500 py-3 text-sm">无订单</div>
      <div v-else class="max-h-48 overflow-y-auto space-y-1">
        <div v-for="o in orders" :key="o.id"
          class="flex items-center justify-between py-1.5 px-3 bg-gray-50 rounded text-xs hover:bg-gray-100">
          <div class="flex items-center gap-2">
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(o.created_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[150px]">{{ o.order_no || '—' }}</span>
            <span class="text-gray-500 truncate max-w-[120px]">{{ o.customer_name || '' }}</span>
          </div>
          <span class="font-medium text-green-600 shrink-0 w-20 text-right">¥{{ Number(o.amount).toLocaleString() }}</span>
        </div>
      </div>
    </div>

    <!-- 支出明细 -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-sm font-medium text-red-600">💸 支出明细（{{ expenses.length }} 笔）</h3>
        <span class="text-sm font-bold text-red-500">合计 ¥{{ totalExpenses.toLocaleString() }}</span>
      </div>
      <div v-if="expensesLoading" class="text-center text-gray-500 py-3 text-sm">加载中...</div>
      <div v-else-if="expenses.length === 0" class="text-center text-gray-500 py-3 text-sm">无支出</div>
      <div v-else class="max-h-48 overflow-y-auto space-y-1">
        <div v-for="e in expenses" :key="e.id"
          class="flex items-center justify-between py-1.5 px-3 bg-gray-50 rounded text-xs hover:bg-gray-100">
          <div class="flex items-center gap-2">
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(e.paid_at || e.created_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[150px]">{{ e.expense_no || '—' }}</span>
            <span class="text-gray-500 truncate max-w-[120px]">{{ e.payee || '' }}</span>
          </div>
          <span class="font-medium text-red-500 shrink-0 w-20 text-right">¥{{ Number(e.amount).toLocaleString() }}</span>
        </div>
      </div>
    </div>

    <!-- 退款明细 -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-sm font-medium text-orange-600">🔄 退款明细（{{ refunds.length }} 笔）</h3>
        <span class="text-sm font-bold text-orange-500">合计 ¥{{ totalRefunds.toLocaleString() }}</span>
      </div>
      <div v-if="refundsLoading" class="text-center text-gray-500 py-3 text-sm">加载中...</div>
      <div v-else-if="refunds.length === 0" class="text-center text-gray-500 py-3 text-sm">无退款</div>
      <div v-else class="max-h-48 overflow-y-auto space-y-1">
        <div v-for="r in refunds" :key="r.id"
          class="flex items-center justify-between py-1.5 px-3 bg-gray-50 rounded text-xs hover:bg-gray-100">
          <div class="flex items-center gap-2">
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(r.completed_at || r.created_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[150px]">{{ r.refund_no || '—' }}</span>
            <span class="text-gray-500 truncate max-w-[120px]">{{ r.reason || '' }}</span>
          </div>
          <span class="font-medium text-orange-500 shrink-0 w-20 text-right">¥{{ Number(r.refund_amount).toLocaleString() }}</span>
        </div>
      </div>
    </div>

    <!-- 转账明细 -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-sm font-medium text-blue-600">🔀 转账明细（{{ transfers.length }} 笔）</h3>
      </div>
      <div v-if="transfersLoading" class="text-center text-gray-500 py-3 text-sm">加载中...</div>
      <div v-else-if="transfers.length === 0" class="text-center text-gray-500 py-3 text-sm">无转账</div>
      <div v-else class="max-h-48 overflow-y-auto space-y-1">
        <div v-for="t in transfers" :key="t.id"
          class="flex items-center justify-between py-1.5 px-3 bg-gray-50 rounded text-xs hover:bg-gray-100">
          <div class="flex items-center gap-2">
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(t.created_at, 'date') }}</span>
            <span class="text-blue-700">{{ t.from_code || '—' }} → {{ t.to_code || '—' }}</span>
          </div>
          <span class="font-medium shrink-0 w-20 text-right">
            <span class="text-blue-500">¥{{ Number(t.amount).toLocaleString() }}</span>
            <span v-if="t.fee > 0" class="text-gray-500"> +费{{ t.fee }}</span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { formatDate } from '../lib/utils'

const props = defineProps({
  accountId: { type: String, default: null },
  period: { type: String, default: '' },
})

const orders = ref([])
const expenses = ref([])
const refunds = ref([])
const transfers = ref([])
const ordersLoading = ref(false)
const expensesLoading = ref(false)
const refundsLoading = ref(false)
const transfersLoading = ref(false)

const totalOrders = computed(() => orders.value.reduce((s, o) => s + Number(o.amount || 0), 0))
const totalExpenses = computed(() => expenses.value.reduce((s, e) => s + Number(e.amount || 0), 0))
const totalRefunds = computed(() => refunds.value.reduce((s, r) => s + Number(r.refund_amount || 0), 0))

const periodStart = computed(() => props.period ? `${props.period}-01` : '')
const periodEnd = computed(() => {
  if (!props.period) return ''
  const [y, m] = props.period.split('-').map(Number)
  const lastDay = new Date(y, m, 0).getDate()
  return `${props.period}-${String(lastDay).padStart(2, '0')}`
})

async function loadOrders() {
  if (!props.accountId || !periodStart.value) return
  ordersLoading.value = true
  try {
    const { data } = await supabase
      .from('orders')
      .select('id, order_no, customer_name, amount, created_at')
      .eq('account_id', props.accountId)
      .in('status', ['completed', 'partially_refunded'])
      .gte('created_at', periodStart.value)
      .lt('created_at', periodEnd.value)
      .order('created_at', { ascending: false })
    orders.value = data || []
  } catch (e) {
    console.error('Failed to load orders:', e)
  } finally {
    ordersLoading.value = false
  }
}

async function loadExpenses() {
  if (!props.accountId || !periodStart.value) return
  expensesLoading.value = true
  try {
    const { data } = await supabase
      .from('expenses')
      .select('id, expense_no, payee, amount, paid_at, created_at')
      .eq('account_id', props.accountId)
      .eq('status', 'paid')
      .is('deleted_at', null)
      .gte('paid_at', periodStart.value)
      .lt('paid_at', periodEnd.value)
      .order('paid_at', { ascending: false })
    expenses.value = data || []
  } catch (e) {
    console.error('Failed to load expenses:', e)
  } finally {
    expensesLoading.value = false
  }
}

async function loadRefunds() {
  if (!props.accountId || !periodStart.value) return
  refundsLoading.value = true
  try {
    const { data } = await supabase
      .from('refunds')
      .select('id, refund_no, refund_amount, reason, completed_at, created_at')
      .eq('refund_to_account_id', props.accountId)
      .eq('status', 'completed')
      .gte('completed_at', periodStart.value)
      .lt('completed_at', periodEnd.value)
      .order('completed_at', { ascending: false })
    refunds.value = data || []
  } catch (e) {
    console.error('Failed to load refunds:', e)
  } finally {
    refundsLoading.value = false
  }
}

async function loadTransfers() {
  if (!props.accountId || !periodStart.value) return
  transfersLoading.value = true
  try {
    const { data: outData } = await supabase
      .from('account_transfers')
      .select('id, transfer_no, from_account_id, to_account_id, amount, fee, created_at, from_account:from_account_id(code), to_account:to_account_id(code)')
      .eq('from_account_id', props.accountId)
      .eq('status', 'completed')
      .gte('created_at', periodStart.value)
      .lt('created_at', periodEnd.value)
      .order('created_at', { ascending: false })
    const { data: inData } = await supabase
      .from('account_transfers')
      .select('id, transfer_no, from_account_id, to_account_id, amount, fee, created_at, from_account:from_account_id(code), to_account:to_account_id(code)')
      .eq('to_account_id', props.accountId)
      .eq('status', 'completed')
      .gte('created_at', periodStart.value)
      .lt('created_at', periodEnd.value)
      .order('created_at', { ascending: false })
    const all = [...(outData || []), ...(inData || [])]
      .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
    transfers.value = all
  } catch (e) {
    console.error('Failed to load transfers:', e)
  } finally {
    transfersLoading.value = false
  }
}

onMounted(() => {
  Promise.all([loadOrders(), loadExpenses(), loadRefunds(), loadTransfers()])
})

watch(() => props.accountId, () => {
  Promise.all([loadOrders(), loadExpenses(), loadRefunds(), loadTransfers()])
})
watch(() => props.period, () => {
  Promise.all([loadOrders(), loadExpenses(), loadRefunds(), loadTransfers()])
})
</script>
