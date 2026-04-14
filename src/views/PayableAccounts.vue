<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">📑 应付账款管理</h1>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">💰 应付总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(stats.totalAmount) }}</div>
        <div class="text-xs text-gray-500 mt-1">共 {{ list.length }} 笔</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">✅ 已付</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.paidAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">⏳ 未付</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(stats.unpaidAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">🔴 逾期笔数</div>
        <div class="text-2xl font-bold text-red-600">{{ stats.overdueCount }}</div>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6">
      <div class="flex flex-wrap items-center gap-3">
        <select v-model="filterStatus"
          class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">全部状态</option>
          <option value="unpaid">未付</option>
          <option value="partial">部分付款</option>
          <option value="paid">已付</option>
        </select>
        <input v-model="searchKeyword" type="text" placeholder="搜索供应商..."
          class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 flex-1 min-w-[160px]" />
        <button @click="openModal()"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer ml-auto">
          + 添加应付
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="text-gray-500">加载中...</div>
    </div>

    <!-- Empty -->
    <div v-else-if="filteredList.length === 0" class="text-center py-20">
      <div class="text-4xl mb-3">📑</div>
      <div class="text-gray-500">暂无应付账款记录</div>
      <button @click="openModal()" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        添加第一笔应付款
      </button>
    </div>

    <!-- Desktop Table -->
    <div v-else-if="!isMobile" class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-gray-50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">供应商</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">应付金额</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">到期日</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">账期</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">发票号</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">已付</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">未付</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">状态</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in filteredList" :key="item.id"
            class="border-t border-gray-50 hover:bg-gray-50/50"
            :class="isOverdue(item) ? 'bg-red-50/60 border-l-4 border-l-red-400' : ''">
            <td class="px-4 py-3 text-sm font-medium text-gray-800">{{ item.supplier_name }}</td>
            <td class="px-4 py-3 text-sm text-right text-gray-800">{{ formatMoney(item.amount) }}</td>
            <td class="px-4 py-3 text-sm text-center" :class="isOverdue(item) ? 'text-red-600 font-medium' : 'text-gray-600'">
              {{ item.due_date || '-' }}
            </td>
            <td class="px-4 py-3 text-sm text-center text-gray-600">{{ item.credit_days ?? 30 }}天</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.invoice_number || '-' }}</td>
            <td class="px-4 py-3 text-sm text-right text-green-600">{{ formatMoney(item.paid_amount) }}</td>
            <td class="px-4 py-3 text-sm text-right text-orange-500">{{ formatMoney(item.remaining_amount) }}</td>
            <td class="px-4 py-3 text-center">
              <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(item.status)">
                {{ statusLabel(item.status) }}
              </span>
            </td>
            <td class="px-4 py-3 text-center">
              <div class="flex items-center justify-center gap-2">
                <button @click="openModal(item)" class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer">编辑</button>
                <button v-if="item.status !== 'paid'" @click="openPay(item)"
                  class="text-green-600 hover:text-green-800 text-xs cursor-pointer">付款</button>
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
        class="bg-white rounded-xl border border-gray-100 p-4"
        :class="isOverdue(item) ? 'border-l-4 border-l-red-400 bg-red-50/40' : ''">
        <div class="flex items-start justify-between mb-2">
          <div class="font-semibold text-gray-800">{{ item.supplier_name }}</div>
          <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(item.status)">
            {{ statusLabel(item.status) }}
          </span>
        </div>
        <div class="text-xl font-bold text-blue-600 mb-2">{{ formatMoney(item.amount) }}</div>
        <div class="grid grid-cols-2 gap-2 text-xs text-gray-500 mb-3">
          <div :class="isOverdue(item) ? 'text-red-600 font-medium' : ''">到期日: {{ item.due_date || '-' }}</div>
          <div>账期: {{ item.credit_days ?? 30 }}天</div>
          <div>发票号: {{ item.invoice_number || '-' }}</div>
          <div class="text-green-600">已付: {{ formatMoney(item.paid_amount) }}</div>
          <div class="text-orange-500">未付: {{ formatMoney(item.remaining_amount) }}</div>
        </div>
        <div class="flex items-center gap-3 pt-2 border-t border-gray-100">
          <button @click="openModal(item)" class="text-blue-600 text-xs cursor-pointer">编辑</button>
          <button v-if="item.status !== 'paid'" @click="openPay(item)"
            class="text-green-600 text-xs cursor-pointer">付款</button>
          <button @click="handleDelete(item)" class="text-red-500 text-xs cursor-pointer">删除</button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showModal = false">
      <div class="bg-white rounded-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">{{ editingItem ? '编辑应付账款' : '添加应付账款' }}</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">供应商名称 <span class="text-red-500">*</span></label>
            <input v-model="form.supplier_name" type="text" placeholder="请输入供应商名称"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">应付金额</label>
              <input v-model.number="form.amount" type="number" step="0.01" placeholder="0.00"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">到期日</label>
              <input v-model="form.due_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">账期(天)</label>
              <input v-model.number="form.credit_days" type="number" placeholder="30"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">发票号</label>
              <input v-model="form.invoice_number" type="text" placeholder="发票编号"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
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

    <!-- Pay Modal -->
    <div v-if="showPayModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showPayModal = false">
      <div class="bg-white rounded-xl w-full max-w-sm mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-2">付款</h2>
        <p class="text-sm text-gray-500 mb-4">
          供应商: {{ payingItem?.supplier_name }} | 未付: {{ formatMoney(payingItem?.remaining_amount) }}
        </p>
        <div>
          <label class="block text-sm text-gray-600 mb-1">付款金额</label>
          <input v-model.number="payAmount" type="number" step="0.01" placeholder="0.00"
            class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showPayModal = false"
            class="px-4 py-2 rounded-lg text-sm text-gray-600 hover:bg-gray-100 transition cursor-pointer">取消</button>
          <button @click="handlePay"
            class="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition cursor-pointer">
            确认付款
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'

const TABLE = 'payable_accounts'

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

// Pay state
const showPayModal = ref(false)
const payingItem = ref(null)
const payAmount = ref(0)

function emptyForm() {
  return { supplier_name: '', amount: null, due_date: '', credit_days: 30, invoice_number: '', note: '' }
}

const todayStr = computed(() => new Date().toISOString().slice(0, 10))

function isOverdue(item) {
  return item.due_date && item.due_date < todayStr.value && item.status !== 'paid'
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
    paidAmount: items.reduce((s, i) => s + Number(i.paid_amount || 0), 0),
    unpaidAmount: items.reduce((s, i) => s + Number(i.remaining_amount || 0), 0),
    overdueCount: items.filter(i => isOverdue(i)).length
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
    ? { supplier_name: item.supplier_name, amount: item.amount, due_date: item.due_date, credit_days: item.credit_days, invoice_number: item.invoice_number, note: item.note }
    : emptyForm()
  showModal.value = true
}

async function handleSave() {
  if (!form.value.supplier_name?.trim()) return alert('请输入供应商名称')
  const amount = Number(form.value.amount) || 0
  const paidAmt = editingItem.value ? Number(editingItem.value.paid_amount) || 0 : 0
  const remaining = amount - paidAmt
  let status = 'unpaid'
  if (paidAmt > 0 && remaining > 0) status = 'partial'
  if (remaining <= 0) status = 'paid'

  const payload = {
    supplier_name: form.value.supplier_name.trim(),
    amount,
    due_date: form.value.due_date || null,
    credit_days: form.value.credit_days ?? 30,
    invoice_number: form.value.invoice_number || null,
    note: form.value.note || null,
    remaining_amount: remaining,
    status
  }

  if (editingItem.value) {
    await supabase.from(TABLE).update({ ...payload, updated_at: new Date().toISOString() }).eq('id', editingItem.value.id)
  } else {
    payload.paid_amount = 0
    await supabase.from(TABLE).insert(payload)
  }
  showModal.value = false
  await fetchData()
}

// Pay
function openPay(item) {
  payingItem.value = item
  payAmount.value = null
  showPayModal.value = true
}

async function handlePay() {
  const amt = Number(payAmount.value)
  if (!amt || amt <= 0) return alert('请输入有效的付款金额')
  const item = payingItem.value
  const newPaid = Number(item.paid_amount || 0) + amt
  const newRemaining = Number(item.amount || 0) - newPaid
  let status = 'partial'
  if (newRemaining <= 0) status = 'paid'

  await supabase.from(TABLE).update({
    paid_amount: newPaid,
    remaining_amount: Math.max(newRemaining, 0),
    status,
    updated_at: new Date().toISOString()
  }).eq('id', item.id)

  showPayModal.value = false
  await fetchData()
}

// Delete
async function handleDelete(item) {
  if (!confirm(`确定删除「${item.supplier_name}」的应付记录吗？`)) return
  await supabase.from(TABLE).update({ deleted_at: new Date().toISOString() }).eq('id', item.id)
  await fetchData()
}

// Helpers
function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function statusLabel(s) {
  return { unpaid: '未付', partial: '部分付款', paid: '已付' }[s] || s
}

function statusClass(s) {
  return {
    unpaid: 'bg-yellow-50 text-yellow-700',
    partial: 'bg-blue-50 text-blue-700',
    paid: 'bg-green-50 text-green-700'
  }[s] || 'bg-gray-50 text-gray-600'
}
</script>
