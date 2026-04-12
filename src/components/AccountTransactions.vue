<template>
  <div v-if="visible" class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col mx-4 pb-16 md:pb-0">
      <!-- 头部 -->
      <div class="flex items-center justify-between px-6 py-4 border-b">
        <div>
          <h3 class="text-lg font-semibold">{{ accountName }} - 账户流水</h3>
          <p class="text-sm text-gray-500 mt-1">当前余额：{{ formatBalance(currentBalance) }}</p>
        </div>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
      </div>

      <!-- 筛选 -->
      <div class="px-6 py-3 border-b flex gap-2 flex-wrap">
        <select v-model="filterModule" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
          <option value="">全部类型</option>
          <option value="订单">订单（收入）</option>
          <option value="支出">支出</option>
          <option value="转账">转账</option>
          <option value="退款">退款</option>
          <option value="电商">电商提现</option>
        </select>
        <input type="date" v-model="dateFrom" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
        <input type="date" v-model="dateTo" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
      </div>

      <!-- 列表 -->
      <div class="flex-1 overflow-y-auto px-6">
        <div v-if="loading" class="py-10 text-center text-gray-500">加载中...</div>
        <div v-else-if="transactions.length === 0" class="py-10 text-center text-gray-500">
          <div class="text-3xl mb-2">📭</div>
          暂无流水记录
        </div>
        <div v-else class="py-2">
          <div v-for="tx in transactions" :key="tx.id" class="flex items-center justify-between py-3 border-b border-gray-50">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="inline-block px-1.5 py-0.5 rounded text-xs font-medium"
                  :class="moduleColor(tx.module)">{{ tx.module }}</span>
                <span class="text-sm text-gray-500">{{ formatDate(tx.created_at) }}</span>
              </div>
              <p class="text-sm mt-1 truncate">{{ tx.description || '-' }}</p>
              <p v-if="tx.user_name" class="text-xs text-gray-400 mt-0.5">操作人：{{ tx.user_name }}</p>
            </div>
            <div class="text-right ml-4 flex-shrink-0">
              <p v-if="tx.amount" :class="isIncome(tx) ? 'text-green-600' : 'text-red-500'" class="font-medium">
                {{ isIncome(tx) ? '+' : '-' }}{{ formatMoney(Math.abs(tx.amount)) }}
              </p>
              <p v-if="tx.balance_before != null && tx.balance_after != null" class="text-xs text-gray-400 mt-0.5">
                {{ Number(tx.balance_before).toFixed(2) }} → {{ Number(tx.balance_after).toFixed(2) }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- 底部统计 -->
      <div v-if="transactions.length > 0" class="px-6 py-3 border-t bg-gray-50 rounded-b-xl text-sm text-gray-600 flex justify-between flex-wrap gap-2">
        <span>共 {{ transactions.length }} 条记录</span>
        <span>
          收入：<span class="text-green-600">{{ formatMoney(incomeTotal) }}</span>
          ｜ 支出：<span class="text-red-500">{{ formatMoney(expenseTotal) }}</span>
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { formatMoney } from '../lib/utils'
import { dayEnd } from '../utils/dateRange'

const props = defineProps({
  visible: Boolean,
  accountId: String,
  accountName: String,
  currentBalance: Number
})

defineEmits(['close'])

const transactions = ref([])
const loading = ref(false)
const filterModule = ref('')
const dateFrom = ref('')
const dateTo = ref('')

const incomeActions = ['create_order', 'ecommerce_withdrawal', 'transfer_in']
const expenseActions = ['create_expense', 'pay_expense', 'transfer_out', 'refund']

function isIncome(tx) {
  if (incomeActions.some(a => tx.action?.includes(a))) return true
  if (tx.module === '订单' && !tx.action?.includes('delete')) return true
  if (tx.action?.includes('transfer') && tx.balance_after > tx.balance_before) return true
  return false
}

const incomeTotal = computed(() =>
  transactions.value.filter(t => isIncome(t) && t.amount).reduce((s, t) => s + Math.abs(Number(t.amount)), 0)
)
const expenseTotal = computed(() =>
  transactions.value.filter(t => !isIncome(t) && t.amount).reduce((s, t) => s + Math.abs(Number(t.amount)), 0)
)

function moduleColor(mod) {
  const m = {
    '订单': 'bg-green-100 text-green-700',
    '支出': 'bg-red-100 text-red-700',
    '转账': 'bg-blue-100 text-blue-700',
    '退款': 'bg-purple-100 text-purple-700',
    '电商': 'bg-orange-100 text-orange-700',
  }
  return m[mod] || 'bg-gray-100 text-gray-700'
}

function formatBalance(val) {
  return val != null ? formatMoney(val) : '-'
}

function formatDate(d) {
  if (!d) return ''
  const dt = new Date(d)
  return `${dt.getMonth()+1}/${dt.getDate()} ${String(dt.getHours()).padStart(2,'0')}:${String(dt.getMinutes()).padStart(2,'0')}`
}

async function loadData() {
  if (!props.accountId) return
  loading.value = true
  try {
    let query = supabase
      .from('operation_logs')
      .select('*')
      .eq('account_id', props.accountId)
      .order('created_at', { ascending: false })
      .limit(200)
    if (filterModule.value) query = query.eq('module', filterModule.value)
    if (dateFrom.value) query = query.gte('created_at', dateFrom.value)
    if (dateTo.value) query = query.lte('created_at', dayEnd(dateTo.value))
    const { data, error } = await query
    if (error) throw error
    transactions.value = data || []
  } catch (e) {
    console.error('加载账户流水失败:', e)
    transactions.value = []
  } finally {
    loading.value = false
  }
}

watch(() => props.visible, (v) => { if (v) loadData() })
</script>
