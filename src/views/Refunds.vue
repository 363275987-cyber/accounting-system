<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">💳 退款管理</h1>
      <div class="flex items-center gap-2">
        <!-- 随机测试数据 -->
        <div v-if="canDeleteRefunds" class="inline-flex items-center gap-1">
          <select v-model="testCount" class="text-xs border border-dashed border-gray-300 rounded px-2 py-1 text-gray-500 bg-transparent outline-none cursor-pointer">
            <option :value="1">1条</option>
            <option :value="5">5条</option>
            <option :value="10">10条</option>
            <option :value="20">20条</option>
          </select>
          <button @click="generateTestData(testCount)" class="text-xs px-2 py-1 border border-dashed border-gray-300 rounded text-gray-500 hover:bg-gray-50 hover:text-gray-600 cursor-pointer">
            🎲 随机测试
          </button>
        </div>
        <button @click="openRefundModal"
        class="bg-orange-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-orange-700 transition cursor-pointer">
        + 登记退款
      </button>
      </div>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">本月退款笔数</div>
        <div class="text-2xl font-bold text-orange-500">{{ stats.count }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">本月退款总额</div>
        <div class="text-2xl font-bold text-red-500">{{ formatMoney(stats.total) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">退款率</div>
        <div class="text-2xl font-bold" :class="stats.rate <= 5 ? 'text-green-600' : stats.rate <= 10 ? 'text-orange-500' : 'text-red-500'">
          {{ stats.rate }}%
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <select v-model="filters.status" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
        <option value="">全部</option>
        <option value="pending">待审批</option>
        <option value="processing">处理中</option>
        <option value="completed">已退</option>
      </select>
      <select v-model="filters.periodType" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
        <option value="all">全部时间</option>
        <option value="month">本月</option>
        <option value="quarter">本季度</option>
      </select>
      <input v-model="search" placeholder="搜订单号/客户/退款原因/账户"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredRefunds.length }} 条</span>
    </div>

    <!-- Action Bar -->
    <div v-if="selectedRefundIds.length > 0 && canDeleteRefunds" class="bg-red-50 border border-red-100 rounded-xl px-4 py-3 mb-4 flex items-center gap-3">
      <span class="text-red-600 text-sm font-medium">已选 {{ selectedRefundIds.length }} 条</span>
      <button @click="handleBatchDeleteRefunds" class="bg-red-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-red-700 transition cursor-pointer">删除选中</button>
      <button @click="selectedRefundIds = []" class="text-gray-500 text-sm hover:text-gray-700 cursor-pointer">取消选择</button>
    </div>

    <!-- Refunds Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <Skeleton v-if="loading" type="table" :rows="6" :columns="7" />
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th v-if="canDeleteRefunds" class="px-4 py-3 text-center w-10">
              <input type="checkbox" :checked="selectedRefundIds.length === filteredRefunds.length && filteredRefunds.length > 0" @change="e => selectedRefundIds = e.target.checked ? filteredRefunds.map(x => x.id) : []" class="rounded cursor-pointer">
            </th>
            <th class="px-4 py-3 text-left font-medium">退款单号</th>
            <th class="px-4 py-3 text-left font-medium">原订单</th>
            <th class="px-4 py-3 text-left font-medium">客户</th>
            <th class="px-4 py-3 text-right font-medium">退款金额</th>
            <th class="px-4 py-3 text-left font-medium">退款原因</th>
            <th class="px-4 py-3 text-left font-medium">付款账户</th>
            <th class="px-4 py-3 text-center font-medium">状态</th>
            <th class="px-4 py-3 text-left font-medium">时间</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in paginatedItems" :key="r.id" class="border-t border-gray-50 hover:bg-gray-50/60 transition">
            <td v-if="canDeleteRefunds" class="px-4 py-3 text-center">
              <input type="checkbox" :value="r.id" v-model="selectedRefundIds" class="rounded cursor-pointer">
            </td>
            <td class="px-4 py-3 text-xs text-gray-500 font-mono">{{ r.refund_no }}</td>
            <td class="px-4 py-3 text-gray-600 text-xs">{{ r.order_info?.order_no || '—' }}</td>
            <td class="px-4 py-3 text-gray-700">{{ r.order_info?.customer_name || '—' }}</td>
            <td class="px-4 py-3 text-right font-semibold text-red-500">{{ formatMoney(r.refund_amount) }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ r.reason }}</td>
            <td class="px-4 py-3">
              <span v-if="r.refund_account_code" class="bg-blue-50 text-blue-700 px-1.5 py-0.5 rounded text-xs">{{ r.refund_account_code }}</span>
              <span v-else class="text-gray-500 text-xs">—</span>
            </td>
            <td class="px-4 py-3 text-center">
              <span v-if="r.status === 'completed'" class="px-2 py-0.5 rounded-full text-xs font-medium bg-green-50 text-green-600">已退</span>
              <span v-else-if="r.status === 'pending'" class="px-2 py-0.5 rounded-full text-xs font-medium bg-amber-50 text-amber-600">待审批</span>
              <span v-else-if="r.status === 'processing'" class="px-2 py-0.5 rounded-full text-xs font-medium bg-blue-50 text-blue-600">处理中</span>
              <span v-else class="px-2 py-0.5 rounded-full text-xs font-medium bg-gray-50 text-gray-600">{{ r.status }}</span>
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatDate(r.created_at) }}</td>
            <td v-if="canDeleteRefunds" class="px-4 py-3 text-center space-x-1">
              <button v-if="r.status === 'pending'" @click="handleApproveRefund(r)" class="text-green-600 hover:text-green-800 text-xs px-2 py-1 rounded hover:bg-green-50 transition cursor-pointer">审批</button>
              <button @click="handleDeleteRefund(r)" class="text-red-400 hover:text-red-600 text-xs px-2 py-1 rounded hover:bg-red-50 transition cursor-pointer">删除</button>
            </td>
          </tr>
          <tr v-if="filteredRefunds.length === 0">
            <td :colspan="canDeleteRefunds ? 9 : 8" class="px-4 py-12 text-center text-gray-500">暂无退款记录</td>
          </tr>
        </tbody>
      </table>
      <div v-if="totalPages > 1" class="px-4 py-3 flex items-center justify-between border-t border-gray-100 text-sm text-gray-500">
        <span>第 {{ currentPage }} / {{ totalPages }} 页</span>
        <div class="flex gap-1">
          <button @click="currentPage = 1" :disabled="currentPage <= 1" class="px-2.5 py-1 border rounded text-xs hover:bg-gray-50 disabled:opacity-40">首页</button>
          <button @click="currentPage--" :disabled="currentPage <= 1" class="px-2.5 py-1 border rounded text-xs hover:bg-gray-50 disabled:opacity-40">上一页</button>
          <button @click="currentPage++" :disabled="currentPage >= totalPages" class="px-2.5 py-1 border rounded text-xs hover:bg-gray-50 disabled:opacity-40">下一页</button>
        </div>
      </div>
    </div>

    <!-- New Refund Modal -->
    <div v-if="showRefundModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showRefundModal = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 max-h-[85vh] flex flex-col overflow-y-auto">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10 shrink-0">
          <h2 class="font-bold text-gray-800">💳 登记退款</h2>
          <button @click="showRefundModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleRefund" class="p-6 space-y-4 flex-1">
          <!-- Order selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">关联订单 <span class="text-red-400">*</span></label>
            <div class="relative">
              <input
                v-model="orderSearch"
                @focus="showOrderDropdown = true"
                @blur="hideOrderDropdown"
                placeholder="搜索订单号/客户名/产品名..."
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
              />
              <button type="button" v-if="form.order_id" @click="clearOrderSelection" class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-red-500 cursor-pointer">&times;</button>
              <!-- 下拉列表 -->
              <div v-if="showOrderDropdown"
                class="absolute z-50 mt-1 left-0 right-0 bg-white border border-gray-200 rounded-lg shadow-xl max-h-56 overflow-y-auto">
                <div
                  v-for="o in filteredOrders"
                  :key="o.id"
                  @mousedown.prevent="selectOrder(o)"
                  class="px-3 py-2.5 hover:bg-orange-50 cursor-pointer text-sm border-b border-gray-50 last:border-0"
                >
                  <div class="flex justify-between items-center">
                    <span class="font-medium text-gray-800">{{ o.customer_name }}</span>
                    <span class="text-orange-600 font-medium">¥{{ o.amount }}</span>
                  </div>
                  <div class="text-xs text-gray-500">{{ o.product_name }} · {{ o.order_no }}</div>
                </div>
                <div v-if="filteredOrders.length === 0" class="text-center py-4 text-gray-500 text-sm">没有匹配的订单</div>
              </div>
            </div>
            <div v-if="selectedOrder" class="mt-2 space-y-1">
              <div class="flex items-center justify-between text-xs text-gray-500 bg-gray-50 rounded px-2 py-1">
                <span>订单金额 ¥{{ selectedOrder.amount }} · {{ selectedOrder.account_code }}</span>
              </div>
              <!-- 订单产品明细 -->
              <div v-if="orderProducts.length > 0" class="bg-gray-50 rounded-lg px-2 py-1.5">
                <div class="text-xs text-gray-500 mb-1">产品明细：</div>
                <div v-for="op in orderProducts" :key="op.id" class="flex items-center justify-between text-xs py-0.5">
                  <span :class="op.is_gift ? 'text-purple-500' : 'text-gray-700'">
                    {{ op.is_gift ? '🎁' : '' }} {{ op.product_name }}
                  </span>
                  <span class="text-gray-500">{{ op.is_gift ? '¥0（赠品）' : '×' + op.quantity }}</span>
                </div>
              </div>
            </div>
          </div>
          <!-- Refund amount -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">退款金额 <span class="text-red-400">*</span></label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">¥</span>
              <input v-model.number="form.refund_amount" type="number" min="0.01" step="0.01" required
                :max="maxRefundable || 999999"
                placeholder="0.00"
                class="w-full pl-8 pr-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <p v-if="selectedOrder" class="text-xs text-gray-500 mt-1">
              可退上限：¥{{ maxRefundable.toFixed(2) }}
              <span v-if="maxRefundable < Number(selectedOrder.amount)">（已退/待退 ¥{{ (Number(selectedOrder.amount) - maxRefundable).toFixed(2) }}）</span>
            </p>
          </div>
          <!-- Reason -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">退款原因</label>
            <select v-model="form.reason" class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="客户退货">客户退货</option>
              <option value="质量问题">质量问题</option>
              <option value="发错货">发错货</option>
              <option value="客户取消">客户取消</option>
              <option value="其他">其他</option>
            </select>
            <input v-if="form.reason === '其他'" v-model="form.custom_reason" placeholder="请填写具体原因" required
              class="w-full mt-2 px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <!-- 付款账户（从哪个账户退款给客户） -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">付款账户 <span class="text-red-400">*</span></label>
            <div class="relative">
              <input
                v-model="accountInputText"
                @focus="onAccountFocus"
                @blur="hideAccountDropdown"
                placeholder="点击选择付款账户..."
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
              />
              <div v-if="showAccountDropdown"
                class="absolute z-50 mt-1 left-0 right-0 bg-white border border-gray-200 rounded-lg shadow-xl max-h-48 overflow-y-auto">
                <template v-for="(accs, ip) in filteredAccountGroups" :key="ip">
                  <div class="px-2 py-1 bg-gray-50 text-xs font-medium text-gray-500 sticky top-0">{{ ip || '未分组' }}</div>
                  <div
                    v-for="acc in accs" :key="acc.id"
                    @mousedown.prevent="selectAccount(acc)"
                    :class="acc.id === form.refund_from_account_id ? 'bg-blue-50' : ''"
                    class="px-3 py-2 hover:bg-orange-50 cursor-pointer text-sm border-b border-gray-50 last:border-0"
                  >
                    {{ acc.code }}{{ acc.short_name ? ` (${acc.short_name})` : '' }}
                    <span v-if="acc.balance != null" class="ml-2 text-xs text-gray-500">¥{{ Number(acc.balance).toFixed(0) }}</span>
                  </div>
                </template>
                <div v-if="Object.keys(filteredAccountGroups).length === 0" class="text-center py-4 text-gray-500 text-sm">没有可用账户</div>
              </div>
            </div>
          </div>
          <!-- Note -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="可选"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showRefundModal = false"
              class="flex-1 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
            <button type="submit" :disabled="submitting"
              class="flex-1 py-2.5 bg-orange-600 text-white rounded-lg text-sm hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
              {{ submitting ? '提交中...' : '确认退款' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, toast, formatDate } from '../lib/utils'
import { randomPick, randomAmount, todayDate, REFUND_REASONS } from '../lib/testDataHelper'
import { logOperation, getAccountBalance, formatMoneyStr } from '../utils/operationLogger'
import Skeleton from '../components/Skeleton.vue'

const auth = useAuthStore()
const canDeleteRefunds = computed(() => ['finance', 'admin', 'manager'].includes(auth.profile?.role))
const selectedRefundIds = ref([])
const loading = ref(true)
const submitting = ref(false)
const search = ref('')
const refunds = ref([])
const completedOrders = ref([])
const accounts = ref([])
const showRefundModal = ref(false)
const currentPage = ref(1)
const pageSize = 20

const filters = reactive({ status: '', periodType: 'month' })

const testCount = ref(5)

// ---------- 随机测试数据生成 ----------
async function generateTestData(count) {
  try {
    // 需要先有已完成的订单才能创建退款
    const { data: orders } = await supabase
      .from('orders')
      .select('id, order_no, customer_name, product_name, amount, account_code, account_id')
      .in('status', ['completed', 'partially_refunded'])
      .limit(500)
    if (!orders || !orders.length) { toast('没有可退款的已完成订单', 'warning'); return }
    const { data: accData } = await supabase.from('accounts').select('id, code').eq('status', 'active')
    const accs = accData || []
    if (!accs.length) { toast('没有可用账户', 'warning'); return }
    const userId = (await supabase.auth.getSession()).data.session?.user?.id
    let success = 0
    for (let i = 0; i < count; i++) {
      const order = randomPick(orders)
      const acc = randomPick(accs)
      const amt = Math.min(randomAmount(50, 5000), order.amount)
      const { error } = await supabase
        .from('refunds')
        .insert({
          order_id: order.id,
          refund_amount: amt,
          reason: randomPick(REFUND_REASONS),
          refund_from_account_id: acc.id,
          status: 'completed',
          created_by: userId,
          note: '测试数据',
        })
      if (error) { console.warn('退款插入失败:', error.message); continue }
      success++
    }
    await loadRefunds()
    calculateStats()
    toast(`成功生成 ${success} 条测试退款`, 'success')
  } catch (e) {
    console.error(e)
    toast('生成测试数据失败：' + (e.message || ''), 'error')
  }
}

const form = reactive({
  order_id: '',
  refund_amount: null,
  reason: '客户退货',
  custom_reason: '',
  refund_from_account_id: '',
  note: '',
})

// 付款账户输入文本（可读写，用于搜索和显示）
const orderSearch = ref('')
const accountInputText = ref('')
const showOrderDropdown = ref(false)
const showAccountDropdown = ref(false)
const orderProducts = ref([]) // 选中订单的产品明细

// blur 延迟关闭
function hideOrderDropdown() { setTimeout(() => showOrderDropdown.value = false, 200) }
function hideAccountDropdown() { setTimeout(() => showAccountDropdown.value = false, 200) }

// 聚焦付款账户时清空搜索文本，显示所有账户
function onAccountFocus() { accountInputText.value = ''; showAccountDropdown.value = true }

// 选中订单 — 计算可退上限
const maxRefundable = ref(0)
async function selectOrder(o) {
  form.order_id = o.id
  // 查询已退金额，设置可退上限
  const { data: existingRefunds } = await supabase.from('refunds')
    .select('refund_amount')
    .eq('order_id', o.id)
    .in('status', ['pending', 'processing', 'completed'])
  const alreadyRefunded = (existingRefunds || []).reduce((sum, r) => sum + Number(r.refund_amount), 0)
  maxRefundable.value = Math.max(0, Number(o.amount) - alreadyRefunded)
  form.refund_amount = maxRefundable.value
  orderSearch.value = `${o.customer_name} - ${o.product_name} (¥${o.amount})`
  showOrderDropdown.value = false
  if (o.account_id && !form.refund_from_account_id) {
    form.refund_from_account_id = o.account_id
    // 更新付款账户显示文本
    const acc = accounts.value.find(a => a.id === o.account_id)
    accountInputText.value = acc ? `${acc.code}${acc.short_name ? ` (${acc.short_name})` : ''}` : ''
  }
  loadOrderProducts(o.id)
}

function clearOrderSelection() {
  form.order_id = ''
  form.refund_amount = null
  orderSearch.value = ''
  orderProducts.value = []
}

// 选中付款账户
function selectAccount(acc) {
  form.refund_from_account_id = acc.id
  accountInputText.value = acc.code + (acc.short_name ? ` (${acc.short_name})` : '')
  showAccountDropdown.value = false
}

const stats = reactive({ count: 0, total: 0, rate: 0 })

const accountsByIP = computed(() => {
  const groups = {}
  for (const acc of accounts.value.filter(a => a.status === 'active')) {
    if (!groups[acc.ip_code]) groups[acc.ip_code] = []
    groups[acc.ip_code].push(acc)
  }
  return groups
})

const selectedOrder = computed(() => {
  if (!form.order_id) return null
  return completedOrders.value.find(o => o.id === form.order_id)
})

// 订单搜索过滤（最近订单优先，已完成排前面）
const filteredOrders = computed(() => {
  let list = completedOrders.value
  if (orderSearch.value) {
    const kw = orderSearch.value.toLowerCase()
    list = list.filter(o =>
      (o.order_no || '').toLowerCase().includes(kw) ||
      (o.customer_name || '').toLowerCase().includes(kw) ||
      (o.product_name || '').toLowerCase().includes(kw)
    )
  }
  return list
})

// 账户搜索过滤（按退款使用频率排序 + 关键词过滤）
const filteredAccountGroups = computed(() => {
  const allGroups = accountsByIP.value
  if (!accountInputText.value) return allGroups

  const kw = accountInputText.value.toLowerCase()
  const filtered = {}
  for (const [ip, accs] of Object.entries(allGroups)) {
    const matched = accs.filter(a =>
      (a.code || '').toLowerCase().includes(kw) ||
      (a.short_name || '').toLowerCase().includes(kw)
    )
    if (matched.length > 0) filtered[ip] = matched
  }
  return filtered
})

async function loadOrderProducts(orderId) {
  try {
    const { data } = await supabase
      .from('order_items')
      .select('id, product_name, quantity, is_gift, sale_price')
      .eq('order_id', orderId)
    orderProducts.value = data || []
  } catch (e) {
    orderProducts.value = []
  }
}

const filteredRefunds = computed(() => {
  let list = refunds.value
  if (filters.status) list = list.filter(r => r.status === filters.status)
  if (search.value) {
    const kw = search.value.toLowerCase()
    list = list.filter(r =>
      (r.refund_no || '').includes(kw) ||
      (r.order_info?.customer_name || '').toLowerCase().includes(kw) ||
      (r.reason || '').toLowerCase().includes(kw) ||
      (r.account_name || '').toLowerCase().includes(kw)
    )
  }
  if (filters.periodType === 'month') {
    const now = new Date()
    const start = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
    list = list.filter(r => r.created_at >= start)
  } else if (filters.periodType === 'quarter') {
    const now = new Date()
    const qStart = Math.floor(now.getMonth() / 3) * 3
    const start = `${now.getFullYear()}-${String(qStart + 1).padStart(2, '0')}-01`
    list = list.filter(r => r.created_at >= start)
  }
  return list
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredRefunds.value.length / pageSize)))
const paginatedItems = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return filteredRefunds.value.slice(start, start + pageSize)
})

async function loadRefunds() {
  loading.value = true
  try {
    const { data } = await supabase
      .from('refunds')
      .select('*, orders!inner(order_no, customer_name, product_name, amount, account_code), refund_from:refund_from_account_id(code)')
      .order('created_at', { ascending: false })
    refunds.value = (data || []).map(r => ({
      ...r,
      order_info: r.orders,
      refund_account_code: r.refund_from?.code || '',
    }))

    // 订单下拉（已完成和部分退款的）
    const { data: orderData } = await supabase
      .from('orders')
      .select('id, order_no, customer_name, product_name, amount, account_code, account_id')
      .in('status', ['completed', 'partially_refunded'])
      .order('created_at', { ascending: false })
      .limit(500)
    completedOrders.value = orderData || []

    // 账户下拉（按退款使用频率排序）
    const { data: accData } = await supabase.from('accounts').select('id, code, short_name, ip_code, balance').eq('status', 'active')
    const allAccs = accData || []
    // 统计退款使用频率
    const { data: refundAccs } = await supabase.from('refunds').select('refund_from_account_id')
    const usageCount = {}
    ;(refundAccs || []).forEach(r => {
      if (r.refund_from_account_id) usageCount[r.refund_from_account_id] = (usageCount[r.refund_from_account_id] || 0) + 1
    })
    // 按使用次数降序排序，同次数按 code 排
    accounts.value = allAccs.sort((a, b) => {
      const aUse = usageCount[a.id] || 0
      const bUse = usageCount[b.id] || 0
      if (bUse !== aUse) return bUse - aUse
      return (a.code || '').localeCompare(b.code || '')
    })
  } catch (e) {
    console.error('Failed to load refunds:', e)
  } finally {
    loading.value = false
  }
}

function calculateStats() {
  const monthStart = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-01`
  const monthData = refunds.value.filter(r => r.created_at >= monthStart)
  stats.count = monthData.length
  stats.total = monthData.reduce((s, r) => s + (r.refund_amount || 0), 0)
  stats.rate = stats.count > 0 ? ((stats.total / (stats.total + 50000)) * 100).toFixed(1) : '0.0'
}

function openRefundModal() {
  form.order_id = ''
  form.refund_amount = null
  form.reason = '客户退货'
  form.custom_reason = ''
  form.refund_from_account_id = ''
  form.note = ''
  orderSearch.value = ''
  accountInputText.value = ''
  orderProducts.value = []
  showOrderDropdown.value = false
  showAccountDropdown.value = false
  showRefundModal.value = true
}

async function handleRefund() {
  if (!form.order_id || !form.refund_amount) return
  if (form.refund_amount <= 0) { toast('退款金额必须大于0', 'warning'); return }
  if (!form.refund_from_account_id) { toast('请选择付款账户', 'warning'); return }

  // 校验累计退款金额不超过订单金额
  if (selectedOrder.value) {
    const { data: existingRefunds } = await supabase.from('refunds')
      .select('refund_amount')
      .eq('order_id', form.order_id)
      .in('status', ['pending', 'processing', 'completed'])
    const alreadyRefunded = (existingRefunds || []).reduce((sum, r) => sum + Number(r.refund_amount), 0)
    const maxRefundable = Number(selectedOrder.value.amount) - alreadyRefunded
    if (form.refund_amount > maxRefundable) {
      toast(`退款金额超出可退上限！订单金额 ¥${selectedOrder.value.amount}，已退/待退 ¥${alreadyRefunded.toFixed(2)}，最多还可退 ¥${maxRefundable.toFixed(2)}`, 'warning')
      return
    }
  }

  submitting.value = true
  try {
    const payload = {
      order_id: form.order_id,
      refund_amount: Number(form.refund_amount),
      reason: form.reason === '其他' ? form.custom_reason : form.reason,
      refund_from_account_id: form.refund_from_account_id,
      status: 'pending',
      created_by: (await supabase.auth.getSession()).data.session?.user?.id,
      note: form.note || null,
    }

    const { data, error } = await supabase
      .from('refunds')
      .insert(payload)
      .select('*, orders!inner(order_no, customer_name, product_name, amount, account_code), refund_from:refund_from_account_id(code)')
      .single()

    if (error) throw error

    // 退款创建为pending状态，审批后才更新订单状态（在process_refund RPC中处理）
    refunds.value.unshift({
      ...data,
      order_info: data.orders,
      refund_account_code: data.refund_from?.code || '',
    })

    showRefundModal.value = false
    calculateStats()

    toast('退款已登记', 'success')
  } catch (e) {
    console.error(e)
    toast('退款登记失败：' + (e.message || ''), 'error')
  } finally {
    submitting.value = false
  }
}

async function handleApproveRefund(r) {
  if (!confirm(`确认审批此退款 ¥${Number(r.refund_amount).toLocaleString()}？审批后将从对应账户扣除余额。`)) return
  try {
    // 审批前读取账户余额
    const accBefore = r.refund_from_account_id ? await getAccountBalance(r.refund_from_account_id) : null

    const { data, error } = await supabase.rpc('process_refund', { p_refund_id: r.id })
    if (error) throw error
    await loadRefunds()
    calculateStats()

    // 操作日志（从数据库查真实余额，不手算）
    try {
      const accAfter = r.refund_from_account_id ? await getAccountBalance(r.refund_from_account_id) : null
      const oldBal = Number(accBefore?.balance ?? 0)
      const newBal = Number(accAfter?.balance ?? oldBal)
      logOperation({
        action: 'approve_refund',
        module: '退款',
        description: `审批退款 ${formatMoneyStr(r.refund_amount)}，原因：${r.reason || ''}${accBefore ? `，账户：${accBefore.name}` : ''}，余额 ${oldBal.toFixed(2)} → ${newBal.toFixed(2)}`,
        detail: { refund_id: r.id, refund_amount: r.refund_amount, reason: r.reason, order_status: data?.order_status },
        amount: -Math.abs(Number(r.refund_amount)),
        accountId: r.refund_from_account_id,
        accountName: accBefore?.name || null,
      })
    } catch (_) {}

    toast('退款已审批通过，订单状态已更新为' + (data?.order_status === 'refunded' ? '已退款' : '部分退款'), 'success')
    // 同步客户数据（退款改变了订单统计）
    supabase.rpc('sync_customers_from_orders').then(() => {})
  } catch (e) {
    toast('审批失败：' + (e.message || ''), 'error')
  }
}

onMounted(() => {
  loadRefunds()
  calculateStats()
})

async function handleDeleteRefund(r) {
  if (!confirm('确定要删除此退款记录吗？')) return
  try {
    const { error } = await supabase.rpc('delete_refund', { p_id: r.id })
    if (error) throw error
    // 仅已完成的退款（completed/processing）才退回余额
    // pending 状态的退款从未扣过余额，删除时不应加回
    let balResult = null
    const refundedStatuses = ['completed', 'processing']
    if (r.refund_from_account_id && r.refund_amount && refundedStatuses.includes(r.status)) {
      try {
        const { useAccountStore } = await import('../stores/accounts')
        balResult = await useAccountStore().updateBalance(r.refund_from_account_id, Number(r.refund_amount))
      } catch (e) { console.warn('余额恢复失败:', e) }
    }
    // 操作日志
    try {
      const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
      const accInfo = r.refund_from_account_id ? await getAccountBalance(r.refund_from_account_id) : null
      const accName = accInfo?.name || ''
      const balText = balResult?.old_balance != null && balResult?.new_balance != null
        ? `，余额 ${Number(balResult.old_balance).toFixed(2)} + ${Math.abs(Number(balResult.new_balance) - Number(balResult.old_balance)).toFixed(2)} → ${Number(balResult.new_balance).toFixed(2)}`
        : ''
      logOperation({
        action: 'delete_refund',
        module: '退款',
        description: `删除退款 ${r.refund_no || ''}，金额 ${Number(r.refund_amount || 0).toFixed(2)}，订单：${r.order_info?.order_no || ''}，账户：${accName}${balText}`,
        detail: { refund_id: r.id, order_no: r.order_info?.order_no, refund_amount: r.refund_amount, account_id: r.refund_from_account_id, account_name: accName, balance_before: balResult?.old_balance, balance_after: balResult?.new_balance },
        amount: r.refund_amount,
        accountId: r.refund_from_account_id,
        accountName: accName,
      })
    } catch (_) {}
    toast('退款已删除', 'success')
    refunds.value = refunds.value.filter(x => x.id !== r.id)
    selectedRefundIds.value = selectedRefundIds.value.filter(id => id !== r.id)
    calculateStats()
  } catch (e) {
    toast(e.message || '操作失败', 'error')
  }
}

async function handleBatchDeleteRefunds() {
  if (!confirm(`确定要删除选中的 ${selectedRefundIds.value.length} 条退款记录吗？`)) return
  // 收集选中的退款信息（用于余额退回和日志记录）
  const selectedRefunds = refunds.value.filter(r => selectedRefundIds.value.includes(r.id))
  try {
    const { data, error } = await supabase.rpc('batch_delete_refunds', { p_ids: selectedRefundIds.value })
    if (error) throw error
    // 退回余额并记录日志
    const { useAccountStore } = await import('../stores/accounts')
    const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
    const refundedStatuses = ['completed', 'processing']
    for (const r of selectedRefunds) {
      let balResult = null
      // 仅已完成的退款才退回余额
      if (r.refund_from_account_id && r.refund_amount && refundedStatuses.includes(r.status)) {
        try { balResult = await useAccountStore().updateBalance(r.refund_from_account_id, Number(r.refund_amount)) } catch (_) {}
      }
      try {
        const accInfo = r.refund_from_account_id ? await getAccountBalance(r.refund_from_account_id) : null
        const accName = accInfo?.name || ''
        const balText = balResult?.old_balance != null && balResult?.new_balance != null
          ? `，余额 ${Number(balResult.old_balance).toFixed(2)} + ${Math.abs(Number(balResult.new_balance) - Number(balResult.old_balance)).toFixed(2)} → ${Number(balResult.new_balance).toFixed(2)}`
          : ''
        logOperation({
          action: 'delete_refund',
          module: '退款',
          description: `[批量删除] 删除退款 ${r.refund_no || ''}，金额 ${Number(r.refund_amount || 0).toFixed(2)}，订单：${r.order_info?.order_no || ''}，账户：${accName}${balText}`,
          detail: { refund_id: r.id, order_no: r.order_info?.order_no, refund_amount: r.refund_amount, account_id: r.refund_from_account_id, account_name: accName, balance_before: balResult?.old_balance, balance_after: balResult?.new_balance },
          amount: r.refund_amount,
          accountId: r.refund_from_account_id,
          accountName: accName,
        })
      } catch (_) {}
    }
    toast(`已删除 ${data?.deleted || 0} 条退款记录`, 'success')
    refunds.value = refunds.value.filter(x => !selectedRefundIds.value.includes(x.id))
    selectedRefundIds.value = []
    calculateStats()
  } catch (e) {
    toast('批量删除失败：' + (e.message || ''), 'error')
  }
}
</script>
