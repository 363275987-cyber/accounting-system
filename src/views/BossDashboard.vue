<template>
  <div class="dash-root"
    @touchstart.passive="onTouchStart"
    @touchmove.passive="onTouchMove"
    @touchend.passive="onTouchEnd">

    <!-- 下拉刷新指示 -->
    <div class="fixed top-0 left-0 right-0 z-30 flex justify-center overflow-hidden pointer-events-none"
      :style="{ height: pullDist + 'px', transition: pullAnimating ? 'height 0.25s ease' : 'none' }">
      <div class="flex items-center gap-2 text-xs text-blue-600/90 pt-4">
        <Icon :name="refreshing ? 'refresh' : 'arrow-down'" class="w-4 h-4"
          :class="[refreshing && 'animate-spin', !refreshing && pullDist >= 60 && 'rotate-180']"
          :style="!refreshing ? 'transition: transform 0.2s ease' : ''" />
        <span class="font-medium tracking-wide">
          {{ refreshing ? '刷新中' : (pullDist >= 60 ? '松开立即刷新' : '下拉刷新') }}
        </span>
      </div>
    </div>

    <!-- Header -->
    <header class="sticky top-0 z-20 bg-white/70 backdrop-blur-xl border-b border-slate-200/60 px-4 py-3">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white shadow-sm shadow-blue-500/30">
            <Icon name="sparkle" class="w-4 h-4" />
          </div>
          <h1 class="text-base font-semibold text-slate-800 tracking-tight">经营看板</h1>
        </div>
        <button @click="reloadAll" :disabled="loading" aria-label="刷新"
          class="w-9 h-9 rounded-full flex items-center justify-center text-slate-500 hover:text-blue-600 hover:bg-blue-50 disabled:opacity-40 transition cursor-pointer">
          <Icon name="refresh" class="w-4 h-4" :class="loading && 'animate-spin'" />
        </button>
      </div>
      <div class="flex gap-1 p-1 bg-slate-100/70 rounded-xl">
        <button v-for="r in ranges" :key="r.key"
          @click="switchRange(r.key)"
          :class="activeRange === r.key ? 'range-tab-active' : 'text-slate-500'"
          class="flex-1 px-3 py-1.5 text-sm rounded-lg transition-all cursor-pointer font-medium">
          {{ r.label }}
        </button>
      </div>
    </header>

    <div class="p-4 space-y-4">
      <!-- 漂移状态 -->
      <div v-if="drift.length > 0"
        class="stagger-card relative overflow-hidden rounded-2xl bg-gradient-to-br from-amber-50 to-orange-50 border border-amber-200/60 p-4 flex items-start gap-3 shadow-sm shadow-amber-500/10">
        <div class="relative">
          <div class="absolute inset-0 bg-amber-400 rounded-full blur-md opacity-30 animate-pulse"></div>
          <Icon name="alert-triangle" class="relative w-5 h-5 text-amber-600" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold text-amber-900">{{ drift.length }} 个账户余额对不齐</div>
          <div class="text-xs text-amber-700/80 mt-0.5 tabular-nums">
            总差额 {{ totalDrift >= 0 ? '+' : '' }}{{ formatMoney(totalDrift) }}
          </div>
        </div>
        <button @click="router.push('/balance')"
          class="text-xs px-3 py-1.5 bg-amber-500 text-white rounded-lg hover:bg-amber-600 active:scale-95 transition cursor-pointer shrink-0 font-medium">
          查看
        </button>
      </div>
      <div v-else class="stagger-card rounded-2xl bg-gradient-to-br from-emerald-50/80 to-teal-50/80 border border-emerald-200/50 p-3 flex items-center gap-3">
        <Icon name="shield-check" class="w-5 h-5 text-emerald-600 shrink-0" />
        <div class="text-sm text-emerald-700/90">所有账户余额对齐 · 数据健康</div>
      </div>

      <!-- 核心指标卡 -->
      <div class="stagger-card hero-card relative overflow-hidden rounded-3xl p-5 shadow-lg shadow-slate-900/5"
        style="animation-delay: 60ms">
        <div class="absolute top-0 right-0 w-48 h-48 bg-gradient-to-br from-blue-400/10 to-indigo-500/5 rounded-full blur-3xl pointer-events-none"></div>

        <div class="flex items-baseline justify-between mb-2 relative">
          <div class="flex items-center gap-1.5 text-xs text-slate-500">
            <Icon name="wallet" class="w-3.5 h-3.5" />
            <span>{{ rangeLabel }} 净利润</span>
          </div>
          <div v-if="prevLabel" class="text-[11px] text-slate-400">vs {{ prevLabel }}</div>
        </div>

        <div class="text-4xl font-bold tabular-nums tracking-tight transition-colors duration-300"
          :class="profit >= 0 ? 'text-emerald-600' : 'text-rose-500'">
          {{ profit >= 0 ? '+' : '' }}{{ formatMoney(animatedProfit) }}
        </div>

        <div v-if="profitDelta !== null" class="mt-2 flex items-center gap-1.5">
          <span class="inline-flex items-center gap-0.5 px-2 py-0.5 rounded-full text-[11px] font-medium tabular-nums"
            :class="profitDeltaPct >= 0
              ? 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200/60'
              : 'bg-rose-50 text-rose-700 ring-1 ring-rose-200/60'">
            <Icon :name="profitDeltaPct >= 0 ? 'arrow-up' : 'arrow-down'" class="w-3 h-3" />
            {{ formatDelta(profitDelta) }}
            <span v-if="profitDeltaPct !== Infinity && profitDeltaPct !== -Infinity">
              ({{ (profitDeltaPct >= 0 ? '+' : '') + profitDeltaPct.toFixed(1) + '%' }})
            </span>
          </span>
        </div>

        <div class="grid grid-cols-2 gap-4 mt-5 pt-4 border-t border-slate-100 relative">
          <div>
            <div class="flex items-center gap-1 text-[11px] text-slate-500 mb-1">
              <Icon name="trending-up" class="w-3 h-3 text-emerald-500" />
              <span>收入</span>
            </div>
            <div class="text-xl font-semibold text-emerald-600 tabular-nums">+{{ formatMoney(animatedIncome) }}</div>
            <div class="mt-1 flex items-center gap-1.5 text-[11px]">
              <span class="text-slate-400 tabular-nums">{{ summary.orders_count }} 笔</span>
              <span v-if="incomeDeltaPct !== null" class="inline-flex items-center tabular-nums"
                :class="incomeDeltaPct >= 0 ? 'text-emerald-600' : 'text-rose-500'">
                <Icon :name="incomeDeltaPct >= 0 ? 'arrow-up' : 'arrow-down'" class="w-2.5 h-2.5" />
                {{ Math.abs(incomeDeltaPct).toFixed(0) }}%
              </span>
            </div>
          </div>
          <div>
            <div class="flex items-center gap-1 text-[11px] text-slate-500 mb-1">
              <Icon name="trending-down" class="w-3 h-3 text-rose-500" />
              <span>支出</span>
            </div>
            <div class="text-xl font-semibold text-rose-500 tabular-nums">-{{ formatMoney(animatedExpense) }}</div>
            <div class="mt-1 flex items-center gap-1.5 text-[11px]">
              <span class="text-slate-400 tabular-nums">退款 {{ formatMoney(summary.refund_total) }}</span>
              <span v-if="expenseDeltaPct !== null" class="inline-flex items-center tabular-nums"
                :class="expenseDeltaPct <= 0 ? 'text-emerald-600' : 'text-rose-500'">
                <Icon :name="expenseDeltaPct >= 0 ? 'arrow-up' : 'arrow-down'" class="w-2.5 h-2.5" />
                {{ Math.abs(expenseDeltaPct).toFixed(0) }}%
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- 现金流图 -->
      <div class="stagger-card rounded-3xl bg-white/90 backdrop-blur border border-slate-200/60 p-4 shadow-sm shadow-slate-900/5"
        style="animation-delay: 120ms">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-1.5">
            <Icon name="line-chart" class="w-4 h-4 text-indigo-500" />
            <h2 class="text-sm font-semibold text-slate-700">近 30 天现金流</h2>
          </div>
          <div class="text-xs text-slate-500">
            净流入 <span class="font-semibold tabular-nums"
              :class="cashFlow30Total >= 0 ? 'text-emerald-600' : 'text-rose-500'">
              {{ cashFlow30Total >= 0 ? '+' : '' }}{{ formatMoney(cashFlow30Total) }}
            </span>
          </div>
        </div>
        <div class="h-56">
          <component :is="VChart" v-if="cashFlowData.length > 0" :option="cashFlowOption" autoresize />
          <div v-else class="h-full flex items-center justify-center text-slate-300 text-sm">暂无数据</div>
        </div>
      </div>

      <!-- 账户余额合计 -->
      <div class="stagger-card rounded-3xl bg-white/90 backdrop-blur border border-slate-200/60 p-5 shadow-sm shadow-slate-900/5"
        style="animation-delay: 180ms">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-semibold text-slate-700">账户余额合计</h2>
          <span class="text-[11px] text-slate-400 tabular-nums">当前 · {{ totalAccountsCount }} 个账户</span>
        </div>
        <div class="space-y-3">
          <div v-for="g in accountGroups" :key="g.key"
            class="group flex items-center gap-3 py-1">
            <div class="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
              :class="g.bg">
              <Icon :name="g.icon" class="w-4 h-4" :class="g.fg" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm font-medium text-slate-700">{{ g.label }}</div>
              <div class="text-[11px] text-slate-400 tabular-nums">{{ g.count }} 个账户</div>
            </div>
            <span class="font-semibold tabular-nums"
              :class="g.total >= 0 ? 'text-slate-800' : 'text-rose-500'">
              {{ formatMoney(g.total) }}
            </span>
          </div>
          <div class="flex items-center justify-between pt-3 mt-1 border-t-2 border-dashed border-slate-200/80">
            <span class="text-sm font-semibold text-slate-700">总计</span>
            <span class="text-lg font-bold tabular-nums"
              :class="allAccountsTotal >= 0 ? 'text-slate-900' : 'text-rose-500'">
              {{ formatMoney(allAccountsTotal) }}
            </span>
          </div>
        </div>
      </div>

      <!-- 店铺销售 Top 5 -->
      <div class="stagger-card rounded-3xl bg-white/90 backdrop-blur border border-slate-200/60 p-5 shadow-sm shadow-slate-900/5"
        style="animation-delay: 240ms">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center gap-1.5">
            <Icon name="trophy" class="w-4 h-4 text-amber-500" />
            <h2 class="text-sm font-semibold text-slate-700">店铺销售 Top 5</h2>
          </div>
          <span class="text-[11px] text-slate-400">{{ rangeLabel }}</span>
        </div>
        <div v-if="topStores.length === 0" class="text-slate-300 text-sm text-center py-6">暂无销售</div>
        <div v-else class="space-y-3">
          <div v-for="(s, i) in topStores" :key="s.account_id"
            class="flex items-center gap-3 py-0.5 transition active:scale-[0.99]">
            <div class="w-7 h-7 rounded-lg flex items-center justify-center text-xs font-bold shrink-0 shadow-sm"
              :class="rankStyle(i)">
              {{ i + 1 }}
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm font-medium text-slate-800 truncate">{{ s.short_name }}</div>
              <div class="text-[11px] text-slate-400 tabular-nums">{{ platformLabel(s.platform) }} · {{ s.orders_count }} 笔</div>
            </div>
            <span class="font-semibold text-emerald-600 tabular-nums">{{ formatMoney(s.sales) }}</span>
          </div>
        </div>
      </div>

      <!-- 近期大额动态 -->
      <div class="stagger-card rounded-3xl bg-white/90 backdrop-blur border border-slate-200/60 p-5 shadow-sm shadow-slate-900/5"
        style="animation-delay: 300ms">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-slate-700">近期大额动态</h2>
          <span class="text-[11px] text-slate-400">阈值 ¥1000</span>
        </div>
        <div v-if="bigEvents.length === 0" class="text-slate-300 text-sm text-center py-6">暂无大额记录</div>
        <div v-else class="space-y-3">
          <div v-for="(e, i) in bigEvents" :key="i"
            class="flex items-start gap-3">
            <div class="w-7 h-7 rounded-full flex items-center justify-center shrink-0 mt-0.5"
              :class="e.kind === 'income' ? 'bg-emerald-50 text-emerald-600 ring-1 ring-emerald-200/60' : 'bg-rose-50 text-rose-600 ring-1 ring-rose-200/60'">
              <Icon :name="e.kind === 'income' ? 'plus' : 'minus'" class="w-3 h-3" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm text-slate-800 truncate">{{ e.label }}</div>
              <div class="text-[11px] text-slate-400 mt-0.5 tabular-nums">
                {{ formatDate(e.event_at) }}<span v-if="e.account_name"> · {{ e.account_name }}</span>
              </div>
            </div>
            <span class="text-sm font-semibold shrink-0 tabular-nums"
              :class="e.kind === 'income' ? 'text-emerald-600' : 'text-rose-500'">
              {{ Number(e.amount) >= 0 ? '+' : '' }}{{ formatMoney(Math.abs(Number(e.amount))) }}
            </span>
          </div>
        </div>
      </div>

      <div class="text-center text-[11px] text-slate-400 pt-2 tabular-nums">
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
import { useCountUp } from '../composables/useCountUp'
import Icon from '../components/icons/Icons.vue'

const router = useRouter()
const accountStore = useAccountStore()

// ========== 异步加载 echarts ==========
const VChart = defineAsyncComponent(async () => {
  const [{ use }, { CanvasRenderer }, { LineChart, BarChart }, { GridComponent, TooltipComponent, MarkLineComponent }, VueEcharts] = await Promise.all([
    import('echarts/core'),
    import('echarts/renderers'),
    import('echarts/charts'),
    import('echarts/components'),
    import('vue-echarts'),
  ])
  use([CanvasRenderer, LineChart, BarChart, GridComponent, TooltipComponent, MarkLineComponent])
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
  return Number(s.income_total || 0) - Number(s.expense_total || 0)
    - Number(s.refund_total || 0) - Number(s.dividend_total || 0)
}
const profit = computed(() => calcProfit(summary.value))
const prevProfit = computed(() => calcProfit(prevSummary.value))

// 数字动画(ease-out)
const animatedProfit = useCountUp(profit)
const animatedIncome = useCountUp(() => Number(summary.value.income_total || 0))
const animatedExpense = useCountUp(() => Number(summary.value.expense_total || 0))

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

const cashFlow30Total = computed(() => cashFlowData.value.reduce((s, d) => s + Number(d.net || 0), 0))

const cashFlowOption = computed(() => ({
  grid: { top: 15, right: 10, bottom: 28, left: 48 },
  tooltip: {
    trigger: 'axis',
    backgroundColor: 'rgba(15,23,42,0.92)',
    borderColor: 'rgba(15,23,42,0.92)',
    textStyle: { color: '#fff', fontSize: 11 },
    padding: [8, 12],
    extraCssText: 'border-radius:10px; box-shadow:0 8px 24px rgba(0,0,0,.15);',
    formatter: (p) => {
      const v = p[0]?.value ?? 0
      return `<div style="font-size:10px;opacity:.7;margin-bottom:2px">${p[0]?.axisValueLabel}</div>
              <div style="font-variant-numeric:tabular-nums">净流入 ${v >= 0 ? '+' : ''}${formatMoney(v)}</div>`
    },
    axisPointer: { type: 'line', lineStyle: { color: 'rgba(99,102,241,0.4)', type: 'dashed' } },
  },
  xAxis: {
    type: 'category',
    boundaryGap: false,
    data: cashFlowData.value.map(d => String(d.flow_date).slice(5)),
    axisLabel: { fontSize: 10, color: '#94a3b8', interval: 'auto' },
    axisLine: { lineStyle: { color: '#e2e8f0' } },
    axisTick: { show: false },
  },
  yAxis: {
    type: 'value',
    axisLabel: {
      fontSize: 10,
      color: '#94a3b8',
      formatter: v => v >= 1000 ? (v / 1000).toFixed(0) + 'k' : (v <= -1000 ? (v / 1000).toFixed(0) + 'k' : v),
    },
    splitLine: { lineStyle: { color: '#f1f5f9' } },
    axisLine: { show: false },
    axisTick: { show: false },
  },
  series: [{
    type: 'line',
    smooth: true,
    symbol: 'circle',
    symbolSize: 0,
    showSymbol: false,
    emphasis: { focus: 'series', scale: 1.4 },
    data: cashFlowData.value.map(d => Number(d.net || 0)),
    lineStyle: {
      width: 2.5,
      color: {
        type: 'linear', x: 0, y: 0, x2: 1, y2: 0,
        colorStops: [
          { offset: 0, color: '#6366f1' },
          { offset: 1, color: '#3b82f6' },
        ],
      },
      shadowColor: 'rgba(99,102,241,0.3)',
      shadowBlur: 10,
      shadowOffsetY: 6,
    },
    itemStyle: { color: '#6366f1', borderColor: '#fff', borderWidth: 2 },
    areaStyle: {
      color: {
        type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
        colorStops: [
          { offset: 0, color: 'rgba(99,102,241,0.25)' },
          { offset: 1, color: 'rgba(99,102,241,0)' },
        ],
      },
    },
  }],
}))

const totalDrift = computed(() => drift.value.reduce((s, d) => s + Number(d.diff || 0), 0))

// 账户分组(带图标 + 配色)
const accountGroups = computed(() => {
  const groups = [
    { key: 'personal', label: '个人账户', icon: 'user', bg: 'bg-blue-50', fg: 'text-blue-600',
      match: c => c === 'personal' || c === 'cash' || c === 'bank' || !c, total: 0, count: 0 },
    { key: 'company',  label: '企业账户', icon: 'building', bg: 'bg-indigo-50', fg: 'text-indigo-600',
      match: c => c === 'company', total: 0, count: 0 },
    { key: 'ecommerce', label: '店铺账户', icon: 'shopping-bag', bg: 'bg-emerald-50', fg: 'text-emerald-600',
      match: c => c === 'ecommerce', total: 0, count: 0 },
  ]
  for (const a of accountStore.accounts) {
    if (a.status === 'deleted') continue
    const g = groups.find(gg => gg.match(a.category))
    if (g) { g.total += Number(a.balance || 0); g.count++ }
  }
  return groups.filter(g => g.count > 0)
})
const totalAccountsCount = computed(() => accountGroups.value.reduce((s, g) => s + g.count, 0))
const allAccountsTotal = computed(() => accountGroups.value.reduce((s, g) => s + g.total, 0))

function rankStyle(i) {
  return [
    'bg-gradient-to-br from-amber-400 to-yellow-500 text-white shadow-amber-500/30',
    'bg-gradient-to-br from-slate-300 to-slate-400 text-white shadow-slate-400/30',
    'bg-gradient-to-br from-orange-400 to-amber-600 text-white shadow-orange-500/30',
  ][i] || 'bg-slate-100 text-slate-500'
}

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
  } catch (_) { drift.value = [] }
}

async function reloadRangeData() {
  loading.value = true
  try { await Promise.all([loadSummary(), loadTopStores()]) }
  catch (e) { console.error('[boss] range data failed:', e) }
  finally { loading.value = false }
}

async function reloadAll() {
  loading.value = true
  try {
    await Promise.all([
      accountStore.fetchAccounts(),
      loadSummary(), loadTopStores(),
      loadCashFlow(), loadBigEvents(), loadDrift(),
    ])
    lastUpdate.value = new Date().toISOString()
  } catch (e) { console.error('[boss] reload failed:', e) }
  finally { loading.value = false }
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
  pullDist.value = dy < 60 ? dy : 60 + (dy - 60) * 0.3
  if (pullDist.value > 100) pullDist.value = 100
}
async function onTouchEnd() {
  if (!_pulling) return
  _pulling = false
  pullAnimating.value = true
  if (pullDist.value >= 60 && !refreshing.value) {
    refreshing.value = true
    try { await reloadAll() } finally { refreshing.value = false }
  }
  pullDist.value = 0
}
</script>

<style scoped>
.dash-root {
  min-height: 100vh;
  padding-bottom: 6rem;
  background:
    radial-gradient(1200px 400px at 0% 0%, rgba(99,102,241,0.08), transparent 60%),
    radial-gradient(800px 300px at 100% 0%, rgba(16,185,129,0.06), transparent 60%),
    linear-gradient(180deg, #f8fafc 0%, #eef2ff 100%);
}

.hero-card {
  background:
    linear-gradient(135deg, rgba(255,255,255,0.95), rgba(255,255,255,0.85)),
    linear-gradient(135deg, #fff, #fff);
  border: 1px solid rgba(148,163,184,0.18);
  box-shadow:
    0 1px 0 rgba(255,255,255,0.6) inset,
    0 10px 30px -12px rgba(15,23,42,0.12);
}

.range-tab-active {
  background: linear-gradient(135deg, #2563eb, #4f46e5);
  color: #fff;
  box-shadow: 0 2px 10px -2px rgba(79,70,229,0.4);
}

.tabular-nums { font-variant-numeric: tabular-nums; }

/* 卡片进场动画(错落) */
.stagger-card {
  animation: slideUp 0.5s cubic-bezier(0.22, 1, 0.36, 1) both;
}
@keyframes slideUp {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}

/* 数字字体微调:更像 SF Pro */
.dash-root { font-feature-settings: 'tnum' 1, 'cv11' 1; }
</style>
