<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">📋 库存流水</h1>
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
        v-model="filters.type"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">全部类型</option>
        <option v-for="(label, key) in TYPE_LABELS" :key="key" :value="key">{{ label }}</option>
      </select>
      <input
        v-model="filters.keyword"
        placeholder="🔍 搜索产品名称/SKU..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-48 outline-none focus:ring-2 focus:ring-blue-500"
        @keydown.enter="search"
      >
      <input
        v-model="filters.startDate"
        type="date"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
      <span class="text-gray-500 text-sm">至</span>
      <input
        v-model="filters.endDate"
        type="date"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
      <button
        @click="search"
        class="bg-blue-600 text-white px-3 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
      >
        🔍 搜索
      </button>
      <button
        @click="resetFilters"
        class="px-3 py-2 text-gray-500 border border-gray-200 rounded-lg text-sm hover:bg-gray-50 cursor-pointer transition"
      >
        重置
      </button>
      <span class="text-sm text-gray-500 ml-auto">
        共 {{ store.logPagination.total }} 条记录
      </span>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-500 text-sm">
      加载中...
    </div>

    <!-- Logs Table -->
    <div v-else class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-100 bg-gray-50/50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">时间</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">仓库</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">产品</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">类型</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500">数量</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500">变动前</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500">变动后</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">关联单号</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">备注</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">操作人</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="store.logs.length === 0">
            <td colspan="10" class="px-4 py-12 text-center text-gray-500">
              暂无流水记录
            </td>
          </tr>
          <tr
            v-for="log in store.logs"
            :key="log.id"
            class="border-b border-gray-50 hover:bg-gray-50/50 transition"
          >
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatTime(log.created_at) }}</td>
            <td class="px-4 py-3 text-gray-700 text-xs">{{ log.warehouse?.name || '--' }}</td>
            <td class="px-4 py-3 text-gray-700">
              <div class="font-medium text-xs">{{ log.product?.name || '--' }}</div>
              <div v-if="log.product?.sku" class="text-gray-500 text-xs font-mono">{{ log.product.sku }}</div>
            </td>
            <td class="px-4 py-3">
              <span
                class="inline-block px-2 py-0.5 rounded-full text-xs font-medium"
                :class="typeTagClass(log.change_type)"
              >
                {{ TYPE_LABELS[log.change_type] || log.change_type }}
              </span>
            </td>
            <td class="px-4 py-3 text-right font-medium" :class="quantityClass(log.change_type)">
              {{ quantityPrefix(log.change_type) }}{{ log.quantity }}
            </td>
            <td class="px-4 py-3 text-right text-gray-500">{{ log.stock_before ?? '--' }}</td>
            <td class="px-4 py-3 text-right text-gray-800">{{ log.stock_after ?? '--' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs font-mono">{{ log.ref_no || '--' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs max-w-[150px] truncate">{{ log.note || '--' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ log.operator?.name || '--' }}</td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination -->
      <div v-if="store.logPagination.total > store.logPagination.pageSize" class="flex items-center justify-between px-4 py-3 border-t border-gray-100">
        <span class="text-xs text-gray-500">
          第 {{ (store.logPagination.page - 1) * store.logPagination.pageSize + 1 }}-{{ Math.min(store.logPagination.page * store.logPagination.pageSize, store.logPagination.total) }} 条
        </span>
        <div class="flex gap-1">
          <button
            @click="goPage(store.logPagination.page - 1)"
            :disabled="store.logPagination.page <= 1"
            class="px-3 py-1 text-xs border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed transition"
          >
            上一页
          </button>
          <button
            @click="goPage(store.logPagination.page + 1)"
            :disabled="store.logPagination.page * store.logPagination.pageSize >= store.logPagination.total"
            class="px-3 py-1 text-xs border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed transition"
          >
            下一页
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { reactive, onMounted } from 'vue'
import { useInventoryStore } from '../stores/inventory'

const store = useInventoryStore()

const TYPE_LABELS = {
  in: '入库',
  out: '出库',
  transfer_in: '调拨入',
  transfer_out: '调拨出',
  count: '盘点',
  return: '退货',
  ship: '发货',
}

const TYPE_TAG_CLASS = {
  in: 'bg-green-50 text-green-600',
  out: 'bg-red-50 text-red-500',
  transfer_in: 'bg-blue-50 text-blue-600',
  transfer_out: 'bg-blue-50 text-blue-600',
  count: 'bg-orange-50 text-orange-600',
  return: 'bg-purple-50 text-purple-600',
  ship: 'bg-gray-100 text-gray-500',
}

function typeTagClass(type) {
  return TYPE_TAG_CLASS[type] || 'bg-gray-100 text-gray-500'
}

function quantityClass(type) {
  if (type === 'in' || type === 'transfer_in' || type === 'return') return 'text-green-600'
  if (type === 'out' || type === 'transfer_out' || type === 'ship') return 'text-red-500'
  return 'text-orange-600'
}

function quantityPrefix(type) {
  if (type === 'in' || type === 'transfer_in' || type === 'return') return '+'
  if (type === 'out' || type === 'transfer_out' || type === 'ship') return '-'
  return ''
}

function formatTime(t) {
  if (!t) return '--'
  const d = new Date(t)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const filters = reactive({
  warehouseId: '',
  type: '',
  keyword: '',
  startDate: '',
  endDate: '',
})

function search() {
  store.logPagination.page = 1
  fetchLogs()
}

function resetFilters() {
  Object.assign(filters, { warehouseId: '', type: '', keyword: '', startDate: '', endDate: '' })
  store.logPagination.page = 1
  fetchLogs()
}

function goPage(page) {
  if (page < 1) return
  store.logPagination.page = page
  fetchLogs()
}

async function fetchLogs() {
  await store.fetchLogs({
    warehouseId: filters.warehouseId || null,
    type: filters.type || null,
    keyword: filters.keyword || null,
    startDate: filters.startDate || null,
    endDate: filters.endDate || null,
    page: store.logPagination.page,
    pageSize: store.logPagination.pageSize,
  })
}

onMounted(() => {
  store.fetchWarehouses()
  fetchLogs()
})
</script>
