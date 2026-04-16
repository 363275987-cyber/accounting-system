<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-lg md:text-xl font-bold text-gray-800">📦 产品订货</h1>
        <p class="text-xs text-gray-500 mt-0.5">向厂商下单采购，跟踪到货进度</p>
      </div>
      <button @click="openCreateModal" class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 cursor-pointer">+ 新建采购单</button>
    </div>

    <!-- Tab: 采购单列表 / 库存预警 -->
    <div class="flex gap-4 mb-4">
      <button @click="activeTab = 'orders'" :class="activeTab === 'orders' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-500'" class="pb-1 text-sm font-medium cursor-pointer">采购单列表</button>
      <button @click="activeTab = 'forecast'" :class="activeTab === 'forecast' ? 'text-blue-600 border-b-2 border-blue-600' : 'text-gray-500'" class="pb-1 text-sm font-medium cursor-pointer">库存消耗预警</button>
    </div>

    <!-- 采购单列表 -->
    <div v-if="activeTab === 'orders'">
      <!-- 筛选 -->
      <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
        <input v-model="search" @input="debouncedLoad" placeholder="搜索单号/供应商..."
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-56 outline-none focus:ring-2 focus:ring-blue-500">
        <select v-model="statusFilter" @change="loadData" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
          <option value="">全部状态</option>
          <option value="pending">待确认</option>
          <option value="confirmed">已确认</option>
          <option value="shipped">已发货</option>
          <option value="partially_arrived">部分到货</option>
          <option value="arrived">已到货</option>
          <option value="cancelled">已取消</option>
        </select>
        <span class="text-sm text-gray-500 ml-auto">共 {{ orders.length }} 个采购单</span>
      </div>

      <!-- 汇总卡片 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500">待确认</div>
          <div class="text-2xl font-bold text-orange-500">{{ summaryCounts.pending }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500">在途（已确认/已发货）</div>
          <div class="text-2xl font-bold text-blue-600">{{ summaryCounts.inTransit }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500">预付定金合计</div>
          <div class="text-2xl font-bold text-purple-600">¥{{ summaryTotal.deposit.toLocaleString() }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="text-xs text-gray-500">采购总金额</div>
          <div class="text-2xl font-bold text-green-600">¥{{ summaryTotal.amount.toLocaleString() }}</div>
        </div>
      </div>

      <!-- 列表 -->
      <div v-if="loading" class="bg-white rounded-xl p-16 text-center text-gray-500">加载中...</div>
      <div v-else class="space-y-3">
        <div v-for="o in orders" :key="o.id" @click="openDetail(o.id)"
          class="bg-white rounded-xl border border-gray-100 p-4 hover:shadow-md cursor-pointer transition">
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-3">
              <span class="font-mono text-sm font-medium text-gray-800">{{ o.order_no }}</span>
              <span class="text-xs px-2 py-0.5 rounded-full" :class="statusClass(o.status)">{{ statusLabel(o.status) }}</span>
            </div>
            <span class="text-xs text-gray-500">{{ formatDate(o.created_at) }}</span>
          </div>
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-600">🏭 {{ o.supplier_name }}</span>
            <span class="font-medium text-blue-600">¥{{ Number(o.total_amount).toLocaleString() }}</span>
          </div>
          <div class="flex items-center gap-4 text-xs text-gray-500 mt-2">
            <span>{{ o.item_count }} 种产品 · {{ o.total_quantity }} 只</span>
            <span v-if="o.arrived_quantity > 0">已到货 {{ o.arrived_quantity }} 只</span>
            <span v-if="o.deposit_amount > 0">定金 ¥{{ Number(o.deposit_amount).toLocaleString() }}</span>
            <span v-if="o.expected_arrival_date">预计 {{ o.expected_arrival_date }}</span>
          </div>
          <div v-if="o.contract_no" class="text-xs text-gray-500 mt-1">合同号：{{ o.contract_no }}</div>
        </div>
        <div v-if="!loading && orders.length === 0" class="bg-white rounded-xl p-16 text-center text-gray-500">暂无采购单</div>
      </div>
    </div>

    <!-- 库存消耗预警 -->
    <div v-if="activeTab === 'forecast'">
      <div v-if="forecastLoading" class="bg-white rounded-xl p-16 text-center text-gray-500">加载中...</div>
      <div v-else class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-600">
              <th class="px-4 py-3 text-left">产品名称</th>
              <th class="px-4 py-3 text-right">30天销量</th>
              <th class="px-4 py-3 text-right">60天销量</th>
              <th class="px-4 py-3 text-right">日均消耗</th>
              <th class="px-4 py-3 text-right">当前库存</th>
              <th class="px-4 py-3 text-right">可售天数</th>
              <th class="px-4 py-3 text-right">在途数量</th>
              <th class="px-4 py-3 text-center">状态</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in forecasts" :key="p.product_id"
              class="border-t border-gray-50" :class="{ 'bg-red-50/50': p.low_stock }">
              <td class="px-4 py-3 text-gray-800 font-medium">{{ p.product_name }}</td>
              <td class="px-4 py-3 text-right">{{ p.sold_30d }}</td>
              <td class="px-4 py-3 text-right">{{ p.sold_60d }}</td>
              <td class="px-4 py-3 text-right text-blue-600">{{ p.daily_avg }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ p.current_stock }}</td>
              <td class="px-4 py-3 text-right font-bold" :class="p.days_remaining <= 15 ? 'text-red-600' : p.days_remaining <= 30 ? 'text-amber-600' : 'text-green-600'">
                {{ p.days_remaining >= 999 ? '∞' : p.days_remaining + '天' }}
              </td>
              <td class="px-4 py-3 text-right text-blue-500">{{ p.in_transit }}</td>
              <td class="px-4 py-3 text-center">
                <span v-if="p.low_stock" class="px-2 py-0.5 rounded-full text-xs bg-red-100 text-red-600 font-medium">⚠️ 库存不足</span>
                <span v-else-if="p.days_remaining <= 30" class="px-2 py-0.5 rounded-full text-xs bg-amber-50 text-amber-600">偏低</span>
                <span v-else class="px-2 py-0.5 rounded-full text-xs bg-green-50 text-green-600">充足</span>
              </td>
            </tr>
            <tr v-if="forecasts.length === 0">
              <td colspan="8" class="px-4 py-16 text-center text-gray-500">暂无数据（仅统计球杆类产品）</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 新建采购单弹窗 -->
    <div v-if="showCreateModal" class="fixed inset-0 z-50 flex items-center justify-center p-4" @click.self="showCreateModal = false">
      <div class="absolute inset-0 bg-black/30"></div>
      <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6">
        <h3 class="text-lg font-bold text-gray-800 mb-4">新建采购单</h3>

        <div class="space-y-4">
          <!-- 供应商 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">供应商 <span class="text-red-400">*</span></label>
            <div class="flex gap-2">
              <select v-model="form.supplier_id" @change="onSupplierChange"
                class="flex-1 px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
                <option value="">选择供应商</option>
                <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
              <button type="button" @click="showSupplierModal = true" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm hover:bg-gray-200 cursor-pointer">+ 新增</button>
            </div>
            <input v-if="!form.supplier_id" v-model="form.supplier_name" placeholder="或直接输入供应商名称"
              class="w-full mt-2 px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>

          <!-- 合同信息 -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">合同编号</label>
              <input v-model="form.contract_no" placeholder="合同编号"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">预计到货日期</label>
              <input v-model="form.expected_arrival_date" type="date"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
          </div>

          <!-- 金额 -->
          <div class="grid grid-cols-3 gap-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">预付定金</label>
              <input v-model.number="form.deposit_amount" type="number" min="0" step="0.01" placeholder="0.00"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">尾款金额</label>
              <div class="w-full px-3 py-2.5 border border-gray-100 rounded-lg text-sm text-gray-500 bg-gray-50">
                ¥{{ (formComputedTotal - (form.deposit_amount || 0)).toLocaleString() }}
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">尾款支付时间</label>
              <input v-model="form.balance_due_date" type="date"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">总金额（自动计算）</label>
            <div class="px-3 py-2.5 border border-gray-100 rounded-lg text-sm font-bold text-blue-600 bg-blue-50">
              ¥{{ formComputedTotal.toLocaleString() }}
            </div>
          </div>

          <!-- 合同备注 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">合同备注</label>
            <textarea v-model="form.contract_note" rows="2" placeholder="合同条款、付款条件等"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>

          <!-- 产品明细 -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="text-sm font-medium text-gray-700">产品明细 <span class="text-red-400">*</span></label>
              <button type="button" @click="addItem" class="text-xs text-blue-600 hover:text-blue-800 cursor-pointer">+ 添加产品</button>
            </div>
            <div class="space-y-2">
              <div v-for="(item, idx) in form.items" :key="idx" class="bg-gray-50 rounded-lg p-3">
                <div class="flex gap-2 items-center">
                  <!-- 产品选择：可搜索产品库或直接输入 -->
                  <div class="flex-1 relative">
                    <input v-model="item.product_name" @focus="openProductDropdown(idx)" @blur="closeProductDropdown(idx)"
                      placeholder="选择或输入产品名称" class="w-full px-2 py-1.5 border border-gray-200 rounded text-sm outline-none focus:ring-2 focus:ring-blue-500">
                    <!-- 产品下拉 -->
                    <div v-if="activeProductDropdown === idx && productDropdownVisible"
                      class="absolute z-50 bottom-full mb-1 left-0 right-0 bg-white border border-gray-200 rounded-lg shadow-xl max-h-48 overflow-y-auto">
                      <input v-model="productSearch" @mousedown.stop placeholder="搜索产品..."
                        class="sticky top-0 w-full px-2 py-1.5 border-b border-gray-100 text-xs outline-none bg-gray-50 rounded-t-lg">
                      <div v-for="p in filteredProducts" :key="p.id"
                        @mousedown.prevent="selectProduct(idx, p)"
                        class="px-3 py-2 hover:bg-blue-50 cursor-pointer text-sm border-b border-gray-50 last:border-0">
                        <div class="text-gray-800">{{ p.name }}</div>
                        <div class="text-xs text-gray-500">成本价 ¥{{ p.cost_price || 0 }} · {{ p.category || '' }} {{ p.brand ? '· ' + p.brand : '' }}</div>
                      </div>
                      <div v-if="filteredProducts.length === 0" class="text-center py-3 text-gray-500 text-xs">未找到，直接输入即可创建新产品</div>
                    </div>
                  </div>
                  <input v-model.number="item.quantity" type="number" min="1" placeholder="数量" class="w-16 px-2 py-1.5 border border-gray-200 rounded text-sm text-center outline-none">
                  <input v-model.number="item.unit_cost" type="number" min="0" step="0.01" placeholder="成本单价" class="w-24 px-2 py-1.5 border border-gray-200 rounded text-sm outline-none">
                  <span class="text-xs text-gray-500 w-20 text-right">¥{{ (item.quantity * item.unit_cost).toLocaleString() }}</span>
                  <button type="button" @click="form.items.splice(idx, 1)" class="text-red-400 hover:text-red-600 cursor-pointer">✕</button>
                </div>
                <!-- 新产品时显示分类和品牌 -->
                <div v-if="!item.product_id && item.product_name.trim()" class="flex gap-2 mt-2">
                  <select v-model="item.category" class="px-2 py-1 border border-gray-200 rounded text-xs outline-none cursor-pointer">
                    <option value="">选择分类</option>
                    <option v-for="(label, key) in PRODUCT_ITEM_CATEGORIES" :key="key" :value="key">{{ label }}</option>
                  </select>
                  <input v-model="item.brand" placeholder="品牌" class="flex-1 px-2 py-1 border border-gray-200 rounded text-xs outline-none">
                  <span class="text-xs text-orange-500 self-center">新产品将自动录入产品库</span>
                </div>
              </div>
              <div v-if="form.items.length === 0" class="text-center py-4 text-gray-500 text-sm">请添加产品</div>
            </div>
            <div v-if="form.items.length > 0" class="flex justify-between text-sm text-gray-500 mt-2 px-1">
              <span>合计 {{ form.items.reduce((s, i) => s + i.quantity, 0) }} 只</span>
              <span class="font-medium text-gray-800">¥{{ formComputedTotal.toLocaleString() }}</span>
            </div>
          </div>

          <!-- 备注 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" placeholder="其他备注"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
        </div>

        <div class="flex justify-end gap-2 mt-5">
          <button @click="showCreateModal = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
          <button @click="handleSubmit" :disabled="submitting" class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 disabled:opacity-40 cursor-pointer">
            {{ submitting ? '提交中...' : '创建采购单' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 新增供应商弹窗 -->
    <div v-if="showSupplierModal" class="fixed inset-0 z-[60] flex items-center justify-center p-4" @click.self="showSupplierModal = false">
      <div class="absolute inset-0 bg-black/30"></div>
      <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
        <h3 class="text-lg font-bold text-gray-800 mb-4">新增供应商</h3>
        <div class="space-y-3">
          <input v-model="newSupplier.name" placeholder="供应商名称 *"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          <input v-model="newSupplier.contact_person" placeholder="联系人"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          <input v-model="newSupplier.phone" placeholder="电话"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          <input v-model="newSupplier.wechat" placeholder="微信"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button @click="showSupplierModal = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
          <button @click="addSupplier" :disabled="addingSupplier" class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">{{ addingSupplier ? '保存中...' : '保存' }}</button>
        </div>
      </div>
    </div>

    <!-- 采购单详情弹窗 -->
    <div v-if="showDetailModal" class="fixed inset-0 z-50 flex justify-end" @click.self="showDetailModal = false">
      <div class="absolute inset-0 bg-black/30"></div>
      <div class="relative bg-white w-full max-w-lg h-full overflow-y-auto shadow-xl">
        <div class="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between">
          <h3 class="text-lg font-bold text-gray-800">采购单详情</h3>
          <button @click="showDetailModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <div v-if="detailData" class="p-6 space-y-6">
          <!-- 基本信息 -->
          <div>
            <h4 class="text-sm font-semibold text-gray-500 mb-3">基本信息</h4>
            <div class="bg-gray-50 rounded-xl p-4 space-y-2 text-sm">
              <div class="flex justify-between"><span class="text-gray-500">采购单号</span><span class="font-mono">{{ detailData.order.order_no }}</span></div>
              <div class="flex justify-between"><span class="text-gray-500">供应商</span><span>{{ detailData.order.supplier_name }}</span></div>
              <div class="flex justify-between"><span class="text-gray-500">状态</span>
                <select v-model="detailData.order.status" @change="updatePOStatus" class="px-2 py-1 border rounded text-xs outline-none cursor-pointer">
                  <option value="pending">待确认</option>
                  <option value="confirmed">已确认</option>
                  <option value="shipped">已发货</option>
                  <option value="partially_arrived">部分到货</option>
                  <option value="arrived">已到货</option>
                  <option value="cancelled">已取消</option>
                </select>
              </div>
              <div class="flex justify-between"><span class="text-gray-500">总金额</span><span class="font-bold text-blue-600">¥{{ Number(detailData.order.total_amount).toLocaleString() }}</span></div>
              <div class="flex justify-between"><span class="text-gray-500">预付定金</span><span>¥{{ Number(detailData.order.deposit_amount).toLocaleString() }}</span></div>
              <div class="flex justify-between"><span class="text-gray-500">尾款</span><span>¥{{ (Number(detailData.order.total_amount) - Number(detailData.order.deposit_amount)).toLocaleString() }}</span></div>
              <div v-if="detailData.order.balance_due_date" class="flex justify-between"><span class="text-gray-500">尾款支付时间</span><span>{{ detailData.order.balance_due_date }}</span></div>
              <div v-if="detailData.order.contract_no" class="flex justify-between"><span class="text-gray-500">合同编号</span><span>{{ detailData.order.contract_no }}</span></div>
              <div v-if="detailData.order.expected_arrival_date" class="flex justify-between"><span class="text-gray-500">预计到货</span><span>{{ detailData.order.expected_arrival_date }}</span></div>
              <div v-if="detailData.order.actual_arrival_date" class="flex justify-between"><span class="text-gray-500">实际到货</span><span>{{ detailData.order.actual_arrival_date }}</span></div>
              <div v-if="detailData.order.contract_note" class="text-sm"><span class="text-gray-500">合同备注：</span>{{ detailData.order.contract_note }}</div>
              <div v-if="detailData.order.note" class="text-sm"><span class="text-gray-500">备注：</span>{{ detailData.order.note }}</div>
            </div>
          </div>

          <!-- 产品明细 -->
          <div>
            <h4 class="text-sm font-semibold text-gray-500 mb-3">产品明细</h4>
            <div class="space-y-2">
              <div v-for="item in detailData.items" :key="item.id" class="bg-gray-50 rounded-lg p-3">
                <div class="flex items-center justify-between text-sm">
                  <span class="font-medium text-gray-800">{{ item.product_name }}</span>
                  <span class="text-blue-600">¥{{ Number(item.subtotal).toLocaleString() }}</span>
                </div>
                <div class="flex items-center gap-4 text-xs text-gray-500 mt-1">
                  <span>订购 {{ item.quantity }} 只</span>
                  <span>单价 ¥{{ Number(item.unit_cost).toLocaleString() }}</span>
                </div>
                <div v-if="detailData.order.status !== 'cancelled'" class="mt-2">
                  <label class="text-xs text-gray-500">已到货数量</label>
                  <div class="flex items-center gap-2 mt-1">
                    <input type="number" v-model.number="item.arrived_quantity" min="0" :max="item.quantity"
                      @change="updateArrived(item)" class="w-20 px-2 py-1 border rounded text-sm text-center outline-none">
                    <span class="text-xs text-gray-500">/ {{ item.quantity }}</span>
                    <div class="flex-1 bg-gray-200 rounded-full h-2">
                      <div class="bg-green-500 h-full rounded-full transition-all"
                        :style="{ width: (item.quantity > 0 ? (item.arrived_quantity / item.quantity * 100) : 0) + '%' }"></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="p-6 text-center text-gray-500">加载中...</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue'
import { supabase } from '../lib/supabase'
import { toast, PRODUCT_ITEM_CATEGORIES } from '../lib/utils'

const loading = ref(false)
const forecastLoading = ref(false)
const submitting = ref(false)
const search = ref('')
const statusFilter = ref('')
const activeTab = ref('orders')
const orders = ref([])
const suppliers = ref([])
const forecasts = ref([])
const showCreateModal = ref(false)
const showSupplierModal = ref(false)
const addingSupplier = ref(false)
const showDetailModal = ref(false)
const detailData = ref(null)

const form = reactive({
  supplier_id: '',
  supplier_name: '',
  contract_no: '',
  expected_arrival_date: '',
  deposit_amount: 0,
  balance_due_date: '',
  total_amount: 0,
  contract_note: '',
  note: '',
  items: [],
})

const newSupplier = reactive({ name: '', contact_person: '', phone: '', wechat: '' })
const allProducts = ref([])
const activeProductDropdown = ref(-1)
const productDropdownVisible = ref(false)
const productSearch = ref('')

const STATUS_MAP = {
  pending: { label: '待确认', cls: 'bg-orange-50 text-orange-600' },
  confirmed: { label: '已确认', cls: 'bg-blue-50 text-blue-600' },
  shipped: { label: '已发货', cls: 'bg-indigo-50 text-indigo-600' },
  partially_arrived: { label: '部分到货', cls: 'bg-amber-50 text-amber-600' },
  arrived: { label: '已到货', cls: 'bg-green-50 text-green-600' },
  cancelled: { label: '已取消', cls: 'bg-gray-100 text-gray-500' },
}

function statusLabel(s) { return STATUS_MAP[s]?.label || s }
function statusClass(s) { return STATUS_MAP[s]?.cls || 'bg-gray-100 text-gray-500' }

function formatDate(d) {
  if (!d) return '-'
  const dt = new Date(d)
  return `${dt.getMonth()+1}/${dt.getDate()} ${String(dt.getHours()).padStart(2,'0')}:${String(dt.getMinutes()).padStart(2,'0')}`
}

const summaryCounts = computed(() => {
  const c = { pending: 0, inTransit: 0 }
  orders.value.forEach(o => {
    if (o.status === 'pending') c.pending++
    if (['confirmed', 'shipped', 'partially_arrived'].includes(o.status)) c.inTransit++
  })
  return c
})

const summaryTotal = computed(() => {
  const t = { deposit: 0, amount: 0 }
  orders.value.forEach(o => {
    t.deposit += Number(o.deposit_amount) || 0
    t.amount += Number(o.total_amount) || 0
  })
  return t
})

const formComputedTotal = computed(() => form.items.reduce((s, i) => s + (i.quantity || 0) * (i.unit_cost || 0), 0))

const filteredProducts = computed(() => {
  if (!productSearch.value) return allProducts.value.slice(0, 30)
  const kw = productSearch.value.toLowerCase()
  return allProducts.value.filter(p => (p.name || '').toLowerCase().includes(kw)).slice(0, 30)
})

let searchTimer = null
function debouncedLoad() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(loadData, 300)
}

async function loadSuppliers() {
  const { data } = await supabase.from('suppliers').select('*').order('name')
  suppliers.value = data || []
}

async function loadData() {
  loading.value = true
  try {
    const { data, error } = await supabase.rpc('get_purchase_orders', {
      p_status: statusFilter.value || null,
      p_search: search.value || null,
      p_limit: 200,
    })
    if (!error) orders.value = data || []
  } catch (e) { console.error(e) }
  finally { loading.value = false }
}

async function loadForecast() {
  forecastLoading.value = true
  try {
    const { data, error } = await supabase.rpc('get_product_consumption')
    if (!error) forecasts.value = data || []
  } catch (e) { console.error(e) }
  finally { forecastLoading.value = false }
}

function onSupplierChange() {
  const s = suppliers.value.find(s => s.id === form.supplier_id)
  if (s) form.supplier_name = s.name
}

function addItem() {
  form.items.push({ product_name: '', product_id: null, quantity: 1, unit_cost: 0, category: '', brand: '' })
}

function openProductDropdown(idx) {
  activeProductDropdown.value = idx
  productDropdownVisible.value = true
  productSearch.value = ''
  loadProducts()
}

function closeProductDropdown(idx) {
  setTimeout(() => {
    if (activeProductDropdown.value === idx) {
      activeProductDropdown.value = -1
      productDropdownVisible.value = false
    }
  }, 200)
}

function selectProduct(idx, p) {
  form.items[idx].product_name = p.name
  form.items[idx].product_id = p.id
  form.items[idx].unit_cost = Number(p.cost_price) || 0
  form.items[idx].category = p.category || ''
  form.items[idx].brand = p.brand || ''
  activeProductDropdown.value = -1
  productDropdownVisible.value = false
}

async function loadProducts() {
  if (allProducts.value.length > 0) return
  const { data } = await supabase.from('products').select('id, name, cost_price, category, brand').order('name').limit(200)
  allProducts.value = data || []
}

function openCreateModal() {
  Object.assign(form, {
    supplier_id: '', supplier_name: '', contract_no: '', expected_arrival_date: '',
    deposit_amount: 0, balance_due_date: '', total_amount: 0, contract_note: '', note: '',
    items: [],
  })
  showCreateModal.value = true
}

async function addSupplier() {
  if (!newSupplier.name.trim()) return
  if (addingSupplier.value) return
  addingSupplier.value = true
  try {
    const { data, error } = await supabase.from('suppliers').insert({
      name: newSupplier.name.trim(),
      contact_person: newSupplier.contact_person.trim() || null,
      phone: newSupplier.phone.trim() || null,
      wechat: newSupplier.wechat.trim() || null,
    }).select().single()
    if (error) return toast('添加供应商失败', 'error')
    suppliers.value.push(data)
    form.supplier_id = data.id
    form.supplier_name = data.name
    Object.assign(newSupplier, { name: '', contact_person: '', phone: '', wechat: '' })
    showSupplierModal.value = false
    toast('供应商已添加', 'success')
  } finally {
    addingSupplier.value = false
  }
}

async function handleSubmit() {
  const supplierName = form.supplier_name.trim()
  if (!supplierName) return toast('请选择或输入供应商', 'error')
  const validItems = form.items.filter(i => i.product_name.trim() && i.quantity > 0)
  if (validItems.length === 0) return toast('请添加至少一个产品', 'error')

  submitting.value = true
  try {
    // 生成单号
    const { data: noData } = await supabase.rpc('generate_po_no')
    const orderNo = noData || ('PO-' + Date.now())

    const totalAmount = formComputedTotal.value

    // 自动创建产品库中没有的新产品
    for (const item of validItems) {
      if (!item.product_id && item.product_name.trim()) {
        // 检查产品库是否已存在同名产品
        const { data: existing } = await supabase.from('products').select('id').ilike('name', item.product_name.trim()).limit(1)
        if (!existing || existing.length === 0) {
          const { data: newProd } = await supabase.from('products').insert({
            name: item.product_name.trim(),
            cost_price: item.unit_cost || 0,
            category: item.category || null,
            brand: item.brand || null,
            price_status: 'pending',
          }).select('id').single()
          if (newProd) item.product_id = newProd.id
        } else {
          item.product_id = existing[0].id
        }
      }
    }

    // 插入主表
    const { data: po, error: poErr } = await supabase.from('purchase_orders').insert({
      order_no: orderNo,
      supplier_id: form.supplier_id || null,
      supplier_name: supplierName,
      status: 'pending',
      total_amount: totalAmount,
      deposit_amount: form.deposit_amount || 0,
      contract_no: form.contract_no || null,
      contract_note: form.contract_note || null,
      expected_arrival_date: form.expected_arrival_date || null,
      balance_due_date: form.balance_due_date || null,
      note: form.note || null,
    }).select().single()

    if (poErr) throw poErr

    // 插入明细
    const items = validItems.map(i => ({
      purchase_order_id: po.id,
      product_id: i.product_id || null,
      product_name: i.product_name.trim(),
      category: i.category || null,
      quantity: i.quantity,
      unit_cost: i.unit_cost,
    }))
    const { error: itemErr } = await supabase.from('purchase_order_items').insert(items)
    if (itemErr) throw itemErr

    showCreateModal.value = false
    toast('采购单已创建：' + orderNo, 'success')
    loadData()
  } catch (e) {
    toast('创建失败：' + (e.message || ''), 'error')
  } finally {
    submitting.value = false
  }
}

async function openDetail(poId) {
  detailData.value = null
  showDetailModal.value = true
  try {
    const { data, error } = await supabase.rpc('get_purchase_order_detail', { p_po_id: poId })
    if (!error) detailData.value = data
  } catch (e) { console.error(e) }
}

async function updatePOStatus() {
  if (!detailData.value) return
  const { error } = await supabase.from('purchase_orders').update({
    status: detailData.value.order.status,
    updated_at: new Date().toISOString(),
  }).eq('id', detailData.value.order.id)
  if (!error) {
    toast('状态已更新', 'success')
    loadData()
    // 全部到货自动填实际到货日期
    if (detailData.value.order.status === 'arrived') {
      await supabase.from('purchase_orders').update({ actual_arrival_date: new Date().toISOString().split('T')[0] }).eq('id', detailData.value.order.id)
    }
  }
}

async function updateArrived(item) {
  const { error } = await supabase.from('purchase_order_items').update({
    arrived_quantity: item.arrived_quantity,
  }).eq('id', item.id)
  if (!error) loadData()
}

async function openEditDeposit() {
  // 用 prompt 简单处理
  const current = detailData.value?.order.deposit_paid || 0
  const val = prompt('已付定金金额：', current)
  if (val === null) return
  const num = parseFloat(val)
  if (isNaN(num) || num < 0) return toast('请输入有效金额', 'error')
  await supabase.from('purchase_orders').update({ deposit_paid: num }).eq('id', detailData.value.order.id)
  detailData.value.order.deposit_paid = num
  loadData()
}

onMounted(() => {
  loadSuppliers()
  loadData()
  loadForecast()
})
</script>
