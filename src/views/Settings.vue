<template>
  <div class="max-w-4xl mx-auto space-y-6">
    <h1 class="text-2xl font-bold text-gray-800"><Icon name="settings" class="inline w-4 h-4 -mt-0.5 mr-1" /> 系统设置</h1>

    <!-- 快捷入口 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <h2 class="text-lg font-semibold text-gray-700 mb-4">🔗 快捷入口</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <router-link to="/platform-integration"
          class="flex items-center gap-3 p-4 rounded-lg border border-gray-100 hover:border-blue-200 hover:bg-blue-50/50 transition group cursor-pointer">
          <span class="text-2xl">🔌</span>
          <div>
            <div class="text-sm font-medium text-gray-700 group-hover:text-blue-700 transition">平台对接</div>
            <div class="text-xs text-gray-500">配置抖店、快手、视频号、聚水潭 API 凭证</div>
          </div>
          <span class="ml-auto text-gray-300 group-hover:text-blue-400 transition">→</span>
        </router-link>
      </div>
    </div>

    <!-- 审批设置 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <h2 class="text-lg font-semibold text-gray-700 mb-4"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 审批设置</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">支出审批限额（元）</label>
          <input type="number" v-model.number="settings.approval_limit"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="超过此金额需审批" />
          <p class="text-xs text-gray-500 mt-1">单笔支出超过此限额需审批</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">转账手续费最大比例（%）</label>
          <input type="number" step="0.01" v-model.number="settings.transfer_fee_max_rate"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="0.01" />
          <p class="text-xs text-gray-500 mt-1">例如 0.01 表示 1%</p>
        </div>
      </div>
    </div>

    <!-- 提成设置 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <h2 class="text-lg font-semibold text-gray-700 mb-4"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 提成设置</h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">IP直播提成比例（%）</label>
          <input type="number" step="0.01" v-model.number="settings.live_commission_rate"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="0.05" />
          <p class="text-xs text-gray-500 mt-1">例如 0.05 表示 5%</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">销售员默认提成比例（%）</label>
          <input type="number" step="0.01" v-model.number="settings.sales_default_commission"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="0.05" />
          <p class="text-xs text-gray-500 mt-1">例如 0.05 表示 5%</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">客服默认提成比例（%）</label>
          <input type="number" step="0.01" v-model.number="settings.cs_default_commission"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
            placeholder="0.02" />
          <p class="text-xs text-gray-500 mt-1">例如 0.02 表示 2%</p>
        </div>
      </div>
    </div>

    <!-- 系统信息 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <h2 class="text-lg font-semibold text-gray-700 mb-4">🖥️ 系统信息</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">默认货币</label>
          <select v-model="settings.default_currency"
            class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none">
            <option value="CNY">CNY - 人民币</option>
            <option value="USD">USD - 美元</option>
            <option value="EUR">EUR - 欧元</option>
            <option value="HKD">HKD - 港币</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-600 mb-1">系统版本</label>
          <div class="px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-500">
            v1.0.0
          </div>
        </div>
      </div>
    </div>

    <!-- 保存按钮 -->
    <div class="flex justify-end">
      <button @click="saveSettings" :disabled="saving"
        class="px-6 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
        {{ saving ? '保存中...' : '💾 保存设置' }}
      </button>
    </div>

    <!-- 操作日志 -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-700">📜 操作日志</h2>
        <span class="text-xs text-gray-500">最近 {{ auditLogs.length }} 条</span>
      </div>
      <div v-if="loadingLogs" class="text-sm text-gray-500 py-4 text-center">加载中...</div>
      <div v-else-if="auditLogs.length === 0" class="text-sm text-gray-500 py-4 text-center">暂无操作日志</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-500 border-b border-gray-100">
              <th class="pb-2 font-medium">操作人</th>
              <th class="pb-2 font-medium">时间</th>
              <th class="pb-2 font-medium">操作</th>
              <th class="pb-2 font-medium">详情</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="log in auditLogs" :key="log.id" class="border-b border-gray-50 hover:bg-gray-50">
              <td class="py-2.5 text-gray-700">{{ log.user_name || '-' }}</td>
              <td class="py-2.5 text-gray-500">{{ formatTime(log.created_at) }}</td>
              <td class="py-2.5">
                <span class="inline-block px-2 py-0.5 rounded text-xs font-medium"
                  :class="getActionClass(log.action)">
                  {{ log.action }}
                </span>
              </td>
              <td class="py-2.5 text-gray-500 max-w-xs truncate">{{ formatDetails(log) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

    <!-- 修改密码 -->
    <div class="mt-8 bg-white rounded-xl border border-gray-100 p-6">
      <h3 class="text-base font-bold text-gray-800 mb-4"><Icon name="lock" class="inline w-4 h-4 -mt-0.5 mr-1" /> 修改密码</h3>
      <div class="space-y-3 max-w-sm">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">当前密码</label>
          <input v-model="pwdForm.old_password" type="password" placeholder="输入当前密码"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">新密码</label>
          <input v-model="pwdForm.new_password" type="password" placeholder="输入新密码（至少6位）"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">确认新密码</label>
          <input v-model="pwdForm.confirm_password" type="password" placeholder="再输一次新密码"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>
        <button @click="changePassword" :disabled="pwdChanging"
          class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 disabled:opacity-40 cursor-pointer">
          {{ pwdChanging ? '修改中...' : '确认修改' }}
        </button>
      </div>
    </div>
  </div>

    <!-- Toast -->
    <div v-if="toast" class="fixed bottom-6 right-6 px-4 py-3 rounded-lg shadow-lg text-sm font-medium z-50 transition"
      :class="toast.type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'">
      {{ toast.message }}
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import Icon from '../components/icons/Icons.vue'

const auth = useAuthStore()
const saving = ref(false)
const loadingLogs = ref(false)
const toast = ref(null)
const auditLogs = ref([])
const pwdForm = reactive({ old_password: '', new_password: '', confirm_password: '' })
const pwdChanging = ref(false)

function showToast(msg, type = 'success') {
  toast.value = { message: msg, type }
  setTimeout(() => toast.value = null, 3000)
}

async function changePassword() {
  if (!pwdForm.old_password || !pwdForm.new_password) return showToast('请填写所有字段', 'error')
  if (pwdForm.new_password.length < 6) return showToast('新密码至少6位', 'error')
  if (pwdForm.new_password !== pwdForm.confirm_password) return showToast('两次新密码不一致', 'error')
  pwdChanging.value = true
  try {
    // 先验证旧密码
    const { data: { user } } = await supabase.auth.getUser()
    if (!user?.email) throw new Error('无法获取当前用户信息')
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: user.email,
      password: pwdForm.old_password,
    })
    if (signInError) {
      showToast('当前密码错误', 'error')
      return
    }
    // 旧密码验证通过，更新新密码
    const { error } = await supabase.auth.updateUser({ password: pwdForm.new_password })
    if (error) throw error
    showToast('密码修改成功')
    Object.assign(pwdForm, { old_password: '', new_password: '', confirm_password: '' })
  } catch (e) {
    if (e.message?.includes('Invalid login') || e.message?.includes('credentials')) {
      showToast('当前密码错误', 'error')
    } else {
      showToast('修改失败：' + (e.message || ''), 'error')
    }
  } finally {
    pwdChanging.value = false
  }
}

const settings = reactive({
  approval_limit: 2000,
  transfer_fee_max_rate: 0.01,
  live_commission_rate: 0.05,
  sales_default_commission: 0.05,
  cs_default_commission: 0.02,
  default_currency: 'CNY',
})

// showToast 已在上方定义

function getSettingCategory(key) {
  const map = {
    approval_limit: 'finance',
    transfer_fee_max_rate: 'finance',
    live_commission_rate: 'commission',
    sales_default_commission: 'commission',
    cs_default_commission: 'commission',
    default_currency: 'system',
  }
  return map[key] || 'system'
}

async function loadSettings() {
  const { data, error } = await supabase
    .from('system_settings')
    .select('key, value')
  if (error) return
  data.forEach(row => {
    if (row.key in settings) {
      const val = row.value
      if (row.key === 'default_currency') {
        settings[row.key] = typeof val === 'string' ? val : String(val)
      } else {
        settings[row.key] = Number(val)
      }
    }
  })
}

async function saveSettings() {
  saving.value = true
  try {
    const rows = Object.entries(settings).map(([key, value]) => ({
      key,
      value: key === 'default_currency' ? String(value) : Number(value),
      category: getSettingCategory(key),
    }))
    const { error } = await supabase
      .from('system_settings')
      .upsert(rows, { onConflict: 'key' })
    if (error) throw error

    // Write audit log
    await supabase.from('audit_logs').insert({
      user_id: auth.profile?.id,
      user_name: auth.profile?.name,
      action: 'update_settings',
      entity: 'system_settings',
      details: Object.fromEntries(Object.entries(settings)),
    })

    showToast('设置已保存')
  } catch (e) {
    showToast('保存失败：' + e.message, 'error')
  } finally {
    saving.value = false
  }
}

async function loadAuditLogs() {
  loadingLogs.value = true
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50)
  if (!error && data) auditLogs.value = data
  loadingLogs.value = false
}

function formatTime(t) {
  if (!t) return '-'
  const d = new Date(t)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function formatDetails(log) {
  if (!log.details) return log.entity || '-'
  if (typeof log.details === 'object') {
    return `${log.entity || ''} ${JSON.stringify(log.details).slice(0, 60)}`
  }
  return String(log.details).slice(0, 80)
}

function getActionClass(action) {
  const map = {
    create: 'bg-green-100 text-green-700',
    insert: 'bg-green-100 text-green-700',
    update: 'bg-blue-100 text-blue-700',
    update_settings: 'bg-purple-100 text-purple-700',
    delete: 'bg-red-100 text-red-700',
    approve: 'bg-yellow-100 text-yellow-700',
    reject: 'bg-orange-100 text-orange-700',
    login: 'bg-gray-100 text-gray-700',
  }
  return map[action] || 'bg-gray-100 text-gray-600'
}

onMounted(() => {
  loadSettings()
  loadAuditLogs()
})
</script>
