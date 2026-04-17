import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { parseEcommerceExcel, importEcommerceOrders, platformTypeName } from '../lib/ecommerceOrderImporter'
import { useAccountStore } from '../stores/accounts'
import * as XLSX from 'xlsx'

export function useEcommerceImport({ loadOrders, loadStats, loadTodayOrdersData }) {
  const accountStore = useAccountStore()

  // ---------- state ----------
  const showEcommerceImportModal = ref(false)
  const ecomImportStep = ref('upload') // upload | preview | result
  const ecomPlatformMode = ref('auto') // auto | douyin | kuaishou | shipinhao
  const ecomImporting = ref(false)
  const ecomImportError = ref('')
  const ecomImportProgress = ref('')   // 导入进度文本，实时显示主线程在做什么
  const isEcomDragging = ref(false)
  const ecomSalesOrders = ref([])
  const ecomAfterSalesOrders = ref([])
  const ecomSkippedCount = ref(0)
  const ecomActiveTab = ref('sales')
  const ecomImportResult = ref({ success: 0, duplicate: 0, failures: [] })

  // ---------- helpers ----------
  function resetEcomImport() {
    ecomImportStep.value = 'upload'
    ecomPlatformMode.value = 'auto'
    ecomImporting.value = false
    ecomImportError.value = ''
    ecomImportProgress.value = ''
    isEcomDragging.value = false
    ecomSalesOrders.value = []
    ecomAfterSalesOrders.value = []
    ecomSkippedCount.value = 0
    ecomActiveTab.value = 'sales'
    ecomImportResult.value = { success: 0, duplicate: 0, failures: [] }
  }

  function openEcommerceImportModal() {
    resetEcomImport()
    showEcommerceImportModal.value = true
  }

  function ecomPlatformTagClass(p) {
    const classes = {
      douyin: 'bg-pink-50 text-pink-600',
      kuaishou: 'bg-orange-50 text-orange-600',
      shipinhao: 'bg-green-50 text-green-600',
    }
    return classes[p] || 'bg-gray-100 text-gray-500'
  }

  // ---------- computed ----------
  const ecomAllOrders = computed(() => [...ecomSalesOrders.value, ...ecomAfterSalesOrders.value])
  const selectedEcomCount = computed(() => ecomAllOrders.value.filter(o => o._selected).length)
  const isAllEcomSelected = computed(() => ecomAllOrders.value.length > 0 && ecomAllOrders.value.every(o => o._selected))
  const isAllEcomSalesSelected = computed(() => ecomSalesOrders.value.length > 0 && ecomSalesOrders.value.every(o => o._selected))
  const isAllEcomAfterSalesSelected = computed(() => ecomAfterSalesOrders.value.length > 0 && ecomAfterSalesOrders.value.every(o => o._selected))
  const ecomSelectedSalesTotal = computed(() => ecomSalesOrders.value.filter(o => o._selected).reduce((s, o) => s + (Number(o.payment_amount) || 0), 0))
  const ecomSelectedRefundTotal = computed(() => ecomAfterSalesOrders.value.filter(o => o._selected).reduce((s, o) => s + (Number(o.refund_amount) || 0), 0))

  // ---------- selection ----------
  function toggleAllEcomSelection(e) {
    const val = e.target.checked
    for (const order of ecomAllOrders.value) order._selected = val
  }
  function toggleEcomSalesAll(e) {
    const val = e.target.checked
    for (const order of ecomSalesOrders.value) order._selected = val
  }
  function toggleEcomAfterSalesAll(e) {
    const val = e.target.checked
    for (const order of ecomAfterSalesOrders.value) order._selected = val
  }

  // ---------- file handling ----------
  async function handleEcomFileSelect(e) {
    const file = e.target.files?.[0]
    if (!file) return
    await processEcomImportFile(file)
    e.target.value = ''
  }

  async function handleEcomFileDrop(e) {
    isEcomDragging.value = false
    const file = e.dataTransfer?.files?.[0]
    if (!file) return
    const ext = file.name.split('.').pop().toLowerCase()
    if (!['xlsx', 'xls'].includes(ext)) {
      ecomImportError.value = '仅支持 .xlsx / .xls 格式'
      return
    }
    await processEcomImportFile(file)
  }

  async function processEcomImportFile(file) {
    ecomImportError.value = ''
    ecomImporting.value = true

    try {
      // 解析 Excel
      const data = new Uint8Array(await file.arrayBuffer())
      const workbook = XLSX.read(data, { type: 'array' })
      const sheetNames = workbook.SheetNames

      const forcePlatform = ecomPlatformMode.value === 'auto' ? null : ecomPlatformMode.value

      const { salesOrders, afterSalesOrders, skipped, errors } = parseEcommerceExcel(workbook, {
        autoDetect: ecomPlatformMode.value === 'auto',
        forcePlatform,
      })

      ecomSalesOrders.value = salesOrders
      ecomAfterSalesOrders.value = afterSalesOrders
      ecomSkippedCount.value = skipped

      if (errors.length > 0) {
        ecomImportError.value = errors.slice(0, 3).join('\n') + (errors.length > 3 ? `\n...共 ${errors.length} 条警告` : '')
      }

      if (salesOrders.length === 0 && afterSalesOrders.length === 0) {
        ecomImportError.value = '未识别到有效的订单数据，请检查文件格式和Sheet名称'
        ecomImporting.value = false
        return
      }

      ecomImportStep.value = 'preview'
    } catch (err) {
      ecomImportError.value = '解析文件失败: ' + (err.message || '')
    } finally {
      ecomImporting.value = false
    }
  }

  // ---------- import ----------
  async function handleEcomImport() {
    const selectedSales = ecomSalesOrders.value.filter(o => o._selected)
    const selectedRefunds = ecomAfterSalesOrders.value.filter(o => o._selected)
    if (selectedSales.length === 0 && selectedRefunds.length === 0) return

    ecomImporting.value = true

    try {
      ecomImportProgress.value = '正在启动…'
      const result = await importEcommerceOrders({
        salesOrders: selectedSales,
        afterSalesOrders: selectedRefunds,
        supabase,
        onProgress: ({ type, current, total, message }) => {
          // 把进度直接写到 UI，避免用户看见"假死"
          ecomImportProgress.value = message || `${type} ${current}/${total}`
        },
      })

      ecomImportResult.value = result
      ecomImportStep.value = 'result'

      // 刷新数据
      loadStats()
      loadOrders()
      loadTodayOrdersData()
      accountStore._forceRefresh = true
      await accountStore.fetchAccounts()
    } catch (err) {
      ecomImportError.value = '导入失败: ' + (err.message || '')
    } finally {
      ecomImporting.value = false
    }
  }

  return {
    // re-export for template use
    platformTypeName,
    // state
    showEcommerceImportModal,
    ecomImportStep,
    ecomPlatformMode,
    ecomImporting,
    ecomImportError,
    ecomImportProgress,
    isEcomDragging,
    ecomSalesOrders,
    ecomAfterSalesOrders,
    ecomSkippedCount,
    ecomActiveTab,
    ecomImportResult,
    // computed
    ecomAllOrders,
    selectedEcomCount,
    isAllEcomSelected,
    isAllEcomSalesSelected,
    isAllEcomAfterSalesSelected,
    ecomSelectedSalesTotal,
    ecomSelectedRefundTotal,
    // functions
    ecomPlatformTagClass,
    resetEcomImport,
    openEcommerceImportModal,
    toggleAllEcomSelection,
    toggleEcomSalesAll,
    toggleEcomAfterSalesAll,
    handleEcomFileSelect,
    handleEcomFileDrop,
    handleEcomImport,
  }
}
