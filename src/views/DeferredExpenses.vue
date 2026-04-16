<template>
  <div class="space-y-6">
    <!-- 统计卡片 -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
      <div v-for="stat in stats" :key="stat.label" class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1">{{ stat.icon }}</div>
        <div class="text-2xl font-bold text-gray-800">{{ stat.value }}</div>
        <div class="text-xs text-gray-500">{{ stat.label }}</div>
      </div>
    </div>

    <!-- 筛选与操作栏 -->
    <div class="bg-white rounded-xl border border-gray-100">
      <div class="px-4 py-3 border-b border-gray-100">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-2 flex-wrap">
            <select v-model="filterCategory"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部类别</option>
              <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
            </select>
            <select v-model="filterStatus"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部状态</option>
              <option value="active">摊销中</option>
              <option value="completed">已完成</option>
              <option value="stopped">已停止</option>
            </select>
            <input v-model="searchQuery" type="text" placeholder="搜索名称..."
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm w-48 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
          </div>
          <div class="flex items-center gap-2">
            <button @click="confirmMonthlyAmortization"
              class="px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition cursor-pointer">
              📅 本月摊销
            </button>
            <button @click="openAddModal"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer">
              + 添加待摊费用
            </button>
          </div>
        </div>
      </div>

      <!-- 桌面端表格 -->
      <div v-if="!isMobile" class="p-4 overflow-x-auto">
        <div v-if="filteredItems.length === 0" class="text-center py-12 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          <div>暂无待摊费用数据</div>
        </div>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-xs font-medium text-gray-500 uppercase">
              <th class="px-3 py-3 text-left">名称</th>
              <th class="px-3 py-3 text-left">类别</th>
              <th class="px-3 py-3 text-right">总额</th>
              <th class="px-3 py-3 text-left">起始日期</th>
              <th class="px-3 py-3 text-center">摊销期(月)</th>
              <th class="px-3 py-3 text-right">月摊额</th>
              <th class="px-3 py-3 text-right">已摊销</th>
              <th class="px-3 py-3 text-right">剩余</th>
              <th class="px-3 py-3 text-center">进度</th>
              <th class="px-3 py-3 text-center">状态</th>
              <th class="px-3 py-3 text-center">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filteredItems" :key="item.id" class="border-t border-gray-50 hover:bg-gray-50/50">
              <td class="px-3 py-3 font-medium text-gray-800">{{ item.name }}</td>
              <td class="px-3 py-3 text-gray-600">{{ item.category }}</td>
              <td class="px-3 py-3 text-right text-gray-800">{{ formatMoney(item.total_amount) }}</td>
              <td class="px-3 py-3 text-gray-600">{{ item.start_date }}</td>
              <td class="px-3 py-3 text-center text-gray-600">{{ item.amortization_months }}</td>
              <td class="px-3 py-3 text-right text-gray-600">{{ formatMoney(item.monthly_amount) }}</td>
              <td class="px-3 py-3 text-right text-blue-600">{{ formatMoney(item.amortized_amount) }}</td>
              <td class="px-3 py-3 text-right text-gray-800">{{ formatMoney(item.remaining_amount) }}</td>
              <td class="px-3 py-3">
                <div class="flex items-center gap-2">
                  <div class="flex-1 bg-gray-200 rounded-full h-2 min-w-[60px]">
                    <div class="bg-blue-500 h-2 rounded-full transition-all"
                      :style="{ width: progressPercent(item) + '%' }"></div>
                  </div>
                  <span class="text-xs text-gray-500 w-10 text-right">{{ progressPercent(item) }}%</span>
                </div>
              </td>
              <td class="px-3 py-3 text-center">
                <span :class="statusClass(item.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                  {{ statusLabel(item.status) }}
                </span>
              </td>
              <td class="px-3 py-3 text-center">
                <div class="flex items-center justify-center gap-1">
                  <button @click="openEditModal(item)" class="text-xs text-blue-600 hover:underline cursor-pointer">编辑</button>
                  <span class="text-gray-300">|</span>
                  <button @click="deleteItem(item)" class="text-xs text-red-500 hover:underline cursor-pointer">删除</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 移动端卡片 -->
      <div v-else class="p-4">
        <div v-if="filteredItems.length === 0" class="text-center py-12 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          <div>暂无待摊费用数据</div>
        </div>
        <div v-else class="space-y-3">
          <div v-for="item in filteredItems" :key="item.id"
            class="border border-gray-100 rounded-lg p-4 hover:shadow-sm transition">
            <div class="flex items-start justify-between mb-2">
              <div>
                <div class="font-medium text-gray-800">{{ item.name }}</div>
                <div class="text-xs text-gray-500 mt-0.5">{{ item.category }} · {{ item.start_date }}</div>
              </div>
              <span :class="statusClass(item.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                {{ statusLabel(item.status) }}
              </span>
            </div>
            <div class="grid grid-cols-3 gap-2 text-sm mb-3">
              <div>
                <div class="text-xs text-gray-500">总额</div>
                <div class="font-medium text-gray-800">{{ formatMoney(item.total_amount) }}</div>
              </div>
              <div>
                <div class="text-xs text-gray-500">已摊销</div>
                <div class="font-medium text-blue-600">{{ formatMoney(item.amortized_amount) }}</div>
              </div>
              <div>
                <div class="text-xs text-gray-500">剩余</div>
                <div class="font-medium text-gray-800">{{ formatMoney(item.remaining_amount) }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2 mb-3">
              <div class="flex-1 bg-gray-200 rounded-full h-2">
                <div class="bg-blue-500 h-2 rounded-full transition-all"
                  :style="{ width: progressPercent(item) + '%' }"></div>
              </div>
              <span class="text-xs text-gray-500">{{ progressPercent(item) }}%</span>
            </div>
            <div class="flex items-center gap-2 text-xs text-gray-500">
              <span>月摊额: {{ formatMoney(item.monthly_amount) }}</span>
              <span>·</span>
              <span>{{ item.amortization_months }}个月</span>
              <span class="flex-1"></span>
              <button @click="openEditModal(item)" class="text-blue-600 hover:underline cursor-pointer">编辑</button>
              <button @click="deleteItem(item)" class="text-red-500 hover:underline cursor-pointer">删除</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 添加/编辑弹窗 -->
    <div v-if="showFormModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="closeFormModal">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h3 class="font-semibold text-gray-800">{{ editingItem ? '编辑待摊费用' : '添加待摊费用' }}</h3>
          <button @click="closeFormModal" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="px-6 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">名称 <span class="text-red-500">*</span></label>
            <input v-model="form.name" type="text" placeholder="如：办公室装修费"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">类别</label>
            <select v-model="form.category"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200">
              <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
            </select>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">总金额</label>
              <input v-model.number="form.total_amount" type="number" step="0.01" min="0" placeholder="0.00"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">摊销期(月)</label>
              <select v-model.number="form.amortization_months"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200">
                <option :value="12">12个月</option>
                <option :value="24">24个月</option>
                <option :value="36">36个月</option>
                <option :value="48">48个月</option>
                <option :value="60">60个月</option>
                <option :value="120">120个月</option>
              </select>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">起始日期</label>
            <input v-model="form.start_date" type="date"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div v-if="form.total_amount > 0 && form.amortization_months > 0"
            class="bg-blue-50 rounded-lg p-3 text-sm text-blue-800">
            月摊销额: <span class="font-semibold">{{ formatMoney(form.total_amount / form.amortization_months) }}</span>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="备注信息..."
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 resize-none"></textarea>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="closeFormModal" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-50 rounded-lg transition cursor-pointer">取消</button>
          <button @click="saveItem" :disabled="!form.name || saving"
            class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
            {{ saving ? '保存中...' : (editingItem ? '保存' : '添加') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'

const categories = ['装修费', '租赁费', '开办费', '其他']

const items = ref([])
const loading = ref(false)
const searchQuery = ref('')
const filterCategory = ref('')
const filterStatus = ref('')
const isMobile = ref(window.innerWidth < 768)

const showFormModal = ref(false)
const editingItem = ref(null)
const saving = ref(false)
const form = ref({
  name: '', category: '装修费', total_amount: 0,
  start_date: '', amortization_months: 12, note: ''
})

function handleResize() {
  isMobile.value = window.innerWidth < 768
}

onMounted(() => {
  window.addEventListener('resize', handleResize)
  fetchItems()
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
})

const filteredItems = computed(() => {
  let list = items.value
  if (filterCategory.value) {
    list = list.filter(i => i.category === filterCategory.value)
  }
  if (filterStatus.value) {
    list = list.filter(i => i.status === filterStatus.value)
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(i => i.name && i.name.toLowerCase().includes(q))
  }
  return list
})

const stats = computed(() => {
  const list = items.value
  const totalAmount = list.reduce((s, i) => s + Number(i.total_amount || 0), 0)
  const amortized = list.reduce((s, i) => s + Number(i.amortized_amount || 0), 0)
  const remaining = list.reduce((s, i) => s + Number(i.remaining_amount || 0), 0)
  const activeItems = list.filter(i => i.status === 'active')
  const monthlyDue = activeItems.reduce((s, i) => s + Number(i.monthly_amount || 0), 0)
  return [
    { icon: '💰', label: '待摊总额', value: formatMoney(totalAmount) },
    { icon: '✅', label: '已摊销', value: formatMoney(amortized) },
    { icon: '⏳', label: '未摊销', value: formatMoney(remaining) },
    { icon: '📅', label: '本月应摊额', value: formatMoney(monthlyDue) },
    { icon: '📊', label: '活跃项数', value: activeItems.length },
  ]
})

function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function progressPercent(item) {
  if (!item.total_amount || item.total_amount <= 0) return 0
  return Math.min(100, Math.round((item.amortized_amount / item.total_amount) * 100))
}

function statusClass(status) {
  const map = {
    active: 'bg-green-50 text-green-700',
    completed: 'bg-blue-50 text-blue-700',
    stopped: 'bg-red-50 text-red-700',
  }
  return map[status] || 'bg-gray-100 text-gray-500'
}

function statusLabel(status) {
  const map = { active: '摊销中', completed: '已完成', stopped: '已停止' }
  return map[status] || status
}

function resetForm() {
  form.value = {
    name: '', category: '装修费', total_amount: 0,
    start_date: '', amortization_months: 12, note: ''
  }
  editingItem.value = null
}

function openAddModal() {
  resetForm()
  showFormModal.value = true
}

function openEditModal(item) {
  editingItem.value = item
  form.value = {
    name: item.name,
    category: item.category || '装修费',
    total_amount: Number(item.total_amount) || 0,
    start_date: item.start_date || '',
    amortization_months: item.amortization_months || 12,
    note: item.note || '',
  }
  showFormModal.value = true
}

function closeFormModal() {
  showFormModal.value = false
  resetForm()
}

async function fetchItems() {
  loading.value = true
  const { data, error } = await supabase
    .from('deferred_expenses')
    .select('*')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
  if (!error && data) {
    items.value = data
  }
  loading.value = false
}

async function saveItem() {
  if (!form.value.name) return
  if (saving.value) return
  saving.value = true
  try {
  const monthlyAmount = form.value.total_amount > 0 && form.value.amortization_months > 0
    ? Number((form.value.total_amount / form.value.amortization_months).toFixed(2))
    : 0

  if (editingItem.value) {
    const remainingAmount = form.value.total_amount - (editingItem.value.amortized_amount || 0)
    const payload = {
      name: form.value.name,
      category: form.value.category,
      total_amount: form.value.total_amount,
      start_date: form.value.start_date || null,
      amortization_months: form.value.amortization_months,
      monthly_amount: monthlyAmount,
      remaining_amount: Math.max(0, remainingAmount),
      note: form.value.note || null,
      updated_at: new Date().toISOString(),
    }
    const { error } = await supabase.from('deferred_expenses').update(payload).eq('id', editingItem.value.id)
    if (!error) closeFormModal()
  } else {
    const payload = {
      name: form.value.name,
      category: form.value.category,
      total_amount: form.value.total_amount,
      start_date: form.value.start_date || null,
      amortization_months: form.value.amortization_months,
      monthly_amount: monthlyAmount,
      amortized_amount: 0,
      remaining_amount: form.value.total_amount,
      status: 'active',
      note: form.value.note || null,
    }
    const { error } = await supabase.from('deferred_expenses').insert(payload)
    if (!error) closeFormModal()
  }
  await fetchItems()
  } finally {
    saving.value = false
  }
}

async function deleteItem(item) {
  if (!confirm(`确定删除 "${item.name}" 吗？`)) return
  await supabase.from('deferred_expenses')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', item.id)
  await fetchItems()
}

async function confirmMonthlyAmortization() {
  const activeItems = items.value.filter(i => i.status === 'active')
  if (activeItems.length === 0) {
    alert('没有需要摊销的活跃项目')
    return
  }
  const totalMonthly = activeItems.reduce((s, i) => s + Number(i.monthly_amount || 0), 0)
  if (!confirm(`确认执行本月摊销？\n\n将对 ${activeItems.length} 个活跃项目执行摊销\n本月摊销总额: ¥${totalMonthly.toFixed(2)}`)) return

  for (const item of activeItems) {
    const monthly = Number(item.monthly_amount || 0)
    const newAmortized = Number(item.amortized_amount || 0) + monthly
    const newRemaining = Number(item.total_amount || 0) - newAmortized
    const newStatus = newRemaining <= 0 ? 'completed' : 'active'
    await supabase.from('deferred_expenses').update({
      amortized_amount: Math.min(newAmortized, Number(item.total_amount)),
      remaining_amount: Math.max(0, newRemaining),
      status: newStatus,
      updated_at: new Date().toISOString(),
    }).eq('id', item.id)
  }
  await fetchItems()
  alert('本月摊销已完成')
}
</script>
