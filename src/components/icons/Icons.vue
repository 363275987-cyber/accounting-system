<script setup>
// 线性图标集。用法: <Icon name="wallet" class="w-5 h-5" />
// 统一 24×24 viewBox、round cap/join、1.75 stroke、currentColor。
defineProps({ name: { type: String, required: true } })
</script>

<template>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"
    aria-hidden="true">
    <!-- 通用 -->
    <template v-if="name === 'arrow-up'"><path d="M12 19V5M5 12l7-7 7 7"/></template>
    <template v-else-if="name === 'arrow-down'"><path d="M12 5v14M19 12l-7 7-7-7"/></template>
    <template v-else-if="name === 'arrow-right'"><path d="M5 12h14M12 5l7 7-7 7"/></template>
    <template v-else-if="name === 'chevron-down'"><path d="m6 9 6 6 6-6"/></template>
    <template v-else-if="name === 'plus'"><path d="M12 5v14M5 12h14"/></template>
    <template v-else-if="name === 'minus'"><path d="M5 12h14"/></template>
    <template v-else-if="name === 'refresh'"><path d="M3 12a9 9 0 0 1 15.5-6.3L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-15.5 6.3L3 16"/><path d="M3 21v-5h5"/></template>
    <template v-else-if="name === 'sparkle'"><path d="M12 3v4m0 10v4M3 12h4m10 0h4M6.3 6.3l2.8 2.8m5.8 5.8 2.8 2.8M6.3 17.7l2.8-2.8m5.8-5.8 2.8-2.8"/></template>
    <template v-else-if="name === 'search'"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></template>

    <!-- 财务 / 商业 -->
    <template v-else-if="name === 'wallet'"><path d="M20 7H5a2 2 0 0 1-2-2 2 2 0 0 1 2-2h12v4"/><path d="M3 5v14a2 2 0 0 0 2 2h16v-14H5"/><path d="M18 12a1 1 0 0 0 0 2"/></template>
    <template v-else-if="name === 'coins'"><circle cx="8" cy="8" r="5"/><path d="M14.8 4.6a5 5 0 1 1 0 10.8"/><circle cx="16" cy="16" r="5"/><path d="M10.8 12a5 5 0 1 0 0 10.8"/></template>
    <template v-else-if="name === 'trending-up'"><path d="M3 17 9 11l4 4 8-8"/><path d="M14 7h7v7"/></template>
    <template v-else-if="name === 'trending-down'"><path d="M3 7 9 13l4-4 8 8"/><path d="M14 17h7v-7"/></template>
    <template v-else-if="name === 'banknote'"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2"/><path d="M6 12h.01M18 12h.01"/></template>
    <template v-else-if="name === 'line-chart'"><path d="M3 3v18h18"/><path d="m7 15 4-4 4 3 5-7"/></template>
    <template v-else-if="name === 'receipt'"><path d="M4 2v20l3-2 3 2 3-2 3 2 3-2 1 1V2z"/><path d="M8 7h8M8 11h8M8 15h6"/></template>

    <!-- 账户类别 -->
    <template v-else-if="name === 'user'"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></template>
    <template v-else-if="name === 'users'"><circle cx="9" cy="8" r="4"/><path d="M3 21a6 6 0 0 1 12 0"/><path d="M16 4a4 4 0 0 1 0 8"/><path d="M18 21a6 6 0 0 0-2-4.6"/></template>
    <template v-else-if="name === 'building'"><rect x="4" y="3" width="16" height="18" rx="1.5"/><path d="M9 7h.01M15 7h.01M9 11h.01M15 11h.01M9 15h.01M15 15h.01"/><path d="M10 21v-4h4v4"/></template>
    <template v-else-if="name === 'store'"><path d="M3 9 4.5 4h15L21 9"/><path d="M4 9v12h16V9"/><path d="M3 9a3 3 0 0 0 5 2 3 3 0 0 0 4 0 3 3 0 0 0 4 0 3 3 0 0 0 5-2"/><path d="M9 21v-6h6v6"/></template>
    <template v-else-if="name === 'shopping-bag'"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4Z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></template>

    <!-- 状态 -->
    <template v-else-if="name === 'trophy'"><path d="M8 21h8M10 17h4v4h-4zM7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v3a3 3 0 0 1-3 3M7 5H4v3a3 3 0 0 0 3 3"/></template>
    <template v-else-if="name === 'alert-triangle'"><path d="M10.3 3.9 1.8 18.5A1.5 1.5 0 0 0 3.1 21h17.8a1.5 1.5 0 0 0 1.3-2.5L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></template>
    <template v-else-if="name === 'shield-check'"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/></template>
    <template v-else-if="name === 'bell'"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></template>
    <template v-else-if="name === 'activity'"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></template>

    <!-- 业务类 -->
    <template v-else-if="name === 'edit'"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.1 2.1 0 1 1 3 3L12 15l-4 1 1-4Z"/></template>
    <template v-else-if="name === 'package'"><path d="M21 8v12.5a.5.5 0 0 1-.5.5h-17a.5.5 0 0 1-.5-.5V8"/><path d="M1 5h22l-2 3H3z"/><path d="M10 12h4"/></template>
    <template v-else-if="name === 'box'"><path d="M21 16V8a2 2 0 0 0-1-1.7l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.7l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><path d="m3.3 7 8.7 5 8.7-5M12 22V12"/></template>
    <template v-else-if="name === 'database'"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v6c0 1.7 4 3 9 3s9-1.3 9-3V5"/><path d="M3 11v6c0 1.7 4 3 9 3s9-1.3 9-3v-6"/></template>
    <template v-else-if="name === 'book-open'"><path d="M12 7v14M20 5H14a3 3 0 0 0-2 2 3 3 0 0 0-2-2H4v14h6a3 3 0 0 1 2 2 3 3 0 0 1 2-2h6Z"/></template>
    <template v-else-if="name === 'clipboard'"><rect x="8" y="3" width="8" height="4" rx="1"/><path d="M16 5h2a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h2"/><path d="M8 11h8M8 15h5"/></template>
    <template v-else-if="name === 'settings'"><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/><circle cx="12" cy="12" r="3"/></template>
    <template v-else-if="name === 'home'"><path d="M3 11.5 12 3l9 8.5"/><path d="M5 10v10a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V10"/></template>
    <template v-else-if="name === 'gauge'"><path d="M12 14 20 6"/><path d="M3.7 16a9 9 0 1 1 16.6 0"/></template>
    <template v-else-if="name === 'file-text'"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h8M8 9h2"/></template>
  </svg>
</template>
