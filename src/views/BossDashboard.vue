<template>
  <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 pb-24">
    <!-- Header -->
    <div class="sticky top-0 z-20 bg-white/80 backdrop-blur border-b border-gray-100 px-4 py-3">
      <div class="flex items-center justify-between mb-2">
        <h1 class="text-lg font-bold text-gray-800">📊 经营看板</h1>
        <button @click="reloadAll" :disabled="loading"
          class="text-gray-500 hover:text-blue-600 disabled:opacity-40 cursor-pointer text-sm">
          <span class="inline-block" :class="{ 'animate-spin': loading }">🔄</span>
        </button>
      </div>
      <div class="flex gap-1">
        <button v-for="r in ranges" :key="r.key"
          @click="switchRange(r.key)"
          :class="activeRange === r.key
            ? 'bg-blue-600 text-white border-blue-600'
            : 'bg-white text-gray-600 border-gray-200'"
          class="flex-1 px-3 py-2 text-sm rounded-lg border transition cursor-pointer">
          {{ r.label }}
        </button>
      </div>
    </div>

    <div class="p-4 space-y-4">
      <!-- 漂移预警 -->
      <div v-if="drift.length > 0"
        class="bg-amber-50 border border-amber-300 rounded-xl p-3 flex items-start gap-3">
        <div class="text-amber-500 text-xl">⚠️</div>
        <div class="flex-1">
          <div class="text-sm font-medium text-amber-800">{{ drift.length }} 个账户余额对不齐</div>
          <div class="text-xs text-amber-700 mt-0.5">
            总差额 {{ totalDrift >= 0 ? '+' : '' }}{{ formatMoney(totalDrift) }}
          </div>
        </div>
        <button @click="router.push('/balance')"
          class="text-xs px-3 py-1.5 bg-amber-500 text-white rounded-lg cursor-pointer">查看</button>
      </div>
      <div v-else
        class="bg-emerald-50 border border-emerald-200 rounded-xl p-3 flex items-center gap-3">
        <div class="text-emerald-500 text-xl">✅</div>
        <div class="flex-1 text-sm text-emerald-700">所有账户余额对齐,数据健康</div>
      </div>

      <!-- 核心三指标:收入 / 支出 / 净利润 -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="text-xs text-gray-500 mb-1">{{ rangeLabel }} 净利润</div>
        <div class="text-4xl font-bold"
          :class="profit >= 0 ? 'text-emerald-600' : 'text-red-500'">
          {{ profit >= 0 ? '+' : '' }}¥{{ formatMoney(profit) }}
        </div>
        <div class="mt-2 text-xs text-gray-500">
          收入 - 支出 - 退款 - 分红
        </div>
        <div class="grid grid-cols-2 gap-3 mt-4 pt-4 border-t border-gray-100">
          <div>
            <div class="text-[11px] text-gray-500 mb-1">收入</div>
            <div class="text-xl font-semibold text-emerald-600">+{{ formatMoney(summary.income_total) }}</div>
            <div class="text-[11px] text-gray-400 mt-0.5">{{ summary.orders_count }} 笔订单</div>
          </div>
          <div>
            <div class="text-[11px] text-gray-500 mb-1">支出</div>
            <div class="text-xl font-semibold text-red-500">-{{ formatMoney(summary.expense_total) }}</div>
            <div class="text-[11px] text-gray-400 mt-0.5">
              退款 ¥{{ formatMoney(summary.refund_total) }}<span v-if="Number(summary.dividend_total) > 0"> · 分红 ¥{{ formatMoney(summary.dividend_total) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 现金流图 30 日 -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">近 30 天现金流</h2>
          <div class="text-xs text-gray-500">
            净流入 <span :class="cashFlow30Total >= 0 ? 'text-emerald-600 font-medium' : 'text-red-500 font-medium'">
              {{ cashFlow30Total >= 0 ? '+' : '' }}¥{{ formatMoney(cashFlow30Total) }}
            </span>
          </div>
        </div>
        <div class="h-56">
          <component :is="VChart" v-if="cashFlowData.length > 0" :option="cashFlowOption" autoresize />
          <div v-else class="h-full flex items-center justify-center text-gray-400 text-sm">暂无数据</div>
        </div>
      </div>

      <!-- 账户余额合计 -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">账户余额合计</h2>
          <span class="text-xs text-gray-500">当前 · {{ totalAccountsCount }} 个账户</span>
        </div>
        <div class="space-y-2">
          <div v-for="g in accountGroups" :key="g.key"
            class="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
            <div class="flex items-center gap-2">
              <span class="text-lg">{{ g.icon }}</span>
              <span class="text-sm text-gray-700">{{ g.label }}</span>
              <span class="text-[11px] text-gray-400">{{ g.count }} 个</span>
            </div>
            <span class="font-semibold" :class="g.total >= 0 ? 'text-gray-800' : 'text-red-500'">
              ¥{{ formatMoney(g.total) }}
            </span>
          </div>
          <div class="flex items-center justify-between pt-3 mt-1 border-t-2 border-gray-200">
            <span class="text-sm font-medium text-gray-700">总计</span>
            <span class="text-lg font-bold"
              :class="allAccountsTotal >= 0 ? 'text-gray-800' : 'text-red-500'">
              ¥{{ formatMoney(allAccountsTotal) }}
            </span>
          </div>
        </div>
      </div>

      <!-- 店铺销售 Top 5 -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">店铺销售 Top 5</h2>
          <span class="text-xs text-gray-500">{{ rangeLabel }}</span>
        </div>
        <div v-if="topStores.length === 0" class="text-gray-400 text-sm text-center py-4">暂无销售</div>
        <div v-else class="space-y-2">
          <div v-for="(s, i) in topStores" :key="s.account_id"
            class="flex items-center gap-3 py-2 border-b border-gray-50 last:border-0">
            <div class="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
              :class="i === 0 ? 'bg-yellow-100 text-yellow-700' :
                      i === 1 ? 'bg-gray-200 text-gray-700' :
                      i === 2 ? 'bg-orange-100 text-orange-700' : 'bg-gray-50 text-gray-400'">
              {{ i + 1 }}
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm font-medium text-gray-800 truncate">{{ s.short_name }}</div>
              <div class="text-[11px] text-gray-400">{{ platformLabel(s.platform) }} · {{ s.orders_count }} 笔</div>
            </div>
            <span class="font-semibold text-emerald-600">¥{{ formatMoney(s.sales) }}</span>
          </div>
        </div>
      </div>

      <!-- 近期大额动态 -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">近期大额动态</h2>
          <span class="text-xs text-gray-500">≥ ¥1000</span>
        </div>
        <div v-if="bigEvents.length === 0" class="text-gray-400 text-sm text-center py-4">暂无大额记录</div>
        <div v-else class="space-y-3">
          <div v-for="(e, i) in bigEvents" :key="i"
            class="flex items-start gap-3">
            <div class="w-2 h-2 mt-1.5 rounded-full shrink-0"
              :class="e.kind === 'income' ? 'bg-emerald-400' : 'bg-red-400'"></div>
            <div class="flex-1 min-w-0">
              <div class="text-sm text-gray-800 truncate">{{ e.label }}</div>
              <div class="text-[11px] text-gray-400 mt-0.5">
                {{ formatDate(e.event_at) }}
                <span v-if="e.account_name"> · {{ e.account_name }}</span>
              </div>
            </div>
            <span class="text-sm font-semibold shrink-0"
              :class="e.kind === 'income' ? 'text-emerald-600' : 'text-red-500'">
              {{ Number(e.amount) >= 0 ? '+' : '' }}¥{{ formatMoney(Math.abs(Number(e.amount))) }}
            </span>
          </div>
        </div>
      </div>

      <div class="text-center text-[11px] text-gray-400 pt-2">
        数据更新于 {{ lastUpdate ? formatDate(lastUpdate) : '—' }}
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineAsyncComponent } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAccountStore } from '../stores/accounts'
import { formatMoney, formatDate, PLATFORM_LABELS } from '../lib/utils'

const router = useRouter()
const accountStore = useAccountStore()

// ========== 异步加载 echarts ==========
const VChart = defineAsyncComponent(async () => {
  const [{ use }, { CanvasRenderer }, { LineChart, BarChart }, { GridComponent, TooltipComponent }, VueEcharts] = await Promise.all([
    import('echarts/core'),
    import('echarts/renderers'),
    import('echarts/charts'),
    import('echarts/components'),
    import('vue-echarts'),
  ])
  use([CanvasRenderer, LineChart, BarChart, GridComponent, TooltipComponent])
  return VueEcharts.default || VueEcharts
})

// ========== 时段切换 ==========
const ranges = [
  { key: 'today', label: '今日' },
  { key: 'month', label: '本月' },
  { key: 'year', label: '本年' },
]
const activeRange = ref('month')
const rangeLabel = computed(() => ranges.find(r => r.key === activeRange.value)?.label || '')

function getRangeIso() {
  const now = new Date()
  const tz = '+08:00'
  let fromStr
  if (activeRange.value === 'today') {
    fromStr = now.toISOString().slice(0, 10)
  } else if (activeRange.value === 'month') {
    fromStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
  } else {
    fromStr = `${now.getFullYear()}-01-01`
  }
  const toStr = now.toISOString().slice(0, 10)
  return {
    from: new Date(fromStr + 'T00:00:00' + tz).toISOString(),
    to:   new Date(toStr   + 'T23:59:59' + tz).toISOString(),
  }
}

function switchRange(key) {
  activeRange.value = key
  reloadRangeData()
}

// ========== 数据状态 ==========
const loading = ref(false)
const lastUpdate = ref(null)
const summary = ref({ income_total: 0, expense_total: 0, refund_total: 0, dividend_total: 0, orders_count: 0 })
const topStores = ref([])
const cashFlowData = ref([])
const bigEvents = ref([])
const drift = ref([])

const profit = computed(() =>
  Number(summary.value.income_total || 0)
  - Number(summary.value.expense_total || 0)
  - Number(summary.value.refund_total || 0)
  - Number(summary.value.dividend_total || 0)
)

const cashFlow30Total = computed(() =>
  cashFlowData.value.reduce((s, d) => s + Number(d.net || 0), 0)
)

const cashFlowOption = computed(() => ({
  grid: { top: 20, right: 15, bottom: 30, left: 50 },
  tooltip: { trigger: 'axis' },
  xAxis: {
    type: 'category',
    data: cashFlowData.value.map(d => String(d.flow_date).slice(5)),
    axisLabel: { fontSize: 10 },
  },
  yAxis: { type: 'value', axisLabel: { fontSize: 10, formatter: v => v >= 1000 ? (v/1000).toFixed(0) + 'k' : v } },
  series: [{
    type: 'line',
    smooth: true,
    symbol: 'circle',
    symbolSize: 4,
    data: cashFlowData.value.map(d => Number(d.net || 0)),
    itemStyle: { color: '#3b82f6' },
    areaStyle: { color: 'rgba(59,130,246,0.1)' },
    lineStyle: { width: 2 },
  }],
}))

const totalDrift = computed(() => drift.value.reduce((s, d) => s + Number(d.diff || 0), 0))

// ========== 账户分组 ==========
const accountGroups = computed(() => {
  const groups = [
    { key: 'personal', label: '个人账户', icon: '👤', match: c => c === 'personal' || c === 'cash' || c === 'bank' || !c, total: 0, count: 0 },
    { key: 'company',  label: '企业账户', icon: '🏢', match: c => c === 'company', total: 0, count: 0 },
    { key: 'ecommerce', label: '店铺账户', icon: '🛒', match: c => c === 'ecommerce', total: 0, count: 0 },
  ]
  for (const a of accountStore.accounts) {
    if (a.status === 'deleted') continue
    const g = groups.find(gg => gg.match(a.category))
    if (g) {
      g.total += Number(a.balance || 0)
      g.count++
    }
  }
  return groups.filter(g => g.count > 0)
})
const totalAccountsCount = computed(() => accountGroups.value.reduce((s, g) => s + g.count, 0))
const allAccountsTotal = computed(() => accountGroups.value.reduce((s, g) => s + g.total, 0))

function platformLabel(k) { return PLATFORM_LABELS[k] || k || '—' }

// ========== 数据加载 ==========
async function loadSummary() {
  const { from, to } = getRangeIso()
  const { data, error } = await supabase.rpc('get_boss_summary', { p_from: from, p_to: to })
  if (error) throw error
  summary.value = data || summary.value
}

async function loadTopStores() {
  const { from, to } = getRangeIso()
  const { data, error } = await supabase.rpc('get_top_stores', { p_from: from, p_to: to, p_limit: 5 })
  if (error) throw error
  topStores.value = data || []
}

async function loadCashFlow() {
  const { data, error } = await supabase.rpc('get_cash_flow_daily', { p_days: 30 })
  if (error) throw error
  cashFlowData.value = data || []
}

async function loadBigEvents() {
  const { data, error } = await supabase.rpc('get_recent_big_events', { p_threshold: 1000, p_limit: 10 })
  if (error) throw error
  bigEvents.value = data || []
}

async function loadDrift() {
  try {
    const { data, error } = await supabase.rpc('check_balance_drift')
    if (error) throw error
    drift.value = data || []
  } catch (_) {
    drift.value = []
  }
}

async function reloadRangeData() {
  loading.value = true
  try {
    await Promise.all([loadSummary(), loadTopStores()])
  } catch (e) {
    console.error('[boss] range data failed:', e)
  } finally {
    loading.value = false
  }
}

async function reloadAll() {
  loading.value = true
  try {
    await Promise.all([
      accountStore.fetchAccounts(),
      loadSummary(),
      loadTopStores(),
      loadCashFlow(),
      loadBigEvents(),
      loadDrift(),
    ])
    lastUpdate.value = new Date().toISOString()
  } catch (e) {
    console.error('[boss] reload failed:', e)
  } finally {
    loading.value = false
  }
}

onMounted(reloadAll)
</script>
