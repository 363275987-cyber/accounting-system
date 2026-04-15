<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">🏦 股东垫资</h1>
      <button
        @click="openCreateModal"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
      >
        + 新增垫资
      </button>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">💰 垫资总额</div>
        <div class="text-2xl font-bold text-blue-600">{{ formatMoney(stats.totalLoan) }}</div>
        <div class="text-xs text-gray-500 mt-1">共 {{ loans.length }} 笔</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">⏳ 未还总额</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(stats.unpaidAmount) }}</div>
        <div class="text-xs text-gray-500 mt-1">待还款本金</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">📅 累计利息</div>
        <div class="text-2xl font-bold text-red-500">{{ formatMoney(stats.totalInterest) }}</div>
        <div class="text-xs text-gray-500 mt-1">至 {{ todayStr }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">✅ 已还总额</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.totalRepaid) }}</div>
        <div class="text-xs text-gray-500 mt-1">含本金+利息</div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="flex items-center justify-center py-20">
      <div class="text-gray-500">加载中...</div>
    </div>

    <!-- Empty State -->
    <div v-else-if="loans.length === 0" class="text-center py-20">
      <div class="text-4xl mb-3">🏦</div>
      <div class="text-gray-500">暂无垫资记录</div>
      <button @click="openCreateModal" class="mt-3 text-blue-600 text-sm hover:underline cursor-pointer">
        新增第一笔垫资
      </button>
    </div>

    <!-- Loan Cards -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div v-for="loan in loans" :key="loan.id"
        class="bg-white rounded-xl border border-gray-100 p-5 hover:shadow-md transition">
        <!-- Card Header -->
        <div class="flex items-start justify-between mb-3">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-full flex items-center justify-center text-lg"
              :class="loan.shareholder_name === '任凯智' ? 'bg-purple-50' : 'bg-cyan-50'">
              {{ loan.shareholder_name === '任凯智' ? '👑' : '🧑‍💻' }}
            </div>
            <div>
              <div class="font-semibold text-gray-800">{{ loan.shareholder_name }}</div>
              <div class="text-xs text-gray-500">{{ loan.shareholder_name === '任凯智' ? '董事长' : '' }}</div>
            </div>
          </div>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
            :class="statusClass(loan.status)">
            {{ statusLabel(loan.status) }}
          </span>
        </div>

        <!-- Amount -->
        <div class="flex items-baseline gap-1 mb-3">
          <span class="text-sm text-gray-500">¥</span>
          <span class="text-2xl font-bold text-gray-800">{{ formatAmount(loan.loan_amount) }}</span>
          <span class="text-xs text-gray-500 ml-1">年利率 {{ loan.annual_rate }}%</span>
        </div>

        <!-- Date Range -->
        <div class="flex items-center gap-4 text-sm text-gray-500 mb-3">
          <span>📅 {{ formatDate(loan.start_date) }}</span>
          <span>→</span>
          <span>📅 {{ formatDate(loan.end_date) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-3">
          <div class="flex items-center justify-between text-xs mb-1">
            <span class="text-gray-500">还款进度</span>
            <span class="text-gray-600 font-medium">{{ repaymentPercent(loan) }}%</span>
          </div>
          <div class="w-full bg-gray-100 rounded-full h-2">
            <div class="h-2 rounded-full transition-all"
              :class="loan.status === 'repaid' ? 'bg-green-500' : 'bg-blue-500'"
              :style="{ width: repaymentPercent(loan) + '%' }">
            </div>
          </div>
        </div>

        <!-- Repayment Summary -->
        <div class="flex items-center gap-4 text-xs mb-3">
          <div class="flex items-center gap-1 text-green-600">
            <span>已还本金</span>
            <span class="font-semibold">{{ formatMoney(loan.repaid_principal || 0) }}</span>
          </div>
          <div class="flex items-center gap-1 text-orange-500">
            <span>未还本金</span>
            <span class="font-semibold">{{ formatMoney((loan.loan_amount || 0) - (loan.repaid_principal || 0)) }}</span>
          </div>
          <div class="flex items-center gap-1 text-gray-500">
            <span>累计利息</span>
            <span class="font-medium">{{ formatMoney(loan.outstanding_interest || 0) }}</span>
          </div>
        </div>

        <!-- Note -->
        <div v-if="loan.note" class="text-xs text-gray-500 mb-3 truncate">💬 {{ loan.note }}</div>

        <!-- Actions -->
        <div class="flex items-center gap-2 pt-3 border-t border-gray-50">
          <button @click="openRepayModal(loan)"
            class="flex-1 bg-green-50 text-green-700 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-green-100 transition cursor-pointer"
            :disabled="loan.status === 'repaid'">
            💰 还款
          </button>
          <button @click="toggleRepayments(loan)"
            class="flex-1 bg-gray-50 text-gray-600 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-gray-100 transition cursor-pointer">
            📋 还款记录
          </button>
        </div>

        <!-- Repayments List (expandable) -->
        <div v-if="expandedLoanId === loan.id && repayments.length > 0"
          class="mt-3 pt-3 border-t border-gray-50 space-y-2">
          <div v-for="r in repayments" :key="r.id"
            class="flex items-center justify-between bg-gray-50 rounded-lg px-3 py-2 text-xs">
            <div>
              <div class="font-medium text-gray-700">{{ formatDate(r.repayment_date) }}</div>
              <div v-if="r.note" class="text-gray-500 mt-0.5">{{ r.note }}</div>
            </div>
            <div class="text-right">
              <div class="font-semibold text-green-600">{{ formatMoney(r.repayment_amount) }}</div>
              <div v-if="r.interest_amount" class="text-gray-500">利息 {{ formatMoney(r.interest_amount) }}</div>
            </div>
          </div>
        </div>
        <div v-else-if="expandedLoanId === loan.id && repayments.length === 0"
          class="mt-3 pt-3 border-t border-gray-50 text-xs text-gray-500 text-center">
          暂无还款记录
        </div>
      </div>
    </div>

    <!-- Create Loan Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showCreateModal = false">
      <div class="bg-white rounded-2xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">新增垫资</h2>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">股东</label>
            <select v-model="createForm.shareholder_id"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="">请选择股东</option>
              <option v-for="s in shareholders" :key="s.id" :value="s.id">
                {{ s.name }}{{ s.name === '任凯智' ? '（董事长）' : '' }}
              </option>
            </select>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm text-gray-600 mb-1">垫资金额（元）</label>
              <input v-model="createForm.loan_amount" type="number" step="0.01" min="0" placeholder="0.00"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">年利率（%）</label>
              <input v-model="createForm.annual_rate" type="number" step="0.01" min="0" placeholder="0.00"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm text-gray-600 mb-1">起始日期</label>
              <input v-model="createForm.start_date" type="date"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">到期日期</label>
              <input v-model="createForm.end_date" type="date"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">
              公司收款账户 <span class="text-red-500">*</span>
            </label>
            <SearchableSelect
              v-model="createForm.receive_account_id"
              :options="accountOptions"
              label-key="code"
              value-key="id"
              placeholder="请选择公司收款账户"
              search-placeholder="搜索账户名称..."
            />
            <p v-if="!createForm.receive_account_id" class="text-xs text-red-500 mt-1">请选择公司收款账户</p>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="createForm.note" rows="2" placeholder="选填"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
        </div>
        <div class="flex gap-3 mt-6">
          <button @click="showCreateModal = false"
            class="flex-1 bg-gray-100 text-gray-600 py-2 rounded-lg text-sm hover:bg-gray-200 transition cursor-pointer">
            取消
          </button>
          <button @click="handleCreate" :disabled="creating || !createForm.receive_account_id"
            class="flex-1 bg-blue-600 text-white py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
            {{ creating ? '提交中...' : '确认创建' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Repay Modal -->
    <div v-if="showRepayModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showRepayModal = false">
      <div class="bg-white rounded-2xl w-full max-w-md mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-1">还款</h2>
        <p class="text-sm text-gray-500 mb-4">
          {{ repayTarget?.shareholder_name }} · 垫资 ¥{{ formatAmount(repayTarget?.loan_amount) }}
        </p>

        <!-- Interest info -->
        <div v-if="repayInterest !== null" class="bg-amber-50 rounded-lg p-3 mb-4">
          <div class="text-sm text-amber-700">
            <span class="font-medium">截至今天应计利息：</span>
            <span class="font-bold text-lg ml-1">¥{{ formatAmount(repayInterest) }}</span>
          </div>
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">付款账户</label>
            <select v-model="repayForm.account_id"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="">请选择付款账户</option>
              <option v-for="acc in accounts" :key="acc.id" :value="acc.id">{{ acc.short_name || acc.platform || acc.account_name }}（余额 ¥{{ formatMoney(acc.balance) }}）</option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">还款金额（元）</label>
            <input v-model="repayForm.repayment_amount" type="number" step="0.01" min="0" placeholder="0.00"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">本次利息（元）</label>
            <input v-model="repayForm.interest_amount" type="number" step="0.01" min="0" placeholder="自动计算为截至今天的利息"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">还款日期</label>
            <input v-model="repayForm.repayment_date" type="date" :max="todayStr"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="repayForm.note" rows="2" placeholder="选填"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
        </div>
        <div class="flex gap-3 mt-6">
          <button @click="showRepayModal = false"
            class="flex-1 bg-gray-100 text-gray-600 py-2 rounded-lg text-sm hover:bg-gray-200 transition cursor-pointer">
            取消
          </button>
          <button @click="handleRepay" :disabled="repaying"
            class="flex-1 bg-green-600 text-white py-2 rounded-lg text-sm hover:bg-green-700 transition cursor-pointer disabled:opacity-50">
            {{ repaying ? '提交中...' : '确认还款' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useShareholderLoanStore } from '../stores/shareholderLoans'
import { supabase } from '../lib/supabase'
import SearchableSelect from '../components/SearchableSelect.vue'

const store = useShareholderLoanStore()
const loans = computed(() => store.loans)
const repayments = computed(() => store.repayments)

// 账户下拉选项（公司收款账户用，复用 accounts ref 中的数据）
const accountOptions = computed(() => {
  return (accounts.value || []).map(a => ({
    ...a,
    code: `${a.short_name || a.platform || a.account_name}（余额 ¥${Number(a.balance || 0).toFixed(2)}）`,
  }))
})

// --- Modal states ---
const showCreateModal = ref(false)
const showRepayModal = ref(false)
const creating = ref(false)
const repaying = ref(false)
const expandedLoanId = ref(null)
const repayTarget = ref(null)
const repayInterest = ref(null)
const accounts = ref([])

// --- Create form ---
const shareholders = ref([])
const createForm = reactive({
  shareholder_id: '',
  loan_amount: '',
  annual_rate: '',
  start_date: '',
  end_date: '',
  note: '',
  receive_account_id: '',
})

// --- Repay form ---
const repayForm = reactive({
  repayment_amount: '',
  interest_amount: '',
  repayment_date: '',
  account_id: '',
  note: '',
})

// --- Today string ---
const todayStr = computed(() => new Date().toISOString().split('T')[0])

// --- Stats ---
const stats = computed(() => {
  const totalLoan = loans.value.reduce((s, l) => s + (Number(l.loan_amount) || 0), 0)
  const totalRepaid = loans.value.reduce((s, l) => s + (Number(l.repaid_principal) || 0), 0)
  const totalInterest = loans.value.reduce((s, l) => s + (Number(l.outstanding_interest) || 0), 0)
  return {
    totalLoan,
    unpaidAmount: totalLoan - totalRepaid,
    totalInterest,
    totalRepaid,
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

function statusLabel(s) {
  const map = { active: '进行中', repaid: '已还清', partial: '部分还款' }
  return map[s] || s
}

function statusClass(s) {
  const map = {
    active: 'bg-blue-100 text-blue-700',
    repaid: 'bg-green-100 text-green-700',
    partial: 'bg-amber-100 text-amber-700',
  }
  return map[s] || 'bg-gray-100 text-gray-600'
}

function repaymentPercent(loan) {
  const total = Number(loan.loan_amount) || 0
  const repaid = Number(loan.repaid_principal) || 0
  if (total === 0) return 0
  return Math.min(100, Math.round((repaid / total) * 100))
}

// --- Actions ---
function openCreateModal() {
  createForm.shareholder_id = ''
  createForm.loan_amount = ''
  createForm.annual_rate = ''
  createForm.start_date = ''
  createForm.end_date = ''
  createForm.note = ''
  createForm.receive_account_id = ''
  showCreateModal.value = true
}

async function handleCreate() {
  if (!createForm.shareholder_id || !createForm.loan_amount || !createForm.start_date) {
    alert('请填写股东、金额和起始日期')
    return
  }
  if (!createForm.receive_account_id) {
    alert('请选择公司收款账户')
    return
  }
  creating.value = true
  try {
    await store.createLoan({
      shareholder_id: createForm.shareholder_id,
      loan_amount: Number(createForm.loan_amount),
      annual_rate: Number(createForm.annual_rate) || 0,
      start_date: createForm.start_date,
      end_date: createForm.end_date || null,
      note: createForm.note || null,
      status: 'active',
      receive_account_id: createForm.receive_account_id,
    })
    showCreateModal.value = false
    await store.fetchLoans()
  } catch (e) {
    alert('创建失败：' + (e.message || '未知错误'))
  } finally {
    creating.value = false
  }
}

async function openRepayModal(loan) {
  repayTarget.value = loan
  repayForm.repayment_amount = ''
  repayForm.interest_amount = ''
  repayForm.repayment_date = todayStr.value
  repayForm.note = ''
  repayInterest.value = null

  // Try to calculate interest
  try {
    const interest = await store.calculateInterest(loan.id)
    repayInterest.value = interest
    repayForm.interest_amount = interest || ''
  } catch (e) {
    console.warn('Could not calculate interest:', e)
  }

  showRepayModal.value = true
}

async function handleRepay() {
  if (!repayForm.repayment_amount || Number(repayForm.repayment_amount) <= 0) {
    alert('请输入还款金额')
    return
  }
  repaying.value = true
  try {
    const loan = repayTarget.value
    // 校验付款账户
    if (!repayForm.account_id) {
      alert('请选择付款账户')
      repaying.value = false
      return
    }

    // 校验付款账户余额是否充足
    const totalRepayment = Number(repayForm.repayment_amount) + (Number(repayForm.interest_amount) || 0)
    const payAccount = accounts.value.find(a => a.id === repayForm.account_id)
    if (payAccount && Number(payAccount.balance) < totalRepayment) {
      alert(`付款账户余额不足！余额 ¥${Number(payAccount.balance).toFixed(2)}，需要 ¥${totalRepayment.toFixed(2)}`)
      repaying.value = false
      return
    }

    await store.createRepayment({
      loan_id: loan.id,
      repayment_amount: Number(repayForm.repayment_amount),
      principal_amount: Number(repayForm.repayment_amount),
      interest_amount: Number(repayForm.interest_amount) || 0,
      repayment_date: repayForm.repayment_date || todayStr.value,
      account_id: repayForm.account_id,
      note: repayForm.note || null,
    })

    // 扣减付款账户余额（还款本金 + 利息）
    try {
      const { useAccountStore } = await import('../stores/accounts')
      await useAccountStore().updateBalance(repayForm.account_id, -totalRepayment)
      // 刷新账户列表中的余额
      const accIdx = accounts.value.findIndex(a => a.id === repayForm.account_id)
      if (accIdx >= 0) accounts.value[accIdx].balance = Number(accounts.value[accIdx].balance) - totalRepayment
    } catch (e) {
      console.error('还款余额扣减失败，还款记录已保存但余额未扣：', e)
      alert('还款记录已保存，但账户余额扣减失败，请手动调整！')
    }

    // Check if fully repaid → update status
    const newTotalRepaid = (Number(loan.repaid_principal) || 0) + Number(repayForm.repayment_amount)
    const loanAmount = Number(loan.loan_amount) || 0
    let newStatus = 'partial'
    if (newTotalRepaid >= loanAmount) {
      newStatus = 'repaid'
    }
    await store.updateLoan(loan.id, { status: newStatus })

    showRepayModal.value = false
    await store.fetchLoans()
    // Refresh repayments if this loan is expanded
    if (expandedLoanId.value === loan.id) {
      await store.fetchRepayments(loan.id)
    }
  } catch (e) {
    alert('还款失败：' + (e.message || '未知错误'))
  } finally {
    repaying.value = false
  }
}

async function toggleRepayments(loan) {
  if (expandedLoanId.value === loan.id) {
    expandedLoanId.value = null
    return
  }
  expandedLoanId.value = loan.id
  await store.fetchRepayments(loan.id)
}

// --- Init ---
onMounted(async () => {
  store.fetchLoans()
  // profiles 表无 status 列（BUG-12 同因），仅按角色筛
  const { data } = await supabase.from('profiles').select('id, name, role').order('name')
  shareholders.value = (data || []).filter(u => ['admin', 'manager'].includes(u.role))
  // 加载账户列表（用于还款时选择付款账户）
  const { data: accData } = await supabase.from('accounts').select('id, short_name, platform, account_name, balance').eq('status', 'active').order('short_name')
  accounts.value = accData || []
})
</script>
