<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800 truncate">🔄 账户转账</h1>
      <div class="flex items-center gap-2 shrink-0">
        <div v-if="canDeleteTransfers" class="hidden md:inline-flex items-center gap-1">
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
        <button
          @click="showTextMode = !showTextMode"
          class="hidden md:inline-flex px-4 py-2 rounded-lg text-sm transition cursor-pointer whitespace-nowrap"
          :class="showTextMode ? 'bg-purple-600 text-white hover:bg-purple-700' : 'bg-purple-50 text-purple-700 hover:bg-purple-100'"
        >
          📋 文本模式
        </button>
        <!-- 移动端更多菜单 -->
        <div class="relative md:hidden">
          <button @click="showMobileMenu = !showMobileMenu" class="px-2.5 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">⋯</button>
          <div v-if="showMobileMenu" class="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-lg border border-gray-100 py-1 z-50 min-w-[140px]">
            <button @click="showTextMode = !showTextMode; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">📋 文本模式</button>
            <button v-if="canDeleteTransfers" @click="generateTestData(testCount); showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm text-gray-400 hover:bg-gray-50 cursor-pointer">🎲 随机测试</button>
          </div>
        </div>
        <div v-if="showMobileMenu" class="fixed inset-0 z-40 md:hidden" @click="showMobileMenu = false"></div>
        <button v-if="auth.isFinance" @click="showTransferModal = true"
          class="bg-blue-600 text-white px-3 md:px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer whitespace-nowrap">
          + 新建转账
        </button>
      </div>
    </div>

    <!-- Text Mode Panel -->
    <div v-if="showTextMode" class="mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-gray-700">📋 粘贴转账文本</h3>
          <button @click="showTextMode = false" class="text-gray-500 hover:text-gray-600 text-sm cursor-pointer">收起 ✕</button>
        </div>
        <textarea
          v-model="rawText"
          rows="5"
          placeholder="粘贴转账文本，每行一条&#10;支持格式：转卡 05日 43000元 中信卡 / 转余利宝 06日 1.5万 / 抖店到账 05日 43000元 靓仔上课台球抖店到账 中信卡 / 珊公户收 06日 11000元 南快手到账 / 南1入账 05日 2000元"
          class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500 resize-none font-mono"
        ></textarea>
        <div class="flex items-center gap-3 mt-3">
          <div class="flex items-center gap-2">
            <span class="text-xs text-gray-500">📅 统一月份：</span>
            <input
              type="month"
              v-model="transferMonthStr"
              class="px-2 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-1 focus:ring-purple-500"
            >
            <span class="text-xs text-gray-500">（文本中可用"X月X日"指定日期）</span>
          </div>
        </div>
        <div class="flex items-center gap-2 mt-2">
          <button
            @click="handleParseTransfers"
            :disabled="!rawText.trim()"
            class="px-4 py-2 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition"
          >
            🔍 解析
          </button>
          <button
            @click="rawText = ''; parsedTransfers = []; parseError = ''"
            class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer transition"
          >
            清空
          </button>
        </div>

        <!-- Parsed Preview -->
        <div v-if="parsedTransfers.length > 0" class="mt-4 space-y-3">
          <div class="text-xs text-gray-500 mb-1">解析到 {{ parsedTransfers.length }} 条转账记录，可编辑后确认提交：</div>
          <div
            v-for="(tr, idx) in parsedTransfers"
            :key="idx"
            class="border border-blue-100 bg-blue-50/30 rounded-lg p-4"
          >
            <div class="text-xs text-gray-500 font-mono bg-gray-50 rounded px-2 py-1 mb-2 break-all whitespace-pre-wrap">{{ tr._rawText }}</div>
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-semibold text-blue-600">🔄 转账 {{ idx + 1 }}</span>
              <button
                @click="submitParsedTransfer(idx)"
                :disabled="submittingParsed"
                class="px-3 py-1 bg-green-600 text-white rounded-md text-xs hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition"
              >
                ✅ 确认提交
              </button>
            </div>
            <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
              <div>
                <span class="text-gray-500 text-xs">转出账户：</span>
                <SearchableSelect
                  v-model="tr.from_account_id"
                  :options="flatAccounts"
                  label-key="label"
                  value-key="id"
                  placeholder="选择转出账户"
                  search-placeholder="搜索账户..."
                  drop-up
                />
              </div>
              <div>
                <span class="text-gray-500 text-xs">转入账户：</span>
                <SearchableSelect
                  v-model="tr.to_account_id"
                  :options="flatAccounts"
                  label-key="label"
                  value-key="id"
                  placeholder="选择转入账户"
                  search-placeholder="搜索账户..."
                  drop-up
                />
              </div>
              <div>
                <span class="text-gray-500 text-xs">金额：</span>
                <input
                  v-model.number="tr.amount"
                  type="number"
                  min="0.01"
                  step="0.01"
                  class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white"
                />
              </div>
              <div>
                <span class="text-gray-500 text-xs">日期：</span>
                <span class="text-sm text-gray-600">{{ tr.date || '今天' }}</span>
              </div>
              <div class="col-span-2">
                <span class="text-gray-500 text-xs">备注：</span>
                <input v-model="tr.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>
          </div>

          <!-- Batch submit -->
          <div class="flex items-center justify-between pt-2">
            <span class="text-xs text-gray-500">
              共 {{ parsedTransfers.length }} 条，合计 {{ formatMoney(parsedTransfers.reduce((s, e) => s + (Number(e.amount) || 0), 0)) }}
            </span>
            <button
              @click="submitAllParsedTransfers"
              :disabled="submittingParsed"
              class="px-5 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition"
            >
              {{ submittingParsed ? '提交中...' : '✅ 全部提交' }}
            </button>
          </div>
        </div>

        <!-- Parse Error -->
        <div v-if="parseError" class="mt-3 text-red-500 text-sm bg-red-50 rounded-lg px-3 py-2">
          ⚠️ {{ parseError }}
        </div>
      </div>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">本月转账次数</div>
        <div class="text-2xl font-bold text-blue-600">{{ monthTransfers.count }}</div>
        <div class="text-xs text-gray-500 mt-1">总金额 {{ formatMoney(monthTransfers.total) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">本月手续费</div>
        <div class="text-2xl font-bold text-orange-500">{{ formatMoney(monthTransfers.fee) }}</div>
        <div class="text-xs text-gray-500 mt-1">转账产生的费用</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">总转账记录</div>
        <div class="text-2xl font-bold text-gray-700">{{ allTransfers.length }} 条</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center">
      <input v-model="search" placeholder="搜索账户或备注" 
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredTransfers.length }} 条</span>
    </div>

    <!-- Action Bar -->
    <div v-if="selectedIds.length > 0 && canDeleteTransfers" class="bg-red-50 border border-red-100 rounded-xl px-4 py-3 mb-4 flex items-center gap-3">
      <span class="text-red-600 text-sm font-medium">已选 {{ selectedIds.length }} 条</span>
      <button v-if="canDelete" @click="handleBatchDelete" class="bg-red-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-red-700 transition cursor-pointer">删除选中</button>
      <button @click="selectedIds = []" class="text-gray-500 text-sm hover:text-gray-700 cursor-pointer">取消选择</button>
    </div>

    <!-- Transfer History -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <Skeleton v-if="loading" type="table" :rows="6" :columns="7" />
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th v-if="canDeleteTransfers" class="px-4 py-3 text-center w-10">
              <input type="checkbox" :checked="isAllSelected" @change="toggleSelectAll" class="rounded cursor-pointer">
            </th>
            <th class="px-4 py-3 text-left font-medium">时间</th>
            <th class="px-4 py-3 text-left font-medium">转出账户</th>
            <th class="px-4 py-3 text-center font-medium">→</th>
            <th class="px-4 py-3 text-left font-medium">转入账户</th>
            <th class="px-4 py-3 text-right font-medium">金额</th>
            <th class="px-4 py-3 text-right font-medium">手续费</th>
            <th class="px-4 py-3 text-left font-medium">操作人</th>
            <th class="px-4 py-3 text-center font-medium">状态</th>
            <th v-if="canDeleteTransfers" class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in filteredTransfers" :key="t.id" class="border-t border-gray-50 hover:bg-gray-50/60 transition">
            <td v-if="canDeleteTransfers" class="px-4 py-3 text-center">
              <input type="checkbox" :value="t.id" v-model="selectedIds" class="rounded cursor-pointer">
            </td>
            <td class="px-4 py-3 text-gray-500 whitespace-nowrap">{{ formatDate(t.created_at) }}</td>
            <td class="px-4 py-3">
              <span class="bg-red-50 text-red-700 px-2 py-0.5 rounded text-xs font-medium">{{ t.from_name }}</span>
            </td>
            <td class="px-4 py-3 text-center text-gray-300">→</td>
            <td class="px-4 py-3">
              <span class="bg-green-50 text-green-700 px-2 py-0.5 rounded text-xs font-medium">{{ t.to_name }}</span>
            </td>
            <td class="px-4 py-3 text-right font-medium text-gray-800">{{ formatMoney(t.amount) }}</td>
            <td class="px-4 py-3 text-right text-orange-500">{{ t.fee > 0 ? formatMoney(t.fee) : '—' }}</td>
            <td class="px-4 py-3 text-gray-500">{{ t.creator_name || '—' }}</td>
            <td class="px-4 py-3 text-center">
              <span :class="t.status === 'completed' ? 'text-green-600 bg-green-50' : t.status === 'failed' ? 'text-red-500 bg-red-50' : 'text-orange-500 bg-orange-50'"
                class="px-2 py-0.5 rounded text-xs font-medium">
                {{ t.status === 'completed' ? '成功' : t.status === 'failed' ? '失败' : '处理中' }}
              </span>
            </td>
            <td v-if="canDeleteTransfers" class="px-4 py-3 text-center">
              <button v-if="canDelete" @click="handleDeleteTransfer(t)" class="text-red-400 hover:text-red-600 text-xs px-2 py-1 rounded hover:bg-red-50 transition cursor-pointer">删除</button>
            </td>
          </tr>
          <tr v-if="filteredTransfers.length === 0">
            <td :colspan="canDeleteTransfers ? 10 : 8" class="px-4 py-12 text-center text-gray-500">暂无转账记录</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- New Transfer Modal -->
    <div v-if="showTransferModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showTransferModal = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 max-h-[85vh] flex flex-col overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 class="font-bold text-gray-800">🔄 新建转账</h2>
          <button @click="showTransferModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleTransfer" class="p-6 space-y-4 overflow-y-auto flex-1">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">转出账户 <span class="text-red-400">*</span></label>
            <SearchableSelect
              v-model="form.from_account_id"
              :options="flatAccounts"
              label-key="label"
              value-key="id"
              placeholder="请选择转出账户"
              search-placeholder="搜索账户名称..."
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">转入账户 <span class="text-red-400">*</span></label>
            <SearchableSelect
              v-model="form.to_account_id"
              :options="flatAccounts"
              label-key="label"
              value-key="id"
              placeholder="请选择转入账户"
              search-placeholder="搜索账户名称..."
            />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">转账金额 <span class="text-red-400">*</span></label>
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">¥</span>
                <input v-model.number="form.amount" type="number" min="0.01" step="0.01" required placeholder="0.00"
                  class="w-full pl-8 pr-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">手续费</label>
              <input v-model.number="form.fee" type="number" min="0" step="0.01" placeholder="0.00"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
          </div>

          <!-- 平台提现费用明细 -->
          <div v-if="isPlatformWithdraw" class="bg-blue-50 border border-blue-100 rounded-lg p-4 space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm font-medium text-blue-800">📋 {{ platformFeeLabel }}提现费用明细</span>
              <button type="button" @click="autoCalcFee" class="text-xs text-blue-600 hover:text-blue-800 cursor-pointer">自动计算</button>
            </div>
            <div class="grid grid-cols-2 gap-2 text-sm">
              <div>
                <label class="text-xs text-gray-500">技术服务费 ({{ platformFeeRates.technical }}%)</label>
                <input v-model.number="form.fee_detail.technical_fee" type="number" min="0" step="0.01" placeholder="0.00"
                  class="w-full px-2 py-1.5 border border-blue-200 rounded text-sm bg-white outline-none focus:ring-1 focus:ring-blue-400">
              </div>
              <div>
                <label class="text-xs text-gray-500">支付通道费 ({{ platformFeeRates.payment }}%)</label>
                <input v-model.number="form.fee_detail.payment_fee" type="number" min="0" step="0.01" placeholder="0.00"
                  class="w-full px-2 py-1.5 border border-blue-200 rounded text-sm bg-white outline-none focus:ring-1 focus:ring-blue-400">
              </div>
              <div>
                <label class="text-xs text-gray-500">提现手续费 ({{ platformFeeRates.withdraw }}%)</label>
                <input v-model.number="form.fee_detail.withdraw_fee" type="number" min="0" step="0.01" placeholder="0.00"
                  class="w-full px-2 py-1.5 border border-blue-200 rounded text-sm bg-white outline-none focus:ring-1 focus:ring-blue-400">
              </div>
              <div>
                <label class="text-xs text-gray-500">其他费用</label>
                <input v-model.number="form.fee_detail.other_fee" type="number" min="0" step="0.01" placeholder="0.00"
                  class="w-full px-2 py-1.5 border border-blue-200 rounded text-sm bg-white outline-none focus:ring-1 focus:ring-blue-400">
              </div>
            </div>
            <div class="border-t border-blue-200 pt-2 text-sm flex items-center justify-between">
              <div>
                <span class="text-gray-600">费用合计：</span>
                <span class="text-red-600 font-bold">¥{{ totalFeeDetail.toFixed(2) }}</span>
                <span class="text-gray-500 ml-2">（占 {{ form.amount ? (totalFeeDetail / form.amount * 100).toFixed(1) : 0 }}%）</span>
              </div>
              <div v-if="effectiveFee > 0" class="flex items-center gap-1">
                <span class="text-xs text-gray-500 mr-1">费用扣除：</span>
                <button type="button" @click="form.fee_mode = 'from_balance'"
                  :class="form.fee_mode === 'from_balance' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
                  class="px-2 py-1 rounded text-xs cursor-pointer">外扣（余额另扣）</button>
                <button type="button" @click="form.fee_mode = 'from_amount'"
                  :class="form.fee_mode === 'from_amount' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
                  class="px-2 py-1 rounded text-xs cursor-pointer">内扣（从本笔扣）</button>
              </div>
            </div>
            <div class="text-sm">
              <span class="text-gray-600">实际到账：</span>
              <span class="text-green-700 font-bold text-lg">¥{{ actualArrival.toFixed(2) }}</span>
            </div>
          </div>

          <p class="text-xs text-gray-500">实际到账 = ¥{{ form.amount || 0 }} - ¥{{ effectiveFee.toFixed(2) }} = ¥{{ actualArrival.toFixed(2) }}</p>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="转账原因"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showTransferModal = false" 
              class="flex-1 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
            <button type="submit" :disabled="submitting || !form.from_account_id || !form.to_account_id"
              class="flex-1 py-2.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
              {{ submitting ? '处理中...' : '确认转账' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { formatMoney, PLATFORM_LABELS, toast, formatDate } from '../lib/utils'
import { randomPick, randomAmount } from '../lib/testDataHelper'
import { logOperation, getAccountBalance, formatMoneyStr } from '../utils/operationLogger'
import SearchableSelect from '../components/SearchableSelect.vue'
import Skeleton from '../components/Skeleton.vue'
import { usePermission } from '../composables/usePermission'

const { canDelete, loadRole } = usePermission()

const auth = useAuthStore()
const accountStore = useAccountStore()
const loading = ref(true)
const submitting = ref(false)
const search = ref('')
const transfers = ref([])
const accounts = ref([])
const showTransferModal = ref(false)
const showTextMode = ref(false)
const showMobileMenu = ref(false)
const selectedIds = ref([])

// --- Text Mode State ---
const rawText = ref('')
const parsedTransfers = ref([])
const transferMonth = ref(new Date())
const transferMonthStr = computed({
  get: () => {
    const d = transferMonth.value
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  },
  set: (val) => {
    const [y, m] = val.split('-').map(Number)
    transferMonth.value = new Date(y, m - 1, 1)
  },
})
const parseError = ref('')
const submittingParsed = ref(false)

const canDeleteTransfers = computed(() => auth.isFinance || auth.isAdmin)

const isAllSelected = computed(() => filteredTransfers.value.length > 0 && selectedIds.value.length === filteredTransfers.value.length)

function toggleSelectAll(e) {
  if (e.target.checked) {
    selectedIds.value = filteredTransfers.value.map(t => t.id)
  } else {
    selectedIds.value = []
  }
}

const form = reactive({
  from_account_id: '',
  to_account_id: '',
  amount: null,
  fee: 0,
  note: '',
  fee_detail: { technical_fee: 0, payment_fee: 0, withdraw_fee: 0, other_fee: 0 },
  fee_mode: 'from_balance',
})

// 平台提现费率配置
const PLATFORM_FEE_RATES = {
  douyin:       { technical: 5, payment: 0.6, withdraw: 0.6, label: '抖音电商' },
  kuaishou:     { technical: 5, payment: 0.6, withdraw: 0.3, label: '快手电商' },
  shipinhao:    { technical: 2, payment: 0.6, withdraw: 0.1, label: '视频号' },
}

// 判断转出账户是否为平台账户
const isPlatformWithdraw = computed(() => {
  if (!form.from_account_id) return false
  const acc = accounts.value.find(a => a.id === form.from_account_id)
  if (!acc) return false
  return !!PLATFORM_FEE_RATES[acc.ecommerce_platform]
})

// 当前平台费率
const platformFeeRates = computed(() => {
  if (!form.from_account_id) return { technical: 0, payment: 0, withdraw: 0, label: '' }
  const acc = accounts.value.find(a => a.id === form.from_account_id)
  if (!acc) return { technical: 0, payment: 0, withdraw: 0, label: '' }
  return PLATFORM_FEE_RATES[acc.ecommerce_platform] || { technical: 0, payment: 0, withdraw: 0, label: '' }
})

// 平台名称
const platformFeeLabel = computed(() => platformFeeRates.value.label)

// 费用明细合计
const totalFeeDetail = computed(() => {
  const d = form.fee_detail
  return (Number(d.technical_fee) || 0) + (Number(d.payment_fee) || 0) + (Number(d.withdraw_fee) || 0) + (Number(d.other_fee) || 0)
})

// 有效手续费（平台提现时用明细合计，否则用手动输入）
const effectiveFee = computed(() => isPlatformWithdraw.value ? totalFeeDetail.value : (Number(form.fee) || 0))

// 实际到账
const actualArrival = computed(() => (Number(form.amount) || 0) - effectiveFee.value)

// 自动根据费率计算费用
function autoCalcFee() {
  const amount = Number(form.amount) || 0
  if (amount <= 0) return
  const rates = platformFeeRates.value
  form.fee_detail.technical_fee = Math.round(amount * rates.technical / 100 * 100) / 100
  form.fee_detail.payment_fee = Math.round(amount * rates.payment / 100 * 100) / 100
  form.fee_detail.withdraw_fee = Math.round(amount * rates.withdraw / 100 * 100) / 100
  form.fee_detail.other_fee = 0
  form.fee = totalFeeDetail.value
}

// 监听金额变化，如果平台提现且费用明细有值则自动重算
const autoCalcOnAmount = computed(() => {
  if (isPlatformWithdraw.value && form.amount && totalFeeDetail.value > 0) {
    autoCalcFee()
  }
  return form.amount
})

const accountsByIP = computed(() => {
  const groups = {}
  for (const acc of accounts.value.filter(a => a.status === 'active')) {
    if (!groups[acc.ip_code]) groups[acc.ip_code] = []
    groups[acc.ip_code].push(acc)
  }
  return groups
})

const flatAccounts = computed(() => {
  return accounts.value
    .filter(a => a.status === 'active')
    .map(a => ({ id: a.id, label: `${a.short_name || a.code}（余额 ${formatMoney(a.balance)}）` }))
})

const filteredTransfers = computed(() => {
  if (!search.value) return transfers.value
  const kw = search.value.toLowerCase()
  return transfers.value.filter(t =>
    (t.from_code || t.from_name || '').toLowerCase().includes(kw) ||
    (t.to_code || t.to_name || '').toLowerCase().includes(kw) ||
    (t.note || '').toLowerCase().includes(kw)
  )
})

const now = new Date()
const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

const monthTransfers = computed(() => {
  const monthData = transfers.value.filter(t => t.created_at >= monthStart)
  return {
    count: monthData.length,
    total: monthData.reduce((s, t) => s + (t.amount || 0), 0),
    fee: monthData.reduce((s, t) => s + (t.fee || 0), 0),
  }
})

const allTransfers = computed(() => transfers.value)

const testCount = ref(5)

// ---------- 随机测试数据生成 ----------
async function generateTestData(count) {
  try {
    let accs = accountStore.getActiveAccounts()
    if (accs.length < 2) { toast('至少需要2个活跃账户', 'warning'); return }
    const userId = (await supabase.auth.getSession()).data.session?.user?.id
    let success = 0
    for (let i = 0; i < count; i++) {
      const shuffled = [...accs].sort(() => Math.random() - 0.5)
      const fromAcc = shuffled[0]
      const toAcc = shuffled[1]
      const amt = randomAmount(500, 10000)
      // 确保余额足够
      if (Number(fromAcc.balance) < amt) continue
      const { data, error } = await supabase
        .from('account_transfers')
        .insert({
          from_account_id: fromAcc.id,
          to_account_id: toAcc.id,
          amount: amt,
          fee: 0,
          note: `测试转账-${randomPick(['日常', '调拨', '归集', '备用'])}`,
          transfer_date: new Date().toISOString(),
        })
        .select('*, from_account:from_account_id(code, short_name), to_account:to_account_id(code, short_name)')
        .single()
      if (error) throw error
      transfers.value.unshift({
        ...data,
        from_code: data.from_account?.code || '—',
        to_code: data.to_account?.code || '—',
        from_name: data.from_account?.short_name || data.from_account?.code || '—',
        to_name: data.to_account?.short_name || data.to_account?.code || '—',
        creator_name: '',
      })
      // 更新余额
      const { useAccountStore } = await import('../stores/accounts')
      await useAccountStore().updateBalance(fromAcc.id, -amt)
      await useAccountStore().updateBalance(toAcc.id, amt)
      // 操作日志
      try {
        const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
        const fromInfo = await getAccountBalance(fromAcc.id)
        const toInfo = await getAccountBalance(toAcc.id)
        logOperation({
          action: 'create_transfer',
          module: '转账',
          description: `[测试] 创建转账 ${Number(amt).toFixed(2)}，${fromInfo?.name || ''} → ${toInfo?.name || ''}`,
          detail: { amount: amt, from_account_id: fromAcc.id, to_account_id: toAcc.id, from_name: fromInfo?.name, to_name: toInfo?.name },
          amount: amt,
        })
      } catch (_) {}
      success++
    }
    toast(`成功生成 ${success} 条测试转账`, 'success')
  } catch (e) {
    console.error(e)
    toast('生成测试数据失败：' + (e.message || ''), 'error')
  }
}

onMounted(async () => {
  loadRole()
  loading.value = true
  try {
    await accountStore.fetchAccounts()
    accounts.value = accountStore.accounts

    const { data } = await supabase
      .from('account_transfers')
      .select('*, from_account:from_account_id(code, short_name, ip_code), to_account:to_account_id(code, short_name, ip_code), creator:created_by(name)')
      .order('created_at', { ascending: false })
    transfers.value = (data || []).map(t => ({
      ...t,
      from_code: t.from_account?.code || '—',
      to_code: t.to_account?.code || '—',
      from_name: t.from_account?.short_name || t.from_account?.code || '—',
      to_name: t.to_account?.short_name || t.to_account?.code || '—',
      creator_name: t.creator?.name || '',
    }))
  } catch (e) {
    console.error('Failed to load transfers:', e)
  } finally {
    loading.value = false
  }
})

async function handleTransfer() {
  if (!form.from_account_id || !form.to_account_id || !form.amount) return
  if (form.from_account_id === form.to_account_id) {
    toast('不能转给自己', 'warning')
    return
  }

  // 余额校验：转出金额 + 手续费不能超过账户余额
  const fromAccount = accounts.value.find(a => a.id === form.from_account_id)
  const fee = effectiveFee.value
  const totalDebit = Number(form.amount) + fee
  if (fromAccount && Number(fromAccount.balance) < totalDebit) {
    toast(`余额不足！账户 ${fromAccount.code} 余额 ¥${Number(fromAccount.balance).toFixed(2)}，需要 ¥${totalDebit.toFixed(2)}`, 'warning')
    return
  }

  submitting.value = true
  try {
    // 构建备注
    let transferNote = form.note || ''
    if (isPlatformWithdraw.value) {
      const autoNote = `${platformFeeLabel.value}提现 | 技术服务费¥${form.fee_detail.technical_fee || 0} + 支付通道费¥${form.fee_detail.payment_fee || 0} + 提现手续费¥${form.fee_detail.withdraw_fee || 0}${form.fee_detail.other_fee ? ' + 其他¥' + form.fee_detail.other_fee : ''}`
      transferNote = transferNote ? `${autoNote}\n${transferNote}` : autoNote
    }

    // 转账前读取两个账户余额
    const fromAccBefore = await getAccountBalance(form.from_account_id)
    const toAccBefore = await getAccountBalance(form.to_account_id)

    // 1. 先插入转账记录（保证有据可查）
    const { data, error } = await supabase
      .from('account_transfers')
      .insert({
        from_account_id: form.from_account_id,
        to_account_id: form.to_account_id,
        amount: Number(form.amount),
        fee: fee,
        note: transferNote || null,
        transfer_date: new Date().toISOString(),
      })
      .select('*, from_account:from_account_id(code, short_name), to_account:to_account_id(code, short_name)')
      .single()

    if (error) throw error

    // 2. 记录插入成功后，更新账户余额
    let transferResult = null
    try {
      const { useAccountStore } = await import('../stores/accounts')
      const accStore = useAccountStore()
      // 转出账户扣款（金额 + 外扣手续费）
      const totalDebit = fee > 0 && form.fee_mode === 'from_balance'
        ? Number(form.amount) + fee
        : Number(form.amount)
      await accStore.updateBalance(form.from_account_id, -totalDebit)
      // 转入账户加款（金额 - 内扣手续费）
      const actualCredit = fee > 0 && form.fee_mode === 'deduct'
        ? Number(form.amount) - fee
        : Number(form.amount)
      await accStore.updateBalance(form.to_account_id, actualCredit)
    } catch (balErr) {
      // 余额更新失败，删除刚插入的记录保持一致性
      console.error('余额更新失败，回滚转账记录:', balErr)
      await supabase.from('account_transfers').delete().eq('id', data.id)
      throw new Error('余额更新失败，转账已回滚：' + (balErr.message || balErr))
    }

    transfers.value.unshift({
      ...data,
      from_code: data.from_account?.code || '—',
      to_code: data.to_account?.code || '—',
      from_name: data.from_account?.short_name || data.from_account?.code || '—',
      to_name: data.to_account?.short_name || data.to_account?.code || '—',
      creator_name: '',
    })

    const fromName = fromAccBefore?.name || data.from_account?.short_name || data.from_account?.code || ''
    const toName = toAccBefore?.name || data.to_account?.short_name || data.to_account?.code || ''

    // 操作日志（两个账户各记一条）
    try {
      const fromOld = Number(fromAccBefore?.balance ?? 0)
      const toOld = Number(toAccBefore?.balance ?? 0)
      const totalDebitLog = fee > 0 && form.fee_mode === 'from_balance' ? Number(form.amount) + fee : Number(form.amount)
      const actualCreditLog = fee > 0 && form.fee_mode === 'deduct' ? Number(form.amount) - fee : Number(form.amount)
      const fromNew = fromOld - totalDebitLog
      const toNew = toOld + actualCreditLog
      const fromDebit = totalDebitLog
      const toCredit = actualCreditLog

      // from 账户：余额减少
      logOperation({
        action: 'transfer_out',
        module: '转账',
        description: `转出 ${formatMoneyStr(fromDebit)} 至 ${toName}${fee > 0 ? `，费用 ${formatMoneyStr(fee)}（${form.fee_mode === 'from_balance' ? '外扣' : '内扣'}）` : ''}，余额 ${fromOld.toFixed(2)} - ${fromDebit.toFixed(2)} → ${fromNew.toFixed(2)}`,
        detail: { transfer_id: data.id, amount: form.amount, fee, fee_mode: form.fee_mode, from_debit: fromDebit, to_account_id: form.to_account_id, to_name: toName },
        amount: fromDebit,
        accountId: form.from_account_id,
        accountName: fromName,
      })
      // to 账户：余额增加
      logOperation({
        action: 'transfer_in',
        module: '转账',
        description: `收到 ${fromName} 转入 ${formatMoneyStr(toCredit)}，余额 ${toOld.toFixed(2)} + ${toCredit.toFixed(2)} → ${toNew.toFixed(2)}`,
        detail: { transfer_id: data.id, amount: form.amount, fee, fee_mode: form.fee_mode, to_credit: toCredit, from_account_id: form.from_account_id, from_name: fromName },
        amount: toCredit,
        accountId: form.to_account_id,
        accountName: toName,
      })
    } catch (_) {}

    // 刷新账户余额
    const { useAccountStore: _accStore } = await import('../stores/accounts')
    await _accStore().fetchAccounts(true)

    showTransferModal.value = false
    form.from_account_id = ''
    form.to_account_id = ''
    form.amount = null
    form.fee = 0
    form.note = ''
    form.fee_detail = { technical_fee: 0, payment_fee: 0, withdraw_fee: 0, other_fee: 0 }
    toast('转账记录已保存', 'success')
  } catch (e) {
    console.error(e)
    toast('转账失败：' + (e.message || '未知错误'), 'error')
  } finally {
    submitting.value = false
  }
}

async function handleDeleteTransfer(t) {
  if (!confirm('确定要删除此转账记录吗？')) return
  try {
    // 转账前读取两个账户余额
    const { getAccountBalance } = await import('../utils/operationLogger')
    const fromAccBefore = t.from_account_id ? await getAccountBalance(t.from_account_id) : null
    const toAccBefore = t.to_account_id ? await getAccountBalance(t.to_account_id) : null

    // 用批量 RPC 统一处理（含余额退回）
    const { data, error } = await supabase.rpc('batch_delete_transfers', { p_ids: [t.id] })
    if (error) throw error

    // 操作日志（两个账户各记一条）
    try {
      const { logOperation } = await import('../utils/operationLogger')
      const fromOld = Number(fromAccBefore?.balance ?? 0)
      const toOld = Number(toAccBefore?.balance ?? 0)
      const amount = Number(t.amount || 0)
      const fromName = fromAccBefore?.name || ''
      const toName = toAccBefore?.name || ''
      if (t.from_account_id && amount > 0) {
        logOperation({
          action: 'delete_transfer',
          module: '转账',
          description: `删除转账，${fromName} 退回 ${amount.toFixed(2)}，余额 ${fromOld.toFixed(2)} + ${amount.toFixed(2)} → ${(fromOld + amount).toFixed(2)}`,
          detail: { transfer_id: t.id, amount, from_account_id: t.from_account_id, from_name: fromName },
          amount,
          accountId: t.from_account_id,
          accountName: fromName,
        })
      }
      if (t.to_account_id && amount > 0) {
        logOperation({
          action: 'delete_transfer',
          module: '转账',
          description: `删除转账，${toName} 扣回 ${amount.toFixed(2)}，余额 ${toOld.toFixed(2)} - ${amount.toFixed(2)} → ${(toOld - amount).toFixed(2)}`,
          detail: { transfer_id: t.id, amount, to_account_id: t.to_account_id, to_name: toName },
          amount,
          accountId: t.to_account_id,
          accountName: toName,
        })
      }
    } catch (_) {}
    toast('转账已删除', 'success')
    transfers.value = transfers.value.filter(x => x.id !== t.id)
    selectedIds.value = selectedIds.value.filter(id => id !== t.id)
  } catch (e) {
    toast(e.message || '操作失败', 'error')
  }
}

async function handleBatchDelete() {
  if (!confirm(`确定要删除选中的 ${selectedIds.value.length} 条转账记录吗？`)) return
  // 收集选中的转账信息（用于余额退回和日志记录）
  const selectedTransfers = transfers.value.filter(t => selectedIds.value.includes(t.id))
  try {
    const { data, error } = await supabase.rpc('batch_delete_transfers', { p_ids: selectedIds.value })
    if (error) throw error
    // 退回余额：from_account 加回来，to_account 扣回去
    const { useAccountStore } = await import('../stores/accounts')
    const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
    for (const t of selectedTransfers) {
      let fromBal = null, toBal = null
      if (t.from_account_id && t.amount) {
        try { fromBal = await useAccountStore().updateBalance(t.from_account_id, Number(t.amount)) } catch (_) {}
      }
      if (t.to_account_id && t.amount) {
        try { toBal = await useAccountStore().updateBalance(t.to_account_id, -Number(t.amount)) } catch (_) {}
      }
      try {
        const fromAcc = t.from_account_id ? await getAccountBalance(t.from_account_id) : null
        const toAcc = t.to_account_id ? await getAccountBalance(t.to_account_id) : null
        logOperation({
          action: 'delete_transfer',
          module: '转账',
          description: `[批量删除] 删除转账 ${t.transfer_no || ''}，金额 ${Number(t.amount || 0).toFixed(2)}，${fromAcc?.name || ''} → ${toAcc?.name || ''}`,
          detail: { transfer_id: t.id, amount: t.amount, from_account: fromAcc?.name, to_account: toAcc?.name, from_balance_before: fromBal?.old_balance, from_balance_after: fromBal?.new_balance, to_balance_before: toBal?.old_balance, to_balance_after: toBal?.new_balance },
          amount: t.amount,
        })
      } catch (_) {}
    }
    toast(`已删除 ${data?.deleted || 0} 条转账记录`, 'success')
    transfers.value = transfers.value.filter(x => !selectedIds.value.includes(x.id))
    selectedIds.value = []
  } catch (e) {
    toast('批量删除失败：' + (e.message || ''), 'error')
  }
}

// ========== Text Mode: Parse & Submit ==========

function parseTransferText(text) {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  const results = []

  const activeAccs = accountStore.getActiveAccounts()
  const accountNameMap = {}
  for (const a of activeAccs) {
    const names = [a.short_name || a.code].filter(Boolean)
    if (a.payment_alias) names.push(a.payment_alias)
    for (const n of names) {
      if (!accountNameMap[n] || n.length > (accountNameMap[n] || '').length) {
        accountNameMap[n] = { id: a.id, label: a.short_name || a.code }
      }
    }
  }
  const accountNames = Object.keys(accountNameMap).sort((a, b) => b.length - a.length)

  for (const line of lines) {
    let fromAccountId = ''
    let toAccountId = ''
    let amount = 0
    let date = null
    let note = ''

    // 1. Extract amount (support 万 unit, comma separator)
    const wan = line.match(/([\d.]+)\s*万/)
    if (wan && parseFloat(wan[1]) > 0) {
      amount = parseFloat(wan[1]) * 10000
    } else {
      const m = line.match(/[￥¥]?\s*([\d,]+\.?\d*)\s*元/)
      if (m && parseFloat(m[1]) > 0) {
        amount = parseFloat(m[1].replace(/,/g, ''))
      }
    }

    // 2. Extract date
    const dm = line.match(/(\d{1,2})月(\d{1,2})日/)
    if (dm) date = dm[0]
    if (!dm) {
      const dayOnly = line.match(/(\d{1,2})日/)
      if (dayOnly) date = dayOnly[0]
    }

    // 3. Keyword-based routing
    // ── 转卡: 余利宝 → 中信卡
    if (/^转卡/.test(line)) {
      fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '余利宝')
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '中信')
      note = line.replace(/^转卡\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    // ── 转余利宝: 中信卡 → 余利宝
    else if (/^转余利宝/.test(line)) {
      fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '中信')
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '余利宝')
      note = line.replace(/^转余利宝\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    // ── 转中信 / 转平安: → 中信卡/平安卡
    else if (/^转中信/.test(line)) {
      fromAccountId = ''
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '中信')
      note = line.replace(/^转中信\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    else if (/^转平安/.test(line)) {
      fromAccountId = ''
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '平安')
      note = line.replace(/^转平安\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    // ── 转（一般户）任公户 / 基本户→一般户: 任公户基本户 → 任公户一般户
    else if (/^转（一般户）任公户/.test(line) || /^基本户→一般户/.test(line)) {
      fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '任公户基本户') || fuzzyMatchAccount(accountNames, accountNameMap, '任公户基本')
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '任公户一般户') || fuzzyMatchAccount(accountNames, accountNameMap, '任公户一般')
      note = line.replace(/^[转（一般户）任公户]+\s*/, '').replace(/^基本户→一般户\s*/, '')
        .replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    // ── XX公户收: from platform → XX公户
    else if (/^(.{1,4})公户收/.test(line)) {
      const gonghuMatch = line.match(/^(.{1,4})公户收/)
      const gonghuName = gonghuMatch[1] // e.g. "珊"
      // to_account: XX公户 (e.g. 珊公户)
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, gonghuName + '公户')
      // from_account: find platform keyword in text (e.g. "南快手到账")
      const platformMatch = line.match(/(.{2,10}?)到账/)
      if (platformMatch) {
        fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, platformMatch[1])
      }
      note = line.replace(/^(.{1,4})公户收\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/(.{2,10}?)到账/, '$1').replace(/\s+/g, ' ').trim()
    }
    // ── 南1入账: 现金 → 南1微信
    else if (/^南1入账/.test(line)) {
      fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '现金')
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, '南1') || fuzzyMatchAccount(accountNames, accountNameMap, '南1微信')
      note = line.replace(/^南1入账\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/\s+/g, ' ').trim()
    }
    // ── XX到账: from platform → account at end of text
    else if (/到账/.test(line)) {
      // Find platform keyword before "到账"
      const platformMatch = line.match(/(.{2,10}?)到账/)
      if (platformMatch) {
        fromAccountId = fuzzyMatchAccount(accountNames, accountNameMap, platformMatch[1])
      }
      // to_account: match from end of text (after removing amount, date, keywords)
      const stripped = line.replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*$/, '').replace(/\d{1,2}月?\d{0,2}日?\s*$/, '')
        .replace(/(.{2,10}?)到账/, '').replace(/^(卡收|卡付)\s*/, '').replace(/\s+/g, ' ').trim()
      toAccountId = fuzzyMatchAccount(accountNames, accountNameMap, stripped)
      // Also try matching end of original line
      if (!toAccountId) {
        const endStripped = line.replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*$/, '').replace(/\d{1,2}月?\d{0,2}日?\s*$/, '').trim()
        for (const name of accountNames) {
          if (endStripped.endsWith(name) && name.length > 1) {
            toAccountId = accountNameMap[name].id
            break
          }
        }
      }
      note = line.replace(/^(卡收|卡付)\s*/, '').replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
        .replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '').replace(/(.{2,10}?)到账/, '$1')
      // Remove matched account name from note
      for (const name of accountNames) {
        if (note.endsWith(name) && name.length > 1) {
          note = note.slice(0, -name.length).trim()
          break
        }
      }
      note = note.replace(/\s+/g, ' ').trim()
    }
    // ── Generic: try to detect any transfer pattern
    else {
      // Try to match account names at beginning and end
      const stripped = line.replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*$/, '').replace(/\d{1,2}月?\d{0,2}日?\s*$/, '').trim()
      for (const name of accountNames) {
        if (stripped.startsWith(name) && name.length > 1) {
          fromAccountId = accountNameMap[name].id
          const remaining = stripped.slice(name.length).trim()
          for (const name2 of accountNames) {
            if (remaining.includes(name2) && name2.length > 1 && name2 !== name) {
              toAccountId = accountNameMap[name2].id
              break
            }
          }
          break
        }
      }
      // Also try end of line for to_account
      if (!toAccountId) {
        for (const name of accountNames) {
          if (stripped.endsWith(name) && name.length > 1) {
            toAccountId = accountNameMap[name].id
            break
          }
        }
      }
      note = stripped
      for (const name of accountNames) {
        if (note.startsWith(name)) note = note.slice(name.length).trim()
        break
      }
      for (const name of accountNames) {
        if (note.endsWith(name) && name.length > 1) { note = note.slice(0, -name.length).trim(); break }
      }
      note = note.replace(/\s+/g, ' ').trim()
    }

    results.push({
      _rawText: line,
      from_account_id: fromAccountId,
      to_account_id: toAccountId,
      amount: amount || null,
      note,
      date: date || null,
      transfer_date: null,
    })
  }

  return results
}

/**
 * Fuzzy match an account name from the accountNames list (sorted longest first).
 * Returns the account id or empty string.
 */
function fuzzyMatchAccount(accountNames, accountNameMap, keyword) {
  if (!keyword) return ''
  // Exact match first
  if (accountNameMap[keyword]) return accountNameMap[keyword].id
  // Contains match (longest first)
  for (const name of accountNames) {
    if (name.includes(keyword) && keyword.length >= 1) {
      return accountNameMap[name].id
    }
  }
  // Reverse: keyword contains account name
  for (const name of accountNames) {
    if (keyword.includes(name) && name.length > 1) {
      return accountNameMap[name].id
    }
  }
  return ''
}

function handleParseTransfers() {
  parseError.value = ''
  if (!rawText.value.trim()) return
  try {
    const transfers = parseTransferText(rawText.value)
    if (transfers.length === 0) {
      parseError.value = '未能解析出任何转账记录，请检查文本格式'
      parsedTransfers.value = []
      return
    }
    parsedTransfers.value = transfers.map(tr => {
      if (tr.date) {
        const dm = tr.date.match(/(\d{1,2})月(\d{1,2})/)
        if (dm) {
          const year = transferMonth.value.getFullYear()
          const month = parseInt(dm[1]) - 1
          const day = parseInt(dm[2])
          tr.transfer_date = new Date(year, month, day).toISOString().slice(0, 10)
        }
      } else if (/^\d{1,2}日?$/.test(tr.date || '')) {
        const dayMatch = (tr.date || '').match(/(\d{1,2})/)
        if (dayMatch) {
          const year = transferMonth.value.getFullYear()
          const month = transferMonth.value.getMonth()
          const day = parseInt(dayMatch[1])
          tr.transfer_date = new Date(year, month, day).toISOString().slice(0, 10)
        }
      } else {
        tr.transfer_date = new Date().toISOString().slice(0, 10)
      }
      return tr
    })
  } catch (e) {
    console.error('解析失败:', e)
    parseError.value = '解析出错: ' + (e.message || '未知错误')
    parsedTransfers.value = []
  }
}

async function submitParsedTransfer(idx) {
  const tr = parsedTransfers.value[idx]
  if (!tr || !tr.amount) {
    toast('请填写金额', 'warning')
    return
  }
  if (!tr.from_account_id || !tr.to_account_id) {
    toast('请选择转出和转入账户', 'warning')
    return
  }
  if (tr.from_account_id === tr.to_account_id) {
    toast('不能转给自己', 'warning')
    return
  }
  submittingParsed.value = true
  try {
    const userId = (await supabase.auth.getSession()).data.session?.user?.id

    // 先通过 RPC 原子转账，成功后再插入记录
    const { data: rpcResult, error: rpcError } = await supabase.rpc('transfer_balance', {
      p_from: tr.from_account_id,
      p_to: tr.to_account_id,
      p_amount: Number(tr.amount),
      p_fee: 0,
      p_fee_mode: null
    })
    if (rpcError) throw rpcError

    // RPC 成功后插入转账记录
    const { data, error } = await supabase
      .from('account_transfers')
      .insert({
        from_account_id: tr.from_account_id,
        to_account_id: tr.to_account_id,
        amount: Number(tr.amount),
        fee: 0,
        note: tr.note || null,
        created_by: userId,
        status: 'completed',
        transfer_date: tr.transfer_date || new Date().toISOString().slice(0, 10),
      })
      .select('*, from_account:from_account_id(code, short_name), to_account:to_account_id(code, short_name)')
      .single()

    if (error) throw error

    transfers.value.unshift({
      ...data,
      from_code: data.from_account?.code || '—',
      to_code: data.to_account?.code || '—',
      from_name: data.from_account?.short_name || data.from_account?.code || '—',
      to_name: data.to_account?.short_name || data.to_account?.code || '—',
      creator_name: '',
    })

    // 操作日志
    try {
      const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
      const fromInfo = await getAccountBalance(tr.from_account_id)
      const toInfo = await getAccountBalance(tr.to_account_id)
      logOperation({
        action: 'create_transfer',
        module: '转账',
        description: `创建转账 ${Number(tr.amount).toFixed(2)}，${fromInfo?.name || ''} → ${toInfo?.name || ''}`,
        detail: { amount: tr.amount, from_account_id: tr.from_account_id, to_account_id: tr.to_account_id, from_name: fromInfo?.name, to_name: toInfo?.name },
        amount: tr.amount,
      })
    } catch (_) {}

    parsedTransfers.value.splice(idx, 1)
    toast('转账记录已保存', 'success')
  } catch (e) {
    toast('提交失败：' + (e.message || ''), 'error')
  } finally {
    submittingParsed.value = false
  }
}

async function submitAllParsedTransfers() {
  const valid = parsedTransfers.value.filter(e => e.amount && e.from_account_id && e.to_account_id && e.from_account_id !== e.to_account_id)
  if (valid.length === 0) {
    toast('没有可提交的转账（请确保每条都有金额和有效的转出/转入账户）', 'warning')
    return
  }
  if (!confirm(`确认批量提交 ${valid.length} 条转账？`)) return
  submittingParsed.value = true
  let successCount = 0
  let failCount = 0
  try {
    const userId = (await supabase.auth.getSession()).data.session?.user?.id
    for (const tr of valid) {
      try {
        const { data, error } = await supabase
          .from('account_transfers')
          .insert({
            from_account_id: tr.from_account_id,
            to_account_id: tr.to_account_id,
            amount: Number(tr.amount),
            fee: 0,
            note: tr.note || null,
            created_by: userId,
            status: 'completed',
            transfer_date: tr.transfer_date || new Date().toISOString().slice(0, 10),
          })
          .select('*, from_account:from_account_id(code, short_name), to_account:to_account_id(code, short_name)')
          .single()

        if (error) throw error

        transfers.value.unshift({
          ...data,
          from_code: data.from_account?.code || '—',
          to_code: data.to_account?.code || '—',
          from_name: data.from_account?.short_name || data.from_account?.code || '—',
          to_name: data.to_account?.short_name || data.to_account?.code || '—',
          creator_name: '',
        })

        // ⚠️ 用 transfer_balance RPC 原子转账（批量内也用 RPC，防止中途失败导致不一致）
        try {
          const { data: rpcResult, error: rpcError } = await supabase.rpc('transfer_balance', {
            p_from: tr.from_account_id,
            p_to: tr.to_account_id,
            p_amount: Number(tr.amount),
            p_fee: 0,
            p_fee_mode: null
          })
          if (rpcError) throw rpcError
        } catch (e) {
          console.error('❌ 批量转账余额变动失败，转出:', tr.from_account_id, '转入:', tr.to_account_id, '金额:', tr.amount, e)
        }

        // 操作日志
        try {
          const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
          const fromInfo = await getAccountBalance(tr.from_account_id)
          const toInfo = await getAccountBalance(tr.to_account_id)
          logOperation({
            action: 'create_transfer',
            module: '转账',
            description: `[批量] 创建转账 ${Number(tr.amount).toFixed(2)}，${fromInfo?.name || ''} → ${toInfo?.name || ''}`,
            detail: { amount: tr.amount, from_account_id: tr.from_account_id, to_account_id: tr.to_account_id, from_name: fromInfo?.name, to_name: toInfo?.name },
            amount: tr.amount,
          })
        } catch (_) {}

        successCount++
      } catch (e) {
        failCount++
        console.error('提交失败:', e)
      }
    }
  } catch (e) {
    toast('批量提交出错：' + (e.message || ''), 'error')
  } finally {
    submittingParsed.value = false
    parsedTransfers.value = []
    toast(`成功提交 ${successCount} 条${failCount > 0 ? `，失败 ${failCount} 条` : ''}`, successCount > 0 ? 'success' : 'error')
  }
}
</script>
