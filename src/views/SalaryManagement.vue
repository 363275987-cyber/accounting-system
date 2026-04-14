<!--
  工资发放管理 — SalaryManagement.vue

  Supabase salaries 表建表 SQL:

  CREATE TABLE salaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_name TEXT NOT NULL,
    position TEXT,
    base_salary NUMERIC(12,2),
    bonus NUMERIC(12,2) DEFAULT 0,
    deduction NUMERIC(12,2) DEFAULT 0,
    actual_amount NUMERIC(12,2) NOT NULL,
    pay_month TEXT NOT NULL,
    pay_date DATE,
    account_id UUID,
    note TEXT,
    recorded_by UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
  );

  CREATE INDEX idx_salaries_pay_month ON salaries(pay_month);
  CREATE INDEX idx_salaries_deleted_at ON salaries(deleted_at);
-->

<template>
  <div>
    <!-- 筛选栏 -->
    <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-3 mb-4 md:mb-6">
      <div class="flex items-center gap-3">
        <input
          type="month"
          v-model="filterMonth"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
        />
        <button
          @click="loadSalaries"
          class="px-3 py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer"
        >
          刷新
        </button>
      </div>
      <div class="flex items-center gap-2">
        <label
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer whitespace-nowrap"
        >
          📥 导入 Excel
          <input
            type="file"
            accept=".xlsx,.xls,.csv"
            class="hidden"
            @change="handleFileUpload"
          />
        </label>
      </div>
    </div>

    <!-- 汇总卡片 -->
    <div v-if="!tableError && salaries.length > 0" class="grid grid-cols-2 md:grid-cols-3 gap-3 mb-4 md:mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">发放人数</div>
        <div class="text-lg font-bold text-gray-800">{{ salaries.length }} 人</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4">
        <div class="text-xs text-gray-500 mb-1">实发总额</div>
        <div class="text-lg font-bold text-blue-600">{{ formatMoney(totalActual) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4 hidden md:block">
        <div class="text-xs text-gray-500 mb-1">基本工资总额</div>
        <div class="text-lg font-bold text-gray-700">{{ formatMoney(totalBase) }}</div>
      </div>
    </div>

    <!-- Excel 预览面板 -->
    <div v-if="previewData.length > 0" class="mb-4 md:mb-6">
      <div class="bg-white rounded-xl border border-blue-200 p-4 md:p-5">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-gray-700">
            📋 预览导入数据（{{ previewData.length }} 条）
          </h3>
          <div class="flex items-center gap-2">
            <button
              @click="previewData = []"
              class="text-sm text-gray-500 hover:text-gray-600 cursor-pointer"
            >
              取消
            </button>
            <button
              @click="confirmImport"
              :disabled="importing"
              class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ importing ? '导入中...' : '确认导入' }}
            </button>
          </div>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <span class="text-xs text-gray-500">发放月份：</span>
          <input
            type="month"
            v-model="importMonth"
            class="px-2 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-1 focus:ring-blue-500"
          />
        </div>
        <div class="overflow-x-auto -mx-4 md:-mx-5 px-4 md:px-5">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-gray-500 border-b border-gray-100">
                <th class="pb-2 pr-3 font-medium whitespace-nowrap">姓名</th>
                <th class="pb-2 pr-3 font-medium whitespace-nowrap">职位</th>
                <th class="pb-2 pr-3 font-medium text-right whitespace-nowrap">基本工资</th>
                <th class="pb-2 pr-3 font-medium text-right whitespace-nowrap">奖金</th>
                <th class="pb-2 pr-3 font-medium text-right whitespace-nowrap">扣款</th>
                <th class="pb-2 pr-3 font-medium text-right whitespace-nowrap">实发金额</th>
                <th class="pb-2 font-medium whitespace-nowrap">备注</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, i) in previewData" :key="i" class="border-b border-gray-50 hover:bg-gray-50">
                <td class="py-2 pr-3 whitespace-nowrap">{{ row.employee_name }}</td>
                <td class="py-2 pr-3 text-gray-500 whitespace-nowrap">{{ row.position || '-' }}</td>
                <td class="py-2 pr-3 text-right whitespace-nowrap">{{ formatMoney(row.base_salary) }}</td>
                <td class="py-2 pr-3 text-right text-green-600 whitespace-nowrap">{{ formatMoney(row.bonus) }}</td>
                <td class="py-2 pr-3 text-right text-red-500 whitespace-nowrap">{{ formatMoney(row.deduction) }}</td>
                <td class="py-2 pr-3 text-right font-medium whitespace-nowrap">{{ formatMoney(row.actual_amount) }}</td>
                <td class="py-2 text-gray-500 truncate max-w-[120px]">{{ row.note || '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- 工资列表 -->
    <div class="bg-white rounded-xl border border-gray-100">
      <!-- 加载中 -->
      <div v-if="loading" class="p-8 text-center text-gray-400 text-sm">加载中...</div>

      <!-- 表不存在提示 -->
      <div v-else-if="tableError" class="p-6 md:p-8">
        <div class="text-center">
          <div class="text-4xl mb-3">🗄️</div>
          <h3 class="text-sm font-semibold text-gray-700 mb-2">salaries 表尚未创建</h3>
          <p class="text-xs text-gray-500 mb-4">请在 Supabase 中执行以下 SQL 创建工资表：</p>
          <div class="bg-gray-50 rounded-lg p-4 text-left max-w-lg mx-auto">
            <pre class="text-xs text-gray-600 whitespace-pre-wrap font-mono leading-relaxed">CREATE TABLE salaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_name TEXT NOT NULL,
  position TEXT,
  base_salary NUMERIC(12,2),
  bonus NUMERIC(12,2) DEFAULT 0,
  deduction NUMERIC(12,2) DEFAULT 0,
  actual_amount NUMERIC(12,2) NOT NULL,
  pay_month TEXT NOT NULL,
  pay_date DATE,
  account_id UUID,
  note TEXT,
  recorded_by UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_salaries_pay_month ON salaries(pay_month);
CREATE INDEX idx_salaries_deleted_at ON salaries(deleted_at);</pre>
          </div>
        </div>
      </div>

      <!-- 空数据 -->
      <div v-else-if="salaries.length === 0" class="p-8 text-center">
        <div class="text-4xl mb-3">💰</div>
        <p class="text-sm text-gray-500">{{ filterMonth }} 暂无工资记录</p>
        <p class="text-xs text-gray-400 mt-1">点击「导入 Excel」上传工资表</p>
      </div>

      <!-- 数据表格 -->
      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-500 border-b border-gray-100">
              <th class="p-3 md:p-4 font-medium whitespace-nowrap">姓名</th>
              <th class="p-3 md:p-4 font-medium whitespace-nowrap">职位</th>
              <th class="p-3 md:p-4 font-medium text-right whitespace-nowrap">基本工资</th>
              <th class="p-3 md:p-4 font-medium text-right whitespace-nowrap hidden md:table-cell">奖金</th>
              <th class="p-3 md:p-4 font-medium text-right whitespace-nowrap hidden md:table-cell">扣款</th>
              <th class="p-3 md:p-4 font-medium text-right whitespace-nowrap">实发金额</th>
              <th class="p-3 md:p-4 font-medium whitespace-nowrap hidden lg:table-cell">月份</th>
              <th class="p-3 md:p-4 font-medium whitespace-nowrap hidden lg:table-cell">备注</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="item in salaries"
              :key="item.id"
              class="border-b border-gray-50 hover:bg-gray-50 transition"
            >
              <td class="p-3 md:p-4 whitespace-nowrap font-medium text-gray-800">{{ item.employee_name }}</td>
              <td class="p-3 md:p-4 text-gray-500 whitespace-nowrap">{{ item.position || '-' }}</td>
              <td class="p-3 md:p-4 text-right whitespace-nowrap">{{ formatMoney(item.base_salary) }}</td>
              <td class="p-3 md:p-4 text-right text-green-600 whitespace-nowrap hidden md:table-cell">{{ formatMoney(item.bonus) }}</td>
              <td class="p-3 md:p-4 text-right text-red-500 whitespace-nowrap hidden md:table-cell">{{ formatMoney(item.deduction) }}</td>
              <td class="p-3 md:p-4 text-right font-semibold text-blue-600 whitespace-nowrap">{{ formatMoney(item.actual_amount) }}</td>
              <td class="p-3 md:p-4 text-gray-500 whitespace-nowrap hidden lg:table-cell">{{ item.pay_month }}</td>
              <td class="p-3 md:p-4 text-gray-400 truncate max-w-[150px] hidden lg:table-cell">{{ item.note || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { formatMoney, toast } from '../lib/utils'

const authStore = useAuthStore()

// --- 状态 ---
const loading = ref(false)
const tableError = ref(false)
const salaries = ref([])
const previewData = ref([])
const importing = ref(false)

// 当前月份默认值
const now = new Date()
const defaultMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
const filterMonth = ref(defaultMonth)
const importMonth = ref(defaultMonth)

// --- 汇总计算 ---
const totalActual = computed(() =>
  salaries.value.reduce((sum, s) => sum + (Number(s.actual_amount) || 0), 0)
)
const totalBase = computed(() =>
  salaries.value.reduce((sum, s) => sum + (Number(s.base_salary) || 0), 0)
)

// --- 加载数据 ---
async function loadSalaries() {
  loading.value = true
  tableError.value = false
  try {
    const { data, error } = await supabase
      .from('salaries')
      .select('*')
      .is('deleted_at', null)
      .eq('pay_month', filterMonth.value)
      .order('created_at', { ascending: false })

    if (error) {
      // 表不存在时 Supabase 返回 42P01 或消息中包含 relation
      if (
        error.code === '42P01' ||
        error.message?.includes('relation') ||
        error.message?.includes('does not exist')
      ) {
        tableError.value = true
        salaries.value = []
      } else {
        throw error
      }
    } else {
      salaries.value = data || []
    }
  } catch (e) {
    console.error('加载工资数据失败:', e)
    toast('加载失败: ' + (e.message || '未知错误'), 'error')
    salaries.value = []
  } finally {
    loading.value = false
  }
}

// --- Excel 导入 ---
async function handleFileUpload(e) {
  const file = e.target.files?.[0]
  if (!file) return

  // 重置 file input 以便重复选同一文件
  e.target.value = ''

  let XLSX
  try {
    XLSX = await import('xlsx')
  } catch {
    toast('请先安装 xlsx 库: npm install xlsx', 'error')
    return
  }

  try {
    const buffer = await file.arrayBuffer()
    const workbook = XLSX.read(buffer, { type: 'array' })
    const sheetName = workbook.SheetNames[0]
    const sheet = workbook.Sheets[sheetName]
    const json = XLSX.utils.sheet_to_json(sheet, { defval: '' })

    if (json.length === 0) {
      toast('文件中没有数据', 'error')
      return
    }

    // 列名映射
    const colMap = {
      '姓名': 'employee_name',
      '职位': 'position',
      '基本工资': 'base_salary',
      '奖金': 'bonus',
      '扣款': 'deduction',
      '实发金额': 'actual_amount',
      '备注': 'note',
    }

    const parsed = json.map(row => {
      const mapped = {}
      for (const [cn, en] of Object.entries(colMap)) {
        mapped[en] = row[cn] !== undefined ? row[cn] : ''
      }
      // 数值字段转换
      mapped.base_salary = Number(mapped.base_salary) || 0
      mapped.bonus = Number(mapped.bonus) || 0
      mapped.deduction = Number(mapped.deduction) || 0
      mapped.actual_amount = Number(mapped.actual_amount) || 0
      return mapped
    })

    // 过滤掉无效行（没有姓名的）
    const valid = parsed.filter(r => r.employee_name && String(r.employee_name).trim())
    if (valid.length === 0) {
      toast('未找到有效数据，请确认 Excel 包含「姓名」列', 'error')
      return
    }

    previewData.value = valid
    toast(`已解析 ${valid.length} 条记录，请确认后导入`, 'info')
  } catch (err) {
    console.error('解析 Excel 失败:', err)
    toast('解析文件失败: ' + (err.message || '格式错误'), 'error')
  }
}

async function confirmImport() {
  if (previewData.value.length === 0) return
  if (!importMonth.value) {
    toast('请选择发放月份', 'error')
    return
  }

  importing.value = true
  try {
    const rows = previewData.value.map(r => ({
      employee_name: String(r.employee_name).trim(),
      position: r.position ? String(r.position).trim() : null,
      base_salary: r.base_salary,
      bonus: r.bonus,
      deduction: r.deduction,
      actual_amount: r.actual_amount,
      pay_month: importMonth.value,
      note: r.note ? String(r.note).trim() : null,
      recorded_by: authStore.user?.id || null,
    }))

    const { error } = await supabase.from('salaries').insert(rows)
    if (error) throw error

    toast(`成功导入 ${rows.length} 条工资记录`, 'success')
    previewData.value = []
    filterMonth.value = importMonth.value
    await loadSalaries()
  } catch (e) {
    console.error('导入失败:', e)
    if (e.code === '42P01' || e.message?.includes('relation')) {
      tableError.value = true
      toast('salaries 表不存在，请先创建表', 'error')
    } else {
      toast('导入失败: ' + (e.message || '未知错误'), 'error')
    }
  } finally {
    importing.value = false
  }
}

// --- 初始化 ---
onMounted(() => {
  loadSalaries()
})
</script>
