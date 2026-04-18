<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 余额对账</h1>
      <button v-if="auth.isAdmin" @click="showLegacy = !showLegacy"
        class="text-xs px-3 py-1.5 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 cursor-pointer inline-flex items-center gap-1">
        <Icon :name="showLegacy ? 'chevron-down' : 'calendar'" class="w-3.5 h-3.5" :class="showLegacy && 'rotate-180'" />
        <span>{{ showLegacy ? '收起月度快照' : '月度快照（管理员）' }}</span>
      </button>
    </div>

    <!-- 漂移巡检 banner:live_balance 与 RPC closing 不一致时提示 -->
    <div v-if="drift.length > 0" class="mb-4 bg-amber-50 border border-amber-200 rounded-xl p-3 flex items-start gap-3">
      <div class="text-amber-500 text-lg"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
      <div class="flex-1 text-sm">
        <div class="font-medium text-amber-800">{{ drift.length }} 个账户余额对不齐</div>
        <div class="text-xs text-amber-700 mt-0.5">
          总差额 {{ totalDrift >= 0 ? '+' : '' }}{{ formatMoney(totalDrift) }} ——
          <span v-for="(d, i) in drift.slice(0, 3)" :key="d.account_id">
            {{ d.short_name }} {{ Number(d.diff) >= 0 ? '+' : '' }}{{ formatMoney(d.diff) }}<span v-if="i < Math.min(drift.length, 3) - 1">、</span>
          </span>
          <span v-if="drift.length > 3">…</span>
        </div>
      </div>
      <button @click="reloadDrift" class="text-xs px-2 py-1 border border-amber-300 text-amber-700 rounded hover:bg-amber-100 cursor-pointer">重新检查</button>
    </div>

    <!-- Date range picker -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex flex-wrap items-center gap-3">
      <div class="flex items-center gap-1">
        <button v-for="p in presets" :key="p.key"
          @click="applyPreset(p.key)"
          class="px-3 py-1.5 text-xs rounded-lg border transition cursor-pointer"
          :class="activePreset === p.key
            ? 'bg-blue-600 border-blue-600 text-white'
            : 'border-gray-200 text-gray-600 hover:bg-gray-50'">
          {{ p.label }}
        </button>
      </div>
      <div class="h-6 w-px bg-gray-200"></div>
      <div class="flex items-center gap-2 text-sm">
        <input type="date" v-model="fromDate" :max="toDate"
          class="px-2 py-1.5 border border-gray-200 rounded-lg outline-none focus:ring-1 focus:ring-blue-400" />
        <span class="text-gray-400">→</span>
        <input type="date" v-model="toDate" :min="fromDate" :max="todayStr"
          class="px-2 py-1.5 border border-gray-200 rounded-lg outline-none focus:ring-1 focus:ring-blue-400" />
      </div>
      <label class="ml-auto flex items-center gap-1.5 text-xs text-gray-600 cursor-pointer select-none">
        <input type="checkbox" v-model="hideInactive" class="rounded cursor-pointer" />
        仅看有变化的账户
      </label>
      <button @click="loadMatrix" :disabled="loading"
        class="px-3 py-1.5 text-xs bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 cursor-pointer inline-flex items-center gap-1">
        <Icon name="refresh" class="w-3.5 h-3.5" :class="loading && 'animate-spin'" />
        <span>{{ loading ? '加载中…' : '刷新' }}</span>
      </button>
    </div>

    <!-- Summary strip -->
    <div v-if="!loading && rows.length > 0" class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-3">
        <div class="text-[11px] text-gray-500 mb-1">期初合计</div>
        <div class="text-lg font-bold text-gray-800">{{ formatMoney(totals.opening) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-green-100 p-3">
        <div class="text-[11px] text-gray-500 mb-1">本期增加</div>
        <div class="text-lg font-bold text-green-600">+{{ formatMoney(totals.increase) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-red-100 p-3">
        <div class="text-[11px] text-gray-500 mb-1">本期减少</div>
        <div class="text-lg font-bold text-red-500">-{{ formatMoney(totals.decrease) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-3">
        <div class="text-[11px] text-gray-500 mb-1">期末合计</div>
        <div class="text-lg font-bold" :class="totals.closing >= 0 ? 'text-gray-800' : 'text-red-500'">
          {{ formatMoney(totals.closing) }}
        </div>
      </div>
    </div>

    <!-- Matrix -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <div v-if="loading" class="p-10 text-center text-gray-500">
        <div class="animate-pulse">加载中…</div>
      </div>
      <div v-else-if="rows.length === 0" class="p-10 text-center text-gray-400">
        <div class="text-3xl mb-2">📭</div>
        <p>该区间内没有账户数据</p>
      </div>
      <table v-else class="w-full text-sm">
        <thead class="bg-gray-50">
          <tr class="text-xs text-gray-500">
            <th class="text-left px-4 py-2.5 font-medium">账户</th>
            <th class="text-right px-4 py-2.5 font-medium">期初</th>
            <th class="text-right px-4 py-2.5 font-medium">本期增加</th>
            <th class="text-right px-4 py-2.5 font-medium">本期减少</th>
            <th class="text-right px-4 py-2.5 font-medium">期末</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="group in groupedRows" :key="group.key">
            <tr class="bg-gray-50/60 border-t border-gray-100">
              <td colspan="5" class="px-4 py-1.5 text-xs font-medium text-gray-500">
                {{ group.label }} · {{ group.accounts.length }} 个账户
              </td>
            </tr>
            <tr v-for="r in group.accounts" :key="r.account_id"
              class="border-t border-gray-50 hover:bg-blue-50/30 transition">
              <td class="px-4 py-2.5">
                <div class="font-medium text-gray-800">{{ r.short_name || r.code || '—' }}</div>
              </td>
              <td class="px-4 py-2.5 text-right text-gray-600">{{ formatMoney(r.opening) }}</td>
              <td class="px-4 py-2.5 text-right">
                <button v-if="r.increase > 0" @click="openDrawer(r, 'in')"
                  class="font-medium text-green-600 hover:underline cursor-pointer">
                  +{{ formatMoney(r.increase) }}
                </button>
                <span v-else class="text-gray-300">—</span>
              </td>
              <td class="px-4 py-2.5 text-right">
                <button v-if="r.decrease > 0" @click="openDrawer(r, 'out')"
                  class="font-medium text-red-500 hover:underline cursor-pointer">
                  -{{ formatMoney(r.decrease) }}
                </button>
                <span v-else class="text-gray-300">—</span>
              </td>
              <td class="px-4 py-2.5 text-right font-semibold"
                :class="r.closing < 0 ? 'text-red-500' : 'text-gray-800'">
                {{ formatMoney(r.closing) }}
              </td>
            </tr>
            <tr v-if="group.accounts.length > 1" class="bg-gray-50/40 border-t border-gray-100 text-xs">
              <td class="px-4 py-1.5 text-gray-500">小计</td>
              <td class="px-4 py-1.5 text-right text-gray-500">{{ formatMoney(group.subtotal.opening) }}</td>
              <td class="px-4 py-1.5 text-right text-green-600">+{{ formatMoney(group.subtotal.increase) }}</td>
              <td class="px-4 py-1.5 text-right text-red-500">-{{ formatMoney(group.subtotal.decrease) }}</td>
              <td class="px-4 py-1.5 text-right font-medium text-gray-700">{{ formatMoney(group.subtotal.closing) }}</td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <!-- Drawer -->
    <BalanceFlowDrawer v-if="drawer.open"
      :account-id="drawer.accountId"
      :account-name="drawer.accountName"
      :account-category="drawer.accountCategory"
      :from="fromDate"
      :to="toDate"
      :direction="drawer.direction"
      @close="drawer.open = false"
      @updated="loadMatrix" />

    <!-- ===== Legacy 月度快照（管理员收纳区） ===== -->
    <div v-if="showLegacy" class="mt-6 bg-white rounded-xl border border-gray-100 p-5">
      <div class="flex items-center justify-between mb-4">
        <h2 class="font-bold text-gray-700"><Icon name="calendar" class="inline w-4 h-4 -mt-0.5 mr-1" /> 月度快照 / 结算</h2>
        <div class="flex items-center gap-2">
          <button @click="prevMonth" :disabled="legacyLoading"
            class="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 cursor-pointer">← 上月</button>
          <span class="text-sm text-gray-600">{{ periodLabel }}</span>
          <button @click="nextMonth" :disabled="legacyLoading"
            class="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 cursor-pointer">下月 →</button>
          <button @click="showSettleModal = true"
            class="ml-2 px-3 py-1 bg-purple-600 text-white rounded text-xs hover:bg-purple-700 cursor-pointer"><Icon name="settings" class="inline w-4 h-4 -mt-0.5 mr-1" /> 手动结算</button>
        </div>
      </div>

      <div v-if="legacyLoading" class="text-center py-6 text-gray-500">加载中…</div>
      <div v-else-if="snapshots.length === 0" class="text-center py-6 text-gray-400">
        <p class="text-sm mb-3">本月暂无快照</p>
        <button @click="generateSnapshot"
          class="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs hover:bg-blue-700 cursor-pointer">生成快照</button>
      </div>
      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <div v-for="s in snapshots" :key="s.id"
          class="border border-gray-100 rounded-lg p-3 text-sm">
          <div class="flex items-center justify-between mb-1">
            <span class="font-medium text-gray-700">{{ s.account_code }}</span>
            <span class="text-[11px]" :class="s.status === 'confirmed' ? 'text-green-600' : 'text-amber-500'">
              {{ s.status === 'confirmed' ? '✅ 已确认' : '📝 待确认' }}
            </span>
          </div>
          <div class="text-xs text-gray-500 flex items-center justify-between">
            <span>期初 {{ formatMoney(s.opening_balance) }}</span>
            <span class="text-gray-400">→</span>
            <span :class="s.closing_balance >= 0 ? 'text-gray-700 font-medium' : 'text-red-500 font-medium'">
              期末 {{ formatMoney(s.closing_balance) }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Legacy settlement modal -->
    <Teleport to="body">
      <div v-if="showSettleModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" @click.self="closeSettleModal">
        <div class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between p-5 border-b border-gray-100">
            <h2 class="text-lg font-bold text-gray-800"><Icon name="settings" class="inline w-4 h-4 -mt-0.5 mr-1" /> 手动结算</h2>
            <button @click="closeSettleModal" class="text-gray-500 hover:text-gray-600 text-xl">✕</button>
          </div>
          <div class="p-5 space-y-4">
            <p class="text-sm text-gray-500">为所有账户结算所选月份，生成期初/期末快照。</p>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">结算月份</label>
              <input v-model="settleMonth" type="month"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500">
            </div>
            <div v-if="settling" class="flex items-center gap-3 p-3 bg-purple-50 rounded-lg">
              <div class="animate-spin text-purple-600">⏳</div>
              <span class="text-sm text-purple-700">正在结算中…</span>
            </div>
            <div v-if="settleResults.length > 0" class="space-y-2 max-h-60 overflow-y-auto">
              <div class="text-sm font-medium text-gray-700">结算结果</div>
              <div v-for="r in settleResults" :key="r.account_id"
                class="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg text-sm">
                <span class="font-medium text-gray-700">{{ r.account_code }}</span>
                <div class="flex items-center gap-3 text-xs">
                  <span class="text-gray-500">期初 {{ formatMoney(r.opening_balance) }}</span>
                  <span class="text-gray-400">→</span>
                  <span class="font-medium" :class="r.closing_balance >= 0 ? 'text-green-600' : 'text-red-500'">
                    期末 {{ formatMoney(r.closing_balance) }}
                  </span>
                </div>
              </div>
            </div>
            <div v-if="settleError" class="p-3 bg-red-50 rounded-lg text-sm text-red-600"><Icon name="x-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> {{ settleError }}</div>
          </div>
          <div class="flex justify-end gap-3 p-5 border-t border-gray-100">
            <button @click="closeSettleModal" class="px-4 py-2 text-sm border border-gray-200 rounded-lg hover:bg-gray-50">关闭</button>
            <button @click="executeSettle" :disabled="settling || !settleMonth"
              class="px-4 py-2 text-sm text-white bg-purple-600 rounded-lg hover:bg-purple-700 disabled:opacity-50">
              {{ settling ? '结算中…' : '开始结算' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { formatMoney, toast } from '../lib/utils'
import BalanceFlowDrawer from '../components/BalanceFlowDrawer.vue'
import Icon from '../components/icons/Icons.vue'

const auth = useAuthStore()
const accountStore = useAccountStore()

// ========== 日期范围 ==========
const todayStr = new Date().toISOString().slice(0, 10)
const fromDate = ref('')
const toDate = ref(todayStr)
const activePreset = ref('thisMonth')

const presets = [
  { key: 'thisMonth', label: '本月至今' },
  { key: 'lastMonth', label: '上月' },
  { key: 'thisQuarter', label: '本季度' },
  { key: 'thisYear', label: '本年至今' },
  { key: 'custom', label: '自定义' },
]

function applyPreset(key) {
  activePreset.value = key
  const now = new Date()
  const y = now.getFullYear()
  const m = now.getMonth()
  const d = now.getDate()
  const pad = n => String(n).padStart(2, '0')
  const fmt = dt => `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}`

  if (key === 'thisMonth') {
    fromDate.value = `${y}-${pad(m + 1)}-01`
    toDate.value = todayStr
  } else if (key === 'lastMonth') {
    const lastM = m === 0 ? 11 : m - 1
    const lastY = m === 0 ? y - 1 : y
    const lastDay = new Date(lastY, lastM + 1, 0).getDate()
    fromDate.value = `${lastY}-${pad(lastM + 1)}-01`
    toDate.value = `${lastY}-${pad(lastM + 1)}-${pad(lastDay)}`
  } else if (key === 'thisQuarter') {
    const qStart = Math.floor(m / 3) * 3
    fromDate.value = `${y}-${pad(qStart + 1)}-01`
    toDate.value = todayStr
  } else if (key === 'thisYear') {
    fromDate.value = `${y}-01-01`
    toDate.value = todayStr
  }
  // custom: 不动
  if (key !== 'custom') loadMatrix()
}

// ========== 矩阵数据 ==========
const loading = ref(false)
const rows = ref([])   // [{ account_id, short_name, code, ip_code, category, opening, increase, decrease, closing }]
const hideInactive = ref(false)  // 隐藏本期无变化的账户

// ========== 漂移巡检 ==========
const drift = ref([])
const totalDrift = computed(() => drift.value.reduce((s, d) => s + Number(d.diff || 0), 0))
async function reloadDrift() {
  try {
    const { data, error } = await supabase.rpc('check_balance_drift')
    if (error) throw error
    drift.value = data || []
  } catch (e) {
    console.warn('[drift] check failed', e)
    drift.value = []
  }
}

async function loadMatrix() {
  if (!fromDate.value || !toDate.value) return
  loading.value = true
  try {
    // 确保账户元数据已加载
    if (accountStore.accounts.length === 0) await accountStore.fetchAccounts()

    const fromIso = new Date(fromDate.value + 'T00:00:00+08:00').toISOString()
    const toIso   = new Date(toDate.value   + 'T23:59:59+08:00').toISOString()
    const { data, error } = await supabase.rpc('compute_balance_range', {
      p_from: fromIso,
      p_to:   toIso,
    })
    if (error) throw error

    const byId = new Map((data || []).map(r => [r.account_id, r]))
    const merged = accountStore.accounts
      .filter(a => a.status !== 'deleted')
      .map(a => {
        const m = byId.get(a.id) || { opening: 0, increase: 0, decrease: 0, closing: Number(a.opening_balance || 0) }
        return {
          account_id: a.id,
          short_name: a.short_name,
          code: a.code,
          ip_code: a.ip_code,
          category: a.category,
          opening: Number(m.opening || 0),
          increase: Number(m.increase || 0),
          decrease: Number(m.decrease || 0),
          closing: Number(m.closing || 0),
        }
      })
    // 默认全显；用户可通过"仅看有变化的账户"checkbox 过滤
    rows.value = merged
  } catch (e) {
    console.error('[Balance] loadMatrix failed:', e)
    toast('加载失败：' + (e.message || ''), 'error')
  } finally {
    loading.value = false
  }
}

// 按三大类(个人/企业/店铺)分组 + 小计 + 固定排序
const GROUP_DEF = [
  { key: 'personal', label: '个人账户', matches: c => c === 'personal' || c === 'cash' || c === 'bank' || !c },
  { key: 'company',  label: '企业账户', matches: c => c === 'company' },
  { key: 'ecommerce', label: '店铺账户', matches: c => c === 'ecommerce' },
]
const visibleRows = computed(() => {
  if (!hideInactive.value) return rows.value
  return rows.value.filter(r => r.increase !== 0 || r.decrease !== 0)
})
const groupedRows = computed(() => {
  const groups = GROUP_DEF.map(g => ({ ...g, accounts: [], subtotal: { opening: 0, increase: 0, decrease: 0, closing: 0 } }))
  for (const r of visibleRows.value) {
    const g = groups.find(gg => gg.matches(r.category)) || groups[0]
    g.accounts.push(r)
    g.subtotal.opening += r.opening
    g.subtotal.increase += r.increase
    g.subtotal.decrease += r.decrease
    g.subtotal.closing += r.closing
  }
  return groups.filter(g => g.accounts.length > 0)
})

const totals = computed(() => rows.value.reduce((acc, r) => ({
  opening: acc.opening + r.opening,
  increase: acc.increase + r.increase,
  decrease: acc.decrease + r.decrease,
  closing: acc.closing + r.closing,
}), { opening: 0, increase: 0, decrease: 0, closing: 0 }))

function categoryLabel(c) {
  return { ecommerce: '电商', personal: '个人', cash: '现金', bank: '银行卡' }[c] || c
}

// ========== 抽屉 ==========
const drawer = ref({ open: false, accountId: '', accountName: '', accountCategory: '', direction: 'in' })

function openDrawer(r, direction) {
  drawer.value = {
    open: true,
    accountId: r.account_id,
    accountName: r.short_name || r.code || '',
    accountCategory: r.category || '',
    direction,
  }
}

// ========== Legacy 月度快照 ==========
const showLegacy = ref(false)
const legacyLoading = ref(false)
const snapshots = ref([])
const currentMonth = ref('')

const periodLabel = computed(() => {
  if (!currentMonth.value) return ''
  const [y, m] = currentMonth.value.split('-')
  return `${y}年${parseInt(m)}月`
})

async function loadSnapshots() {
  legacyLoading.value = true
  try {
    const { data, error } = await supabase
      .from('balance_snapshots')
      .select('*, account:account_id(code, short_name)')
      .eq('period', currentMonth.value)
    if (error) throw error
    const list = (data || []).slice().sort((a, b) => (a.account?.code || '').localeCompare(b.account?.code || ''))
    snapshots.value = list.map(s => ({
      ...s,
      account_code: s.account?.short_name || s.account?.code || '',
    }))
  } catch (e) {
    console.error('[Balance-legacy]', e)
    snapshots.value = []
  } finally {
    legacyLoading.value = false
  }
}

function prevMonth() {
  const [y, m] = currentMonth.value.split('-').map(Number)
  currentMonth.value = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`
}
function nextMonth() {
  const [y, m] = currentMonth.value.split('-').map(Number)
  currentMonth.value = m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, '0')}`
}

async function generateSnapshot() {
  try {
    const { error } = await supabase.rpc('generate_monthly_snapshots')
    if (error) throw error
    toast('快照已生成', 'success')
    await loadSnapshots()
  } catch (e) {
    toast('生成失败：' + (e.message || ''), 'error')
  }
}

// Settle modal
const showSettleModal = ref(false)
const settleMonth = ref('')
const settling = ref(false)
const settleResults = ref([])
const settleError = ref('')

function closeSettleModal() {
  showSettleModal.value = false
  settleResults.value = []
  settleError.value = ''
  settling.value = false
}

async function executeSettle() {
  if (!settleMonth.value) { toast('请选择结算月份', 'warning'); return }
  settling.value = true
  settleResults.value = []
  settleError.value = ''
  try {
    const [y, m] = settleMonth.value.split('-').map(Number)
    const lastDay = new Date(y, m, 0).getDate()
    const settlementDate = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`
    const { data, error } = await supabase.rpc('settle_monthly_balances', { settlement_date: settlementDate })
    if (error) throw error
    const arr = Array.isArray(data) ? data : (data ? [data] : [])
    settleResults.value = arr.map(r => ({
      account_id: r.account_id,
      account_code: r.account_code || r.code || `账户${String(r.account_id).slice(0, 6)}`,
      opening_balance: r.opening_balance ?? 0,
      closing_balance: r.closing_balance ?? 0,
    }))
    toast('结算完成', 'success')
    await loadSnapshots()
  } catch (e) {
    settleError.value = e.message || '结算失败'
    toast('结算失败', 'error')
  } finally {
    settling.value = false
  }
}

// ========== 初始化 ==========
onMounted(() => {
  const now = new Date()
  currentMonth.value = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  applyPreset('thisMonth')  // 默认本月至今
  reloadDrift()             // 每次进页检查一次余额漂移
})

watch(() => [fromDate.value, toDate.value], () => {
  // 用户手动改日期时切成 custom（除非恰好匹配某个 preset，不细判）
  activePreset.value = 'custom'
})
watch(() => showLegacy.value, (val) => {
  if (val) loadSnapshots()
})
watch(() => currentMonth.value, () => {
  if (showLegacy.value) loadSnapshots()
})
</script>
