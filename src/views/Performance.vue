<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="trophy" class="inline w-4 h-4 -mt-0.5 mr-1" /> 业绩统计</h1>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <select v-model="filters.periodType" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        <option value="monthly">按月</option>
      </select>
      <input v-model="filters.periodValue" type="month" 
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
      <select v-model="filters.sortBy" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        <option value="amount">按金额排序</option>
        <option value="orders">按订单数排序</option>
        <option value="avg">按客单价排序</option>
      </select>
      <button @click="loadData" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm hover:bg-gray-200 cursor-pointer"><Icon name="refresh" class="inline w-4 h-4 -mt-0.5 mr-1" /> 刷新
      </button>
    </div>

    <!-- 加载错误提示（方便定位是 RPC 未部署还是无权限等）-->
    <div v-if="loadError && !loading" class="bg-red-50 border border-red-200 rounded-2xl p-3 mb-3 text-sm">
      <div class="font-medium text-red-700 mb-1"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> {{ loadError }}</div>
      <div class="text-xs text-red-500 mb-2">如持续无法加载，请联系管理员检查 get_performance_data / sales_targets 权限。</div>
      <button @click="loadData" class="px-3 py-1 bg-red-500 text-white rounded text-xs hover:bg-red-600 cursor-pointer">重试</button>
    </div>

    <!-- Loading skeleton (BUG-6: 替代 emoji 等待) -->
    <template v-if="loading">
      <Skeleton type="stats" :count="4" stats-grid-class="grid-cols-2 lg:grid-cols-4" class="mb-6" />
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <Skeleton type="table" :rows="6" :columns="8" />
      </div>
    </template>

    <template v-else>
      <!-- Team Summary -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 团队总金额</div>
          <div class="text-2xl font-bold text-green-600">{{ formatMoney(teamTotal.amount) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="package" class="inline w-4 h-4 -mt-0.5 mr-1" /> 总订单数</div>
          <div class="text-2xl font-bold text-blue-600">{{ teamTotal.orders }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 平均客单价</div>
          <div class="text-2xl font-bold text-purple-600">{{ formatMoney(teamTotal.avg) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="target" class="inline w-4 h-4 -mt-0.5 mr-1" /> 达标人数</div>
          <div class="text-2xl font-bold text-orange-500">{{ targetAchievedCount }}/{{ targetTotalCount }}</div>
        </div>
      </div>

      <!-- Ranking Table -->
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden mb-6">
        <div class="px-4 py-3 border-b border-gray-100">
          <h2 class="font-bold text-gray-700"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 业绩排行榜</h2>
        </div>
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-600">
              <th class="px-4 py-3 text-center font-medium w-16">排名</th>
              <th class="px-4 py-3 text-left font-medium">姓名</th>
              <th class="px-4 py-3 text-left font-medium">角色</th>
              <th class="px-4 py-3 text-right font-medium">订单数</th>
              <th class="px-4 py-3 text-right font-medium">总金额</th>
              <th class="px-4 py-3 text-right font-medium">客单价</th>
              <th class="px-4 py-3 text-left font-medium">使用渠道</th>
              <th class="px-4 py-3 text-center font-medium">目标完成</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(item, idx) in sortedPerformance" :key="item.user_id" 
              class="border-t border-gray-50 hover:bg-gray-50/60 transition">
              <td class="px-4 py-3 text-center">
                <span :class="idx === 0 ? 'text-yellow-500' : idx === 1 ? 'text-gray-500' : idx === 2 ? 'text-orange-400' : 'text-gray-300'"
                  class="font-bold text-lg">
                  {{ idx < 3 ? ['🥇','🥈','🥉'][idx] : idx + 1 }}
                </span>
              </td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ item.user_name }}</td>
              <td class="px-4 py-3">
                <span class="text-xs px-2 py-0.5 rounded-full"
                  :class="item.user_role === 'sales' ? 'bg-blue-50 text-blue-700' : 'bg-gray-50 text-gray-600'">
                  {{ roleLabel(item.user_role) }}
                </span>
              </td>
              <td class="px-4 py-3 text-right text-gray-700">{{ item.total_orders }}</td>
              <td class="px-4 py-3 text-right font-semibold text-green-600">{{ formatMoney(item.total_amount) }}</td>
              <td class="px-4 py-3 text-right text-gray-600">{{ formatMoney(item.avg_order_amount) }}</td>
              <td class="px-4 py-3 text-gray-500">{{ item.channels_used }}</td>
              <td class="px-4 py-3 text-center">
                <template v-if="item.target_amount > 0">
                  <div class="inline-flex items-center gap-2">
                    <div class="w-20 h-2 bg-gray-100 rounded-full overflow-hidden">
                      <div class="h-full rounded-full transition-all" 
                        :class="item.completion_rate >= 1 ? 'bg-green-500' : item.completion_rate >= 0.7 ? 'bg-blue-500' : 'bg-orange-400'"
                        :style="{ width: Math.min(item.completion_rate * 100, 100) + '%' }">
                      </div>
                    </div>
                    <span class="text-xs font-medium" :class="item.completion_rate >= 1 ? 'text-green-600' : 'text-gray-500'">
                      {{ Math.round(item.completion_rate * 100) }}%
                    </span>
                  </div>
                </template>
                <span v-else class="text-xs text-gray-500">未设目标</span>
              </td>
            </tr>
            <tr v-if="performanceData.length === 0">
              <td colspan="8" class="px-4 py-12 text-center text-gray-500">暂无业绩数据</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Sales Targets Section -->
      <div v-if="auth.isFinance && targets.length > 0" class="bg-white rounded-xl border border-gray-100 p-5">
        <h2 class="font-bold text-gray-700 mb-4"><Icon name="target" class="inline w-4 h-4 -mt-0.5 mr-1" /> 本月销售目标</h2>
        <div class="space-y-3">
          <div v-for="t in targets" :key="t.id" class="flex items-center gap-4">
            <div class="w-24 text-sm text-gray-600 truncate">{{ t.user_name }}</div>
            <div class="flex-1">
              <div class="flex items-center gap-2 mb-1">
                <span class="text-sm font-medium" :class="t.completion_rate >= 1 ? 'text-green-600' : 'text-gray-700'">
                  {{ formatMoney(t.actual_amount) }}
                </span>
                <span class="text-gray-300">/</span>
                <span class="text-sm text-gray-500">{{ formatMoney(t.target_amount) }}</span>
              </div>
              <div class="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
                <div class="h-full rounded-full transition-all"
                  :class="t.completion_rate >= 1 ? 'bg-green-500' : t.completion_rate >= 0.7 ? 'bg-blue-500' : 'bg-orange-400'"
                  :style="{ width: Math.min(t.completion_rate * 100, 100) + '%' }">
                </div>
              </div>
            </div>
            <div class="text-xs text-gray-500">
              订单 {{ t.actual_orders }}/{{ t.target_orders }}
              · 客单价 {{ formatMoney(t.target_amount > 0 ? t.actual_amount / Math.max(t.actual_orders, 1) : 0) }}
            </div>
          </div>
        </div>
      </div>

      <!-- Leader: Group Performance Section -->
      <div v-if="isGroupLeader && myGroupPerformance.length > 0" class="bg-white rounded-xl border border-gray-100 overflow-hidden mt-6">
        <div class="px-4 py-3 border-b border-gray-100 flex items-center gap-2">
          <h2 class="font-bold text-gray-700"><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 我的小组业绩</h2>
          <span class="text-xs text-gray-500">（{{ myGroupInfo?.group_name || '' }}）</span>
        </div>
        <div class="grid grid-cols-3 gap-4 p-4 border-b border-gray-50">
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="text-xs text-gray-500 mb-1">组总金额</div>
            <div class="text-lg font-bold text-green-600">{{ formatMoney(myGroupTotal.amount) }}</div>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="text-xs text-gray-500 mb-1">组订单数</div>
            <div class="text-lg font-bold text-blue-600">{{ myGroupTotal.orders }}</div>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="text-xs text-gray-500 mb-1">组客单价</div>
            <div class="text-lg font-bold text-purple-600">{{ formatMoney(myGroupTotal.avg) }}</div>
          </div>
        </div>
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-600">
              <th class="px-4 py-2 text-left font-medium">姓名</th>
              <th class="px-4 py-2 text-right font-medium">订单数</th>
              <th class="px-4 py-2 text-right font-medium">总金额</th>
              <th class="px-4 py-2 text-right font-medium">客单价</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in myGroupPerformance" :key="p.user_id" class="border-t border-gray-50 hover:bg-gray-50/60">
              <td class="px-4 py-2.5 font-medium text-gray-800">
                {{ p.user_name }}
                <span v-if="p.user_id === auth.user" class="text-xs text-blue-500 ml-1">（我）</span>
              </td>
              <td class="px-4 py-2.5 text-right text-gray-700">{{ p.total_orders }}</td>
              <td class="px-4 py-2.5 text-right font-semibold text-green-600">{{ formatMoney(p.total_amount) }}</td>
              <td class="px-4 py-2.5 text-right text-gray-600">{{ formatMoney(p.avg_order_amount) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase, withTimeout } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, toast } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'
import Icon from '../components/icons/Icons.vue'

const auth = useAuthStore()
const loading = ref(true)
const loadError = ref('') // 显示给用户的具体错误信息（而不是 only 吐到 console）

const filters = reactive({
  periodType: 'monthly',
  periodValue: '',
  sortBy: 'amount',
})

const performanceData = ref([])
const targets = ref([])

// Group leader data
const myGroupInfo = ref(null) // { group_id, group_name, is_leader }
const myGroupPerformance = ref([])
const isGroupLeader = computed(() => myGroupInfo.value?.is_leader === true)

const roleLabels = {
  sales: '销售',
  cs: '客服',
  finance: '财务',
  manager: '经理',
  admin: '管理员',
  hr: '人事',
  coach: '教练',
}

function roleLabel(role) {
  return roleLabels[role] || role || '—'
}

const teamTotal = computed(() => {
  if (!performanceData.value.length) return { amount: 0, orders: 0, avg: 0 }
  const totalAmount = performanceData.value.reduce((s, r) => s + r.total_amount, 0)
  const totalOrders = performanceData.value.reduce((s, r) => s + r.total_orders, 0)
  return {
    amount: totalAmount,
    orders: totalOrders,
    avg: totalOrders > 0 ? totalAmount / totalOrders : 0,
  }
})

const sortedPerformance = computed(() => {
  const sorted = [...performanceData.value]
  const key = filters.sortBy === 'amount' ? 'total_amount' : filters.sortBy === 'orders' ? 'total_orders' : 'avg_order_amount'
  sorted.sort((a, b) => b[key] - a[key])
  return sorted
})

const targetAchievedCount = computed(() => targets.value.filter(t => t.completion_rate >= 1).length)
const targetTotalCount = computed(() => targets.value.length)

function getDefaultPeriod() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

function buildMonthRange(monthStr) {
  const [year, month] = monthStr.split('-').map(Number)
  const start = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0))
  const end = new Date(Date.UTC(year, month, 1, 0, 0, 0))
  return { start: start.toISOString(), end: end.toISOString() }
}

async function loadTargetsFlexible(monthStr) {
  try {
    const { data, error } = await withTimeout(
      supabase.from('sales_targets').select('*').limit(500),
      10000,
      '加载销售目标'
    )
    if (error) throw error
    const list = data || []
    return list
      .filter(row => {
        const period = row.period_value || row.period || row.month || row.target_month || ''
        const periodType = row.period_type || row.type || row.target_type || 'monthly'
        return String(period) === monthStr && String(periodType) === 'monthly'
      })
      .map(t => ({
        ...t,
        user_id: t.user_id || t.profile_id || t.owner_id,
        user_name: t.user_name || t.name || '未命名',
        target_amount: Number(t.target_amount || t.amount || 0),
        target_orders: Number(t.target_orders || t.orders || 0),
        actual_amount: Number(t.actual_amount || 0),
        actual_orders: Number(t.actual_orders || 0),
      }))
  } catch (e) {
    console.error('[Performance] flexible target load error:', e)
    return []
  }
}

async function loadPerformanceFallback(monthStr) {
  const { start, end } = buildMonthRange(monthStr)
  const { data: orders, error } = await withTimeout(
    supabase
      .from('orders')
      .select('id, amount, sales_id, creator_id, status, created_at, order_source, service_number_code')
      .is('deleted_at', null)
      .gte('created_at', start)
      .lt('created_at', end),
    15000,
    '按订单聚合业绩'
  )
  if (error) throw error

  const validOrders = (orders || []).filter(o => ['completed', 'partially_refunded', 'paid'].includes(o.status))
  const userIds = [...new Set(validOrders.map(o => o.sales_id || o.creator_id).filter(Boolean))]

  let profileMap = {}
  if (userIds.length > 0) {
    const { data: profiles, error: profileError } = await withTimeout(
      supabase.from('profiles').select('id, name, role').in('id', userIds),
      10000,
      '加载业绩人员'
    )
    if (profileError) throw profileError
    profileMap = Object.fromEntries((profiles || []).map(p => [p.id, p]))
  }

  const sourceLabelMap = {
    sales_guided: '销售引导',
    organic: '自然进店',
    cs_service: '客服服务',
    shared: '平分单',
  }

  const grouped = new Map()
  for (const order of validOrders) {
    const userId = order.sales_id || order.creator_id || 'unassigned'
    const profile = profileMap[userId]
    const current = grouped.get(userId) || {
      user_id: userId === 'unassigned' ? null : userId,
      user_name: profile?.name || '未分配',
      user_role: profile?.role || '',
      total_orders: 0,
      total_amount: 0,
      avg_order_amount: 0,
      channels_used: '',
      target_amount: 0,
      completion_rate: 0,
      _channels: new Set(),
    }
    current.total_orders += 1
    current.total_amount += Number(order.amount || 0)
    const label = sourceLabelMap[order.order_source] || order.service_number_code || order.order_source || '未标记'
    current._channels.add(label)
    grouped.set(userId, current)
  }

  return [...grouped.values()].map(item => ({
    ...item,
    avg_order_amount: item.total_orders > 0 ? item.total_amount / item.total_orders : 0,
    channels_used: [...item._channels].join('、'),
  }))
}

async function loadData() {
  loading.value = true
  loadError.value = ''
  try {
    if (filters.periodType !== 'monthly' || !filters.periodValue) {
      loadError.value = '请选择月份'
      return
    }
    const [y, m] = filters.periodValue.split('-')
    const monthStr = `${y}-${m}`

    const [perfResult, targetData] = await Promise.all([
      withTimeout(
        supabase.rpc('get_performance_data', { p_period: monthStr }),
        12000,
        '加载业绩 RPC'
      ),
      loadTargetsFlexible(monthStr),
    ])

    targets.value = targetData.map(t => ({
      ...t,
      completion_rate: t.target_amount > 0 ? (t.actual_amount || 0) / t.target_amount : 0,
    }))

    // 先把 targets.value 赋完值，再计算 perf 的 completion_rate（依赖 getTargetAmount）
    const { data: perfData, error: perfError } = perfResult
    if (perfError) {
      console.error('[Performance] get_performance_data RPC error:', perfError)
      const fallbackData = await loadPerformanceFallback(monthStr)
      performanceData.value = fallbackData.map(p => ({
        ...p,
        completion_rate: p.user_id ? (getTargetAmount(p.user_id) > 0 ? (p.total_amount || 0) / getTargetAmount(p.user_id) : 0) : 0,
      }))
      loadError.value = `业绩 RPC 已回退为前端聚合：${perfError.message || perfError.code || '未知错误'}`
    } else {
      performanceData.value = (perfData || []).map(p => ({
        ...p,
        user_role: p.user_role || p.role || '',
        completion_rate: p.user_id ? (getTargetAmount(p.user_id) > 0 ? (p.total_amount || 0) / getTargetAmount(p.user_id) : 0) : 0,
      }))
    }
  } catch (e) {
    console.error('[Performance] load fatal:', e)
    loadError.value = `加载失败：${e?.message || String(e)}`
    toast(loadError.value, 'error')
  } finally {
    loading.value = false
  }
}

function getTargetAmount(userId) {
  const t = targets.value.find(t => t.user_id === userId)
  return t ? t.target_amount : 0
}

const myGroupTotal = computed(() => {
  const data = myGroupPerformance.value
  if (!data.length) return { amount: 0, orders: 0, avg: 0 }
  const amount = data.reduce((s, r) => s + Number(r.total_amount), 0)
  const orders = data.reduce((s, r) => s + Number(r.total_orders), 0)
  return { amount, orders, avg: orders > 0 ? amount / orders : 0 }
})

async function loadGroupLeaderData() {
  if (!auth.user) return
  try {
    // Check if user is a group leader
    const { data: groupData, error } = await supabase
      .rpc('get_user_sales_group', { p_user_id: auth.user })
    if (error || !groupData || groupData.length === 0) return

    const leaderGroup = groupData.find(g => g.is_leader)
    if (!leaderGroup) return

    myGroupInfo.value = leaderGroup

    // Load group performance for the selected month
    if (filters.periodValue) {
      const { data: perfData, error: gpError } = await supabase
        .rpc('get_group_performance_data', { p_group_id: leaderGroup.group_id, p_period: filters.periodValue })
      if (gpError) console.error('Group performance RPC error:', gpError)
      myGroupPerformance.value = perfData || []
    }
  } catch (e) {
    console.error('Failed to load group leader data:', e)
  }
}

onMounted(() => {
  filters.periodValue = getDefaultPeriod()
  loadData()
  loadGroupLeaderData()
})
</script>
