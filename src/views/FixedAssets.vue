<template>
  <div class="space-y-6">
    <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1"><Icon name="building" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
        <div class="text-2xl font-bold text-gray-800">¥{{ formatNum(summary.totalOriginal) }}</div>
        <div class="text-xs text-gray-500">资产原值总额</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1"><Icon name="trending-down" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
        <div class="text-2xl font-bold text-gray-800">¥{{ formatNum(summary.totalDepreciation) }}</div>
        <div class="text-xs text-gray-500">累计折旧</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1">💎</div>
        <div class="text-2xl font-bold text-gray-800">¥{{ formatNum(summary.netValue) }}</div>
        <div class="text-xs text-gray-500">资产净值</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1"><Icon name="calendar" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
        <div class="text-2xl font-bold text-gray-800">¥{{ formatNum(summary.monthlyTotal) }}</div>
        <div class="text-xs text-gray-500">本月折旧额</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-2xl mb-1"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
        <div class="text-2xl font-bold text-gray-800">{{ summary.activeCount }} / {{ summary.totalCount }}</div>
        <div class="text-xs text-gray-500">在用 / 总数量</div>
      </div>
    </div>

    <div class="bg-white rounded-xl border border-gray-100">
      <div class="border-b border-gray-100 px-4 py-3">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="flex items-center gap-2">
            <select v-model="filterCategory"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部类别</option>
              <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
            </select>
            <select v-model="filterStatus"
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
              <option value="">全部状态</option>
              <option :value="ASSET_STATUS.IN_USE">在用</option>
              <option :value="ASSET_STATUS.IDLE">闲置</option>
              <option :value="ASSET_STATUS.DISPOSED">已处置</option>
            </select>
            <input v-model="searchQuery" type="text" placeholder="搜索资产名称/序列号..."
              class="border border-gray-200 rounded-lg px-3 py-2 text-sm w-52 focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
          </div>
          <div class="flex items-center gap-2">
            <button @click="showDepreciationConfirm = true"
              class="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600 transition cursor-pointer">
              批量计提折旧
            </button>
            <button @click="openAddModal"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer">
              + 添加固定资产
            </button>
          </div>
        </div>
      </div>

      <div class="p-4">
        <div v-if="loading" class="text-center py-12 text-gray-400">加载中...</div>
        <div v-else-if="filteredAssets.length === 0" class="text-center py-12 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          <div>暂无固定资产数据</div>
        </div>

        <template v-else>
          <div v-if="!isMobile" class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-gray-50 text-xs font-medium text-gray-500 uppercase">
                  <th class="px-3 py-3 text-left">资产名称</th>
                  <th class="px-3 py-3 text-left">类别</th>
                  <th class="px-3 py-3 text-left">购入日期</th>
                  <th class="px-3 py-3 text-right">原值</th>
                  <th class="px-3 py-3 text-center">折旧年限</th>
                  <th class="px-3 py-3 text-center">残值率</th>
                  <th class="px-3 py-3 text-right">累计折旧</th>
                  <th class="px-3 py-3 text-right">净值</th>
                  <th class="px-3 py-3 text-center">状态</th>
                  <th class="px-3 py-3 text-center">操作</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-50">
                <tr v-for="a in filteredAssets" :key="a.id" class="hover:bg-gray-50/50 transition">
                  <td class="px-3 py-3 font-medium text-gray-800">
                    {{ a.name }}
                    <div v-if="a.serial_number" class="text-xs text-gray-400">{{ a.serial_number }}</div>
                  </td>
                  <td class="px-3 py-3 text-gray-600">{{ a.category }}</td>
                  <td class="px-3 py-3 text-gray-600">{{ a.purchase_date }}</td>
                  <td class="px-3 py-3 text-right text-gray-800">¥{{ formatNum(a.purchase_price) }}</td>
                  <td class="px-3 py-3 text-center text-gray-600">{{ (a.useful_life_months / 12).toFixed(0) }}年</td>
                  <td class="px-3 py-3 text-center text-gray-600">{{ a.residual_rate }}%</td>
                  <td class="px-3 py-3 text-right text-orange-600">¥{{ formatNum(a.accumulated_depreciation) }}</td>
                  <td class="px-3 py-3 text-right text-green-700 font-medium">¥{{ formatNum(a.current_value) }}</td>
                  <td class="px-3 py-3 text-center">
                    <span :class="statusClass(a.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                      {{ statusLabel(a.status) }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-center">
                    <button @click="openEditModal(a)" class="text-xs text-blue-600 hover:underline cursor-pointer mr-2">编辑</button>
                    <button v-if="a.status !== ASSET_STATUS.DISPOSED" @click="confirmDispose(a)" class="text-xs text-red-500 hover:underline cursor-pointer">处置</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div v-else class="space-y-3">
            <div v-for="a in filteredAssets" :key="a.id"
              class="border border-gray-100 rounded-lg p-4 hover:shadow-sm transition">
              <div class="flex items-start justify-between mb-2">
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-gray-800 truncate">{{ a.name }}</div>
                  <div v-if="a.serial_number" class="text-xs text-gray-400 mt-0.5">{{ a.serial_number }}</div>
                </div>
                <span :class="statusClass(a.status)" class="text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0 ml-2">
                  {{ statusLabel(a.status) }}
                </span>
              </div>
              <div class="grid grid-cols-2 gap-2 text-sm text-gray-600 mb-3">
                <div>类别: {{ a.category }}</div>
                <div>购入: {{ a.purchase_date }}</div>
                <div>原值: ¥{{ formatNum(a.purchase_price) }}</div>
                <div>净值: <span class="text-green-700 font-medium">¥{{ formatNum(a.current_value) }}</span></div>
                <div>折旧年限: {{ (a.useful_life_months / 12).toFixed(0) }}年</div>
                <div>累计折旧: <span class="text-orange-600">¥{{ formatNum(a.accumulated_depreciation) }}</span></div>
              </div>
              <div class="flex items-center gap-2 pt-3 border-t border-gray-50">
                <button @click="openEditModal(a)" class="text-xs text-blue-600 hover:underline cursor-pointer">编辑</button>
                <span class="text-gray-300">|</span>
                <button v-if="a.status !== ASSET_STATUS.DISPOSED" @click="confirmDispose(a)" class="text-xs text-red-500 hover:underline cursor-pointer">处置</button>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>

    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showModal = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 class="text-lg font-semibold text-gray-800">{{ isEditing ? '编辑固定资产' : '添加固定资产' }}</h3>
          <button @click="showModal = false" class="text-gray-400 hover:text-gray-600 cursor-pointer text-xl">&times;</button>
        </div>
        <div class="px-6 py-4 space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">资产名称 <span class="text-red-500">*</span></label>
              <input v-model="form.name" type="text" required
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">类别</label>
              <select v-model="form.category"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
                <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">序列号</label>
              <input v-model="form.serial_number" type="text"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">购入日期</label>
              <input v-model="form.purchase_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">原值 (元)</label>
              <input v-model.number="form.purchase_price" type="number" step="0.01" min="0"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">折旧年限</label>
              <select v-model.number="form.useful_life_years"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
                <option :value="3">3年</option>
                <option :value="5">5年</option>
                <option :value="10">10年</option>
                <option :value="15">15年</option>
                <option :value="20">20年</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">残值率 (%)</label>
              <input v-model.number="form.residual_rate" type="number" step="0.01" min="0" max="100"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">折旧起始日期</label>
              <input v-model="form.depreciation_start_date" type="date"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">使用人</label>
              <input v-model="form.assigned_to" type="text"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">状态</label>
              <select v-model="form.status"
                class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400">
                <option :value="ASSET_STATUS.IN_USE">在用</option>
                <option :value="ASSET_STATUS.IDLE">闲置</option>
              </select>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2"
              class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-200 focus:border-blue-400"></textarea>
          </div>
          <div v-if="form.purchase_price > 0" class="bg-blue-50 rounded-lg p-3 text-sm text-blue-800">
            <div class="font-medium mb-1">自动计算</div>
            <div>月折旧额: ¥{{ formatNum(computedMonthly) }}</div>
            <div>预计净残值: ¥{{ formatNum(form.purchase_price * form.residual_rate / 100) }}</div>
          </div>
        </div>
        <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100">
          <button @click="showModal = false"
            class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition cursor-pointer">
            取消
          </button>
          <button @click="saveAsset" :disabled="saving"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition cursor-pointer disabled:opacity-50">
            {{ saving ? '保存中...' : '保存' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="showDepreciationConfirm" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showDepreciationConfirm = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md mx-4">
        <div class="px-6 py-4 border-b border-gray-100">
          <h3 class="text-lg font-semibold text-gray-800">批量计提折旧确认</h3>
        </div>
        <div class="px-6 py-4">
          <p class="text-sm text-gray-600 mb-3">
            将为 <span class="font-bold text-gray-800">{{ activeAssetsForDepreciation.length }}</span> 项在用资产计提
            <span class="font-bold text-gray-800">{{ currentPeriod }}</span> 的折旧。
          </p>
          <p class="text-sm text-gray-600">
            本次折旧总额: <span class="font-bold text-orange-600">¥{{ formatNum(depreciationTotal) }}</span>
          </p>
        </div>
        <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100">
          <button @click="showDepreciationConfirm = false"
            class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition cursor-pointer">
            取消
          </button>
          <button @click="runDepreciation" :disabled="depreciating"
            class="px-4 py-2 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600 transition cursor-pointer disabled:opacity-50">
            {{ depreciating ? '处理中...' : '确认计提' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="showDisposeConfirm" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="showDisposeConfirm = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md mx-4">
        <div class="px-6 py-4 border-b border-gray-100">
          <h3 class="text-lg font-semibold text-gray-800">资产处置确认</h3>
        </div>
        <div class="px-6 py-4">
          <p class="text-sm text-gray-600">
            确认将资产 <span class="font-bold text-gray-800">{{ disposeTarget?.name }}</span> 标记为已处置？
          </p>
        </div>
        <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100">
          <button @click="showDisposeConfirm = false"
            class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition cursor-pointer">
            取消
          </button>
          <button @click="disposeAsset" :disabled="disposing"
            class="px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700 transition cursor-pointer disabled:opacity-50">
            {{ disposing ? '处理中...' : '确认处置' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase'
import { ASSET_STATUS, ASSET_STATUS_LABEL } from '../constants/enums'
import Icon from '../components/icons/Icons.vue'

const categories = ['装修', '设备', '器材', '办公家具', '车辆', '其他']

const assets = ref([])
const loading = ref(false)
const saving = ref(false)
const depreciating = ref(false)
const disposing = ref(false)
const showModal = ref(false)
const showDepreciationConfirm = ref(false)
const showDisposeConfirm = ref(false)
const disposeTarget = ref(null)
const isEditing = ref(false)
const editingId = ref(null)

const filterCategory = ref('')
const filterStatus = ref('')
const searchQuery = ref('')

const isMobile = ref(window.innerWidth < 768)
const onResize = () => { isMobile.value = window.innerWidth < 768 }
onMounted(() => { window.addEventListener('resize', onResize); fetchAssets() })
onUnmounted(() => { window.removeEventListener('resize', onResize) })

const defaultForm = () => ({
  name: '',
  category: '设备',
  serial_number: '',
  purchase_date: new Date().toISOString().slice(0, 10),
  purchase_price: 0,
  useful_life_years: 5,
  residual_rate: 5,
  depreciation_start_date: new Date().toISOString().slice(0, 10),
  assigned_to: '',
  status: ASSET_STATUS.IN_USE,
  note: ''
})
const form = ref(defaultForm())

const computedMonthly = computed(() => {
  const p = form.value.purchase_price || 0
  const r = form.value.residual_rate || 0
  const months = (form.value.useful_life_years || 5) * 12
  if (months === 0) return 0
  return (p * (1 - r / 100)) / months
})

const summary = computed(() => {
  const nonDisposed = assets.value.filter(a => a.status !== ASSET_STATUS.DISPOSED)
  const active = assets.value.filter(a => a.status === ASSET_STATUS.IN_USE)
  const totalOriginal = nonDisposed.reduce((s, a) => s + Number(a.purchase_price || 0), 0)
  const totalDepreciation = nonDisposed.reduce((s, a) => s + Number(a.accumulated_depreciation || 0), 0)
  return {
    totalOriginal,
    totalDepreciation,
    netValue: totalOriginal - totalDepreciation,
    monthlyTotal: active.reduce((s, a) => s + Number(a.monthly_depreciation || 0), 0),
    activeCount: active.length,
    totalCount: assets.value.length
  }
})

const filteredAssets = computed(() => {
  return assets.value.filter(a => {
    if (filterCategory.value && a.category !== filterCategory.value) return false
    if (filterStatus.value && a.status !== filterStatus.value) return false
    if (searchQuery.value) {
      const q = searchQuery.value.toLowerCase()
      const match = (a.name || '').toLowerCase().includes(q) ||
        (a.serial_number || '').toLowerCase().includes(q)
      if (!match) return false
    }
    return true
  })
})

const currentPeriod = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
})

const activeAssetsForDepreciation = computed(() => {
  return assets.value.filter(a => a.status === ASSET_STATUS.IN_USE)
})

const depreciationTotal = computed(() => {
  return activeAssetsForDepreciation.value.reduce((s, a) => s + Number(a.monthly_depreciation || 0), 0)
})

function formatNum(n) {
  return Number(n || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function statusLabel(s) {
  return ASSET_STATUS_LABEL[s] || s
}

function statusClass(s) {
  return {
    [ASSET_STATUS.IN_USE]: 'bg-green-50 text-green-700',
    [ASSET_STATUS.IDLE]: 'bg-yellow-50 text-yellow-700',
    [ASSET_STATUS.MAINTENANCE]: 'bg-blue-50 text-blue-700',
    [ASSET_STATUS.DISPOSED]: 'bg-gray-100 text-gray-500'
  }[s] || 'bg-gray-100 text-gray-500'
}

async function fetchAssets() {
  loading.value = true
  const { data, error } = await supabase
    .from('assets')
    .select('*')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
  if (!error) assets.value = data || []
  loading.value = false
}

function openAddModal() {
  isEditing.value = false
  editingId.value = null
  form.value = defaultForm()
  showModal.value = true
}

function openEditModal(asset) {
  isEditing.value = true
  editingId.value = asset.id
  form.value = {
    name: asset.name || '',
    category: asset.category || '设备',
    serial_number: asset.serial_number || '',
    purchase_date: asset.purchase_date || '',
    purchase_price: Number(asset.purchase_price || 0),
    useful_life_years: Math.round((asset.useful_life_months || 60) / 12),
    residual_rate: Number(asset.residual_rate || 5),
    depreciation_start_date: asset.depreciation_start_date || asset.purchase_date || '',
    assigned_to: asset.assigned_to || '',
    status: asset.status || ASSET_STATUS.IN_USE,
    note: asset.note || ''
  }
  showModal.value = true
}

async function saveAsset() {
  if (!form.value.name.trim()) return alert('请填写资产名称')
  saving.value = true

  const useful_life_months = form.value.useful_life_years * 12
  const purchase_price = form.value.purchase_price || 0
  const residual_rate = form.value.residual_rate || 0
  const monthly_depreciation = useful_life_months > 0
    ? (purchase_price * (1 - residual_rate / 100)) / useful_life_months
    : 0

  const payload = {
    name: form.value.name.trim(),
    category: form.value.category,
    serial_number: form.value.serial_number || null,
    purchase_date: form.value.purchase_date || null,
    purchase_price,
    useful_life_months,
    residual_rate,
    depreciation_method: 'straight_line',
    depreciation_start_date: form.value.depreciation_start_date || form.value.purchase_date || null,
    monthly_depreciation: Math.round(monthly_depreciation * 100) / 100,
    assigned_to: form.value.assigned_to || null,
    status: form.value.status,
    note: form.value.note || null,
    updated_at: new Date().toISOString()
  }

  if (isEditing.value) {
    const existing = assets.value.find(a => a.id === editingId.value)
    payload.accumulated_depreciation = Number(existing?.accumulated_depreciation || 0)
    payload.current_value = purchase_price - payload.accumulated_depreciation

    await supabase.from('assets').update(payload).eq('id', editingId.value)
  } else {
    payload.accumulated_depreciation = 0
    payload.current_value = purchase_price
    await supabase.from('assets').insert(payload)
  }

  saving.value = false
  showModal.value = false
  await fetchAssets()
}

function confirmDispose(asset) {
  disposeTarget.value = asset
  showDisposeConfirm.value = true
}

async function disposeAsset() {
  if (!disposeTarget.value) return
  disposing.value = true
  await supabase.from('assets').update({
    status: ASSET_STATUS.DISPOSED,
    note: (disposeTarget.value.note ? disposeTarget.value.note + '\n' : '') + `处置日期: ${new Date().toISOString().slice(0, 10)}`,
    updated_at: new Date().toISOString()
  }).eq('id', disposeTarget.value.id)
  disposing.value = false
  showDisposeConfirm.value = false
  disposeTarget.value = null
  await fetchAssets()
}

async function runDepreciation() {
  depreciating.value = true
  const period = currentPeriod.value
  const activeList = activeAssetsForDepreciation.value

  const { data: existing } = await supabase
    .from('depreciation_records')
    .select('asset_id')
    .eq('period', period)
  const existingIds = new Set((existing || []).map(r => r.asset_id))

  const toProcess = activeList.filter(a => !existingIds.has(a.id))

  if (toProcess.length === 0) {
    alert(`${period} 的折旧已全部计提完毕，无需重复操作。`)
    depreciating.value = false
    showDepreciationConfirm.value = false
    return
  }

  const records = toProcess.map(a => {
    const md = Number(a.monthly_depreciation || 0)
    const newAccum = Number(a.accumulated_depreciation || 0) + md
    const remaining = Number(a.purchase_price || 0) - newAccum
    return {
      asset_id: a.id,
      period,
      amount: Math.round(md * 100) / 100,
      accumulated: Math.round(newAccum * 100) / 100,
      remaining_value: Math.round(Math.max(remaining, 0) * 100) / 100
    }
  })

  await supabase.from('depreciation_records').insert(records)

  for (const r of records) {
    await supabase.from('assets').update({
      accumulated_depreciation: r.accumulated,
      current_value: r.remaining_value,
      updated_at: new Date().toISOString()
    }).eq('id', r.asset_id)
  }

  depreciating.value = false
  showDepreciationConfirm.value = false
  await fetchAssets()
}
</script>
