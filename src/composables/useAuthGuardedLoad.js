import { onMounted, watch } from 'vue'
import { useAuthStore } from '../stores/auth'

/**
 * 在登录态确认后再触发加载逻辑。
 *
 * 背景:
 *   很多 View 的 onMounted 里直接调 store.fetchXxx()，但此时 auth.init()
 *   可能还没跑完，导致第一次请求在未登录状态下发出，触发 RLS 错误或 404，
 *   并污染 supabase-js 的请求队列（见 BUG-9）。
 *
 * 这个 composable 保证 loader 只会在 auth.isLoggedIn === true 之后被调用
 * 一次。如果挂载时已经登录，会立即调用；否则 watch 登录状态变化，一旦
 * 登录成功就触发 loader 并取消 watch。
 *
 * 使用示例:
 *   ```js
 *   // views/SomeView.vue
 *   import { useAuthGuardedLoad } from '@/composables/useAuthGuardedLoad'
 *   import { useProductStore } from '@/stores/products'
 *
 *   const productStore = useProductStore()
 *
 *   useAuthGuardedLoad(async () => {
 *     await productStore.fetchProducts()
 *   })
 *   ```
 *
 * 注意:
 *   - loader 只会被调用一次，重复进入页面如果组件被卸载重建会重新触发，
 *     这是符合 onMounted 语义的。
 *   - 如果 loader 自身抛错，这里不捕获，调用方自己在 loader 里处理。
 *
 * @param {() => any | Promise<any>} loader - 登录后要执行的加载函数
 */
export function useAuthGuardedLoad(loader) {
  const auth = useAuthStore()
  onMounted(() => {
    if (auth.isLoggedIn) {
      loader()
      return
    }
    const unwatch = watch(
      () => auth.isLoggedIn,
      (val) => {
        if (val) {
          loader()
          unwatch()
        }
      }
    )
  })
}
