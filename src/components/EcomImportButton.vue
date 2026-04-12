<template>
  <div>
    <!-- 触发按钮已移至父组件 Orders.vue 的导入弹窗内 -->

    <!-- Modal: E-commerce Import -->
    <div
      v-if="showEcommerceImportModal"
      class="fixed inset-0 bg-black/30 flex items-center justify-center z-50"
      @click.self="showEcommerceImportModal = false"
      @dragover.prevent="isEcomDragging = true"
      @dragleave.prevent="isEcomDragging = false"
      @drop.prevent="handleEcomFileDrop"
    >
      <div class="bg-white rounded-2xl shadow-2xl w-full md:max-w-5xl md:mx-4 overflow-hidden max-h-[90vh] flex flex-col">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 class="font-bold text-gray-800">🛒 电商订单导入</h2>
          <button @click="showEcommerceImportModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="p-6 overflow-y-auto">
          <!-- Step 1: Upload -->
          <div v-if="ecomImportStep === 'upload'" class="space-y-4">
            <div class="bg-blue-50 border border-blue-100 rounded-lg p-4 text-sm text-blue-700">
              <p class="font-medium mb-1">📌 电商订单导入说明</p>
              <ul class="list-disc list-inside space-y-1 text-xs text-blue-600">
                <li>支持抖音、快手、视频号平台的销售订单和售后订单</li>
                <li>自动识别 Sheet 名称判断平台（如"抖音-销售订单明细"）</li>
                <li>销售订单自动匹配/创建对应电商账户并增加余额</li>
                <li>售后订单自动匹配原始订单并扣减余额</li>
                <li>通过 SKU 编码关联产品库</li>
                <li>自动去重：已导入的订单号会跳过</li>
              </ul>
            </div>

            <!-- Platform Selection -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">平台选择</label>
              <div class="flex items-center gap-3">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input type="radio" v-model="ecomPlatformMode" value="auto" class="rounded cursor-pointer">
                  <span class="text-sm">自动识别（根据Sheet名称）</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input type="radio" v-model="ecomPlatformMode" value="douyin" class="rounded cursor-pointer">
                  <span class="text-sm text-pink-600">抖音</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input type="radio" v-model="ecomPlatformMode" value="kuaishou" class="rounded cursor-pointer">
                  <span class="text-sm text-orange-600">快手</span>
                </label>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input type="radio" v-model="ecomPlatformMode" value="shipinhao" class="rounded cursor-pointer">
                  <span class="text-sm text-green-600">视频号</span>
                </label>
              </div>
            </div>

            <label v-if="!ecomImporting" class="cursor-pointer">
              <div
                class="border-2 border-dashed rounded-lg p-8 text-center transition"
                :class="isEcomDragging ? 'border-green-500 bg-green-50' : 'border-gray-300 hover:border-green-400 hover:bg-green-50/30'"
              >
                <div class="text-3xl mb-2">📁</div>
                <div class="text-sm text-gray-600">点击选择 Excel 文件，或拖拽到此处</div>
                <div class="text-xs text-gray-500 mt-1">支持 .xlsx / .xls，可同时包含销售和售后Sheet</div>
              </div>
              <input
                type="file"
                accept=".xlsx,.xls"
                class="hidden"
                @change="handleEcomFileSelect"
              />
            </label>
            <div v-else class="border-2 border-dashed border-blue-300 rounded-lg p-8 text-center bg-blue-50/50">
              <div class="text-3xl mb-2 animate-pulse">📊</div>
              <div class="text-sm text-blue-600 font-medium">正在解析文件...</div>
              <div class="text-xs text-blue-400 mt-1">大文件可能需要几十秒，请耐心等待</div>
            </div>

            <div v-if="ecomImportError" class="text-red-500 text-sm bg-red-50 rounded-lg px-3 py-2">
              ⚠️ {{ ecomImportError }}
            </div>
          </div>

          <!-- Step 2: Preview -->
          <div v-if="ecomImportStep === 'preview'" class="space-y-4">
            <div class="flex items-center justify-between flex-wrap gap-2">
              <h3 class="text-sm font-semibold text-gray-700">👁️ 数据预览</h3>
              <div class="flex items-center gap-3 text-xs">
                <label class="flex items-center gap-1 cursor-pointer">
                  <input type="checkbox" :checked="isAllEcomSelected" @change="toggleAllEcomSelection" class="rounded cursor-pointer">
                  <span>全选</span>
                </label>
                <span class="text-green-600">已选 {{ selectedEcomCount }} / {{ ecomAllOrders.length }} 条</span>
              </div>
            </div>

            <!-- Tabs -->
            <div class="flex items-center gap-2 border-b border-gray-200 pb-2">
              <button
                @click="ecomActiveTab = 'sales'"
                :class="ecomActiveTab === 'sales' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-500'"
                class="px-3 py-1 text-sm cursor-pointer"
              >
                销售订单 ({{ ecomSalesOrders.length }})
              </button>
              <button
                @click="ecomActiveTab = 'aftersales'"
                :class="ecomActiveTab === 'aftersales' ? 'text-orange-600 border-b-2 border-orange-600' : 'text-gray-500'"
                class="px-3 py-1 text-sm cursor-pointer"
              >
                售后订单 ({{ ecomAfterSalesOrders.length }})
              </button>
            </div>

            <!-- Stats -->
            <div class="flex items-center gap-4 text-xs text-gray-500">
              <span>跳过（无效/重复）: {{ ecomSkippedCount }} 条</span>
              <span>已选销售金额: ¥{{ ecomSelectedSalesTotal }}</span>
              <span>已选退款金额: ¥{{ ecomSelectedRefundTotal }}</span>
            </div>

            <!-- Sales Preview Table -->
            <div v-if="ecomActiveTab === 'sales'" class="border border-gray-200 rounded-lg overflow-hidden">
              <div class="overflow-x-auto max-h-[45vh] overflow-y-auto">
                <table class="w-full text-xs">
                  <thead class="sticky top-0 z-10">
                    <tr class="bg-gray-50 text-gray-600">
                      <th class="px-2 py-2 text-center w-8"><input type="checkbox" :checked="isAllEcomSalesSelected" @change="toggleEcomSalesAll" class="rounded cursor-pointer"></th>
                      <th class="px-2 py-2 text-left font-medium">行号</th>
                      <th class="px-2 py-2 text-center font-medium">平台</th>
                      <th class="px-2 py-2 text-left font-medium">店铺</th>
                      <th class="px-2 py-2 text-left font-medium">外部订单号</th>
                      <th class="px-2 py-2 text-left font-medium">SKU编码</th>
                      <th class="px-2 py-2 text-right font-medium">金额</th>
                      <th class="px-2 py-2 text-left font-medium">状态</th>
                      <th class="px-2 py-2 text-left font-medium">时间</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="order in ecomSalesOrders" :key="'s-' + order._rowIdx" class="border-t border-gray-100 hover:bg-green-50/30" :class="{ 'opacity-40': !order._selected }">
                      <td class="px-2 py-1.5 text-center"><input type="checkbox" v-model="order._selected" class="rounded cursor-pointer"></td>
                      <td class="px-2 py-1.5 text-gray-500">{{ order._rowIdx }}</td>
                      <td class="px-2 py-1.5 text-center">
                        <span class="px-1.5 py-0.5 rounded text-[10px]" :class="ecomPlatformTagClass(order.platform_type)">{{ platformTypeName(order.platform_type) }}</span>
                      </td>
                      <td class="px-2 py-1.5 text-gray-800">{{ order.platform_store || '—' }}</td>
                      <td class="px-2 py-1.5 text-gray-600 font-mono max-w-[140px] truncate" :title="order.external_order_no">{{ order.external_order_no || '—' }}</td>
                      <td class="px-2 py-1.5 text-gray-600 font-mono text-[10px]">{{ order.sku_code || '—' }}</td>
                      <td class="px-2 py-1.5 text-right text-green-600 font-medium">{{ formatMoney(order.payment_amount) }}</td>
                      <td class="px-2 py-1.5">
                        <span class="px-1.5 py-0.5 rounded text-[10px]" :class="order.status === '已关闭' || order.status === '交易关闭' || order.status === '已取消' ? 'bg-gray-100 text-gray-500' : 'bg-green-50 text-green-600'">{{ order.status }}</span>
                      </td>
                      <td class="px-2 py-1.5 text-gray-500 max-w-[120px] truncate" :title="order.order_time">{{ order.order_time || '—' }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <!-- After Sales Preview Table -->
            <div v-if="ecomActiveTab === 'aftersales'" class="border border-gray-200 rounded-lg overflow-hidden">
              <div class="overflow-x-auto max-h-[45vh] overflow-y-auto">
                <table class="w-full text-xs">
                  <thead class="sticky top-0 z-10">
                    <tr class="bg-gray-50 text-gray-600">
                      <th class="px-2 py-2 text-center w-8"><input type="checkbox" :checked="isAllEcomAfterSalesSelected" @change="toggleEcomAfterSalesAll" class="rounded cursor-pointer"></th>
                      <th class="px-2 py-2 text-left font-medium">行号</th>
                      <th class="px-2 py-2 text-center font-medium">平台</th>
                      <th class="px-2 py-2 text-left font-medium">店铺</th>
                      <th class="px-2 py-2 text-left font-medium">售后单号</th>
                      <th class="px-2 py-2 text-left font-medium">关联订单号</th>
                      <th class="px-2 py-2 text-right font-medium">退款金额</th>
                      <th class="px-2 py-2 text-left font-medium">售后状态</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="refund in ecomAfterSalesOrders" :key="'a-' + refund._rowIdx" class="border-t border-gray-100 hover:bg-orange-50/30" :class="{ 'opacity-40': !refund._selected }">
                      <td class="px-2 py-1.5 text-center"><input type="checkbox" v-model="refund._selected" class="rounded cursor-pointer"></td>
                      <td class="px-2 py-1.5 text-gray-500">{{ refund._rowIdx }}</td>
                      <td class="px-2 py-1.5 text-center">
                        <span class="px-1.5 py-0.5 rounded text-[10px]" :class="ecomPlatformTagClass(refund.platform_type)">{{ platformTypeName(refund.platform_type) }}</span>
                      </td>
                      <td class="px-2 py-1.5 text-gray-800">{{ refund.platform_store || '—' }}</td>
                      <td class="px-2 py-1.5 text-gray-600 font-mono max-w-[140px] truncate" :title="refund.refund_no">{{ refund.refund_no || '—' }}</td>
                      <td class="px-2 py-1.5 text-gray-600 font-mono max-w-[140px] truncate" :title="refund.external_order_no">{{ refund.external_order_no || '—' }}</td>
                      <td class="px-2 py-1.5 text-right text-red-500 font-medium">-{{ formatMoney(refund.refund_amount) }}</td>
                      <td class="px-2 py-1.5">
                        <span class="px-1.5 py-0.5 rounded text-[10px] bg-orange-50 text-orange-600">{{ refund.status }}</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div class="flex gap-3 pt-2">
              <button @click="ecomImportStep = 'upload'; resetEcomImport()" class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">← 重新上传</button>
              <button @click="showEcommerceImportModal = false; resetEcomImport()" class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
              <button
                @click="handleEcomImport"
                :disabled="selectedEcomCount === 0 || ecomImporting"
                class="flex-1 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition"
              >
                {{ ecomImporting ? '⏳ 导入中...' : `✅ 确认导入 ${selectedEcomCount} 条` }}
              </button>
            </div>
          </div>

          <!-- Step 3: Result -->
          <div v-if="ecomImportStep === 'result'" class="space-y-4">
            <div class="text-center py-4">
              <div class="text-4xl mb-3">🎉</div>
              <h3 class="text-lg font-bold text-gray-800 mb-2">导入完成</h3>
              <div class="flex items-center justify-center gap-6">
                <div class="text-center">
                  <div class="text-2xl font-bold text-green-600">{{ ecomImportResult.success }}</div>
                  <div class="text-xs text-gray-500">成功</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-bold text-yellow-500">{{ ecomImportResult.duplicate }}</div>
                  <div class="text-xs text-gray-500">跳过（重复）</div>
                </div>
                <div v-if="ecomImportResult.failures.length > 0" class="text-center">
                  <div class="text-2xl font-bold text-red-500">{{ ecomImportResult.failures.length }}</div>
                  <div class="text-xs text-gray-500">失败</div>
                </div>
              </div>
            </div>
            <div v-if="ecomImportResult.failures.length > 0" class="bg-red-50 border border-red-100 rounded-lg p-3">
              <div class="text-xs font-medium text-red-600 mb-2">失败的记录：</div>
              <div class="space-y-1 max-h-32 overflow-y-auto">
                <div v-for="(fail, idx) in ecomImportResult.failures" :key="idx" class="text-xs text-red-500">
                  第 {{ fail.row }} 行：{{ fail.external_order_no || fail.refund_no || '' }} — {{ fail.message }}
                </div>
              </div>
            </div>
            <div class="flex justify-center pt-2">
              <button @click="showEcommerceImportModal = false; resetEcomImport()" class="px-6 py-2.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer transition">完成</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useEcommerceImport } from '../composables/useEcommerceImport'
import { formatMoney } from '../lib/utils'

const props = defineProps({
  loadOrders: { type: Function, required: true },
  loadStats: { type: Function, required: true },
  loadTodayOrdersData: { type: Function, required: true },
})

const emit = defineEmits(['open-ecommerce-import'])

function handleOpen() {
  emit('open-ecommerce-import')
  openEcommerceImportModal()
}

const {
  platformTypeName,
  showEcommerceImportModal,
  ecomImportStep,
  ecomPlatformMode,
  ecomImporting,
  ecomImportError,
  isEcomDragging,
  ecomSalesOrders,
  ecomAfterSalesOrders,
  ecomSkippedCount,
  ecomActiveTab,
  ecomImportResult,
  ecomAllOrders,
  selectedEcomCount,
  isAllEcomSelected,
  isAllEcomSalesSelected,
  isAllEcomAfterSalesSelected,
  ecomSelectedSalesTotal,
  ecomSelectedRefundTotal,
  ecomPlatformTagClass,
  resetEcomImport,
  openEcommerceImportModal,
  toggleAllEcomSelection,
  toggleEcomSalesAll,
  toggleEcomAfterSalesAll,
  handleEcomFileSelect,
  handleEcomFileDrop,
  handleEcomImport,
} = useEcommerceImport({
  loadOrders: props.loadOrders,
  loadStats: props.loadStats,
  loadTodayOrdersData: props.loadTodayOrdersData,
})

defineExpose({ openEcommerceImportModal })
</script>
