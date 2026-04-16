<template>
  <div class="max-w-5xl mx-auto pb-20 bg-gray-50 min-h-screen">
    <!-- 数据库连接错误提示 -->
    <div v-if="dbError" class="bg-orange-50 border border-orange-200 rounded-2xl p-4 mb-4 text-sm text-orange-700">
      ⚠️ {{ dbError }}
    </div>

    <!-- 非财务人员提示 -->
    <div v-if="!authStore.isFinance" class="text-center py-20 text-gray-500">
      <div class="text-5xl mb-3">🔒</div>
      <div class="text-sm">收支总览仅对管理员和财务人员开放</div>
    </div>

    <template v-if="authStore.isFinance">
      <!-- 页面标题 -->
      <h1 class="text-xl font-bold text-gray-800 mb-4 pt-2">📊 收支总览</h1>

      <!-- ========== 顶部3卡片 ========== -->
      <div class="grid grid-cols-3 gap-3 mb-4">
        <!-- 今日销售额 -->
        <div class="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm">
          <div class="text-xs text-gray-500 mb-1">💰 今日销售额</div>
          <div v-if="loading" class="h-8 w-24 bg-gray-100 rounded-lg animate-pulse"></div>
          <div v-else class="text-2xl font-bold text-gray-800">
            {{ todayStats.todaySales !== null ? formatMoney(todayStats.todaySales) : '--' }}
          </div>
          <div class="text-xs text-gray-500 mt-1">私域+电商合计</div>
        </div>

        <!-- 今日订单数 -->
        <div class="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm">
          <div class="text-xs text-gray-500 mb-1">📦 今日订单数</div>
          <div v-if="loading" class="h-8 w-24 bg-gray-100 rounded-lg animate-pulse"></div>
          <div v-else class="text-2xl font-bold text-gray-800">
            {{ todayStats.todayOrders !== null ? todayStats.todayOrders + ' 笔' : '--' }}
          </div>
          <div class="text-xs text-gray-500 mt-1">私域+电商合计</div>
        </div>

        <!-- 本月利润 -->
        <div class="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm">
          <div class="text-xs text-gray-500 mb-1">📈 本月利润</div>
          <div v-if="loading" class="h-8 w-24 bg-gray-100 rounded-lg animate-pulse"></div>
          <div v-else class="text-2xl font-bold" :class="(stats.profit || 0) >= 0 ? 'text-green-500' : 'text-red-500'">
            {{ stats.profit !== null ? formatMoney(stats.profit) : '--' }}
          </div>
          <div class="text-xs text-gray-500 mt-1">私域+电商提现+其他收入 - 支出</div>
        </div>
      </div>

      <!-- ========== 下方两栏 ========== -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <!-- 最近订单 -->
        <div class="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold text-gray-800 text-sm">最近订单</h2>
            <router-link to="/orders" class="text-xs text-blue-500">查看全部 →</router-link>
          </div>
          <div v-if="loading" class="space-y-3">
            <div v-for="i in 5" :key="i" class="flex justify-between">
              <div class="flex-1 space-y-1">
                <div class="h-4 w-28 bg-gray-100 rounded-lg animate-pulse"></div>
                <div class="h-3 w-40 bg-gray-50 rounded-lg animate-pulse"></div>
              </div>
              <div class="h-4 w-16 bg-gray-100 rounded-lg animate-pulse mt-1"></div>
            </div>
          </div>
          <div v-else class="space-y-1">
            <div v-for="order in recentOrders" :key="order.id" class="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
              <div class="flex-1 min-w-0 mr-3">
                <div class="flex items-center gap-1.5">
                  <span class="text-sm font-medium text-gray-800 truncate">{{ order.customer_name || '--' }}</span>
                  <span v-if="order.platform_type && ECOMMERCE_PLATFORMS[order.platform_type]"
                        class="inline-block px-1.5 py-0.5 rounded-full flex-shrink-0 bg-green-50 text-green-600 text-[10px]">
                    {{ ECOMMERCE_PLATFORMS[order.platform_type] }}
                  </span>
                </div>
                <div class="text-xs text-gray-500 mt-0.5 truncate">
                  {{ PRODUCT_CATEGORIES[order.product_category] || order.product_category || '' }} · {{ formatDate(order.created_at) }}
                </div>
              </div>
              <div class="text-sm font-semibold flex-shrink-0 text-green-500">
                {{ formatMoney(order.payment_amount || order.amount) }}
              </div>
            </div>
            <div v-if="recentOrders.length === 0" class="text-sm text-gray-500 text-center py-6">暂无订单数据</div>
          </div>
        </div>

        <!-- 账户余额总览 -->
        <div class="bg-white rounded-2xl p-4 border border-gray-100 shadow-sm">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold text-gray-800 text-sm">账户余额总览</h2>
            <router-link to="/accounts" class="text-xs text-blue-500">管理账户 →</router-link>
          </div>
          <div v-if="loading" class="space-y-4">
            <div class="h-10 bg-gray-100 rounded-lg animate-pulse"></div>
            <div class="h-10 bg-gray-100 rounded-lg animate-pulse"></div>
          </div>
          <div v-else class="space-y-3">
            <!-- 个人账户 -->
            <div class="flex items-center justify-between p-3 rounded-xl bg-green-50">
              <div>
                <div class="text-xs text-gray-500">个人账户</div>
                <div class="text-xs text-gray-500 mt-0.5">{{ accountSummary.personalCount }} 个账户</div>
              </div>
              <div class="text-lg font-bold text-green-500">
                {{ formatMoney(accountSummary.personalTotal) }}
              </div>
            </div>
            <!-- 企业账户 -->
            <div class="flex items-center justify-between p-3 rounded-xl bg-blue-50">
              <div>
                <div class="text-xs text-gray-500">企业账户</div>
                <div class="text-xs text-gray-500 mt-0.5">{{ accountSummary.companyCount }} 个账户</div>
              </div>
              <div class="text-lg font-bold text-blue-500">
                {{ formatMoney(accountSummary.companyTotal) }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, formatDate, PLATFORM_LABELS, PRODUCT_CATEGORIES, ECOMMERCE_PLATFORMS, EXPENSE_STATUS, EXPENSE_CATEGORIES } from '../lib/utils'
// BUG-4 残留修复：Dashboard 的"本月利润"原本和 Reports Overview tab 不一致
//（Dashboard 用 approved+paid、不算工资和转账费），导致用户看两个地方的利润
// 数字对不上。改为统一调用 computeOverviewProfit。
import { computeOverviewProfit } from '../utils/financialMetrics'

const authStore = useAuthStore()

// --- 状态 ---
const loading = ref(true)
const dbError = ref(null)

const stats = ref({
  totalIncome: null,
  totalExpense: null,
  profit: null,
})

const recentOrders = ref([])
const accountSummary = ref({
  personalTotal: 0,
  companyTotal: 0,
  personalCount: 0,
  companyCount: 0,
})

// --- 今日数据 ---
const todayStats = ref({
  todaySales: null,
  todayOrders: null,
})

// --- 今日标签 ---
const todayLabel = computed(() => {
  const now = new Date()
  const h = now.getHours()
  const prefix = h < 6 ? '昨日' : '今日'
  return `${prefix}数据（6:00起算）`
})

// --- 本月时间范围 ---
//
// 返回 [本月 1 号 00:00:00, 本月最后一天 23:59:59]，对应 Reports.Overview 的
// 区间口径（gte + lte），让两边数字完全一致。注意：computeOverviewProfit 用 lte，
// 不能传"下月 1 号 00:00"否则会重复包含下月第一秒的数据。
function getMonthRange() {
  const now = new Date()
  const year = now.getFullYear()
  const month = now.getMonth()
  const start = new Date(year, month, 1, 0, 0, 0)
  const end = new Date(year, month + 1, 0, 23, 59, 59)
  return { start: start.toISOString(), end: end.toISOString() }
}

// --- 获取今日时间范围（6点起算） ---
function getTodayRange() {
  const now = new Date()
  let dayStart
  if (now.getHours() < 6) {
    dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 6, 0, 0)
  } else {
    dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 6, 0, 0)
  }
  const dayEnd = new Date(dayStart)
  dayEnd.setDate(dayEnd.getDate() + 1)
  return { startISO: dayStart.toISOString(), endISO: dayEnd.toISOString() }
}

// --- 数据加载 ---
async function loadDashboard() {
  loading.value = true
  dbError.value = null

  try {
    await loadTodayStats()
    if (authStore.isFinance) {
      await loadFinanceDashboard()
    }
  } catch (err) {
    console.error('加载仪表盘失败:', err)
    dbError.value = '数据库未连接，部分数据加载失败'
  } finally {
    loading.value = false
  }
}

// --- 今日数据 ---
async function loadTodayStats() {
  try {
    const { startISO, endISO } = getTodayRange()

    const [salesRes, orderCountRes] = await Promise.all([
      // 今日销售额（全部orders，包含电商）
      supabase
        .from('orders')
        .select('payment_amount')
        .gte('created_at', startISO)
        .lte('created_at', endISO)
        .is('deleted_at', null),
      // 今日订单数（全部orders，包含电商）
      supabase
        .from('orders')
        .select('id', { count: 'exact', head: true })
        .gte('created_at', startISO)
        .lte('created_at', endISO)
        .is('deleted_at', null),
    ])

    const todaySales = salesRes.data?.reduce((s, r) => s + (Number(r.payment_amount) || 0), 0) || 0

    todayStats.value = {
      todaySales: todaySales > 0 ? todaySales : 0,
      todayOrders: orderCountRes.count ?? 0,
    }
  } catch (e) {
    console.error('加载今日数据失败:', e)
  }
}

// --- 管理员/财务视图 ---
async function loadFinanceDashboard() {
  const { start, end } = getMonthRange()
  try {
  // BUG-4 残留修复：现金口径"本月经营盈余"统一从 computeOverviewProfit 取，
  // 与 Reports.Overview tab 完全一致。本函数只额外查最近订单和账户余额（这两个
  // 不在 financialMetrics 范围内）。
  const [overviewProfit, recentRes, accountsRes] = await Promise.all([
    computeOverviewProfit(supabase, start, end),
    // 最近10笔订单（全部，包含电商）
    supabase
      .from('orders')
      .select('id, amount, payment_amount, customer_name, product_category, created_at, platform_type')
      .order('created_at', { ascending: false })
      .is('deleted_at', null)
      .limit(10),
    // 全部非电商账户（排除电商账户）
    supabase
      .from('accounts')
      .select('id, code, platform, balance, category, ecommerce_platform')
      .eq('status', 'active')
      .is('ecommerce_platform', null),
  ])

  stats.value.totalIncome = overviewProfit.totalIncome
  stats.value.totalExpense = overviewProfit.totalExpense
  stats.value.profit = overviewProfit.profit

  recentOrders.value = recentRes.data || []

  // 账户余额分类
  const accounts = accountsRes.data || []
  const PERSONAL_PLATFORMS = ['alipay', 'wechat', 'alipay_personal']
  let personalTotal = 0
  let companyTotal = 0
  let personalCount = 0
  let companyCount = 0

  for (const acc of accounts) {
    const balance = Number(acc.balance) || 0
    let category = acc.category
    if (!category) {
      if (PERSONAL_PLATFORMS.includes(acc.platform)) category = 'personal'
      else category = 'company'
    }
    if (category === 'personal') {
      personalTotal += balance
      personalCount++
    } else {
      companyTotal += balance
      companyCount++
    }
  }

  accountSummary.value = { personalTotal, companyTotal, personalCount, companyCount }
  } catch (e) {
    console.error('加载财务总览失败:', e)
  }
}

onMounted(() => {
  loadDashboard()
})
</script>
