<template>
  <div class="max-w-6xl mx-auto space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-bold text-gray-800">🔌 平台对接</h1>
      <button @click="showLogs = true"
        class="px-4 py-2 text-sm text-gray-600 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer">
        📜 同步日志
      </button>
    </div>
    <p class="text-sm text-gray-500">配置外部电商平台的 API 凭证，同步订单数据到系统。</p>

    <!-- 平台卡片网格 -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div v-for="config in platformConfigs" :key="config.key"
        class="bg-white rounded-xl shadow-sm border border-gray-100 p-5 hover:shadow-md transition group">
        <div class="flex items-start justify-between mb-3">
          <div class="flex items-center gap-3">
            <div class="w-11 h-11 rounded-lg flex items-center justify-center text-xl bg-gradient-to-br text-white"
              :class="config.color">
              {{ config.icon }}
            </div>
            <div>
              <h3 class="font-semibold text-gray-800">{{ config.name }}</h3>
              <p class="text-xs text-gray-500">{{ config.description }}</p>
            </div>
          </div>
          <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium"
            :class="getStatusBadgeClass(getCredStatus(config.key))">
            <span class="w-1.5 h-1.5 rounded-full" :class="getStatusDotClass(getCredStatus(config.key))"></span>
            {{ getStatusLabel(getCredStatus(config.key)) }}
          </span>
        </div>

        <!-- 凭证信息摘要 -->
        <div v-if="getCredential(config.key)" class="mt-3 p-3 bg-gray-50 rounded-lg space-y-1.5 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-500">店铺名称</span>
            <span class="text-gray-700 font-medium">{{ getCredential(config.key).shop_name || '-' }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-500">App ID</span>
            <span class="text-gray-700 font-mono text-xs">{{ maskString(getCredential(config.key).app_id) }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-500">最后同步</span>
            <span class="text-gray-700">{{ formatTime(getCredential(config.key).last_sync_at) }}</span>
          </div>
          <div v-if="getCredential(config.key).last_error" class="flex justify-between">
            <span class="text-red-500">错误</span>
            <span class="text-red-600 text-xs truncate max-w-[200px]">{{ getCredential(config.key).last_error }}</span>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="mt-4 flex items-center gap-2">
          <button @click="openEditModal(config.key)"
            class="flex-1 px-3 py-2 text-sm rounded-lg transition cursor-pointer"
            :class="getCredential(config.key)
              ? 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              : 'bg-blue-600 text-white hover:bg-blue-700'">
            {{ getCredential(config.key) ? '✏️ 编辑凭证' : '➕ 添加凭证' }}
          </button>
          <button v-if="getCredential(config.key)" @click="handleTest(config.key)"
            :disabled="testing === config.key"
            class="px-3 py-2 text-sm bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition cursor-pointer disabled:opacity-50">
            {{ testing === config.key ? '⏳' : '🔌' }} 测试
          </button>
          <button v-if="getCredential(config.key)" @click="handleSync(config.key)"
            :disabled="syncing === config.key"
            class="px-3 py-2 text-sm bg-green-50 text-green-700 rounded-lg hover:bg-green-100 transition cursor-pointer disabled:opacity-50">
            {{ syncing === config.key ? '⏳' : '🔄' }} 同步
          </button>
        </div>

        <!-- API文档链接 -->
        <a :href="config.apiDoc" target="_blank" rel="noopener"
          class="mt-3 inline-block text-xs text-gray-500 hover:text-blue-500 transition">
          📖 {{ config.name }}开放平台文档 →
        </a>
      </div>
    </div>

    <!-- 添加/编辑凭证弹窗 -->
    <teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/30" @click="closeModal"></div>
        <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6 space-y-5 max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-800">
              {{ editingPlatform ? PLATFORM_CONFIG[editingPlatform].name + ' 凭证配置' : '添加平台凭证' }}
            </h2>
            <button @click="closeModal" class="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition cursor-pointer">✕</button>
          </div>

          <div class="space-y-4">
            <!-- 平台选择（新增时） -->
            <div v-if="!editingPlatform">
              <label class="block text-sm font-medium text-gray-600 mb-1">选择平台</label>
              <select v-model="form.platform"
                class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none">
                <option value="">请选择...</option>
                <option v-for="config in platformConfigs" :key="config.key" :value="config.key">
                  {{ config.icon }} {{ config.name }}
                </option>
              </select>
            </div>

            <!-- 平台标识（编辑时） -->
            <div v-else class="flex items-center gap-2 p-3 bg-gray-50 rounded-lg">
              <span class="text-xl">{{ PLATFORM_CONFIG[editingPlatform].icon }}</span>
              <span class="text-sm font-medium text-gray-700">{{ PLATFORM_CONFIG[editingPlatform].name }}</span>
            </div>

            <!-- 店铺名称 -->
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">店铺名称</label>
              <input type="text" v-model="form.shop_name" placeholder="方便识别的店铺名称"
                class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none" />
            </div>

            <!-- App ID -->
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">App ID / Client ID</label>
              <input type="text" v-model="form.app_id" placeholder="平台分配的 App ID"
                class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none" />
            </div>

            <!-- App Secret -->
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">App Secret / Client Secret</label>
              <div class="relative">
                <input :type="showSecret ? 'text' : 'password'" v-model="form.app_secret" placeholder="平台分配的 App Secret"
                  class="w-full px-4 py-2.5 pr-10 border border-gray-200 rounded-lg text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none" />
                <button @click="showSecret = !showSecret" type="button"
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-600 cursor-pointer">
                  {{ showSecret ? '🙈' : '👁️' }}
                </button>
              </div>
              <p class="text-xs text-gray-500 mt-1">凭证加密存储，不会明文展示</p>
            </div>

            <!-- Shop ID（可选） -->
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">
                店铺 ID <span class="text-gray-500 font-normal">（部分平台需要）</span>
              </label>
              <input type="text" v-model="form.shop_id" placeholder="如有多个店铺，填写对应店铺ID"
                class="w-full px-4 py-2.5 border border-gray-200 rounded-lg text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none" />
            </div>
          </div>

          <!-- 操作按钮 -->
          <div class="flex items-center gap-3 pt-2">
            <button @click="closeModal"
              class="flex-1 px-4 py-2.5 text-sm text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200 transition cursor-pointer">
              取消
            </button>
            <button @click="saveCredential" :disabled="saving"
              class="flex-1 px-4 py-2.5 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition disabled:opacity-50 cursor-pointer">
              {{ saving ? '保存中...' : '💾 保存' }}
            </button>
          </div>
        </div>
      </div>
    </teleport>

    <!-- 同步日志弹窗 -->
    <teleport to="body">
      <div v-if="showLogs" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/30" @click="showLogs = false"></div>
        <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[80vh] flex flex-col">
          <div class="flex items-center justify-between p-5 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-800">📜 同步日志</h2>
            <button @click="showLogs = false" class="w-8 h-8 flex items-center justify-center text-gray-500 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition cursor-pointer">✕</button>
          </div>
          <div class="flex-1 overflow-y-auto p-5">
            <div v-if="loadingLogs" class="text-sm text-gray-500 text-center py-8">加载中...</div>
            <div v-else-if="syncLogs.length === 0" class="text-sm text-gray-500 text-center py-8">暂无同步日志</div>
            <div v-else class="space-y-3">
              <div v-for="log in syncLogs" :key="log.id"
                class="flex items-start gap-3 p-3 rounded-lg bg-gray-50 text-sm">
                <span class="text-lg flex-shrink-0">{{ getPlatformIcon(log.platform) }}</span>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="font-medium text-gray-700">{{ log.action }}</span>
                    <span class="px-2 py-0.5 rounded text-xs font-medium"
                      :class="log.status === 'success' ? 'bg-green-100 text-green-700' : log.status === 'partial' ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-700'">
                      {{ log.status === 'success' ? '成功' : log.status === 'partial' ? '部分成功' : '失败' }}
                    </span>
                    <span class="text-xs text-gray-500 ml-auto flex-shrink-0">{{ formatTime(log.created_at) }}</span>
                  </div>
                  <div class="text-gray-500">
                    影响 {{ log.records_affected || 0 }} 条记录
                    <span v-if="log.duration_ms"> · 耗时 {{ log.duration_ms }}ms</span>
                  </div>
                  <div v-if="log.error_message" class="text-red-500 text-xs mt-1 break-all">
                    {{ log.error_message }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </teleport>

    <!-- Toast -->
    <div v-if="toast" class="fixed bottom-6 right-6 px-4 py-3 rounded-lg shadow-lg text-sm font-medium z-50 transition"
      :class="toast.type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'">
      {{ toast.message }}
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { PLATFORM_CONFIG, PLATFORM_KEYS, createPlatform } from '../lib/platforms/index.js'

// 平台配置列表
const platformConfigs = computed(() => PLATFORM_KEYS.map(key => PLATFORM_CONFIG[key]))

// 状态
const credentials = ref([])
const syncLogs = ref([])
const loadingLogs = ref(false)
const showModal = ref(false)
const showLogs = ref(false)
const showSecret = ref(false)
const saving = ref(false)
const testing = ref(null)
const syncing = ref(null)
const toast = ref(null)
const editingPlatform = ref(null) // null=新增, 'douyin'=编辑抖店

// 表单
const form = reactive({
  platform: '',
  shop_name: '',
  app_id: '',
  app_secret: '',
  shop_id: '',
})

function showToast(message, type = 'success') {
  toast.value = { message, type }
  setTimeout(() => { toast.value = null }, 3000)
}

// 辅助函数
function getCredential(platform) {
  return credentials.value.find(c => c.platform === platform)
}

function getCredStatus(platform) {
  const cred = getCredential(platform)
  if (!cred) return 'none'
  if (cred.status === 'error') return 'error'
  if (cred.last_sync_at && new Date(cred.token_expires_at) < new Date()) return 'expired'
  if (cred.app_id && cred.app_secret) return 'connected'
  return 'configured'
}

function getStatusLabel(status) {
  const map = { none: '未配置', configured: '已配置', connected: '已连接', error: '连接异常', expired: '已过期' }
  return map[status] || status
}

function getStatusBadgeClass(status) {
  const map = {
    none: 'bg-gray-100 text-gray-500',
    configured: 'bg-yellow-50 text-yellow-600',
    connected: 'bg-green-50 text-green-600',
    error: 'bg-red-50 text-red-600',
    expired: 'bg-orange-50 text-orange-600',
  }
  return map[status] || 'bg-gray-100 text-gray-500'
}

function getStatusDotClass(status) {
  const map = {
    none: 'bg-gray-300',
    configured: 'bg-yellow-400',
    connected: 'bg-green-400',
    error: 'bg-red-400',
    expired: 'bg-orange-400',
  }
  return map[status] || 'bg-gray-300'
}

function getPlatformIcon(platform) {
  return PLATFORM_CONFIG[platform]?.icon || '📦'
}

function maskString(str) {
  if (!str) return '-'
  if (str.length <= 8) return '****' + str.slice(-4)
  return str.slice(0, 4) + '****' + str.slice(-4)
}

function formatTime(t) {
  if (!t) return '从未'
  const d = new Date(t)
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// 加载凭证列表
async function loadCredentials() {
  const { data, error } = await supabase
    .from('platform_credentials')
    .select('*')
    .order('created_at', { ascending: true })
  if (!error && data) {
    credentials.value = data
  }
}

// 加载同步日志
async function loadSyncLogs() {
  loadingLogs.value = true
  const { data, error } = await supabase
    .from('platform_sync_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50)
  if (!error && data) {
    syncLogs.value = data
  }
  loadingLogs.value = false
}

// 打开编辑弹窗
function openEditModal(platform) {
  editingPlatform.value = platform
  const cred = getCredential(platform)
  if (cred) {
    form.platform = cred.platform
    form.shop_name = cred.shop_name || ''
    form.app_id = cred.app_id || ''
    form.app_secret = '' // 不回显密码
    form.shop_id = cred.shop_id || ''
  } else {
    form.platform = platform
    form.shop_name = ''
    form.app_id = ''
    form.app_secret = ''
    form.shop_id = ''
  }
  showSecret.value = false
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  editingPlatform.value = null
  form.platform = ''
  form.shop_name = ''
  form.app_id = ''
  form.app_secret = ''
  form.shop_id = ''
}

// 保存凭证
async function saveCredential() {
  const platform = editingPlatform.value || form.platform
  if (!platform) {
    showToast('请选择平台', 'error')
    return
  }
  if (!form.app_id) {
    showToast('请填写 App ID', 'error')
    return
  }

  saving.value = true
  try {
    const payload = {
      platform,
      shop_name: form.shop_name || null,
      app_id: form.app_id,
      shop_id: form.shop_id || null,
      status: 'active',
    }

    // 只有填了新 secret 才更新（不覆盖已有值）
    if (form.app_secret) {
      payload.app_secret = form.app_secret
    }

    const existing = getCredential(platform)
    let error

    if (existing) {
      // 更新
      const result = await supabase
        .from('platform_credentials')
        .update({ ...payload, updated_at: new Date().toISOString() })
        .eq('id', existing.id)
      error = result.error
    } else {
      // 新增
      payload.shop_id = payload.shop_id || ''
      const result = await supabase
        .from('platform_credentials')
        .insert(payload)
      error = result.error
    }

    if (error) throw error

    showToast('凭证已保存')
    closeModal()
    await loadCredentials()
  } catch (e) {
    showToast('保存失败: ' + e.message, 'error')
  } finally {
    saving.value = false
  }
}

// 测试连接
async function handleTest(platform) {
  const cred = getCredential(platform)
  if (!cred) return

  testing.value = platform
  try {
    const instance = createPlatform(cred)
    const result = await instance.testConnection()
    if (result.success) {
      showToast(`${PLATFORM_CONFIG[platform].name}: ${result.message}`)
    } else {
      showToast(`${PLATFORM_CONFIG[platform].name}: ${result.message}`, 'error')
    }
  } catch (e) {
    showToast('测试失败: ' + e.message, 'error')
  } finally {
    testing.value = null
  }
}

// 手动同步
async function handleSync(platform) {
  const cred = getCredential(platform)
  if (!cred) return

  syncing.value = platform
  try {
    const instance = createPlatform(cred)
    // 同步最近7天的订单
    const endTime = new Date().toISOString()
    const startTime = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString()
    const result = await instance.syncOrders(supabase, { startTime, endTime })
    if (result.synced > 0) {
      showToast(`${PLATFORM_CONFIG[platform].name}: ${result.message}`)
      await loadCredentials()
    } else {
      showToast(`${PLATFORM_CONFIG[platform].name}: ${result.message}`, 'info')
    }
  } catch (e) {
    showToast('同步失败: ' + e.message, 'error')
  } finally {
    syncing.value = null
  }
}

// 监听日志弹窗打开
import { watch } from 'vue'
watch(showLogs, (val) => {
  if (val) loadSyncLogs()
})

onMounted(() => {
  loadCredentials()
})
</script>
