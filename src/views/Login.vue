<template>
  <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
    <div class="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
      <div class="text-center mb-8">
        <div class="text-4xl mb-2">🎱</div>
        <h1 class="text-2xl font-bold text-gray-800">台球公司账目系统</h1>
        <p class="text-gray-500 text-sm mt-1">财务管理平台</p>
      </div>

      <!-- 成功提示 -->
      <div v-if="success" class="bg-green-50 text-green-600 px-4 py-3 rounded-lg text-sm mb-4">
        {{ success }}
      </div>
      <!-- 错误提示 -->
      <div v-if="error" class="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm mb-4">
        {{ error }}
      </div>

      <!-- ==================== 模式1: 登录 ==================== -->
      <template v-if="mode === 'login'">
        <!-- 快捷登录入口 -->
        <div v-if="savedAccounts.length > 0" class="mb-5">
          <div class="text-xs text-gray-500 mb-2">快速登录</div>
          <div class="space-y-2">
            <button
              v-for="acc in savedAccounts"
              :key="acc.email"
              type="button"
              @click="quickLogin(acc)"
              :disabled="quickLoading === acc.email"
              class="w-full flex items-center gap-3 px-4 py-2.5 rounded-xl border border-gray-100 hover:bg-blue-50 hover:border-blue-200 transition cursor-pointer text-left disabled:opacity-50"
            >
              <div class="w-9 h-9 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center text-sm font-bold flex-shrink-0">
                {{ (acc.email || '?')[0].toUpperCase() }}
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-gray-800 truncate">{{ acc.email }}</div>
                <div class="text-xs text-gray-500">{{ acc.role || '账号' }}</div>
              </div>
              <span v-if="quickLoading === acc.email" class="text-blue-400 text-xs">登录中...</span>
              <span v-else class="text-blue-400 text-xs">→</span>
            </button>
          </div>
          <div class="relative flex items-center my-4">
            <div class="flex-1 border-t border-gray-200"></div>
            <span class="px-3 text-xs text-gray-500">或手动登录</span>
            <div class="flex-1 border-t border-gray-200"></div>
          </div>
        </div>

        <form @submit.prevent="handleLogin" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">账号</label>
            <input v-model="email" type="email" placeholder="请输入邮箱"
              class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">密码</label>
            <input v-model="password" type="password" placeholder="请输入密码"
              class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none">
          </div>
          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
              <input type="checkbox" v-model="rememberMe" class="rounded border-gray-300" />
              记住账号密码
            </label>
            <button type="button" @click="switchMode('forgot')" class="text-sm text-blue-500 hover:text-blue-700 cursor-pointer">
              忘记密码？
            </button>
          </div>
          <button type="submit" :disabled="loading"
            class="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition disabled:opacity-50 cursor-pointer">
            {{ loading ? '登录中...' : '登录' }}
          </button>
        </form>
      </template>

      <!-- ==================== 模式2: 忘记密码（发送重置邮件） ==================== -->
      <template v-else-if="mode === 'forgot'">
        <div class="text-center mb-6">
          <div class="text-3xl mb-2">🔑</div>
          <h2 class="text-lg font-bold text-gray-800">忘记密码</h2>
          <p class="text-gray-500 text-sm mt-1">输入注册邮箱，我们将发送重置链接</p>
        </div>

        <form @submit.prevent="handleForgot" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">邮箱地址</label>
            <input v-model="resetEmail" type="email" placeholder="请输入注册邮箱" autofocus
              class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none">
          </div>
          <button type="submit" :disabled="loading"
            class="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition disabled:opacity-50 cursor-pointer">
            {{ loading ? '发送中...' : '发送重置链接' }}
          </button>
        </form>

        <div class="mt-4 text-center">
          <button type="button" @click="switchMode('login')" class="text-sm text-gray-500 hover:text-blue-600 cursor-pointer">
            ← 返回登录
          </button>
        </div>
      </template>

      <!-- ==================== 模式3: 重置密码（设置新密码） ==================== -->
      <template v-else-if="mode === 'reset'">
        <div class="text-center mb-6">
          <div class="text-3xl mb-2">🔒</div>
          <h2 class="text-lg font-bold text-gray-800">设置新密码</h2>
          <p class="text-gray-500 text-sm mt-1">请输入您的新密码</p>
        </div>

        <form @submit.prevent="handleReset" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">新密码</label>
            <input v-model="newPassword" type="password" placeholder="请输入新密码（至少6位）" autofocus
              class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">确认密码</label>
            <input v-model="confirmPassword" type="password" placeholder="请再次输入新密码"
              class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none">
          </div>
          <!-- 密码强度提示 -->
          <div v-if="newPassword" class="space-y-1">
            <div class="flex gap-1">
              <div class="h-1 flex-1 rounded" :class="passwordStrength >= 1 ? 'bg-red-400' : 'bg-gray-200'"></div>
              <div class="h-1 flex-1 rounded" :class="passwordStrength >= 2 ? 'bg-yellow-400' : 'bg-gray-200'"></div>
              <div class="h-1 flex-1 rounded" :class="passwordStrength >= 3 ? 'bg-green-400' : 'bg-gray-200'"></div>
            </div>
            <p class="text-xs" :class="passwordStrength >= 3 ? 'text-green-600' : passwordStrength >= 2 ? 'text-yellow-600' : 'text-red-500'">
              {{ passwordStrength >= 3 ? '密码强度：强' : passwordStrength >= 2 ? '密码强度：中' : '密码强度：弱（建议包含大小写字母和数字）' }}
            </p>
          </div>
          <button type="submit" :disabled="loading"
            class="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition disabled:opacity-50 cursor-pointer">
            {{ loading ? '重置中...' : '确认重置密码' }}
          </button>
        </form>

        <div class="mt-4 text-center">
          <button type="button" @click="switchMode('login')" class="text-sm text-gray-500 hover:text-blue-600 cursor-pointer">
            ← 返回登录
          </button>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { supabase } from '../lib/supabase'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

// 共享状态
const mode = ref('login') // 'login' | 'forgot' | 'reset'
const loading = ref(false)
const error = ref('')
const success = ref('')

// 登录表单
const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const quickLoading = ref('')
const savedAccounts = ref([])

// 忘记密码表单
const resetEmail = ref('')

// 重置密码表单
const newPassword = ref('')
const confirmPassword = ref('')

// 密码强度计算
const passwordStrength = computed(() => {
  const p = newPassword.value
  if (!p) return 0
  let score = 0
  if (p.length >= 6) score++
  if (/[a-z]/.test(p) && /[A-Z]/.test(p)) score++
  if (/\d/.test(p) && /[^a-zA-Z0-9]/.test(p)) score++
  return score
})

// 保存的账号 key
const STORAGE_KEY = 'accounting_remembered_accounts'
const REMEMBER_KEY = 'accounting_remember_me'

function switchMode(newMode) {
  mode.value = newMode
  error.value = ''
  success.value = ''
}

onMounted(() => {
  // 读取记住的账号列表
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    savedAccounts.value = saved ? JSON.parse(saved) : []
    const lastEmail = localStorage.getItem(REMEMBER_KEY)
    if (lastEmail) {
      const acc = savedAccounts.value.find(a => a.email === lastEmail)
      if (acc) {
        email.value = acc.email
        rememberMe.value = true
      }
    }
  } catch (e) {}

  // 监听 Supabase PASSWORD_RECOVERY 事件
  // 当用户点击重置链接回到页面时，Supabase 会自动处理 token 并触发此事件
  supabase.auth.onAuthStateChange((event) => {
    if (event === 'PASSWORD_RECOVERY') {
      mode.value = 'reset'
      success.value = '身份验证成功，请设置新密码'
    }
  })

  // 兼容 hash 路由：如果 URL 带 ?reset=1 或 hash 里有 access_token/type=recovery
  // Supabase 在 hash 路由下会把 token 放在 URL fragment 里
  const hash = window.location.hash
  if (hash.includes('type=recovery') || hash.includes('reset=1')) {
    // Supabase JS SDK 会自动从 URL 中提取 token 并触发 PASSWORD_RECOVERY 事件
    // 这里做个延迟兜底，如果 3 秒后还没触发，手动切到 reset 模式
    setTimeout(() => {
      if (mode.value !== 'reset') {
        mode.value = 'reset'
        success.value = '请设置新密码'
      }
    }, 2000)
  }
})

// ---- 登录逻辑 ----
async function quickLogin(acc) {
  email.value = acc.email
  rememberMe.value = true
}

function saveAccount(emailVal, passwordVal, role) {
  try {
    let accounts = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
    accounts = accounts.filter(a => a.email !== emailVal)
    accounts.unshift({ email: emailVal, role: role || '', savedAt: Date.now() })
    accounts = accounts.slice(0, 5)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(accounts))
    savedAccounts.value = accounts
  } catch (e) {}
}

function removeSavedAccount(emailVal) {
  try {
    let accounts = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
    accounts = accounts.filter(a => a.email !== emailVal)
    localStorage.setItem(STORAGE_KEY, JSON.stringify(accounts))
    savedAccounts.value = accounts
  } catch (e) {}
}

async function handleLogin() {
  loading.value = true
  error.value = ''
  success.value = ''
  try {
    await auth.login(email.value, password.value)
    if (rememberMe.value) {
      const role = auth.profile?.role || ''
      saveAccount(email.value, password.value, role)
      localStorage.setItem(REMEMBER_KEY, email.value)
    } else {
      removeSavedAccount(email.value)
    }
    router.push('/')
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('Invalid login') || msg.includes('Invalid credentials')) {
      error.value = '账号或密码错误'
    } else if (msg.includes('Too many requests')) {
      error.value = '请求过于频繁，请稍后再试'
    } else if (msg.includes('Email not confirmed')) {
      error.value = '邮箱未验证，请先查收验证邮件'
    } else {
      error.value = '登录失败，请检查账号密码'
    }
  } finally {
    loading.value = false
  }
}

// ---- 忘记密码逻辑 ----
async function handleForgot() {
  if (!resetEmail.value) {
    error.value = '请输入邮箱地址'
    return
  }
  loading.value = true
  error.value = ''
  success.value = ''
  try {
    await auth.resetPassword(resetEmail.value)
    success.value = '重置链接已发送到 ' + resetEmail.value + '，请查收邮件（注意检查垃圾邮件）'
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('rate limit') || msg.includes('Too many')) {
      error.value = '请求过于频繁，请稍后再试'
    } else {
      error.value = '发送失败：' + (msg || '请稍后重试')
    }
  } finally {
    loading.value = false
  }
}

// ---- 重置密码逻辑 ----
async function handleReset() {
  error.value = ''
  success.value = ''

  if (!newPassword.value) {
    error.value = '请输入新密码'
    return
  }
  if (newPassword.value.length < 6) {
    error.value = '密码至少需要 6 个字符'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    error.value = '两次输入的密码不一致'
    return
  }

  loading.value = true
  try {
    await auth.updatePassword(newPassword.value)
    success.value = '密码重置成功！正在跳转到登录页...'
    // 重置后登出，让用户用新密码登录
    setTimeout(async () => {
      await auth.logout()
      mode.value = 'login'
      success.value = '密码已重置，请用新密码登录'
      newPassword.value = ''
      confirmPassword.value = ''
    }, 1500)
  } catch (e) {
    const msg = e.message || ''
    if (msg.includes('same_password') || msg.includes('should be different')) {
      error.value = '新密码不能与旧密码相同'
    } else {
      error.value = '重置失败：' + (msg || '请重新获取重置链接')
    }
  } finally {
    loading.value = false
  }
}
</script>
