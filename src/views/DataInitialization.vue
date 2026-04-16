<template>
  <div class="max-w-5xl mx-auto pb-20">
    <!-- 非财务屏蔽 -->
    <div v-if="!auth.isFinance" class="text-center py-20 text-gray-500">
      <div class="text-5xl mb-3">🔒</div>
      <div class="text-sm">数据初始化仅对管理员和财务人员开放</div>
    </div>

    <template v-else>
      <!-- Header -->
      <div class="flex items-center justify-between mb-4 pt-2 flex-wrap gap-3">
        <h1 class="text-xl font-bold text-gray-800">⚠️ 数据初始化</h1>
        <div class="text-xs text-gray-400">仅财务/管理员可用 · 操作不可逆</div>
      </div>

      <!-- 红色警告横幅 -->
      <div class="bg-red-50 border border-red-200 rounded-2xl p-4 mb-4">
        <div class="flex items-start gap-3">
          <div class="text-2xl leading-none">🚨</div>
          <div class="flex-1 text-sm text-red-700 space-y-1.5">
            <div class="font-bold text-red-800">高危操作 · 不可逆</div>
            <div>本页用于在新财年或测试完成后<b>清空交易流水数据</b>，同时保留账户、员工、品类、产品等基础字典。</div>
            <ul class="list-disc pl-5 space-y-1 text-red-600">
              <li>清空后历史对账/报表将变空，<b>强烈建议先到 Supabase 后台做一次 pg_dump 备份</b>。</li>
              <li>账户表 accounts.balance 字段<b>不会</b>自动归零，清空完成后请到「余额对账/期初余额」页手动重设期初值。</li>
              <li>执行采用<b>软删</b>（UPDATE deleted_at = now()），不会物理删除；数据库管理员仍可在 SQL 里恢复。</li>
              <li>不涉及的表：accounts、profiles、expense_categories、products、employees、channel_assignments、warehouses 等字典数据。</li>
            </ul>
          </div>
        </div>
      </div>

      <!-- 控制条 -->
      <div class="bg-white rounded-2xl border border-gray-100 p-4 mb-4 flex items-center gap-3 flex-wrap">
        <button
          @click="refreshCounts"
          :disabled="counting"
          class="px-3 py-1.5 bg-gray-50 hover:bg-gray-100 border border-gray-200 rounded-lg text-xs text-gray-600 cursor-pointer transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{ counting ? '统计中…' : '🔄 重新统计' }}
        </button>
        <button
          @click="selectAll(true)"
          class="px-3 py-1.5 bg-gray-50 hover:bg-gray-100 border border-gray-200 rounded-lg text-xs text-gray-600 cursor-pointer transition"
        >全选</button>
        <button
          @click="selectAll(false)"
          class="px-3 py-1.5 bg-gray-50 hover:bg-gray-100 border border-gray-200 rounded-lg text-xs text-gray-600 cursor-pointer transition"
        >清空选择</button>
        <span class="text-xs text-gray-400 ml-auto">
          已选 <b class="text-gray-700">{{ selectedTables.length }}</b> 张表 ·
          将清空 <b class="text-red-600">{{ selectedRowCount }}</b> 条记录
        </span>
      </div>

      <!-- 模块列表 -->
      <div class="space-y-4">
        <div
          v-for="group in groups"
          :key="group.key"
          class="bg-white rounded-2xl border border-gray-100 p-4"
        >
          <div class="flex items-center justify-between mb-3">
            <div class="flex items-center gap-2">
              <span class="text-lg">{{ group.icon }}</span>
              <span class="font-semibold text-gray-800 text-sm">{{ group.label }}</span>
              <span class="text-xs text-gray-400">{{ group.hint }}</span>
            </div>
            <div class="flex gap-1">
              <button
                @click="toggleGroup(group, true)"
                class="text-xs text-gray-400 hover:text-gray-600 cursor-pointer transition px-2"
              >组内全选</button>
              <button
                @click="toggleGroup(group, false)"
                class="text-xs text-gray-400 hover:text-gray-600 cursor-pointer transition px-2"
              >组内清空</button>
            </div>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <label
              v-for="t in group.tables"
              :key="t.table"
              class="flex items-center gap-3 p-3 rounded-xl border text-sm transition cursor-pointer"
              :class="[
                t.supported
                  ? (selection[t.table] ? 'border-red-300 bg-red-50' : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50')
                  : 'border-gray-100 bg-gray-50 cursor-not-allowed opacity-60'
              ]"
            >
              <input
                type="checkbox"
                v-model="selection[t.table]"
                :disabled="!t.supported"
                class="w-4 h-4 accent-red-600"
              />
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-1.5 flex-wrap">
                  <span class="font-medium text-gray-800">{{ t.label }}</span>
                  <code class="text-[10px] text-gray-400 bg-gray-100 px-1 rounded">{{ t.table }}</code>
                  <span
                    v-if="!t.supported"
                    class="text-[10px] text-gray-500 bg-gray-200 px-1.5 py-0.5 rounded"
                  >{{ t.unsupportReason || '不支持软删 · 跳过' }}</span>
                </div>
                <div class="text-xs text-gray-500 mt-0.5">
                  当前有
                  <b
                    :class="(counts[t.table] || 0) > 0 ? 'text-gray-700' : 'text-gray-400'"
                  >{{ counts[t.table] == null ? '--' : counts[t.table] }}</b>
                  条
                </div>
              </div>
            </label>
          </div>
        </div>
      </div>

      <!-- 执行按钮 -->
      <div class="sticky bottom-3 mt-6">
        <div class="bg-white rounded-2xl border-2 border-red-200 p-4 shadow-lg flex items-center gap-3 flex-wrap">
          <div class="flex-1 min-w-0 text-sm">
            <div v-if="!selectedTables.length" class="text-gray-400">请勾选至少一个模块后才能执行。</div>
            <div v-else>
              即将清空：
              <span class="font-semibold text-red-600">{{ selectedTables.length }}</span> 张表，
              共 <span class="font-semibold text-red-600">{{ selectedRowCount }}</span> 条记录。
            </div>
          </div>
          <button
            @click="startPurge"
            :disabled="!selectedTables.length || running"
            class="px-5 py-2.5 rounded-lg text-sm font-semibold text-white transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            :class="running ? 'bg-gray-400' : 'bg-red-600 hover:bg-red-700'"
          >
            {{ running ? `清空中… ${progress.done}/${progress.total}` : '⚠️ 开始清空' }}
          </button>
        </div>
      </div>

      <!-- 进度日志 -->
      <div v-if="log.length" class="mt-4 bg-gray-900 text-gray-100 rounded-2xl p-4 font-mono text-xs space-y-1 max-h-80 overflow-auto">
        <div v-for="(line, i) in log" :key="i" :class="lineClass(line)">
          <span class="text-gray-500">[{{ line.ts }}]</span>
          {{ line.msg }}
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { reactive, ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { toast } from '../lib/utils'

/**
 * 数据初始化 —— 清空交易流水，保留基础数据
 *
 * 安全假设：
 * 1. 调用方必须是 auth.isFinance（admin/finance/manager）——路由已校验，UI 再兜底
 * 2. 数据库 RLS 对这些表的 update 权限应已对 finance 开放（历史上所有详情页都能软删）
 * 3. 绝不使用 DELETE FROM —— 全部用 UPDATE deleted_at = now()
 * 4. accounts / profiles / expense_categories / products / warehouses / suppliers 等字典不出现在清单中
 */

const auth = useAuthStore()
const accountStore = useAccountStore()

// ============================================================================
// 表清单（按业务模块分组）
// - supported: 该表是否有 deleted_at 列，能做软删
// - 没有 deleted_at 的表（如 account_transfers / balance_snapshots / operation_logs /
//   balance_change_logs / audit_logs / withdrawals）在此统一置灰并注明原因
// ============================================================================
const TABLE_GROUPS = [
  {
    key: 'transactions',
    icon: '💰',
    label: '交易流水',
    hint: '订单、支出、收入、退款等业务主流水',
    tables: [
      { table: 'orders',            label: '订单（含电商/线下）',    supported: true },
      { table: 'order_items',       label: '订单明细',              supported: true, dependent: 'orders' },
      { table: 'expenses',          label: '支出记录',              supported: true },
      { table: 'other_income',      label: '其他收入',              supported: true },
      { table: 'refunds',           label: '退款记录',              supported: true },
      { table: 'account_transfers', label: '账户转账',              supported: true },
      { table: 'withdrawals',       label: '电商提现',              supported: true },
    ],
  },
  {
    key: 'salary',
    icon: '🧾',
    label: '工资与分红',
    hint: '薪资、提成、分红流水',
    tables: [
      { table: 'salaries',            label: '工资记录',            supported: true },
      { table: 'commission_records',  label: '提成记录',            supported: true },
      { table: 'dividends',           label: '股东分红',            supported: true },
    ],
  },
  {
    key: 'ledger',
    icon: '📒',
    label: '财务台账',
    hint: '待摊、预付、应付、预收等台账',
    tables: [
      { table: 'deferred_expenses',   label: '长期待摊费用',        supported: true },
      { table: 'deferred_revenue',    label: '预收账款',            supported: true },
      { table: 'prepaid_accounts',    label: '预付账款',            supported: true },
      { table: 'payable_accounts',    label: '应付账款',            supported: true },
      { table: 'other_receivables',   label: '其他应收',            supported: true },
      { table: 'other_payables',      label: '其他应付',            supported: true },
      { table: 'intangible_assets',   label: '无形资产',            supported: true },
    ],
  },
  {
    key: 'balance',
    icon: '💳',
    label: '账户快照/日志',
    hint: '余额快照与变更日志 · 无 deleted_at，仅列出不可勾选',
    tables: [
      { table: 'balance_snapshots',    label: '月度余额快照',         supported: false, unsupportReason: '无 deleted_at · 清空后期末余额不可复现，请到「余额对账」手动处理' },
      { table: 'balance_change_logs',  label: '余额变更审批日志',     supported: false, unsupportReason: '无 deleted_at · 审计类表禁止批量清空' },
      { table: 'operation_logs',       label: '操作日志',             supported: false, unsupportReason: '无 deleted_at · 审计类表禁止批量清空' },
      { table: 'audit_logs',           label: '数据库审计日志',       supported: false, unsupportReason: '无 deleted_at · 审计类表禁止批量清空' },
    ],
  },
]

// ============================================================================
// 响应式状态
// ============================================================================
const groups = TABLE_GROUPS
const selection = reactive({})              // { table_name: boolean }
const counts    = reactive({})              // { table_name: number|null }
const counting  = ref(false)
const running   = ref(false)
const log       = ref([])
const progress  = reactive({ done: 0, total: 0 })

// 初始化勾选状态（默认全 false）
for (const g of TABLE_GROUPS) {
  for (const t of g.tables) selection[t.table] = false
}

const selectedTables = computed(() =>
  TABLE_GROUPS.flatMap(g => g.tables)
    .filter(t => t.supported && selection[t.table])
)

const selectedRowCount = computed(() =>
  selectedTables.value.reduce((s, t) => s + (Number(counts[t.table]) || 0), 0)
)

// ============================================================================
// 统计每张表当前条数（deleted_at IS NULL）
// ============================================================================
async function refreshCounts() {
  if (counting.value) return
  counting.value = true
  pushLog('info', '开始统计各表当前条数…')
  try {
    const tasks = []
    for (const g of TABLE_GROUPS) {
      for (const t of g.tables) {
        if (!t.supported) { counts[t.table] = null; continue }
        tasks.push((async () => {
          try {
            const { count, error } = await supabase
              .from(t.table)
              .select('id', { count: 'exact', head: true })
              .is('deleted_at', null)
            if (error) throw error
            counts[t.table] = count ?? 0
          } catch (e) {
            console.warn(`[DataInit] 统计 ${t.table} 失败`, e?.message || e)
            counts[t.table] = 0
            pushLog('warn', `统计 ${t.table} 失败：${e?.message || e}`)
          }
        })())
      }
    }
    await Promise.all(tasks)
    pushLog('success', '统计完成')
  } finally {
    counting.value = false
  }
}

// ============================================================================
// 勾选辅助
// ============================================================================
function selectAll(val) {
  for (const g of TABLE_GROUPS) {
    for (const t of g.tables) if (t.supported) selection[t.table] = val
  }
}
function toggleGroup(group, val) {
  for (const t of group.tables) if (t.supported) selection[t.table] = val
}

// ============================================================================
// 执行清空（三层防御）
// ============================================================================
async function startPurge() {
  if (!auth.isFinance) { toast('无权限', 'error'); return }
  const tables = selectedTables.value
  if (!tables.length) { toast('请至少勾选一张表', 'error'); return }

  // —— 第二层防御：confirm 列出清单 ——
  const summary = tables
    .map(t => `  · ${t.label}（${t.table}）：${counts[t.table] || 0} 条`)
    .join('\n')
  const confirmMsg =
    `即将软删以下 ${tables.length} 张表的数据：\n\n${summary}\n\n` +
    `合计 ${selectedRowCount.value} 条记录。\n\n` +
    `操作不可撤销（仅数据库侧可手动恢复）。\n继续？`
  if (!window.confirm(confirmMsg)) return

  // —— 第三层防御：要求手动输入「确认清空」 ——
  const phrase = window.prompt(
    '最终确认：请输入"确认清空"四个字后点击"确定"以继续。\n\n' +
    '任何其他输入将中止操作。'
  )
  if (phrase !== '确认清空') {
    toast('已取消（确认短语不匹配）', 'info')
    pushLog('warn', `用户输入 "${phrase ?? ''}"，与 "确认清空" 不匹配，已中止`)
    return
  }

  // —— 开始执行 ——
  running.value = true
  progress.total = tables.length
  progress.done = 0
  const startTs = new Date().toISOString()
  const executed = []  // 已软删的表，出错时回滚
  pushLog('info', `开始清空，起始时间戳 ${startTs}`)

  try {
    for (const t of tables) {
      pushLog('info', `→ 正在清空 ${t.label}（${t.table}）…`)
      const { error, count } = await supabase
        .from(t.table)
        .update({ deleted_at: startTs }, { count: 'exact' })
        .is('deleted_at', null)
      if (error) {
        pushLog('error', `❌ ${t.table} 清空失败：${error.message}`)
        throw new Error(`${t.label}（${t.table}）清空失败：${error.message}`)
      }
      executed.push(t.table)
      progress.done += 1
      pushLog('success', `✅ ${t.table} 完成，影响 ${count ?? '?'} 行`)
      toast(`已清空 ${t.label} (${progress.done}/${progress.total})`, 'success', 1200)
    }

    // —— 审计日志（尝试写入 audit_logs，失败不影响主流程）——
    try {
      await supabase.from('audit_logs').insert({
        action: 'data_initialization_purge',
        table_name: 'multi',
        new_data: {
          ts: startTs,
          operator: auth.profile?.name || auth.profile?.email,
          role: auth.profile?.role,
          tables: executed,
          total_rows: selectedRowCount.value,
        },
      })
    } catch (e) {
      console.warn('[DataInit] 写入 audit_logs 失败（可忽略）', e?.message || e)
    }
    console.info('[DataInit] 清空完成', {
      ts: startTs,
      operator: auth.profile?.name,
      tables: executed,
      total_rows: selectedRowCount.value,
    })

    pushLog('success', `🎉 全部完成！共清空 ${executed.length} 张表、${selectedRowCount.value} 条记录`)
    toast(`清空完成：${executed.length} 张表 / ${selectedRowCount.value} 条`, 'success', 5000)

    // 刷新账户，并提示用户余额未自动归零
    try { accountStore._forceRefresh = true; await accountStore.fetchAccounts() } catch (e) { console.warn("[silent catch]", e?.message || e) }
    setTimeout(() => {
      window.alert(
        '交易流水已清空。\n\n' +
        '⚠️ accounts.balance 字段未自动归零，请前往：\n' +
        '「资金管理 → 账户管理」，在每个账户行点击「📌 期初」按钮\n' +
        '逐一重设期初余额（记得勾选"同步 balance"以重建当前余额）。'
      )
    }, 500)

    // 刷新计数
    await refreshCounts()
    // 重置勾选
    selectAll(false)
  } catch (e) {
    pushLog('error', `操作中断：${e?.message || e}`)
    if (executed.length) {
      pushLog('warn', `尝试回滚已软删的 ${executed.length} 张表（deleted_at = ${startTs}）…`)
      await rollback(executed, startTs)
    }
    toast(`清空失败：${e?.message || e}`, 'error', 5000)
  } finally {
    running.value = false
  }
}

async function rollback(tables, ts) {
  for (const name of tables) {
    try {
      const { error } = await supabase
        .from(name)
        .update({ deleted_at: null })
        .eq('deleted_at', ts)
      if (error) throw error
      pushLog('success', `↩ 已回滚 ${name}`)
    } catch (e) {
      pushLog('error', `回滚 ${name} 失败：${e?.message || e}（请联系 DBA）`)
    }
  }
}

// ============================================================================
// 日志工具
// ============================================================================
function pushLog(level, msg) {
  const ts = new Date().toLocaleTimeString('zh-CN', { hour12: false })
  log.value.push({ level, ts, msg })
  // 控制台镜像
  const fn = level === 'error' ? console.error : level === 'warn' ? console.warn : console.info
  fn(`[DataInit] ${msg}`)
}
function lineClass(line) {
  return {
    error:   'text-red-400',
    warn:    'text-yellow-300',
    success: 'text-green-300',
    info:    'text-gray-300',
  }[line.level] || 'text-gray-300'
}

// ============================================================================
// 初始化
// ============================================================================
onMounted(() => {
  refreshCounts()
})
</script>
