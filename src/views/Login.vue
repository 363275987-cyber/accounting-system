<template>
  <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100">
    <div class="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
      <div class="text-center mb-8">
        <div class="text-4xl mb-2">🎱</div>
        <h1 class="text-2xl font-bold text-gray-800">台球公司账目系统</h1>
        <p class="text-gray-500 text-sm mt-1">财务管理平台</p>
      </div>

      <div v-if="error" class="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm mb-4">
        {{ error }}
      </div>

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
        <label class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
          <input type="checkbox" v-model="rememberMe" class="rounded border-gray-300" />
          记住账号密码
        </label>
        <button type="submit" :disabled="loading"
          class="w-full bg-blue-600 text-white py-3 rounded-xl font-medium hover:bg-blue-700 transition disabled:opacity-50 cursor-pointer">
          {{ loading ? '登录中...' : '登录' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const rememberMe = ref(false)
const quickLoading = ref('')
const savedAccounts = ref([])

// 保存的账号 key
const STORAGE_KEY = 'accounting_remembered_accounts'
const REMEMBER_KEY = 'accounting_remember_me'

onMounted(() => {
  // 读取记住的账号列表
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    savedAccounts.value = saved ? JSON.parse(saved) : []
    // 恢复上次的账号密码
    const lastEmail = localStorage.getItem(REMEMBER_KEY)
    if (lastEmail) {
      const acc = savedAccounts.value.find(a => a.email === lastEmail)
      if (acc) {
        email.value = acc.email
        rememberMe.value = true
      }
    }
  } catch (e) {}
})

async function quickLogin(acc) {
  // 快捷登录只填充邮箱，用户需手动输入密码
  email.value = acc.email
  rememberMe.value = true
}

function saveAccount(emailVal, passwordVal, role) {
  try {
    let accounts = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
    // 去重
    accounts = accounts.filter(a => a.email !== emailVal)
    // 只保存邮箱和角色，不存密码
    accounts.unshift({ email: emailVal, role: role || '', savedAt: Date.now() })
    // 最多保存 5 个
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
  try {
    await auth.login(email.value, password.value)
    if (rememberMe.value) {
      // 获取角色
      const role = auth.profile?.role || ''
      saveAccount(email.value, password.value, role)
      localStorage.setItem(REMEMBER_KEY, email.value)
    } else {
      // 不记住就移除
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
</script>
