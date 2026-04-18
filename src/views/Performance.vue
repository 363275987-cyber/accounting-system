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
import { supabase } from '../lib/supabase'
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

    // 并行拉取业绩数据和目标表（之前串行且目标后加载，导致 completion_rate 一直按空目标算 → 全是 0%）
    const [perfResult, targetResult] = await Promise.all([
      supabase.rpc('get_performance_data', { p_period: monthStr }),
      supabase.from('sales_targets').select('*').eq('period_type', 'monthly').eq('period_value', monthStr),
    ])

    const { data: targetData, error: targetError } = targetResult
    if (targetError) {
      console.error('[Performance] sales_targets error:', targetError)
      // 业绩目标表不是强依赖，失败只记不阻塞
      loadError.value = `业绩目标表加载失败：${targetError.message || targetError.code}`
      targets.value = []
    } else {
      targets.value = (targetData || []).map(t => ({
        ...t,
        completion_rate: t.target_amount > 0 ? (t.actual_amount || 0) / t.target_amount : 0,
      }))
    }

    // 先把 targets.value 赋完值，再计算 perf 的 completion_rate（依赖 getTargetAmount）
    const { data: perfData, error: perfError } = perfResult
    if (perfError) {
      // 之前这里只 console.error 后继续，导致"没数据"但表象像加载失败
      // 现在把具体错误告诉用户，常见：RPC 未部署 / 无权限 / 网络断
      console.error('[Performance] get_performance_data RPC error:', perfError)
      // 业绩数据是主要依赖，优先用它的错误信息覆盖目标表的错误
      loadError.value = `业绩数据加载失败：${perfError.message || perfError.code || '未知错误'}`
      performanceData.value = []
    } else {
      performanceData.value = (perfData || []).map(p => ({
        ...p,
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
