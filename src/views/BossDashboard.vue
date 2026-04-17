<template>
  <div class="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 pb-24"
    @touchstart.passive="onTouchStart"
    @touchmove.passive="onTouchMove"
    @touchend.passive="onTouchEnd">

    <!-- 下拉刷新指示条 -->
    <div class="fixed top-0 left-0 right-0 z-30 flex justify-center overflow-hidden pointer-events-none"
      :style="{ height: pullDist + 'px', transition: pullAnimating ? 'height 0.25s ease' : 'none' }">
      <div class="flex items-center gap-2 text-xs text-blue-600 pt-4">
        <span v-if="refreshing" class="inline-block animate-spin">🔄</span>
        <span v-else :style="{ transform: `rotate(${pullDist >= 60 ? 180 : 0}deg)`, transition: 'transform 0.15s' }">↓</span>
        <span>{{ refreshing ? '刷新中…' : (pullDist >= 60 ? '松开立即刷新' : '下拉刷新') }}</span>
      </div>
    </div>

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

      <!-- 核心三指标:收入 / 支出 / 净利润(带同比/环比) -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="flex items-baseline justify-between mb-1">
          <div class="text-xs text-gray-500">{{ rangeLabel }} 净利润</div>
          <div v-if="prevLabel" class="text-[11px] text-gray-400">vs {{ prevLabel }}</div>
        </div>
        <div class="text-4xl font-bold"
          :class="profit >= 0 ? 'text-emerald-600' : 'text-red-500'">
          {{ profit >= 0 ? '+' : '' }}{{ formatMoney(profit) }}
        </div>
        <div v-if="profitDelta !== null" class="mt-1 text-xs flex items-center gap-1">
          <span :class="profitDeltaPct >= 0 ? 'text-emerald-600' : 'text-red-500'">
            {{ profitDeltaPct >= 0 ? '↑' : '↓' }} {{ formatDelta(profitDelta) }}
            <span v-if="profitDeltaPct !== Infinity && profitDeltaPct !== -Infinity">({{ (profitDeltaPct >= 0 ? '+' : '') + profitDeltaPct.toFixed(1) + '%' }})</span>
          </span>
        </div>
        <div class="mt-2 text-[11px] text-gray-400">收入 - 支出 - 退款 - 分红</div>

        <div class="grid grid-cols-2 gap-3 mt-4 pt-4 border-t border-gray-100">
          <div>
            <div class="text-[11px] text-gray-500 mb-1">收入</div>
            <div class="text-xl font-semibold text-emerald-600">+{{ formatMoney(summary.income_total) }}</div>
            <div class="text-[11px] mt-0.5">
              <span class="text-gray-400">{{ summary.orders_count }} 笔</span>
              <span v-if="incomeDeltaPct !== null" class="ml-1"
                :class="incomeDeltaPct >= 0 ? 'text-emerald-600' : 'text-red-500'">
                {{ incomeDeltaPct >= 0 ? '↑' : '↓' }}{{ Math.abs(incomeDeltaPct).toFixed(0) }}%
              </span>
            </div>
          </div>
          <div>
            <div class="text-[11px] text-gray-500 mb-1">支出</div>
            <div class="text-xl font-semibold text-red-500">-{{ formatMoney(summary.expense_total) }}</div>
            <div class="text-[11px] mt-0.5">
              <span class="text-gray-400">退款 {{ formatMoney(summary.refund_total) }}</span>
              <span v-if="expenseDeltaPct !== null" class="ml-1"
                :class="expenseDeltaPct <= 0 ? 'text-emerald-600' : 'text-red-500'">
                {{ expenseDeltaPct >= 0 ? '↑' : '↓' }}{{ Math.abs(expenseDeltaPct).toFixed(0) }}%
              </span>
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
              {{ cashFlow30Total >= 0 ? '+' : '' }}{{ formatMoney(cashFlow30Total) }}
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
              {{ formatMoney(g.total) }}
            </span>
          </div>
          <div class="flex items-center justify-between pt-3 mt-1 border-t-2 border-gray-200">
            <span class="text-sm font-medium text-gray-700">总计</span>
            <span class="text-lg font-bold"
              :class="allAccountsTotal >= 0 ? 'text-gray-800' : 'text-red-500'">
              {{ formatMoney(allAccountsTotal) }}
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
            <span class="font-semibold text-emerald-600">{{ formatMoney(s.sales) }}</span>
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
              {{ Number(e.amount) >= 0 ? '+' : '' }}{{ formatMoney(Math.abs(Number(e.amount))) }}
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

const TZ = '+08:00'
const pad = n => String(n).padStart(2, '0')
function getRangeIso() {
  const now = new Date()
  let fromStr
  if (activeRange.value === 'today') {
    fromStr = now.toISOString().slice(0, 10)
  } else if (activeRange.value === 'month') {
    fromStr = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-01`
  } else {
    fromStr = `${now.getFullYear()}-01-01`
  }
  const toStr = now.toISOString().slice(0, 10)
  return {
    from: new Date(fromStr + 'T00:00:00' + TZ).toISOString(),
    to:   new Date(toStr   + 'T23:59:59' + TZ).toISOString(),
  }
}
// 对比用上一个同等区间：
//   今日 → 昨日;   本月 → 上月同天数;   本年 → 去年同天数
function getPrevRangeIso() {
  const now = new Date()
  if (activeRange.value === 'today') {
    const y = new Date(now); y.setDate(y.getDate() - 1)
    const s = `${y.getFullYear()}-${pad(y.getMonth() + 1)}-${pad(y.getDate())}`
    return {
      from: new Date(s + 'T00:00:00' + TZ).toISOString(),
      to:   new Date(s + 'T23:59:59' + TZ).toISOString(),
    }
  }
  if (activeRange.value === 'month') {
    const d = now.getDate()
    const pm = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    const lastDay = new Date(pm.getFullYear(), pm.getMonth() + 1, 0).getDate()
    const dayEnd = Math.min(d, lastDay)
    const prefix = `${pm.getFullYear()}-${pad(pm.getMonth() + 1)}`
    return {
      from: new Date(`${prefix}-01T00:00:00${TZ}`).toISOString(),
      to:   new Date(`${prefix}-${pad(dayEnd)}T23:59:59${TZ}`).toISOString(),
    }
  }
  // year
  const py = now.getFullYear() - 1
  return {
    from: new Date(`${py}-01-01T00:00:00${TZ}`).toISOString(),
    to:   new Date(`${py}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T23:59:59${TZ}`).toISOString(),
  }
}
const prevLabel = computed(() => ({ today: '昨日', month: '上月同期', year: '去年同期' })[activeRange.value] || '')

function switchRange(key) {
  activeRange.value = key
  reloadRangeData()
}

// ========== 数据状态 ==========
const loading = ref(false)
const lastUpdate = ref(null)
const summary = ref({ income_total: 0, expense_total: 0, refund_total: 0, dividend_total: 0, orders_count: 0 })
const prevSummary = ref({ income_total: 0, expense_total: 0, refund_total: 0, dividend_total: 0, orders_count: 0 })
const topStores = ref([])
const cashFlowData = ref([])
const bigEvents = ref([])
const drift = ref([])

function calcProfit(s) {
  return Number(s.income_total || 0)
    - Number(s.expense_total || 0)
    - Number(s.refund_total || 0)
    - Number(s.dividend_total || 0)
}
const profit = computed(() => calcProfit(summary.value))
const prevProfit = computed(() => calcProfit(prevSummary.value))
function pctChange(cur, prev) {
  const c = Number(cur || 0), p = Number(prev || 0)
  if (Math.abs(p) < 0.001) return c === 0 ? null : (c > 0 ? Infinity : -Infinity)
  return (c - p) / Math.abs(p) * 100
}
const profitDelta = computed(() => prevProfit.value === 0 && profit.value === 0 ? null : profit.value - prevProfit.value)
const profitDeltaPct = computed(() => pctChange(profit.value, prevProfit.value))
const incomeDeltaPct = computed(() => pctChange(summary.value.income_total, prevSummary.value.income_total))
const expenseDeltaPct = computed(() => pctChange(summary.value.expense_total, prevSummary.value.expense_total))
function formatDelta(v) { return (v >= 0 ? '+' : '-') + formatMoney(Math.abs(v)) }

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
  const { from: pf, to: pt } = getPrevRangeIso()
  const [cur, prev] = await Promise.all([
    supabase.rpc('get_boss_summary', { p_from: from, p_to: to }),
    supabase.rpc('get_boss_summary', { p_from: pf, p_to: pt }),
  ])
  if (cur.error) throw cur.error
  if (prev.error) throw prev.error
  summary.value = cur.data || summary.value
  prevSummary.value = prev.data || prevSummary.value
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

// ========== 下拉刷新 ==========
const pullDist = ref(0)
const pullAnimating = ref(false)
const refreshing = ref(false)
let _startY = 0
let _pulling = false

function onTouchStart(e) {
  if (window.scrollY > 0) return
  _startY = e.touches[0].clientY
  _pulling = true
  pullAnimating.value = false
}
function onTouchMove(e) {
  if (!_pulling) return
  const dy = e.touches[0].clientY - _startY
  if (dy <= 0) { pullDist.value = 0; return }
  // 阻尼曲线：前 60px 线性，超过加阻尼
  pullDist.value = dy < 60 ? dy : 60 + (dy - 60) * 0.3
  if (pullDist.value > 100) pullDist.value = 100
}
async function onTouchEnd() {
  if (!_pulling) return
  _pulling = false
  pullAnimating.value = true
  if (pullDist.value >= 60 && !refreshing.value) {
    refreshing.value = true
    try { await reloadAll() } finally {
      refreshing.value = false
    }
  }
  pullDist.value = 0
}
</script>
