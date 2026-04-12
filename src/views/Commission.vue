<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">💰 提成管理</h1>
      <div class="flex gap-2">
        <!-- Tab switcher -->
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key"
          class="px-4 py-2 rounded-lg text-sm transition cursor-pointer"
          :class="activeTab === tab.key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-500 hover:bg-gray-50'">
          {{ tab.icon }} {{ tab.label }}
        </button>
      </div>
    </div>

    <!-- ==================== 规则配置 Tab ==================== -->
    <template v-if="activeTab === 'rules'">
      <!-- Admin only guard -->
      <div v-if="!auth.isAdmin" class="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-500">
        🔒 仅管理员可访问提成规则配置
      </div>
      <template v-else>
        <!-- Add rule button -->
        <div class="flex justify-end mb-4">
          <button @click="openRuleModal()" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
            ➕ 添加规则
          </button>
        </div>

        <!-- Loading -->
        <div v-if="rulesLoading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
          <div class="text-2xl mb-2 animate-pulse">⚙️</div>
          <div class="text-gray-500 text-sm">加载规则数据...</div>
        </div>

        <!-- Rules table -->
        <div v-else class="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 text-gray-600">
                <th class="px-4 py-3 text-left font-medium">角色</th>
                <th class="px-4 py-3 text-left font-medium">规则名称</th>
                <th class="px-4 py-3 text-left font-medium">类型</th>
                <th class="px-4 py-3 text-right font-medium">比例/金额</th>
                <th class="px-4 py-3 text-right font-medium">最低金额</th>
                <th class="px-4 py-3 text-right font-medium">最高金额</th>
                <th class="px-4 py-3 text-center font-medium">状态</th>
                <th class="px-4 py-3 text-center font-medium">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="rule in rules" :key="rule.id"
                class="border-t border-gray-50 hover:bg-gray-50/60 transition">
                <td class="px-4 py-3">
                  <span class="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700">
                    {{ roleLabel(rule.role) }}
                  </span>
                </td>
                <td class="px-4 py-3 font-medium text-gray-800">{{ rule.rule_name }}</td>
                <td class="px-4 py-3 text-gray-600">{{ rule.commission_type === 'percentage' ? '按比例' : '固定金额' }}</td>
                <td class="px-4 py-3 text-right font-semibold" :class="rule.commission_type === 'percentage' ? 'text-blue-600' : 'text-green-600'">
                  {{ rule.commission_type === 'percentage' ? (rule.rate * 100).toFixed(1) + '%' : formatMoney(rule.rate) }}
                </td>
                <td class="px-4 py-3 text-right text-gray-500">{{ rule.min_amount ? formatMoney(rule.min_amount) : '-' }}</td>
                <td class="px-4 py-3 text-right text-gray-500">{{ rule.max_amount ? formatMoney(rule.max_amount) : '-' }}</td>
                <td class="px-4 py-3 text-center">
                  <span class="text-xs px-2 py-0.5 rounded-full" :class="rule.status === 'active' ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500'">
                    {{ rule.status === 'active' ? '启用' : '停用' }}
                  </span>
                </td>
                <td class="px-4 py-3 text-center">
                  <div class="flex items-center justify-center gap-1">
                    <button @click="openRuleModal(rule)" class="px-2 py-1 text-blue-600 hover:bg-blue-50 rounded cursor-pointer" title="编辑">
                      ✏️
                    </button>
                    <button @click="toggleRuleStatus(rule)" class="px-2 py-1 hover:bg-gray-50 rounded cursor-pointer" :title="rule.status === 'active' ? '停用' : '启用'">
                      {{ rule.status === 'active' ? '⏸️' : '▶️' }}
                    </button>
                  </div>
                </td>
              </tr>
              <tr v-if="rules.length === 0">
                <td colspan="8" class="px-4 py-12 text-center text-gray-500">暂无提成规则，点击上方按钮添加</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>

    <!-- ==================== 月度汇总 Tab ==================== -->
    <template v-if="activeTab === 'summary'">
      <!-- Filters -->
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="summaryMonth" type="month"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        <button @click="loadSummary" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm hover:bg-gray-200 cursor-pointer">
          🔄 刷新
        </button>
      </div>

      <!-- Loading -->
      <div v-if="summaryLoading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
        <div class="text-2xl mb-2 animate-pulse">📊</div>
        <div class="text-gray-500 text-sm">加载提成汇总...</div>
      </div>

      <template v-else>
        <!-- Summary cards -->
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <div class="bg-white rounded-xl border border-gray-100 p-5">
            <div class="text-sm text-gray-500 mb-1">💰 提成总额</div>
            <div class="text-2xl font-bold text-green-600">{{ formatMoney(summaryStats.totalCommission) }}</div>
          </div>
          <div class="bg-white rounded-xl border border-gray-100 p-5">
            <div class="text-sm text-gray-500 mb-1">👥 发放人数</div>
            <div class="text-2xl font-bold text-blue-600">{{ summaryStats.totalPeople }}</div>
          </div>
          <div class="bg-white rounded-xl border border-gray-100 p-5">
            <div class="text-sm text-gray-500 mb-1">⏳ 待确认</div>
            <div class="text-2xl font-bold text-orange-500">{{ summaryStats.pendingCount }}</div>
          </div>
          <div class="bg-white rounded-xl border border-gray-100 p-5">
            <div class="text-sm text-gray-500 mb-1">✅ 已发放</div>
            <div class="text-2xl font-bold text-green-500">{{ summaryStats.paidCount }}</div>
          </div>
        </div>

        <!-- Summary table -->
        <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <div class="px-4 py-3 border-b border-gray-100">
            <h2 class="font-bold text-gray-700">📋 提成明细</h2>
          </div>
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 text-gray-600">
                <th class="px-4 py-3 text-left font-medium">姓名</th>
                <th class="px-4 py-3 text-left font-medium">角色</th>
                <th class="px-4 py-3 text-right font-medium">提成基数</th>
                <th class="px-4 py-3 text-right font-medium">比例</th>
                <th class="px-4 py-3 text-right font-medium">提成金额</th>
                <th class="px-4 py-3 text-center font-medium">来源</th>
                <th class="px-4 py-3 text-center font-medium">状态</th>
                <th v-if="auth.isAdmin" class="px-4 py-3 text-center font-medium">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="record in summaryRecords" :key="record.id"
                class="border-t border-gray-50 hover:bg-gray-50/60 transition">
                <td class="px-4 py-3 font-medium text-gray-800">{{ record.user_name || record.user_id?.slice(0, 8) }}</td>
                <td class="px-4 py-3">
                  <span class="text-xs px-2 py-0.5 rounded-full"
                    :class="record.user_role === 'sales' ? 'bg-blue-50 text-blue-700' : 'bg-gray-50 text-gray-600'">
                    {{ roleLabel(record.user_role) }}
                  </span>
                </td>
                <td class="px-4 py-3 text-right text-gray-700">{{ formatMoney(record.base_amount) }}</td>
                <td class="px-4 py-3 text-right text-gray-600">
                  <template v-if="record.commission_type === 'percentage'">
                    {{ (record.rate * 100).toFixed(1) }}%
                  </template>
                  <template v-else>固定</template>
                </td>
                <td class="px-4 py-3 text-right font-semibold text-green-600">{{ formatMoney(record.commission_amount) }}</td>
                <td class="px-4 py-3 text-center">
                  <span class="text-xs text-gray-500">{{ sourceLabel(record.source_type) }}</span>
                </td>
                <td class="px-4 py-3 text-center">
                  <span class="text-xs px-2 py-0.5 rounded-full" :class="statusClass(record.status)">
                    {{ statusLabel(record.status) }}
                  </span>
                </td>
                <td v-if="auth.isAdmin" class="px-4 py-3 text-center">
                  <select :value="record.status" @change="updateRecordStatus(record, $event.target.value)"
                    class="text-xs px-2 py-1 border border-gray-200 rounded outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
                    <option value="pending">待确认</option>
                    <option value="confirmed">已确认</option>
                    <option value="paid">已发放</option>
                  </select>
                </td>
              </tr>
              <tr v-if="summaryRecords.length === 0">
                <td :colspan="auth.isAdmin ? 8 : 7" class="px-4 py-12 text-center text-gray-500">当月暂无提成数据</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>

    <!-- ==================== 规则编辑弹窗 ==================== -->
    <Teleport to="body">
      <div v-if="showRuleModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center" @click.self="showRuleModal = false">
        <div class="bg-white rounded-xl shadow-xl w-full max-w-md mx-4 overflow-hidden">
          <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
            <h3 class="font-bold text-gray-800">{{ editingRule.id ? '编辑规则' : '添加规则' }}</h3>
            <button @click="showRuleModal = false" class="text-gray-500 hover:text-gray-600 cursor-pointer text-xl leading-none">&times;</button>
          </div>
          <div class="p-5 space-y-4">
            <!-- 角色选择 -->
            <div>
              <label class="block text-sm text-gray-600 mb-1">适用角色</label>
              <select v-model="editingRule.role" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="">请选择</option>
                <option value="sales">销售</option>
                <option value="cs">客服</option>
                <option value="manager">经理</option>
                <option value="coach">教练</option>
              </select>
            </div>
            <!-- 规则名称 -->
            <div>
              <label class="block text-sm text-gray-600 mb-1">规则名称</label>
              <input v-model="editingRule.rule_name" type="text" placeholder="例：销售基础提成"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <!-- 提成类型 -->
            <div>
              <label class="block text-sm text-gray-600 mb-1">提成类型</label>
              <select v-model="editingRule.commission_type" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
                <option value="percentage">按比例</option>
                <option value="fixed">固定金额</option>
              </select>
            </div>
            <!-- 比例/金额 -->
            <div>
              <label class="block text-sm text-gray-600 mb-1">
                {{ editingRule.commission_type === 'percentage' ? '提成比例（小数，如 0.05 = 5%）' : '固定金额（元）' }}
              </label>
              <input v-model.number="editingRule.rate" type="number" step="any" min="0" placeholder="0"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <!-- 最低/最高金额 -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm text-gray-600 mb-1">最低金额（可选）</label>
                <input v-model.number="editingRule.min_amount" type="number" step="any" min="0" placeholder="0"
                  class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              </div>
              <div>
                <label class="block text-sm text-gray-600 mb-1">最高金额（可选）</label>
                <input v-model.number="editingRule.max_amount" type="number" step="any" min="0" placeholder="0"
                  class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              </div>
            </div>
            <!-- 条件（JSON） -->
            <div>
              <label class="block text-sm text-gray-600 mb-1">附加条件（JSON，可选）</label>
              <textarea v-model="editingRule.conditions" rows="2" placeholder='例：{"min_orders": 10}'
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none font-mono"></textarea>
            </div>
            <!-- 状态 -->
            <div class="flex items-center gap-2">
              <input type="checkbox" v-model="editingRule.active" id="rule-active" class="rounded">
              <label for="rule-active" class="text-sm text-gray-600">启用规则</label>
            </div>
          </div>
          <div class="px-5 py-4 border-t border-gray-100 flex justify-end gap-2">
            <button @click="showRuleModal = false" class="px-4 py-2 text-gray-500 rounded-lg text-sm hover:bg-gray-50 cursor-pointer">
              取消
            </button>
            <button @click="saveRule" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
              保存
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, toast, COMMISSION_STATUS, COMMISSION_SOURCE } from '../lib/utils'

const auth = useAuthStore()

// ===== Tabs =====
const activeTab = ref('summary')
const tabs = computed(() => {
  const list = [
    { key: 'summary', icon: '📊', label: '月度汇总' },
  ]
  if (auth.isAdmin) {
    list.unshift({ key: 'rules', icon: '⚙️', label: '规则配置' })
  }
  return list
})

// ===== Role labels =====
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
  return roleLabels[role] || role || '-'
}

function statusLabel(status) {
  return COMMISSION_STATUS[status]?.label || status
}

function statusClass(status) {
  return COMMISSION_STATUS[status]?.class || 'text-gray-500 bg-gray-50'
}

function sourceLabel(type) {
  return COMMISSION_SOURCE[type] || type || '-'
}

// ===== Rules Tab =====
const rulesLoading = ref(true)
const rules = ref([])
const showRuleModal = ref(false)
const editingRule = reactive({
  id: null,
  role: '',
  rule_name: '',
  commission_type: 'percentage',
  rate: 0,
  min_amount: null,
  max_amount: null,
  conditions: '',
  active: true,
})

function openRuleModal(rule = null) {
  if (rule) {
    editingRule.id = rule.id
    editingRule.role = rule.role
    editingRule.rule_name = rule.rule_name
    editingRule.commission_type = rule.commission_type
    editingRule.rate = rule.rate
    editingRule.min_amount = rule.min_amount
    editingRule.max_amount = rule.max_amount
    editingRule.conditions = typeof rule.conditions === 'string' ? rule.conditions : (rule.conditions ? JSON.stringify(rule.conditions, null, 2) : '')
    editingRule.active = rule.status === 'active'
  } else {
    editingRule.id = null
    editingRule.role = ''
    editingRule.rule_name = ''
    editingRule.commission_type = 'percentage'
    editingRule.rate = 0
    editingRule.min_amount = null
    editingRule.max_amount = null
    editingRule.conditions = ''
    editingRule.active = true
  }
  showRuleModal.value = true
}

async function loadRules() {
  rulesLoading.value = true
  try {
    const { data, error } = await supabase
      .from('commission_rules')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    rules.value = data || []
  } catch (e) {
    console.error('Failed to load commission rules:', e)
    toast('加载规则失败', 'error')
  } finally {
    rulesLoading.value = false
  }
}

async function saveRule() {
  // Validate
  if (!editingRule.role) {
    toast('请选择适用角色', 'warning')
    return
  }
  if (!editingRule.rule_name.trim()) {
    toast('请填写规则名称', 'warning')
    return
  }
  if (!editingRule.rate || editingRule.rate <= 0) {
    toast('请填写有效的比例/金额', 'warning')
    return
  }

  // Parse conditions
  let conditions = null
  if (editingRule.conditions.trim()) {
    try {
      conditions = JSON.parse(editingRule.conditions.trim())
    } catch {
      toast('附加条件 JSON 格式错误', 'warning')
      return
    }
  }

  const payload = {
    role: editingRule.role,
    rule_name: editingRule.rule_name.trim(),
    commission_type: editingRule.commission_type,
    rate: editingRule.rate,
    min_amount: editingRule.min_amount || null,
    max_amount: editingRule.max_amount || null,
    conditions,
    status: editingRule.active ? 'active' : 'inactive',
  }

  try {
    if (editingRule.id) {
      const { error } = await supabase
        .from('commission_rules')
        .update(payload)
        .eq('id', editingRule.id)
      if (error) throw error
      toast('规则已更新', 'success')
    } else {
      const { error } = await supabase
        .from('commission_rules')
        .insert(payload)
      if (error) throw error
      toast('规则已添加', 'success')
    }
    showRuleModal.value = false
    await loadRules()
  } catch (e) {
    console.error('Failed to save rule:', e)
    toast('保存失败：' + (e.message || '未知错误'), 'error')
  }
}

async function toggleRuleStatus(rule) {
  const newStatus = rule.status === 'active' ? 'inactive' : 'active'
  try {
    const { error } = await supabase
      .from('commission_rules')
      .update({ status: newStatus })
      .eq('id', rule.id)
    if (error) throw error
    rule.status = newStatus
    toast(newStatus === 'active' ? '规则已启用' : '规则已停用', 'success')
  } catch (e) {
    console.error('Failed to toggle rule status:', e)
    toast('操作失败', 'error')
  }
}

// ===== Summary Tab =====
const summaryLoading = ref(true)
const summaryMonth = ref('')
const summaryRecords = ref([])

const summaryStats = computed(() => {
  const records = summaryRecords.value
  const totalCommission = records.reduce((s, r) => s + Number(r.commission_amount || 0), 0)
  const userIds = new Set(records.map(r => r.user_id))
  return {
    totalCommission,
    totalPeople: userIds.size,
    pendingCount: records.filter(r => r.status === 'pending').length,
    paidCount: records.filter(r => r.status === 'paid').length,
  }
})

function getDefaultMonth() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

async function loadSummary() {
  if (!summaryMonth.value) return
  summaryLoading.value = true
  try {
    // Fetch commission records for the selected month
    // period format: "YYYY-MM"
    const { data, error } = await supabase
      .from('commission_records')
      .select('*')
      .eq('period', summaryMonth.value)
      .order('created_at', { ascending: false })
    if (error) throw error

    // Fetch user profiles for names/roles
    const records = data || []
    const userIds = [...new Set(records.map(r => r.user_id).filter(Boolean))]
    let userMap = {}
    if (userIds.length > 0) {
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, name, role')
        .in('id', userIds)
      ;(profiles || []).forEach(p => { userMap[p.id] = p })
    }

    summaryRecords.value = records.map(r => ({
      ...r,
      user_name: userMap[r.user_id]?.name || '',
      user_role: userMap[r.user_id]?.role || '',
      commission_type: r.rate !== null && r.rate > 0 && r.rate < 1 ? 'percentage' : 'fixed',
    }))
  } catch (e) {
    console.error('Failed to load summary:', e)
    toast('加载提成汇总失败', 'error')
  } finally {
    summaryLoading.value = false
  }
}

async function updateRecordStatus(record, newStatus) {
  try {
    const { error } = await supabase
      .from('commission_records')
      .update({ status: newStatus })
      .eq('id', record.id)
    if (error) throw error
    record.status = newStatus
    toast('状态已更新', 'success')
  } catch (e) {
    console.error('Failed to update status:', e)
    toast('更新失败', 'error')
    // Reload to revert UI
    await loadSummary()
  }
}

// ===== Init =====
onMounted(() => {
  summaryMonth.value = getDefaultMonth()
  if (auth.isAdmin) {
    loadRules()
  }
  loadSummary()
})
</script>
