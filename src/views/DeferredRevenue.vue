<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">📋 预收账款管理</h1>
      <button
        @click="openCreateModal"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer"
      >
        + 添加预收
      </button>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">💰 预收总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(stats.totalAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">✅ 已消课金额</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.consumedAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">⏳ 未消课金额</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(stats.remainingAmount) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">🟢 活跃学员数</div>
        <div class="text-2xl font-bold text-blue-600">{{ stats.activeCount }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-sm text-gray-500 mb-1">🎓 已完成学员数</div>
        <div class="text-2xl font-bold text-gray-600">{{ stats.completedCount }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6">
      <div class="flex flex-wrap items-center gap-3">
        <select v-model="filterStatus" class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">全部状态</option>
          <option value="active">进行中</option>
          <option value="completed">已完成</option>
          <option value="refunded">已退款</option>
        </select>
        <select v-model="filterProduct" class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">全部课程</option>
          <option v-for="p in productOptions" :key="p" :value="p">{{ p }}</option>
        </select>
        <input
          v-model="searchText"
          type="text"
          placeholder="搜索客户姓名/电话"
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
      <div class="text-4xl mb-3">📋</div>
      <div class="text-gray-500">暂无预收账款记录</div>
      <button @click="openCreateModal" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        添加第一笔预收
      </button>
    </div>

    <!-- Desktop Table -->
    <div v-else-if="!isMobile" class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-gray-50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">客户姓名</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">电话</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">课程</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">总额</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">收款日期</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">总课时</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">已消</th>
            <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 uppercase">剩余</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">消课进度</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">状态</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">操作</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-50">
          <tr v-for="item in filteredList" :key="item.id" class="hover:bg-gray-50/50 transition">
            <td class="px-4 py-3 text-sm font-medium text-gray-800">{{ item.customer_name }}</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.phone || '-' }}</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.product_name }}</td>
            <td class="px-4 py-3 text-sm text-gray-800 text-right font-medium">{{ formatMoney(item.total_amount) }}</td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ item.received_date }}</td>
            <td class="px-4 py-3 text-sm text-gray-600 text-center">{{ item.total_sessions }}</td>
            <td class="px-4 py-3 text-sm text-gray-600 text-center">{{ item.consumed_sessions }}</td>
            <td class="px-4 py-3 text-sm text-gray-600 text-center">{{ item.remaining_sessions }}</td>
            <td class="px-4 py-3 text-sm">
              <div class="flex items-center gap-2">
                <div class="flex-1 bg-gray-100 rounded-full h-2 w-20">
                  <div class="h-2 rounded-full transition-all"
                    :class="progressPercent(item) >= 100 ? 'bg-green-500' : 'bg-blue-500'"
                    :style="{ width: Math.min(progressPercent(item), 100) + '%' }"></div>
                </div>
                <span class="text-xs text-gray-500 w-10 text-right">{{ progressPercent(item) }}%</span>
              </div>
            </td>
            <td class="px-4 py-3">
              <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="statusClass(item.status)">
                {{ statusLabel(item.status) }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-2">
                <button @click="openEditModal(item)" class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer">编辑</button>
                <button @click="openConsumeDialog(item)" class="text-green-600 hover:text-green-800 text-xs cursor-pointer" v-if="item.status === 'active'">消课</button>
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
          <div>
            <div class="font-semibold text-gray-800">{{ item.customer_name }}</div>
            <div class="text-xs text-gray-500">{{ item.phone || '-' }} / {{ item.product_name }}</div>
          </div>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
            :class="statusClass(item.status)">
            {{ statusLabel(item.status) }}
          </span>
        </div>
        <div class="flex items-baseline gap-1 mb-2">
          <span class="text-sm text-gray-500">¥</span>
          <span class="text-xl font-bold text-gray-800">{{ formatAmount(item.total_amount) }}</span>
          <span class="text-xs text-gray-500 ml-2">收款 {{ item.received_date }}</span>
        </div>
        <div class="flex items-center gap-4 text-xs text-gray-500 mb-2">
          <span>总课时 {{ item.total_sessions }}</span>
          <span>已消 {{ item.consumed_sessions }}</span>
          <span>剩余 {{ item.remaining_sessions }}</span>
        </div>
        <div class="mb-3">
          <div class="flex items-center justify-between text-xs mb-1">
            <span class="text-gray-500">消课进度</span>
            <span class="text-gray-600 font-medium">{{ progressPercent(item) }}%</span>
          </div>
          <div class="w-full bg-gray-100 rounded-full h-2">
            <div class="h-2 rounded-full transition-all"
              :class="progressPercent(item) >= 100 ? 'bg-green-500' : 'bg-blue-500'"
              :style="{ width: Math.min(progressPercent(item), 100) + '%' }"></div>
          </div>
        </div>
        <div class="flex items-center gap-3 pt-2 border-t border-gray-100">
          <button @click="openEditModal(item)" class="text-blue-600 text-xs cursor-pointer">编辑</button>
          <button @click="openConsumeDialog(item)" class="text-green-600 text-xs cursor-pointer" v-if="item.status === 'active'">消课</button>
          <button @click="handleDelete(item)" class="text-red-500 text-xs cursor-pointer">删除</button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showModal = false">
      <div class="bg-white rounded-xl w-full max-w-lg mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-lg font-bold text-gray-800 mb-4">{{ isEdit ? '编辑预收' : '添加预收' }}</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">客户姓名 <span class="text-red-500">*</span></label>
            <input v-model="form.customer_name" type="text" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">电话</label>
            <input v-model="form.phone" type="text" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">课程</label>
            <select v-model="form.product_name" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option value="线下课">线下课</option>
              <option value="私教课">私教课</option>
              <option value="VIP课程">VIP课程</option>
              <option value="其他">其他</option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">总金额</label>
            <input v-model.number="form.total_amount" type="number" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">收款日期</label>
            <input v-model="form.received_date" type="date" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">总课时</label>
            <input v-model.number="form.total_sessions" type="number" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
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

    <!-- Consume Dialog -->
    <div v-if="showConsumeDialog" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showConsumeDialog = false">
      <div class="bg-white rounded-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">消课 - {{ consumeTarget?.customer_name }}</h2>
        <div class="text-sm text-gray-500 mb-4">
          剩余课时: {{ consumeTarget?.remaining_sessions }} 节 / 剩余金额: {{ formatMoney(consumeTarget?.remaining_amount) }}
        </div>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">消课数量（节）</label>
            <input v-model.number="consumeSessions" type="number" min="1" :max="consumeTarget?.remaining_sessions"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              @input="calcConsumeAmount" />
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">消课金额</label>
            <input v-model.number="consumeAmount" type="number" readonly
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm bg-gray-50 text-gray-600" />
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showConsumeDialog = false" class="px-4 py-2 text-sm text-gray-600 hover:text-gray-800 cursor-pointer">取消</button>
          <button @click="handleConsume" :disabled="saving" class="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition cursor-pointer disabled:opacity-50">
            {{ saving ? '处理中...' : '确认消课' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'

const loading = ref(false)
const saving = ref(false)
const list = ref([])
const showModal = ref(false)
const showConsumeDialog = ref(false)
const isEdit = ref(false)
const editId = ref(null)
const searchText = ref('')
const filterStatus = ref('')
const filterProduct = ref('')
const isMobile = ref(window.innerWidth < 768)

const productOptions = ['线下课', '私教课', 'VIP课程', '其他']

const defaultForm = () => ({
  customer_name: '',
  phone: '',
  product_name: '线下课',
  total_amount: 9800,
  received_date: new Date().toISOString().slice(0, 10),
  total_sessions: 0,
  note: ''
})
const form = ref(defaultForm())

const consumeTarget = ref(null)
const consumeSessions = ref(1)
const consumeAmount = ref(0)

const handleResize = () => { isMobile.value = window.innerWidth < 768 }
onMounted(() => {
  window.addEventListener('resize', handleResize)
  fetchList()
})
onUnmounted(() => { window.removeEventListener('resize', handleResize) })

const stats = computed(() => {
  const items = list.value
  return {
    totalAmount: items.reduce((s, i) => s + Number(i.total_amount || 0), 0),
    consumedAmount: items.reduce((s, i) => s + Number(i.consumed_amount || 0), 0),
    remainingAmount: items.reduce((s, i) => s + Number(i.remaining_amount || 0), 0),
    activeCount: items.filter(i => i.status === 'active').length,
    completedCount: items.filter(i => i.status === 'completed').length
  }
})

const filteredList = computed(() => {
  let result = list.value
  if (filterStatus.value) {
    result = result.filter(i => i.status === filterStatus.value)
  }
  if (filterProduct.value) {
    result = result.filter(i => i.product_name === filterProduct.value)
  }
  if (searchText.value) {
    const s = searchText.value.toLowerCase()
    result = result.filter(i =>
      (i.customer_name || '').toLowerCase().includes(s) ||
      (i.phone || '').includes(s)
    )
  }
  return result
})

async function fetchList() {
  loading.value = true
  const { data, error } = await supabase
    .from('deferred_revenue')
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
    customer_name: item.customer_name,
    phone: item.phone || '',
    product_name: item.product_name,
    total_amount: item.total_amount,
    received_date: item.received_date,
    total_sessions: item.total_sessions,
    note: item.note || ''
  }
  showModal.value = true
}

async function handleSave() {
  if (!form.value.customer_name) return alert('请输入客户姓名')
  saving.value = true

  const existing = isEdit.value ? list.value.find(i => i.id === editId.value) : null
  const consumedAmt = existing ? Number(existing.consumed_amount || 0) : 0
  const consumedSess = existing ? Number(existing.consumed_sessions || 0) : 0
  const remainingAmount = Number(form.value.total_amount) - consumedAmt
  const remainingSessions = Number(form.value.total_sessions) - consumedSess

  const payload = {
    customer_name: form.value.customer_name,
    phone: form.value.phone || null,
    product_name: form.value.product_name,
    total_amount: form.value.total_amount,
    received_date: form.value.received_date,
    total_sessions: form.value.total_sessions,
    remaining_amount: remainingAmount,
    remaining_sessions: remainingSessions,
    note: form.value.note || null,
    updated_at: new Date().toISOString()
  }

  if (isEdit.value) {
    await supabase.from('deferred_revenue').update(payload).eq('id', editId.value)
  } else {
    payload.consumed_amount = 0
    payload.consumed_sessions = 0
    payload.remaining_amount = payload.total_amount
    payload.remaining_sessions = payload.total_sessions
    payload.status = 'active'
    await supabase.from('deferred_revenue').insert(payload)
  }

  saving.value = false
  showModal.value = false
  await fetchList()
}

function openConsumeDialog(item) {
  consumeTarget.value = item
  consumeSessions.value = 1
  calcConsumeAmount()
  showConsumeDialog.value = true
}

function calcConsumeAmount() {
  if (!consumeTarget.value || !consumeTarget.value.total_sessions) {
    consumeAmount.value = 0
    return
  }
  const perSession = Number(consumeTarget.value.total_amount) / Number(consumeTarget.value.total_sessions)
  consumeAmount.value = Math.round(perSession * consumeSessions.value * 100) / 100
}

async function handleConsume() {
  if (!consumeTarget.value) return
  if (consumeSessions.value <= 0) return alert('请输入消课数量')
  if (consumeSessions.value > consumeTarget.value.remaining_sessions) return alert('消课数量不能超过剩余课时')

  saving.value = true
  const item = consumeTarget.value
  const newConsumedSessions = Number(item.consumed_sessions) + consumeSessions.value
  const newConsumedAmount = Number(item.consumed_amount) + consumeAmount.value
  const newRemainingSessions = Number(item.total_sessions) - newConsumedSessions
  const newRemainingAmount = Number(item.total_amount) - newConsumedAmount
  const newStatus = newRemainingSessions <= 0 ? 'completed' : 'active'

  await supabase.from('deferred_revenue').update({
    consumed_sessions: newConsumedSessions,
    consumed_amount: newConsumedAmount,
    remaining_sessions: newRemainingSessions,
    remaining_amount: newRemainingAmount,
    status: newStatus,
    updated_at: new Date().toISOString()
  }).eq('id', item.id)

  saving.value = false
  showConsumeDialog.value = false
  await fetchList()
}

async function handleDelete(item) {
  if (!confirm(`确定要删除 ${item.customer_name} 的预收记录吗？`)) return
  await supabase.from('deferred_revenue').update({
    deleted_at: new Date().toISOString()
  }).eq('id', item.id)
  await fetchList()
}

function progressPercent(item) {
  if (!item.total_sessions) return 0
  return Math.round((item.consumed_sessions / item.total_sessions) * 100)
}

function statusClass(status) {
  const map = {
    active: 'bg-green-50 text-green-700',
    completed: 'bg-gray-100 text-gray-600',
    refunded: 'bg-red-50 text-red-600'
  }
  return map[status] || 'bg-gray-100 text-gray-600'
}

function statusLabel(status) {
  const map = { active: '进行中', completed: '已完成', refunded: '已退款' }
  return map[status] || status
}

function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatAmount(val) {
  return Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}
</script>
