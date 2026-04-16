<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4"
      @click.self="handleClose"
    >
      <div class="bg-white rounded-xl shadow-xl w-full max-w-5xl max-h-[92vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-5 border-b border-gray-100 flex-shrink-0">
          <h2 class="text-lg font-bold text-gray-800">🔢 批量重设期初余额</h2>
          <button @click="handleClose" :disabled="running" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer disabled:opacity-40">✕</button>
        </div>

        <!-- 警告条 -->
        <div class="px-5 pt-4 flex-shrink-0">
          <div class="bg-amber-50 border border-amber-200 rounded-lg p-3 text-xs text-amber-700 leading-relaxed">
            ⚠️ <b>批量修改所有账户的期初余额</b>。会按行独立执行，部分失败时已成功的行不会回滚（请看完成日志）。
            <br/>勾选「同步 balance」= 同时把当前余额重设为新期初（适合数据初始化后重建开账）。
          </div>
        </div>

        <!-- 工具条 -->
        <div class="px-5 py-3 flex-shrink-0 flex items-center gap-2 flex-wrap border-b border-gray-100 bg-gray-50">
          <!-- 分类筛选 -->
          <div class="flex items-center gap-1 bg-white rounded-lg border border-gray-200 p-1">
            <button
              v-for="f in filterOptions"
              :key="f.value"
              @click="categoryFilter = f.value"
              class="px-2.5 py-1 text-xs rounded transition cursor-pointer"
              :class="categoryFilter === f.value ? 'bg-blue-500 text-white' : 'text-gray-500 hover:text-gray-700'"
            >{{ f.label }}</button>
          </div>

          <!-- 搜索 -->
          <input
            v-model="keyword"
            type="text"
            placeholder="🔍 搜索账户名/简称"
            class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-blue-400 w-40"
          />

          <!-- 快捷填充 -->
          <div class="ml-auto flex items-center gap-1 flex-wrap">
            <button
              @click="quickFillBalance"
              class="px-2.5 py-1.5 bg-white border border-gray-200 rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer"
              title="把所有可见行的新期初填为当前余额"
            >= 当前余额</button>
            <button
              @click="quickFillOpening"
              class="px-2.5 py-1.5 bg-white border border-gray-200 rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer"
              title="把所有可见行的新期初填为当前 opening_balance（撤销未保存的修改）"
            >= 当前期初</button>
            <button
              @click="quickFillZero"
              class="px-2.5 py-1.5 bg-white border border-gray-200 rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer"
              title="把所有可见行的新期初填为 0（现金起账）"
            >= 0</button>
            <span class="text-gray-300">|</span>
            <label class="flex items-center gap-1.5 text-xs text-gray-600 cursor-pointer px-2">
              <input type="checkbox" :checked="allSync" @change="toggleAllSync" class="w-3.5 h-3.5 accent-blue-600 cursor-pointer"/>
              <span>全部同步 balance</span>
            </label>
          </div>
        </div>

        <!-- 表格 -->
        <div class="flex-1 overflow-auto px-5 py-3 min-h-0">
          <table class="w-full text-sm">
            <thead class="sticky top-0 bg-white z-10">
              <tr class="text-xs text-gray-500 border-b border-gray-200">
                <th class="p-2 text-left w-16">
                  <label class="flex items-center gap-1.5 cursor-pointer">
                    <input type="checkbox" :checked="allSelected" @change="toggleAllSelected" class="w-4 h-4 accent-blue-600 cursor-pointer"/>
                    <span>全选</span>
                  </label>
                </th>
                <th class="p-2 text-left">账户</th>
                <th class="p-2 text-right">当前余额</th>
                <th class="p-2 text-right">当前期初</th>
                <th class="p-2 text-right w-40">新期初</th>
                <th class="p-2 text-center w-20">同步</th>
                <th class="p-2 text-right w-24">delta</th>
                <th class="p-2 text-center w-16">状态</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!visibleRows.length">
                <td colspan="8" class="p-8 text-center text-sm text-gray-400">未匹配到账户</td>
              </tr>
              <tr
                v-for="r in visibleRows"
                :key="r.id"
                class="border-b border-gray-50 hover:bg-gray-50 transition"
                :class="{ 'bg-blue-50/50': hasRowChange(r) }"
              >
                <td class="p-2">
                  <input type="checkbox" v-model="r.selected" class="w-4 h-4 accent-blue-600 cursor-pointer"/>
                </td>
                <td class="p-2">
                  <div class="font-medium text-gray-800 text-sm">{{ r.short_name || r.code || '—' }}</div>
                  <div class="text-[11px] text-gray-400">{{ r.code || '' }} · {{ categoryLabel(r.category) }}</div>
                </td>
                <td class="p-2 text-right">
                  <span :class="Number(r.balance) >= 0 ? 'text-green-600' : 'text-red-500'">
                    ¥{{ Number(r.balance || 0).toFixed(2) }}
                  </span>
                </td>
                <td class="p-2 text-right text-gray-600">
                  ¥{{ Number(r.opening_balance || 0).toFixed(2) }}
                </td>
                <td class="p-2 text-right">
                  <input
                    v-model.number="r.newOpening"
                    type="number"
                    step="0.01"
                    class="w-full px-2 py-1 border rounded text-right text-sm outline-none focus:ring-1 focus:ring-blue-400"
                    :class="hasRowChange(r) ? 'border-blue-300 bg-blue-50/70' : 'border-gray-200'"
                    :disabled="!r.selected || running"
                  />
                </td>
                <td class="p-2 text-center">
                  <input
                    type="checkbox"
                    v-model="r.syncBalance"
                    :disabled="!r.selected || running"
                    class="w-4 h-4 accent-blue-600 cursor-pointer"
                  />
                </td>
                <td class="p-2 text-right text-xs" :class="rowDeltaClass(r)">
                  {{ rowDeltaText(r) }}
                </td>
                <td class="p-2 text-center">
                  <span v-if="r.status === 'pending'" class="text-xs text-gray-300">—</span>
                  <span v-else-if="r.status === 'running'" class="text-xs text-blue-500">…</span>
                  <span v-else-if="r.status === 'success'" class="text-xs text-green-500">✓</span>
                  <span v-else-if="r.status === 'error'" class="text-xs text-red-500" :title="r.error">✗</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 汇总 + Footer -->
        <div class="flex-shrink-0 border-t border-gray-100 px-5 py-3 bg-gray-50 space-y-2">
          <!-- 汇总 -->
          <div class="text-xs text-gray-600 flex items-center gap-4 flex-wrap">
            <span>共 <b class="text-gray-800">{{ rows.length }}</b> 个活跃账户</span>
            <span>已选 <b class="text-gray-800">{{ selectedCount }}</b></span>
            <span>有变更 <b class="text-blue-600">{{ changeCount }}</b> 行</span>
            <span v-if="changeCount > 0">合计 opening delta
              <b :class="totalDelta >= 0 ? 'text-green-600' : 'text-red-500'">
                {{ totalDelta >= 0 ? '+' : '' }}{{ totalDelta.toFixed(2) }}
              </b>
            </span>
            <span v-if="running" class="ml-auto text-blue-500">
              处理中 {{ progress.done }} / {{ progress.total }}
            </span>
            <span v-else-if="lastSummary" class="ml-auto text-gray-500">
              上次：✓ {{ lastSummary.ok }} · ✗ {{ lastSummary.fail }}
            </span>
          </div>

          <!-- 按钮 -->
          <div class="flex justify-end gap-3">
            <button
              @click="handleClose"
              :disabled="running"
              class="px-4 py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer disabled:opacity-50"
            >取消</button>
            <button
              @click="handleSave"
              :disabled="running || !changeCount"
              class="px-5 py-2 text-sm text-white rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              :class="running ? 'bg-gray-400' : 'bg-blue-600 hover:bg-blue-700'"
            >
              {{ running ? '保存中…' : `保存 (${changeCount})` }}
            </button>
          </div>
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
})
const emit = defineEmits(['close', 'saved'])

const authStore = useAuthStore()
const accountStore = useAccountStore()

// ────────────────────────────────────────────────
// 状态
// ────────────────────────────────────────────────
const rows = ref([])                 // [{ id, code, short_name, category, balance, opening_balance, newOpening, syncBalance, selected, status, error }]
const categoryFilter = ref('all')    // all | personal | company
const keyword = ref('')
const running = ref(false)
const progress = reactive({ done: 0, total: 0 })
const lastSummary = ref(null)

const filterOptions = [
  { label: '全部', value: 'all' },
  { label: '👤 个人', value: 'personal' },
  { label: '🏢 企业', value: 'company' },
]

// ────────────────────────────────────────────────
// 打开时初始化
// ────────────────────────────────────────────────
watch(() => props.visible, async (v) => {
  if (!v) return
  // 强刷账户，保证 balance/opening_balance 最新
  try {
    accountStore._forceRefresh = true
    await accountStore.fetchAccounts()
  } catch (e) {
    console.warn('[BatchOpening] 加载账户失败', e?.message || e)
  }
  // 只处理活跃账户
  const active = (accountStore.accounts || []).filter(a => a.status === 'active')
  rows.value = active.map(a => reactive({
    id: a.id,
    code: a.code || '',
    short_name: a.short_name || '',
    category: a.category || '',
    balance: Number(a.balance || 0),
    opening_balance: Number(a.opening_balance || 0),
    newOpening: Number(a.opening_balance || 0),   // 默认与当前期初一致（= 无变更）
    syncBalance: true,
    selected: true,
    status: 'pending',
    error: '',
  }))
  progress.done = 0
  progress.total = 0
  lastSummary.value = null
})

// ────────────────────────────────────────────────
// 衍生状态
// ────────────────────────────────────────────────
const visibleRows = computed(() => {
  const kw = keyword.value.trim().toLowerCase()
  return rows.value.filter(r => {
    if (categoryFilter.value !== 'all' && r.category !== categoryFilter.value) return false
    if (kw) {
      const hay = `${r.code} ${r.short_name}`.toLowerCase()
      if (!hay.includes(kw)) return false
    }
    return true
  })
})

const allSelected = computed(() =>
  visibleRows.value.length > 0 && visibleRows.value.every(r => r.selected)
)
const allSync = computed(() =>
  visibleRows.value.length > 0 && visibleRows.value.every(r => r.syncBalance)
)

const selectedCount = computed(() => rows.value.filter(r => r.selected).length)

function hasRowChange(r) {
  if (!r.selected) return false
  const v = Number(r.newOpening || 0)
  if (Math.abs(v - r.opening_balance) > 0.005) return true
  if (r.syncBalance && Math.abs(v - r.balance) > 0.005) return true
  return false
}

const changeCount = computed(() => rows.value.filter(hasRowChange).length)

const totalDelta = computed(() =>
  rows.value
    .filter(hasRowChange)
    .reduce((s, r) => s + (Number(r.newOpening || 0) - r.opening_balance), 0)
)

function rowDelta(r) {
  return Number(r.newOpening || 0) - r.opening_balance
}
function rowDeltaText(r) {
  if (!hasRowChange(r)) return ''
  const d = rowDelta(r)
  return (d >= 0 ? '+' : '') + d.toFixed(2)
}
function rowDeltaClass(r) {
  if (!hasRowChange(r)) return 'text-gray-300'
  return rowDelta(r) >= 0 ? 'text-green-600' : 'text-red-500'
}

function categoryLabel(c) {
  if (c === 'personal') return '个人'
  if (c === 'company') return '企业'
  return c || '—'
}

// ────────────────────────────────────────────────
// 勾选 / 快捷填充
// ────────────────────────────────────────────────
function toggleAllSelected(e) {
  const v = !!e.target.checked
  visibleRows.value.forEach(r => { r.selected = v })
}
function toggleAllSync(e) {
  const v = !!e.target.checked
  visibleRows.value.forEach(r => { r.syncBalance = v })
}
function quickFillBalance() {
  visibleRows.value.forEach(r => { if (r.selected) r.newOpening = Number(r.balance || 0) })
}
function quickFillOpening() {
  visibleRows.value.forEach(r => { if (r.selected) r.newOpening = Number(r.opening_balance || 0) })
}
function quickFillZero() {
  visibleRows.value.forEach(r => { if (r.selected) r.newOpening = 0 })
}

// ────────────────────────────────────────────────
// 保存（逐行执行 + 进度回显）
// ────────────────────────────────────────────────
async function handleSave() {
  if (!authStore.isFinance) { toast('无权限', 'error'); return }
  const pending = rows.value.filter(hasRowChange)
  if (!pending.length) { toast('没有需要保存的行', 'info'); return }

  // 二次确认
  const summary = pending.slice(0, 10)
    .map(r => `  · ${r.short_name || r.code}：¥${r.opening_balance.toFixed(2)} → ¥${Number(r.newOpening).toFixed(2)}${r.syncBalance ? ' (同步 balance)' : ''}`)
    .join('\n')
  const more = pending.length > 10 ? `\n  …… 以及其余 ${pending.length - 10} 行` : ''
  const confirmMsg =
    `将更新 ${pending.length} 个账户的期初余额：\n\n${summary}${more}\n\n` +
    `合计 opening delta ${totalDelta.value >= 0 ? '+' : ''}${totalDelta.value.toFixed(2)}\n\n` +
    `继续？`
  if (!window.confirm(confirmMsg)) return

  const phrase = window.prompt('最终确认：请输入"确认批量"四个字以继续。')
  if (phrase !== '确认批量') {
    toast('已取消（确认短语不匹配）', 'info')
    return
  }

  running.value = true
  progress.total = pending.length
  progress.done = 0
  let okCount = 0
  let failCount = 0

  // 重置状态
  pending.forEach(r => { r.status = 'pending'; r.error = '' })

  // 动态加载 logger
  let logOperation = null
  try {
    const mod = await import('../utils/operationLogger')
    logOperation = mod.logOperation
  } catch (e) {
    console.warn('[BatchOpening] 加载 operationLogger 失败（忽略）', e?.message || e)
  }

  for (const r of pending) {
    r.status = 'running'
    const oldOpening = r.opening_balance
    const oldBalance = r.balance
    const newOpening = Number(r.newOpening || 0)

    try {
      // 1) UPDATE opening_balance
      const { error: updErr } = await supabase
        .from('accounts')
        .update({ opening_balance: newOpening })
        .eq('id', r.id)
      if (updErr) throw updErr

      // 2) 同步 balance
      let balanceChanged = false
      if (r.syncBalance && Math.abs(newOpening - oldBalance) > 0.005) {
        const delta = newOpening - oldBalance
        try {
          await accountStore.updateBalance(
            r.id, delta,
            '期初余额校准（批量）',
            'opening_balance',
            null
          )
          balanceChanged = true
        } catch (e) {
          // 回滚 opening_balance
          try {
            await supabase.from('accounts').update({ opening_balance: oldOpening }).eq('id', r.id)
          } catch (rbErr) {
            console.error('[BatchOpening] 回滚 opening_balance 失败', rbErr)
          }
          throw new Error(`同步 balance 失败：${e?.message || e}`)
        }
      }

      // 3) 写操作日志
      if (logOperation) {
        try {
          const nameLabel = r.short_name || r.code || r.id
          await logOperation({
            action: 'reset_opening_balance',
            module: '账户',
            description:
              `批量重设期初余额，${nameLabel}，` +
              `期初 ¥${oldOpening.toFixed(2)} → ¥${newOpening.toFixed(2)}` +
              (balanceChanged
                ? `；balance 同步 ¥${oldBalance.toFixed(2)} → ¥${newOpening.toFixed(2)}`
                : '；balance 未变'),
            detail: {
              account_id: r.id,
              account_name: nameLabel,
              old_opening_balance: oldOpening,
              new_opening_balance: newOpening,
              sync_balance: !!r.syncBalance,
              balance_changed: balanceChanged,
              old_balance: oldBalance,
              new_balance: balanceChanged ? newOpening : oldBalance,
              batch: true,
            },
            amount: Math.abs(newOpening - oldOpening),
            accountId: r.id,
            accountName: nameLabel,
            balanceBefore: oldBalance,
            balanceAfter: balanceChanged ? newOpening : oldBalance,
          })
        } catch (logErr) {
          console.warn('[BatchOpening] 写操作日志失败（忽略）', logErr?.message || logErr)
        }
      }

      // 同步行内状态（成功后用新值覆盖，避免二次点击又触发 change）
      r.opening_balance = newOpening
      if (r.syncBalance) r.balance = newOpening
      r.status = 'success'
      okCount += 1
    } catch (e) {
      r.status = 'error'
      r.error = e?.message || String(e)
      console.error(`[BatchOpening] ${r.short_name || r.code} 失败`, e)
      failCount += 1
    } finally {
      progress.done += 1
    }
  }

  lastSummary.value = { ok: okCount, fail: failCount }

  // 刷新账户
  try {
    accountStore._forceRefresh = true
    await accountStore.fetchAccounts()
  } catch (e) {
    console.warn('[BatchOpening] 刷新账户失败（忽略）', e?.message || e)
  }

  running.value = false

  if (failCount === 0) {
    toast(`全部成功：${okCount} 个账户已更新`, 'success', 4000)
    emit('saved', { ok: okCount, fail: 0 })
    emit('close')
  } else {
    toast(`完成：成功 ${okCount} · 失败 ${failCount}（失败行已在表格中标红，请核对）`, 'error', 6000)
    emit('saved', { ok: okCount, fail: failCount })
    // 不自动关闭，留窗口给用户查看错误
  }
}

function handleClose() {
  if (running.value) return
  emit('close')
}
</script>
