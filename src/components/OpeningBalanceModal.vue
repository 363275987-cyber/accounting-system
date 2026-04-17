<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4"
      @click.self="handleClose"
    >
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md max-h-[90vh] overflow-y-auto">
        <!-- Header -->
        <div class="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 class="text-lg font-bold text-gray-800">📌 重设期初余额</h2>
          <button @click="handleClose" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>

        <!-- Body -->
        <div class="p-5 space-y-4">
          <!-- 醒目警告 -->
          <div class="bg-amber-50 border border-amber-200 rounded-lg p-3 text-xs text-amber-700 leading-relaxed">
            ⚠️ <b>期初余额是账户的开账起点</b>。修改会影响所有对账报表的基准线——仅在新财年开始或数据清空后使用。
          </div>

          <!-- 数据初始化快捷链接 -->
          <div v-if="isFinance" class="text-xs text-gray-500">
            刚做过数据初始化？
            <a href="#/data-initialization" class="text-blue-500 hover:text-blue-700 underline cursor-pointer">
              去数据初始化页 →
            </a>
          </div>

          <!-- 账户基本信息（只读） -->
          <div class="bg-gray-50 rounded-lg p-3 space-y-1.5 text-sm">
            <div class="flex items-center justify-between">
              <span class="text-gray-500">账户</span>
              <span class="font-medium text-gray-800">{{ account?.short_name || account?.code || '-' }}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-gray-500">当前余额 (balance)</span>
              <span class="font-semibold" :class="currentBalance >= 0 ? 'text-green-600' : 'text-red-500'">
                ¥{{ currentBalance.toFixed(2) }}
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-gray-500">当前期初 (opening_balance)</span>
              <span class="font-semibold text-gray-700">¥{{ currentOpeningBalance.toFixed(2) }}</span>
            </div>
            <!-- 差值提示（仅当 balance ≠ opening 时） -->
            <div
              v-if="Math.abs(currentBalance - currentOpeningBalance) > 0.005"
              class="text-xs text-gray-400 pt-1 border-t border-gray-200 mt-2"
            >
              差值 ¥{{ (currentBalance - currentOpeningBalance).toFixed(2) }}，
              这是期初 + 所有流水累计的正常结果，不是 bug。
            </div>
          </div>

          <!-- 新期初余额输入 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">新期初余额</label>
            <input
              v-model.number="form.newOpening"
              type="number"
              step="0.01"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="默认 0（现金起账）"
            />
            <p class="text-xs text-gray-500 mt-1">
              可填正数/负数/0。负债账户（信用卡等）期初可能为负。
            </p>
          </div>

          <!-- 备注 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">说明备注（可选）</label>
            <textarea
              v-model="form.note"
              rows="2"
              placeholder="如：2026 财年开账 / 数据初始化后重建期初"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            ></textarea>
          </div>

          <!-- 是否同步 balance -->
          <div class="border-t border-gray-100 pt-4">
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="checkbox"
                v-model="form.syncBalance"
                class="mt-0.5 w-4 h-4 accent-blue-600 cursor-pointer"
              />
              <div class="flex-1 text-sm">
                <div class="font-medium text-gray-800">同步把 balance 字段重设为新期初</div>
                <p class="text-xs text-gray-500 mt-0.5 leading-relaxed">
                  勾上 = 把当前余额也重设为新期初（<b>常用于清空流水后重建</b>；需配合已清空该账户的所有交易流水使用）。<br/>
                  关闭 = 只改 opening_balance，不动 balance（适用于只修正录错的开账数，不影响后续流水累计）。
                </p>
              </div>
            </label>
          </div>

          <!-- 预览变更 -->
          <div v-if="hasChange" class="bg-blue-50 border border-blue-100 rounded-lg p-3 text-xs text-blue-700 space-y-0.5">
            <div>期初：¥{{ currentOpeningBalance.toFixed(2) }} → ¥{{ Number(form.newOpening || 0).toFixed(2) }}</div>
            <div v-if="form.syncBalance">
              余额：¥{{ currentBalance.toFixed(2) }} → ¥{{ Number(form.newOpening || 0).toFixed(2) }}
              <span class="text-blue-400">(delta {{ balanceDelta >= 0 ? '+' : '' }}{{ balanceDelta.toFixed(2) }})</span>
            </div>
            <div v-else class="text-blue-400">余额不变（仅改期初）</div>
          </div>
        </div>

        <!-- Footer -->
        <div class="flex justify-end gap-3 p-5 border-t border-gray-100">
          <button
            @click="handleClose"
            :disabled="saving"
            class="px-4 py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer disabled:opacity-50"
          >
            取消
          </button>
          <button
            @click="handleSave"
            :disabled="saving || !hasChange"
            class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            {{ saving ? '保存中...' : '保存' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, reactive, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { toast } from '../lib/utils'

const props = defineProps({
  visible: { type: Boolean, default: false },
  account: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

const authStore = useAuthStore()
const accountStore = useAccountStore()
const isFinance = computed(() => authStore.isFinance)

const saving = ref(false)

const form = reactive({
  newOpening: 0,
  note: '',
  syncBalance: true,
})

const currentBalance = computed(() => Number(props.account?.balance ?? 0))
const currentOpeningBalance = computed(() => Number(props.account?.opening_balance ?? 0))

const balanceDelta = computed(() => Number(form.newOpening || 0) - currentBalance.value)

const hasChange = computed(() => {
  const v = Number(form.newOpening || 0)
  // 期初不同，或者勾了同步且新期初 ≠ 当前余额
  if (Math.abs(v - currentOpeningBalance.value) > 0.005) return true
  if (form.syncBalance && Math.abs(v - currentBalance.value) > 0.005) return true
  return false
})

// 每次打开弹窗时重置表单
watch(() => props.visible, (v) => {
  if (v && props.account) {
    form.newOpening = Number(props.account.opening_balance ?? 0)
    form.note = ''
    form.syncBalance = true
  }
})

function handleClose() {
  if (saving.value) return
  emit('close')
}

async function handleSave() {
  if (!props.account?.id) return
  if (!isFinance.value) {
    toast('无权限', 'error')
    return
  }
  if (!hasChange.value) {
    toast('数据没有变化', 'info')
    return
  }

  saving.value = true
  const accountId = props.account.id
  const accountName = props.account.short_name || props.account.code || ''
  const oldOpening = currentOpeningBalance.value
  const oldBalance = currentBalance.value
  const newOpening = Number(form.newOpening || 0)
  const note = form.note?.trim() || ''
  const syncBalance = !!form.syncBalance

  try {
    // 1. 更新 opening_balance
    const { error: updErr } = await supabase
      .from('accounts')
      .update({ opening_balance: newOpening })
      .eq('id', accountId)
    if (updErr) throw updErr

    // 2. 同步 balance（若勾选）——用 RPC 保证原子，并留下 balance_change_logs 痕迹
    let balanceChanged = false
    if (syncBalance && Math.abs(newOpening - oldBalance) > 0.005) {
      const delta = newOpening - oldBalance
      const reason = note
        ? `期初余额校准（同步balance）：${note}`
        : '期初余额校准（同步balance）'
      try {
        await accountStore.updateBalance(accountId, delta, reason, 'opening_balance', null)
        balanceChanged = true
      } catch (e) {
        // 回滚 opening_balance
        console.error('[OpeningBalance] balance 同步失败，回滚 opening_balance', e)
        try {
          await supabase
            .from('accounts')
            .update({ opening_balance: oldOpening })
            .eq('id', accountId)
        } catch (rbErr) {
          console.error('[OpeningBalance] 回滚 opening_balance 也失败', rbErr)
        }
        throw new Error(`同步 balance 失败：${e?.message || e}`)
      }
    }

    // 2.5 写 manual_adjustments 保证余额对账 RPC 与 live balance 保持一致
    // 公式：adjust = (delta_balance_live) - (delta_opening)
    //   让 RPC closing_new = closing_old + delta_balance_live = live_new
    try {
      const deltaOpening = newOpening - oldOpening
      const deltaLive = balanceChanged ? (newOpening - oldBalance) : 0
      const adjAmt = deltaLive - deltaOpening
      if (Math.abs(adjAmt) > 0.005) {
        const { data: { session } } = await supabase.auth.getSession()
        const userId = session?.user?.id
        await supabase.from('manual_adjustments').insert({
          account_id: accountId,
          amount: adjAmt,
          adjustment_date: new Date().toISOString(),
          note: `期初校准补偿 ${accountName}` + (note ? `：${note}` : ''),
          recorded_by: userId,
          status: 'completed',
        })
      }
    } catch (e) {
      console.warn('[OpeningBalance] 写 manual_adjustments 失败（不阻断主流程）', e)
    }

    // 3. 写操作日志
    try {
      const { logOperation } = await import('../utils/operationLogger')
      await logOperation({
        action: 'reset_opening_balance',
        module: '账户',
        description:
          `重设期初余额，${accountName}，` +
          `期初 ¥${oldOpening.toFixed(2)} → ¥${newOpening.toFixed(2)}` +
          (balanceChanged
            ? `；balance 同步重设 ¥${oldBalance.toFixed(2)} → ¥${newOpening.toFixed(2)}`
            : '；balance 未变'),
        detail: {
          account_id: accountId,
          account_name: accountName,
          old_opening_balance: oldOpening,
          new_opening_balance: newOpening,
          sync_balance: syncBalance,
          balance_changed: balanceChanged,
          old_balance: oldBalance,
          new_balance: balanceChanged ? newOpening : oldBalance,
          note,
        },
        amount: Math.abs(newOpening - oldOpening),
        accountId,
        accountName,
        balanceBefore: oldBalance,
        balanceAfter: balanceChanged ? newOpening : oldBalance,
      })
    } catch (e) {
      console.warn('[OpeningBalance] 写操作日志失败（忽略）', e?.message || e)
    }

    // 4. 刷新账户数据
    try {
      accountStore._forceRefresh = true
      await accountStore.fetchAccounts()
    } catch (e) {
      console.warn('[OpeningBalance] 刷新账户失败（忽略）', e?.message || e)
    }

    // 5. Toast + 关闭
    toast(
      `${accountName} 期初余额已更新: ¥${oldOpening.toFixed(2)} → ¥${newOpening.toFixed(2)}` +
        `（balance 字段${balanceChanged ? '已同步' : '未变'}）`,
      'success',
      4000
    )
    emit('saved', { accountId, oldOpening, newOpening, balanceChanged })
    emit('close')
  } catch (e) {
    console.error('[OpeningBalance] 保存失败', e)
    toast(`保存失败：${e?.message || e}`, 'error', 5000)
  } finally {
    saving.value = false
  }
}
</script>
