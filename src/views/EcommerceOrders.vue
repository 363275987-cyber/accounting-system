<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-4 md:mb-6">
      <div>
        <h1 class="text-lg md:text-xl font-bold text-gray-800 truncate">🛒 电商订单</h1>
        <p class="text-xs text-gray-500 mt-0.5">管理所有电商平台导入的订单</p>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <button v-if="canDelete" @click="showImportModal = true" class="hidden md:inline-flex bg-green-600 text-white px-3 py-2 rounded-lg text-sm hover:bg-green-700 transition cursor-pointer whitespace-nowrap">📥 导入订单</button>
        <button @click="handleExport" class="hidden md:inline-flex px-3 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer transition">📤 导出</button>
        <button v-if="selectedOrders.length > 0 && canDelete" @click="handleBatchDelete"
          class="px-3 py-2 bg-red-50 text-red-600 rounded-lg text-sm hover:bg-red-100 cursor-pointer transition">
          🗑️ 删除 ({{ selectedOrders.length }})
        </button>
        <!-- 移动端更多菜单 -->
        <div class="relative md:hidden">
          <button @click="showMobileMenu = !showMobileMenu" class="px-2.5 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">⋯</button>
          <div v-if="showMobileMenu" class="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-lg border border-gray-100 py-1 z-50 min-w-[140px]">
            <button v-if="canDelete" @click="showImportModal = true; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">📥 导入订单</button>
            <button @click="handleExport(); showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">📤 导出</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">本月订单</div>
        <div class="text-xl font-bold text-blue-600">{{ stats.monthOrders }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">本月销售额</div>
        <div class="text-xl font-bold text-green-600">{{ formatMoney(stats.monthSales) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">本月退款</div>
        <div class="text-xl font-bold text-red-500">{{ formatMoney(stats.monthRefund) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">本月净额</div>
        <div class="text-xl font-bold text-purple-600">{{ formatMoney(stats.monthSales - stats.monthRefund) }}</div>
      </div>
    </div>

    <!-- 筛选区 -->
    <div class="bg-white rounded-xl border border-gray-100 p-3 md:p-4 mb-4 flex gap-2 md:gap-3 items-center flex-wrap">
      <input v-model="filters.keyword" @keyup.enter="loadOrders" placeholder="搜索订单号/店铺/SKU..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-40 md:w-52 outline-none focus:ring-2 focus:ring-blue-500">
      <select v-model="filters.platform" @change="loadOrders" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部平台</option>
        <option value="douyin">抖音</option>
        <option value="kuaishou">快手</option>
        <option value="shipinhao">视频号</option>
      </select>
      <select v-model="filters.store" @change="loadOrders" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部店铺</option>
        <option v-for="s in storeList" :key="s" :value="s">{{ s }}</option>
      </select>
      <select v-model="filters.status" @change="loadOrders" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部状态</option>
        <option value="completed">已完成</option>
        <option value="partially_refunded">部分退款</option>
        <option value="refunded">已退款</option>
        <option value="pending">待确认</option>
      </select>
      <input type="date" v-model="filters.dateFrom" @change="loadOrders" class="px-2 py-2 border border-gray-200 rounded-lg text-sm">
      <span class="text-gray-400 text-xs">~</span>
      <input type="date" v-model="filters.dateTo" @change="loadOrders" class="px-2 py-2 border border-gray-200 rounded-lg text-sm">
      <button @click="loadOrders" class="px-3 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm hover:bg-blue-100 cursor-pointer">🔍</button>
      <button v-if="hasActiveFilters" @click="clearFilters" class="px-3 py-2 text-gray-500 rounded-lg text-sm hover:bg-gray-100 cursor-pointer">✕ 清除</button>
      <span class="text-xs text-gray-500 ml-auto">共 {{ pagination.total }} 条</span>
    </div>

    <!-- 桌面端表格 -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden hidden md:block">
      <div v-if="loading" class="p-16 text-center text-gray-500">加载中...</div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th v-if="canDelete" class="px-3 py-3 text-center w-10">
              <input type="checkbox" :checked="isAllSelected" @change="toggleSelectAll" class="rounded cursor-pointer">
            </th>
            <th class="px-3 py-3 text-left font-medium">时间</th>
            <th class="px-3 py-3 text-left font-medium">平台</th>
            <th class="px-3 py-3 text-left font-medium">店铺</th>
            <th class="px-3 py-3 text-left font-medium">线上订单号</th>
            <th class="px-3 py-3 text-left font-medium">SKU</th>
            <th class="px-3 py-3 text-right font-medium">订单金额</th>
            <th class="px-3 py-3 text-right font-medium">实收金额</th>
            <th class="px-3 py-3 text-center font-medium">状态</th>
            <th class="px-3 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="order in orders" :key="order.id"
            class="border-t border-gray-50 hover:bg-gray-50/60 cursor-pointer"
            @click="openDetail(order)">
            <td v-if="canDelete" class="px-3 py-3 text-center" @click.stop>
              <input type="checkbox" :value="order.id" v-model="selectedOrders" class="rounded cursor-pointer">
            </td>
            <td class="px-3 py-3 text-gray-500 whitespace-nowrap text-xs">{{ formatDate(order.order_time || order.created_at) }}</td>
            <td class="px-3 py-3">
              <span :class="platformBadgeClass(order.platform_type)" class="text-xs px-2 py-0.5 rounded-full">
                {{ PLATFORM_MAP[order.platform_type] || order.platform_type }}
              </span>
            </td>
            <td class="px-3 py-3 text-sm text-gray-800">{{ order.platform_store || '—' }}</td>
            <td class="px-3 py-3 text-xs text-gray-600 font-mono max-w-[180px] truncate" :title="order.external_order_no">{{ order.external_order_no || '—' }}</td>
            <td class="px-3 py-3 text-xs text-purple-600 font-mono">{{ order.sku_code || '—' }}</td>
            <td class="px-3 py-3 text-right font-medium text-gray-800">{{ formatMoney(order.amount) }}</td>
            <td class="px-3 py-3 text-right font-medium text-green-600">{{ formatMoney(order.payment_amount || order.amount) }}</td>
            <td class="px-3 py-3 text-center">
              <span :class="[STATUS_MAP[order.status]?.class, 'px-2 py-0.5 rounded text-xs']">
                {{ STATUS_MAP[order.status]?.label || order.status }}
              </span>
            </td>
            <td class="px-3 py-3 text-center" @click.stop>
              <div class="flex items-center justify-center gap-1">
                <button @click="openDetail(order)" class="text-blue-500 hover:text-blue-700 text-xs px-2 py-1 rounded hover:bg-blue-50 cursor-pointer">详情</button>
                <button v-if="canDelete" @click="handleDelete(order)" class="text-red-400 hover:text-red-600 text-xs px-2 py-1 rounded hover:bg-red-50 cursor-pointer">删除</button>
              </div>
            </td>
          </tr>
          <tr v-if="!loading && orders.length === 0">
            <td :colspan="canDelete ? 10 : 9" class="px-4 py-16 text-center text-gray-500">
              <div class="text-3xl mb-2">📭</div>
              <div>暂无电商订单</div>
              <div class="text-xs mt-1">请在「电商管理」页面导入订单</div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- 移动端卡片 -->
    <div class="md:hidden space-y-2">
      <div v-if="loading" class="space-y-2">
        <div v-for="i in 5" :key="i" class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="h-4 w-24 bg-gray-100 rounded animate-pulse mb-2"></div>
          <div class="h-6 w-32 bg-gray-100 rounded animate-pulse"></div>
        </div>
      </div>
      <div v-for="order in orders" :key="'m-' + order.id"
        class="bg-white rounded-xl border border-gray-100 p-3 shadow-sm cursor-pointer"
        @click="openDetail(order)">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2 min-w-0 flex-1">
            <span :class="platformBadgeClass(order.platform_type)" class="text-xs px-2 py-0.5 rounded-full flex-shrink-0">
              {{ PLATFORM_MAP[order.platform_type] || order.platform_type }}
            </span>
            <span class="text-sm font-semibold text-green-600">{{ formatMoney(order.payment_amount || order.amount) }}</span>
          </div>
          <span :class="[STATUS_MAP[order.status]?.class, 'px-2 py-0.5 rounded text-xs flex-shrink-0 ml-2']">
            {{ STATUS_MAP[order.status]?.label || order.status }}
          </span>
        </div>
        <div class="text-xs text-gray-500 truncate mb-1">
          {{ order.platform_store || '—' }}
          <span v-if="order.external_order_no"> · <span class="font-mono">{{ order.external_order_no }}</span></span>
          <span v-if="order.sku_code"> · SKU:{{ order.sku_code }}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-xs text-gray-400">{{ formatDate(order.order_time || order.created_at) }}</span>
          <span v-if="order.amount !== order.payment_amount" class="text-xs text-gray-400">订单额 {{ formatMoney(order.amount) }}</span>
        </div>
      </div>
      <div v-if="!loading && orders.length === 0" class="text-center py-16 text-gray-500">
        <div class="text-3xl mb-2">📭</div>
        <div>暂无电商订单</div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="pagination.total > pagination.pageSize" class="flex items-center justify-between mt-4">
      <span class="text-xs text-gray-500">第 {{ pagination.page }} / {{ totalPages }} 页，共 {{ pagination.total }} 条</span>
      <div class="flex gap-1">
        <button @click="goPage(1)" :disabled="pagination.page <= 1" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">首页</button>
        <button @click="goPage(pagination.page - 1)" :disabled="pagination.page <= 1" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">上一页</button>
        <button @click="goPage(pagination.page + 1)" :disabled="pagination.page >= totalPages" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">下一页</button>
        <button @click="goPage(totalPages)" :disabled="pagination.page >= totalPages" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">末页</button>
      </div>
    </div>

    <!-- 详情弹窗 -->
    <div v-if="showDetail" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showDetail = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full md:max-w-lg md:mx-4 overflow-hidden max-h-[90vh] flex flex-col">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 class="font-bold text-gray-800">🛒 电商订单详情</h2>
          <button @click="showDetail = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="p-6 overflow-y-auto space-y-3" v-if="detailOrder">
          <!-- 状态 & 金额 -->
          <div class="flex items-center justify-between">
            <span :class="[STATUS_MAP[detailOrder.status]?.class, 'px-3 py-1 rounded-lg text-sm font-medium']">
              {{ STATUS_MAP[detailOrder.status]?.label || detailOrder.status }}
            </span>
            <span class="text-xl font-bold text-green-600">{{ formatMoney(detailOrder.payment_amount || detailOrder.amount) }}</span>
          </div>

          <!-- 平台信息 -->
          <div class="bg-blue-50 rounded-lg p-4 space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">平台</span>
              <span :class="platformBadgeClass(detailOrder.platform_type)" class="font-medium px-2 py-0.5 rounded-full text-xs">
                {{ PLATFORM_MAP[detailOrder.platform_type] || detailOrder.platform_type }}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">店铺</span>
              <span class="font-medium text-gray-800">{{ detailOrder.platform_store || '—' }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.external_order_no">
              <span class="text-gray-500">线上订单号</span>
              <span class="font-mono text-gray-700 text-xs">{{ detailOrder.external_order_no }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.sku_code">
              <span class="text-gray-500">SKU编码</span>
              <span class="font-mono text-purple-600">{{ detailOrder.sku_code }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.payment_amount">
              <span class="text-gray-500">实收金额</span>
              <span class="font-medium text-green-600">{{ formatMoney(detailOrder.payment_amount) }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.amount && detailOrder.amount !== detailOrder.payment_amount">
              <span class="text-gray-500">订单金额</span>
              <span class="text-gray-600">{{ formatMoney(detailOrder.amount) }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.account_code">
              <span class="text-gray-500">账户代码</span>
              <span class="font-mono text-blue-600 text-xs">{{ detailOrder.account_code }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.order_time">
              <span class="text-gray-500">下单时间</span>
              <span class="text-gray-700">{{ formatDate(detailOrder.order_time, 'full') }}</span>
            </div>
          </div>

          <!-- 通用信息 -->
          <div class="bg-gray-50 rounded-lg p-4 space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">系统订单号</span>
              <span class="font-mono text-gray-700 text-xs">{{ detailOrder.order_no }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.quantity && detailOrder.quantity > 1">
              <span class="text-gray-500">数量</span>
              <span class="text-gray-800">{{ detailOrder.quantity }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">创建时间</span>
              <span class="text-gray-600 text-xs">{{ formatDate(detailOrder.created_at, 'full') }}</span>
            </div>
            <div class="flex justify-between" v-if="detailOrder.note">
              <span class="text-gray-500">备注</span>
              <span class="text-gray-800 text-right max-w-[60%]">{{ detailOrder.note }}</span>
            </div>
          </div>

          <!-- 退款记录 -->
          <div v-if="detailRefunds.length > 0" class="space-y-2">
            <h3 class="text-sm font-medium text-gray-700">退款记录</h3>
            <div v-for="r in detailRefunds" :key="r.id" class="bg-red-50 rounded-lg p-3 text-sm">
              <div class="flex justify-between">
                <span class="text-red-600 font-medium">-{{ formatMoney(r.refund_amount) }}</span>
                <span :class="r.status === 'completed' ? 'text-green-600' : 'text-orange-500'" class="text-xs">
                  {{ r.status === 'completed' ? '已完成' : r.status === 'pending' ? '待审批' : r.status }}
                </span>
              </div>
              <div class="text-xs text-gray-500 mt-1">
                {{ r.refund_no }} · {{ formatDate(r.created_at) }}
                <span v-if="r.reason"> · {{ r.reason }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 移动端菜单遮罩 -->
    <div v-if="showMobileMenu" class="fixed inset-0 z-40 md:hidden" @click="showMobileMenu = false"></div>

    <!-- 电商订单导入弹窗 -->
    <div v-if="showImportModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-[60] pb-16 md:pb-0" @click.self="showImportModal = false">
      <div class="bg-white rounded-2xl w-full max-w-lg mx-4 max-h-[85vh] flex flex-col overflow-hidden">
        <div class="shrink-0 px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="font-bold text-gray-800">🛒 电商订单导入</h2>
          <button @click="closeImport" class="text-gray-500 hover:text-gray-600 cursor-pointer text-xl">&times;</button>
        </div>
        <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
          <div class="bg-blue-50 rounded-lg p-3 text-xs text-blue-700 space-y-1">
            <div class="font-medium">📌 使用说明</div>
            <ul class="list-disc list-inside space-y-0.5">
              <li>支持抖音、快手、视频号的销售和售后订单</li>
              <li>自动识别 Sheet 名称判断平台</li>
              <li>客户端自动对冲退款，只导入有效订单</li>
              <li>自动去重：已导入的订单号会跳过</li>
            </ul>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">平台选择</label>
            <div class="flex gap-3 flex-wrap">
              <label v-for="opt in importPlatformOptions" :key="opt.key" class="flex items-center gap-1.5 cursor-pointer">
                <input type="radio" v-model="importPlatform" :value="opt.key" class="cursor-pointer" />
                <span class="text-sm">{{ opt.label }}</span>
              </label>
            </div>
          </div>
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center cursor-pointer hover:border-blue-400 transition"
               @click="$refs.importFileInput?.click()"
               @dragover.prevent @drop.prevent="handleImportDrop">
            <input ref="importFileInput" type="file" accept=".xlsx,.xls" class="hidden" @change="handleImportFile" />
            <div v-if="!importParsed">
              <div class="text-3xl mb-2">📂</div>
              <div class="text-sm text-gray-600">点击选择 Excel 文件，或拖拽到此处</div>
              <div class="text-xs text-gray-400 mt-1">支持 .xlsx / .xls</div>
            </div>
            <div v-else class="text-left">
              <div class="text-sm font-medium text-gray-800 mb-2">📄 {{ importFileName }}</div>
              <div class="text-xs text-gray-600 space-y-1">
                <div>📦 销售订单：{{ importSalesCount }} 条</div>
                <div>↩️ 售后订单：{{ importAfterSalesCount }} 条</div>
                <div class="text-green-600 font-medium">✅ 对冲后有效订单：{{ importEffectiveCount }} 条</div>
                <div v-if="importSkipped > 0" class="text-gray-500">⏭️ 跳过：{{ importSkipped }} 条</div>
              </div>
            </div>
          </div>
          <div v-if="importProgress" class="bg-gray-50 rounded-lg p-3">
            <div class="text-sm text-gray-700 mb-1">{{ importProgress.message }}</div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-blue-500 rounded-full h-2 transition-all" :style="{ width: importProgress.percent + '%' }"></div>
            </div>
          </div>
          <div v-if="importResult" class="rounded-lg p-3" :class="importResult.failures?.length ? 'bg-orange-50' : 'bg-green-50'">
            <div class="text-sm font-medium mb-1" :class="importResult.failures?.length ? 'text-orange-700' : 'text-green-700'">导入完成</div>
            <div class="text-xs space-y-0.5">
              <div class="text-green-600">✅ 成功：{{ importResult.success }} 条</div>
              <div v-if="importResult.duplicate" class="text-gray-500">⏭️ 重复跳过：{{ importResult.duplicate }} 条</div>
              <div v-if="importResult.failures?.length" class="text-red-500">❌ 失败：{{ importResult.failures.length }} 条</div>
            </div>
          </div>
        </div>
        <div class="shrink-0 px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="closeImport" class="px-4 py-2 text-gray-600 text-sm rounded-lg hover:bg-gray-100 cursor-pointer">{{ importResult ? '关闭' : '取消' }}</button>
          <button v-if="importParsed && !importResult" @click="doImport" :disabled="importing || importEffectiveCount === 0"
            class="px-4 py-2 bg-green-600 text-white text-sm rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
            {{ importing ? '导入中...' : '开始导入' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import * as XLSX from 'xlsx'
import { supabase } from '../lib/supabase'
import { parseEcommerceExcel, importEcommerceOrders } from '../lib/ecommerceOrderImporter'
import { formatMoney, PLATFORM_LABELS, toast } from '../lib/utils'
import { useAuthStore } from '../stores/auth'
import { logOperation } from '../utils/operationLogger'
import { dayEnd } from '../utils/dateRange'

const auth = useAuthStore()

const PLATFORM_MAP = {
  douyin: '抖音',
  kuaishou: '快手',
  shipinhao: '视频号',
}

const STATUS_MAP = {
  pending: { label: '待确认', class: 'bg-yellow-50 text-yellow-700' },
  completed: { label: '已完成', class: 'bg-green-50 text-green-700' },
  partially_refunded: { label: '部分退款', class: 'bg-orange-50 text-orange-700' },
  refunded: { label: '已退款', class: 'bg-red-50 text-red-600' },
  cancelled: { label: '已取消', class: 'bg-gray-100 text-gray-500' },
}

// ========== 状态 ==========
const loading = ref(false)
const orders = ref([])
const selectedOrders = ref([])
const pagination = reactive({ total: 0, page: 1, pageSize: 20 })
const storeList = ref([])

const filters = reactive({
  keyword: '',
  platform: '',
  store: '',
  status: '',
  dateFrom: '',
  dateTo: '',
})

const stats = reactive({
  monthOrders: 0,
  monthSales: 0,
  monthRefund: 0,
})

const showDetail = ref(false)
const detailOrder = ref(null)
const detailRefunds = ref([])
const showMobileMenu = ref(false)

// ========== 导入状态 ==========
const showImportModal = ref(false)
const importPlatform = ref('auto')
const importFileName = ref('')
const importParsed = ref(null)
const importSalesCount = ref(0)
const importAfterSalesCount = ref(0)
const importEffectiveCount = ref(0)
const importSkipped = ref(0)
const importing = ref(false)
const importProgress = ref(null)
const importResult = ref(null)

const importPlatformOptions = [
  { key: 'auto', label: '自动识别(根据Sheet名称)' },
  { key: 'douyin', label: '抖音' },
  { key: 'kuaishou', label: '快手' },
  { key: 'shipinhao', label: '视频号' },
]

// ========== 权限 ==========
const canDelete = computed(() => ['admin', 'finance', 'manager'].includes(auth.profile?.role))
const isAllSelected = computed(() => orders.value.length > 0 && selectedOrders.value.length === orders.value.length)
const totalPages = computed(() => Math.max(1, Math.ceil(pagination.total / pagination.pageSize)))
const hasActiveFilters = computed(() => filters.keyword || filters.platform || filters.store || filters.status || filters.dateFrom || filters.dateTo)

// ========== 工具 ==========
function formatDate(dateStr, format) {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  if (format === 'full') {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

function platformBadgeClass(platform) {
  return {
    douyin: 'bg-pink-50 text-pink-600',
    kuaishou: 'bg-orange-50 text-orange-600',
    shipinhao: 'bg-green-50 text-green-600',
  }[platform] || 'bg-gray-100 text-gray-600'
}

// ========== 数据加载 ==========
async function loadOrders() {
  loading.value = true
  selectedOrders.value = []
  try {
    let query = supabase
      .from('orders')
      .select('*', { count: 'exact' })
      .not('platform_type', 'is', null)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .range((pagination.page - 1) * pagination.pageSize, pagination.page * pagination.pageSize - 1)

    if (filters.keyword) {
      query = query.or(`external_order_no.ilike.%${filters.keyword}%,platform_store.ilike.%${filters.keyword}%,sku_code.ilike.%${filters.keyword}%,order_no.ilike.%${filters.keyword}%`)
    }
    if (filters.platform) query = query.eq('platform_type', filters.platform)
    if (filters.store) query = query.eq('platform_store', filters.store)
    if (filters.status) query = query.eq('status', filters.status)
    if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom)
    if (filters.dateTo) query = query.lte('created_at', dayEnd(filters.dateTo))

    const { data, error, count } = await query
    if (error) throw error
    orders.value = data || []
    pagination.total = count || 0
  } catch (e) {
    console.error('加载电商订单失败:', e)
    toast('加载电商订单失败：' + (e?.message || e?.code || '未知错误'), 'error')
  } finally {
    loading.value = false
  }
}

async function loadStoreList() {
  try {
    const { data } = await supabase
      .from('orders')
      .select('platform_store')
      .not('platform_type', 'is', null)
      .not('platform_store', 'is', null)
      .is('deleted_at', null)
      .limit(500)
    storeList.value = [...new Set((data || []).map(d => d.platform_store).filter(Boolean))].sort()
  } catch (e) {
    console.error('加载店铺列表失败:', e)
  }
}

async function loadStats() {
  const now = new Date()
  const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
  try {
    // 本月订单 & 销售额
    const { data: monthOrders } = await supabase
      .from('orders')
      .select('amount, payment_amount')
      .not('platform_type', 'is', null)
      .is('deleted_at', null)
      .gte('created_at', monthStart)

    stats.monthOrders = (monthOrders || []).length
    stats.monthSales = (monthOrders || []).reduce((s, o) => s + (Number(o.payment_amount || o.amount) || 0), 0)

    // 本月退款
    const { data: monthRefunds } = await supabase
      .from('refunds')
      .select('refund_amount, orders!inner(platform_type)')
      .gte('created_at', monthStart)
      .is('deleted_at', null)
      .eq('status', 'completed')

    const ecomRefunds = (monthRefunds || []).filter(r => r.orders?.platform_type)
    stats.monthRefund = ecomRefunds.reduce((s, r) => s + (Number(r.refund_amount) || 0), 0)
  } catch (e) {
    console.error('加载统计失败:', e)
  }
}

// ========== 操作 ==========
function toggleSelectAll(e) {
  selectedOrders.value = e.target.checked ? orders.value.map(o => o.id) : []
}

function goPage(p) {
  if (p < 1 || p > totalPages.value) return
  pagination.page = p
  loadOrders()
}

function clearFilters() {
  filters.keyword = ''
  filters.platform = ''
  filters.store = ''
  filters.status = ''
  filters.dateFrom = ''
  filters.dateTo = ''
  pagination.page = 1
  loadOrders()
}

function openDetail(order) {
  detailOrder.value = order
  detailRefunds.value = []
  showDetail.value = true
  loadDetailRefunds(order.id)
}

async function loadDetailRefunds(orderId) {
  try {
    const { data } = await supabase
      .from('refunds')
      .select('id, refund_no, refund_amount, reason, status, created_at')
      .eq('order_id', orderId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
    detailRefunds.value = data || []
  } catch (e) {
    detailRefunds.value = []
  }
}

async function handleDelete(order) {
  if (!confirm(`确认删除此电商订单？\n订单号: ${order.external_order_no || order.order_no}\n金额: ¥${Number(order.amount).toFixed(2)}`)) return
  try {
    const { error } = await supabase.rpc('delete_order', { p_id: order.id })
    if (error) throw error
    await logOperation({
      action: 'delete_order',
      target_type: 'order',
      target_id: order.id,
      detail: `删除电商订单 ${order.external_order_no || order.order_no}，金额 ¥${Number(order.amount).toFixed(2)}，平台 ${PLATFORM_MAP[order.platform_type] || order.platform_type}`,
      operator_name: auth.profile?.name,
    })
    toast('订单已删除', 'success')
    loadOrders()
    loadStats()
  } catch (e) {
    toast('删除失败：' + (e.message || ''), 'error')
  }
}

async function handleBatchDelete() {
  if (!confirm(`确认删除选中的 ${selectedOrders.value.length} 条电商订单？`)) return
  try {
    const { data, error } = await supabase.rpc('batch_delete_orders', {
      p_ids: selectedOrders.value,
    })
    if (error) throw error
    const deletedCount = data?.deleted || selectedOrders.value.length
    await logOperation({
      action: 'batch_delete_orders',
      target_type: 'order',
      detail: `批量删除 ${deletedCount} 条电商订单`,
      operator_name: auth.profile?.name,
    })
    toast(`已删除 ${deletedCount} 条订单`, 'success')
    selectedOrders.value = []
    loadOrders()
    loadStats()
  } catch (e) {
    toast('批量删除失败: ' + (e.message || e), 'error')
  }
}

async function handleExport() {
  try {
    toast('正在导出...', 'info')
    let query = supabase
      .from('orders')
      .select('order_no, external_order_no, platform_type, platform_store, sku_code, amount, payment_amount, status, order_time, created_at')
      .not('platform_type', 'is', null)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(5000)

    if (filters.platform) query = query.eq('platform_type', filters.platform)
    if (filters.store) query = query.eq('platform_store', filters.store)
    if (filters.status) query = query.eq('status', filters.status)
    if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom)
    if (filters.dateTo) query = query.lte('created_at', dayEnd(filters.dateTo))

    const { data, error } = await query
    if (error) throw error

    const header = ['系统订单号', '线上订单号', '平台', '店铺', 'SKU', '订单金额', '实收金额', '状态', '下单时间', '导入时间']
    const rows = (data || []).map(o => [
      o.order_no || '',
      o.external_order_no || '',
      PLATFORM_MAP[o.platform_type] || o.platform_type || '',
      o.platform_store || '',
      o.sku_code || '',
      Number(o.amount).toFixed(2),
      Number(o.payment_amount || o.amount).toFixed(2),
      STATUS_MAP[o.status]?.label || o.status || '',
      o.order_time || '',
      o.created_at || '',
    ])

    const csv = '\uFEFF' + [header, ...rows].map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `电商订单_${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
    toast('导出完成', 'success')
  } catch (e) {
    toast('导出失败', 'error')
  }
}

// ========== 导入功能 ==========
function handleImportDrop(e) {
  const file = e.dataTransfer?.files?.[0]
  if (file) processImportFile(file)
}

function handleImportFile(e) {
  const file = e.target?.files?.[0]
  if (file) processImportFile(file)
}

async function processImportFile(file) {
  importFileName.value = file.name
  importResult.value = null
  importProgress.value = null

  try {
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data, { type: 'array' })

    const options = {
      autoDetect: importPlatform.value === 'auto',
      forcePlatform: importPlatform.value === 'auto' ? null : importPlatform.value,
    }

    const parsed = parseEcommerceExcel(workbook, options)
    importParsed.value = parsed
    importSalesCount.value = parsed.salesOrders.length
    importAfterSalesCount.value = parsed.afterSalesOrders.length
    importSkipped.value = parsed.skipped

    const afterSalesOrderNos = new Set(parsed.afterSalesOrders.map(a => a.external_order_no))
    const effectiveOrders = parsed.salesOrders.filter(s => !afterSalesOrderNos.has(s.external_order_no))
    importEffectiveCount.value = effectiveOrders.length
  } catch (e) {
    toast('文件解析失败: ' + e.message, 'error')
  }
}

async function doImport() {
  if (!importParsed.value) return
  importing.value = true
  importProgress.value = { message: '准备导入...', percent: 0 }

  try {
    const result = await importEcommerceOrders({
      salesOrders: importParsed.value.salesOrders,
      afterSalesOrders: importParsed.value.afterSalesOrders,
      supabase,
      onProgress: (p) => {
        const total = (importParsed.value.salesOrders.length || 1) + (importParsed.value.afterSalesOrders.length || 0)
        const current = p.type === 'aftersales'
          ? (importParsed.value.salesOrders.length + p.current)
          : p.current
        importProgress.value = {
          message: p.type === 'sales' ? `导入销售订单 ${p.current}/${p.total}` : `处理售后 ${p.current}/${p.total}`,
          percent: Math.round((current / total) * 100),
        }
      },
    })
    importResult.value = result
    importProgress.value = null
    // 刷新列表和统计
    await Promise.all([loadOrders(), loadStats(), loadStoreList()])
  } catch (e) {
    toast('导入失败: ' + e.message, 'error')
  } finally {
    importing.value = false
  }
}

function closeImport() {
  showImportModal.value = false
  importParsed.value = null
  importResult.value = null
  importProgress.value = null
  importFileName.value = ''
}

// ========== 初始化 ==========
onMounted(() => {
  if (auth.isLoggedIn) {
    loadOrders()
    loadStoreList()
    loadStats()
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { loadOrders(); loadStoreList(); loadStats(); unwatch() }
    })
  }
})
</script>
