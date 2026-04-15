<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">📊 余额快照（月度对账）</h1>
      <!-- Manual settle button (admin only) -->
      <button v-if="auth.isAdmin" @click="showSettleModal = true"
        class="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-purple-700 transition">
        🔧 手动结算
      </button>
    </div>

    <!-- Month Selector -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6 flex gap-3 items-center">
      <button @click="prevMonth" class="px-3 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50 cursor-pointer" :disabled="loading">← 上月</button>
      <span class="text-sm font-medium text-gray-700">{{ periodLabel }}</span>
      <button @click="nextMonth" class="px-3 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50 cursor-pointer" :disabled="loading">下月 →</button>
      <span class="ml-auto text-xs text-gray-500" v-if="currentSnapshot">
        状态：{{ currentSnapshot.status === 'confirmed' ? '✅ 已确认' : '📝 待确认' }}
      </span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
      <div class="text-2xl mb-2 animate-pulse">📊</div>
      <div class="text-gray-500">加载快照数据...</div>
    </div>

    <template v-else>
      <!-- No snapshot -->
      <div v-if="!currentSnapshot" class="bg-white rounded-xl border border-100 p-12 text-center">
        <div class="text-4xl mb-3">📋</div>
        <p class="text-gray-500 mb-4">本月暂无快照数据</p>
        <button @click="generateSnapshot"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
          生成快照
        </button>
        <p class="text-xs text-gray-500 mt-2">自动从上月结余计算期初余额</p>
      </div>

      <!-- Snapshot Detail -->
      <template v-else>
        <!-- Account Selection -->
        <div class="bg-white rounded-xl border border-gray-100 p-4 mb-6">
          <label class="text-sm font-medium text-gray-700 mb-2">查看账户</label>
          <div class="flex flex-wrap gap-2">
            <button v-for="snap in allSnapshots" :key="snap.account_id"
              @click="selectAccount(snap.account_id)"
              class="px-3 py-1.5 text-xs rounded-lg border cursor-pointer transition"
              :class="selectedAccountId === snap.account_id
                ? 'bg-blue-600 text-white border-blue-600'
                : 'border-gray-200 text-gray-600 hover:bg-gray-50'">
              {{ snap.account_code }}
              <span class="ml-1 opacity-60">{{ formatMoney(snap.closing_balance) }}</span>
            </button>
          </div>
        </div>

        <!-- Balance Card -->
        <div class="bg-white rounded-xl border border-gray-100 p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-bold text-gray-700">{{ currentSnapshot.account_code }} — {{ periodLabel }}</h2>
            <div v-if="auth.isAdmin" class="flex gap-2">
              <button v-if="currentSnapshot.status === 'open'" @click="confirmSnapshot"
                class="px-3 py-1.5 bg-green-600 text-white rounded-lg text-xs hover:bg-green-700 cursor-pointer">
                ✅ 确认
              </button>
              <button @click="showAdjustModal = true"
                class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer">
                ✏️ 调整期初余额
              </button>
            </div>
          </div>

          <div class="space-y-3">
            <div class="flex justify-between items-center py-2 border-b border-gray-50">
              <span class="text-gray-600 text-sm">期初余额</span>
              <span class="font-medium text-gray-800">{{ formatMoney(currentSnapshot.opening_balance) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-green-600">
              <span class="text-sm">+ 订单收入</span>
              <span>+{{ formatMoney(currentSnapshot.total_income) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-red-500">
              <span class="text-sm">- 支出</span>
              <span>-{{ formatMoney(currentSnapshot.total_expense) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-red-400">
              <span class="text-sm">- 退款</span>
              <span>-{{ formatMoney(currentSnapshot.total_refund) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-blue-600">
              <span class="text-sm">+ 转入</span>
              <span>+{{ formatMoney(currentSnapshot.transfer_in) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-blue-400">
              <span class="text-sm">- 转出</span>
              <span>-{{ formatMoney(currentSnapshot.transfer_out) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-50 text-gray-500">
              <span class="text-sm">- 手续费</span>
              <span>-{{ formatMoney(currentSnapshot.transfer_fee) }}</span>
            </div>
            <div v-if="currentSnapshot.admin_adjustment !== 0" class="flex justify-between items-center py-2 border-b border-gray-50 text-purple-600">
              <span class="text-sm">± 管理调整</span>
              <span>{{ formatMoney(currentSnapshot.admin_adjustment) }}</span>
              <span v-if="currentSnapshot.admin_reason" class="text-xs opacity-60 ml-1">({{ currentSnapshot.admin_reason }})</span>
            </div>
            <div class="flex justify-between items-center py-2">
              <span class="font-bold text-lg text-gray-800">期末余额（系统计算）</span>
              <span class="font-bold text-2xl"
                :class="currentSnapshot.closing_balance >= 0 ? 'text-green-600' : 'text-red-500'">
                {{ formatMoney(currentSnapshot.closing_balance) }}
              </span>
            </div>
          </div>
        </div>

        <!-- ===== 对账区域 ===== -->
        <div class="bg-white rounded-xl border-2 p-6 mb-6"
          :class="reconStatus === 'matched' ? 'border-green-300' : reconStatus === 'mismatch' ? 'border-red-300' : 'border-gray-200'">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-bold text-gray-700">🔍 月底对账</h2>
            <span v-if="reconStatus === 'matched'" class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full">✅ 已对平</span>
            <span v-else-if="reconStatus === 'mismatch'" class="text-xs bg-red-100 text-red-700 px-2 py-1 rounded-full">❌ 有差额</span>
            <span v-else class="text-xs bg-gray-100 text-gray-500 px-2 py-1 rounded-full">待对账</span>
          </div>

          <!-- 对比区域 -->
          <div class="grid grid-cols-3 gap-4 mb-4">
            <div class="text-center p-4 bg-gray-50 rounded-lg">
              <div class="text-xs text-gray-500 mb-1">系统计算</div>
              <div class="text-lg font-bold text-gray-800">{{ formatMoney(currentSnapshot.closing_balance) }}</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-lg">
              <div class="text-xs text-gray-500 mb-1">实际余额</div>
              <div v-if="editingActual" class="flex items-center gap-1 justify-center">
                <span class="text-xs text-gray-500">¥</span>
                <input v-model.number="actualInput" type="number" step="0.01"
                  class="w-28 px-2 py-1 border border-gray-300 rounded text-lg font-bold text-center outline-none focus:ring-2 focus:ring-blue-400"
                  @keyup.enter="saveActual" @keyup.escape="cancelActual">
              </div>
              <div v-else class="text-lg font-bold"
                :class="currentSnapshot.actual_balance != null ? 'text-gray-800' : 'text-gray-500'">
                {{ currentSnapshot.actual_balance != null ? formatMoney(currentSnapshot.actual_balance) : '未填写' }}
                <button @click="startEditActual" class="ml-1 text-blue-500 hover:text-blue-700 cursor-pointer">✏️</button>
              </div>
            </div>
            <div class="text-center p-4 rounded-lg"
              :class="reconStatus === 'matched' ? 'bg-green-50' : reconStatus === 'mismatch' ? 'bg-red-50' : 'bg-gray-50'">
              <div class="text-xs text-gray-500 mb-1">差额</div>
              <div class="text-lg font-bold"
                :class="reconStatus === 'matched' ? 'text-green-600' : reconStatus === 'mismatch' ? 'text-red-600' : 'text-gray-500'">
                {{ currentSnapshot.actual_balance != null ? (currentSnapshot.balance_diff > 0 ? '+' : '') + formatMoney(currentSnapshot.balance_diff) : '—' }}
              </div>
            </div>
          </div>

          <!-- 差额说明 -->
          <div class="mb-4">
            <label class="block text-xs font-medium text-gray-600 mb-1">差额说明（选填）</label>
            <textarea v-model="diffReasonInput" rows="2" placeholder="例如：微信提现手续费未记录、银行扣了年费..."
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-400 resize-none"></textarea>
          </div>

          <!-- 操作按钮 -->
          <div class="flex gap-2">
            <button v-if="editingActual" @click="saveActual"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
              💾 保存对账
            </button>
            <button v-else @click="startEditActual"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
              📝 填写实际余额
            </button>
            <button v-if="editingActual" @click="cancelActual"
              class="px-4 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50 cursor-pointer">
              取消
            </button>
            <button v-if="reconStatus === 'mismatch' && !editingActual" @click="showDetailDrilldown = !showDetailDrilldown"
              class="px-4 py-2 border border-orange-200 bg-orange-50 text-orange-700 rounded-lg text-sm hover:bg-orange-100 cursor-pointer">
              📋 查看明细
            </button>
          </div>

          <!-- 明细展开区域 -->
          <div v-if="showDetailDrilldown" class="mt-4 border-t border-gray-100 pt-4">
            <DrilldownDetail :account-id="selectedAccountId" :period="currentMonth" />
          </div>
        </div>

        <!-- History Settlement Records -->
        <div class="bg-white rounded-xl border border-gray-100 p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-bold text-gray-700">📜 历史结算记录</h2>
            <button v-if="historyPage > 0" @click="loadHistory(historyPage - 1)"
              class="text-xs text-blue-600 hover:text-blue-800 cursor-pointer">← 上一页</button>
          </div>

          <div v-if="historyLoading" class="text-center text-gray-500 py-4">
            <div class="animate-pulse">加载中...</div>
          </div>

          <div v-else-if="settlementHistory.length === 0" class="text-center text-gray-500 py-6">
            <div class="text-2xl mb-2">📭</div>
            <p>暂无结算记录</p>
          </div>

          <div v-else class="space-y-3">
            <div v-for="record in settlementHistory" :key="record.id"
              class="border border-gray-50 rounded-lg p-3 hover:bg-gray-50 transition">
              <div class="flex items-center justify-between mb-2">
                <span class="font-medium text-gray-700">{{ record.account_code }}</span>
                <span class="text-xs text-gray-500">{{ formatDate(record.settlement_date, 'date') }}</span>
              </div>
              <div class="flex items-center justify-between text-sm">
                <span class="text-gray-500">期初：<span class="text-gray-700">{{ formatMoney(record.opening_balance) }}</span></span>
                <span class="text-gray-500">→</span>
                <span class="text-gray-500">期末：<span class="font-medium" :class="record.closing_balance >= 0 ? 'text-green-600' : 'text-red-500'">{{ formatMoney(record.closing_balance) }}</span></span>
              </div>
            </div>
            <div v-if="settlementHistory.length >= 20" class="text-center">
              <button @click="loadHistory(historyPage + 1)"
                class="text-xs text-blue-600 hover:text-blue-800 cursor-pointer">加载更多 →</button>
            </div>
          </div>
        </div>

        <!-- Adjustment Modal -->
        <div v-if="showAdjustModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showAdjustModal = false">
          <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm mx-4 max-h-[85vh] flex flex-col overflow-hidden">
            <div class="px-6 py-4 border-b border-gray-100 shrink-0">
              <h2 class="font-bold text-gray-800">调整期初余额</h2>
              <p class="text-xs text-red-500 mt-1">⚠️ 仅老板权限，调整后不可撤回，会记录调整原因</p>
            </div>
            <div class="p-6 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">当前期初余额</label>
                <div class="px-3 py-2 bg-gray-50 rounded-lg text-sm text-gray-700">{{ formatMoney(currentSnapshot.opening_balance) }}</div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">调整为 <span class="text-red-400">*</span></label>
                <div class="relative">
                  <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">¥</span>
                  <input v-model.number="adjustAmount" type="number" required placeholder="0.00"
                    class="w-full pl-8 pr-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-red-500">
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">调整原因 <span class="text-red-400">*</span></label>
                <textarea v-model="adjustReason" rows="2" placeholder="必填" required
                  class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
              </div>
              <div class="flex gap-2">
                <button @click="showAdjustModal = false"
                  class="flex-1 py-2 border border-gray-200 rounded-lg text-sm hover:bg-gray-50 cursor-pointer">取消</button>
                <button @click="handleAdjust" class="flex-1 py-2 bg-red-600 text-white rounded-lg text-sm hover:bg-red-700 cursor-pointer">
                  确认调整
                </button>
              </div>
            </div>
          </div>
        </div>
      </template>
    </template>

    <!-- ===== Manual Settlement Modal ===== -->
    <Teleport to="body">
      <div v-if="showSettleModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" @click.self="showSettleModal = false">
        <div class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
          <!-- Modal Header -->
          <div class="flex items-center justify-between p-5 border-b border-gray-100">
            <h2 class="text-lg font-bold text-gray-800">🔧 手动结算</h2>
            <button @click="closeSettleModal" class="text-gray-500 hover:text-gray-600 text-xl">✕</button>
          </div>

          <!-- Modal Body -->
          <div class="p-5 space-y-4">
            <p class="text-sm text-gray-500">
              选择结算月份，系统将为所有账户结算当月余额，生成期初/期末快照记录。
            </p>

            <!-- Settlement date picker -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">结算月份</label>
              <input v-model="settleMonth" type="month"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500">
            </div>

            <!-- Settling status -->
            <div v-if="settling" class="flex items-center gap-3 p-3 bg-purple-50 rounded-lg">
              <div class="animate-spin text-purple-600">⏳</div>
              <span class="text-sm text-purple-700">正在结算中，请稍候...</span>
            </div>

            <!-- Settlement results -->
            <div v-if="settleResults.length > 0" class="space-y-2 max-h-60 overflow-y-auto">
              <div class="text-sm font-medium text-gray-700">结算结果</div>
              <div v-for="r in settleResults" :key="r.account_id"
                class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg text-sm">
                <span class="font-medium text-gray-700">{{ r.account_code }}</span>
                <div class="flex items-center gap-3 text-xs">
                  <span class="text-gray-500">期初 {{ formatMoney(r.opening_balance) }}</span>
                  <span class="text-gray-500">→</span>
                  <span class="font-medium" :class="r.closing_balance >= 0 ? 'text-green-600' : 'text-red-500'">
                    期末 {{ formatMoney(r.closing_balance) }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Error -->
            <div v-if="settleError" class="p-3 bg-red-50 rounded-lg text-sm text-red-600">
              ❌ {{ settleError }}
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="flex justify-end gap-3 p-5 border-t border-gray-100 shrink-0">
            <button @click="closeSettleModal"
              class="px-4 py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition">
              关闭
            </button>
            <button @click="executeSettle" :disabled="settling || !settleMonth"
              class="px-4 py-2 text-sm text-white bg-purple-600 rounded-lg hover:bg-purple-700 transition disabled:opacity-50 disabled:cursor-not-allowed">
              {{ settling ? '结算中...' : '开始结算' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, toast, formatDate } from '../lib/utils'
import DrilldownDetail from '../components/DrilldownDetail.vue'

const auth = useAuthStore()
const loading = ref(true)
const showAdjustModal = ref(false)
const adjustAmount = ref(null)
const adjustReason = ref('')
const selectedAccountId = ref(null)
const snapshots = ref([])
const currentMonth = ref('')

// --- Settlement modal state ---
const showSettleModal = ref(false)
const settleMonth = ref('')
const settling = ref(false)
const settleResults = ref([])
const settleError = ref('')

// --- History state ---
const settlementHistory = ref([])
const historyLoading = ref(false)
const historyPage = ref(0)

const currentSnapshot = computed(() => {
  if (!selectedAccountId.value) return snapshots.value[0] || null
  return snapshots.value.find(s => s.account_id === selectedAccountId.value) || null
})

const allSnapshots = computed(() => snapshots.value || [])

const periodLabel = computed(() => {
  if (!currentMonth.value) return ''
  const [y, m] = currentMonth.value.split('-')
  return `${y}年${parseInt(m)}月`
})

async function loadSnapshots() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('balance_snapshots')
      .select('*, account:account_id(code, ip_code, account_name, short_name)')
      .eq('period', currentMonth.value)
    if (error) {
      console.error('[Balance] loadSnapshots error:', error)
      snapshots.value = []
      return
    }
    // balance_snapshots 无 code 列,按 account.code 客户端排序
    const list = (data || []).slice().sort((a, b) => {
      const ac = a.account?.code || ''
      const bc = b.account?.code || ''
      return ac.localeCompare(bc)
    })
    // 扁平化一份便于模板访问 account_code
    snapshots.value = list.map(s => ({
      ...s,
      account_code: s.account?.code || '',
      account_name: s.account?.short_name || s.account?.account_name || '',
    }))
    if (snapshots.value.length > 0 && !selectedAccountId.value) {
      selectedAccountId.value = snapshots.value[0].account_id
    }
  } catch (e) {
    console.error('Failed to load snapshots:', e)
  } finally {
    loading.value = false
  }
}

function prevMonth() {
  const [y, m] = currentMonth.value.split('-').map(Number)
  if (m === 1) { currentMonth.value = `${y - 1}-12` }
  else { currentMonth.value = `${y}-${String(m - 1).padStart(2, '0')}` }
}

function nextMonth() {
  const [y, m] = currentMonth.value.split('-').map(Number)
  if (m === 12) { currentMonth.value = `${y + 1}-01` }
  else { currentMonth.value = `${y}-${String(m + 1).padStart(2, '0')}` }
}

async function selectAccount(accountId) {
  selectedAccountId.value = accountId
}

async function generateSnapshot() {
  try {
    const { error } = await supabase.rpc('generate_monthly_snapshots')
    if (error) throw error
    toast('快照已生成', 'success')
    await loadSnapshots()
  } catch (e) {
    console.error(e)
    toast('生成失败：' + (e.message || ''), 'error')
  }
}

async function confirmSnapshot() {
  try {
    const { error } = await supabase
      .from('balance_snapshots')
      .update({
        status: 'confirmed',
        confirmed_by: (await supabase.auth.getSession()).data.session?.user?.id,
        confirmed_at: new Date().toISOString(),
      })
      .eq('id', currentSnapshot.value.id)
    if (error) throw error
    currentSnapshot.value.status = 'confirmed'
    toast('已确认', 'success')
  } catch (e) {
    toast('确认失败', 'error')
  }
}

async function handleAdjust() {
  if (!adjustAmount.value || !adjustReason.value) {
    toast('请填写调整金额和原因', 'warning'); return
  }
  try {
    const { error } = await supabase
      .from('balance_snapshots')
      .update({
        opening_balance: Number(adjustAmount.value),
        admin_adjustment: Number(adjustAmount.value) - currentSnapshot.value.opening_balance,
        admin_reason: adjustReason.value,
      })
      .eq('id', currentSnapshot.value.id)
    if (error) throw error
    // Trigger recalculation by updating
    currentSnapshot.value.opening_balance = Number(adjustAmount.value)
    showAdjustModal.value = false
    adjustAmount.value = null
    adjustReason.value = ''
    toast('已调整期初余额', 'success')
  } catch (e) {
    toast('调整失败', 'error')
  }
}

// --- Settlement Modal ---
function closeSettleModal() {
  showSettleModal.value = false
  settleResults.value = []
  settleError.value = ''
  settling.value = false
}

async function executeSettle() {
  if (!settleMonth.value) {
    toast('请选择结算月份', 'warning')
    return
  }

  settling.value = true
  settleResults.value = []
  settleError.value = ''

  try {
    // Call the RPC function settle_monthly_balances
    // settlement_date should be the last day of the selected month
    const [y, m] = settleMonth.value.split('-').map(Number)
    const lastDay = new Date(y, m, 0).getDate()
    const settlementDate = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`

    const { data, error } = await supabase.rpc('settle_monthly_balances', {
      settlement_date: settlementDate
    })

    if (error) throw error

    // Parse results - the RPC might return an array or single object
    if (Array.isArray(data)) {
      settleResults.value = data.map(r => ({
        account_id: r.account_id,
        account_code: r.account_code || r.code || `账户${r.account_id?.slice(0, 6)}`,
        opening_balance: r.opening_balance ?? 0,
        closing_balance: r.closing_balance ?? 0,
      }))
    } else if (data && typeof data === 'object') {
      // If it returns a single result, wrap it
      settleResults.value = [{
        account_id: data.account_id,
        account_code: data.account_code || data.code || '结算结果',
        opening_balance: data.opening_balance ?? 0,
        closing_balance: data.closing_balance ?? 0,
      }]
    } else {
      settleResults.value = []
    }

    toast('结算完成！', 'success')

    // Refresh snapshots and history
    await Promise.all([
      loadSnapshots(),
      loadHistory(0),
    ])
  } catch (e) {
    console.error('Settlement error:', e)
    settleError.value = e.message || '结算失败，请检查数据库函数是否正确配置'
    toast('结算失败', 'error')
  } finally {
    settling.value = false
  }
}

// --- 对账（Reconciliation） ---
const editingActual = ref(false)
const actualInput = ref(null)
const diffReasonInput = ref('')
const showDetailDrilldown = ref(false)

const reconStatus = computed(() => {
  if (!currentSnapshot.value || currentSnapshot.value.actual_balance == null) return 'pending'
  if (Math.abs(currentSnapshot.value.balance_diff) < 0.01) return 'matched'
  return 'mismatch'
})

function startEditActual() {
  actualInput.value = currentSnapshot.value.actual_balance ?? null
  diffReasonInput.value = currentSnapshot.value.diff_reason ?? ''
  editingActual.value = true
}

function cancelActual() {
  editingActual.value = false
  actualInput.value = null
}

async function saveActual() {
  const userId = (await supabase.auth.getSession()).data.session?.user?.id
  const { error } = await supabase
    .from('balance_snapshots')
    .update({
      actual_balance: actualInput.value ?? null,
      diff_reason: diffReasonInput.value || null,
      reconciled_by: userId,
      reconciled_at: new Date().toISOString(),
    })
    .eq('id', currentSnapshot.value.id)
  if (error) throw error
  // 刷新快照数据
  Object.assign(currentSnapshot.value, {
    actual_balance: actualInput.value,
    balance_diff: (actualInput.value ?? 0) - (currentSnapshot.value.closing_balance ?? 0),
    diff_reason: diffReasonInput.value || null,
  })
  editingActual.value = false
  toast('对账已保存', 'success')
}

// --- History ---
async function loadHistory(page = 0) {
  historyLoading.value = true
  historyPage.value = page

  try {
    const pageSize = 20
    const { data, error } = await supabase
      .from('balance_snapshots')
      .select('*, account:account_id(code, ip_code)')
      .eq('status', 'confirmed')
      .order('settlement_date', { ascending: false })
      .order('account_code')
      .range(page * pageSize, (page + 1) * pageSize - 1)

    if (error) throw error

    settlementHistory.value = (data || []).map(s => ({
      id: s.id,
      account_code: s.account?.code || s.account_code || `账户${s.account_id?.slice(0, 6)}`,
      settlement_date: s.settlement_date || s.period ? `${s.period}-01` : null,
      opening_balance: s.opening_balance ?? 0,
      closing_balance: s.closing_balance ?? 0,
    }))
  } catch (e) {
    console.error('Failed to load history:', e)
    settlementHistory.value = []
  } finally {
    historyLoading.value = false
  }
}

onMounted(() => {
  const now = new Date()
  currentMonth.value = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  loadSnapshots()
  loadHistory(0)
})

watch(currentMonth, () => loadSnapshots())
</script>
