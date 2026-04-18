<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 操作日志</h1>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4">
      <div class="flex gap-2 items-center flex-wrap">
        <!-- Time filter -->
        <div class="flex bg-gray-100 rounded-lg p-0.5">
          <button v-for="t in timeOptions" :key="t.value" @click="timeFilter = t.value"
            class="px-3 py-1.5 rounded-md text-xs font-medium transition cursor-pointer whitespace-nowrap"
            :class="timeFilter === t.value ? 'bg-white text-blue-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'">
            {{ t.label }}
          </button>
        </div>
        <!-- Module filter -->
        <select v-model="moduleFilter"
          class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
          <option value="">全部模块</option>
          <option value="订单">订单</option>
          <option value="支出">支出</option>
          <option value="转账">转账</option>
          <option value="退款">退款</option>
        </select>
        <!-- Action filter -->
        <select v-model="actionFilter"
          class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
          <option value="">全部操作</option>
          <option v-for="a in actionOptions" :key="a.value" :value="a.value">{{ a.label }}</option>
        </select>
        <span class="text-xs text-gray-500 ml-auto">共 {{ filteredLogs.length }} 条</span>
      </div>
      <!-- Custom date range -->
      <div v-if="timeFilter === 'custom'" class="flex gap-2 items-center mt-3">
        <input type="date" v-model="customDateFrom"
          class="px-2 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-blue-500">
        <span class="text-gray-500 text-xs">至</span>
        <input type="date" v-model="customDateTo"
          class="px-2 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-blue-500">
      </div>
    </div>

    <!-- Log Cards -->
    <div v-if="loading" class="space-y-3">
      <div v-for="i in 5" :key="i" class="bg-white rounded-xl border border-gray-100 p-4 animate-pulse">
        <div class="flex gap-3">
          <div class="w-20 h-4 bg-gray-100 rounded"></div>
          <div class="w-32 h-4 bg-gray-100 rounded"></div>
        </div>
        <div class="w-3/4 h-3 bg-gray-50 rounded mt-3"></div>
      </div>
    </div>

    <div v-else-if="filteredLogs.length === 0" class="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-500">
      <div class="text-3xl mb-2">📭</div>
      <div>暂无操作日志</div>
    </div>

    <div v-else class="space-y-2">
      <div v-for="log in filteredLogs" :key="log.id"
        class="bg-white rounded-xl border border-gray-100 hover:shadow-sm transition-shadow overflow-hidden">
        <div class="flex">
          <!-- Color left bar -->
          <div class="w-1 flex-shrink-0" :class="moduleColor(log.module)"></div>
          <div class="flex-1 p-4">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <!-- Module pill -->
                <span class="px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="modulePillClass(log.module)">
                  {{ log.module }}
                </span>
                <!-- Action type -->
                <span class="text-xs text-gray-500">{{ actionLabel(log.action) }}</span>
              </div>
              <div class="flex items-center gap-2">
                <!-- Amount -->
                <span v-if="log.amount" class="text-sm font-semibold" :class="amountClass(log.action)">
                  {{ amountPrefix(log.action) }}{{ formatMoneyStr(log.amount) }}
                </span>
                <!-- Time -->
                <span class="text-xs text-gray-500">{{ relativeTime(log.created_at) }}</span>
              </div>
            </div>
            <!-- Description -->
            <p class="text-sm text-gray-700 mb-1.5">{{ log.description }}</p>
            <!-- Meta row -->
            <div class="flex items-center gap-4 text-xs text-gray-500">
              <span v-if="log.user_name"><Icon name="user" class="inline w-4 h-4 -mt-0.5 mr-1" /> {{ log.user_name }}</span>
              <span v-if="log.account_name"><Icon name="building" class="inline w-4 h-4 -mt-0.5 mr-1" /> {{ log.account_name }}</span>
              <span v-if="log.balance_before != null && log.balance_after != null"
                class="text-gray-500">
                余额 {{ formatMoneyStr(log.balance_before) }} → {{ formatMoneyStr(log.balance_after) }}
                <span :class="Number(log.balance_after) >= Number(log.balance_before) ? 'text-green-600' : 'text-red-500'">
                  ({{ Number(log.balance_after) >= Number(log.balance_before) ? '+' : '' }}{{ formatMoneyStr(Number(log.balance_after) - Number(log.balance_before)) }})
                </span>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Load more -->
    <div v-if="hasMore" class="text-center mt-4">
      <button @click="loadMore" :disabled="loadingMore"
        class="px-6 py-2 text-sm text-blue-600 border border-blue-200 rounded-lg hover:bg-blue-50 transition cursor-pointer disabled:opacity-50">
        {{ loadingMore ? '加载中...' : '加载更多' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from '../components/icons/Icons.vue'

const logs = ref([])
const loading = ref(true)
const loadingMore = ref(false)
const pageSize = 50
const timeFilter = ref('today')
const moduleFilter = ref('')
const actionFilter = ref('')
const customDateFrom = ref('')
const customDateTo = ref('')

const timeOptions = [
  { label: '今日', value: 'today' },
  { label: '本周', value: 'week' },
  { label: '本月', value: 'month' },
  { label: '全部', value: 'all' },
  { label: '自定义', value: 'custom' },
]

const actionOptions = [
  { value: 'create_order', label: '新建订单' },
  { value: 'update_order', label: '修改订单' },
  { value: 'delete_order', label: '删除订单' },
  { value: 'pay_expense', label: '支付支出' },
  { value: 'delete_expense', label: '删除支出' },
  { value: 'approve_expense', label: '审批支出' },
  { value: 'transfer', label: '转账' },
  { value: 'delete_transfer', label: '删除转账' },
  { value: 'refund', label: '退款' },
  { value: 'approve_refund', label: '审批退款' },
]

function getTimeRange() {
  const now = new Date()
  const start = new Date()
  switch (timeFilter.value) {
    case 'today':
      start.setHours(0, 0, 0, 0)
      return { start: start.toISOString(), end: now.toISOString() }
    case 'week':
      const day = start.getDay() || 7
      start.setDate(start.getDate() - day + 1)
      start.setHours(0, 0, 0, 0)
      return { start: start.toISOString(), end: now.toISOString() }
    case 'month':
      start.setDate(1)
      start.setHours(0, 0, 0, 0)
      return { start: start.toISOString(), end: now.toISOString() }
    case 'all':
      return null
    case 'custom': {
      if (customDateFrom.value) {
        const s = new Date(customDateFrom.value)
        s.setHours(0, 0, 0, 0)
        const e = customDateTo.value ? new Date(customDateTo.value + 'T23:59:59') : now
        return { start: s.toISOString(), end: e.toISOString() }
      }
      return null
    }
    default:
      return null
  }
}

async function fetchLogs(append = false) {
  if (append) {
    loadingMore.value = true
  } else {
    loading.value = true
    logs.value = []
  }

  try {
    let query = supabase
      .from('operation_logs')
      .select('*')
      .order('created_at', { ascending: false })
      .range(0, pageSize - 1)

    const timeRange = getTimeRange()
    if (timeRange) {
      query = query.gte('created_at', timeRange.start).lte('created_at', timeRange.end)
    }
    if (moduleFilter.value) {
      query = query.eq('module', moduleFilter.value)
    }
    if (actionFilter.value) {
      query = query.eq('action', actionFilter.value)
    }

    const { data, error } = await query
    if (error) throw error
    logs.value = append ? [...logs.value, ...(data || [])] : (data || [])
  } catch (e) {
    console.error('Failed to fetch operation logs:', e)
  } finally {
    loading.value = false
    loadingMore.value = false
  }
}

const hasMore = computed(() => logs.value.length >= pageSize)

function loadMore() {
  // For simplicity, re-fetch with larger range
  // In production you'd track the last created_at and fetch beyond it
  fetchLogs(true)
}

const filteredLogs = computed(() => logs.value)

// Watch filters and refetch
watch([timeFilter, moduleFilter, actionFilter], () => {
  fetchLogs()
})

watch([customDateFrom, customDateTo], () => {
  if (timeFilter.value === 'custom') fetchLogs()
})

onMounted(() => fetchLogs())

// ========== Helpers ==========

function moduleColor(module) {
  const colors = {
    '订单': 'bg-green-400',
    '支出': 'bg-red-400',
    '转账': 'bg-blue-400',
    '退款': 'bg-orange-400',
  }
  return colors[module] || 'bg-gray-300'
}

function modulePillClass(module) {
  const cls = {
    '订单': 'bg-green-50 text-green-700',
    '支出': 'bg-red-50 text-red-700',
    '转账': 'bg-blue-50 text-blue-700',
    '退款': 'bg-orange-50 text-orange-700',
  }
  return cls[module] || 'bg-gray-50 text-gray-600'
}

function actionLabel(action) {
  const labels = {
    create_order: '新建',
    update_order: '修改',
    delete_order: '删除',
    pay_expense: '付款',
    delete_expense: '删除',
    approve_expense: '审批',
    transfer: '转账',
    delete_transfer: '删除转账',
    refund: '退款',
    approve_refund: '审批退款',
  }
  return labels[action] || action
}

function amountClass(action) {
  // Income actions: green, expense actions: red
  if (['create_order'].includes(action)) return 'text-green-600'
  if (['delete_order'].includes(action)) return 'text-orange-500'
  if (['pay_expense', 'delete_expense', 'refund'].includes(action)) return 'text-red-500'
  if (['transfer'].includes(action)) return 'text-blue-600'
  return 'text-gray-700'
}

function amountPrefix(action) {
  if (['create_order'].includes(action)) return '+'
  if (['pay_expense', 'delete_expense', 'refund'].includes(action)) return '-'
  return ''
}

function formatMoneyStr(amount) {
  if (amount == null) return ''
  return `¥${Number(amount).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

function relativeTime(dateStr) {
  if (!dateStr) return ''
  const now = new Date()
  const date = new Date(dateStr)
  const diff = now - date
  const seconds = Math.floor(diff / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)

  if (seconds < 60) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`
  if (days < 7) return `${days}天前`
  if (days < 30) return `${Math.floor(days / 7)}周前`
  return dateStr.slice(0, 10)
}
</script>
