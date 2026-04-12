import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import { useAuthStore } from './stores/auth'
import './style.css'
import App from './App.vue'

const app = createApp(App)
const pinia = createPinia()
app.use(pinia)
app.use(router)

// Init auth before mounting
const auth = useAuthStore()
await auth.init()

// --------------- 全局错误处理 ---------------

/** 判断是否为 Supabase 认证会话丢失错误 */
function isAuthSessionMissing(err) {
  if (!err) return false
  const msg = err.message || String(err)
  return msg.includes('AuthSessionMissingError') || msg.includes('Auth session missing')
}

/** 判断是否为网络错误 */
function isNetworkError(err) {
  if (!err) return false
  const msg = err.message || String(err)
  return msg.includes('Failed to fetch') ||
    msg.includes('Network Error') ||
    msg.includes('ERR_NETWORK') ||
    msg.includes('net::') ||
    msg.includes('ECONNREFUSED')
}

/** 统一处理错误 */
function handleGlobalError(err, source = 'unknown') {
  console.error(`[GlobalErrorHandler][${source}]`, err)

  if (isAuthSessionMissing(err)) {
    console.warn('[GlobalErrorHandler] 登录会话已过期，正在跳转登录页…')
    router.replace('/login')
    return
  }

  if (isNetworkError(err)) {
    console.warn('[GlobalErrorHandler] 网络连接异常，请检查网络后重试')
    return
  }

  // 其余错误仅打印警告，不打扰用户
  console.warn('[GlobalErrorHandler] 发生未知错误，请查看控制台了解详情')
}

// 1. Vue 组件内未捕获错误
app.config.errorHandler = (err, instance, info) => {
  handleGlobalError(err, `vue-component (${info})`)
}

// 2. 未处理的 Promise rejection
window.addEventListener('unhandledrejection', (event) => {
  event.preventDefault()
  handleGlobalError(event.reason, 'unhandledrejection')
})

// 3. 全局 JS 运行时错误
window.addEventListener('error', (event) => {
  handleGlobalError(event.error || event.message, 'window-error')
})

// --------------- /全局错误处理 ---------------

app.mount('#app')
