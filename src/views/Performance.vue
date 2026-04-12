<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">🏆 业绩统计</h1>
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
      <button @click="loadData" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm hover:bg-gray-200 cursor-pointer">
        🔄 刷新
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
      <div class="text-2xl mb-2 animate-pulse">📊</div>
      <div class="text-gray-500 text-sm">加载业绩数据...</div>
    </div>

    <template v-else>
      <!-- Team Summary -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">💰 团队总金额</div>
          <div class="text-2xl font-bold text-green-600">{{ formatMoney(teamTotal.amount) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">📦 总订单数</div>
          <div class="text-2xl font-bold text-blue-600">{{ teamTotal.orders }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">📋 平均客单价</div>
          <div class="text-2xl font-bold text-purple-600">{{ formatMoney(teamTotal.avg) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">🎯 达标人数</div>
          <div class="text-2xl font-bold text-orange-500">{{ targetAchievedCount }}/{{ targetTotalCount }}</div>
        </div>
      </div>

      <!-- Ranking Table -->
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden mb-6">
        <div class="px-4 py-3 border-b border-gray-100">
          <h2 class="font-bold text-gray-700">📊 业绩排行榜</h2>
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
        <h2 class="font-bold text-gray-700 mb-4">🎯 本月销售目标</h2>
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
          <h2 class="font-bold text-gray-700">🏷️ 我的小组业绩</h2>
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

const auth = useAuthStore()
const loading = ref(true)

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
  try {
    // Determine date filter based on period
    let startDate = ''
    if (filters.periodType === 'monthly' && filters.periodValue) {
      const [y, m] = filters.periodValue.split('-')
      const monthStr = `${y}-${m}`
      
      // Load performance data via RPC (SECURITY DEFINER bypasses RLS)
      const { data: perfData, error: perfError } = await supabase
        .rpc('get_performance_data', { p_period: monthStr })
      if (perfError) console.error('RPC error:', perfError)
      performanceData.value = (perfData || []).map(p => ({
        ...p,
        completion_rate: p.user_id ? (getTargetAmount(p.user_id) > 0 ? (p.total_amount || 0) / getTargetAmount(p.user_id) : 0) : 0,
      }))

      // Load targets
      const { data: targetData } = await supabase
        .from('sales_targets')
        .select('*')
        .eq('period_type', 'monthly')
        .eq('period_value', monthStr)
      targets.value = (targetData || []).map(t => ({
        ...t,
        completion_rate: t.target_amount > 0 ? (t.actual_amount || 0) / t.target_amount : 0,
      }))
    }
  } catch (e) {
    console.error('Failed to load performance data:', e)
    toast('加载失败', 'error')
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
