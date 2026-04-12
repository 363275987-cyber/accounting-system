import { ref } from 'vue'

const toasts = ref([])
let _id = 0

export function useToast() {
  function toast(message, type = 'info', duration = 3500) {
    const id = ++_id
    toasts.value.push({ id, message, type, visible: false })
    // trigger enter animation on next tick
    requestAnimationFrame(() => {
      const t = toasts.value.find(t => t.id === id)
      if (t) t.visible = true
    })
    setTimeout(() => remove(id), duration)
    return id
  }

  function remove(id) {
    const t = toasts.value.find(t => t.id === id)
    if (t) {
      t.visible = false
      setTimeout(() => {
        toasts.value = toasts.value.filter(t => t.id !== id)
      }, 300) // wait for exit animation
    }
  }

  return { toasts, toast, remove }
}
