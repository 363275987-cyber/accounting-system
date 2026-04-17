<script setup>
// 单文件多图标集合。用法: <Icon name="banknote" class="w-5 h-5" />
// 所有路径都是 stroke 风格(Lucide-ish),便于 currentColor 控制。
defineProps({ name: { type: String, required: true } })
</script>

<template>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"
    aria-hidden="true">
    <template v-if="name === 'banknote'">
      <rect width="20" height="12" x="2" y="6" rx="2" />
      <circle cx="12" cy="12" r="2" />
      <path d="M6 12h.01M18 12h.01" />
    </template>
    <template v-else-if="name === 'trending-up'">
      <polyline points="22 7 13.5 15.5 8.5 10.5 2 17" />
      <polyline points="16 7 22 7 22 13" />
    </template>
    <template v-else-if="name === 'trending-down'">
      <polyline points="22 17 13.5 8.5 8.5 13.5 2 7" />
      <polyline points="16 17 22 17 22 11" />
    </template>
    <template v-else-if="name === 'arrow-up'">
      <line x1="12" y1="19" x2="12" y2="5" />
      <polyline points="5 12 12 5 19 12" />
    </template>
    <template v-else-if="name === 'arrow-down'">
      <line x1="12" y1="5" x2="12" y2="19" />
      <polyline points="19 12 12 19 5 12" />
    </template>
    <template v-else-if="name === 'arrow-right'">
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </template>
    <template v-else-if="name === 'wallet'">
      <path d="M21 12V7a2 2 0 0 0-2-2H5a2 2 0 0 1-2-2v18a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-5" />
      <circle cx="18" cy="12" r="2" />
    </template>
    <template v-else-if="name === 'user'">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 21a8 8 0 0 1 16 0" />
    </template>
    <template v-else-if="name === 'building'">
      <rect x="4" y="3" width="16" height="18" rx="2" />
      <path d="M9 7h.01M15 7h.01M9 11h.01M15 11h.01M9 15h.01M15 15h.01" />
      <path d="M10 21v-4h4v4" />
    </template>
    <template v-else-if="name === 'shopping-bag'">
      <path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z" />
      <line x1="3" y1="6" x2="21" y2="6" />
      <path d="M16 10a4 4 0 0 1-8 0" />
    </template>
    <template v-else-if="name === 'trophy'">
      <path d="M8 21h8" />
      <path d="M12 17v4" />
      <path d="M17 4h3a1 1 0 0 1 1 1v3a4 4 0 0 1-4 4" />
      <path d="M7 4H4a1 1 0 0 0-1 1v3a4 4 0 0 0 4 4" />
      <path d="M7 4h10v6a5 5 0 0 1-10 0V4Z" />
    </template>
    <template v-else-if="name === 'alert-triangle'">
      <path d="m10.29 3.86-8.79 15.24A2 2 0 0 0 3.21 22h17.58a2 2 0 0 0 1.71-2.9L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </template>
    <template v-else-if="name === 'shield-check'">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <polyline points="9 12 11 14 15 10" />
    </template>
    <template v-else-if="name === 'refresh'">
      <polyline points="23 4 23 10 17 10" />
      <polyline points="1 20 1 14 7 14" />
      <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10" />
      <path d="M20.49 15a9 9 0 0 1-14.85 3.36L1 14" />
    </template>
    <template v-else-if="name === 'line-chart'">
      <path d="M3 3v18h18" />
      <path d="m7 16 4-4 4 3 5-7" />
    </template>
    <template v-else-if="name === 'sparkle'">
      <path d="m12 3 2.5 5.5L20 11l-5.5 2.5L12 19l-2.5-5.5L4 11l5.5-2.5Z" />
      <path d="M19 3v4M21 5h-4" />
    </template>
    <template v-else-if="name === 'chevron-down'">
      <polyline points="6 9 12 15 18 9" />
    </template>
    <template v-else-if="name === 'plus'">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </template>
    <template v-else-if="name === 'minus'">
      <line x1="5" y1="12" x2="19" y2="12" />
    </template>
  </svg>
</template>
