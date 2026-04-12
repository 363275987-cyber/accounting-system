<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-lg md:text-xl font-bold text-gray-800">📦 产品销量报表</h1>
        <p class="text-xs text-gray-500 mt-0.5">按产品统计销量、收入和成本</p>
      </div>
    </div>

    <!-- 筛选区 -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="search" placeholder="搜索产品名/品牌..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
      <select v-model="categoryFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部分类</option>
        <option v-for="(label, key) in PRODUCT_ITEM_CATEGORIES" :key="key" :value="key">{{ label }}</option>
      </select>
      <select v-model="channelFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部渠道</option>
        <option v-for="(label, key) in CHANNEL_OPTIONS" :key="key" :value="key">{{ label }}</option>
      </select>
      <select v-model="periodType" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="month">本月</option>
        <option value="quarter">本季度</option>
        <option value="all">全部</option>
      </select>
      <button @click="loadData" class="px-3 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm hover:bg-blue-100 cursor-pointer">🔄 刷新</button>
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredData.length }} 个产品</span>
    </div>

    <!-- 汇总卡片 -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">产品种类</div>
        <div class="text-2xl font-bold text-blue-600">{{ filteredData.length }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">总销量（件）</div>
        <div class="text-2xl font-bold text-green-600">{{ totalQuantity }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">总收入</div>
        <div class="text-2xl font-bold text-orange-500">¥{{ totalRevenue.toLocaleString() }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">总成本</div>
        <div class="text-2xl font-bold text-red-500">¥{{ totalCost.toLocaleString() }}</div>
      </div>
    </div>

    <!-- 毛利卡片 -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex items-center justify-between">
      <div>
        <div class="text-xs text-gray-500">总毛利</div>
        <div class="text-2xl font-bold" :class="totalProfit >= 0 ? 'text-green-600' : 'text-red-500'">¥{{ totalProfit.toLocaleString() }}</div>
      </div>
      <div class="text-right">
        <div class="text-xs text-gray-500">毛利率</div>
        <div class="text-lg font-bold" :class="profitMargin >= 0 ? 'text-green-600' : 'text-red-500'">{{ profitMargin }}%</div>
      </div>
    </div>

    <!-- 销量排行表 -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <div v-if="loading" class="p-16 text-center text-gray-500">加载中...</div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-center w-10">#</th>
            <th class="px-4 py-3 text-left">产品名称</th>
            <th class="px-4 py-3 text-left">销售渠道</th>
            <th class="px-4 py-3 text-left">分类</th>
            <th class="px-4 py-3 text-right">销量</th>
            <th class="px-4 py-3 text-right">总收入</th>
            <th class="px-4 py-3 text-right">总成本</th>
            <th class="px-4 py-3 text-right">毛利</th>
            <th class="px-4 py-3 text-right">毛利率</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, idx) in paginatedData" :key="item.name"
            class="border-t border-gray-50 hover:bg-gray-50/60">
            <td class="px-4 py-3 text-center text-gray-500">{{ idx + 1 + (currentPage - 1) * pageSize }}</td>
            <td class="px-4 py-3 text-gray-800 font-medium">{{ item.name }}</td>
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded-full"
                :class="{
                  'bg-gray-100 text-gray-600': item.channel === 'private',
                  'bg-pink-50 text-pink-600': item.channel === 'douyin',
                  'bg-orange-50 text-orange-600': item.channel === 'kuaishou',
                  'bg-green-50 text-green-600': item.channel === 'shipinhao',
                }">{{ CHANNEL_OPTIONS[item.channel] || '私域' }}</span>
            </td>
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
          <tr v-if="filteredData.length === 0">
            <td colspan="9" class="px-4 py-16 text-center text-gray-500">暂无数据</td>
          </tr>
        </tbody>
      </table>

      <!-- 分页 -->
      <div v-if="totalPages > 1" class="flex items-center justify-between px-4 py-3 border-t border-gray-50">
        <span class="text-xs text-gray-500">第 {{ currentPage }} / {{ totalPages }} 页</span>
        <div class="flex gap-1">
          <button @click="currentPage--" :disabled="currentPage <= 1" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">上一页</button>
          <button @click="currentPage++" :disabled="currentPage >= totalPages" class="px-2 py-1 border rounded text-xs disabled:opacity-40 cursor-pointer hover:bg-gray-50">下一页</button>
        </div>
      </div>
    </div>

    <!-- 品牌排行 -->
    <div v-if="brandData.length > 0" class="mt-6">
      <h2 class="text-base font-semibold text-gray-800 mb-3">🏷️ 品牌销量排行</h2>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div v-for="brand in brandData" :key="brand.name"
          class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-sm font-medium text-gray-700 truncate">{{ brand.name }}</div>
          <div class="flex items-baseline justify-between mt-2">
            <span class="text-lg font-bold text-blue-600">{{ brand.quantity }}</span>
            <span class="text-xs text-gray-500">件</span>
          </div>
          <div class="text-xs text-gray-500 mt-1">收入 ¥{{ brand.revenue.toLocaleString() }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { formatMoney, PRODUCT_ITEM_CATEGORIES, PLATFORM_LABELS, toast } from '../lib/utils'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

const loading = ref(true)
const search = ref('')
const categoryFilter = ref('')
const channelFilter = ref('')
const periodType = ref('month')
const CHANNEL_OPTIONS = { private: '私域', douyin: '抖音', kuaishou: '快手', shipinhao: '视频号' }
const currentPage = ref(1)
const pageSize = 20
const rawData = ref([])

const filteredData = computed(() => {
  let list = rawData.value
  if (search.value) {
    const kw = search.value.toLowerCase()
    list = list.filter(i =>
      (i.name || '').toLowerCase().includes(kw)
    )
  }
  if (categoryFilter.value) {
    list = list.filter(i => i.category === categoryFilter.value)
  }
  if (channelFilter.value) {
    list = list.filter(i => i.channel === channelFilter.value)
  }
  return list
})

const sortedData = computed(() => {
  return [...filteredData.value].sort((a, b) => b.quantity - a.quantity)
})

const totalPages = computed(() => Math.max(1, Math.ceil(sortedData.value.length / pageSize)))

const paginatedData = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return sortedData.value.slice(start, start + pageSize)
})

const totalQuantity = computed(() => filteredData.value.reduce((s, i) => s + i.quantity, 0))
const totalRevenue = computed(() => filteredData.value.reduce((s, i) => s + i.revenue, 0))
const totalCost = computed(() => filteredData.value.reduce((s, i) => s + i.cost, 0))
const totalProfit = computed(() => totalRevenue.value - totalCost.value)
const profitMargin = computed(() => {
  if (totalRevenue.value <= 0) return '0.0'
  return ((totalProfit.value / totalRevenue.value) * 100).toFixed(1)
})

const brandData = computed(() => {
  const brands = {}
  for (const item of sortedData.value) {
    if (!brands[item.brand]) {
      brands[item.brand] = { name: item.brand || '未分类', quantity: 0, revenue: 0, cost: 0 }
    }
    brands[item.brand].quantity += item.quantity
    brands[item.brand].revenue += item.revenue
    brands[item.brand].cost += item.cost
  }
  return Object.values(brands).sort((a, b) => b.quantity - a.quantity).slice(0, 8)
})

async function loadData() {
  loading.value = true
  try {
    // 构建时间过滤
    let dateFilter = ''
    if (periodType.value === 'month') {
      const now = new Date()
      const start = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
      dateFilter = start
    } else if (periodType.value === 'quarter') {
      const now = new Date()
      const qStart = Math.floor(now.getMonth() / 3) * 3
      const start = `${now.getFullYear()}-${String(qStart + 1).padStart(2, '0')}-01`
      dateFilter = start
    }

    // 1. 查所有订单明细 + 订单状态 + 订单金额 + 平台类型
    let itemQuery = supabase
      .from('order_items')
      .select('product_name, quantity, unit_cost, sale_price, is_gift, product_id, order_id, created_at, orders(status, amount, platform_type)')

    if (dateFilter) {
      itemQuery = itemQuery.gte('created_at', dateFilter)
    }

    const { data: items, error } = await itemQuery
    if (error) throw error

    // 2. 查所有已完成退款的退款金额（按 order_id 汇总）
    const orderIds = [...new Set((items || []).map(i => i.order_id).filter(Boolean))]
    const refundByOrder = {}
    if (orderIds.length > 0) {
      // 分批查，每批 100
      const chunks = []
      for (let i = 0; i < orderIds.length; i += 100) {
        chunks.push(orderIds.slice(i, i + 100))
      }
      for (const chunk of chunks) {
        const orFilter = chunk.map(id => `order_id.eq.${id}`).join(',')
        const { data: refunds } = await supabase
          .from('refunds')
          .select('order_id, refund_amount, status')
          .eq('status', 'completed')
          .or(orFilter)
        ;(refunds || []).forEach(r => {
          if (!refundByOrder[r.order_id]) refundByOrder[r.order_id] = 0
          refundByOrder[r.order_id] += Number(r.refund_amount) || 0
        })
      }
    }

    // 3. 按产品名聚合（排除赠品、排除全退款订单）
    const productMap = {}
    for (const item of (items || [])) {
      if (item.is_gift) continue

      const orderStatus = item.orders?.status
      const orderAmount = Number(item.orders?.amount) || 0

      // 全退款：完全排除
      if (orderStatus === 'refunded') continue
      // 非已完成/部分退款也排除（待确认、已取消等）
      if (orderStatus && !['completed', 'partially_refunded'].includes(orderStatus)) continue

      const qty = item.quantity || 1
      const name = item.product_name || '未命名产品'
      const channel = item.orders?.platform_type || 'private'
      const channelKey = `${name}__${channel}`
      if (!productMap[channelKey]) {
        productMap[channelKey] = { name, channel, category: '', brand: '', quantity: 0, revenue: 0, cost: 0 }
      }

      // 计算退款扣减比例
      let refundRatio = 0
      if (orderStatus === 'partially_refunded' && orderAmount > 0) {
        const totalRefunded = refundByOrder[item.order_id] || 0
        refundRatio = Math.min(totalRefunded / orderAmount, 1)
      }

      // 扣减后的实际数值
      const actualQty = orderStatus === 'partially_refunded' ? qty : qty // 数量不变（已售出）
      const actualRevenue = Number(item.sale_price) * qty * (1 - refundRatio)
      const actualCost = Number(item.unit_cost) * qty * (1 - refundRatio)

      productMap[channelKey].quantity += actualQty
      productMap[channelKey].revenue += actualRevenue
      productMap[channelKey].cost += actualCost
    }

    // 4. 补充分类和品牌信息
    const uniqueProductNames = [...new Set(Object.values(productMap).map(p => p.name))]
    if (uniqueProductNames.length > 0) {
      const chunks = []
      for (let i = 0; i < uniqueProductNames.length; i += 50) {
        chunks.push(uniqueProductNames.slice(i, i + 50))
      }
      for (const chunk of chunks) {
        const orFilter = chunk.map(n => `name.eq.${n}`).join(',')
        const { data: products } = await supabase
          .from('products')
          .select('name, category, brand')
          .or(orFilter)
        ;(products || []).forEach(p => {
          // 更新所有同名产品（不同渠道的条目）
          for (const key in productMap) {
            if (productMap[key].name === p.name) {
              if (p.category) productMap[key].category = p.category
              if (p.brand) productMap[key].brand = p.brand
            }
          }
        })
      }
    }

    rawData.value = Object.values(productMap)
  } catch (e) {
    console.error('加载销量数据失败:', e)
    toast('加载数据失败', 'error')
  } finally {
    loading.value = false
  }
}

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
