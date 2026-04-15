<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Mobile Top Bar -->
    <header v-if="isMobile" class="fixed top-0 left-0 right-0 h-12 bg-white border-b border-gray-200 z-30 flex items-center justify-between px-4 md:hidden">
      <button @click="sidebarOpen = true" aria-label="打开菜单" class="w-10 h-10 flex items-center justify-center text-gray-600 hover:bg-gray-100 rounded-lg transition cursor-pointer">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/></svg>
      </button>
      <h1 class="font-semibold text-sm text-gray-800 truncate">{{ routeTitle }}</h1>
      <div class="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-xs font-medium flex-shrink-0">
        {{ userInitial }}
      </div>
    </header>

    <!-- Mobile Overlay -->
    <div
      v-if="isMobile && sidebarOpen"
      class="fixed inset-0 bg-black/20 z-40 transition-opacity duration-200 md:hidden"
      @click="sidebarOpen = false"
    ></div>

    <!-- Sidebar (drawer on mobile, fixed on desktop) -->
    <aside
      role="navigation"
      aria-label="主导航"
      class="fixed left-0 top-0 bottom-0 w-72 md:w-56 bg-white border-r border-gray-100 flex flex-col z-50 transition-transform duration-200 ease-out"
      :class="isMobile ? (sidebarOpen ? 'translate-x-0' : '-translate-x-full') : 'translate-x-0'"
    >
      <div class="p-5 border-b border-gray-100">
        <div class="flex items-center gap-2">
          <span class="text-2xl">🎱</span>
          <div>
            <div class="font-bold text-gray-800 text-sm">台球账目系统</div>
            <div class="text-xs text-gray-500">{{ profile?.name || '未登录' }}</div>
          </div>
        </div>
      </div>

      <!-- 可滚动的导航区域 -->
      <nav class="flex-1 overflow-y-auto py-3 px-3 space-y-0.5 scrollbar-thin">
        <!-- 始终可见：首页入口 -->
        <router-link to="/"
          class="flex items-center gap-2.5 px-3 py-2.5 rounded-lg text-sm transition relative"
          :class="$route.path === '/' ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-600 hover:bg-gray-50'"
          @click="closeSidebar"
        >
          <span class="text-base">📊</span>
          <span class="flex-1">收支总览</span>
        </router-link>

        <template v-for="(group, gIndex) in menuGroups" :key="gIndex">
          <button
            @click="toggleGroup(gIndex)"
            class="w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-sm font-semibold text-gray-700 hover:bg-gray-50 transition cursor-pointer mt-1"
          >
            <span class="flex items-center gap-2.5">
              <span class="text-base">{{ group.icon }}</span>
              <span>{{ group.label }}</span>
            </span>
            <svg class="w-3.5 h-3.5 text-gray-300 transition-transform duration-200 flex-shrink-0" :class="collapsedGroups[gIndex] ? '' : 'rotate-180'" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 9l-7 7-7-7"/></svg>
          </button>
          <div v-show="!collapsedGroups[gIndex]" class="space-y-0.5 ml-2 pl-3 border-l-2 border-gray-100">
            <router-link
              v-for="item in group.items"
              :key="item.path"
              :to="item.path"
              class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition relative"
              :class="$route.path === item.path ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-500 hover:bg-gray-50 hover:text-gray-700'"
              @click="closeSidebar"
            >
              <span class="flex-1 truncate">{{ item.label }}</span>
              <span
                v-if="item.badge && item.badge > 0"
                class="bg-red-500 text-white text-xs font-bold rounded-full min-w-[20px] h-5 flex items-center justify-center px-1.5 flex-shrink-0"
              >{{ item.badge > 99 ? '99+' : item.badge }}</span>
              <span
                v-else-if="item.dot"
                class="w-2 h-2 bg-red-500 rounded-full flex-shrink-0"
              ></span>
            </router-link>
          </div>
        </template>
      </nav>

      <div class="p-3 border-t border-gray-100 pb-20 md:pb-3">
        <button @click="handleLogout" class="w-full flex items-center gap-2.5 px-3 py-2.5 rounded-lg text-sm text-gray-500 hover:bg-gray-50 hover:text-gray-600 transition cursor-pointer">
          <span>退出登录</span>
        </button>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="pt-12 pb-14 px-4 md:ml-56 md:p-6 md:pt-6 md:pb-6 transition-all duration-200">
      <div class="max-w-7xl mx-auto">
        <router-view />
      </div>
    </main>

    <!-- Mobile Bottom Tab Bar -->
    <nav v-if="isMobile" aria-label="底部导航" class="fixed bottom-0 left-0 right-0 h-14 bg-white border-t border-gray-200 z-50 flex items-center justify-around md:hidden">
      <router-link to="/" class="flex flex-col items-center justify-center flex-1 h-full transition-colors active:scale-90 active:opacity-70" :class="$route.path === '/' ? 'text-blue-600' : 'text-gray-500'">
        <span class="text-lg leading-none mb-0.5">📊</span>
        <span class="text-[10px] leading-none">首页</span>
      </router-link>
      <router-link to="/orders" class="flex flex-col items-center justify-center flex-1 h-full transition-colors active:scale-90 active:opacity-70" :class="$route.path === '/orders' ? 'text-blue-600' : 'text-gray-500'">
        <span class="text-lg leading-none mb-0.5">📝</span>
        <span class="text-[10px] leading-none">订单</span>
      </router-link>
      <router-link to="/expenses" class="flex flex-col items-center justify-center flex-1 h-full transition-colors active:scale-90 active:opacity-70" :class="$route.path === '/expenses' ? 'text-blue-600' : 'text-gray-500'">
        <span class="text-lg leading-none mb-0.5">💸</span>
        <span class="text-[10px] leading-none">收支</span>
      </router-link>
      <router-link to="/accounts" class="flex flex-col items-center justify-center flex-1 h-full transition-colors active:scale-90 active:opacity-70" :class="$route.path === '/accounts' ? 'text-blue-600' : 'text-gray-500'">
        <span class="text-lg leading-none mb-0.5">🏦</span>
        <span class="text-[10px] leading-none">账户</span>
      </router-link>
      <button @click="sidebarOpen = true" aria-label="更多菜单" class="flex flex-col items-center justify-center flex-1 h-full text-gray-500 transition-colors active:scale-90 active:opacity-70 cursor-pointer">
        <span class="text-lg leading-none mb-0.5">☰</span>
        <span class="text-[10px] leading-none">更多</span>
      </button>
    </nav>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { usePermission } from '../composables/usePermission'
import { supabase } from '../lib/supabase'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const { role, loadRole } = usePermission()
const profile = computed(() => auth.profile)
const pendingCount = ref(0)

// Mobile detection
const isMobile = ref(false)
const sidebarOpen = ref(false)

function checkMobile() {
  isMobile.value = window.innerWidth < 768
}

onMounted(() => {
  checkMobile()
  window.addEventListener('resize', checkMobile)
  loadRole()
})

onUnmounted(() => {
  window.removeEventListener('resize', checkMobile)
})

function closeSidebar() {
  if (isMobile.value) sidebarOpen.value = false
}

// Route title mapping
const ROUTE_TITLES = {
  '/': '收支总览',
  '/orders': '订单登记',
  '/expenses': '收支管理',
  '/service-numbers': '客服号管理',
  '/accounts': '账户管理',
  '/transfers': '转账提现',

  '/balance': '余额快照',
  '/performance': '业绩统计',
  '/commission': '提成管理',
  '/reports': '财务报表',
  '/platforms': '平台收入',
  '/platform-integration': '凭证配置',
  '/platform-orders': '外部订单',
  '/products': '产品库',
  '/customers': '客户管理',
  '/coaching': '教练系统',
  '/legal-reports': '法定报表',
  '/users': '用户管理',
  '/sales-groups': '销售分组',
  '/settings': '系统设置',
  '/assets': '手机管理',
  '/shareholder-loans': '股东垫资',
  '/logs': '操作日志',
  '/warehouses': '仓库管理',
  '/inventory': '库存管理',
  '/inventory-logs': '库存流水',
  '/purchase-orders': '产品订货',
  '/fixed-assets': '固定资产',
  '/deferred-expenses': '长期待摊费用',
  '/intangible-assets': '无形资产',
  '/prepaid-accounts': '预付账款',
  '/payable-accounts': '应付账款',
  '/deferred-revenue': '预收账款',
  '/other-receivables': '其他应收款',
  '/other-payables': '其他应付款',
}

const routeTitle = computed(() => {
  const path = route.path
  // Exact match first
  if (ROUTE_TITLES[path]) return ROUTE_TITLES[path]
  // Prefix match for dynamic routes like /accounts/:id
  const segments = path.split('/')
  if (segments.length > 1 && ROUTE_TITLES['/' + segments[1]]) {
    return ROUTE_TITLES['/' + segments[1]]
  }
  // Fallback from meta title
  return route.meta?.title || '台球账目'
})

const userInitial = computed(() => {
  const name = profile.value?.name
  return name ? name.charAt(0) : '?'
})

// 折叠状态
const collapsedGroups = reactive({})

function toggleGroup(index) {
  collapsedGroups[index] = !collapsedGroups[index]
}

// 菜单分组（展开项根据角色权限动态调整）
const menuGroups = computed(() => {
  const groups = []
  const r = role.value || auth.profile?.role || ''

  // 仓库角色只能看库存相关
  if (r === 'warehouse') {
    groups.push({
      icon: '🗄️',
      label: '库存管理',
      items: [
        { label: '仓库管理', path: '/warehouses' },
        { label: '库存总览', path: '/inventory' },
        { label: '库存流水', path: '/inventory-logs' },
        { label: '产品订货', path: '/purchase-orders' },
      ],
    })
    return groups
  }

  // 非财务角色只看首页（订单入口保留）
  if (!['admin', 'finance', 'manager'].includes(r)) {
    return []
  }

  // ✏️ 业务登记
  groups.push({
    icon: '✏️',
    label: '业务登记',
    items: [
      { label: '订单管理', path: '/orders' },
      { label: '收支管理', path: '/expenses' },
      { label: '客户管理', path: '/customers' },
    ],
  })

  // 📦 产品与电商
  groups.push({
    icon: '📦',
    label: '产品与电商',
    items: [
      { label: '产品库', path: '/products' },
      { label: '产品销量', path: '/product-sales' },
      { label: '电商订单', path: '/ecommerce-orders' },
      { label: '电商销量', path: '/ecommerce-sales' },
      { label: '电商管理', path: '/ecommerce' },
    ],
  })

  // 💰 资金管理
  groups.push({
    icon: '💰',
    label: '资金管理',
    items: [
      { label: '账户管理', path: '/accounts' },
      { label: '转账提现', path: '/transfers' },
      { label: '余额对账', path: '/balance' },
      { label: '股东垫资', path: '/shareholder-loans' },
      { label: '股东分红', path: '/dividends' },
      { label: '手机管理', path: '/assets' },
    ],
  })

  // 📒 财务台账
  groups.push({
    icon: '📒',
    label: '财务台账',
    items: [
      { label: '固定资产', path: '/fixed-assets' },
      { label: '长期待摊', path: '/deferred-expenses' },
      { label: '无形资产', path: '/intangible-assets' },
      { label: '预付账款', path: '/prepaid-accounts' },
      { label: '应付账款', path: '/payable-accounts' },
      { label: '预收账款', path: '/deferred-revenue' },
      { label: '其他应收', path: '/other-receivables' },
      { label: '其他应付', path: '/other-payables' },
    ],
  })

  // 👥 团队与业绩
  groups.push({
    icon: '👥',
    label: '团队与业绩',
    items: [
      { label: '业绩总览', path: '/performance' },
      { label: '提成管理', path: '/commission' },
      { label: '销售分组', path: '/sales-groups' },
      { label: '教练管理', path: '/coaching' },
      { label: '客服号管理', path: '/service-numbers' },
      { label: '渠道管理', path: '/channels' },
    ],
  })

  // 🏪 平台与对接
  groups.push({
    icon: '🏪',
    label: '平台与对接',
    items: [
      { label: '平台管理', path: '/platforms' },
      { label: '平台对接', path: '/platform-integration' },
      { label: '平台订单', path: '/platform-orders' },
    ],
  })

  // 🗄️ 库存管理
  groups.push({
    icon: '🗄️',
    label: '库存管理',
    items: [
      { label: '仓库管理', path: '/warehouses' },
      { label: '库存总览', path: '/inventory' },
      { label: '库存流水', path: '/inventory-logs' },
      { label: '采购订单', path: '/purchase-orders' },
    ],
  })

  // 📊 报表
  groups.push({
    icon: '📊',
    label: '报表',
    items: [
      { label: '财务报表', path: '/reports' },
      { label: '法务报表', path: '/legal-reports' },
    ],
  })

  // ⚙️ 系统
  if (auth.isFinance) {
    groups.push({
      icon: '⚙️',
      label: '系统',
      items: [
        { label: '用户管理', path: '/users' },
        { label: '操作日志', path: '/logs' },
        { label: '系统设置', path: '/settings' },
      ],
    })
  }

  return groups
})

async function fetchPendingCount() {
  if (!auth.isFinance) return
  try {
    const { data, error } = await supabase.rpc('get_pending_count')
    if (!error && data != null) {
      pendingCount.value = Number(data) || 0
    }
  } catch (e) {}
}

onMounted(() => {
  if (auth.isLoggedIn) fetchPendingCount()
})

watch(() => auth.isLoggedIn, (val) => {
  if (val) fetchPendingCount()
  else pendingCount.value = 0
})

let timer = null
onMounted(() => {
  timer = setInterval(fetchPendingCount, 60000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})

async function handleLogout() {
  await auth.logout()
  pendingCount.value = 0
  sidebarOpen.value = false
  router.push('/login')
}
</script>

<style scoped>
/* 自定义细滚动条 */
.scrollbar-thin {
  scrollbar-width: 3px;
}
.scrollbar-thin::-webkit-scrollbar {
  width: 3px;
}
.scrollbar-thin::-webkit-scrollbar-track {
  background: transparent;
}
</style>
