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

    <!-- 状态 / 反馈 -->
    <template v-else-if="name === 'check'"><path d="M20 6 9 17l-5-5"/></template>
    <template v-else-if="name === 'check-circle'"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></template>
    <template v-else-if="name === 'x'"><path d="M18 6 6 18M6 6l12 12"/></template>
    <template v-else-if="name === 'x-circle'"><circle cx="12" cy="12" r="9"/><path d="m9 9 6 6M15 9l-6 6"/></template>
    <template v-else-if="name === 'info'"><circle cx="12" cy="12" r="9"/><path d="M12 17v-5M12 8h.01"/></template>
    <template v-else-if="name === 'help-circle'"><circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 1 1 5.8 1c0 2-3 3-3 3M12 17h.01"/></template>
    <template v-else-if="name === 'loader'"><path d="M12 3v3m0 12v3M5.6 5.6l2.1 2.1m8.6 8.6 2.1 2.1M3 12h3m12 0h3M5.6 18.4l2.1-2.1m8.6-8.6 2.1-2.1"/></template>

    <!-- 时间 / 日历 -->
    <template v-else-if="name === 'calendar'"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></template>
    <template v-else-if="name === 'clock'"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></template>

    <!-- 操作 -->
    <template v-else-if="name === 'download'"><path d="M12 3v12m0 0-4-4m4 4 4-4"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/></template>
    <template v-else-if="name === 'upload'"><path d="M12 21V9m0 0-4 4m4-4 4 4"/><path d="M4 7V5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2"/></template>
    <template v-else-if="name === 'filter'"><path d="M3 5h18l-7 9v5l-4 2v-7Z"/></template>
    <template v-else-if="name === 'trash'"><path d="M4 6h16M10 11v6M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 6l1 14a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-14"/></template>
    <template v-else-if="name === 'copy'"><rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V4a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h4"/></template>
    <template v-else-if="name === 'save'"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M7 3v6h10M7 21v-8h10v8"/></template>
    <template v-else-if="name === 'link'"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></template>
    <template v-else-if="name === 'eye'"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></template>
    <template v-else-if="name === 'eye-off'"><path d="m2 2 20 20M6.7 6.7C3.5 8.8 1 12 1 12s4 7 11 7c2 0 3.8-.6 5.3-1.4"/><path d="M10 4.4c.6-.2 1.3-.3 2-.3 7 0 11 7.1 11 7.1s-1.3 2.2-3.4 4"/><path d="M14.1 14.1a3 3 0 0 1-4.2-4.2"/></template>

    <!-- 商业 / 金融 扩展 -->
    <template v-else-if="name === 'credit-card'"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20M6 15h3"/></template>
    <template v-else-if="name === 'gift'"><rect x="3" y="8" width="18" height="4" rx="1"/><path d="M5 12v8a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-8M12 8v13"/><path d="M12 8a3 3 0 1 0-3-3M12 8a3 3 0 1 1 3-3"/></template>
    <template v-else-if="name === 'tag'"><path d="M9 3h10a2 2 0 0 1 2 2v10l-9 9a2 2 0 0 1-2.8 0l-7.2-7.2a2 2 0 0 1 0-2.8Z"/><circle cx="14" cy="9" r="1.3"/></template>
    <template v-else-if="name === 'target'"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.3"/></template>
    <template v-else-if="name === 'crown'"><path d="m3 17 2-11 5 5 2-7 2 7 5-5 2 11Z"/><path d="M3 21h18"/></template>
    <template v-else-if="name === 'dollar'"><path d="M12 3v18M17 6H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 1 1 0 7H6"/></template>
    <template v-else-if="name === 'briefcase'"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M2 13h20"/></template>

    <!-- 安全 / 权限 -->
    <template v-else-if="name === 'lock'"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></template>
    <template v-else-if="name === 'unlock'"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/></template>
    <template v-else-if="name === 'key'"><circle cx="8" cy="15" r="4"/><path d="m10.8 12.8 9.2-9.2M16 6l3 3M13 9l2 2"/></template>

    <!-- 通讯 / 外部 -->
    <template v-else-if="name === 'mail'"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="m3 7 9 7 9-7"/></template>
    <template v-else-if="name === 'phone'"><path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2z"/></template>
    <template v-else-if="name === 'globe'"><circle cx="12" cy="12" r="9"/><path d="M2 12h20M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/></template>
    <template v-else-if="name === 'external-link'"><path d="M15 3h6v6M10 14 21 3M21 12v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h6"/></template>

    <!-- 创意 / 其他 -->
    <template v-else-if="name === 'brain'"><path d="M12 4a3 3 0 0 0-6 0 3 3 0 0 0-2 5 3 3 0 0 0 0 6 3 3 0 0 0 2 5 3 3 0 0 0 6 0"/><path d="M12 4a3 3 0 0 1 6 0 3 3 0 0 1 2 5 3 3 0 0 1 0 6 3 3 0 0 1-2 5 3 3 0 0 1-6 0"/><path d="M12 4v16"/></template>
    <template v-else-if="name === 'bulb'"><path d="M9 18h6M10 21h4M12 3a6 6 0 0 1 4 10.5c-1 .8-1.5 2-1.5 3.5h-5c0-1.5-.5-2.7-1.5-3.5A6 6 0 0 1 12 3Z"/></template>
    <template v-else-if="name === 'star'"><path d="m12 3 2.9 6 6.6.9-4.8 4.6 1.1 6.5L12 18l-5.9 3 1.1-6.5L2.5 9.9 9 9Z"/></template>
    <template v-else-if="name === 'flag'"><path d="M4 21V4M4 4h13l-3 5 3 5H4"/></template>
    <template v-else-if="name === 'camera'"><path d="M2 8h5l2-3h6l2 3h5v12H2z"/><circle cx="12" cy="13" r="4"/></template>
    <template v-else-if="name === 'image'"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-5-5L5 21"/></template>
    <template v-else-if="name === 'folder'"><path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></template>
    <template v-else-if="name === 'inbox'"><path d="M3 13h5l2 3h4l2-3h5"/><path d="M3 13 5 5a2 2 0 0 1 2-1h10a2 2 0 0 1 2 1l2 8v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></template>
    <template v-else-if="name === 'rocket'"><path d="M5 19a4 4 0 0 1 4-4 4 4 0 0 1-4 4z"/><path d="m15 4-2 2-3 1-5 5 4 4 5-5 1-3 2-2a3 3 0 0 0-2-2z"/><circle cx="14" cy="10" r="1"/></template>
    <template v-else-if="name === 'wand'"><path d="M15 4V2M15 16v-2M8 9h2M20 9h2M17.8 11.8l1.4 1.4M17.8 6.2l1.4-1.4"/><path d="M5 22 14 13l-3-3L2 19Z"/></template>
    <template v-else-if="name === 'zap'"><path d="m13 2-10 12h7l-1 8 10-12h-7z"/></template>
    <template v-else-if="name === 'dices'"><rect x="2" y="10" width="12" height="12" rx="2"/><rect x="10" y="2" width="12" height="12" rx="2"/><path d="M6 14h.01M10 18h.01M14 10h.01M18 6h.01M18 10h.01M14 6h.01"/></template>
  </svg>
</template>
