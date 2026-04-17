import { ref, watch } from 'vue'

// 数字滚动上升动画 composable
// 用法:
//   const displayValue = useCountUp(() => rawValue.value, { duration: 800 })
// 返回一个 ref,值会在 rawValue 变化时从旧值平滑过渡到新值(ease-out)
export function useCountUp(source, { duration = 700 } = {}) {
  const out = ref(typeof source === 'function' ? source() : source.value)
  let rafId = null
  let from = out.value
  let to = out.value
  let start = 0

  function step(now) {
    if (!start) start = now
    const t = Math.min(1, (now - start) / duration)
    // ease-out cubic
    const eased = 1 - Math.pow(1 - t, 3)
    out.value = from + (to - from) * eased
    if (t < 1) {
      rafId = requestAnimationFrame(step)
    } else {
      out.value = to
      rafId = null
    }
  }

  watch(source, (next) => {
    const n = Number(next || 0)
    if (rafId) cancelAnimationFrame(rafId)
    from = Number(out.value || 0)
    to = n
    if (from === to) return
    start = 0
    rafId = requestAnimationFrame(step)
  }, { immediate: false })

  return out
}
