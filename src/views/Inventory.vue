<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 库存总览</h1>
      <div class="flex gap-2">
        <button
          @click="openTransferModal"
          class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-purple-700 transition cursor-pointer"
        ><Icon name="refresh" class="inline w-4 h-4 -mt-0.5 mr-1" /> 仓库调拨
        </button>
        <button
          @click="openAdjustModal"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
        ><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" /> 库存调整
        </button>
      </div>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-4 gap-4 mb-5">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1"><Icon name="package" class="inline w-4 h-4 -mt-0.5 mr-1" /> 总库存</div>
        <div class="text-2xl font-bold text-gray-800">{{ store.stats.totalStock }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1"><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 产品数</div>
        <div class="text-2xl font-bold text-blue-600">{{ store.stats.totalProducts }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1"><Icon name="building" class="inline w-4 h-4 -mt-0.5 mr-1" /> 仓库数</div>
        <div class="text-2xl font-bold text-indigo-600">{{ store.stats.totalWarehouses }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 低库存预警</div>
        <div class="text-2xl font-bold text-orange-500">{{ store.stats.lowStockWarnings }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <select
        v-model="filters.warehouseId"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">全部仓库</option>
        <option v-for="wh in store.warehouses" :key="wh.id" :value="wh.id">
          {{ wh.is_active ? '' : '❌ ' }}{{ wh.name }}
        </option>
      </select>
      <select
        v-model="filters.brand"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">全部品牌</option>
        <option v-for="b in allBrands" :key="b" :value="b">{{ b }}</option>
      </select>
      <input
        v-model="filters.keyword"
        placeholder="🔍 搜索产品名称..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-56 outline-none focus:ring-2 focus:ring-blue-500"
        @keydown.enter="search"
      >
      <button
        @click="search"
        class="bg-blue-600 text-white px-3 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
      ><Icon name="search" class="inline w-4 h-4 -mt-0.5 mr-1" /> 搜索
      </button>
      <button
        @click="handleExportInventory"
        class="bg-green-600 text-white px-3 py-2 rounded-lg text-sm hover:bg-green-700 transition cursor-pointer"
      ><Icon name="download" class="inline w-4 h-4 -mt-0.5 mr-1" /> 导出CSV
      </button>
      <span class="text-sm text-gray-500 ml-auto">
        共 {{ store.pagination.total }} 条记录
      </span>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-500 text-sm">
      加载中...
    </div>

    <!-- Inventory Table -->
    <div v-else class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <div class="overflow-x-auto" style="max-height: 70vh;">
        <table class="w-full text-sm">
          <thead class="sticky top-0 z-10">
            <tr class="border-b border-gray-100 bg-gray-50/80 backdrop-blur-sm">
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 w-24">品牌</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">产品名称</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 w-20">类型</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-500 w-32">仓库</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 w-24">当前库存</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 w-24">已预留</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 w-24">可用库存</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 w-24">成本价</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-500 w-24">售价</th>
              <th class="text-center px-4 py-3 text-xs font-medium text-gray-500 w-24">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="store.inventory.length === 0">
              <td colspan="10" class="px-4 py-12 text-center text-gray-500">
                暂无库存数据
              </td>
            </tr>
            <tr
              v-for="item in store.inventory"
              :key="item.id"
              class="border-b border-gray-50 hover:bg-gray-50/50 transition"
            >
              <td class="px-4 py-3">
                <span v-if="item.brand" class="inline-flex items-center gap-1.5 text-xs">
                  <span class="w-2 h-2 rounded-full" :style="{ backgroundColor: brandColor(item.brand) }"></span>
                  <span class="text-gray-700">{{ item.brand }}</span>
                </span>
                <span v-else class="text-gray-300">—</span>
              </td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ item.product_name }}</td>
              <td class="px-4 py-3">
                <span class="inline-block px-2 py-0.5 text-xs rounded-full bg-blue-50 text-blue-600">
                  {{ categoryMap[item.category] || item.category || '—' }}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-500 text-xs">{{ item.warehouse_name }}</td>
              <td class="px-4 py-3 text-right font-medium" :class="item.quantity > 0 ? 'text-green-600' : 'text-red-500'">
                {{ item.quantity }}
              </td>
              <td class="px-4 py-3 text-right text-orange-500">{{ item.reserved || 0 }}</td>
              <td class="px-4 py-3 text-right font-medium" :class="item.available > 0 ? 'text-green-600' : 'text-red-500'">
                {{ item.available }}
              </td>
              <td class="px-4 py-3 text-right text-gray-700">
                {{ userRole === 'admin' ? Number(item.cost_price).toFixed(2) : '***' }}
              </td>
              <td class="px-4 py-3 text-right text-gray-700">{{ Number(item.retail_price).toFixed(2) }}</td>
              <td class="px-4 py-3 text-center">
                <div class="inline-flex gap-1">
                  <button
                    @click="openEditModal(item)"
                    class="p-1.5 rounded-lg hover:bg-blue-50 text-blue-500 transition cursor-pointer"
                    title="编辑"
                  ><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" />
                  </button>
                  <button
                    v-if="userRole === 'admin'"
                    @click="deleteItem(item)"
                    class="p-1.5 rounded-lg hover:bg-red-50 text-red-400 transition cursor-pointer"
                    title="删除"
                  >
                    🗑️
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="store.pagination.total > store.pagination.pageSize" class="flex items-center justify-between px-4 py-3 border-t border-gray-100">
        <span class="text-xs text-gray-500">
          第 {{ (store.pagination.page - 1) * store.pagination.pageSize + 1 }}-{{ Math.min(store.pagination.page * store.pagination.pageSize, store.pagination.total) }} 条
        </span>
        <div class="flex gap-1">
          <button
            @click="goPage(store.pagination.page - 1)"
            :disabled="store.pagination.page <= 1"
            class="px-3 py-1 text-xs border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed transition"
          >
            上一页
          </button>
          <button
            @click="goPage(store.pagination.page + 1)"
            :disabled="store.pagination.page * store.pagination.pageSize >= store.pagination.total"
            class="px-3 py-1 text-xs border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed transition"
          >
            下一页
          </button>
        </div>
      </div>
    </div>

    <!-- ========== 编辑库存弹窗 ========== -->
    <div v-if="showEditModal" class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/40" @click="showEditModal = false"></div>
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4"><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" /> 编辑库存</h2>

        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-500 mb-1">产品名称</label>
            <div class="px-3 py-2 bg-gray-50 rounded-lg text-sm text-gray-800">{{ editForm.productName }}</div>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">仓库</label>
            <div class="px-3 py-2 bg-gray-50 rounded-lg text-sm text-gray-800">{{ editForm.warehouseName }}</div>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">当前库存</label>
            <div class="px-3 py-2 bg-gray-50 rounded-lg text-sm text-gray-800 font-medium">{{ editForm.currentQuantity }}</div>
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">新库存数量 <span class="text-red-400">*</span></label>
            <input
              v-model.number="editForm.newQuantity"
              type="number"
              min="0"
              placeholder="输入新的库存数量"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>
          <div>
            <label class="block text-sm text-gray-500 mb-1">备注</label>
            <input
              v-model="editForm.note"
              placeholder="可选备注"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showEditModal = false"
            class="px-4 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition"
          >
            取消
          </button>
          <button
            @click="submitEdit"
            :disabled="submitting"
            class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 cursor-pointer transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ submitting ? '处理中...' : '确认修改' }}
          </button>
        </div>
      </div>
    </div>

    <!-- ========== 库存调整弹窗 ========== -->
    <div v-if="showAdjustModal" class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/40" @click="showAdjustModal = false"></div>
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4"><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" /> 库存调整</h2>

        <div class="space-y-4">
          <!-- 仓库 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">仓库 <span class="text-red-400">*</span></label>
            <select
              v-model="adjustForm.warehouseId"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择仓库</option>
              <option v-for="wh in activeWarehouses" :key="wh.id" :value="wh.id">{{ wh.name }}</option>
            </select>
          </div>

          <!-- 产品 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">产品 <span class="text-red-400">*</span></label>
            <SearchableSelect
              v-model="adjustForm.productId"
              :options="productOptions"
              placeholder="搜索产品..."
              search-placeholder="搜索名称..."
            />
          </div>

          <!-- 调整类型 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">调整类型 <span class="text-red-400">*</span></label>
            <select
              v-model="adjustForm.type"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择</option>
              <option value="in">入库</option>
              <option value="out">出库</option>
              <option value="count">盘点</option>
            </select>
          </div>

          <!-- 数量 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">数量 <span class="text-red-400">*</span></label>
            <input
              v-model.number="adjustForm.quantity"
              type="number"
              min="1"
              placeholder="调整数量"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <!-- 备注 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">备注</label>
            <input
              v-model="adjustForm.note"
              placeholder="可选备注"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showAdjustModal = false"
            class="px-4 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition"
          >
            取消
          </button>
          <button
            @click="submitAdjust"
            :disabled="submitting"
            class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 cursor-pointer transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ submitting ? '处理中...' : '确认调整' }}
          </button>
        </div>
      </div>
    </div>

    <!-- ========== 仓库调拨弹窗 ========== -->
    <div v-if="showTransferModal" class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/40" @click="showTransferModal = false"></div>
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4"><Icon name="refresh" class="inline w-4 h-4 -mt-0.5 mr-1" /> 仓库调拨</h2>

        <div class="space-y-4">
          <!-- 源仓库 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">源仓库 <span class="text-red-400">*</span></label>
            <select
              v-model="transferForm.fromWarehouseId"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择</option>
              <option v-for="wh in activeWarehouses" :key="wh.id" :value="wh.id">{{ wh.name }}</option>
            </select>
          </div>

          <!-- 目标仓库 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">目标仓库 <span class="text-red-400">*</span></label>
            <select
              v-model="transferForm.toWarehouseId"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择</option>
              <option v-for="wh in activeWarehouses" :key="wh.id" :value="wh.id">{{ wh.name }}</option>
            </select>
          </div>

          <!-- 产品 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">产品 <span class="text-red-400">*</span></label>
            <SearchableSelect
              v-model="transferForm.productId"
              :options="productOptions"
              placeholder="搜索产品..."
              search-placeholder="搜索名称..."
            />
          </div>

          <!-- 数量 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">数量 <span class="text-red-400">*</span></label>
            <input
              v-model.number="transferForm.quantity"
              type="number"
              min="1"
              placeholder="调拨数量"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <!-- 备注 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">备注</label>
            <input
              v-model="transferForm.note"
              placeholder="可选备注"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showTransferModal = false"
            class="px-4 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition"
          >
            取消
          </button>
          <button
            @click="submitTransfer"
            :disabled="submitting"
            class="px-4 py-2 text-sm text-white bg-purple-600 rounded-lg hover:bg-purple-700 cursor-pointer transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ submitting ? '处理中...' : '确认调拨' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useInventoryStore } from '../stores/inventory'
import { supabase } from '../lib/supabase'
import { toast } from '../lib/utils'
import SearchableSelect from '../components/SearchableSelect.vue'
import Icon from '../components/icons/Icons.vue'

const store = useInventoryStore()

const filters = reactive({ warehouseId: '', brand: '', keyword: '' })
const userRole = ref('')

// 筛选变化自动重新查询
watch(() => [filters.warehouseId, filters.brand], () => {
  store.pagination.page = 1
  fetchInventory()
})

const categoryMap = {
  cue: '球杆',
  shaft: '前支',
  jump_break: '冲跳杆',
  tip: '皮头',
  chalk: '巧克',
  glove: '手套',
  glue: '胶水',
  extension: '加长把',
  maintenance: '保养',
  towel: '毛巾',
  case: '杆箱',
  bag: '杆包',
  rest: '架杆',
  ball: '球',
  table: '球桌',
  accessory: '配件',
  course: '课程',
  recording_course: '录播课',
  offline_camp: '线下营',
  service: '服务',
  book: '书籍',
  other: '其他',
}

// Brand color hash for tag dots
const brandColors = {}
let colorIndex = 0
const colorPalette = ['#3B82F6', '#8B5CF6', '#EC4899', '#F59E0B', '#10B981', '#EF4444', '#06B6D4', '#F97316']
function brandColor(name) {
  if (!brandColors[name]) {
    brandColors[name] = colorPalette[colorIndex % colorPalette.length]
    colorIndex++
  }
  return brandColors[name]
}

// Products for searchable select
const products = ref([])
const productOptions = computed(() =>
  products.value.map(p => ({
    value: p.id,
    label: p.brand ? `${p.name}（${p.brand}）` : p.name,
  }))
)

const allBrands = ref([])

const activeWarehouses = computed(() =>
  store.warehouses.filter(w => w.is_active)
)

// 加载所有品牌（用于筛选下拉，不受分页影响）
async function loadBrands() {
  const { data } = await supabase
    .from('inventory_view')
    .select('brand')
    .not('brand', 'is', null)
  if (data) {
    allBrands.value = [...new Set(data.map(r => r.brand))].sort()
  }
}

// ========== 编辑库存 ==========
const showEditModal = ref(false)
const editForm = reactive({
  id: '',
  productId: '',
  warehouseId: '',
  productName: '',
  warehouseName: '',
  currentQuantity: 0,
  newQuantity: null,
  note: '',
})

function openEditModal(item) {
  Object.assign(editForm, {
    id: item.id,
    productId: item.product_id,
    warehouseId: item.warehouse_id,
    productName: item.product_name,
    warehouseName: item.warehouse_name,
    currentQuantity: item.quantity,
    newQuantity: item.quantity,
    note: '',
  })
  showEditModal.value = true
}

async function submitEdit() {
  if (editForm.newQuantity === null || editForm.newQuantity === '') {
    alert('请输入新库存数量')
    return
  }
  const diff = editForm.newQuantity - editForm.currentQuantity
  if (diff === 0) {
    alert('库存数量未变化')
    return
  }
  submitting.value = true
  try {
    const { error } = await supabase.rpc('adjust_inventory', {
      p_product_id: editForm.productId,
      p_warehouse_id: editForm.warehouseId,
      p_quantity: diff,
      p_type: diff > 0 ? 'in' : 'out',
      p_note: editForm.note || `编辑调整：${editForm.currentQuantity} → ${editForm.newQuantity}`,
    })
    if (error) throw error
    alert('库存修改成功')
    showEditModal.value = false
    loadData()
  } catch (e) {
    alert('操作失败：' + (e.message || '未知错误'))
  } finally {
    submitting.value = false
  }
}

// ========== 删除库存 ==========
async function deleteItem(item) {
  if (!confirm(`确定要删除「${item.product_name}」在「${item.warehouse_name}」的库存记录吗？当前库存 ${item.quantity}，此操作不可恢复。`)) {
    return
  }
  try {
    // 写日志（删除前记录）
    await supabase.from('inventory_logs').insert({
      warehouse_id: item.warehouse_id,
      product_id: item.product_id,
      change_type: 'adjust',
      quantity: item.quantity,
      before_qty: item.quantity,
      after_qty: 0,
      note: `删除库存记录，原库存 ${item.quantity}`,
      created_by: (await supabase.auth.getSession()).data?.session?.user?.id,
    }).then(() => {}).catch(() => {})
    
    const { error } = await supabase.from('inventory').delete().eq('id', item.id)
    if (error) throw error
    alert('删除成功')
    loadData()
  } catch (e) {
    alert('删除失败：' + (e.message || '未知错误'))
  }
}

// ========== 库存调整 ==========
const showAdjustModal = ref(false)
const submitting = ref(false)
const adjustForm = reactive({ warehouseId: '', productId: '', type: '', quantity: null, note: '' })

function openAdjustModal() {
  Object.assign(adjustForm, { warehouseId: '', productId: '', type: '', quantity: null, note: '' })
  showAdjustModal.value = true
}

async function submitAdjust() {
  if (!adjustForm.warehouseId || !adjustForm.productId || !adjustForm.type || !adjustForm.quantity) {
    alert('请填写所有必填字段')
    return
  }
  submitting.value = true
  try {
    await store.adjustStock(
      adjustForm.warehouseId,
      adjustForm.productId,
      adjustForm.quantity,
      adjustForm.type,
      adjustForm.note
    )
    alert('库存调整成功')
    showAdjustModal.value = false
    loadData()
  } catch (e) {
    alert('操作失败：' + (e.message || '未知错误'))
  } finally {
    submitting.value = false
  }
}

// ========== 仓库调拨 ==========
const showTransferModal = ref(false)
const transferForm = reactive({ fromWarehouseId: '', toWarehouseId: '', productId: '', quantity: null, note: '' })

function openTransferModal() {
  Object.assign(transferForm, { fromWarehouseId: '', toWarehouseId: '', productId: '', quantity: null, note: '' })
  showTransferModal.value = true
}

async function submitTransfer() {
  if (!transferForm.fromWarehouseId || !transferForm.toWarehouseId || !transferForm.productId || !transferForm.quantity) {
    alert('请填写所有必填字段')
    return
  }
  if (transferForm.fromWarehouseId === transferForm.toWarehouseId) {
    alert('源仓库和目标仓库不能相同')
    return
  }
  submitting.value = true
  try {
    await store.transferStock(
      transferForm.fromWarehouseId,
      transferForm.toWarehouseId,
      transferForm.productId,
      transferForm.quantity,
      transferForm.note
    )
    alert('调拨成功')
    showTransferModal.value = false
    loadData()
  } catch (e) {
    alert('操作失败：' + (e.message || '未知错误'))
  } finally {
    submitting.value = false
  }
}

// ========== Pagination ==========
function goPage(page) {
  if (page < 1) return
  store.pagination.page = page
  fetchInventory()
}

// ========== Data ==========
async function handleExportInventory() {
  try {
    toast('正在导出...', 'info')
    const keyword = (filters.keyword || '').replace(/[,%().*]/g, '')
    let query = supabase
      .from('inventory_view')
      .select('brand, product_name, category, warehouse_name, quantity, reserved, available, sale_price')
      .order('product_name')
      .limit(5000)

    if (filters.warehouseId) query = query.eq('warehouse_id', filters.warehouseId)
    if (filters.brand) query = query.eq('brand', filters.brand)
    if (keyword) {
      query = query.or(`product_name.ilike.%${keyword}%,warehouse_name.ilike.%${keyword}%,brand.ilike.%${keyword}%`)
    }

    const { data, error } = await query
    if (error) throw error
    const rows = data || []

    const header = ['品牌', '产品名称', '类型', '仓库', '库存数量', '已预留', '可用库存', '售价']
    const body = rows.map(r => [
      r.brand || '',
      r.product_name || '',
      categoryMap[r.category] || r.category || '',
      r.warehouse_name || '',
      r.quantity || 0,
      r.reserved || 0,
      r.available || 0,
      r.sale_price ? Number(r.sale_price).toFixed(2) : '',
    ])

    const BOM = '\uFEFF'
    const csv = BOM + [header, ...body].map(row =>
      row.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(',')
    ).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    const today = new Date().toISOString().slice(0, 10)
    link.download = `库存_${today}.csv`
    link.click()
    URL.revokeObjectURL(link.href)
    toast(`已导出 ${rows.length} 条数据`, 'success')
  } catch (e) {
    console.error('导出失败:', e)
    toast('导出失败：' + (e.message || ''), 'error')
  }
}

function search() {
  store.pagination.page = 1
  fetchInventory()
}

async function fetchInventory() {
  await store.fetchInventory({
    warehouseId: filters.warehouseId || null,
    brand: filters.brand || null,
    keyword: filters.keyword || null,
    page: store.pagination.page,
    pageSize: store.pagination.pageSize,
  })
}

async function fetchProducts() {
  const { data } = await supabase
    .from('products')
    .select('id, name, brand')
    .eq('status', 'active')
    .order('name')
  products.value = data || []
}

async function fetchUserRole() {
  const { data: { session } } = await supabase.auth.getSession()
  const { data } = await supabase.from('profiles').select('role').eq('id', session?.user?.id).single()
  userRole.value = data?.role || ''
}

async function loadData() {
  await Promise.all([
    store.fetchStats(),
    fetchInventory(),
    fetchProducts(),
    loadBrands(),
  ])
}

onMounted(() => {
  store.fetchWarehouses()
  fetchUserRole()
  loadData()
})
</script>
