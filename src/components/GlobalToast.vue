<template>
  <Teleport to="body">
    <div class="fixed top-4 right-4 z-[9999] flex flex-col gap-2 pointer-events-none" aria-live="polite">
      <div
        v-for="t in toasts"
        :key="t.id"
        role="alert"
        :aria-label="t.message"
        class="pointer-events-auto max-w-sm px-4 py-3 rounded-xl shadow-lg text-sm font-medium flex items-center gap-2 transition-all duration-300"
        :class="[
          typeClasses[t.type] || typeClasses.info,
          t.visible ? 'opacity-100 translate-x-0' : 'opacity-0 translate-x-8'
        ]"
      >
        <span class="flex-shrink-0">{{ typeIcons[t.type] || typeIcons.info }}</span>
        <span class="flex-1">{{ t.message }}</span>
        <button
          @click="remove(t.id)"
          class="flex-shrink-0 opacity-60 hover:opacity-100 cursor-pointer ml-1"
          aria-label="关闭提示"
        >&times;</button>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { useToast } from '../composables/useToast'

const { toasts, remove } = useToast()

const typeClasses = {
  success: 'bg-green-600 text-white',
  error: 'bg-red-600 text-white',
  warning: 'bg-amber-500 text-white',
  info: 'bg-gray-800 text-white',
}

const typeIcons = {
  success: '✓',
  error: '✕',
  warning: '⚠',
  info: 'ℹ',
}
</script>
