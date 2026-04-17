<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-black/30 z-50 flex justify-end" @click.self="$emit('close')">
      <div class="bg-white w-full max-w-2xl h-full shadow-2xl flex flex-col">
        <!-- Header -->
        <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <div>
            <h2 class="font-bold text-gray-800">
              {{ accountName }}
              <span class="ml-2 text-sm font-normal"
                :class="direction === 'in' ? 'text-green-600' : 'text-red-500'">
                {{ direction === 'in' ? '本期增加' : '本期减少' }}明细
              </span>
            </h2>
            <p class="text-xs text-gray-500 mt-0.5">{{ from }} ~ {{ to }} · 共 {{ flows.length }} 笔 · 合计 {{ direction === 'in' ? '+' : '-' }}{{ formatMoney(total) }}</p>
          </div>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>

        <!-- Body -->
        <div class="flex-1 overflow-y-auto px-5 py-4">
          <div v-if="loading" class="text-center py-12 text-gray-500">加载中…</div>
          <div v-else-if="flows.length === 0" class="text-center py-12 text-gray-400">
            <div class="text-3xl mb-2">📭</div>
            <p>该期间没有{{ direction === 'in' ? '增加' : '减少' }}流水</p>
          </div>
          <div v-else class="space-y-2">
            <div v-for="f in flows" :key="f.key"
              class="border border-gray-100 rounded-lg p-3 hover:bg-gray-50 transition">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="text-xs px-2 py-0.5 rounded-full shrink-0" :class="typeClass(f.type)">{{ typeLabel(f.type) }}</span>
                    <span class="text-xs text-gray-500">{{ formatDate(f.flow_at, 'datetime') }}</span>
                  </div>
                  <div class="text-sm text-gray-700 truncate">{{ f.summary }}</div>
                  <div v-if="f.sub" class="text-xs text-gray-400 mt-0.5 truncate">{{ f.sub }}</div>
                </div>
                <div class="shrink-0 text-right">
                  <div class="font-semibold"
                    :class="direction === 'in' ? 'text-green-600' : 'text-red-500'">
                    {{ direction === 'in' ? '+' : '-' }}{{ formatMoney(f.abs_amount) }}
                  </div>
                  <div class="mt-1 flex items-center gap-1 justify-end">
                    <button v-if="f.editable" @click="startEdit(f)"
                      class="text-xs px-2 py-0.5 border border-gray-200 rounded hover:bg-gray-100 cursor-pointer">✏️ 改</button>
                    <button v-if="f.sourceRoute" @click="gotoSource(f)"
                      class="text-xs px-2 py-0.5 border border-blue-200 text-blue-600 rounded hover:bg-blue-50 cursor-pointer">↗ 源页</button>
                  </div>
                </div>
              </div>

              <!-- Inline edit -->
              <div v-if="editingKey === f.key" class="mt-3 pt-3 border-t border-gray-100 bg-amber-50/40 -mx-3 -mb-3 px-3 pb-3 rounded-b-lg">
                <div class="grid grid-cols-2 gap-2 mb-2">
                  <div>
                    <label class="text-[11px] text-gray-500">金额</label>
                    <input v-model.number="editBuf.amount" type="number" step="0.01"
                      class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                  </div>
                  <div>
                    <label class="text-[11px] text-gray-500">日期</label>
                    <input v-model="editBuf.date" type="date"
                      class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                  </div>
                </div>
                <div class="mb-2">
                  <label class="text-[11px] text-gray-500">备注</label>
                  <input v-model="editBuf.note" type="text"
                    class="w-full px-2 py-1 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-amber-400" />
                </div>
                <div class="flex items-center gap-2">
                  <button @click="saveEdit(f)" :disabled="saving"
                    class="px-3 py-1 bg-amber-500 text-white rounded text-xs hover:bg-amber-600 disabled:opacity-50 cursor-pointer">
                    {{ saving ? '保存中…' : '保存' }}
                  </button>
                  <button @click="cancelEdit" class="px-3 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 cursor-pointer">取消</button>
                  <span class="text-[11px] text-gray-400 ml-auto">仅改金额/日期/备注，其他字段请到源页改</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { formatMoney, formatDate, toast } from '../lib/utils'

const props = defineProps({
  accountId: { type: String, required: true },
  accountName: { type: String, default: '' },
  from: { type: String, required: true },        // 'YYYY-MM-DD'
  to:   { type: String, required: true },
  direction: { type: String, required: true },   // 'in' | 'out'
})
const emit = defineEmits(['close', 'updated'])
const router = useRouter()

const loading = ref(false)
const flows = ref([])
const total = computed(() => flows.value.reduce((s, f) => s + Number(f.abs_amount || 0), 0))

const editingKey = ref(null)
const editBuf = ref({ amount: 0, date: '', note: '' })
const saving = ref(false)

// 时间范围：from 00:00 到 to 23:59:59（按东八区）
const fromIso = computed(() => new Date(props.from + 'T00:00:00+08:00').toISOString())
const toIso   = computed(() => new Date(props.to   + 'T23:59:59+08:00').toISOString())

function typeLabel(t) {
  return {
    order: '订单',
    expense: '支出',
    refund: '退款',
    transfer_in: '转入',
    transfer_out: '转出',
    withdrawal_out: '店铺提现',
    withdrawal_in: '提现到账',
  }[t] || t
}
function typeClass(t) {
  return {
    order:           'bg-green-100 text-green-700',
    expense:         'bg-red-100 text-red-600',
    refund:          'bg-orange-100 text-orange-600',
    transfer_in:     'bg-blue-100 text-blue-700',
    transfer_out:    'bg-blue-50 text-blue-500',
    withdrawal_in:   'bg-teal-100 text-teal-700',
    withdrawal_out:  'bg-purple-100 text-purple-700',
  }[t] || 'bg-gray-100 text-gray-600'
}

async function loadFlows() {
  loading.value = true
  flows.value = []
  try {
    const acc = props.accountId
    const isIn = props.direction === 'in'
    const tasks = []

    if (isIn) {
      // 订单收入
      tasks.push(supabase.from('orders')
        .select('id, order_no, customer_name, amount, paid_at, created_at, note, status')
        .eq('account_id', acc)
        .is('deleted_at', null)
        .in('status', ['completed', 'partially_refunded'])
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'order-' + r.id,
          type: 'order',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `${r.order_no || '—'} · ${r.customer_name || ''}`.trim(),
          sub: r.note || '',
          editable: true,
          table: 'orders',
          id: r.id,
          amountField: 'amount',
          dateField: r.paid_at ? 'paid_at' : 'created_at',
          noteField: 'note',
          sourceRoute: { name: 'Orders' },
        }))))

      // 转账转入
      tasks.push(supabase.from('account_transfers')
        .select('id, amount, fee, transfer_date, created_at, note, from_account:from_account_id(short_name,code)')
        .eq('to_account_id', acc)
        .eq('status', 'completed')
        .is('deleted_at', null)
        .or(`and(transfer_date.gte.${fromIso.value},transfer_date.lte.${toIso.value}),and(transfer_date.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'trin-' + r.id,
          type: 'transfer_in',
          flow_at: r.transfer_date || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `从 ${r.from_account?.short_name || r.from_account?.code || '—'} 转入`,
          sub: r.note || '',
          editable: true,
          table: 'account_transfers',
          id: r.id,
          amountField: 'amount',
          dateField: r.transfer_date ? 'transfer_date' : 'created_at',
          noteField: 'note',
          sourceRoute: { name: 'Transfers' },
        }))))

      // 店铺提现到账
      tasks.push(supabase.from('withdrawals')
        .select('id, amount, actual_arrival, fee_detail, withdrawn_at, created_at, remark, store_name, account:account_id(short_name,code)')
        .eq('to_account_id', acc)
        .eq('status', 'completed')
        .is('deleted_at', null)
        .or(`and(withdrawn_at.gte.${fromIso.value},withdrawn_at.lte.${toIso.value}),and(withdrawn_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'wdin-' + r.id,
          type: 'withdrawal_in',
          flow_at: r.withdrawn_at || r.created_at,
          abs_amount: Number(r.actual_arrival ?? r.amount ?? 0),
          summary: `${r.account?.short_name || r.store_name || '店铺'} 提现到账`,
          sub: r.remark || '',
          editable: false,   // withdrawals 金额牵扯两边余额，不做就地编辑
          table: 'withdrawals',
          id: r.id,
          sourceRoute: { name: 'Ecommerce' },
        }))))
    } else {
      // 支出
      tasks.push(supabase.from('expenses')
        .select('id, amount, payee, category, paid_at, created_at, note, status')
        .eq('account_id', acc)
        .eq('status', 'paid')
        .is('deleted_at', null)
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'exp-' + r.id,
          type: 'expense',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `${r.category || ''} · ${r.payee || ''}`.trim().replace(/^·\s*/, ''),
          sub: r.note || '',
          editable: true,
          table: 'expenses',
          id: r.id,
          amountField: 'amount',
          dateField: r.paid_at ? 'paid_at' : 'created_at',
          noteField: 'note',
          sourceRoute: { name: 'Expenses' },
        }))))

      // 退款（退给客户）
      tasks.push(supabase.from('refunds')
        .select('id, refund_no, refund_amount, reason, paid_at, created_at, note, status')
        .eq('refund_from_account_id', acc)
        .eq('status', 'completed')
        .is('deleted_at', null)
        .or(`and(paid_at.gte.${fromIso.value},paid_at.lte.${toIso.value}),and(paid_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'rfnd-' + r.id,
          type: 'refund',
          flow_at: r.paid_at || r.created_at,
          abs_amount: Number(r.refund_amount || 0),
          summary: `${r.refund_no || '—'} · ${r.reason || ''}`.trim(),
          sub: r.note || '',
          editable: false,  // 退款金额影响订单状态，不做就地编辑
          table: 'refunds',
          id: r.id,
          sourceRoute: { name: 'Orders' },
        }))))

      // 转账转出（含手续费合并展示）
      tasks.push(supabase.from('account_transfers')
        .select('id, amount, fee, transfer_date, created_at, note, to_account:to_account_id(short_name,code)')
        .eq('from_account_id', acc)
        .eq('status', 'completed')
        .is('deleted_at', null)
        .or(`and(transfer_date.gte.${fromIso.value},transfer_date.lte.${toIso.value}),and(transfer_date.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'trout-' + r.id,
          type: 'transfer_out',
          flow_at: r.transfer_date || r.created_at,
          abs_amount: Number(r.amount || 0) + Number(r.fee || 0),
          summary: `转出到 ${r.to_account?.short_name || r.to_account?.code || '—'}${Number(r.fee) > 0 ? `（含手续费 ¥${r.fee}）` : ''}`,
          sub: r.note || '',
          editable: true,
          table: 'account_transfers',
          id: r.id,
          amountField: 'amount',
          dateField: r.transfer_date ? 'transfer_date' : 'created_at',
          noteField: 'note',
          sourceRoute: { name: 'Transfers' },
        }))))

      // 店铺提现扣款
      tasks.push(supabase.from('withdrawals')
        .select('id, amount, actual_arrival, fee_detail, withdrawn_at, created_at, remark, store_name, to_account:to_account_id(short_name,code)')
        .eq('account_id', acc)
        .eq('status', 'completed')
        .is('deleted_at', null)
        .or(`and(withdrawn_at.gte.${fromIso.value},withdrawn_at.lte.${toIso.value}),and(withdrawn_at.is.null,created_at.gte.${fromIso.value},created_at.lte.${toIso.value})`)
        .then(({ data }) => (data || []).map(r => ({
          key: 'wdout-' + r.id,
          type: 'withdrawal_out',
          flow_at: r.withdrawn_at || r.created_at,
          abs_amount: Number(r.amount || 0),
          summary: `提现到 ${r.to_account?.short_name || r.to_account?.code || '—'}`,
          sub: r.remark || '',
          editable: false,
          table: 'withdrawals',
          id: r.id,
          sourceRoute: { name: 'Ecommerce' },
        }))))
    }

    const results = await Promise.all(tasks)
    flows.value = results.flat().sort((a, b) => new Date(b.flow_at) - new Date(a.flow_at))
  } catch (e) {
    console.error('[BalanceFlowDrawer] load failed:', e)
    toast('加载明细失败：' + (e.message || ''), 'error')
  } finally {
    loading.value = false
  }
}

function startEdit(f) {
  editingKey.value = f.key
  editBuf.value = {
    amount: f.abs_amount,
    date: (f.flow_at || '').slice(0, 10),
    note: f.sub || '',
  }
}
function cancelEdit() {
  editingKey.value = null
}
async function saveEdit(f) {
  if (saving.value) return
  saving.value = true
  try {
    const patch = {}
    patch[f.amountField] = Number(editBuf.value.amount)
    // 日期字段：date 列直接字符串，timestamptz 列补 +08:00
    if (f.dateField === 'paid_at' || f.dateField === 'created_at' || f.dateField === 'transfer_date') {
      patch[f.dateField] = new Date(editBuf.value.date + 'T00:00:00+08:00').toISOString()
    } else {
      patch[f.dateField] = editBuf.value.date
    }
    patch[f.noteField] = editBuf.value.note || null

    const { error } = await supabase.from(f.table).update(patch).eq('id', f.id)
    if (error) throw error
    toast('已保存', 'success')
    editingKey.value = null
    emit('updated')   // 让父组件重新拉矩阵
    await loadFlows()
  } catch (e) {
    toast('保存失败：' + (e.message || ''), 'error')
  } finally {
    saving.value = false
  }
}

function gotoSource(f) {
  if (!f.sourceRoute) return
  router.push(f.sourceRoute)
}

onMounted(loadFlows)
watch(() => [props.accountId, props.from, props.to, props.direction], loadFlows)
</script>
