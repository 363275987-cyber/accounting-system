<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="credit-card" class="inline w-4 h-4 -mt-0.5 mr-1" /> 预付账款管理</h1>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 预付总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(stats.totalAmount) }}</div>
        <div class="text-xs text-gray-500 mt-1">共 {{ list.length }} 笔</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="check-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 已核销</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.settledAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">⏳ 未核销</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(stats.remainingAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 待核销笔数</div>
        <div class="text-2xl font-bold text-purple-600">{{ stats.pendingCount }}</div>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6">
      <div class="flex flex-wrap items-center gap-3">
        <select v-model="filterStatus"
          class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">全部状态</option>
          <option value="pending">待核销</option>
          <option value="partial">部分核销</option>
          <option value="settled">已核销</option>
        </select>
        <input v-model="searchKeyword" type="text" placeholder="搜索供应商..."
          class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 flex-1 min-w-[160px]" />
        <button @click="openModal()"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer ml-auto">
          + 添加预付
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="text-gray-500">加载中...</div>
    </div>

    <!-- Empty -->
    <div v-else-if="filteredList.length === 0" class="text-center py-20">
      <div class="text-4xl mb-3"><Icon name="credit-card" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
      <div class="text-gray-500">暂无预付账款记录</div>
      <button @click="openModal()" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        添加第一笔预付款
      </button>
    </div>

    <!-- Desktop Table -->
    <div v-else-if="!isMobile" class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-gray-50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">供应商</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">预付金额</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">付款日期</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">用途</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">已核销</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">未核销</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">状态</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in filteredList" :key="item.id" class="border-t border-gray-50 hover:bg-gray-50/50">
            <td class="px-4 py-3 text-sm font-medium text-gray-800">{{ item.supplier_name }}</td>
            <td class="px-4 py-3 text-sm text-right text-gray-800">{{ formatMoney(item.amount) }}</td>
            <td class="px-4 py-3 text-sm text-center text-gray-600">{{ item.paid_date || '-' }}</td>
            <td class="px-4 py-3 text-sm text-gray-600 max-w-[160px] truncate">{{ item.purpose || '-' }}</td>
            <td class="px-4 py-3 text-sm text-right text-green-600">{{ formatMoney(item.settled_amount) }}</td>
            <td class="px-4 py-3 text-sm text-right text-orange-500">{{ formatMoney(item.remaining_amount) }}</td>
            <td class="px-4 py-3 text-center">
              <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(item.status)">
                {{ statusLabel(item.status) }}
              </span>
            </td>
            <td class="px-4 py-3 text-center">
              <div class="flex items-center justify-center gap-2">
                <button @click="openModal(item)" class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer">编辑</button>
                <button v-if="item.status !== 'settled'" @click="openSettle(item)"
                  class="text-green-600 hover:text-green-800 text-xs cursor-pointer">核销</button>
                <button @click="handleDelete(item)" class="text-red-500 hover:text-red-700 text-xs cursor-pointer">删除</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards -->
    <div v-else class="space-y-3">
      <div v-for="item in filteredList" :key="item.id"
        class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="flex items-start justify-between mb-2">
          <div class="font-semibold text-gray-800">{{ item.supplier_name }}</div>
          <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(item.status)">
            {{ statusLabel(item.status) }}
          </span>
        </div>
        <div class="text-xl font-bold text-blue-600 mb-2">{{ formatMoney(item.amount) }}</div>
        <div class="grid grid-cols-2 gap-2 text-xs text-gray-500 mb-3">
          <div>付款日期: {{ item.paid_date || '-' }}</div>
          <div>用途: {{ item.purpose || '-' }}</div>
          <div class="text-green-600">已核销: {{ formatMoney(item.settled_amount) }}</div>
          <div class="text-orange-500">未核销: {{ formatMoney(item.remaining_amount) }}</div>
        </div>
        <div class="flex items-center gap-3 pt-2 border-t border-gray-100">
          <button @click="openModal(item)" class="text-blue-600 text-xs cursor-pointer">编辑</button>
          <button v-if="item.status !== 'settled'" @click="openSettle(item)"
            class="text-green-600 text-xs cursor-pointer">核销</button>
          <button @click="handleDelete(item)" class="text-red-500 text-xs cursor-pointer">删除</button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showModal = false">
      <div class="bg-white rounded-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">{{ editingItem ? '编辑预付账款' : '添加预付账款' }}</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">供应商名称 <span class="text-red-500">*</span></label>
            <input v-model="form.supplier_name" type="text" placeholder="请输入供应商名称"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">预付金额</label>
              <input v-model.number="form.amount" type="number" step="0.01" placeholder="0.00"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">付款日期</label>
              <input v-model="form.paid_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">用途</label>
            <input v-model="form.purpose" type="text" placeholder="预付款用途"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="备注信息"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showModal = false"
            class="px-4 py-2 rounded-lg text-sm text-gray-600 hover:bg-gray-100 transition cursor-pointer">取消</button>
          <button @click="handleSave"
            class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer">
            {{ editingItem ? '保存' : '添加' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Settle Modal -->
    <div v-if="showSettleModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showSettleModal = false">
      <div class="bg-white rounded-xl w-full max-w-sm mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-2">核销预付款</h2>
        <p class="text-sm text-gray-500 mb-4">
          供应商: {{ settlingItem?.supplier_name }} | 未核销: {{ formatMoney(settlingItem?.remaining_amount) }}
        </p>
        <div>
          <label class="block text-sm text-gray-600 mb-1">核销金额</label>
          <input v-model.number="settleAmount" type="number" step="0.01" placeholder="0.00"
            class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showSettleModal = false"
            class="px-4 py-2 rounded-lg text-sm text-gray-600 hover:bg-gray-100 transition cursor-pointer">取消</button>
          <button @click="handleSettle"
            class="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition cursor-pointer">
            确认核销
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from '../components/icons/Icons.vue'

const TABLE = 'prepaid_accounts'

const loading = ref(false)
const list = ref([])
const filterStatus = ref('')
const searchKeyword = ref('')

const isMobile = ref(window.innerWidth < 768)
const onResize = () => { isMobile.value = window.innerWidth < 768 }
onMounted(() => { window.addEventListener('resize', onResize); fetchData() })
onUnmounted(() => { window.removeEventListener('resize', onResize) })

// Modal state
const showModal = ref(false)
const editingItem = ref(null)
const form = ref(emptyForm())

// Settle state
const showSettleModal = ref(false)
const settlingItem = ref(null)
const settleAmount = ref(0)

function emptyForm() {
  return { supplier_name: '', amount: null, paid_date: '', purpose: '', note: '' }
}

// Computed
const filteredList = computed(() => {
  return list.value.filter(item => {
    if (filterStatus.value && item.status !== filterStatus.value) return false
    if (searchKeyword.value && !item.supplier_name?.includes(searchKeyword.value)) return false
    return true
  })
})

const stats = computed(() => {
  const items = list.value
  return {
    totalAmount: items.reduce((s, i) => s + Number(i.amount || 0), 0),
    settledAmount: items.reduce((s, i) => s + Number(i.settled_amount || 0), 0),
    remainingAmount: items.reduce((s, i) => s + Number(i.remaining_amount || 0), 0),
    pendingCount: items.filter(i => i.status !== 'settled').length
  }
})

// Fetch
async function fetchData() {
  loading.value = true
  const { data, error } = await supabase
    .from(TABLE)
    .select('*')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
  if (!error) list.value = data || []
  loading.value = false
}

// Modal
function openModal(item = null) {
  editingItem.value = item
  form.value = item
    ? { supplier_name: item.supplier_name, amount: item.amount, paid_date: item.paid_date, purpose: item.purpose, note: item.note }
    : emptyForm()
  showModal.value = true
}

async function handleSave() {
  if (!form.value.supplier_name?.trim()) return alert('请输入供应商名称')
  const amount = Number(form.value.amount) || 0
  const settled = editingItem.value ? Number(editingItem.value.settled_amount) || 0 : 0
  const remaining = amount - settled
  let status = 'pending'
  if (settled > 0 && remaining > 0) status = 'partial'
  if (remaining <= 0) status = 'settled'

  const payload = {
    supplier_name: form.value.supplier_name.trim(),
    amount,
    paid_date: form.value.paid_date || null,
    purpose: form.value.purpose || null,
    note: form.value.note || null,
    remaining_amount: remaining,
    status
  }

  if (editingItem.value) {
    await supabase.from(TABLE).update({ ...payload, updated_at: new Date().toISOString() }).eq('id', editingItem.value.id)
  } else {
    payload.settled_amount = 0
    await supabase.from(TABLE).insert(payload)
  }
  showModal.value = false
  await fetchData()
}

// Settle
function openSettle(item) {
  settlingItem.value = item
  settleAmount.value = null
  showSettleModal.value = true
}

async function handleSettle() {
  const amt = Number(settleAmount.value)
  if (!amt || amt <= 0) return alert('请输入有效的核销金额')
  const item = settlingItem.value
  const newSettled = Number(item.settled_amount || 0) + amt
  const newRemaining = Number(item.amount || 0) - newSettled
  let status = 'partial'
  if (newRemaining <= 0) status = 'settled'

  await supabase.from(TABLE).update({
    settled_amount: newSettled,
    remaining_amount: Math.max(newRemaining, 0),
    status,
    updated_at: new Date().toISOString()
  }).eq('id', item.id)

  showSettleModal.value = false
  await fetchData()
}

// Delete
async function handleDelete(item) {
  if (!confirm(`确定删除「${item.supplier_name}」的预付记录吗？`)) return
  await supabase.from(TABLE).update({ deleted_at: new Date().toISOString() }).eq('id', item.id)
  await fetchData()
}

// Helpers
function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function statusLabel(s) {
  return { pending: '待核销', partial: '部分核销', settled: '已核销' }[s] || s
}

function statusClass(s) {
  return {
    pending: 'bg-yellow-50 text-yellow-700',
    partial: 'bg-blue-50 text-blue-700',
    settled: 'bg-green-50 text-green-700'
  }[s] || 'bg-gray-50 text-gray-600'
}
</script>
