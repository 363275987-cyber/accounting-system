<template>
  <div class="p-4 md:p-6 space-y-6">
    <!-- 顶部标题 + 筛选 -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 电商销量</h1>
      <div class="flex items-center gap-2 flex-wrap">
        <button v-for="opt in dateOptions" :key="opt.key"
          @click="setDateRange(opt.key)"
          :class="activeRange === opt.key
            ? 'px-3 py-1.5 rounded-lg text-sm font-medium bg-green-500 text-white cursor-pointer'
            : 'px-3 py-1.5 rounded-lg text-sm text-gray-600 hover:bg-gray-100 cursor-pointer'">
          {{ opt.label }}
        </button>
        <span class="mx-1 text-gray-300">|</span>
        <input type="date" v-model="customStart" @change="applyCustomRange" class="px-2 py-1.5 border border-gray-200 rounded-lg text-sm" />
        <span class="text-gray-500">~</span>
        <input type="date" v-model="customEnd" @change="applyCustomRange" class="px-2 py-1.5 border border-gray-200 rounded-lg text-sm" />
        <button v-if="activeRange" @click="activeRange = ''; rangeStart = ''; rangeEnd = ''; loadData()" class="px-3 py-1.5 rounded-lg text-sm text-gray-500 hover:bg-gray-100 cursor-pointer">✕</button>
        <span class="text-xs text-gray-500 ml-1">{{ rangeLabel }}</span>
      </div>
    </div>

    <!-- 平台Tab + 店铺筛选 -->
    <div class="flex flex-col sm:flex-row sm:items-center gap-3">
      <div class="flex gap-1.5">
        <button v-for="pt in platformTabOptions" :key="pt.key"
          @click="activePlatformTab = pt.key"
          :class="activePlatformTab === pt.key
            ? 'px-3 py-1.5 rounded-lg text-sm font-medium bg-green-50 text-green-700 border border-green-300 cursor-pointer'
            : 'px-3 py-1.5 rounded-lg text-sm text-gray-500 bg-white border border-gray-200 hover:bg-gray-50 cursor-pointer'">
          {{ pt.label }}
        </button>
      </div>
      <select v-model="storeFilter" class="px-3 py-1.5 border border-gray-200 rounded-lg text-sm bg-white text-gray-700 cursor-pointer focus:outline-none focus:border-green-300 focus:ring-1 focus:ring-green-300">
        <option value="">全部店铺</option>
        <option v-for="s in storeList" :key="s" :value="s">{{ s }}</option>
      </select>
    </div>

    <!-- 汇总卡片 -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1.5"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 销售额</div>
        <div class="text-xl font-bold text-green-600">¥{{ formatNum(summary.sales) }}</div>
        <div class="text-xs text-gray-500 mt-0.5">{{ summary.orders }} 单</div>
      </div>
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1.5">↩️ 退款</div>
        <div class="text-xl font-bold text-red-500">¥{{ formatNum(summary.refund) }}</div>
        <div class="text-xs text-gray-500 mt-0.5">退款率 {{ summary.refundRate }}%</div>
      </div>
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1.5"><Icon name="trending-up" class="inline w-4 h-4 -mt-0.5 mr-1" /> 净营业额</div>
        <div class="text-xl font-bold text-blue-600">¥{{ formatNum(summary.net) }}</div>
        <div class="text-xs text-gray-500 mt-0.5">有效 {{ summary.effectiveOrders }} 单</div>
      </div>
    </div>

    <!-- 待结算资金（分店铺） -->
    <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
      <div class="text-xs text-gray-500 mb-3"><Icon name="shopping-bag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 待结算资金</div>
      <div v-if="pendingByStore.length" class="space-y-0">
        <div v-for="(item, idx) in pendingByStore" :key="item.name"
          :class="[
            'flex items-center justify-between py-2 px-1 text-sm rounded-lg',
            storeFilter && storeFilter === item.name ? 'bg-green-50 font-medium' : ''
          ]">
          <span :class="storeFilter && storeFilter === item.name ? 'text-green-700' : 'text-gray-700'">{{ item.name }}</span>
          <span :class="storeFilter && storeFilter === item.name ? 'text-green-700 font-bold' : 'text-gray-800 font-medium'">¥{{ formatNum(item.balance) }}</span>
        </div>
        <div class="border-t border-gray-200 mt-1 pt-2 px-1 flex items-center justify-between text-sm font-bold">
          <span class="text-gray-800">合计</span>
          <span class="text-green-600">¥{{ formatNum(totalPending) }}</span>
        </div>
      </div>
      <div v-else class="text-center text-gray-500 py-4 text-sm">暂无数据</div>
    </div>

    <!-- 日趋势折线图（全宽） -->
    <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-sm font-medium text-gray-700">日趋势</h3>
      </div>
      <div v-if="dailyData.length" style="height: 320px">
        <v-chart :option="trendOption" autoresize />
      </div>
      <div v-else class="text-center text-gray-500 py-16 text-sm">暂无数据</div>
    </div>

    <!-- 店铺明细表 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <div class="px-4 py-3 border-b border-gray-100">
        <h3 class="text-sm font-medium text-gray-700">店铺明细</h3>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-500 text-xs">
              <th class="px-4 py-2 text-left">日期</th>
              <th class="px-3 py-2 text-left">店铺</th>
              <th class="px-3 py-2 text-left">平台</th>
              <th class="px-3 py-2 text-right">订单数</th>
              <th class="px-3 py-2 text-right">有效单</th>
              <th class="px-3 py-2 text-right">销售额</th>
              <th class="px-3 py-2 text-right">退款</th>
              <th class="px-3 py-2 text-right">退款率</th>
              <th class="px-3 py-2 text-right">净营业额</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in filteredTableData" :key="row.order_date + row.account_id"
              :class="[
                'border-t border-gray-100 hover:bg-gray-50',
                storeFilter && storeFilter === row.store_name ? 'bg-green-50/50' : ''
              ]">
              <td class="px-4 py-2 text-gray-600 text-xs">{{ row.order_date }}</td>
              <td class="px-3 py-2 font-medium text-gray-800 text-xs">{{ row.store_name }}</td>
              <td class="px-3 py-2 text-gray-500 text-xs">{{ platformLabel(row.ecommerce_platform) }}</td>
              <td class="px-3 py-2 text-right">{{ row.order_count }}</td>
              <td class="px-3 py-2 text-right text-green-600">{{ row.effective_count }}</td>
              <td class="px-3 py-2 text-right text-green-600">{{ formatNum(row.sales_amount) }}</td>
              <td class="px-3 py-2 text-right text-red-400">{{ formatNum(row.refund_amount) }}</td>
              <td class="px-3 py-2 text-right text-orange-500">{{ row.sales_amount > 0 ? ((row.refund_amount / row.sales_amount) * 100).toFixed(1) + '%' : '-' }}</td>
              <td class="px-3 py-2 text-right font-medium text-green-600">{{ formatNum(row.net_income) }}</td>
            </tr>
            <tr v-if="!filteredTableData.length" class="text-center text-gray-500 py-8">
              <td colspan="9">暂无数据</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, defineAsyncComponent } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { PLATFORM_LABELS } from '../lib/utils'
import Icon from '../components/icons/Icons.vue'

// ⚠️ echarts + vue-echarts 异步加载(合计 ~430KB),渲染到图表时才下载
const VChart = defineAsyncComponent(async () => {
  const [{ use }, { CanvasRenderer }, { LineChart }, { GridComponent, TooltipComponent, LegendComponent }, VueEcharts] = await Promise.all([
    import('echarts/core'),
    import('echarts/renderers'),
    import('echarts/charts'),
    import('echarts/components'),
    import('vue-echarts'),
  ])
  use([CanvasRenderer, LineChart, GridComponent, TooltipComponent, LegendComponent])
  return VueEcharts.default || VueEcharts
})

const auth = useAuthStore()

// 状态
const dailyData = ref([])
const accountData = ref([])
const storeFilter = ref('')
const activePlatformTab = ref('all')
const rangeStart = ref('')
const rangeEnd = ref('')
const activeRange = ref('')
const customStart = ref('')
const customEnd = ref('')

// PLATFORM_LABELS 已从 utils.js 统一导入

const platformTabOptions = [
  { key: 'all', label: '全部平台' },
  { key: 'douyin', label: '抖音' },
  { key: 'kuaishou', label: '快手' },
  { key: 'shipinhao', label: '视频号' },
]

const dateOptions = [
  { key: 'today', label: '今日' },
  { key: '7days', label: '近7天' },
  { key: '30days', label: '近30天' },
  { key: 'month', label: '本月' },
]

// 日期计算
function setDateRange(key) {
  const today = new Date()
  const fmt = d => d.toISOString().split('T')[0]
  const dayMs = 86400000
  activeRange.value = key
  switch (key) {
    case 'today': rangeStart.value = rangeEnd.value = fmt(today); break
    case '7days': rangeStart.value = fmt(new Date(today.getTime() - 6 * dayMs)); rangeEnd.value = fmt(today); break
    case '30days': rangeStart.value = fmt(new Date(today.getTime() - 29 * dayMs)); rangeEnd.value = fmt(today); break
    case 'month':
      rangeStart.value = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`
      rangeEnd.value = fmt(today); break
  }
  loadData()
}

function applyCustomRange() {
  if (!customStart.value || !customEnd.value) return
  rangeStart.value = customStart.value
  rangeEnd.value = customEnd.value
  activeRange.value = 'custom'
  loadData()
}

const rangeLabel = computed(() => {
  if (!rangeStart.value) return ''
  return rangeStart.value === rangeEnd.value ? rangeStart.value : `${rangeStart.value} ~ ${rangeEnd.value}`
})

// 数据
const storeList = computed(() => [...new Set(dailyData.value.map(d => d.store_name))])

// 获取平台对应的key（从店铺名前缀推断或直接从数据取）
const platformForStore = (storeName) => {
  const found = dailyData.value.find(d => d.store_name === storeName && d.ecommerce_platform)
  return found?.ecommerce_platform || 'other'
}

const filteredData = computed(() => {
  let data = dailyData.value
  // 平台筛选
  if (activePlatformTab.value !== 'all') {
    data = data.filter(d => d.ecommerce_platform === activePlatformTab.value)
  }
  // 店铺筛选
  if (storeFilter.value) {
    data = data.filter(d => d.store_name === storeFilter.value)
  }
  return data
})

const filteredTableData = computed(() => {
  return [...filteredData.value].sort((a, b) => b.order_date.localeCompare(a.order_date) || a.store_name.localeCompare(b.store_name))
})

const summary = computed(() => {
  const d = filteredData.value
  const orders = d.reduce((s, r) => s + Number(r.order_count || 0), 0)
  const sales = d.reduce((s, r) => s + Number(r.sales_amount || 0), 0)
  const refund = d.reduce((s, r) => s + Number(r.refund_amount || 0), 0)
  const net = d.reduce((s, r) => s + Number(r.net_income || 0), 0)
  const effectiveOrders = d.reduce((s, r) => s + Number(r.effective_count || 0), 0)
  return {
    orders,
    sales,
    refund,
    net,
    refundRate: sales > 0 ? (refund / sales * 100).toFixed(1) : '0.0',
    effectiveOrders,
  }
})

// 待结算资金分店铺
const pendingByStore = computed(() => {
  let accounts = accountData.value || []

  // 平台筛选：从账户的平台字段过滤
  if (activePlatformTab.value !== 'all') {
    accounts = accounts.filter(a => a.ecommerce_platform === activePlatformTab.value)
  }

  // 构建 storeName: balance 列表
  const map = {}
  accounts.forEach(a => {
    const name = a.short_name || a.store_name || a.name || a.account_name || '未知'
    map[name] = (map[name] || 0) + Number(a.balance || 0)
  })

  return Object.entries(map)
    .map(([name, balance]) => ({ name, balance }))
    .sort((a, b) => b.balance - a.balance)
})

const totalPending = computed(() => {
  return pendingByStore.value.reduce((s, item) => s + item.balance, 0)
})

// ECharts options
const trendOption = computed(() => {
  // 按日期汇总（分平台）
  const dateMap = {}
  const netDateMap = {}
  filteredData.value.forEach(d => {
    if (!dateMap[d.order_date]) dateMap[d.order_date] = {}
    const p = PLATFORM_LABELS[d.ecommerce_platform] || d.ecommerce_platform
    dateMap[d.order_date][p] = (dateMap[d.order_date][p] || 0) + Number(d.sales_amount || 0)
    netDateMap[d.order_date] = (netDateMap[d.order_date] || 0) + Number(d.net_income || 0)
  })
  const dates = Object.keys(dateMap).sort()
  const platforms = [...new Set(filteredData.value.map(d => PLATFORM_LABELS[d.ecommerce_platform] || d.ecommerce_platform))]
  const series = platforms.map(p => ({
    name: p,
    type: 'line',
    smooth: true,
    symbol: 'circle',
    symbolSize: 4,
    data: dates.map(d => Math.round((dateMap[d]?.[p] || 0) * 100) / 100),
  }))

  // 净营业额汇总线
  series.push({
    name: '净营业额',
    type: 'line',
    smooth: true,
    symbol: 'circle',
    symbolSize: 5,
    lineStyle: { width: 3 },
    itemStyle: { color: '#f97316' },
    data: dates.map(d => Math.round((netDateMap[d] || 0) * 100) / 100),
  })

  return {
    tooltip: { trigger: 'axis', valueFormatter: v => '¥' + Number(v || 0).toLocaleString() },
    legend: { bottom: 0, textStyle: { fontSize: 11 } },
    grid: { left: 50, right: 20, top: 10, bottom: 40 },
    xAxis: { type: 'category', data: dates, axisLabel: { fontSize: 10, formatter: v => v.slice(5) } },
    yAxis: { type: 'value', axisLabel: { fontSize: 10, formatter: v => v >= 10000 ? (v / 10000).toFixed(1) + '万' : v } },
    series,
  }
})

// 工具
function formatNum(n) {
  return Number(n || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function platformLabel(key) {
  return PLATFORM_LABELS[key] || key || '未知'
}

// 加载数据
async function loadData() {
  if (!rangeStart.value) return

  // 查询电商订单（platform_type 非空）
  const { data: ordersRaw } = await supabase
    .from('orders')
    .select('id, amount, payment_amount, account_id, status, platform_type, platform_store, created_at')
    .is('deleted_at', null)
    .not('platform_type', 'is', null)
    .gte('created_at', rangeStart.value + 'T00:00:00')
    .lte('created_at', rangeEnd.value + 'T23:59:59')
  const orders = ordersRaw || []

  // 获取这些订单的已完成退款
  const orderIds = orders.map(o => o.id)
  let refundsMap = {}
  if (orderIds.length > 0) {
    // 分批查询退款（避免超出 URL 长度限制）
    const batchSize = 200
    for (let i = 0; i < orderIds.length; i += batchSize) {
      const batch = orderIds.slice(i, i + batchSize)
      const { data: refundsRaw } = await supabase
        .from('refunds')
        .select('order_id, refund_amount')
        .is('deleted_at', null)
        .in('order_id', batch)
        .eq('status', 'completed')
      if (refundsRaw) {
        refundsRaw.forEach(r => {
          refundsMap[r.order_id] = (refundsMap[r.order_id] || 0) + Number(r.refund_amount || 0)
        })
      }
    }
  }

  // 加载账户信息用于 store_name 映射
  const { data: accData } = await supabase
    .from('accounts')
    .select('id, short_name, ecommerce_platform, balance, status')
    .not('ecommerce_platform', 'is', null)
  const accountsAll = accData || []
  const accountMap = {}
  accountsAll.forEach(a => { accountMap[a.id] = a })

  // 客户端按 日期 + account_id + platform_type 聚合
  const aggMap = {}
  orders.forEach(o => {
    const orderDate = o.created_at ? o.created_at.split('T')[0] : ''
    if (!orderDate) return
    const key = `${orderDate}|${o.account_id || ''}|${o.platform_type}`
    if (!aggMap[key]) {
      const acc = accountMap[o.account_id] || {}
      aggMap[key] = {
        order_date: orderDate,
        account_id: o.account_id,
        store_name: o.platform_store || acc.short_name || '未知',
        ecommerce_platform: o.platform_type,
        order_count: 0,
        effective_count: 0,
        sales_amount: 0,
        refund_amount: 0,
        net_income: 0,
      }
    }
    const row = aggMap[key]
    const amt = Number(o.payment_amount || o.amount || 0)
    const refAmt = refundsMap[o.id] || 0
    row.order_count += 1
    row.sales_amount += amt
    row.refund_amount += refAmt
    row.net_income += amt - refAmt
    // 有效单：未被完全退款的订单
    if (refAmt < amt) {
      row.effective_count += 1
    }
  })

  dailyData.value = Object.values(aggMap)

  // 加载待结算资金（分店铺）
  accountData.value = accountsAll.filter(a => a.status === 'active')
}

onMounted(() => {
  if (auth.isLoggedIn) {
    setDateRange('7days')
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { setDateRange('7days'); unwatch() }
    })
  }
})
</script>
