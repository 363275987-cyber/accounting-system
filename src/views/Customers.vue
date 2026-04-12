<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">👥 客户管理</h1>
      <button @click="openAddModal" class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer">
        + 添加客户
      </button>
    </div>

    <!-- 今日新增客户 -->
    <div v-if="todayNewCustomers > 0" class="bg-white rounded-xl p-3 mb-4 border border-gray-100 flex items-center gap-3">
      <div class="w-1 h-8 rounded-full bg-purple-400"></div>
      <div class="text-sm">
        <span class="text-gray-500">今日新增</span>
        <span class="ml-2 font-semibold text-gray-800">{{ todayNewCustomers }}</span>
        <span class="ml-1 text-gray-500">位客户</span>
      </div>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">客户总数</div>
        <div class="text-2xl font-bold text-gray-800">{{ summary.total_customers }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">本月新增</div>
        <div class="text-2xl font-bold text-blue-600">{{ summary.new_this_month }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">活跃客户 (30天)</div>
        <div class="text-2xl font-bold text-green-600">{{ summary.active_30d }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">客均消费</div>
        <div class="text-2xl font-bold text-purple-600">¥{{ summary.avg_amount }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4">
      <div class="flex items-center gap-3 flex-wrap">
        <div class="flex-1 min-w-[200px]">
          <input
            v-model="searchText"
            @input="debouncedSearch"
            type="text"
            placeholder="搜索手机号 / 姓名..."
            class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="flex gap-1 bg-gray-100 rounded-lg p-0.5">
          <button
            v-for="st in statusOptions" :key="st.value"
            @click="currentStatus = st.value; loadData()"
            class="px-3 py-1.5 rounded-md text-xs transition cursor-pointer"
            :class="currentStatus === st.value ? 'bg-white text-blue-700 font-medium shadow-sm' : 'text-gray-500 hover:text-gray-700'"
          >{{ st.label }}</button>
        </div>
        <select
          v-model="currentTag"
          @change="loadData()"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 bg-white"
        >
          <option value="">全部标签</option>
          <option v-for="tag in allTags" :key="tag" :value="tag">{{ tag }}</option>
        </select>
      </div>
    </div>

    <!-- Customer Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-100 text-xs text-gray-500">
            <th class="text-left px-4 py-3 font-medium">手机号</th>
            <th class="text-left px-4 py-3 font-medium">姓名</th>
            <th class="text-left px-4 py-3 font-medium">最近地址</th>
            <th class="text-right px-4 py-3 font-medium">订单数</th>
            <th class="text-right px-4 py-3 font-medium">总消费</th>
            <th class="text-left px-4 py-3 font-medium">首次下单</th>
            <th class="text-left px-4 py-3 font-medium">最近下单</th>
            <th class="text-center px-4 py-3 font-medium">状态</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="c in customers" :key="c.id"
            @click="openDetail(c.id)"
            class="border-b border-gray-50 hover:bg-blue-50/50 cursor-pointer transition"
          >
            <td class="px-4 py-3 font-mono text-gray-700">{{ c.phone }}</td>
            <td class="px-4 py-3 text-gray-800">{{ c.name || '-' }}</td>
            <td class="px-4 py-3 text-gray-500 max-w-[180px] truncate">{{ c.address || '-' }}</td>
            <td class="px-4 py-3 text-right font-medium">{{ c.total_orders }}</td>
            <td class="px-4 py-3 text-right font-medium text-blue-600">¥{{ Number(c.total_amount).toLocaleString() }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ formatDate(c.first_order_at) }}</td>
            <td class="px-4 py-3 text-gray-600 text-xs">{{ formatDate(c.last_order_at) }}</td>
            <td class="px-4 py-3 text-center">
              <span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium" :class="statusClass(c.status)">{{ statusLabel(c.status) }}</span>
            </td>
          </tr>
          <tr v-if="customers.length === 0">
            <td colspan="8" class="px-4 py-12 text-center text-gray-500">暂无客户数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center" @click.self="showModal = false">
      <div class="absolute inset-0 bg-black/30"></div>
      <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6 mx-4">
        <h3 class="text-lg font-bold text-gray-800 mb-4">{{ editingCustomer ? '编辑客户' : '添加客户' }}</h3>
        <div class="space-y-3">
          <div>
            <label class="block text-xs text-gray-500 mb-1">手机号 <span class="text-red-500">*</span></label>
            <input v-model="form.phone" type="tel" maxlength="11" class="w-full px-3 py-2 border rounded-lg text-sm outline-none focus:ring-2" :class="form.phone && !/^1[3-9]\d{9}$/.test(form.phone) ? 'border-red-300 focus:ring-red-500' : 'border-gray-200 focus:ring-blue-500'" placeholder="11位手机号" />
            <p v-if="form.phone && !/^1[3-9]\d{9}$/.test(form.phone)" class="text-xs text-red-500 mt-0.5">请输入正确的11位手机号</p>
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">姓名</label>
            <input v-model="form.name" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="客户姓名" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">地址</label>
            <input v-model="form.address" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="收货地址" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">标签</label>
            <div class="flex flex-wrap gap-1 mb-1">
              <span v-for="tag in form.tags" :key="tag" class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-50 text-blue-700 rounded text-xs">
                {{ tag }}
                <button @click="removeTag(tag)" class="hover:text-red-500 cursor-pointer">✕</button>
              </span>
            </div>
            <div class="flex gap-1">
              <input v-model="newTag" @keydown.enter.prevent="addTag" class="flex-1 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" placeholder="输入标签" />
              <button @click="addTag" class="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200 cursor-pointer">添加</button>
            </div>
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none" placeholder="备注信息"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button @click="showModal = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer transition">取消</button>
          <button @click="saveCustomer" :disabled="!form.phone.trim()" class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition">保存</button>
        </div>
      </div>
    </div>

    <!-- Customer Detail Slide-over -->
    <div v-if="showDetail" class="fixed inset-0 z-50 flex justify-end" @click.self="showDetail = false">
      <div class="absolute inset-0 bg-black/30"></div>
      <div class="relative bg-white w-full max-w-lg h-full overflow-y-auto shadow-xl">
        <div class="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between">
          <h3 class="text-lg font-bold text-gray-800">客户详情</h3>
          <button @click="showDetail = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <div v-if="detail" class="p-6 space-y-6">
          <!-- Basic Info -->
          <div>
            <h4 class="text-sm font-semibold text-gray-500 mb-3">基本信息</h4>
            <div class="bg-gray-50 rounded-xl p-4 space-y-2">
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">手机号</span>
                <span class="font-mono">{{ detail.customer.phone }}</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">姓名</span>
                <span>{{ detail.customer.name || '-' }}</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">地址</span>
                <span class="text-right max-w-[60%]">{{ detail.customer.address || '-' }}</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">来源</span>
                <span>{{ sourceLabel(detail.customer.source) }}</span>
              </div>
              <div class="flex justify-between text-sm items-center">
                <span class="text-gray-500">标签</span>
                <div class="flex items-center gap-1 flex-wrap justify-end">
                  <span v-for="tag in detail.customer.tags" :key="tag" class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-50 text-blue-700 rounded text-xs">
                    {{ tag }}
                    <button @click="removeDetailTag(tag)" class="hover:text-red-500 cursor-pointer">✕</button>
                  </span>
                  <button @click="showTagInput = !showTagInput" class="text-blue-500 hover:text-blue-700 text-xs cursor-pointer">+ 加标签</button>
                </div>
              </div>
              <!-- Inline tag input -->
              <div v-if="showTagInput" class="flex gap-1">
                <input v-model="newDetailTag" @keydown.enter.prevent="addDetailTag" class="flex-1 px-2 py-1 border border-gray-200 rounded text-xs outline-none" placeholder="标签名" />
                <button @click="addDetailTag" class="px-2 py-1 bg-blue-50 text-blue-600 rounded text-xs cursor-pointer hover:bg-blue-100">确认</button>
              </div>
              <div class="flex justify-between text-sm items-center">
                <span class="text-gray-500">状态</span>
                <select
                  v-model="detail.customer.status"
                  @change="updateStatus(detail.customer.status)"
                  class="px-2 py-1 border border-gray-200 rounded text-xs bg-white outline-none"
                >
                  <option value="active">活跃</option>
                  <option value="inactive">沉默</option>
                  <option value="churned">流失</option>
                  <option value="blacklist">黑名单</option>
                </select>
              </div>
              <div v-if="detail.customer.note || detail.customer.lesson_note" class="text-sm">
                <span class="text-gray-500">备注：</span>
                <span class="text-gray-600">{{ detail.customer.note || '-' }}</span>
              </div>
              <div class="flex justify-between text-sm items-center">
                <span class="text-gray-500">是否学员</span>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" v-model="detail.customer.is_student" @change="toggleStudent" class="rounded" />
                  <span :class="detail.customer.is_student ? 'text-blue-600 font-medium' : 'text-gray-500'">{{ detail.customer.is_student ? '是' : '否' }}</span>
                </label>
              </div>
              <div v-if="detail.customer.is_student" class="flex justify-between text-sm items-center">
                <span class="text-gray-500">私教课次数</span>
                <div class="flex items-center gap-2">
                  <button @click="updateLessonCount(-1)" class="w-6 h-6 rounded bg-gray-100 hover:bg-gray-200 flex items-center justify-center text-gray-600 cursor-pointer">-</button>
                  <span class="font-bold text-blue-600 w-6 text-center">{{ detail.customer.lesson_count || 0 }}</span>
                  <button @click="updateLessonCount(1)" class="w-6 h-6 rounded bg-blue-50 hover:bg-blue-100 flex items-center justify-center text-blue-600 cursor-pointer">+</button>
                </div>
              </div>
            </div>
          </div>

          <!-- Stats -->
          <div>
            <h4 class="text-sm font-semibold text-gray-500 mb-3">消费统计</h4>
            <div class="grid grid-cols-2 gap-3">
              <div class="bg-gray-50 rounded-xl p-3 text-center">
                <div class="text-xs text-gray-500">总订单</div>
                <div class="text-xl font-bold text-gray-800">{{ detail.customer.total_orders }}</div>
              </div>
              <div class="bg-gray-50 rounded-xl p-3 text-center">
                <div class="text-xs text-gray-500">总金额</div>
                <div class="text-xl font-bold text-blue-600">¥{{ Number(detail.customer.total_amount).toLocaleString() }}</div>
              </div>
              <div class="bg-gray-50 rounded-xl p-3 text-center">
                <div class="text-xs text-gray-500">客均单价</div>
                <div class="text-xl font-bold text-purple-600">¥{{ detail.avg_order_amount }}</div>
              </div>
              <div class="bg-gray-50 rounded-xl p-3 text-center">
                <div class="text-xs text-gray-500">退款次数/金额</div>
                <div class="text-sm font-bold text-red-500">{{ detail.refunds.length }}次 / ¥{{ detail.refunds.reduce((s, r) => s + Number(r.refund_amount), 0).toLocaleString() }}</div>
              </div>
            </div>
            <div class="flex justify-between text-xs text-gray-500 mt-2 px-1">
              <span>首次下单：{{ formatDate(detail.customer.first_order_at) }}</span>
              <span>最近下单：{{ formatDate(detail.customer.last_order_at) }}</span>
            </div>
          </div>

          <!-- Trend -->
          <div v-if="detail.trend && detail.trend.length > 0">
            <h4 class="text-sm font-semibold text-gray-500 mb-3">消费趋势</h4>
            <div class="bg-gray-50 rounded-xl p-4">
              <div class="space-y-2">
                <div v-for="t in detail.trend" :key="t.month" class="flex items-center gap-3 text-sm">
                  <span class="text-gray-500 text-xs w-16 flex-shrink-0">{{ t.month }}</span>
                  <div class="flex-1 bg-gray-200 rounded-full h-4 overflow-hidden">
                    <div
                      class="bg-blue-500 h-full rounded-full transition-all"
                      :style="{ width: trendWidth(t.amount) + '%' }"
                    ></div>
                  </div>
                  <span class="text-gray-600 text-xs w-20 text-right flex-shrink-0">
                    {{ t.orders }}单 ¥{{ Number(t.amount).toLocaleString() }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Orders -->
          <div>
            <h4 class="text-sm font-semibold text-gray-500 mb-3">订单记录 ({{ detail.orders.length }})</h4>
            <div class="space-y-2">
              <div v-for="o in detail.orders" :key="o.id" class="bg-gray-50 rounded-lg p-3">
                <div class="flex items-center justify-between mb-1">
                  <span class="font-mono text-xs text-gray-500">{{ o.order_no }}</span>
                  <span class="text-xs text-gray-500">{{ formatDate(o.created_at) }}</span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span>{{ o.product_name }}</span>
                  <span class="font-medium text-blue-600">¥{{ Number(o.amount).toLocaleString() }}</span>
                </div>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-xs px-1.5 py-0.5 rounded" :class="orderStatusClass(o.status)">{{ orderStatusLabel(o.status) }}</span>
                  <span class="text-xs text-gray-500">{{ sourceLabel(o.order_source) }}</span>
                </div>
              </div>
              <div v-if="detail.orders.length === 0" class="text-center text-gray-500 text-sm py-4">暂无订单</div>
            </div>
          </div>

          <!-- Refunds -->
          <div v-if="detail.refunds && detail.refunds.length > 0">
            <h4 class="text-sm font-semibold text-gray-500 mb-3">退款记录</h4>
            <div class="space-y-2">
              <div v-for="r in detail.refunds" :key="r.refund_no" class="bg-red-50 rounded-lg p-3">
                <div class="flex items-center justify-between text-sm">
                  <span class="font-mono text-xs">{{ r.refund_no }}</span>
                  <span class="font-medium text-red-600">-¥{{ Number(r.refund_amount).toLocaleString() }}</span>
                </div>
                <div class="text-xs text-gray-500 mt-1">{{ r.reason || '无原因' }} · {{ formatDate(r.created_at) }}</div>
              </div>
            </div>
          </div>
        </div>
        <!-- Loading state -->
        <div v-else class="p-6 text-center text-gray-500">加载中...</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { usePermission } from '../composables/usePermission'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const { canDelete, loadRole } = usePermission()

const customers = ref([])
const summary = reactive({ total_customers: 0, new_this_month: 0, active_30d: 0, avg_amount: 0 })
const todayNewCustomers = ref(0)
const searchText = ref('')
const currentStatus = ref('')
const currentTag = ref('')
const allTags = ref([])
const showModal = ref(false)
const editingCustomer = ref(null)
const showDetail = ref(false)
const detail = ref(null)
const detailId = ref(null)
const showTagInput = ref(false)
const newTag = ref('')
const newDetailTag = ref('')
const form = reactive({ phone: '', name: '', address: '', tags: [], note: '' })

const statusOptions = [
  { value: '', label: '全部' },
  { value: 'active', label: '活跃' },
  { value: 'inactive', label: '沉默' },
  { value: 'churned', label: '流失' },
  { value: 'blacklist', label: '黑名单' },
]

const STATUS_MAP = {
  active: { label: '活跃', cls: 'bg-green-50 text-green-700' },
  inactive: { label: '沉默', cls: 'bg-yellow-50 text-yellow-700' },
  churned: { label: '流失', cls: 'bg-gray-100 text-gray-500' },
  blacklist: { label: '黑名单', cls: 'bg-red-50 text-red-700' },
}

const SOURCE_MAP = {
  sales_guided: '销售引导',
  organic: '自然进店',
  cs_service: '客服服务',
  repeat: '回头客',
}

function statusLabel(s) { return STATUS_MAP[s]?.label || s || '未知' }
function statusClass(s) { return STATUS_MAP[s]?.cls || 'bg-gray-100 text-gray-500' }
function sourceLabel(s) { return SOURCE_MAP[s] || s || '-' }

function orderStatusLabel(s) {
  const map = { completed: '已完成', pending: '待确认', cancelled: '已取消', refunding: '退款中', partially_refunded: '部分退款', refunded: '已全退款' }
  return map[s] || s
}
function orderStatusClass(s) {
  const map = { completed: 'bg-green-50 text-green-700', pending: 'bg-yellow-50 text-yellow-700', cancelled: 'bg-gray-100 text-gray-500', refunding: 'bg-red-50 text-red-600', partially_refunded: 'bg-amber-50 text-amber-600', refunded: 'bg-red-50 text-red-600' }
  return map[s] || 'bg-gray-100 text-gray-500'
}

function formatDate(d) {
  if (!d) return '-'
  const dt = new Date(d)
  return `${dt.getMonth() + 1}/${dt.getDate()} ${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}`
}

function trendWidth(amount) {
  if (!detail.value?.trend?.length) return 0
  const max = Math.max(...detail.value.trend.map(t => Number(t.amount)), 1)
  return Math.max((Number(amount) / max) * 100, 2)
}

// Debounce search
let searchTimer = null
function debouncedSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => loadData(), 300)
}

async function loadSummary() {
  const { data, error } = await supabase.rpc('get_customer_summary')
  if (error) {
    console.error('[Customers] loadSummary error:', error)
    return
  }
  if (data) {
    Object.assign(summary, data)
  }
}

async function loadTodayNewCustomers() {
  try {
    const now = new Date()
    let dayStart
    if (now.getHours() < 6) {
      dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 6, 0, 0)
    } else {
      dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 6, 0, 0)
    }
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + 1)
    const { count } = await supabase
      .from('customers')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', dayStart.toISOString())
      .lte('created_at', dayEnd.toISOString())
    todayNewCustomers.value = count || 0
  } catch (e) {
    console.error('加载今日新增客户失败:', e)
  }
}

async function loadData() {
  const { data, error } = await supabase.rpc('get_customer_stats', {
    p_search: searchText.value,
    p_status: currentStatus.value,
    p_tag: currentTag.value,
    p_limit: 200,
    p_offset: 0,
  })
  if (error) {
    console.error('[Customers] loadData error:', error)
    return
  }
  customers.value = data || []
  // Collect all unique tags
  const tagSet = new Set()
  ;(data || []).forEach(c => {
    if (c.tags && Array.isArray(c.tags)) c.tags.forEach(t => tagSet.add(t))
  })
  allTags.value = [...tagSet].sort()
}

function openAddModal() {
  editingCustomer.value = null
  Object.assign(form, { phone: '', name: '', address: '', tags: [], note: '' })
  newTag.value = ''
  showModal.value = true
}

function openEditModal(c) {
  editingCustomer.value = c
  Object.assign(form, { phone: c.phone, name: c.name || '', address: c.address || '', tags: [...(c.tags || [])], note: c.note || '' })
  newTag.value = ''
  showModal.value = true
}

function addTag() {
  const t = newTag.value.trim()
  if (t && !form.tags.includes(t)) {
    form.tags.push(t)
    newTag.value = ''
  }
}

function removeTag(tag) {
  form.tags = form.tags.filter(t => t !== tag)
}

async function saveCustomer() {
  if (!form.phone.trim()) return
  if (!/^1[3-9]\d{9}$/.test(form.phone.trim())) {
    toast('请输入正确的11位手机号', 'error')
    return
  }
  const payload = {
    phone: form.phone.trim(),
    name: form.name.trim() || null,
    address: form.address.trim() || null,
    tags: form.tags,
    note: form.note.trim() || null,
  }
  if (editingCustomer.value) {
    const { error } = await supabase.from('customers').update(payload).eq('id', editingCustomer.value.id)
    if (error) return alert('保存失败：' + error.message)
  } else {
    const { error } = await supabase.from('customers').insert(payload)
    if (error) return alert('添加失败：' + error.message)
  }
  showModal.value = false
  await loadData()
  await loadSummary()
}

async function openDetail(id) {
  detailId.value = id
  detail.value = null
  showDetail.value = true
  showTagInput.value = false
  newDetailTag.value = ''
  try {
    const { data, error } = await supabase.rpc('get_customer_detail', { p_customer_id: id })
    if (error) {
      console.error('get_customer_detail error:', error)
      alert('加载客户详情失败: ' + error.message)
      return
    }
    if (!data) {
      alert('未找到客户详情数据')
      return
    }
    detail.value = data
  } catch (e) {
    console.error('openDetail exception:', e)
    alert('加载异常: ' + (e.message || '未知错误'))
  }
}

async function addDetailTag() {
  const t = newDetailTag.value.trim()
  if (!t || !detail.value) return
  const tags = [...(detail.value.customer.tags || [])]
  if (tags.includes(t)) { newDetailTag.value = ''; return }
  tags.push(t)
  const { error } = await supabase.from('customers').update({ tags }).eq('id', detailId.value)
  if (!error) {
    detail.value.customer.tags = tags
    newDetailTag.value = ''
    await loadData()
  }
}

async function removeDetailTag(tag) {
  if (!detail.value) return
  const tags = detail.value.customer.tags.filter(t => t !== tag)
  const { error } = await supabase.from('customers').update({ tags }).eq('id', detailId.value)
  if (!error) {
    detail.value.customer.tags = tags
    await loadData()
  }
}

async function updateStatus(status) {
  if (!detailId.value) return
  await supabase.from('customers').update({ status }).eq('id', detailId.value)
  await loadData()
}

async function toggleStudent() {
  if (!detailId.value) return
  await supabase.from('customers').update({ is_student: detail.value.customer.is_student }).eq('id', detailId.value)
  await loadData()
}

async function updateLessonCount(delta) {
  if (!detailId.value || !detail.value) return
  const newCount = Math.max(0, (detail.value.customer.lesson_count || 0) + delta)
  detail.value.customer.lesson_count = newCount
  await supabase.from('customers').update({ lesson_count: newCount }).eq('id', detailId.value)
}

function initLoad() {
  loadSummary()
  loadData()
  loadTodayNewCustomers()
  // 后台同步（不阻塞页面加载）
  supabase.rpc('sync_customers_from_orders').then(() => {}).catch(() => {})
}

onMounted(() => {
  if (auth.isLoggedIn) {
    initLoad()
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { initLoad(); unwatch() }
    })
  }
})
</script>
