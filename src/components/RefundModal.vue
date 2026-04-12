<template>
  <div v-if="visible" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 max-h-[85vh] flex flex-col overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10 shrink-0">
        <h2 class="font-bold text-gray-800">💳 订单退款</h2>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
      </div>
      <form @submit.prevent="handleRefund" class="p-6 space-y-4 flex-1">
        <!-- 订单信息（只读） -->
        <div class="bg-gray-50 rounded-lg p-4 space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">订单号</span>
            <span class="text-sm font-mono text-gray-700">{{ order?.order_no || '—' }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">客户</span>
            <span class="text-sm text-gray-700">{{ order?.customer_name || '—' }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">商品</span>
            <span class="text-sm text-gray-700">{{ order?.product_name || '—' }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">订单金额</span>
            <span class="text-sm font-semibold text-green-600">¥{{ Number(order?.amount || 0).toLocaleString() }}</span>
          </div>
          <div v-if="alreadyRefunded > 0" class="flex items-center justify-between">
            <span class="text-sm text-gray-500">已退金额</span>
            <span class="text-sm font-semibold text-red-500">-¥{{ alreadyRefunded.toFixed(2) }}</span>
          </div>
          <div class="flex items-center justify-between border-t border-gray-200 pt-2">
            <span class="text-sm font-medium text-gray-700">可退金额</span>
            <span class="text-sm font-bold text-orange-600">¥{{ maxRefundable.toFixed(2) }}</span>
          </div>
        </div>

        <!-- 退款金额 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">退款金额 <span class="text-red-400">*</span></label>
          <div class="relative">
            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">¥</span>
            <input v-model.number="form.refund_amount" type="number" min="0.01" step="0.01" required
              :max="maxRefundable || 999999"
              placeholder="0.00"
              class="w-full pl-8 pr-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div class="flex items-center gap-2 mt-1.5">
            <button type="button" @click="form.refund_amount = maxRefundable"
              class="text-xs text-orange-600 hover:text-orange-700 cursor-pointer underline">全额退款</button>
          </div>
        </div>

        <!-- 退款原因 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">退款原因</label>
          <select v-model="form.reason" class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
            <option value="客户退货">客户退货</option>
            <option value="质量问题">质量问题</option>
            <option value="发错货">发错货</option>
            <option value="客户取消">客户取消</option>
            <option value="物流损坏">物流损坏</option>
            <option value="其他">其他</option>
          </select>
          <input v-if="form.reason === '其他'" v-model="form.custom_reason" placeholder="请填写具体原因" required
            class="w-full mt-2 px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>

        <!-- 付款账户 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">付款账户 <span class="text-red-400">*</span></label>
          <div class="relative">
            <input
              v-model="accountInputText"
              @focus="onAccountFocus"
              @blur="hideAccountDropdown"
              placeholder="点击选择付款账户..."
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
            />
            <div v-if="showAccountDropdown"
              class="absolute z-50 mt-1 left-0 right-0 bg-white border border-gray-200 rounded-lg shadow-xl max-h-48 overflow-y-auto">
              <div
                v-for="acc in filteredAccounts" :key="acc.id"
                @mousedown.prevent="selectAccount(acc)"
                :class="acc.id === form.refund_from_account_id ? 'bg-blue-50' : ''"
                class="px-3 py-2 hover:bg-orange-50 cursor-pointer text-sm border-b border-gray-50 last:border-0"
              >
                {{ acc.short_name || acc.code }}
                <span v-if="acc.balance != null" class="ml-2 text-xs text-gray-500">¥{{ Number(acc.balance).toFixed(0) }}</span>
              </div>
              <div v-if="filteredAccounts.length === 0" class="text-center py-4 text-gray-500 text-sm">没有可用账户</div>
            </div>
          </div>
        </div>

        <!-- 备注 -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
          <textarea v-model="form.note" rows="2" placeholder="可选"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
        </div>

        <div class="flex gap-3 pt-2">
          <button type="button" @click="$emit('close')"
            class="flex-1 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
          <button type="submit" :disabled="submitting || maxRefundable <= 0"
            class="flex-1 py-2.5 bg-orange-600 text-white rounded-lg text-sm hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
            {{ submitting ? '提交中...' : '确认退款' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { toast } from '../lib/utils'

const props = defineProps({
  visible: Boolean,
  order: Object,
  accounts: { type: Array, default: () => [] },
})

const emit = defineEmits(['close', 'submitted'])

const submitting = ref(false)
const alreadyRefunded = ref(0)
const maxRefundable = ref(0)
const accountInputText = ref('')
const showAccountDropdown = ref(false)

const form = reactive({
  refund_amount: null,
  reason: '客户退货',
  custom_reason: '',
  refund_from_account_id: '',
  note: '',
})

// 当弹窗打开（order变化）时，初始化数据
watch(() => [props.visible, props.order], async ([vis, order]) => {
  if (!vis || !order) return
  // 重置表单
  form.refund_amount = null
  form.reason = '客户退货'
  form.custom_reason = ''
  form.refund_from_account_id = ''
  form.note = ''
  accountInputText.value = ''
  alreadyRefunded.value = 0
  maxRefundable.value = 0

  // 查询已退金额
  try {
    const { data: existingRefunds } = await supabase.from('refunds')
      .select('refund_amount')
      .eq('order_id', order.id)
      .is('deleted_at', null)
      .in('status', ['pending', 'processing', 'completed'])
    const refunded = (existingRefunds || []).reduce((sum, r) => sum + Number(r.refund_amount), 0)
    alreadyRefunded.value = refunded
    maxRefundable.value = Math.max(0, Number(order.amount) - refunded)
    form.refund_amount = maxRefundable.value
  } catch (e) {
    maxRefundable.value = Number(order.amount || 0)
    form.refund_amount = maxRefundable.value
  }

  // 自动填充付款账户
  if (order.account_id) {
    form.refund_from_account_id = order.account_id
    const acc = props.accounts.find(a => a.id === order.account_id)
    accountInputText.value = acc ? (acc.short_name || acc.code) : ''
  }
}, { immediate: true })

// 账户搜索
const filteredAccounts = computed(() => {
  const all = (props.accounts || []).filter(a => a.status === 'active')
  if (!accountInputText.value) return all
  const kw = accountInputText.value.toLowerCase()
  return all.filter(a =>
    (a.code || '').toLowerCase().includes(kw) ||
    (a.short_name || '').toLowerCase().includes(kw)
  )
})

function onAccountFocus() { accountInputText.value = ''; showAccountDropdown.value = true }
function hideAccountDropdown() { setTimeout(() => showAccountDropdown.value = false, 200) }
function selectAccount(acc) {
  form.refund_from_account_id = acc.id
  accountInputText.value = acc.short_name || acc.code
  showAccountDropdown.value = false
}

async function handleRefund() {
  if (!form.refund_amount || form.refund_amount <= 0) {
    toast('退款金额必须大于0', 'warning'); return
  }
  if (form.refund_amount > maxRefundable.value) {
    toast(`退款金额超出可退上限 ¥${maxRefundable.value.toFixed(2)}`, 'warning'); return
  }
  if (!form.refund_from_account_id) {
    toast('请选择付款账户', 'warning'); return
  }

  submitting.value = true
  try {
    const userId = (await supabase.auth.getSession()).data.session?.user?.id
    const payload = {
      order_id: props.order.id,
      refund_amount: Number(form.refund_amount),
      reason: form.reason === '其他' ? form.custom_reason : form.reason,
      refund_from_account_id: form.refund_from_account_id,
      status: 'pending',
      created_by: userId,
      note: form.note || null,
    }

    const { data, error } = await supabase
      .from('refunds')
      .insert(payload)
      .select()
      .single()

    if (error) throw error

    toast('退款已登记，等待审批', 'success')
    emit('submitted', data)
  } catch (e) {
    console.error('退款登记失败:', e)
    toast('退款登记失败：' + (e.message || ''), 'error')
  } finally {
    submitting.value = false
  }
}
</script>
