<template>
  <div v-if="loading" class="min-h-screen flex items-center justify-center bg-gray-50">
    <div class="text-center">
      <div class="text-4xl mb-3 animate-bounce">🎱</div>
      <div class="text-gray-500 text-sm">加载中...</div>
    </div>
  </div>
  <router-view v-else />
  <GlobalToast />
</template>

<script setup>
import { ref, onErrorCaptured } from 'vue'
import { useAuthStore } from './stores/auth'
import { useToast } from './composables/useToast'
import GlobalToast from './components/GlobalToast.vue'

const auth = useAuthStore()
const loading = ref(true)
const { toast } = useToast()

// 全局错误捕获 — 把报错信息转成中文友好提示
onErrorCaptured((err, instance, info) => {
  const msg = err.message || '未知错误'
  let userMsg = '操作失败'

  if (msg.includes("Cannot read properties of undefined")) {
    const prop = msg.match(/reading '(\w+)'/)
    if (prop) {
      userMsg = `数据加载异常：找不到 ${prop} 数据，请刷新页面重试`
    } else {
      userMsg = '数据加载异常：请刷新页面重试'
    }
  } else if (msg.includes("Cannot read properties of null")) {
    const prop = msg.match(/reading '(\w+)'/)
    if (prop) {
      userMsg = `数据为空：缺少 ${prop}，请联系管理员`
    } else {
      userMsg = '数据为空，请刷新页面重试'
    }
  } else if (msg.includes("Failed to fetch") || msg.includes("NetworkError")) {
    userMsg = '网络连接失败，请检查网络后重试'
  } else if (msg.includes("timeout")) {
    userMsg = '请求超时，请稍后重试'
  } else if (msg.includes("401") || msg.includes("Unauthorized")) {
    userMsg = '登录已过期，请重新登录'
  } else if (msg.includes("403") || msg.includes("Forbidden")) {
    userMsg = '没有操作权限'
  } else if (msg.includes("422") || msg.includes("Unprocessable")) {
    userMsg = '提交的数据格式不正确，请检查后重试'
  } else if (msg.includes("500")) {
    userMsg = '服务器内部错误，请稍后重试'
  } else if (msg.includes("TypeError") || msg.includes("ReferenceError")) {
    userMsg = `程序异常：${msg.substring(0, 50)}`
  } else {
    userMsg = `操作失败：${msg.substring(0, 80)}`
  }

  toast(userMsg, 'error', 5000)
})

// Auth init happens in main.js before mount
setTimeout(() => { loading.value = false }, 2000)
</script>
