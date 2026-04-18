<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 其他应付款管理</h1>
      <button
        @click="openCreateModal"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer"
      >
        + 添加应付款
      </button>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 应付总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(stats.totalAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="check-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 已退还</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.returnedAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">⏳ 未退还</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(stats.remainingAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1"><Icon name="home" class="inline w-4 h-4 -mt-0.5 mr-1" /> 押金小计</div>
        <div class="text-2xl font-bold text-purple-500">{{ formatMoney(stats.depositTotal) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">🛡️ 保证金小计</div>
        <div class="text-2xl font-bold text-blue-500">{{ formatMoney(stats.guaranteeTotal) }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6">
      <div class="flex flex-wrap items-center gap-3">
        <!-- Type Tabs -->
        <div class="flex rounded-lg border border-gray-200 overflow-hidden">
          <button v-for="tab in typeTabs" :key="tab.value"
            @click="filterType = tab.value"
            class="px-3 py-1.5 text-sm transition cursor-pointer"
            :class="filterType === tab.value ? 'bg-blue-600 text-white' : 'text-gray-600 hover:bg-gray-50'">
            {{ tab.label }}
          </button>
        </div>
        <select v-model="filterStatus" class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">全部状态</option>
          <option value="pending">待退还</option>
          <option value="partial">部分退还</option>
          <option value="returned">已退还</option>
        </select>
        <input
          v-model="searchText"
          type="text"
          placeholder="搜索对方名称"
          class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-48"
        />
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="text-gray-500">加载中...</div>
    </div>

    <!-- Empty State -->
    <div v-else-if="filteredList.length === 0" class="text-center py-20">
      <div class="text-4xl mb-3"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
      <div class="text-gray-500">暂无应付款记录</div>
      <button @click="openCreateModal" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        添加第一笔应付款
      </button>
    </div>

    <!-- Desktop Table -->
    <div v-else-if="!isMobile" class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-gray-50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">类型</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">对方</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">金额</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">发生日期</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">预计退还日</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">已退</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">未退</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">状态</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">操作</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-50">
          <tr v-for="item in filteredList" :key="item.id" class="hover:bg-gray-50/50 transition">
            <td class="px-4 py-3">
              <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="typeBadgeClass(item.payable_type)">
                {{ typeLabel(item.payable_type) }}
              </span>
            </td>
            <td class="px-4 py-3 text-sm font-medium text-gray-800">{{ item.counterparty }}</td>
            <td class="px-4 py-3 text-sm text-gray-800 text-right font-medium">{{ formatMoney(item.amount) }}</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.occurred_date }}</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.expected_date || '-' }}</td>
            <td class="px-4 py-3 text-sm text-green-600 text-right">{{ formatMoney(item.returned_amount) }}</td>
            <td class="px-4 py-3 text-sm text-orange-500 text-right">{{ formatMoney(item.remaining_amount) }}</td>
            <td class="px-4 py-3">
              <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="statusClass(item.status)">
                {{ statusLabel(item.status) }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-2">
                <button @click="openEditModal(item)" class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer">编辑</button>
                <button @click="openReturnDialog(item)" class="text-green-600 hover:text-green-800 text-xs cursor-pointer" v-if="item.status !== 'returned'">退还</button>
                <button @click="handleDelete(item)" class="text-red-500 hover:text-red-700 text-xs cursor-pointer">删除</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards -->
    <div v-else class="space-y-4">
      <div v-for="item in filteredList" :key="item.id"
        class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="flex items-start justify-between mb-3">
          <div class="flex items-center gap-2">
            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
              :class="typeBadgeClass(item.payable_type)">
              {{ typeLabel(item.payable_type) }}
            </span>
            <span class="font-semibold text-gray-800">{{ item.counterparty }}</span>
          </div>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
            :class="statusClass(item.status)">
            {{ statusLabel(item.status) }}
          </span>
        </div>
        <div class="flex items-baseline gap-1 mb-2">
          <span class="text-sm text-gray-500">¥</span>
          <span class="text-xl font-bold text-gray-800">{{ formatAmount(item.amount) }}</span>
        </div>
        <div class="flex items-center gap-4 text-xs text-gray-500 mb-2">
          <span>发生 {{ item.occurred_date }}</span>
          <span v-if="item.expected_date">预计 {{ item.expected_date }}</span>
        </div>
        <div class="flex items-center gap-4 text-xs mb-3">
          <span class="text-green-600">已退还 {{ formatMoney(item.returned_amount) }}</span>
          <span class="text-orange-500">未退还 {{ formatMoney(item.remaining_amount) }}</span>
        </div>
        <div v-if="item.note" class="text-xs text-gray-500 mb-3 truncate">{{ item.note }}</div>
        <div class="flex items-center gap-3 pt-2 border-t border-gray-100">
          <button @click="openEditModal(item)" class="text-blue-600 text-xs cursor-pointer">编辑</button>
          <button @click="openReturnDialog(item)" class="text-green-600 text-xs cursor-pointer" v-if="item.status !== 'returned'">退还</button>
          <button @click="handleDelete(item)" class="text-red-500 text-xs cursor-pointer">删除</button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showModal = false">
      <div class="bg-white rounded-xl w-full max-w-lg mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-lg font-bold text-gray-800 mb-4">{{ isEdit ? '编辑应付款' : '添加应付款' }}</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">类型</label>
            <select v-model="form.payable_type" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option value="deposit">押金</option>
              <option value="guarantee">保证金</option>
              <option value="other">其他</option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">对方 <span class="text-red-500">*</span></label>
            <input v-model="form.counterparty" type="text" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">金额</label>
            <input v-model.number="form.amount" type="number" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">发生日期</label>
            <input v-model="form.occurred_date" type="date" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">预计退还日期（可选）</label>
            <input v-model="form.expected_date" type="date" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showModal = false" class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800 cursor-pointer">取消</button>
          <button @click="handleSave" :disabled="saving" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer disabled:opacity-50">
            {{ saving ? '保存中...' : '保存' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Return Dialog -->
    <div v-if="showReturnDialog" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showReturnDialog = false">
      <div class="bg-white rounded-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">退还 - {{ returnTarget?.counterparty }}</h2>
        <div class="text-sm text-gray-500 mb-4">
          未退还金额: {{ formatMoney(returnTarget?.remaining_amount) }}
        </div>
        <div>
          <label class="block text-sm text-gray-600 mb-1">退还金额</label>
          <input v-model.number="returnAmount" type="number" min="0.01" :max="returnTarget?.remaining_amount"
            class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showReturnDialog = false" class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800 cursor-pointer">取消</button>
          <button @click="handleReturn" :disabled="saving" class="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition cursor-pointer disabled:opacity-50">
            {{ saving ? '处理中...' : '确认退还' }}
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

const loading = ref(false)
const saving = ref(false)
const list = ref([])
const showModal = ref(false)
const showReturnDialog = ref(false)
const isEdit = ref(false)
const editId = ref(null)
const searchText = ref('')
const filterStatus = ref('')
const filterType = ref('')
const isMobile = ref(window.innerWidth < 768)

const typeTabs = [
  { label: '全部', value: '' },
  { label: '押金', value: 'deposit' },
  { label: '保证金', value: 'guarantee' },
  { label: '其他', value: 'other' }
]

const defaultForm = () => ({
  payable_type: 'deposit',
  counterparty: '',
  amount: 0,
  occurred_date: new Date().toISOString().slice(0, 10),
  expected_date: '',
  note: ''
})
const form = ref(defaultForm())

const returnTarget = ref(null)
const returnAmount = ref(0)

const handleResize = () => { isMobile.value = window.innerWidth < 768 }
onMounted(() => {
  window.addEventListener('resize', handleResize)
  fetchList()
})
onUnmounted(() => { window.removeEventListener('resize', handleResize) })

const stats = computed(() => {
  const items = list.value
  return {
    totalAmount: items.reduce((s, i) => s + Number(i.amount || 0), 0),
    returnedAmount: items.reduce((s, i) => s + Number(i.returned_amount || 0), 0),
    remainingAmount: items.reduce((s, i) => s + Number(i.remaining_amount || 0), 0),
    depositTotal: items.filter(i => i.payable_type === 'deposit').reduce((s, i) => s + Number(i.amount || 0), 0),
    guaranteeTotal: items.filter(i => i.payable_type === 'guarantee').reduce((s, i) => s + Number(i.amount || 0), 0)
  }
})

const filteredList = computed(() => {
  let result = list.value
  if (filterType.value) {
    result = result.filter(i => i.payable_type === filterType.value)
  }
  if (filterStatus.value) {
    result = result.filter(i => i.status === filterStatus.value)
  }
  if (searchText.value) {
    const s = searchText.value.toLowerCase()
    result = result.filter(i => (i.counterparty || '').toLowerCase().includes(s))
  }
  return result
})

async function fetchList() {
  loading.value = true
  const { data, error } = await supabase
    .from('other_payables')
    .select('*')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
  if (!error) list.value = data || []
  loading.value = false
}

function openCreateModal() {
  isEdit.value = false
  editId.value = null
  form.value = defaultForm()
  showModal.value = true
}

function openEditModal(item) {
  isEdit.value = true
  editId.value = item.id
  form.value = {
    payable_type: item.payable_type,
    counterparty: item.counterparty,
    amount: item.amount,
    occurred_date: item.occurred_date,
    expected_date: item.expected_date || '',
    note: item.note || ''
  }
  showModal.value = true
}

async function handleSave() {
  if (!form.value.counterparty) return alert('请输入对方名称')
  saving.value = true

  const existing = isEdit.value ? list.value.find(i => i.id === editId.value) : null
  const returnedAmt = existing ? Number(existing.returned_amount || 0) : 0
  const remainingAmount = Number(form.value.amount) - returnedAmt

  const payload = {
    payable_type: form.value.payable_type,
    counterparty: form.value.counterparty,
    amount: form.value.amount,
    occurred_date: form.value.occurred_date,
    expected_date: form.value.expected_date || null,
    remaining_amount: remainingAmount,
    note: form.value.note || null,
    updated_at: new Date().toISOString()
  }

  if (isEdit.value) {
    await supabase.from('other_payables').update(payload).eq('id', editId.value)
  } else {
    payload.returned_amount = 0
    payload.remaining_amount = payload.amount
    payload.status = 'pending'
    await supabase.from('other_payables').insert(payload)
  }

  saving.value = false
  showModal.value = false
  await fetchList()
}

function openReturnDialog(item) {
  returnTarget.value = item
  returnAmount.value = Number(item.remaining_amount)
  showReturnDialog.value = true
}

async function handleReturn() {
  if (!returnTarget.value) return
  if (returnAmount.value <= 0) return alert('请输入退还金额')
  if (returnAmount.value > Number(returnTarget.value.remaining_amount)) return alert('退还金额不能超过未退还金额')

  saving.value = true
  const item = returnTarget.value
  const newReturned = Number(item.returned_amount) + returnAmount.value
  const newRemaining = Number(item.amount) - newReturned
  const newStatus = newRemaining <= 0 ? 'returned' : 'partial'

  await supabase.from('other_payables').update({
    returned_amount: newReturned,
    remaining_amount: newRemaining,
    status: newStatus,
    updated_at: new Date().toISOString()
  }).eq('id', item.id)

  saving.value = false
  showReturnDialog.value = false
  await fetchList()
}

async function handleDelete(item) {
  if (!confirm(`确定要删除 ${item.counterparty} 的应付款记录吗？`)) return
  await supabase.from('other_payables').update({
    deleted_at: new Date().toISOString()
  }).eq('id', item.id)
  await fetchList()
}

function typeBadgeClass(type) {
  const map = {
    deposit: 'bg-purple-50 text-purple-700',
    guarantee: 'bg-blue-50 text-blue-700',
    other: 'bg-gray-100 text-gray-600'
  }
  return map[type] || 'bg-gray-100 text-gray-600'
}

function typeLabel(type) {
  const map = { deposit: '押金', guarantee: '保证金', other: '其他' }
  return map[type] || type
}

function statusClass(status) {
  const map = {
    pending: 'bg-yellow-50 text-yellow-700',
    partial: 'bg-blue-50 text-blue-700',
    returned: 'bg-green-50 text-green-700'
  }
  return map[status] || 'bg-gray-100 text-gray-600'
}

function statusLabel(status) {
  const map = { pending: '待退还', partial: '部分退还', returned: '已退还' }
  return map[status] || status
}

function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatAmount(val) {
  return Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}
</script>
