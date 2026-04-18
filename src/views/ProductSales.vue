<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-4">
      <div>
        <h1 class="text-lg md:text-xl font-bold text-gray-800"><Icon name="package" class="inline w-4 h-4 -mt-0.5 mr-1" /> 产品销量报表</h1>
        <p class="text-xs text-gray-500 mt-0.5">按销售链路统计销量、收入</p>
      </div>
    </div>

    <!-- ========== 链路切换 Tab ========== -->
    <div class="flex items-center gap-1.5 mb-4 overflow-x-auto pb-1 scrollbar-none">
      <button v-for="ch in channels" :key="ch.key"
        @click="activeChannel = ch.key"
        :class="activeChannel === ch.key
          ? 'px-4 py-2 rounded-lg text-sm font-semibold bg-blue-600 text-white shadow-sm cursor-pointer'
          : 'px-4 py-2 rounded-lg text-sm text-gray-600 bg-white border border-gray-200 hover:bg-gray-50 cursor-pointer'">
        {{ ch.icon }} {{ ch.label }}
      </button>
    </div>

    <!-- ========== 筛选区（通用） ========== -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <!-- 私域：产品搜索 -->
      <input v-if="activeChannel === 'private'" v-model="search" placeholder="搜索产品名..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-48 outline-none focus:ring-2 focus:ring-blue-500">
      <!-- 私域：分类筛选 -->
      <select v-if="activeChannel === 'private'" v-model="categoryFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部分类</option>
        <option v-for="(label, key) in PRODUCT_ITEM_CATEGORIES" :key="key" :value="key">{{ label }}</option>
      </select>
      <!-- 电商：平台筛选 -->
      <select v-if="activeChannel === 'ecommerce'" v-model="ecomPlatformFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部平台</option>
        <option v-for="(label, key) in ECOM_PLATFORM_OPTIONS" :key="key" :value="key">{{ label }}</option>
      </select>
      <!-- 电商：店铺筛选 -->
      <select v-if="activeChannel === 'ecommerce'" v-model="ecomStoreFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部店铺</option>
        <option v-for="s in ecomStoreList" :key="s" :value="s">{{ s }}</option>
      </select>
      <!-- 通用：时间范围 -->
      <select v-model="periodType" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="month">本月</option>
        <option value="quarter">本季度</option>
        <option value="year">本年</option>
        <option value="all">全部</option>
      </select>
      <button @click="loadData" class="px-3 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm hover:bg-blue-100 cursor-pointer"><Icon name="refresh" class="inline w-4 h-4 -mt-0.5 mr-1" /> 刷新</button>
      <span class="text-sm text-gray-500 ml-auto">
        {{ activeChannel === 'private' ? `共 ${privateFilteredData.length} 个产品` : `共 ${ecomFilteredData.length} 条记录` }}
      </span>
    </div>

    <!-- ========== 私域销售 ========== -->
    <template v-if="activeChannel === 'private'">
      <!-- 汇总卡片 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1">产品种类</div>
          <div class="text-2xl font-bold text-blue-600">{{ privateFilteredData.length }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1">总销量（件）</div>
          <div class="text-2xl font-bold text-green-600">{{ pvTotalQuantity }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1">总收入</div>
          <div class="text-2xl font-bold text-orange-500">{{ formatMoney(pvTotalRevenue) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1">总成本</div>
          <div class="text-2xl font-bold text-red-500">{{ formatMoney(pvTotalCost) }}</div>
        </div>
      </div>

      <!-- 毛利卡片 -->
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex items-center justify-between">
        <div>
          <div class="text-xs text-gray-500">总毛利</div>
          <div class="text-2xl font-bold" :class="pvTotalProfit >= 0 ? 'text-green-600' : 'text-red-500'">{{ formatMoney(pvTotalProfit) }}</div>
        </div>
        <div class="text-right">
          <div class="text-xs text-gray-500">毛利率</div>
          <div class="text-lg font-bold" :class="pvProfitMargin >= 0 ? 'text-green-600' : 'text-red-500'">{{ pvProfitMarginStr }}%</div>
        </div>
      </div>

      <!-- 销量排行表 -->
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <Skeleton v-if="loading" type="table" :rows="6" :columns="8" />
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-600">
              <th class="px-4 py-3 text-center w-10">#</th>
              <th class="px-4 py-3 text-left">产品名称</th>
              <th class="px-4 py-3 text-left">分类</th>
              <th class="px-4 py-3 text-right">销量</th>
              <th class="px-4 py-3 text-right">总收入</th>
              <th class="px-4 py-3 text-right">总成本</th>
              <th class="px-4 py-3 text-right">毛利</th>
              <th class="px-4 py-3 text-right">毛利率</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, idx) in pvPaginatedData" :key="item.name"
              class="border-t border-gray-50 hover:bg-gray-50/60">
              <td class="px-4 py-3 text-center text-gray-500">{{ idx + 1 + (pvPage - 1) * pageSize }}</td>
              <td class="px-4 py-3 text-gray-800 font-medium">{{ item.name }}</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                  {{ PRODUCT_ITEM_CATEGORIES[item.category] || item.category || '—' }}
                </span>
              </td>
              <td class="px-4 py-3 text-right font-medium text-gray-700">{{ item.quantity }}</td>
              <td class="px-4 py-3 text-right text-green-600">{{ formatMoney(item.revenue) }}</td>
              <td class="px-4 py-3 text-right text-red-500">{{ formatMoney(item.cost) }}</td>
              <td class="px-4 py-3 text-right font-medium" :class="item.profit >= 0 ? 'text-green-600' : 'text-red-500'">
                {{ formatMoney(item.profit) }}
              </td>
              <td class="px-4 py-3 text-right text-gray-500">
                {{ item.revenue > 0 ? ((item.profit / item.revenue) * 100).toFixed(1) : '—' }}%
              </td>
            </tr>
            <tr v-if="privateFilteredData.length === 0">
              <td colspan="8" class="px-4 py-16 text-center text-gray-500">暂无私域销售数据</td>
            </tr>
          </tbody>
        </table>
        <!-- 分页 -->
        <div v-if="pvTotalPages > 1" class="flex items-center justify-between px-4 py-3 border-t border-gray-50">
          <span class="text-xs text-gray-500">第 {{ pvPage }} / {{ pvTotalPages }} 页</span>
          <div class="flex gap-1">
            <button @click="pvPage--" :disabled="pvPage <= 1" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">上一页</button>
            <button @click="pvPage++" :disabled="pvPage >= pvTotalPages" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">下一页</button>
          </div>
        </div>
      </div>

      <!-- 品牌排行 -->
      <div v-if="pvBrandData.length > 0" class="mt-6">
        <h2 class="text-base font-semibold text-gray-800 mb-3"><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 品牌销量排行</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div v-for="brand in pvBrandData" :key="brand.name"
            class="bg-white rounded-xl border border-gray-100 p-4">
            <div class="text-sm font-medium text-gray-700 truncate">{{ brand.name }}</div>
            <div class="flex items-baseline justify-between mt-2">
              <span class="text-lg font-bold text-blue-600">{{ brand.quantity }}</span>
              <span class="text-xs text-gray-500">件</span>
            </div>
            <div class="text-xs text-gray-500 mt-1">收入 {{ formatMoney(brand.revenue) }}</div>
          </div>
        </div>
      </div>
    </template>

    <!-- ========== 电商销售 ========== -->
    <template v-if="activeChannel === 'ecommerce'">
      <!-- 汇总卡片 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 总销售额</div>
          <div class="text-2xl font-bold text-green-600">{{ formatMoney(ecomSummary.sales) }}</div>
          <div class="text-xs text-gray-500 mt-0.5">{{ ecomSummary.orders }} 单</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1">↩️ 退款金额</div>
          <div class="text-2xl font-bold text-red-500">{{ formatMoney(ecomSummary.refund) }}</div>
          <div class="text-xs text-gray-500 mt-0.5">退款率 {{ ecomSummary.refundRate }}%</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1"><Icon name="trending-up" class="inline w-4 h-4 -mt-0.5 mr-1" /> 净销售额</div>
          <div class="text-2xl font-bold text-blue-600">{{ formatMoney(ecomSummary.net) }}</div>
          <div class="text-xs text-gray-500 mt-0.5">有效 {{ ecomSummary.effectiveOrders }} 单</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500 mb-1"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 客单价</div>
          <div class="text-2xl font-bold text-purple-600">{{ formatMoney(ecomSummary.avgOrderValue) }}</div>
          <div class="text-xs text-gray-500 mt-0.5">有效单均值</div>
        </div>
      </div>

      <!-- 平台分布 -->
      <div v-if="ecomPlatformBreakdown.length > 0" class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        <div v-for="pb in ecomPlatformBreakdown" :key="pb.platform"
          class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-gray-800">
              <span :class="platformBadgeClass(pb.platform)" class="inline-block px-2 py-0.5 rounded-full text-xs mr-1">
                {{ ECOM_PLATFORM_OPTIONS[pb.platform] || pb.platform }}
              </span>
            </span>
            <span class="text-xs text-gray-500">{{ pb.orders }} 单</span>
          </div>
          <div class="text-xl font-bold text-gray-800">{{ formatMoney(pb.sales) }}</div>
          <div class="flex items-center justify-between mt-1">
            <span class="text-xs text-gray-500">净额 {{ formatMoney(pb.net) }}</span>
            <span class="text-xs text-red-400">退 {{ formatMoney(pb.refund) }}</span>
          </div>
        </div>
      </div>

      <!-- 店铺明细表 -->
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-100 flex items-center justify-between">
          <h3 class="text-sm font-medium text-gray-700">店铺销售明细</h3>
        </div>
        <Skeleton v-if="loading" type="table" :rows="6" :columns="7" />
        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 text-gray-500 text-xs">
                <th class="px-4 py-2.5 text-center w-10">#</th>
                <th class="px-4 py-2.5 text-left">店铺</th>
                <th class="px-3 py-2.5 text-left">平台</th>
                <th class="px-3 py-2.5 text-right">订单数</th>
                <th class="px-3 py-2.5 text-right">有效单</th>
                <th class="px-3 py-2.5 text-right">销售额</th>
                <th class="px-3 py-2.5 text-right">退款</th>
                <th class="px-3 py-2.5 text-right">退款率</th>
                <th class="px-3 py-2.5 text-right">净销售额</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, idx) in ecomPaginatedData" :key="row.store + row.platform"
                class="border-t border-gray-50 hover:bg-gray-50/60">
                <td class="px-4 py-3 text-center text-gray-500">{{ idx + 1 + (ecomPage - 1) * pageSize }}</td>
                <td class="px-4 py-3 text-gray-800 font-medium">{{ row.store || '未知' }}</td>
                <td class="px-3 py-3">
                  <span :class="platformBadgeClass(row.platform)" class="text-xs px-2 py-0.5 rounded-full">
                    {{ ECOM_PLATFORM_OPTIONS[row.platform] || row.platform || '—' }}
                  </span>
                </td>
                <td class="px-3 py-3 text-right">{{ row.orders }}</td>
                <td class="px-3 py-3 text-right text-green-600">{{ row.effectiveOrders }}</td>
                <td class="px-3 py-3 text-right text-green-600 font-medium">{{ formatMoney(row.sales) }}</td>
                <td class="px-3 py-3 text-right text-red-400">{{ formatMoney(row.refund) }}</td>
                <td class="px-3 py-3 text-right text-orange-500">{{ row.refundRate }}%</td>
                <td class="px-3 py-3 text-right font-semibold text-blue-600">{{ formatMoney(row.net) }}</td>
              </tr>
              <tr v-if="ecomFilteredData.length === 0">
                <td colspan="9" class="px-4 py-16 text-center text-gray-500">暂无电商销售数据</td>
              </tr>
            </tbody>
            <!-- 合计行 -->
            <tfoot v-if="ecomFilteredData.length > 0">
              <tr class="border-t-2 border-gray-200 bg-gray-50 font-semibold text-sm">
                <td class="px-4 py-3"></td>
                <td class="px-4 py-3 text-gray-700">合计</td>
                <td class="px-3 py-3"></td>
                <td class="px-3 py-3 text-right">{{ ecomSummary.orders }}</td>
                <td class="px-3 py-3 text-right text-green-600">{{ ecomSummary.effectiveOrders }}</td>
                <td class="px-3 py-3 text-right text-green-600">{{ formatMoney(ecomSummary.sales) }}</td>
                <td class="px-3 py-3 text-right text-red-400">{{ formatMoney(ecomSummary.refund) }}</td>
                <td class="px-3 py-3 text-right text-orange-500">{{ ecomSummary.refundRate }}%</td>
                <td class="px-3 py-3 text-right text-blue-600">{{ formatMoney(ecomSummary.net) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
        <!-- 分页 -->
        <div v-if="ecomTotalPages > 1" class="flex items-center justify-between px-4 py-3 border-t border-gray-50">
          <span class="text-xs text-gray-500">第 {{ ecomPage }} / {{ ecomTotalPages }} 页</span>
          <div class="flex gap-1">
            <button @click="ecomPage--" :disabled="ecomPage <= 1" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">上一页</button>
            <button @click="ecomPage++" :disabled="ecomPage >= ecomTotalPages" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">下一页</button>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import Skeleton from '../components/Skeleton.vue'
import { supabase } from '../lib/supabase'
import { formatMoney, PRODUCT_ITEM_CATEGORIES, PLATFORM_LABELS, toast } from '../lib/utils'
import { useAuthStore } from '../stores/auth'
import Icon from '../components/icons/Icons.vue'

const auth = useAuthStore()

// ========== 链路定义（可扩展） ==========
const channels = [
  { key: 'private', label: '私域销售', icon: '🏠' },
  { key: 'ecommerce', label: '电商销售', icon: '🛒' },
  // 以后新增链路只需在此追加，例如：
  // { key: 'wholesale', label: '批发渠道', icon: '📦' },
]

const ECOM_PLATFORM_OPTIONS = {
  douyin: '抖音',
  kuaishou: '快手',
  shipinhao: '视频号',
}

// ========== 共享状态 ==========
const loading = ref(true)
const activeChannel = ref('private')
const periodType = ref('month')
const pageSize = 20

// ========== 私域状态 ==========
const search = ref('')
const categoryFilter = ref('')
const pvRawData = ref([])
const pvPage = ref(1)

// ========== 电商状态 ==========
const ecomPlatformFilter = ref('')
const ecomStoreFilter = ref('')
const ecomRawData = ref([])   // 按店铺+平台聚合的数据
const ecomPage = ref(1)

// ========== 时间范围计算 ==========
function getDateFilter() {
  const now = new Date()
  if (periodType.value === 'month') {
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
  } else if (periodType.value === 'quarter') {
    const qStart = Math.floor(now.getMonth() / 3) * 3
    return `${now.getFullYear()}-${String(qStart + 1).padStart(2, '0')}-01`
  } else if (periodType.value === 'year') {
    return `${now.getFullYear()}-01-01`
  }
  return '' // 'all'
}

// ========== 私域数据加载 ==========
async function loadPrivateData() {
  const dateFilter = getDateFilter()

  // 查询私域订单明细（platform_type IS NULL）
  let itemQuery = supabase
    .from('order_items')
    .select('product_name, quantity, unit_cost, sale_price, is_gift, product_id, order_id, created_at, orders!inner(status, amount, platform_type)')
    .is('orders.platform_type', null)

  if (dateFilter) {
    itemQuery = itemQuery.gte('created_at', dateFilter)
  }

  const { data: items, error } = await itemQuery
  if (error) throw error

  // 查退款
  const orderIds = [...new Set((items || []).map(i => i.order_id).filter(Boolean))]
  const refundByOrder = {}
  if (orderIds.length > 0) {
    for (let i = 0; i < orderIds.length; i += 100) {
      const chunk = orderIds.slice(i, i + 100)
      const orFilter = chunk.map(id => `order_id.eq.${id}`).join(',')
      const { data: refunds } = await supabase
        .from('refunds')
        .select('order_id, refund_amount, status')
        .is('deleted_at', null)
        .eq('status', 'completed')
        .or(orFilter)
      ;(refunds || []).forEach(r => {
        if (!refundByOrder[r.order_id]) refundByOrder[r.order_id] = 0
        refundByOrder[r.order_id] += Number(r.refund_amount) || 0
      })
    }
  }

  // 按产品名聚合
  const productMap = {}
  for (const item of (items || [])) {
    if (item.is_gift) continue
    const orderStatus = item.orders?.status
    const orderAmount = Number(item.orders?.amount) || 0
    if (orderStatus === 'refunded') continue
    if (orderStatus && !['completed', 'partially_refunded'].includes(orderStatus)) continue

    const qty = item.quantity || 1
    const name = item.product_name || '未命名产品'
    if (!productMap[name]) {
      productMap[name] = { name, category: '', brand: '', quantity: 0, revenue: 0, cost: 0 }
    }

    let refundRatio = 0
    if (orderStatus === 'partially_refunded' && orderAmount > 0) {
      const totalRefunded = refundByOrder[item.order_id] || 0
      refundRatio = Math.min(totalRefunded / orderAmount, 1)
    }

    productMap[name].quantity += qty
    productMap[name].revenue += Number(item.sale_price) * qty * (1 - refundRatio)
    productMap[name].cost += Number(item.unit_cost) * qty * (1 - refundRatio)
  }

  // 补充分类和品牌
  const uniqueProductNames = [...new Set(Object.values(productMap).map(p => p.name))]
  if (uniqueProductNames.length > 0) {
    for (let i = 0; i < uniqueProductNames.length; i += 50) {
      const chunk = uniqueProductNames.slice(i, i + 50)
      const orFilter = chunk.map(n => `name.eq.${n}`).join(',')
      const { data: products } = await supabase
        .from('products')
        .select('name, category, brand')
        .or(orFilter)
      ;(products || []).forEach(p => {
        for (const key in productMap) {
          if (productMap[key].name === p.name) {
            if (p.category) productMap[key].category = p.category
            if (p.brand) productMap[key].brand = p.brand
          }
        }
      })
    }
  }

  pvRawData.value = Object.values(productMap)
}

// ========== 电商数据加载 ==========
async function loadEcommerceData() {
  const dateFilter = getDateFilter()

  // 查询电商订单（platform_type 非空）
  let query = supabase
    .from('orders')
    .select('id, amount, payment_amount, status, platform_type, platform_store, created_at')
    .not('platform_type', 'is', null)
    .is('deleted_at', null)

  if (dateFilter) {
    query = query.gte('created_at', dateFilter)
  }

  const { data: orders, error } = await query
  if (error) throw error

  // 查退款
  const orderIds = (orders || []).map(o => o.id)
  const refundsMap = {}
  if (orderIds.length > 0) {
    for (let i = 0; i < orderIds.length; i += 200) {
      const batch = orderIds.slice(i, i + 200)
      const { data: refunds } = await supabase
        .from('refunds')
        .select('order_id, refund_amount')
        .is('deleted_at', null)
        .in('order_id', batch)
        .eq('status', 'completed')
      if (refunds) {
        refunds.forEach(r => {
          refundsMap[r.order_id] = (refundsMap[r.order_id] || 0) + Number(r.refund_amount || 0)
        })
      }
    }
  }

  // 按 店铺+平台 聚合
  const storeMap = {}
  for (const o of (orders || [])) {
    const store = o.platform_store || '未知店铺'
    const platform = o.platform_type || 'other'
    const key = `${store}__${platform}`
    if (!storeMap[key]) {
      storeMap[key] = { store, platform, orders: 0, effectiveOrders: 0, sales: 0, refund: 0, net: 0 }
    }
    const row = storeMap[key]
    const amt = Number(o.payment_amount || o.amount || 0)
    const refAmt = refundsMap[o.id] || 0
    row.orders += 1
    row.sales += amt
    row.refund += refAmt
    row.net += amt - refAmt
    if (refAmt < amt) row.effectiveOrders += 1
  }

  // 计算退款率
  for (const row of Object.values(storeMap)) {
    row.refundRate = row.sales > 0 ? ((row.refund / row.sales) * 100).toFixed(1) : '0.0'
  }

  ecomRawData.value = Object.values(storeMap).sort((a, b) => b.net - a.net)
}

// ========== 统一加载 ==========
async function loadData() {
  loading.value = true
  try {
    await Promise.all([loadPrivateData(), loadEcommerceData()])
  } catch (e) {
    console.error('加载销量数据失败:', e)
    toast('加载数据失败', 'error')
  } finally {
    loading.value = false
  }
}

// ========== 私域 computed ==========
const privateFilteredData = computed(() => {
  let list = pvRawData.value
  if (search.value) {
    const kw = search.value.toLowerCase()
    list = list.filter(i => (i.name || '').toLowerCase().includes(kw))
  }
  if (categoryFilter.value) {
    list = list.filter(i => i.category === categoryFilter.value)
  }
  return list
})

const pvSortedData = computed(() => [...privateFilteredData.value].sort((a, b) => b.quantity - a.quantity))
const pvTotalPages = computed(() => Math.max(1, Math.ceil(pvSortedData.value.length / pageSize)))
const pvPaginatedData = computed(() => {
  const start = (pvPage.value - 1) * pageSize
  return pvSortedData.value.slice(start, start + pageSize)
})

const pvTotalQuantity = computed(() => privateFilteredData.value.reduce((s, i) => s + i.quantity, 0))
const pvTotalRevenue = computed(() => privateFilteredData.value.reduce((s, i) => s + i.revenue, 0))
const pvTotalCost = computed(() => privateFilteredData.value.reduce((s, i) => s + i.cost, 0))
const pvTotalProfit = computed(() => pvTotalRevenue.value - pvTotalCost.value)
const pvProfitMargin = computed(() => pvTotalRevenue.value > 0 ? pvTotalProfit.value / pvTotalRevenue.value * 100 : 0)
const pvProfitMarginStr = computed(() => pvProfitMargin.value.toFixed(1))

const pvBrandData = computed(() => {
  const brands = {}
  for (const item of pvSortedData.value) {
    const bName = item.brand || '未分类'
    if (!brands[bName]) brands[bName] = { name: bName, quantity: 0, revenue: 0, cost: 0 }
    brands[bName].quantity += item.quantity
    brands[bName].revenue += item.revenue
    brands[bName].cost += item.cost
  }
  return Object.values(brands).sort((a, b) => b.quantity - a.quantity).slice(0, 8)
})

// ========== 电商 computed ==========
const ecomStoreList = computed(() => [...new Set(ecomRawData.value.map(d => d.store))])

const ecomFilteredData = computed(() => {
  let list = ecomRawData.value
  if (ecomPlatformFilter.value) {
    list = list.filter(i => i.platform === ecomPlatformFilter.value)
  }
  if (ecomStoreFilter.value) {
    list = list.filter(i => i.store === ecomStoreFilter.value)
  }
  return list
})

const ecomTotalPages = computed(() => Math.max(1, Math.ceil(ecomFilteredData.value.length / pageSize)))
const ecomPaginatedData = computed(() => {
  const start = (ecomPage.value - 1) * pageSize
  return ecomFilteredData.value.slice(start, start + pageSize)
})

const ecomSummary = computed(() => {
  const d = ecomFilteredData.value
  const orders = d.reduce((s, r) => s + r.orders, 0)
  const effectiveOrders = d.reduce((s, r) => s + r.effectiveOrders, 0)
  const sales = d.reduce((s, r) => s + r.sales, 0)
  const refund = d.reduce((s, r) => s + r.refund, 0)
  const net = d.reduce((s, r) => s + r.net, 0)
  return {
    orders,
    effectiveOrders,
    sales,
    refund,
    net,
    refundRate: sales > 0 ? ((refund / sales) * 100).toFixed(1) : '0.0',
    avgOrderValue: effectiveOrders > 0 ? net / effectiveOrders : 0,
  }
})

const ecomPlatformBreakdown = computed(() => {
  const map = {}
  for (const row of ecomFilteredData.value) {
    const p = row.platform
    if (!map[p]) map[p] = { platform: p, orders: 0, sales: 0, refund: 0, net: 0 }
    map[p].orders += row.orders
    map[p].sales += row.sales
    map[p].refund += row.refund
    map[p].net += row.net
  }
  return Object.values(map).sort((a, b) => b.net - a.net)
})

// ========== 工具 ==========
function platformBadgeClass(platform) {
  const classes = {
    douyin: 'bg-pink-50 text-pink-600',
    kuaishou: 'bg-orange-50 text-orange-600',
    shipinhao: 'bg-green-50 text-green-600',
  }
  return classes[platform] || 'bg-gray-100 text-gray-600'
}

// ========== watch & mount ==========
watch(activeChannel, () => {
  pvPage.value = 1
  ecomPage.value = 1
})

watch(periodType, () => {
  loadData()
})

onMounted(() => {
  if (auth.isLoggedIn) {
    loadData()
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { loadData(); unwatch() }
    })
  }
})
</script>
