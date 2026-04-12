<template>
  <div v-if="visible" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col mx-4">
      <!-- 头部 -->
      <div class="flex items-center justify-between px-6 py-4 border-b">
        <div>
          <h3 class="text-lg font-semibold">{{ accountName }} - 交易明细</h3>
          <p class="text-sm text-gray-500 mt-1">当前余额：{{ formatBalance(currentBalance) }}</p>
        </div>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
      </div>

      <!-- 筛选 -->
      <div class="px-6 py-3 border-b flex gap-2 flex-wrap">
        <select v-model="filterType" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
          <option value="">全部类型</option>
          <option value="收入">收入</option>
          <option value="支出">支出</option>
          <option value="转出">转出</option>
          <option value="转入">转入</option>
          <option value="退款">退款</option>
        </select>
        <input type="date" v-model="dateFrom" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
        <input type="date" v-model="dateTo" @change="loadData" class="px-2 py-1.5 border rounded text-sm">
      </div>

      <!-- 列表 -->
      <div class="flex-1 overflow-y-auto px-6">
        <div v-if="loading" class="py-10 text-center text-gray-500">加载中...</div>
        <div v-else-if="transactions.length === 0" class="py-10 text-center text-gray-500">暂无交易记录</div>
        <div v-else class="py-2">
          <div v-for="tx in transactions" :key="tx.source_id + tx.txn_type" class="flex items-center justify-between py-3 border-b border-gray-50">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="inline-block px-1.5 py-0.5 rounded text-xs font-medium"
                  :class="typeColor(tx.txn_type)">{{ tx.txn_type }}</span>
                <span class="text-sm text-gray-500">{{ formatDate(tx.created_at) }}</span>
              </div>
              <p class="text-sm mt-1 truncate">{{ tx.description || tx.ref_no || '-' }}</p>
              <p v-if="tx.ref_no" class="text-xs text-gray-500 mt-0.5">{{ tx.ref_no }}</p>
            </div>
            <div class="text-right ml-4 flex-shrink-0">
              <p :class="tx.txn_type === '收入' || tx.txn_type === '转入' ? 'text-green-600' : 'text-red-500'" class="font-medium">
                {{ tx.txn_type === '收入' || tx.txn_type === '转入' ? '+' : '-' }}{{ formatMoney(tx.amount) }}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- 底部统计 -->
      <div v-if="transactions.length > 0" class="px-6 py-3 border-t bg-gray-50 rounded-b-xl text-sm text-gray-600 flex justify-between">
        <span>共 {{ transactions.length }} 条记录</span>
        <span>
          收入合计：<span class="text-green-600">{{ formatMoney(incomeTotal) }}</span>
          ｜ 支出合计：<span class="text-red-500">{{ formatMoney(expenseTotal) }}</span>
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
const filterType = ref('')
const dateFrom = ref('')
const dateTo = ref('')

const incomeTotal = computed(() => 
  transactions.value.filter(t => t.txn_type === '收入' || t.txn_type === '转入').reduce((s, t) => s + Number(t.amount), 0)
)
const expenseTotal = computed(() => 
  transactions.value.filter(t => t.txn_type === '支出' || t.txn_type === '转出' || t.txn_type === '退款').reduce((s, t) => s + Number(t.amount), 0)
)

function typeColor(type) {
  const m = { '收入': 'bg-green-100 text-green-700', '支出': 'bg-red-100 text-red-700', '转出': 'bg-orange-100 text-orange-700', '转入': 'bg-blue-100 text-blue-700', '退款': 'bg-purple-100 text-purple-700' }
  return m[type] || 'bg-gray-100 text-gray-700'
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
      .from('account_transactions')
      .select('*')
      .eq('account_id', props.accountId)
      .order('created_at', { ascending: false })
      .limit(200)
    if (filterType.value) query = query.eq('txn_type', filterType.value)
    if (dateFrom.value) query = query.gte('created_at', dateFrom.value)
    if (dateTo.value) query = query.lte('created_at', dayEnd(dateTo.value))
    const { data, error } = await query
    if (error) throw error
    transactions.value = data || []
  } catch (e) {
    console.error('加载交易明细失败:', e)
    transactions.value = []
  } finally {
    loading.value = false
  }
}

watch(() => props.visible, (v) => { if (v) loadData() })
</script>
