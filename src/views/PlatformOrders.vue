<template>
  <div>
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
      <div>
        <h2 class="text-lg font-semibold text-gray-800">外部订单</h2>
        <p class="text-xs text-gray-500 mt-0.5">来自各平台的订单数据</p>
      </div>
      <div class="flex items-center gap-2">
        <button @click="syncAll" :disabled="syncing" class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 transition cursor-pointer">
          {{ syncing ? '同步中...' : '🔄 手动同步' }}
        </button>
        <select v-model="filterPlatform" class="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white cursor-pointer">
          <option value="">全部平台</option>
          <option value="douyin">抖店</option>
          <option value="kuaishou">快手</option>
          <option value="wechat_video">视频号</option>
          <option value="jushuitan">聚水潭</option>
        </select>
        <select v-model="filterSyncStatus" class="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white cursor-pointer">
          <option value="">全部状态</option>
          <option value="pending">待同步</option>
          <option value="synced">已同步</option>
          <option value="failed">同步失败</option>
        </select>
      </div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-5">
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1">总订单</div>
        <div class="text-xl font-bold text-gray-800">{{ stats.total }}</div>
      </div>
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1">已同步</div>
        <div class="text-xl font-bold text-green-600">{{ stats.synced }}</div>
      </div>
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1">待同步</div>
        <div class="text-xl font-bold text-orange-500">{{ stats.pending }}</div>
      </div>
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="text-xs text-gray-500 mb-1">总金额</div>
        <div class="text-xl font-bold text-blue-600">{{ formatMoney(stats.totalAmount) }}</div>
      </div>
    </div>

    <!-- Desktop Table -->
    <div class="hidden md:block bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-100 bg-gray-50/50">
            <th class="px-4 py-3 text-left font-medium text-gray-500">平台</th>
            <th class="px-4 py-3 text-left font-medium text-gray-500">外部订单号</th>
            <th class="px-4 py-3 text-left font-medium text-gray-500">客户</th>
            <th class="px-4 py-3 text-left font-medium text-gray-500">商品</th>
            <th class="px-4 py-3 text-right font-medium text-gray-500">金额</th>
            <th class="px-4 py-3 text-left font-medium text-gray-500">状态</th>
            <th class="px-4 py-3 text-left font-medium text-gray-500">同步</th>
            <th class="px-4 py-3 text-center font-medium text-gray-500">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading" class="border-b border-gray-50"><td colspan="8" class="px-4 py-8 text-center text-gray-500">加载中...</td></tr>
          <tr v-else-if="orders.length === 0" class="border-b border-gray-50"><td colspan="8" class="px-4 py-8 text-center text-gray-500">暂无外部订单数据</td></tr>
          <tr v-for="order in orders" :key="order.id" class="border-b border-gray-50 hover:bg-gray-50/50 transition">
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded-full" :class="platformClass(order.platform)">{{ platformLabel(order.platform) }}</span>
            </td>
            <td class="px-4 py-3 text-gray-600 font-mono text-xs">{{ order.external_order_id }}</td>
            <td class="px-4 py-3">
              <div class="text-gray-700">{{ order.customer_name || '—' }}</div>
              <div v-if="order.customer_phone" class="text-xs text-gray-500">{{ order.customer_phone }}</div>
            </td>
            <td class="px-4 py-3 text-gray-600 max-w-[200px] truncate">{{ order.product_name || '—' }}</td>
            <td class="px-4 py-3 text-right font-medium text-gray-800">¥{{ Number(order.amount || 0).toFixed(2) }}</td>
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded" :class="orderStatusClass(order.order_status)">{{ orderStatusLabel(order.order_status) }}</span>
            </td>
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded" :class="syncStatusClass(order.sync_status)">{{ order.syncStatusLabel || syncStatusLabel(order.sync_status) }}</span>
            </td>
            <td class="px-4 py-3 text-center">
              <button v-if="order.sync_status !== 'synced' && !order.linked_order_id" @click="convertOrder(order)" class="text-xs text-blue-600 hover:text-blue-800 cursor-pointer">转为内部订单</button>
              <span v-else class="text-xs text-green-500">已关联</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards -->
    <div class="md:hidden space-y-2">
      <div v-if="loading" class="bg-white rounded-xl p-6 text-center text-gray-500 text-sm">加载中...</div>
      <div v-else-if="orders.length === 0" class="bg-white rounded-xl p-6 text-center text-gray-500 text-sm">暂无外部订单数据</div>
      <div v-for="order in orders" :key="order.id" class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs px-2 py-0.5 rounded-full" :class="platformClass(order.platform)">{{ platformLabel(order.platform) }}</span>
          <span class="text-xs px-2 py-0.5 rounded" :class="syncStatusClass(order.sync_status)">{{ order.syncStatusLabel || syncStatusLabel(order.sync_status) }}</span>
        </div>
        <div class="flex items-end justify-between mb-2">
          <div class="text-gray-700 text-sm font-medium">{{ order.customer_name || '未填写' }}</div>
          <div class="text-lg font-bold text-gray-800">¥{{ Number(order.amount || 0).toFixed(2) }}</div>
        </div>
        <div class="text-xs text-gray-500 space-y-0.5">
          <div>{{ order.product_name || '—' }}</div>
          <div>订单号：{{ order.external_order_id }}</div>
          <div v-if="order.order_time">{{ formatDate(order.order_time) }}</div>
        </div>
        <div v-if="order.sync_status !== 'synced' && !order.linked_order_id" class="mt-3 pt-2 border-t border-gray-50">
          <button @click="convertOrder(order)" class="text-xs text-blue-600 font-medium cursor-pointer">转为内部订单 →</button>
        </div>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="flex items-center justify-center gap-2 mt-4">
      <button @click="page = Math.max(1, page - 1)" :disabled="page <= 1" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 disabled:opacity-30 cursor-pointer">上一页</button>
      <span class="text-xs text-gray-500">{{ page }} / {{ totalPages }}</span>
      <button @click="page = Math.min(totalPages, page + 1)" :disabled="page >= totalPages" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 disabled:opacity-30 cursor-pointer">下一页</button>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { createPlatform } from '../lib/platforms/index.js'
import { PLATFORM_LABELS } from '../lib/utils'

const loading = ref(false)
const syncing = ref(false)
const orders = ref([])
const page = ref(1)
const pageSize = 20
const totalCount = ref(0)
const filterPlatform = ref('')
const filterSyncStatus = ref('')

const totalPages = computed(() => Math.max(1, Math.ceil(totalCount.value / pageSize)))

const stats = computed(() => {
  const all = orders.value
  return {
    total: totalCount.value,
    synced: all.filter(o => o.sync_status === 'synced').length,
    pending: all.filter(o => o.sync_status === 'pending').length,
    totalAmount: all.reduce((s, o) => s + Number(o.amount || 0), 0),
  }
})

// PLATFORM_LABELS 已从 utils.js 统一导入
const PLATFORM_CLASSES = { douyin: 'bg-black text-white', kuaishou: 'bg-orange-500 text-white', wechat_video: 'bg-green-500 text-white', jushuitan: 'bg-blue-500 text-white' }
const ORDER_STATUS_LABELS = { pending: '待付款', paid: '已付款', shipped: '已发货', completed: '已完成', cancelled: '已取消', refunded: '已退款' }
const ORDER_STATUS_CLASSES = { pending: 'bg-gray-100 text-gray-500', paid: 'bg-blue-50 text-blue-600', shipped: 'bg-purple-50 text-purple-600', completed: 'bg-green-50 text-green-600', cancelled: 'bg-red-50 text-red-500', refunded: 'bg-amber-50 text-amber-600' }
const SYNC_STATUS_LABELS = { pending: '待同步', synced: '已同步', failed: '同步失败' }
const SYNC_STATUS_CLASSES = { pending: 'bg-orange-50 text-orange-600', synced: 'bg-green-50 text-green-600', failed: 'bg-red-50 text-red-500' }

function platformLabel(p) { return PLATFORM_LABELS[p] || p }
function platformClass(p) { return PLATFORM_CLASSES[p] || 'bg-gray-100 text-gray-600' }
function orderStatusLabel(s) { return ORDER_STATUS_LABELS[s] || s }
function orderStatusClass(s) { return ORDER_STATUS_CLASSES[s] || 'bg-gray-100 text-gray-500' }
function syncStatusLabel(s) { return SYNC_STATUS_LABELS[s] || s }
function syncStatusClass(s) { return SYNC_STATUS_CLASSES[s] || 'bg-gray-100 text-gray-500' }
function formatMoney(v) { return Number(v || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }
function formatDate(d) { if (!d) return ''; return new Date(d).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }) }

async function loadOrders() {
  loading.value = true
  try {
    let query = supabase
      .from('platform_orders')
      .select('*', { count: 'exact' })
      .order('order_time', { ascending: false })
      .range((page.value - 1) * pageSize, page.value * pageSize - 1)
    if (filterPlatform.value) query = query.eq('platform', filterPlatform.value)
    if (filterSyncStatus.value) query = query.eq('sync_status', filterSyncStatus.value)
    const { data, error, count } = await query
    if (error) throw error
    orders.value = data || []
    totalCount.value = count || 0
  } catch (e) {
    console.error('加载外部订单失败:', e)
    orders.value = []
  } finally {
    loading.value = false
  }
}

async function syncAll() {
  syncing.value = true
  try {
    const { data: creds } = await supabase
      .from('platform_credentials')
      .select('*')
      .eq('status', 'active')
    if (!creds || creds.length === 0) {
      alert('请先在"平台对接"页面配置API凭证')
      return
    }
    let synced = 0
    for (const cred of creds) {
      try {
        const platform = createPlatform(cred)
        await platform.syncOrders(supabase)
        synced++
      } catch (e) {
        console.warn(`同步 ${cred.platform} 失败:`, e)
      }
    }
    alert(`同步完成！共处理 ${creds.length} 个平台`)
    await loadOrders()
  } catch (e) {
    console.error('同步失败:', e)
    alert('同步失败: ' + (e.message || ''))
  } finally {
    syncing.value = false
  }
}

async function convertOrder(order) {
  if (!confirm(`确定将外部订单 ${order.external_order_id} 转为内部订单？`)) return
  try {
    const payload = {
      service_number_code: null,
      payment_method: null,
      customer_name: order.customer_name || null,
      customer_phone: order.customer_phone || null,
      customer_address: order.customer_address || null,
      product_category: 'other',
      product_name: order.product_name || null,
      amount: Number(order.amount) || 0,
      note: `[${platformLabel(order.platform)}] 外部订单号: ${order.external_order_id}${order.remark ? '\n' + order.remark : ''}`,
      status: 'completed',
      source_platform: order.platform,
      external_order_id: order.external_order_id,
    }
    const { data, error } = await supabase
      .from('orders')
      .insert(payload)
      .select()
      .single()
    if (error) throw error
    // 更新外部订单同步状态
    await supabase
      .from('platform_orders')
      .update({ sync_status: 'synced', linked_order_id: data.id })
      .eq('id', order.id)
    alert('转换成功！')
    await loadOrders()
  } catch (e) {
    console.error('转换失败:', e)
    alert('转换失败: ' + (e.message || ''))
  }
}

onMounted(loadOrders)
watch([filterPlatform, filterSyncStatus, page], loadOrders)
</script>
