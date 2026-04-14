<template>
  <div class="p-4 md:p-6 space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <h1 class="text-xl font-bold text-gray-800">💰 分红管理</h1>
      <button
        v-if="canEdit"
        @click="showDistributeModal = true"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
      >
        📊 按利润分红
      </button>
    </div>

    <!-- Toast -->
    <Transition name="fade">
      <div v-if="toastMsg"
        class="fixed top-6 left-1/2 -translate-x-1/2 z-[100] px-4 py-2 rounded-lg text-sm font-medium shadow-lg"
        :class="toastType === 'error' ? 'bg-red-500 text-white' : 'bg-green-500 text-white'">
        {{ toastMsg }}
      </div>
    </Transition>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">💰 本年已分红总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(summaryStats.yearPaidTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">{{ currentYear }} 年度</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">👑 任凯智 已分红</div>
        <div class="text-2xl font-bold text-purple-600">{{ formatMoney(summaryStats.yearPaidRen) }}</div>
        <div class="text-xs text-gray-500 mt-1">占比 60%</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">🧑‍💻 王孟南 已分红</div>
        <div class="text-2xl font-bold text-cyan-600">{{ formatMoney(summaryStats.yearPaidWang) }}</div>
        <div class="text-xs text-gray-500 mt-1">占比 40%</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">⏳ 待发放</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(summaryStats.pendingTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">共 {{ summaryStats.pendingCount }} 笔</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap items-center gap-3">
      <select v-model="filterYear"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 bg-white cursor-pointer">
        <option v-for="y in yearOptions" :key="y" :value="y">{{ y }} 年</option>
      </select>
      <div class="flex rounded-lg border border-gray-200 overflow-hidden">
        <button v-for="opt in statusOptions" :key="opt.value"
          @click="filterStatus = opt.value"
          class="px-3 py-1.5 text-sm transition cursor-pointer"
          :class="filterStatus === opt.value ? 'bg-blue-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'">
          {{ opt.label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="text-gray-500">加载中...</div>
    </div>

    <!-- Empty State -->
    <div v-else-if="filteredRecords.length === 0" class="text-center py-20">
      <div class="text-4xl mb-3">💰</div>
      <div class="text-gray-500">暂无分红记录</div>
      <button v-if="canEdit" @click="showDistributeModal = true" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        创建第一笔分红
      </button>
    </div>

    <!-- Desktop Table -->
    <div v-else class="hidden md:block bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full">
        <thead>
          <tr class="bg-gray-50 text-left text-xs text-gray-500">
            <th class="px-4 py-3 font-medium">期间</th>
            <th class="px-4 py-3 font-medium">股东</th>
            <th class="px-4 py-3 font-medium">分红比例</th>
            <th class="px-4 py-3 font-medium text-right">金额</th>
            <th class="px-4 py-3 font-medium">状态</th>
            <th class="px-4 py-3 font-medium">打款日期</th>
            <th class="px-4 py-3 font-medium">备注</th>
            <th class="px-4 py-3 font-medium text-center">操作</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-50">
          <tr v-for="row in filteredRecords" :key="row.id" class="hover:bg-gray-50/50 transition">
            <td class="px-4 py-3 text-sm text-gray-700">{{ row.period || '-' }}</td>
            <td class="px-4 py-3 text-sm">
              <div class="flex items-center gap-2">
                <span class="text-base">{{ row.shareholder_name === '任凯智' ? '👑' : '🧑‍💻' }}</span>
                <span class="font-medium text-gray-800">{{ row.shareholder_name }}</span>
              </div>
            </td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ (Number(row.share_ratio) * 100).toFixed(0) }}%</td>
            <td class="px-4 py-3 text-sm text-right font-semibold text-gray-800">{{ formatMoney(row.amount) }}</td>
            <td class="px-4 py-3">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                :class="row.status === 'paid' ? 'bg-green-50 text-green-700' : 'bg-orange-50 text-orange-700'">
                {{ row.status === 'paid' ? '已发放' : '待发放' }}
              </span>
            </td>
            <td class="px-4 py-3 text-sm text-gray-600">{{ row.pay_date ? formatDate(row.pay_date) : '-' }}</td>
            <td class="px-4 py-3 text-sm text-gray-500 max-w-[150px] truncate">{{ row.note || '-' }}</td>
            <td class="px-4 py-3 text-center">
              <div v-if="row.status === 'pending' && canEdit" class="flex items-center justify-center gap-2">
                <button @click="confirmPay(row)"
                  class="text-xs text-green-600 hover:text-green-700 font-medium cursor-pointer">
                  确认发放
                </button>
                <button @click="softDelete(row)"
                  class="text-xs text-red-500 hover:text-red-600 font-medium cursor-pointer">
                  删除
                </button>
              </div>
              <span v-else class="text-xs text-gray-400">-</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile Card List -->
    <div v-if="!loading && filteredRecords.length > 0" class="md:hidden space-y-3">
      <div v-for="row in filteredRecords" :key="'m-' + row.id"
        class="bg-white rounded-xl border border-gray-100 p-4 hover:shadow-md transition">
        <div class="flex items-start justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="text-base">{{ row.shareholder_name === '任凯智' ? '👑' : '🧑‍💻' }}</span>
            <span class="font-semibold text-gray-800">{{ row.shareholder_name }}</span>
            <span class="text-xs text-gray-400">{{ (Number(row.share_ratio) * 100).toFixed(0) }}%</span>
          </div>
          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
            :class="row.status === 'paid' ? 'bg-green-50 text-green-700' : 'bg-orange-50 text-orange-700'">
            {{ row.status === 'paid' ? '已发放' : '待发放' }}
          </span>
        </div>
        <div class="flex items-baseline gap-1 mb-2">
          <span class="text-sm text-gray-500">¥</span>
          <span class="text-xl font-bold text-gray-800">{{ formatAmount(row.amount) }}</span>
        </div>
        <div class="flex items-center gap-4 text-xs text-gray-500 mb-2">
          <span>📅 {{ row.period || '-' }}</span>
          <span v-if="row.pay_date">💳 {{ formatDate(row.pay_date) }}</span>
        </div>
        <div v-if="row.note" class="text-xs text-gray-500 mb-2 truncate">💬 {{ row.note }}</div>
        <div v-if="row.status === 'pending' && canEdit" class="flex items-center gap-2 pt-2 border-t border-gray-50">
          <button @click="confirmPay(row)"
            class="flex-1 bg-green-50 text-green-700 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-green-100 transition cursor-pointer">
            确认发放
          </button>
          <button @click="softDelete(row)"
            class="flex-1 bg-red-50 text-red-600 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-red-100 transition cursor-pointer">
            删除
          </button>
        </div>
      </div>
    </div>

    <!-- Shareholder Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 rounded-full bg-purple-50 flex items-center justify-center text-lg">👑</div>
          <div>
            <div class="font-semibold text-gray-800">任凯智</div>
            <div class="text-xs text-gray-500">董事长 · 60%</div>
          </div>
        </div>
        <div class="space-y-2">
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">累计分红</span>
            <span class="font-semibold text-purple-600">{{ formatMoney(shareholderSummary.ren.allTimePaid) }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">本年分红</span>
            <span class="font-semibold text-gray-700">{{ formatMoney(shareholderSummary.ren.yearPaid) }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">最近发放日期</span>
            <span class="text-gray-700">{{ shareholderSummary.ren.lastPayDate || '-' }}</span>
          </div>
        </div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="flex items-center gap-3 mb-4">
          <div class="w-10 h-10 rounded-full bg-cyan-50 flex items-center justify-center text-lg">🧑‍💻</div>
          <div>
            <div class="font-semibold text-gray-800">王孟南</div>
            <div class="text-xs text-gray-500">IP · 40%</div>
          </div>
        </div>
        <div class="space-y-2">
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">累计分红</span>
            <span class="font-semibold text-cyan-600">{{ formatMoney(shareholderSummary.wang.allTimePaid) }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">本年分红</span>
            <span class="font-semibold text-gray-700">{{ formatMoney(shareholderSummary.wang.yearPaid) }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-500">最近发放日期</span>
            <span class="text-gray-700">{{ shareholderSummary.wang.lastPayDate || '-' }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Distribute Modal -->
    <div v-if="showDistributeModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showDistributeModal = false">
      <div class="bg-white rounded-2xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">📊 按利润分红</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">分红总额（元）</label>
            <input v-model="distForm.totalAmount" type="number" step="0.01" min="0" placeholder="输入分红总额"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <!-- Auto-calc preview -->
          <div v-if="Number(distForm.totalAmount) > 0" class="bg-blue-50 rounded-lg p-3 space-y-2">
            <div class="flex items-center justify-between text-sm">
              <span class="text-gray-600">👑 任凯智（60%）</span>
              <span class="font-bold text-purple-600">¥{{ formatAmount(Number(distForm.totalAmount) * 0.6) }}</span>
            </div>
            <div class="flex items-center justify-between text-sm">
              <span class="text-gray-600">🧑‍💻 王孟南（40%）</span>
              <span class="font-bold text-cyan-600">¥{{ formatAmount(Number(distForm.totalAmount) * 0.4) }}</span>
            </div>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">分红期间</label>
            <input v-model="distForm.period" type="text" placeholder="如 2026-Q1 或 2026-04"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="distForm.note" rows="2" placeholder="选填"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
        </div>
        <div class="flex gap-3 mt-6">
          <button @click="showDistributeModal = false"
            class="flex-1 bg-gray-100 text-gray-600 py-2.5 rounded-lg text-sm hover:bg-gray-200 transition cursor-pointer">
            取消
          </button>
          <button @click="handleDistribute" :disabled="distributing"
            class="flex-1 bg-blue-600 text-white py-2.5 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer disabled:opacity-50">
            {{ distributing ? '提交中...' : '确认分红' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const canEdit = computed(() => ['admin', 'finance', 'manager'].includes(auth.profile?.role || ''))

// --- Toast ---
const toastMsg = ref('')
const toastType = ref('success')
let toastTimer = null
function toast(msg, type = 'success') {
  toastMsg.value = msg
  toastType.value = type
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastMsg.value = '' }, 2500)
}

// --- State ---
const loading = ref(false)
const records = ref([])
const allRecords = ref([]) // all-time records for shareholder summary
const currentYear = new Date().getFullYear()
const filterYear = ref(currentYear)
const filterStatus = ref('all')
const statusOptions = [
  { label: '全部', value: 'all' },
  { label: '待发放', value: 'pending' },
  { label: '已发放', value: 'paid' },
]

// Year options: current year down to 2020
const yearOptions = computed(() => {
  const years = []
  for (let y = currentYear; y >= 2020; y--) years.push(y)
  return years
})

// --- Distribute Modal ---
const showDistributeModal = ref(false)
const distributing = ref(false)
const distForm = reactive({
  totalAmount: '',
  period: '',
  note: '',
})

// --- Fetch Records ---
async function fetchRecords() {
  loading.value = true
  try {
    const yearStart = `${filterYear.value}-01-01`
    const yearEnd = `${filterYear.value}-12-31`

    const { data, error } = await supabase
      .from('dividends')
      .select('*')
      .is('deleted_at', null)
      .gte('created_at', yearStart)
      .lte('created_at', yearEnd + 'T23:59:59')
      .order('created_at', { ascending: false })

    if (error) throw error
    records.value = data || []
  } catch (e) {
    console.error('Failed to fetch dividends:', e)
    toast('加载分红记录失败', 'error')
  } finally {
    loading.value = false
  }
}

// Fetch all-time records for shareholder summary
async function fetchAllRecords() {
  try {
    const { data, error } = await supabase
      .from('dividends')
      .select('*')
      .is('deleted_at', null)
      .order('created_at', { ascending: false })

    if (error) throw error
    allRecords.value = data || []
  } catch (e) {
    console.error('Failed to fetch all dividends:', e)
  }
}

// --- Filtered Records ---
const filteredRecords = computed(() => {
  if (filterStatus.value === 'all') return records.value
  return records.value.filter(r => r.status === filterStatus.value)
})

// --- Summary Stats (current year view) ---
const summaryStats = computed(() => {
  const yearPaid = records.value.filter(r => r.status === 'paid')
  const yearPaidTotal = yearPaid.reduce((s, r) => s + (Number(r.amount) || 0), 0)
  const yearPaidRen = yearPaid.filter(r => r.shareholder_name === '任凯智').reduce((s, r) => s + (Number(r.amount) || 0), 0)
  const yearPaidWang = yearPaid.filter(r => r.shareholder_name === '王孟南').reduce((s, r) => s + (Number(r.amount) || 0), 0)
  const pending = records.value.filter(r => r.status === 'pending')
  const pendingTotal = pending.reduce((s, r) => s + (Number(r.amount) || 0), 0)
  return {
    yearPaidTotal,
    yearPaidRen,
    yearPaidWang,
    pendingTotal,
    pendingCount: pending.length,
  }
})

// --- Shareholder Summary (all-time + current year) ---
const shareholderSummary = computed(() => {
  function calcShareholder(name) {
    const all = allRecords.value.filter(r => r.shareholder_name === name)
    const paid = all.filter(r => r.status === 'paid')
    const allTimePaid = paid.reduce((s, r) => s + (Number(r.amount) || 0), 0)

    const yearStart = `${currentYear}-01-01`
    const yearPaid = paid.filter(r => r.created_at >= yearStart).reduce((s, r) => s + (Number(r.amount) || 0), 0)

    const sorted = paid.filter(r => r.pay_date).sort((a, b) => b.pay_date.localeCompare(a.pay_date))
    const lastPayDate = sorted.length > 0 ? formatDate(sorted[0].pay_date) : null

    return { allTimePaid, yearPaid, lastPayDate }
  }
  return {
    ren: calcShareholder('任凯智'),
    wang: calcShareholder('王孟南'),
  }
})

// --- Helpers ---
function formatMoney(v) {
  return '¥' + (Number(v) || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatAmount(v) {
  return (Number(v) || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatDate(d) {
  if (!d) return '-'
  return d.slice(0, 10)
}

// --- Distribute ---
async function handleDistribute() {
  const total = Number(distForm.totalAmount)
  if (!total || total <= 0) {
    toast('请输入有效的分红总额', 'error')
    return
  }
  if (!distForm.period?.trim()) {
    toast('请输入分红期间', 'error')
    return
  }

  distributing.value = true
  try {
    const renAmount = Math.round(total * 0.6 * 100) / 100
    const wangAmount = Math.round(total * 0.4 * 100) / 100

    const rows = [
      {
        shareholder_name: '任凯智',
        share_ratio: 0.60,
        amount: renAmount,
        period: distForm.period.trim(),
        status: 'pending',
        note: distForm.note?.trim() || null,
        recorded_by: auth.profile?.id || null,
      },
      {
        shareholder_name: '王孟南',
        share_ratio: 0.40,
        amount: wangAmount,
        period: distForm.period.trim(),
        status: 'pending',
        note: distForm.note?.trim() || null,
        recorded_by: auth.profile?.id || null,
      },
    ]

    const { error } = await supabase.from('dividends').insert(rows)
    if (error) throw error

    toast('分红记录已创建')
    showDistributeModal.value = false
    distForm.totalAmount = ''
    distForm.period = ''
    distForm.note = ''
    await Promise.all([fetchRecords(), fetchAllRecords()])
  } catch (e) {
    console.error('Failed to create dividends:', e)
    toast('创建分红记录失败: ' + (e.message || '未知错误'), 'error')
  } finally {
    distributing.value = false
  }
}

// --- Confirm Pay ---
async function confirmPay(row) {
  if (!confirm(`确认发放 ${row.shareholder_name} 的 ¥${formatAmount(row.amount)} 分红？`)) return

  try {
    const today = new Date().toISOString().split('T')[0]
    const { error } = await supabase
      .from('dividends')
      .update({ status: 'paid', pay_date: today })
      .eq('id', row.id)

    if (error) throw error
    toast('已确认发放')
    await Promise.all([fetchRecords(), fetchAllRecords()])
  } catch (e) {
    console.error('Failed to confirm pay:', e)
    toast('确认发放失败: ' + (e.message || '未知错误'), 'error')
  }
}

// --- Soft Delete ---
async function softDelete(row) {
  if (!confirm(`确认删除 ${row.shareholder_name} 的 ¥${formatAmount(row.amount)} 分红记录？`)) return

  try {
    const { error } = await supabase
      .from('dividends')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', row.id)

    if (error) throw error
    toast('已删除')
    await Promise.all([fetchRecords(), fetchAllRecords()])
  } catch (e) {
    console.error('Failed to delete dividend:', e)
    toast('删除失败: ' + (e.message || '未知错误'), 'error')
  }
}

// --- Watch & Init ---
watch(filterYear, () => fetchRecords())

onMounted(async () => {
  await Promise.all([fetchRecords(), fetchAllRecords()])
})
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
