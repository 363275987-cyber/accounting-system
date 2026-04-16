import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const routes = [
  { path: '/login', name: 'Login', component: () => import('../views/Login.vue'), meta: { guest: true } },
  { 
    path: '/', 
    component: () => import('../views/Layout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', name: 'Dashboard', component: () => import('../views/Dashboard.vue') },
      { path: 'orders', name: 'Orders', component: () => import('../views/Orders.vue') },
      { path: 'expenses', name: 'Expenses', component: () => import('../views/IncomeExpense.vue') },
      { path: 'expense-categories', name: 'ExpenseCategories', component: () => import('../views/ExpenseCategories.vue'), meta: { title: '支出类别管理' } },
      { path: 'accounts', name: 'Accounts', component: () => import('../views/Accounts.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'transfers', name: 'Transfers', component: () => import('../views/Transfers.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'service-numbers', name: 'ServiceNumbers', component: () => import('../views/ServiceNumbers.vue'), meta: { title: '客服号管理' } },
      { path: 'performance', name: 'Performance', component: () => import('../views/Performance.vue') },
      { path: 'commission', name: 'Commission', component: () => import('../views/Commission.vue') },
      { path: 'salary', name: 'SalaryManagement', component: () => import('../views/SalaryManagement.vue'), meta: { title: '工资管理', roles: ['admin', 'finance', 'manager'] } },
      { path: 'users', name: 'Users', component: () => import('../views/UserManagement.vue'), meta: { roles: ['admin'] } },
      { path: 'sales-groups', name: 'SalesGroups', component: () => import('../views/SalesGroups.vue'), meta: { roles: ['admin', 'manager'] } },
      { path: 'refunds', redirect: '/orders' },
      { path: 'balance', name: 'Balance', component: () => import('../views/Balance.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'products', name: 'Products', component: () => import('../views/Products.vue') },
      { path: 'customers', name: 'Customers', component: () => import('../views/Customers.vue') },
      { path: 'reports', name: 'Reports', component: () => import('../views/Reports.vue') },
      { path: 'product-sales', name: 'ProductSales', component: () => import('../views/ProductSales.vue') },
      { path: 'legal-reports', redirect: '/reports' },
      { path: 'coaching', name: 'Coaching', component: () => import('../views/Coaching.vue') },
      { path: 'platforms', name: 'Platforms', component: () => import('../views/Platforms.vue') },
      { path: 'ecommerce-sales', name: 'EcommerceSales', component: () => import('../views/EcommerceSales.vue') },
      { path: 'shareholder-loans', name: 'ShareholderLoans', component: () => import('../views/ShareholderLoans.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'dividends', name: 'Dividends', component: () => import('../views/Dividends.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'logs', name: 'OperationLogs', component: () => import('../views/OperationLogs.vue'), meta: { title: '操作日志', roles: ['admin', 'finance', 'manager'] } },
      { path: 'assets', name: 'AssetManagement', component: () => import('../views/AssetManagement.vue') },
      { path: 'fixed-assets', name: 'FixedAssets', component: () => import('../views/FixedAssets.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'deferred-expenses', name: 'DeferredExpenses', component: () => import('../views/DeferredExpenses.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'prepaid-accounts', name: 'PrepaidAccounts', component: () => import('../views/PrepaidAccounts.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'payable-accounts', name: 'PayableAccounts', component: () => import('../views/PayableAccounts.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'deferred-revenue', name: 'DeferredRevenue', component: () => import('../views/DeferredRevenue.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'other-receivables', name: 'OtherReceivables', component: () => import('../views/OtherReceivables.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'intangible-assets', name: 'IntangibleAssets', component: () => import('../views/IntangibleAssets.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'other-payables', name: 'OtherPayables', component: () => import('../views/OtherPayables.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
      { path: 'platform-integration', name: 'PlatformIntegration', component: () => import('../views/PlatformIntegration.vue') },
      { path: 'platform-orders', name: 'PlatformOrders', component: () => import('../views/PlatformOrders.vue') },
      { path: 'settings', name: 'Settings', component: () => import('../views/Settings.vue'), meta: { adminOnly: true } },
      { path: 'accounts/:id', name: 'AccountDetail', component: () => import('../views/AccountDetail.vue') },
      { path: 'warehouses', name: 'Warehouses', component: () => import('../views/Warehouses.vue'), meta: { title: '仓库管理' } },
      { path: 'inventory', name: 'Inventory', component: () => import('../views/Inventory.vue'), meta: { title: '库存管理' } },
      { path: 'inventory-logs', name: 'InventoryLogs', component: () => import('../views/InventoryLogs.vue'), meta: { title: '库存流水' } },
      { path: 'purchase-orders', name: 'PurchaseOrders', component: () => import('../views/PurchaseOrders.vue') },
      { path: 'ecommerce', name: 'Ecommerce', component: () => import('../views/Ecommerce.vue') },
      { path: 'ecommerce-orders', name: 'EcommerceOrders', component: () => import('../views/EcommerceOrders.vue') },
      { path: 'channels', name: 'Channels', component: () => import('../views/Channels.vue'), meta: { roles: ['admin', 'finance', 'manager'] } },
    ]
  },
  // 404
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

// Auth guard — wait for auth initialization before checking
router.beforeEach(async (to, from, next) => {
  const auth = useAuthStore()
  
  // If auth is still loading, wait for it
  if (auth.loading) {
    await new Promise(resolve => {
      const unwatch = auth.$subscribe(() => {
        if (!auth.loading) {
          unwatch()
          resolve()
        }
      })
      // Safety timeout: if loading takes too long, proceed anyway
      setTimeout(() => { unwatch(); resolve() }, 3000)
    })
  }
  
  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    next('/login')
  } else if (to.meta.guest && auth.isLoggedIn) {
    next('/')
  } else {
    // 角色权限校验
    const allowedRoles = to.meta.roles || to.matched.find(r => r.meta.roles)?.meta.roles
    if (allowedRoles && auth.profile?.role && !allowedRoles.includes(auth.profile.role)) {
      next('/') // 无权限跳回首页
      return
    }
    // adminOnly 校验
    if (to.meta.adminOnly && !auth.isAdmin) {
      next('/')
      return
    }
    next()
  }
})

export default router
