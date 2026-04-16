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
            <select v-model="filterType"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部类型</option>
              <option v-for="t in assetTypes" :key="t" :value="t">{{ t }}</option>
            </select>
            <select v-model="filterStatus"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部状态</option>
              <option :value="INTANGIBLE_ASSET_STATUS.ACTIVE">有效</option>
              <option :value="INTANGIBLE_ASSET_STATUS.EXPIRED">已过期</option>
              <option :value="INTANGIBLE_ASSET_STATUS.DISPOSED">已处置</option>
            </select>
            <input v-model="searchQuery" type="text" placeholder="搜索名称/登记号..."
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm w-48 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
          </div>
          <button @click="openAddModal"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer">
            + 添加无形资产
          </button>
        </div>
      </div>

      <!-- 桌面端表格 -->
      <div v-if="!isMobile" class="p-4 overflow-x-auto">
        <div v-if="filteredItems.length === 0" class="text-center py-12 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          <div>暂无无形资产数据</div>
        </div>
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-xs font-medium text-gray-500 uppercase">
              <th class="px-3 py-3 text-left">名称</th>
              <th class="px-3 py-3 text-left">类型</th>
              <th class="px-3 py-3 text-left">登记号</th>
              <th class="px-3 py-3 text-left">取得日期</th>
              <th class="px-3 py-3 text-left">到期日</th>
              <th class="px-3 py-3 text-right">原值</th>
              <th class="px-3 py-3 text-right">累计摊销</th>
              <th class="px-3 py-3 text-right">净值</th>
              <th class="px-3 py-3 text-center">状态</th>
              <th class="px-3 py-3 text-center">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filteredItems" :key="item.id"
              class="border-t border-gray-50 hover:bg-gray-50/50"
              :class="{ 'bg-amber-50/50': isExpiringSoon(item) }">
              <td class="px-3 py-3 font-medium text-gray-800">
                {{ item.name }}
                <span v-if="isExpiringSoon(item)" class="ml-1 text-xs text-amber-600">⚠️ 即将到期</span>
              </td>
              <td class="px-3 py-3 text-gray-600">{{ item.asset_type }}</td>
              <td class="px-3 py-3 text-gray-600">{{ item.registration_number || '-' }}</td>
              <td class="px-3 py-3 text-gray-600">{{ item.registration_date || '-' }}</td>
              <td class="px-3 py-3" :class="isExpiringSoon(item) ? 'text-amber-600 font-medium' : 'text-gray-600'">
                {{ item.expiry_date || '-' }}
              </td>
              <td class="px-3 py-3 text-right text-gray-800">{{ formatMoney(item.purchase_cost) }}</td>
              <td class="px-3 py-3 text-right text-blue-600">{{ formatMoney(item.accumulated_amortization) }}</td>
              <td class="px-3 py-3 text-right text-gray-800 font-medium">{{ formatMoney(item.current_value) }}</td>
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
          <div>暂无无形资产数据</div>
        </div>
        <div v-else class="space-y-3">
          <div v-for="item in filteredItems" :key="item.id"
            class="border rounded-lg p-4 hover:shadow-sm transition"
            :class="isExpiringSoon(item) ? 'border-amber-200 bg-amber-50/30' : 'border-gray-100'">
            <div class="flex items-start justify-between mb-2">
              <div>
                <div class="font-medium text-gray-800">
                  {{ item.name }}
                  <span v-if="isExpiringSoon(item)" class="ml-1 text-xs text-amber-600">⚠️</span>
                </div>
                <div class="text-xs text-gray-500 mt-0.5">{{ item.asset_type }} · {{ item.registration_number || '无登记号' }}</div>
              </div>
              <span :class="statusClass(item.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                {{ statusLabel(item.status) }}
              </span>
            </div>
            <div class="grid grid-cols-3 gap-2 text-sm mb-3">
              <div>
                <div class="text-xs text-gray-500">原值</div>
                <div class="font-medium text-gray-800">{{ formatMoney(item.purchase_cost) }}</div>
              </div>
              <div>
                <div class="text-xs text-gray-500">累计摊销</div>
                <div class="font-medium text-blue-600">{{ formatMoney(item.accumulated_amortization) }}</div>
              </div>
              <div>
                <div class="text-xs text-gray-500">净值</div>
                <div class="font-medium text-gray-800">{{ formatMoney(item.current_value) }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2 text-xs text-gray-500">
              <span>取得: {{ item.registration_date || '-' }}</span>
              <span>·</span>
              <span :class="isExpiringSoon(item) ? 'text-amber-600 font-medium' : ''">
                到期: {{ item.expiry_date || '-' }}
              </span>
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
          <h3 class="font-semibold text-gray-800">{{ editingItem ? '编辑无形资产' : '添加无形资产' }}</h3>
          <button @click="closeFormModal" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="px-6 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">名称 <span class="text-red-500">*</span></label>
            <input v-model="form.name" type="text" placeholder="如：XX商标"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">资产类型</label>
              <select v-model="form.asset_type"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200">
                <option v-for="t in assetTypes" :key="t" :value="t">{{ t }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">登记号</label>
              <input v-model="form.registration_number" type="text" placeholder="登记/注册号"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">取得日期</label>
              <input v-model="form.registration_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">到期日</label>
              <input v-model="form.expiry_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">原值(购入成本)</label>
              <input v-model.number="form.purchase_cost" type="number" step="0.01" min="0" placeholder="0.00"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">使用年限(月)</label>
              <input v-model.number="form.useful_life_months" type="number" min="0" placeholder="可选"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
          </div>
          <div v-if="form.purchase_cost > 0 && form.useful_life_months > 0"
            class="bg-blue-50 rounded-lg p-3 text-sm text-blue-800">
            月摊销额: <span class="font-semibold">{{ formatMoney(form.purchase_cost / form.useful_life_months) }}</span>
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
import { INTANGIBLE_ASSET_STATUS, INTANGIBLE_ASSET_STATUS_LABEL } from '../constants/enums'

const assetTypes = ['商标', '专利', '软件', '著作权', '其他']

const items = ref([])
const loading = ref(false)
const searchQuery = ref('')
const filterType = ref('')
const filterStatus = ref('')
const isMobile = ref(window.innerWidth < 768)

const showFormModal = ref(false)
const editingItem = ref(null)
const saving = ref(false)
const form = ref({
  name: '', asset_type: '商标', registration_number: '',
  registration_date: '', expiry_date: '', purchase_cost: 0,
  useful_life_months: null, note: ''
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
  if (filterType.value) {
    list = list.filter(i => i.asset_type === filterType.value)
  }
  if (filterStatus.value) {
    list = list.filter(i => i.status === filterStatus.value)
  }
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(i =>
      (i.name && i.name.toLowerCase().includes(q)) ||
      (i.registration_number && i.registration_number.toLowerCase().includes(q))
    )
  }
  return list
})

function isExpiringSoon(item) {
  if (!item.expiry_date || item.status !== INTANGIBLE_ASSET_STATUS.ACTIVE) return false
  const expiry = new Date(item.expiry_date)
  const now = new Date()
  const diff = (expiry - now) / (1000 * 60 * 60 * 24)
  return diff >= 0 && diff <= 90
}

const stats = computed(() => {
  const list = items.value
  const totalCost = list.reduce((s, i) => s + Number(i.purchase_cost || 0), 0)
  const totalAmortization = list.reduce((s, i) => s + Number(i.accumulated_amortization || 0), 0)
  const totalNetValue = list.reduce((s, i) => s + Number(i.current_value || 0), 0)
  const expiringSoon = list.filter(i => isExpiringSoon(i)).length
  return [
    { icon: '💎', label: '无形资产原值总额', value: formatMoney(totalCost) },
    { icon: '📉', label: '累计摊销', value: formatMoney(totalAmortization) },
    { icon: '💰', label: '净值', value: formatMoney(totalNetValue) },
    { icon: '⚠️', label: '即将到期(90天内)', value: expiringSoon },
    { icon: '📊', label: '资产数量', value: list.length },
  ]
})

function formatMoney(val) {
  return '¥' + Number(val || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function statusClass(status) {
  const map = {
    [INTANGIBLE_ASSET_STATUS.ACTIVE]: 'bg-green-50 text-green-700',
    [INTANGIBLE_ASSET_STATUS.EXPIRED]: 'bg-amber-50 text-amber-700',
    [INTANGIBLE_ASSET_STATUS.DISPOSED]: 'bg-red-50 text-red-700',
  }
  return map[status] || 'bg-gray-100 text-gray-500'
}

function statusLabel(status) {
  return INTANGIBLE_ASSET_STATUS_LABEL[status] || status
}

function resetForm() {
  form.value = {
    name: '', asset_type: '商标', registration_number: '',
    registration_date: '', expiry_date: '', purchase_cost: 0,
    useful_life_months: null, note: ''
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
    asset_type: item.asset_type || '商标',
    registration_number: item.registration_number || '',
    registration_date: item.registration_date || '',
    expiry_date: item.expiry_date || '',
    purchase_cost: Number(item.purchase_cost) || 0,
    useful_life_months: item.useful_life_months || null,
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
    .from('intangible_assets')
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
  const monthlyAmort = (form.value.purchase_cost > 0 && form.value.useful_life_months > 0)
    ? Number((form.value.purchase_cost / form.value.useful_life_months).toFixed(2))
    : 0

  if (editingItem.value) {
    const currentValue = form.value.purchase_cost - (editingItem.value.accumulated_amortization || 0)
    const payload = {
      name: form.value.name,
      asset_type: form.value.asset_type,
      registration_number: form.value.registration_number || null,
      registration_date: form.value.registration_date || null,
      expiry_date: form.value.expiry_date || null,
      purchase_cost: form.value.purchase_cost,
      useful_life_months: form.value.useful_life_months || null,
      current_value: Math.max(0, currentValue),
      note: form.value.note || null,
      updated_at: new Date().toISOString(),
    }
    const { error } = await supabase.from('intangible_assets').update(payload).eq('id', editingItem.value.id)
    if (!error) closeFormModal()
  } else {
    const payload = {
      name: form.value.name,
      asset_type: form.value.asset_type,
      registration_number: form.value.registration_number || null,
      registration_date: form.value.registration_date || null,
      expiry_date: form.value.expiry_date || null,
      purchase_cost: form.value.purchase_cost,
      useful_life_months: form.value.useful_life_months || null,
      accumulated_amortization: 0,
      current_value: form.value.purchase_cost,
      status: INTANGIBLE_ASSET_STATUS.ACTIVE,
      note: form.value.note || null,
    }
    const { error } = await supabase.from('intangible_assets').insert(payload)
    if (!error) closeFormModal()
  }
  await fetchItems()
  } finally {
    saving.value = false
  }
}

async function deleteItem(item) {
  if (!confirm(`确定删除 "${item.name}" 吗？`)) return
  await supabase.from('intangible_assets')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', item.id)
  await fetchItems()
}
</script>
