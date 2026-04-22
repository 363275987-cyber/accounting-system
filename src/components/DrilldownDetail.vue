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
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(o.flow_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[220px]">{{ o.summary || '—' }}</span>
          </div>
          <span class="font-medium text-green-600 shrink-0 w-20 text-right">¥{{ Number(o.abs_amount).toLocaleString() }}</span>
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
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(e.flow_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[220px]">{{ e.summary || '—' }}</span>
          </div>
          <span class="font-medium text-red-500 shrink-0 w-20 text-right">¥{{ Number(e.abs_amount).toLocaleString() }}</span>
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
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(r.flow_at, 'date') }}</span>
            <span class="text-gray-700 truncate max-w-[220px]">{{ r.summary || '—' }}</span>
          </div>
          <span class="font-medium text-orange-500 shrink-0 w-20 text-right">¥{{ Number(r.abs_amount).toLocaleString() }}</span>
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
            <span class="text-gray-500 w-16 shrink-0">{{ formatDate(t.flow_at, 'date') }}</span>
            <span class="text-blue-700">{{ t.summary || '—' }}</span>
          </div>
          <span class="font-medium text-blue-500 shrink-0 w-20 text-right">¥{{ Number(t.abs_amount).toLocaleString() }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { formatDate } from '../lib/utils'
import { loadAccountDrilldown } from '../lib/accountFlows'

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

const totalOrders = computed(() => orders.value.reduce((s, o) => s + Number(o.abs_amount || 0), 0))
const totalExpenses = computed(() => expenses.value.reduce((s, e) => s + Number(e.abs_amount || 0), 0))
const totalRefunds = computed(() => refunds.value.reduce((s, r) => s + Number(r.abs_amount || 0), 0))

const periodStart = computed(() => props.period ? `${props.period}-01` : '')
const periodEnd = computed(() => {
  if (!props.period) return ''
  const [y, m] = props.period.split('-').map(Number)
  const lastDay = new Date(y, m, 0).getDate()
  return `${props.period}-${String(lastDay).padStart(2, '0')}`
})

async function loadAll() {
  if (!props.accountId || !periodStart.value || !periodEnd.value) {
    orders.value = []
    expenses.value = []
    refunds.value = []
    transfers.value = []
    return
  }

  ordersLoading.value = true
  expensesLoading.value = true
  refundsLoading.value = true
  transfersLoading.value = true
  try {
    const data = await loadAccountDrilldown({
      accountId: props.accountId,
      from: periodStart.value,
      to: periodEnd.value,
    })
    orders.value = data.orders
    expenses.value = data.expenses
    refunds.value = data.refunds
    transfers.value = data.transfers
  } catch (e) {
    console.error('Failed to load drilldown:', e)
  } finally {
    ordersLoading.value = false
    expensesLoading.value = false
    refundsLoading.value = false
    transfersLoading.value = false
  }
}

onMounted(() => {
  loadAll()
})

watch(() => props.accountId, () => {
  loadAll()
})
watch(() => props.period, () => {
  loadAll()
})
</script>
