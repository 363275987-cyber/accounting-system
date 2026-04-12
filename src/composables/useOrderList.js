import { ref, reactive, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useOrderStore } from '../stores/orders'
import { useAccountStore } from '../stores/accounts'
import { toast, debounce, PLATFORM_LABELS } from '../lib/utils'

/**
 * 订单列表相关逻辑（筛选、分页、选择、操作）
 * @param {object} authStore
 */
export function useOrderList(authStore) {
  const orderStore = useOrderStore()
  const accountStore = useAccountStore()

  // ---------- permissions ----------
  const isFinance = computed(() => authStore.isFinance)
  const isAdmin = computed(() => authStore.isAdmin)

  // ---------- Tab 筛选 ----------
  const activeTab = ref('private')
  const orderTabs = [
    { key: 'private', label: '私域订单' },
  ]

  const filteredOrders = computed(() => {
    return orderStore.orders.filter(o => !o.platform_type)
  })

  // ---------- selection ----------
  const selectedOrders = ref([])
  const canDeleteOrders = computed(() => isAdmin.value || isFinance.value || authStore.isSales)
  const isAllSelected = computed(() => filteredOrders.value.length > 0 && selectedOrders.value.length === filteredOrders.value.length)

  function toggleSelectAll(e) {
    if (e.target.checked) {
      selectedOrders.value = filteredOrders.value.map(o => o.id)
    } else {
      selectedOrders.value = []
    }
  }

  function canDeleteOrder(order) {
    if (isAdmin.value || isFinance.value) return true
    if (authStore.isSales) {
      return order.created_by === authStore.profile?.id
    }
    return false
  }

  // ---------- filters ----------
  const filters = reactive({
    keyword: '',
    searchField: '',
    category: '',
    status: '',
    dateFrom: '',
    dateTo: '',
  })

  // ---------- load orders ----------
  async function loadOrders() {
    const safeKeyword = (filters.keyword || '').replace(/[,%().*]/g, '')
    await orderStore.fetchOrders({
      keyword: safeKeyword || undefined,
      searchField: filters.searchField || undefined,
      category: filters.category || undefined,
      status: filters.status || undefined,
      dateFrom: filters.dateFrom || undefined,
      dateTo: filters.dateTo || undefined,
      page: orderStore.pagination.page,
      pageSize: orderStore.pagination.pageSize,
      platformTab: activeTab.value,
    })
  }

  // Watch filters for auto-reload (debounced)
  const debouncedLoad = debounce(() => loadOrders(), 300)
  watch(
    () => [filters.category, filters.status, filters.dateFrom, filters.dateTo],
    () => debouncedLoad()
  )

  // ---------- pagination ----------
  const totalPages = computed(() => {
    const { total, pageSize } = orderStore.pagination
    return Math.max(1, Math.ceil(total / pageSize))
  })

  function calcDisplayPages(current, total) {
    if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
    const pages = []
    pages.push(1)
    if (current > 3) pages.push('...')
    const start = Math.max(2, current - 1)
    const end = Math.min(total - 1, current + 1)
    for (let i = start; i <= end; i++) pages.push(i)
    if (current < total - 2) pages.push('...')
    if (total > 1) pages.push(total)
    return pages
  }

  const displayPages = computed(() => calcDisplayPages(orderStore.pagination.page, totalPages.value))

  function goPage(p) {
    if (p < 1 || p > totalPages.value) return
    orderStore.pagination.page = p
    loadOrders()
  }

  // ---------- platform tag helpers ----------
  function ecomPlatformTagClass(p) {
    const classes = {
      douyin: 'bg-pink-50 text-pink-600',
      kuaishou: 'bg-orange-50 text-orange-600',
      shipinhao: 'bg-green-50 text-green-600',
    }
    return classes[p] || 'bg-gray-100 text-gray-500'
  }

  function platformTypeTagLabel(p) {
    return PLATFORM_LABELS[p] || p || ''
  }

  function platformTypeTagClass(p) {
    const classes = {
      douyin: 'bg-pink-100 text-pink-700',
      kuaishou: 'bg-orange-100 text-orange-700',
      shipinhao: 'bg-green-100 text-green-700',
    }
    return classes[p] || 'bg-gray-100 text-gray-500'
  }

  // ---------- account helpers ----------
  function getAccountName(accountId) {
    const acc = accountStore.accounts.find(a => a.id === accountId)
    return acc ? (acc.short_name || acc.code) : '未知账户'
  }

  function getAccountShortName(accountId) {
    const acc = accountStore.accounts.find(a => a.id === accountId)
    return acc ? (acc.short_name || acc.code) : '—'
  }

  // ---------- actions ----------
  async function handleConfirmPayment(order) {
    if (!confirm(`确认已收到款项 ¥${Number(order.amount).toLocaleString()}？\n\n客户：${order.customer_name}\n产品：${order.product_name}`)) return
    try {
      const { error } = await supabase.from('orders').update({ status: 'completed' }).eq('id', order.id)
      if (error) throw error
      order.status = 'completed'
      toast('已确认收款', 'success')
      loadOrders()
    } catch (e) {
      toast('操作失败：' + (e.message || ''), 'error')
    }
  }

  async function handleCancel(order) {
    if (!confirm('确定要取消此订单吗？')) return
    try {
      await orderStore.updateOrder(order.id, { status: 'cancelled' })
      toast('订单已取消', 'success')
      loadOrders()
    } catch (e) {
      toast(e.message || '操作失败', 'error')
    }
  }

  async function handleDelete(order) {
    if (!confirm('确定要删除此订单吗？此操作不可恢复。')) return
    try {
      await orderStore.deleteOrder(order)
      toast('订单已删除', 'success')
      selectedOrders.value = selectedOrders.value.filter(id => id !== order.id)
      loadOrders()
    } catch (e) {
      toast(e.message || '操作失败', 'error')
    }
  }

  async function handleBatchDelete() {
    if (!selectedOrders.value.length) return
    if (!confirm(`确定要删除选中的 ${selectedOrders.value.length} 条订单吗？`)) return
    try {
      // 使用 batch_delete_orders RPC（软删除 + 退回余额）
      const { data, error } = await supabase.rpc('batch_delete_orders', {
        p_ids: selectedOrders.value,
      })
      if (error) throw error
      const deletedCount = data?.deleted || selectedOrders.value.length
      toast(`已删除 ${deletedCount} 条订单`, 'success')
      selectedOrders.value = []
      // 刷新账户余额（批量删除可能退回了多个账户的余额）
      accountStore.fetchAccounts()
      loadOrders()
    } catch (e) {
      console.error('批量删除失败:', e?.message || e?.details || JSON.stringify(e))
      toast('批量删除失败：' + (e.message || ''), 'error')
    }
  }

  return {
    // store ref
    orderStore,
    // tab
    activeTab,
    orderTabs,
    filteredOrders,
    // selection
    selectedOrders,
    canDeleteOrders,
    isAllSelected,
    toggleSelectAll,
    canDeleteOrder,
    // filters
    filters,
    // loading
    loadOrders,
    // pagination
    totalPages,
    displayPages,
    goPage,
    // platform helpers
    ecomPlatformTagClass,
    platformTypeTagLabel,
    platformTypeTagClass,
    // account helpers
    getAccountName,
    getAccountShortName,
    // actions
    handleConfirmPayment,
    handleCancel,
    handleDelete,
    handleBatchDelete,
  }
}
