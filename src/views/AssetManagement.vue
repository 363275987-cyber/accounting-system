<template>
  <div class="space-y-6">
    <!-- 统计卡片 -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
      <div v-for="stat in stats" :key="stat.label" class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1">{{ stat.icon }}</div>
        <div class="text-2xl font-bold text-gray-800">{{ stat.total }}</div>
        <div class="text-xs text-gray-500">{{ stat.label }}</div>
        <div v-if="stat.active !== undefined" class="text-xs text-green-600 mt-1">活跃: {{ stat.active }}</div>
      </div>
    </div>

    <!-- Tab切换 + 操作栏 -->
    <div class="bg-white rounded-xl border border-gray-100">
      <div class="border-b border-gray-100 px-4 pt-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex gap-1">
            <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
              class="px-4 py-2 rounded-lg text-sm font-medium transition cursor-pointer"
              :class="activeTab === tab.key ? 'bg-blue-50 text-blue-700' : 'text-gray-500 hover:bg-gray-50'">
              {{ tab.icon }} {{ tab.label }}
            </button>
          </div>
          <div class="flex items-center gap-2">
            <input v-model="searchQuery" type="text" placeholder="搜索名称/序列号/分配人..."
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm w-56 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            <button @click="showBindGroupPanel = !showBindGroupPanel"
              class="px-3 py-2 rounded-lg text-sm border border-gray-200 hover:bg-gray-50 transition cursor-pointer"
              :class="showBindGroupPanel ? 'bg-purple-50 border-purple-200 text-purple-700' : 'text-gray-600'">
              🔗 绑定组
            </button>
            <button @click="openAddModal"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer">
              + 添加资产
            </button>
          </div>
        </div>
      </div>

      <!-- 资产列表 -->
      <div v-if="!showBindGroupPanel" class="p-4">
        <div v-if="filteredAssets.length === 0" class="text-center py-12 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          <div>暂无{{ tabs.find(t => t.key === activeTab)?.label }}数据</div>
        </div>
        <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
          <div v-for="asset in filteredAssets" :key="asset.id"
            class="border border-gray-100 rounded-lg p-4 hover:shadow-sm transition group">
            <div class="flex items-start justify-between mb-2">
              <div class="flex-1 min-w-0">
                <div class="font-medium text-gray-800 truncate">{{ asset.name }}</div>
                <div v-if="asset.serial_number" class="text-xs text-gray-500 mt-0.5 truncate">{{ asset.serial_number }}</div>
              </div>
              <span :class="statusClass(asset.status)"
                class="text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0 ml-2">
                {{ statusLabel(asset.status) }}
              </span>
            </div>
            <div class="space-y-1 text-sm">
              <div v-if="asset.assigned_to" class="flex items-center gap-1 text-gray-600">
                <span>👤</span><span>{{ asset.assigned_to }}</span>
              </div>
              <div v-if="asset.monthly_cost > 0" class="flex items-center gap-1 text-gray-600">
                <span>💰</span><span>¥{{ Number(asset.monthly_cost).toFixed(2) }}/月</span>
              </div>
              <div v-if="asset.bind_group" class="flex items-center gap-1 text-purple-600">
                <span>🔗</span><span>{{ asset.bind_group }}</span>
              </div>
            </div>
            <div class="flex items-center gap-1 mt-3 pt-3 border-t border-gray-50 opacity-0 group-hover:opacity-100 transition">
              <button @click="openEditModal(asset)" class="text-xs text-blue-600 hover:underline cursor-pointer">编辑</button>
              <span class="text-gray-300">|</span>
              <button @click="deleteAsset(asset)" class="text-xs text-red-500 hover:underline cursor-pointer">删除</button>
            </div>
          </div>
        </div>
      </div>

      <!-- 绑定组管理面板 -->
      <div v-else class="p-4">
        <div class="flex items-center justify-between mb-4">
          <h3 class="font-medium text-gray-800">绑定组管理</h3>
          <button @click="openBindGroupModal"
            class="px-3 py-1.5 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 transition cursor-pointer">
            + 创建绑定组
          </button>
        </div>
        <div v-if="bindGroups.length === 0" class="text-center py-8 text-gray-500">
          <div class="text-3xl mb-2">🔗</div>
          <div>暂无绑定组</div>
        </div>
        <div v-else class="space-y-3">
          <div v-for="group in bindGroups" :key="group.name" class="border border-gray-100 rounded-lg p-4">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <span class="font-medium text-gray-800">🔗 {{ group.name }}</span>
                <span class="text-xs text-gray-500">{{ group.assets.length }} 个资产</span>
              </div>
              <button @click="dissolveGroup(group.name)" class="text-xs text-red-500 hover:underline cursor-pointer">解除全部绑定</button>
            </div>
            <div class="flex flex-wrap gap-2">
              <span v-for="a in group.assets" :key="a.id"
                class="inline-flex items-center gap-1 px-2 py-1 bg-gray-50 rounded text-xs text-gray-600">
                {{ typeIcon(a.asset_type) }} {{ a.name }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 添加/编辑弹窗 -->
    <div v-if="showFormModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="closeFormModal">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h3 class="font-semibold text-gray-800">{{ editingAsset ? '编辑资产' : '添加资产' }}</h3>
          <button @click="closeFormModal" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="px-6 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">资产类型</label>
            <select v-model="form.asset_type"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200">
              <option value="phone">📱 手机</option>
              <option value="wechat">💬 微信号</option>
              <option value="sim_card">📶 SIM卡</option>
              <option value="bank_card">💳 银行卡</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">名称/标识</label>
            <input v-model="form.name" type="text" placeholder="如：华为P60、微信号-南1"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">序列号/微信号</label>
            <input v-model="form.serial_number" type="text" placeholder="序列号或微信号"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">状态</label>
              <select v-model="form.status"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200">
                <option :value="ASSET_STATUS.IN_USE">在用</option>
                <option :value="ASSET_STATUS.IDLE">闲置</option>
                <option :value="ASSET_STATUS.MAINTENANCE">维修中</option>
                <option :value="ASSET_STATUS.DISPOSED">已处置</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">月租费 (¥)</label>
              <input v-model="form.monthly_cost" type="number" step="0.01" min="0" placeholder="0.00"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">分配给</label>
            <input v-model="form.assigned_to" type="text" placeholder="使用人姓名"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">购买日期</label>
            <input v-model="form.purchase_date" type="date"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="备注信息..."
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 resize-none"></textarea>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="closeFormModal" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-50 rounded-lg transition cursor-pointer">取消</button>
          <button @click="saveAsset" :disabled="!form.name || savingAsset"
            class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
            {{ savingAsset ? '保存中...' : (editingAsset ? '保存' : '添加') }}
          </button>
        </div>
      </div>
    </div>

    <!-- 创建绑定组弹窗 -->
    <div v-if="showBindModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showBindModal = false">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h3 class="font-semibold text-gray-800">创建绑定组</h3>
          <button @click="showBindModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="px-6 py-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">组名</label>
            <input v-model="bindForm.name" type="text" placeholder="如：设备组A"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-200" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">选择要绑定的资产</label>
            <div class="max-h-48 overflow-y-auto border border-gray-200 rounded-lg">
              <label v-for="asset in allAssets" :key="asset.id"
                class="flex items-center gap-2 px-3 py-2 hover:bg-gray-50 cursor-pointer text-sm">
                <input type="checkbox" :value="asset.id" v-model="bindForm.assetIds" class="rounded" />
                <span>{{ typeIcon(asset.asset_type) }}</span>
                <span class="text-gray-700">{{ asset.name }}</span>
                <span v-if="asset.serial_number" class="text-gray-500 text-xs truncate">{{ asset.serial_number }}</span>
              </label>
            </div>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="showBindModal = false" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-50 rounded-lg transition cursor-pointer">取消</button>
          <button @click="createBindGroup" :disabled="!bindForm.name || bindForm.assetIds.length < 2 || creatingBindGroup"
            class="px-4 py-2 text-sm bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
            {{ creatingBindGroup ? '创建中...' : '创建绑定' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { ASSET_STATUS } from '../constants/enums'

const tabs = [
  { key: 'phone', label: '手机', icon: '📱' },
  { key: 'wechat', label: '微信号', icon: '💬' },
  { key: 'sim_card', label: 'SIM卡', icon: '📶' },
  { key: 'bank_card', label: '银行卡', icon: '💳' },
]

const activeTab = ref('phone')
const searchQuery = ref('')
const assets = ref([])
const loading = ref(false)
const showBindGroupPanel = ref(false)

// Form modal
const showFormModal = ref(false)
const editingAsset = ref(null)
const form = ref({
  asset_type: 'phone', name: '', serial_number: '', monthly_cost: 0,
  status: ASSET_STATUS.IN_USE, assigned_to: '', purchase_date: '', note: ''
})

// Bind group modal
const showBindModal = ref(false)
const bindForm = ref({ name: '', assetIds: [] })
const savingAsset = ref(false)
const creatingBindGroup = ref(false)

const allAssets = computed(() => assets.value)
const filteredAssets = computed(() => {
  let list = assets.value.filter(a => a.asset_type === activeTab.value)
  if (searchQuery.value.trim()) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(a =>
      (a.name && a.name.toLowerCase().includes(q)) ||
      (a.serial_number && a.serial_number.toLowerCase().includes(q)) ||
      (a.assigned_to && a.assigned_to.toLowerCase().includes(q))
    )
  }
  return list
})

const stats = computed(() => {
  const list = assets.value
  const countByType = (type) => {
    const items = list.filter(a => a.asset_type === type)
    return { total: items.length, active: items.filter(a => a.status === ASSET_STATUS.IN_USE).length }
  }
  const phone = countByType('phone')
  const wechat = countByType('wechat')
  const sim = countByType('sim_card')
  const bank = countByType('bank_card')
  const totalCost = list.reduce((sum, a) => sum + (Number(a.monthly_cost) || 0), 0)
  return [
    { icon: '📱', label: '手机', ...phone },
    { icon: '💬', label: '微信号', ...wechat },
    { icon: '📶', label: 'SIM卡', ...sim },
    { icon: '💳', label: '银行卡', total: bank.total },
    { icon: '💰', label: '月租费总额', total: '¥' + totalCost.toFixed(0) },
  ]
})

const bindGroups = computed(() => {
  const groups = {}
  assets.value.forEach(a => {
    if (a.bind_group) {
      if (!groups[a.bind_group]) groups[a.bind_group] = []
      groups[a.bind_group].push(a)
    }
  })
  return Object.entries(groups).map(([name, assets]) => ({ name, assets }))
})

function typeIcon(type) {
  const map = { phone: '📱', wechat: '💬', sim_card: '📶', bank_card: '💳' }
  return map[type] || '📦'
}

function statusClass(status) {
  const map = {
    [ASSET_STATUS.IN_USE]: 'bg-green-50 text-green-700',
    [ASSET_STATUS.IDLE]: 'bg-yellow-50 text-yellow-700',
    [ASSET_STATUS.MAINTENANCE]: 'bg-blue-50 text-blue-700',
    [ASSET_STATUS.DISPOSED]: 'bg-gray-100 text-gray-500',
  }
  return map[status] || 'bg-gray-100 text-gray-500'
}

function statusLabel(status) {
  const map = {
    [ASSET_STATUS.IN_USE]: '在用',
    [ASSET_STATUS.IDLE]: '闲置',
    [ASSET_STATUS.MAINTENANCE]: '维修中',
    [ASSET_STATUS.DISPOSED]: '已处置',
  }
  return map[status] || status
}

function resetForm() {
  form.value = {
    asset_type: activeTab.value, name: '', serial_number: '', monthly_cost: 0,
    status: ASSET_STATUS.IN_USE, assigned_to: '', purchase_date: '', note: ''
  }
  editingAsset.value = null
}

function openAddModal() {
  resetForm()
  showFormModal.value = true
}

function openEditModal(asset) {
  editingAsset.value = asset
  form.value = {
    asset_type: asset.asset_type,
    name: asset.name,
    serial_number: asset.serial_number || '',
    monthly_cost: asset.monthly_cost || 0,
    status: asset.status,
    assigned_to: asset.assigned_to || '',
    purchase_date: asset.purchase_date || '',
    note: asset.note || '',
  }
  showFormModal.value = true
}

function closeFormModal() {
  showFormModal.value = false
  resetForm()
}

async function fetchAssets() {
  loading.value = true
  const { data, error } = await supabase
    .from('assets')
    .select('*')
    .order('created_at', { ascending: false })
  if (!error && data) {
    assets.value = data
  }
  loading.value = false
}

async function saveAsset() {
  if (!form.value.name) return
  if (savingAsset.value) return
  savingAsset.value = true
  try {
    const payload = {
      asset_type: form.value.asset_type,
      name: form.value.name,
      serial_number: form.value.serial_number || null,
      monthly_cost: form.value.monthly_cost || 0,
      status: form.value.status,
      assigned_to: form.value.assigned_to || null,
      purchase_date: form.value.purchase_date || null,
      note: form.value.note || null,
    }

    if (editingAsset.value) {
      const { error } = await supabase.from('assets').update(payload).eq('id', editingAsset.value.id)
      if (!error) closeFormModal()
    } else {
      const { error } = await supabase.from('assets').insert(payload)
      if (!error) closeFormModal()
    }
    await fetchAssets()
  } finally {
    savingAsset.value = false
  }
}

async function deleteAsset(asset) {
  if (!confirm(`确定删除 "${asset.name}" 吗？`)) return
  await supabase.from('assets').delete().eq('id', asset.id)
  await fetchAssets()
}

function openBindGroupModal() {
  bindForm.value = { name: '', assetIds: [] }
  showBindModal.value = true
}

async function createBindGroup() {
  if (!bindForm.value.name || bindForm.value.assetIds.length < 2) return
  if (creatingBindGroup.value) return
  creatingBindGroup.value = true
  try {
    // Clear existing bind_group for selected assets
    await supabase.from('assets').update({ bind_group: null }).in('id', bindForm.value.assetIds)
    // Set new bind_group
    await supabase.from('assets').update({ bind_group: bindForm.value.name }).in('id', bindForm.value.assetIds)
    showBindModal.value = false
    await fetchAssets()
  } finally {
    creatingBindGroup.value = false
  }
}

async function dissolveGroup(groupName) {
  if (!confirm(`确定解除 "${groupName}" 组的全部绑定吗？`)) return
  await supabase.from('assets').update({ bind_group: null }).eq('bind_group', groupName)
  await fetchAssets()
}

onMounted(fetchAssets)
</script>
