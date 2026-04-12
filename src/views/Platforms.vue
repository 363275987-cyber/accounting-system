<template>
  <div>
    <h1 class="text-xl font-bold text-gray-800 mb-6">📱 平台收入</h1>

    <!-- 筛选栏 -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex items-center gap-4">
      <select v-model="filter.status" class="px-3 py-1.5 text-sm border border-gray-200 rounded-lg" @change="loadData">
        <option value="">全部状态</option>
        <option value="pending_review">待校验</option>
        <option value="confirmed">已确认</option>
        <option value="rejected">已驳回</option>
      </select>
      <select v-model="filter.platform" class="px-3 py-1.5 text-sm border border-gray-200 rounded-lg" @change="loadData">
        <option value="">全部平台</option>
        <option v-for="(label, key) in PLATFORM_LABELS" :key="key" :value="key">{{ label }}</option>
      </select>
      <input v-model="filter.period" type="month" class="px-3 py-1.5 text-sm border border-gray-200 rounded-lg" @change="loadData" />
      <div class="flex-1"></div>
      <button @click="showAddModal = true" class="px-4 py-1.5 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition-colors">
        + 新增收入
      </button>
    </div>

    <!-- 数据表格 -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50 text-gray-500 text-xs uppercase">
          <tr>
            <th class="px-4 py-3 text-left">平台</th>
            <th class="px-4 py-3 text-left">周期</th>
            <th class="px-4 py-3 text-right">总收入</th>
            <th class="px-4 py-3 text-right">已结算</th>
            <th class="px-4 py-3 text-right">待结算</th>
            <th class="px-4 py-3 text-right">手续费</th>
            <th class="px-4 py-3 text-left">状态</th>
            <th class="px-4 py-3 text-left">备注</th>
            <th class="px-4 py-3 text-center">操作</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-50">
          <tr v-for="row in revenues" :key="row.id" class="hover:bg-gray-50/50">
            <td class="px-4 py-3 font-medium">{{ PLATFORM_LABELS[row.platform] || row.platform }}</td>
            <td class="px-4 py-3 text-gray-500">{{ row.period }}</td>
            <td class="px-4 py-3 text-right font-medium">{{ formatMoney(row.total_revenue) }}</td>
            <td class="px-4 py-3 text-right text-green-600">{{ formatMoney(row.settled_amount) }}</td>
            <td class="px-4 py-3 text-right text-orange-500">{{ formatMoney(row.pending_amount) }}</td>
            <td class="px-4 py-3 text-right text-red-400">{{ formatMoney(row.fee_amount) }}</td>
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded-full" :class="statusClass(row.status)">
                {{ STATUS_LABELS[row.status] || row.status }}
              </span>
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs truncate max-w-[120px]">{{ row.note || '--' }}</td>
            <td class="px-4 py-3 text-center">
              <template v-if="row.status === 'pending_review' && authStore.isFinance">
                <button @click="reviewRecord(row, 'confirmed')" class="text-green-600 hover:text-green-700 text-xs mr-2">✓ 确认</button>
                <button @click="reviewRecord(row, 'rejected')" class="text-red-500 hover:text-red-600 text-xs">✗ 驳回</button>
              </template>
              <span v-else class="text-xs text-gray-300">--</span>
            </td>
          </tr>
          <tr v-if="revenues.length === 0">
            <td colspan="9" class="px-4 py-12 text-center text-gray-500">暂无数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- 新增收入弹窗 -->
    <div v-if="showAddModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showAddModal = false">
      <div class="bg-white rounded-2xl shadow-xl w-[480px] p-6">
        <h3 class="font-bold text-lg mb-4">新增平台收入</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">平台 *</label>
            <select v-model="form.platform" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm">
              <option value="">请选择</option>
              <option v-for="(label, key) in PLATFORM_LABELS" :key="key" :value="key">{{ label }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">周期 *</label>
            <input v-model="form.period" type="month" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">总收入 *</label>
              <input v-model.number="form.total_revenue" type="number" step="0.01" placeholder="0.00" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">已结算</label>
              <input v-model.number="form.settled_amount" type="number" step="0.01" placeholder="0.00" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm text-gray-600 mb-1">待结算</label>
              <input v-model.number="form.pending_amount" type="number" step="0.01" placeholder="0.00" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
            </div>
            <div>
              <label class="block text-sm text-gray-600 mb-1">手续费率(%)</label>
              <input v-model.number="form.fee_rate" type="number" step="0.01" placeholder="0" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" />
            </div>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <textarea v-model="form.note" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm resize-none" placeholder="可选"></textarea>
          </div>
        </div>
        <div class="flex justify-end gap-3 mt-6">
          <button @click="showAddModal = false" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg">取消</button>
          <button @click="addRecord" :disabled="submitting" class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
            {{ submitting ? '提交中...' : '提交（待校验）' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, PLATFORM_LABELS, toast } from '../lib/utils'

const authStore = useAuthStore()

const STATUS_LABELS = {
  pending_review: '待校验',
  confirmed: '已确认',
  rejected: '已驳回',
}

const revenues = ref([])
const showAddModal = ref(false)
const submitting = ref(false)

const filter = ref({ status: '', platform: '', period: '' })
const form = ref({
  platform: '', period: '', total_revenue: 0, settled_amount: 0,
  pending_amount: 0, fee_rate: 0, note: ''
})

function statusClass(status) {
  const map = {
    pending_review: 'bg-orange-100 text-orange-700',
    confirmed: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-600',
  }
  return map[status] || 'bg-gray-100 text-gray-500'
}

async function loadData() {
  let query = supabase
    .from('platform_revenues')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100)

  if (filter.value.status) query = query.eq('status', filter.value.status)
  if (filter.value.platform) query = query.eq('platform', filter.value.platform)
  if (filter.value.period) query = query.eq('period', filter.value.period)

  const { data } = await query
  revenues.value = data || []
}

async function addRecord() {
  if (!form.value.platform || !form.value.period) {
    toast('请填写平台和周期', 'warning')
    return
  }
  submitting.value = true
  try {
    const feeAmount = Number(form.value.total_revenue) * (Number(form.value.fee_rate) || 0) / 100
    const { error } = await supabase.from('platform_revenues').insert({
      platform: form.value.platform,
      period: form.value.period,
      total_revenue: form.value.total_revenue || 0,
      settled_amount: form.value.settled_amount || 0,
      pending_amount: form.value.pending_amount || 0,
      fee_rate: form.value.fee_rate || 0,
      fee_amount: feeAmount,
      status: 'pending_review', // 默认待校验
      recorded_by: authStore.user,
      note: form.value.note,
    })
    if (error) throw error
    toast('已提交，等待校验', 'success')
    showAddModal.value = false
    form.value = { platform: '', period: '', total_revenue: 0, settled_amount: 0, pending_amount: 0, fee_rate: 0, note: '' }
    loadData()
  } catch (e) {
    toast(e.message || '操作失败', 'error')
  } finally {
    submitting.value = false
  }
}

async function reviewRecord(row, newStatus) {
  if (!authStore.isFinance) {
    toast('无权限操作', 'error')
    return
  }
  const label = newStatus === 'confirmed' ? '确认' : '驳回'
  if (!confirm(`确定${label}该记录？`)) return

  try {
    const { error } = await supabase
      .from('platform_revenues')
      .update({
        status: newStatus,
        reviewed_by: authStore.user,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', row.id)
    if (error) throw error
    toast(`已${label}`, 'success')
    loadData()
  } catch (e) {
    toast(e.message || '操作失败', 'error')
  }
}

onMounted(() => loadData())
</script>
