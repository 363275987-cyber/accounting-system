<template>
  <div class="max-w-6xl mx-auto pb-20">
    <!-- 非财务屏蔽 -->
    <div v-if="!auth.isFinance" class="text-center py-20 text-gray-500">
      <div class="text-5xl mb-3">🔒</div>
      <div class="text-sm">工资管理仅对管理员和财务人员开放</div>
    </div>

    <template v-else>
      <div class="flex items-center justify-between mb-4 pt-2">
        <h1 class="text-xl font-bold text-gray-800">💼 工资管理</h1>
        <!-- Tab 切换 -->
        <div class="inline-flex bg-gray-100 rounded-lg p-1 text-sm">
          <button
            @click="viewMode = 'monthly'"
            :class="viewMode === 'monthly' ? 'bg-white text-gray-800 shadow-sm' : 'text-gray-500 hover:text-gray-700'"
            class="px-3 py-1.5 rounded-md cursor-pointer transition-all"
          >📅 按月管理</button>
          <button
            @click="switchToYearly"
            :class="viewMode === 'yearly' ? 'bg-white text-gray-800 shadow-sm' : 'text-gray-500 hover:text-gray-700'"
            class="px-3 py-1.5 rounded-md cursor-pointer transition-all"
          >📊 年度看板</button>
        </div>
      </div>

      <!-- ═══════════ 年度看板 ═══════════ -->
      <div v-if="viewMode === 'yearly'">
        <div class="bg-white rounded-2xl border border-gray-100 p-4 mb-3 flex items-center gap-3 flex-wrap">
          <label class="text-sm text-gray-600">年度</label>
          <select
            v-model="yearPick"
            @change="loadYearData"
            class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option v-for="y in yearOptions" :key="y" :value="y">{{ y }} 年</option>
          </select>
          <span class="text-xs text-gray-500 ml-2">
            {{ yearLoading ? '加载中...' : `共 ${yearSummary.employeeCount} 人 · 全年应发 ${formatMoney(yearSummary.totalAccrued)} · 实发 ${formatMoney(yearSummary.totalPaid)}` }}
          </span>
        </div>

        <!-- 月度趋势条形图 -->
        <div class="bg-white rounded-2xl border border-gray-100 p-4 mb-3">
          <div class="text-sm font-medium text-gray-700 mb-3">📈 {{ yearPick }} 年月度趋势</div>
          <div v-if="yearLoading" class="text-xs text-gray-400 py-8 text-center">加载中...</div>
          <div v-else class="grid grid-cols-12 gap-1 h-40 items-end">
            <div
              v-for="(m, idx) in yearData.monthly"
              :key="idx"
              class="relative group cursor-pointer"
              @click="drillToMonth(idx + 1)"
            >
              <div
                class="bg-blue-500 hover:bg-blue-600 rounded-t transition-all"
                :style="{ height: yearChartHeight(m.accrued) + '%' }"
                :title="`${idx + 1} 月：应发 ${formatMoney(m.accrued)}，实发 ${formatMoney(m.paid)}，${m.count} 人`"
              ></div>
              <div class="text-center text-xs text-gray-500 mt-1">{{ idx + 1 }}月</div>
              <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:block bg-gray-800 text-white text-xs rounded px-2 py-1 whitespace-nowrap z-10">
                <div>应发 {{ formatMoney(m.accrued) }}</div>
                <div>实发 {{ formatMoney(m.paid) }}</div>
                <div>{{ m.count }} 人</div>
              </div>
            </div>
          </div>
          <p class="text-xs text-gray-400 mt-3">💡 点击柱子可以跳到对应月份详情</p>
        </div>

        <!-- 员工全年汇总表 -->
        <div class="bg-white rounded-2xl border border-gray-100 overflow-hidden mb-3">
          <div class="px-4 py-3 border-b border-gray-100 text-sm font-medium text-gray-700 flex items-center justify-between gap-3 flex-wrap">
            <span class="flex items-center gap-2">
              👥 员工全年汇总
              <span v-if="yearDuplicateGroups.length > 0" class="text-xs text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full" :title="yearDuplicateGroups.map(g => g.join('/')).join('；')">
                ⚠ 疑似同一人被拆分：{{ yearDuplicateGroups.length }} 组
              </span>
            </span>
            <div class="flex items-center gap-2">
              <input
                v-model="yearEmpSearch"
                type="text"
                placeholder="🔍 搜姓名"
                class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-2 focus:ring-blue-500 w-40"
              />
              <button
                v-if="yearData.byEmployee.length > 0"
                @click="exportYearCsv"
                class="text-xs text-blue-600 hover:text-blue-700 cursor-pointer"
              >📥 导出 CSV</button>
            </div>
          </div>
          <div v-if="yearLoading" class="py-8 text-center text-xs text-gray-400">加载中...</div>
          <div v-else-if="yearData.byEmployee.length === 0" class="py-12 text-center text-sm text-gray-400">
            {{ yearPick }} 年暂无工资记录
          </div>
          <div v-else-if="filteredYearEmployees.length === 0" class="py-12 text-center text-sm text-gray-400">
            没有匹配"{{ yearEmpSearch }}"的员工
          </div>
          <div v-else class="overflow-x-auto">
            <table class="min-w-full text-sm">
              <thead class="bg-gray-50 text-xs text-gray-600">
                <tr>
                  <th class="px-3 py-2 text-left sticky left-0 bg-gray-50 z-10">姓名</th>
                  <th v-for="m in 12" :key="m" class="px-2 py-2 text-right whitespace-nowrap">{{ m }}月</th>
                  <th class="px-3 py-2 text-right font-semibold whitespace-nowrap">合计</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="emp in filteredYearEmployees" :key="emp.name" class="border-t border-gray-50 hover:bg-gray-50" :class="emp._likelyDup ? 'bg-orange-50/50' : ''">
                  <td class="px-3 py-2 sticky left-0 bg-white hover:bg-gray-50 font-medium text-gray-700" :class="emp._likelyDup ? 'bg-orange-50/50 hover:bg-orange-100/50' : ''">
                    <span>{{ emp.name }}</span>
                    <span v-if="emp._likelyDup" class="ml-1 text-[10px] text-orange-600" :title="'疑似与其他行同一人：' + emp._dupPeers.join('、')">⚠</span>
                  </td>
                  <td v-for="(amt, mi) in emp.months" :key="mi" class="px-2 py-2 text-right font-mono text-xs" :class="amt > 0 ? 'text-gray-700' : 'text-gray-300'">
                    {{ amt > 0 ? amt.toFixed(0) : '-' }}
                  </td>
                  <td class="px-3 py-2 text-right font-mono font-semibold text-gray-800">{{ emp.total.toFixed(2) }}</td>
                </tr>
                <tr class="border-t-2 border-gray-200 bg-gray-50 font-semibold">
                  <td class="px-3 py-2 sticky left-0 bg-gray-50">合计</td>
                  <td v-for="(mt, mi) in yearData.monthly" :key="mi" class="px-2 py-2 text-right font-mono text-xs text-gray-700">{{ mt.accrued > 0 ? mt.accrued.toFixed(0) : '-' }}</td>
                  <td class="px-3 py-2 text-right font-mono text-gray-800">{{ yearSummary.totalAccrued.toFixed(2) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- ═══════════ 按月管理（原有 UI） ═══════════ -->
      <div v-else>

      <!-- 月份选择 + 操作区 -->
      <div class="bg-white rounded-2xl border border-gray-100 p-4 mb-3">
        <div class="flex items-center justify-between flex-wrap gap-3">
          <div class="flex items-center gap-3">
            <label class="text-sm text-gray-600">应发月份</label>
            <input
              v-model="payMonth"
              type="month"
              class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              @change="loadSalaries"
            />
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <button
              @click="copyLastMonth"
              :disabled="copying"
              class="px-3 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-40 cursor-pointer"
              title="把上月的工资名单复制到本月(剔除本月已存在的)"
            >{{ copying ? '复制中...' : '📋 复制上月' }}</button>
            <button
              @click="downloadTemplate"
              class="px-3 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer"
              title="下载 Excel 导入模板"
            >📥 下载模板</button>
            <label class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
              📤 上传 Excel
              <input ref="fileInput" type="file" accept=".xlsx,.xls" class="hidden" @change="handleFile" />
            </label>
            <button
              @click="openCreateModal"
              class="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 cursor-pointer"
            >+ 手动添加</button>
            <button
              v-if="records.length > 0"
              @click="exportMonthCsv"
              class="px-3 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer"
              title="把当前月份工资导出为 CSV"
            >📥 导出 CSV</button>
          </div>
        </div>
        <p class="text-xs text-gray-500 mt-2">
          ⚠️ 工资按"应发月份"权责发生制计提到当月利润表；实发请点右侧"发放"扣账户余额。
        </p>
      </div>

      <!-- F: 统计卡片 4 格 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
        <div
          @click="applyCardFilter('all')"
          class="bg-white rounded-2xl border p-4 cursor-pointer transition-all"
          :class="cardFilter === 'all' ? 'border-blue-400 ring-2 ring-blue-100' : 'border-gray-100 hover:border-gray-200'"
        >
          <div class="text-xs text-gray-500 mb-1">本月应发 {{ cardFilter === 'all' ? '✓' : '' }}</div>
          <div class="text-xl font-bold text-blue-600">{{ formatMoney(stats.accrued) }}</div>
          <div class="text-xs text-gray-400 mt-1">{{ records.length }} 人</div>
        </div>
        <div
          @click="applyCardFilter('paid')"
          class="bg-white rounded-2xl border p-4 cursor-pointer transition-all"
          :class="cardFilter === 'paid' ? 'border-green-400 ring-2 ring-green-100' : 'border-gray-100 hover:border-gray-200'"
        >
          <div class="text-xs text-gray-500 mb-1">已发放 {{ cardFilter === 'paid' ? '✓' : '' }}</div>
          <div class="text-xl font-bold text-green-600">{{ formatMoney(stats.paid) }}</div>
          <div class="text-xs text-gray-400 mt-1">{{ stats.paidCount }} 人</div>
        </div>
        <div
          @click="applyCardFilter('pending')"
          class="bg-white rounded-2xl border p-4 cursor-pointer transition-all"
          :class="cardFilter === 'pending' ? 'border-yellow-400 ring-2 ring-yellow-100' : 'border-gray-100 hover:border-gray-200'"
        >
          <div class="text-xs text-gray-500 mb-1">未发放 {{ cardFilter === 'pending' ? '✓' : '' }}</div>
          <div class="text-xl font-bold text-yellow-600">{{ formatMoney(stats.pending) }}</div>
          <div class="text-xs text-gray-400 mt-1">{{ stats.pendingCount }} 人</div>
        </div>
        <div
          @click="applyCardFilter('overdue')"
          class="bg-white rounded-2xl border p-4 cursor-pointer transition-all"
          :class="cardFilter === 'overdue' ? 'border-red-400 ring-2 ring-red-100' : 'border-gray-100 hover:border-gray-200'"
          title="规则:次月 15 号前发上月工资,过了 15 号还未发算欠发"
        >
          <div class="text-xs text-gray-500 mb-1">欠发(过期) {{ cardFilter === 'overdue' ? '✓' : '' }}</div>
          <div class="text-xl font-bold" :class="stats.overdue > 0 ? 'text-red-600' : 'text-gray-400'">{{ formatMoney(stats.overdue) }}</div>
          <div class="text-xs text-gray-400 mt-1">{{ stats.overdueCount }} 人 · 次月 15 号后未发</div>
        </div>
      </div>

      <!-- E: 搜索 + 状态筛选 -->
      <div class="bg-white rounded-2xl border border-gray-100 p-3 mb-3 flex items-center gap-3 flex-wrap">
        <input
          v-model="search"
          type="text"
          placeholder="🔍 搜索姓名或备注"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 w-64"
        />
        <select
          v-model="statusFilter"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="all">全部状态</option>
          <option value="paid">已发放</option>
          <option value="pending">未发放</option>
        </select>
        <span class="text-xs text-gray-500 ml-auto">显示 {{ displayedRecords.length }} / {{ records.length }}</span>
      </div>

      <!-- C: 批量操作浮条 -->
      <div
        v-if="selectedIds.size > 0"
        class="bg-blue-50 border border-blue-200 rounded-2xl p-3 mb-3 flex items-center gap-3 flex-wrap"
      >
        <span class="text-sm text-blue-800 font-medium">已选 {{ selectedIds.size }} 条</span>
        <button
          @click="openPayModalBatch"
          class="px-3 py-1.5 bg-green-600 text-white rounded-lg text-xs hover:bg-green-700 cursor-pointer"
        >💰 批量发放</button>
        <button
          @click="batchPayslip"
          class="px-3 py-1.5 bg-purple-600 text-white rounded-lg text-xs hover:bg-purple-700 cursor-pointer"
        >🧾 批量工资条</button>
        <button
          @click="batchDelete"
          class="px-3 py-1.5 bg-red-500 text-white rounded-lg text-xs hover:bg-red-600 cursor-pointer"
        >🗑 批量删除</button>
        <button
          @click="clearSelection"
          class="px-3 py-1.5 border border-gray-200 bg-white rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer"
        >取消选择</button>
      </div>

      <!-- 撤销删除浮条 -->
      <div
        v-if="pendingUndo"
        class="bg-amber-50 border border-amber-200 rounded-2xl p-3 mb-3 flex items-center gap-3"
      >
        <span class="text-sm text-amber-800">
          🗑 已删除{{ pendingUndo.kind === 'batch' ? ` ${pendingUndo.rows.length} 条` : ` ${pendingUndo.rows[0]?.employee_name || ''} 的工资` }}
          <span v-if="pendingUndo.refunds && pendingUndo.refunds.length > 0" class="text-xs text-amber-700 ml-1">
            · 退回 ¥{{ pendingUndo.refunds.reduce((s, r) => s + Number(r.amount || 0), 0).toFixed(2) }}
          </span>
          <span class="text-xs text-amber-600 ml-1">({{ undoSecondsLeft }}s 内可撤销)</span>
        </span>
        <button
          @click="undoDelete"
          class="ml-auto px-3 py-1.5 bg-amber-600 text-white rounded-lg text-xs hover:bg-amber-700 cursor-pointer"
        >↩ 撤销</button>
      </div>

      <!-- 加载错误展示(便于 debug) -->
      <div v-if="loadError" class="bg-red-50 border border-red-200 rounded-2xl p-3 mb-3 text-sm">
        <div class="font-medium text-red-700 mb-1">⚠️ 加载工资数据失败</div>
        <div class="text-xs text-red-600 font-mono break-all">{{ loadError }}</div>
        <button @click="loadSalaries" class="mt-2 px-3 py-1 bg-red-500 text-white rounded text-xs hover:bg-red-600 cursor-pointer">重试</button>
      </div>

      <!-- 工资列表 -->
      <div class="bg-white rounded-2xl border border-gray-100 overflow-hidden">
        <Skeleton v-if="loading" type="table" :rows="6" :columns="8" />
        <table v-else class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-600">
              <th class="px-3 py-3 w-8 text-center">
                <input
                  ref="headCheckbox"
                  type="checkbox"
                  :checked="allSelected"
                  @change="toggleAll"
                  class="cursor-pointer"
                />
              </th>
              <th class="px-4 py-3 text-left font-medium cursor-pointer select-none" @click="toggleSort('employee_name')">
                员工姓名 <span class="text-xs text-gray-400">{{ sortIndicator('employee_name') }}</span>
              </th>
              <th class="px-4 py-3 text-right font-medium cursor-pointer select-none" @click="toggleSort('base_salary')">
                基本工资 <span class="text-xs text-gray-400">{{ sortIndicator('base_salary') }}</span>
              </th>
              <th class="px-4 py-3 text-right font-medium cursor-pointer select-none" @click="toggleSort('actual_amount')">
                实发金额 <span class="text-xs text-gray-400">{{ sortIndicator('actual_amount') }}</span>
              </th>
              <th class="px-4 py-3 text-center font-medium">应发月份</th>
              <th class="px-4 py-3 text-center font-medium">实际发薪</th>
              <th class="px-4 py-3 text-center font-medium">状态</th>
              <th class="px-4 py-3 text-center font-medium">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in displayedRecords"
              :key="row.id"
              class="border-t border-gray-50 hover:bg-gray-50/60"
              :class="selectedIds.has(row.id) ? 'bg-blue-50/60' : ''"
            >
              <td class="px-3 py-3 text-center">
                <input
                  type="checkbox"
                  :checked="selectedIds.has(row.id)"
                  @change="toggleSelect(row.id)"
                  class="cursor-pointer"
                />
              </td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ row.employee_name }}</td>
              <td class="px-4 py-3 text-right text-gray-600 cursor-text" @dblclick="startInlineEdit(row, 'base_salary')" :title="baseSalaryTooltip(row)">
                <template v-if="inlineEdit && inlineEdit.rowId === row.id && inlineEdit.field === 'base_salary'">
                  <input
                    ref="inlineInputRef"
                    v-model.number="inlineEdit.value"
                    type="number"
                    step="0.01"
                    class="w-24 px-2 py-1 border border-blue-300 rounded text-sm text-right outline-none focus:ring-2 focus:ring-blue-400"
                    @keydown.enter.prevent="commitInlineEdit"
                    @keydown.esc.prevent="cancelInlineEdit"
                    @blur="commitInlineEdit"
                  />
                </template>
                <template v-else>
                  {{ formatMoney(computedBaseSalary(row)) }}
                  <span v-if="baseSalaryExtras(row) > 0" class="block text-[10px] text-gray-400 leading-tight">底薪 {{ formatMoney(row.base_salary || 0) }}</span>
                </template>
              </td>
              <td class="px-4 py-3 text-right font-semibold text-blue-600 cursor-text" @dblclick="startInlineEdit(row, 'actual_amount')" title="双击修改">
                <template v-if="inlineEdit && inlineEdit.rowId === row.id && inlineEdit.field === 'actual_amount'">
                  <input
                    ref="inlineInputRef"
                    v-model.number="inlineEdit.value"
                    type="number"
                    step="0.01"
                    class="w-24 px-2 py-1 border border-blue-300 rounded text-sm text-right outline-none focus:ring-2 focus:ring-blue-400"
                    @keydown.enter.prevent="commitInlineEdit"
                    @keydown.esc.prevent="cancelInlineEdit"
                    @blur="commitInlineEdit"
                  />
                </template>
                <template v-else>{{ formatMoney(row.actual_amount) }}</template>
              </td>
              <td class="px-4 py-3 text-center text-gray-500">{{ row.pay_month || '--' }}</td>
              <td class="px-4 py-3 text-center text-xs text-gray-500">
                {{ row.pay_date ? formatDate(row.pay_date, 'date') : '未发放' }}
                <div v-if="row.pay_date && row.account_id" class="text-[10px] text-gray-400">
                  {{ getAccountName(row.account_id) }}
                </div>
              </td>
              <td class="px-4 py-3 text-center">
                <span
                  class="inline-block px-2 py-0.5 rounded text-xs"
                  :class="rowStatusClass(row)"
                >{{ rowStatusLabel(row) }}</span>
              </td>
              <td class="px-4 py-3 text-center whitespace-nowrap">
                <button
                  v-if="!row.pay_date"
                  @click="openPayModal(row)"
                  class="text-green-600 hover:text-green-700 text-xs mr-2 cursor-pointer"
                >发放</button>
                <button @click="openPayslipModal([row])" class="text-purple-600 hover:text-purple-700 text-xs mr-2 cursor-pointer" title="生成可打印的工资条">工资条</button>
                <button @click="openEditModal(row)" class="text-blue-600 hover:text-blue-700 text-xs mr-2 cursor-pointer">编辑</button>
                <button @click="handleDelete(row)" class="text-red-400 hover:text-red-600 text-xs cursor-pointer">删除</button>
              </td>
            </tr>
            <tr v-if="displayedRecords.length === 0">
              <td colspan="8" class="px-4 py-12 text-center text-gray-500">
                <div class="text-3xl mb-2">📭</div>
                <div v-if="records.length === 0">{{ payMonth }} 暂无工资记录</div>
                <div v-else>没有匹配的记录</div>
                <div v-if="records.length === 0" class="text-xs text-gray-400 mt-1">点击"上传 Excel"或"手动添加"或"📋 复制上月"开始</div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 导入预览弹窗 -->
      <div v-if="showPreview" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="closePreview">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-4xl mx-4 max-h-[85vh] flex flex-col overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
            <h2 class="font-bold text-gray-800">导入预览 — {{ payMonth }}</h2>
            <button @click="closePreview" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">×</button>
          </div>
          <div class="flex-1 overflow-y-auto p-6">
            <div v-if="availableSheets.length > 1" class="mb-3 flex items-center gap-2 text-sm">
              <label class="text-gray-600">选择 Sheet:</label>
              <select
                v-model="selectedSheet"
                @change="parseSheet(selectedSheet)"
                class="px-3 py-1.5 border border-gray-200 rounded-lg outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option v-for="name in availableSheets" :key="name" :value="name">{{ name }}</option>
              </select>
              <span class="text-xs text-gray-400">(共 {{ availableSheets.length }} 个 sheet)</span>
            </div>
            <div class="mb-3 text-sm text-gray-600">
              共解析到 <b class="text-blue-600">{{ previewRows.length }}</b> 行，
              其中有效 <b class="text-green-600">{{ validPreviewRows.length }}</b> 行
              <span v-if="invalidPreviewCount > 0" class="text-orange-500">
                (跳过 {{ invalidPreviewCount }} 行无效数据)
              </span>
            </div>
            <table class="w-full text-sm border border-gray-100 rounded">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-3 py-2 text-left text-gray-600">姓名</th>
                  <th class="px-3 py-2 text-right text-gray-600" title="基本工资/底薪">底薪</th>
                  <th class="px-3 py-2 text-right text-gray-600 whitespace-nowrap" title="所有加项合计（含底薪+岗位+职务+加班+绩效+提成+补贴等）">应发</th>
                  <th class="px-3 py-2 text-right text-gray-600 whitespace-nowrap" title="扣项合计（社保+公积金+个税+其他）">扣款</th>
                  <th class="px-3 py-2 text-right text-gray-600">实发</th>
                  <th class="px-3 py-2 text-left text-gray-600 w-48">明细</th>
                  <th class="px-3 py-2 text-center text-gray-600">状态</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, i) in previewRows" :key="i" class="border-t border-gray-50" :class="r._valid ? '' : 'bg-orange-50/40'">
                  <td class="px-3 py-2">
                    <input
                      v-model="r.employee_name"
                      @change="revalidatePreviewRow(r)"
                      class="w-full px-2 py-0.5 bg-transparent border border-transparent hover:border-gray-200 focus:border-blue-400 focus:bg-white rounded text-sm outline-none"
                    />
                  </td>
                  <td class="px-3 py-2 text-right">
                    <input
                      v-model.number="r.base_salary"
                      type="number"
                      step="0.01"
                      class="w-20 px-2 py-0.5 bg-transparent border border-transparent hover:border-gray-200 focus:border-blue-400 focus:bg-white rounded text-right text-sm outline-none"
                    />
                  </td>
                  <td class="px-3 py-2 text-right text-xs text-gray-600">
                    <span v-if="r._gross">{{ (Number(r._gross) || 0).toFixed(2) }}</span>
                    <span v-else class="text-gray-300">—</span>
                  </td>
                  <td class="px-3 py-2 text-right text-xs text-red-500">
                    <span v-if="r._dedSum">-{{ (Number(r._dedSum) || 0).toFixed(2) }}</span>
                    <span v-else class="text-gray-300">—</span>
                  </td>
                  <td class="px-3 py-2 text-right font-semibold">
                    <input
                      v-model.number="r.actual_amount"
                      @change="revalidatePreviewRow(r)"
                      type="number"
                      step="0.01"
                      class="w-24 px-2 py-0.5 bg-transparent border border-transparent hover:border-gray-200 focus:border-blue-400 focus:bg-white rounded text-right text-sm outline-none font-semibold text-blue-600"
                    />
                  </td>
                  <td class="px-3 py-2 text-xs text-gray-500">
                    <div v-if="hasBreakdownItems(r)" class="truncate max-w-[260px]" :title="formatBreakdownTitle(r)">
                      <span class="text-blue-600">🧮</span>
                      {{ formatBreakdownShort(r) }}
                    </div>
                    <input
                      v-else
                      v-model="r.note"
                      placeholder="备注"
                      class="w-full px-2 py-0.5 bg-transparent border border-transparent hover:border-gray-200 focus:border-blue-400 focus:bg-white rounded text-xs outline-none"
                    />
                  </td>
                  <td class="px-3 py-2 text-center">
                    <span v-if="r._valid" class="text-green-600 text-xs">✓ 有效</span>
                    <span v-else class="text-orange-500 text-xs">{{ r._reason }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-if="importError" class="mx-6 mb-3 bg-red-50 border border-red-200 rounded-lg p-2 text-xs shrink-0">
            <div class="font-medium text-red-700 mb-1">⚠️ 导入失败</div>
            <div class="text-red-600 font-mono break-all">{{ importError }}</div>
          </div>
          <div class="px-6 py-4 border-t border-gray-100 flex items-center justify-end gap-2 shrink-0">
            <button @click="showPreview = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
            <button
              @click="confirmImport"
              :disabled="importing || validPreviewRows.length === 0"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-40 cursor-pointer"
            >{{ importing ? '导入中...' : `确认导入 ${validPreviewRows.length} 条` }}</button>
          </div>
        </div>
      </div>

      <!-- 新建/编辑弹窗 -->
      <div v-if="showModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showModal = false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="font-bold text-gray-800">{{ editingId ? '编辑工资' : '新增工资' }}</h2>
            <button @click="showModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">×</button>
          </div>
          <form @submit.prevent="submitForm" class="p-6 space-y-3 max-h-[80vh] overflow-y-auto">
            <div>
              <label class="block text-sm text-gray-700 mb-1">员工姓名 <span class="text-red-500">*</span></label>
              <input
                v-model="form.employee_name"
                required
                list="salary-employee-list"
                autocomplete="off"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              />
              <datalist id="salary-employee-list">
                <option v-for="name in knownEmployees" :key="name" :value="name"></option>
              </datalist>
              <p v-if="knownEmployees.length > 0" class="text-xs text-gray-400 mt-1">
                💡 从历史记录中提取了 {{ knownEmployees.length }} 个姓名，输入时会自动补全
              </p>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm text-gray-700 mb-1">基本工资</label>
                <input v-model.number="form.base_salary" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-sm text-gray-700 mb-1">实发金额 <span class="text-red-500">*</span></label>
                <input v-model.number="form.actual_amount" type="number" step="0.01" min="0" required class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
            </div>

            <!-- 详细拆分计算器（可折叠） -->
            <div class="bg-gray-50 rounded-lg p-3 border border-gray-100">
              <button
                type="button"
                @click="breakdownExpanded = !breakdownExpanded"
                class="w-full flex items-center justify-between text-sm text-gray-700 cursor-pointer"
              >
                <span>🧮 详细拆分（奖金/社保/个税等）<span v-if="breakdownHasValue" class="ml-1 text-blue-600 text-xs">· 已启用</span></span>
                <span class="text-gray-400">{{ breakdownExpanded ? '▲' : '▼' }}</span>
              </button>
              <div v-if="breakdownExpanded" class="mt-3 space-y-2">
                <div class="grid grid-cols-2 gap-2">
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-green-600">+ 奖金</span>
                    <input v-model.number="form.breakdown.bonus" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-green-600">+ 津贴</span>
                    <input v-model.number="form.breakdown.allowance" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-red-500">− 社保</span>
                    <input v-model.number="form.breakdown.social" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-red-500">− 公积金</span>
                    <input v-model.number="form.breakdown.housing" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-red-500">− 个税</span>
                    <input v-model.number="form.breakdown.tax" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                  <label class="flex items-center justify-between gap-2 text-xs text-gray-600">
                    <span class="text-red-500">− 其他</span>
                    <input v-model.number="form.breakdown.other" type="number" step="0.01" class="w-24 px-2 py-1 border border-gray-200 rounded text-xs outline-none focus:ring-1 focus:ring-blue-500" />
                  </label>
                </div>
                <div class="border-t border-gray-200 pt-2 mt-2 text-xs text-gray-600 space-y-0.5">
                  <div class="flex justify-between"><span>公式</span><span class="font-mono text-gray-500 text-right break-all max-w-[70%]">{{ breakdownFormula }}</span></div>
                  <div class="flex justify-between items-center">
                    <span>= 计算实发</span>
                    <span class="font-mono font-semibold text-blue-600">¥{{ breakdownComputed.toFixed(2) }}</span>
                  </div>
                  <button
                    type="button"
                    @click="applyBreakdownToActual"
                    class="mt-1 w-full px-3 py-1.5 bg-blue-50 text-blue-700 rounded text-xs hover:bg-blue-100 cursor-pointer"
                  >应用到「实发金额」并存入备注</button>
                </div>
              </div>
            </div>

            <div>
              <label class="block text-sm text-gray-700 mb-1">应发月份 <span class="text-red-500">*</span></label>
              <input v-model="form.pay_month" type="month" required class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm text-gray-700 mb-1">实际发薪日(可空)</label>
              <input v-model="form.pay_date" type="date" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
              <p class="text-xs text-gray-500 mt-1">留空表示已计提未发放。如需扣减账户余额，请走"发放"按钮。</p>
            </div>
            <div>
              <label class="block text-sm text-gray-700 mb-1">备注</label>
              <textarea v-model="form.note" rows="2" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"></textarea>
            </div>
            <div v-if="formError" class="bg-red-50 border border-red-200 rounded-lg p-2 text-xs">
              <div class="font-medium text-red-700 mb-1">⚠️ 保存失败</div>
              <div class="text-red-600 font-mono break-all">{{ formError }}</div>
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button type="button" @click="showModal = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
              <button type="submit" :disabled="submitting" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-40 cursor-pointer">
                {{ submitting ? '保存中...' : '保存' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- A: 发放工资弹窗 -->
      <div v-if="showPayModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showPayModal = false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="font-bold text-gray-800">
              💰 发放工资
              <span class="text-sm text-gray-500 font-normal ml-2">
                （{{ payTargets.length === 1 ? payTargets[0].employee_name : `${payTargets.length} 人` }}，合计 {{ formatMoney(payTotalAmount) }}）
              </span>
            </h2>
            <button @click="showPayModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">×</button>
          </div>
          <form @submit.prevent="submitPay" class="p-6 space-y-3">
            <!-- 单人模式:支持多账户分拆;批量模式:只能选一个账户 -->
            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-sm text-gray-700">
                  发薪账户 <span class="text-red-500">*</span>
                  <span v-if="isSinglePay" class="text-xs text-gray-400 ml-2">支持从多个账户拆分发放</span>
                </label>
                <button
                  v-if="isSinglePay"
                  type="button"
                  @click="addSplit"
                  class="text-xs text-blue-600 hover:text-blue-700 cursor-pointer"
                >+ 再加一个账户</button>
              </div>
              <div class="space-y-2">
                <div
                  v-for="(s, idx) in payForm.splits"
                  :key="idx"
                  class="flex items-center gap-2"
                >
                  <select
                    v-model="s.account_id"
                    required
                    class="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">请选择账户</option>
                    <option v-for="a in accountOptions" :key="a.id" :value="a.id">
                      {{ accountOptionLabel(a) }}
                    </option>
                  </select>
                  <input
                    v-if="isSinglePay"
                    v-model.number="s.amount"
                    type="number"
                    step="0.01"
                    min="0"
                    placeholder="金额"
                    class="w-32 px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <template v-if="splitRowBadges[idx]">
                    <span
                      class="px-2 py-0.5 rounded-full text-[11px] whitespace-nowrap"
                      :class="splitRowBadges[idx].warn ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'"
                    >{{ splitRowBadges[idx].warn ? '⚠ ' : '✓ ' }}{{ splitRowBadges[idx].text }}</span>
                  </template>
                  <button
                    v-if="isSinglePay && payForm.splits.length > 1"
                    type="button"
                    @click="removeSplit(idx)"
                    class="text-red-400 hover:text-red-600 text-sm w-6 h-6 flex items-center justify-center cursor-pointer"
                    title="移除此账户"
                  >×</button>
                </div>
              </div>

              <!-- 分账户汇总与校验 -->
              <div v-if="isSinglePay" class="mt-2 flex items-center justify-between text-xs">
                <span class="text-gray-500">
                  应发 <b class="text-gray-700">{{ formatMoney(payTotalAmount) }}</b>，
                  已分配 <b :class="splitMismatch !== 0 ? 'text-orange-600' : 'text-green-600'">{{ formatMoney(splitAllocated) }}</b>
                  <span v-if="splitMismatch !== 0" class="text-orange-600">
                    （差额 {{ splitMismatch > 0 ? '缺' : '多' }} ¥{{ Math.abs(splitMismatch).toFixed(2) }}）
                  </span>
                </span>
                <button
                  v-if="splitMismatch !== 0 && payForm.splits.length >= 1"
                  type="button"
                  @click="autoFillLastSplit"
                  class="text-blue-600 hover:text-blue-700 cursor-pointer"
                >自动把差额填到最后一行</button>
              </div>
              <p v-if="payBalanceWarn" class="text-xs text-red-500 mt-1">⚠️ {{ payBalanceWarn }}</p>
            </div>

            <div>
              <label class="block text-sm text-gray-700 mb-1">发放日期 <span class="text-red-500">*</span></label>
              <input
                v-model="payForm.pay_date"
                type="date"
                required
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p class="text-xs text-gray-500 mt-1">
                {{ isSinglePay
                  ? '按每行账户分别扣款,写入对应条数支出记录。'
                  : '批量模式:所有员工从同一账户发放,每人一条支出记录。' }}
              </p>
            </div>

            <div class="bg-gray-50 rounded-lg p-3 text-xs text-gray-600 space-y-1 max-h-32 overflow-y-auto">
              <div v-for="r in payTargets" :key="r.id" class="flex justify-between">
                <span>{{ r.employee_name }}</span>
                <span class="font-mono">{{ formatMoney(r.actual_amount) }}</span>
              </div>
            </div>

            <!-- 批量发放进度条（只在并发池跑的时候显示）-->
            <div v-if="paying && payProgress.total > 1" class="pt-2">
              <div class="flex items-center justify-between text-xs text-gray-600 mb-1">
                <span>发放进度</span>
                <span class="font-mono">{{ payProgress.done }} / {{ payProgress.total }}</span>
              </div>
              <div class="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
                <div
                  class="h-full bg-green-500 transition-all"
                  :style="{ width: (payProgress.total > 0 ? (payProgress.done / payProgress.total * 100) : 0) + '%' }"
                ></div>
              </div>
            </div>

            <div class="flex justify-end gap-2 pt-2">
              <button type="button" @click="showPayModal = false" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
              <button
                type="submit"
                :disabled="paying || !canSubmitPay"
                class="px-4 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-40 cursor-pointer"
              >
                {{ paying
                  ? (payProgress.total > 0 ? `发放中 ${payProgress.done}/${payProgress.total}...` : '发放中...')
                  : `确认发放 ${formatMoney(payTotalAmount)}` }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Excel 密码输入弹窗 -->
      <div v-if="showPwdModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="cancelPwd">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4">
          <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 class="font-bold text-gray-800">🔐 文件已加密</h2>
            <button @click="cancelPwd" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">×</button>
          </div>
          <form @submit.prevent="submitPwd" class="p-6 space-y-3">
            <div class="text-sm text-gray-600">
              <div class="mb-1">文件：<span class="font-mono text-gray-800">{{ pendingFileName }}</span></div>
              <div class="text-xs text-gray-500">请输入打开该文件的密码</div>
            </div>
            <div>
              <input
                v-model="pwdInput"
                type="password"
                autofocus
                placeholder="Excel 打开密码"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p v-if="pwdError" class="text-xs text-red-500 mt-2">{{ pwdError }}</p>
              <p v-else class="text-xs text-gray-400 mt-2">
                ℹ️ 仅支持 .xls（老版 Excel）的密码；.xlsx 的 AES 加密建议先另存为无密码版本。
              </p>
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button type="button" @click="cancelPwd" class="px-4 py-2 text-sm text-gray-500 hover:bg-gray-50 rounded-lg cursor-pointer">取消</button>
              <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">解析</button>
            </div>
          </form>
        </div>
      </div>
      </div> <!-- /按月管理 -->

      <!-- 工资条弹窗（支持单人/多人打印） -->
      <div v-if="showPayslipModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 payslip-overlay" @click.self="showPayslipModal = false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 max-h-[90vh] flex flex-col">
          <div class="px-6 py-3 border-b border-gray-100 flex items-center justify-between payslip-hide">
            <h2 class="font-bold text-gray-800">🧾 工资条 <span class="text-sm text-gray-400 font-normal ml-2">{{ payslipRows.length }} 人</span></h2>
            <div class="flex items-center gap-2">
              <button @click="copyPayslipText" class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs text-gray-600 hover:bg-gray-50 cursor-pointer">📋 复制文本</button>
              <button @click="printPayslip" class="px-3 py-1.5 bg-blue-600 text-white rounded-lg text-xs hover:bg-blue-700 cursor-pointer">🖨 打印</button>
              <button @click="showPayslipModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">×</button>
            </div>
          </div>
          <div class="overflow-y-auto p-6 space-y-4" id="payslip-print-area">
            <div v-for="r in payslipRows" :key="r.id" class="border border-gray-200 rounded-xl p-4 payslip-card">
              <div class="flex items-center justify-between border-b border-dashed border-gray-200 pb-2 mb-3">
                <div>
                  <div class="text-sm text-gray-500">工资条 · {{ r.pay_month }}</div>
                  <div class="text-lg font-bold text-gray-800 mt-0.5">{{ r.employee_name }}</div>
                </div>
                <div class="text-right">
                  <div class="text-xs text-gray-500">实发</div>
                  <div class="text-xl font-bold text-green-600 font-mono">¥{{ Number(r.actual_amount || 0).toFixed(2) }}</div>
                </div>
              </div>
              <!-- 头部小计：应发 / 扣款 / 底薪 / 发放日期 / 账户 / 状态 -->
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm">
                <div class="flex justify-between border-b border-dotted border-gray-100 py-1" :title="baseSalaryTooltip(r)">
                  <dt class="text-gray-500">基本工资<span v-if="baseSalaryExtras(r) > 0" class="text-[10px] text-gray-400 ml-1">(底薪+岗位+职务)</span></dt>
                  <dd class="font-mono text-gray-700">¥{{ computedBaseSalary(r).toFixed(2) }}</dd>
                </div>
                <template v-if="payslipBreakdownTotals(r.note).hasData">
                  <div class="flex justify-between border-b border-dotted border-gray-100 py-1">
                    <dt class="text-gray-500">应发合计</dt>
                    <dd class="font-mono text-gray-800">¥{{ payslipBreakdownTotals(r.note).gross.toFixed(2) }}</dd>
                  </div>
                  <div class="flex justify-between border-b border-dotted border-gray-100 py-1">
                    <dt class="text-gray-500">扣款合计</dt>
                    <dd class="font-mono text-red-500">-¥{{ payslipBreakdownTotals(r.note).deduct.toFixed(2) }}</dd>
                  </div>
                </template>
                <div class="flex justify-between border-b border-dotted border-gray-100 py-1">
                  <dt class="text-gray-500">发放日期</dt>
                  <dd class="text-gray-700">{{ r.pay_date ? formatDate(r.pay_date, 'date') : '— 未发放 —' }}</dd>
                </div>
                <div class="flex justify-between border-b border-dotted border-gray-100 py-1">
                  <dt class="text-gray-500">发放账户</dt>
                  <dd class="text-gray-700">{{ getAccountName(r.account_id) || '—' }}</dd>
                </div>
                <div class="flex justify-between border-b border-dotted border-gray-100 py-1">
                  <dt class="text-gray-500">状态</dt>
                  <dd :class="r.pay_date ? 'text-green-600' : 'text-yellow-600'">{{ r.pay_date ? '已发放' : '待发放' }}</dd>
                </div>
                <!-- 备注（去掉拆分前缀行，单独展示） -->
                <div v-if="payslipNoteClean(r.note)" class="col-span-2 flex justify-between border-b border-dotted border-gray-100 py-1">
                  <dt class="text-gray-500">备注</dt>
                  <dd class="text-gray-700 text-right max-w-[80%] break-words">{{ payslipNoteClean(r.note) }}</dd>
                </div>
              </dl>
              <!-- 拆分明细（若 note 带有"【拆分】"行则解析展示） -->
              <div v-if="payslipBreakdownRows(r.note).length > 0" class="mt-3 pt-3 border-t border-dashed border-gray-200">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-xs text-gray-500">💼 发放明细（共 {{ payslipBreakdownRows(r.note).length }} 项）</div>
                  <div class="text-xs text-gray-400">应发 ¥{{ payslipBreakdownTotals(r.note).gross.toFixed(2) }} − 扣款 ¥{{ payslipBreakdownTotals(r.note).deduct.toFixed(2) }} = 实发 ¥{{ Number(r.actual_amount || 0).toFixed(2) }}</div>
                </div>
                <div class="grid grid-cols-3 gap-x-4 gap-y-1 text-xs">
                  <div v-for="(it, ix) in payslipBreakdownRows(r.note)" :key="ix" class="flex justify-between border-b border-dotted border-gray-100 py-0.5">
                    <span class="text-gray-600">{{ it.label }}</span>
                    <span class="font-mono" :class="it.isPlus ? 'text-green-600' : 'text-red-500'">{{ it.isPlus ? '+' : '-' }}{{ it.value.toFixed(2) }}</span>
                  </div>
                </div>
              </div>
              <div class="text-xs text-gray-400 mt-3 text-right">✍️ 员工签字：_________________</div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import * as XLSX from 'xlsx'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { useExpenseStore } from '../stores/expenses'
import { formatMoney, formatDate, toast } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'

const auth = useAuthStore()
const accountStore = useAccountStore()
const expensesStore = useExpenseStore()

const loading = ref(true)
const records = ref([])
const fileInput = ref(null)
const loadError = ref('') // 加载失败时保留错误信息在页面上

// ─── 基本工资 = 底薪 + 岗位 + 职务 ───
// DB 里 base_salary 字段存的是原始"底薪"（Excel 导入时从"基本工资/底薪"列拿的），
// 但用户要求概念上的"基本工资" = 底薪 + 岗位工资 + 职务工资（三项都是固定工资，不随考勤/绩效浮动）。
// 为避免数据迁移 + 保留导入明细（工资条要分开展示），这里在"展示层"做聚合：
// - 读取：computedBaseSalary(row) = row.base_salary + 【拆分】里的岗位 + 职务
// - 编辑：双击列显示的是聚合值，提交时减掉 岗位+职务 反推到 raw base_salary
function baseSalaryExtras(row) {
  // 从 note 的【拆分】行里解析出"岗位"与"职务"之和。没有就返回 0（兼容旧数据/手工单）。
  if (!row?.note) return 0
  const items = payslipBreakdownRows(row.note)
  let extra = 0
  for (const it of items) {
    if (!it.isPlus) continue
    if (it.label === '岗位' || it.label === '职务') extra += Number(it.value) || 0
  }
  return extra
}
function computedBaseSalary(row) {
  return Number(row?.base_salary || 0) + baseSalaryExtras(row)
}
function baseSalaryTooltip(row) {
  // 显示"底薪 X + 岗位 Y + 职务 Z = 合计 sum"，无明细时仅显示底薪
  const base = Number(row?.base_salary || 0)
  const items = payslipBreakdownRows(row?.note)
  const pos = items.find(it => it.isPlus && it.label === '岗位')?.value || 0
  const duty = items.find(it => it.isPlus && it.label === '职务')?.value || 0
  if (!pos && !duty) return `底薪 ¥${base.toFixed(2)}`
  const sum = base + pos + duty
  const parts = [`底薪 ¥${base.toFixed(2)}`]
  if (pos) parts.push(`岗位 ¥${pos.toFixed(2)}`)
  if (duty) parts.push(`职务 ¥${duty.toFixed(2)}`)
  return parts.join(' + ') + ` = ¥${sum.toFixed(2)}（双击修改合计值）`
}

// ─── 表格内快捷编辑（双击 base_salary / actual_amount 即改即存）───
// 需求：员工多的时候进完整弹窗改一个数太累；双击直接编辑更顺手
const inlineEdit = ref(null) // { rowId, field, value, origValue, extras }
const inlineInputRef = ref(null)
function startInlineEdit(row, field) {
  if (!auth.isFinance) return
  // base_salary 编辑显示的是"基本工资"聚合值（底薪+岗位+职务），commit 时再减回去
  const extras = field === 'base_salary' ? baseSalaryExtras(row) : 0
  const startVal = field === 'base_salary'
    ? computedBaseSalary(row)
    : (Number(row[field]) || 0)
  inlineEdit.value = {
    rowId: row.id,
    field,
    value: startVal,
    origValue: startVal,
    extras,
  }
  // nextTick 保证 DOM 已经渲染出 input
  nextTick(() => {
    const el = Array.isArray(inlineInputRef.value) ? inlineInputRef.value[0] : inlineInputRef.value
    if (el && typeof el.focus === 'function') {
      el.focus()
      el.select?.()
    }
  })
}
function cancelInlineEdit() {
  inlineEdit.value = null
}
// 仅当当前仍是 snap 对应行/字段时才清空编辑状态，避免并发切行把新编辑覆盖
function clearInlineIfSame(snap) {
  if (inlineEdit.value && inlineEdit.value.rowId === snap.rowId && inlineEdit.value.field === snap.field) {
    inlineEdit.value = null
  }
}
async function commitInlineEdit() {
  const snap = inlineEdit.value
  if (!snap) return
  const newVal = Number(snap.value) || 0
  // 金额没变化就不请求
  if (Math.round(newVal * 100) === Math.round(snap.origValue * 100)) {
    clearInlineIfSame(snap)
    return
  }
  if (newVal < 0) {
    toast('金额不能为负', 'warning')
    clearInlineIfSame(snap)
    return
  }
  const rowId = snap.rowId
  const field = snap.field
  // base_salary 特殊处理：用户输入的是"基本工资"聚合值，DB 存的是 raw 底薪
  let persistVal = newVal
  if (field === 'base_salary') {
    const extras = Number(snap.extras) || 0
    if (newVal < extras) {
      toast(`基本工资不能低于 岗位+职务 合计 ¥${extras.toFixed(2)}（请进入编辑弹窗修改明细）`, 'warning')
      clearInlineIfSame(snap)
      return
    }
    persistVal = Math.round((newVal - extras) * 100) / 100
  }
  try {
    const payload = { [field]: persistVal }
    const { error } = await supabase.from('salaries').update(payload).eq('id', rowId)
    if (error) throw error
    // 乐观更新：本地先改，再静默拉一次
    const local = records.value.find(r => r.id === rowId)
    if (local) local[field] = persistVal
    clearInlineIfSame(snap)
    toast(`${field === 'actual_amount' ? '实发' : '基本'}金额已更新为 ${formatMoney(newVal)}`, 'success', 2000)
  } catch (e) {
    console.error('[SalaryManagement] inline edit failed:', e)
    toast('保存失败: ' + (e.message || e), 'error')
    clearInlineIfSame(snap)
  }
}

// 当前月份默认是上月(月初算上月工资是常见场景)
function defaultMonth() {
  const now = new Date()
  const last = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  return `${last.getFullYear()}-${String(last.getMonth() + 1).padStart(2, '0')}`
}
const payMonth = ref(defaultMonth())

// ─── 视图模式：按月 / 年度看板 ───
const viewMode = ref('monthly') // 'monthly' | 'yearly'
const yearPick = ref(new Date().getFullYear())
const yearLoading = ref(false)
const yearData = ref({ monthly: [], byEmployee: [] })
// 默认展示近 5 年 + 未来 1 年
const yearOptions = computed(() => {
  const cur = new Date().getFullYear()
  const list = []
  for (let y = cur + 1; y >= cur - 5; y--) list.push(y)
  return list
})
const yearSummary = computed(() => {
  const totalAccrued = yearData.value.monthly.reduce((s, m) => s + (m.accrued || 0), 0)
  const totalPaid = yearData.value.monthly.reduce((s, m) => s + (m.paid || 0), 0)
  const employeeCount = yearData.value.byEmployee.length
  return { totalAccrued, totalPaid, employeeCount }
})

// 年度表搜索 + 疑似同名分组（比如 "张三" 与 "张 三" 被 Excel 导入成两条记录）
const yearEmpSearch = ref('')

// 归一化姓名：去所有空白 + 小写 + 去掉常见标点。用来检测"看上去一样"的名字
function normEmpName(n) {
  return String(n || '').toLowerCase().replace(/[\s\u3000.·,，、\-_·]/g, '')
}

// 把同一归一化键下 >= 2 个原始名字的聚成一组，并把 group 列表返回
const yearDuplicateGroups = computed(() => {
  const keyMap = new Map() // normalized -> [raw names]
  for (const emp of yearData.value.byEmployee) {
    const key = normEmpName(emp.name)
    if (!key) continue
    if (!keyMap.has(key)) keyMap.set(key, [])
    keyMap.get(key).push(emp.name)
  }
  const groups = []
  for (const arr of keyMap.values()) {
    if (arr.length > 1) groups.push(arr)
  }
  return groups
})

// 反向索引：每个原始名字对应它的 peers（不含自己）
const yearDupPeerMap = computed(() => {
  const map = new Map()
  for (const group of yearDuplicateGroups.value) {
    for (const name of group) {
      map.set(name, group.filter(n => n !== name))
    }
  }
  return map
})

const filteredYearEmployees = computed(() => {
  const q = yearEmpSearch.value.trim().toLowerCase()
  const source = yearData.value.byEmployee
  const list = q
    ? source.filter(emp => emp.name.toLowerCase().includes(q))
    : source
  const peerMap = yearDupPeerMap.value
  return list.map(emp => {
    const peers = peerMap.get(emp.name)
    if (peers && peers.length > 0) {
      return { ...emp, _likelyDup: true, _dupPeers: peers }
    }
    return emp
  })
})

function yearChartHeight(v) {
  const max = Math.max(...yearData.value.monthly.map(m => m.accrued || 0), 1)
  return Math.round((v / max) * 100)
}

async function switchToYearly() {
  viewMode.value = 'yearly'
  if (yearData.value.monthly.length === 0) await loadYearData()
}

async function loadYearData() {
  yearLoading.value = true
  try {
    const year = yearPick.value
    // 取整年所有 salary 记录。pay_month 格式 'YYYY-MM'，string 范围比较 OK
    const { data, error } = await supabase
      .from('salaries')
      .select('employee_name, actual_amount, pay_month, pay_date')
      .is('deleted_at', null)
      .gte('pay_month', `${year}-01`)
      .lte('pay_month', `${year}-12`)
      .limit(5000)
    if (error) throw error

    // 按月聚合
    const monthly = Array.from({ length: 12 }, () => ({ accrued: 0, paid: 0, count: 0 }))
    // 按员工聚合：{ name -> { months: [12], total } }
    const empMap = new Map()
    for (const r of data || []) {
      const amt = Number(r.actual_amount || 0)
      const [y, m] = (r.pay_month || '').split('-').map(Number)
      if (!y || !m || m < 1 || m > 12) continue
      const idx = m - 1
      monthly[idx].accrued += amt
      monthly[idx].count += 1
      if (r.pay_date) monthly[idx].paid += amt

      const key = r.employee_name || '—'
      if (!empMap.has(key)) empMap.set(key, { name: key, months: Array(12).fill(0), total: 0 })
      const emp = empMap.get(key)
      emp.months[idx] += amt
      emp.total += amt
    }
    // 按全年合计从高到低排序
    const byEmployee = Array.from(empMap.values()).sort((a, b) => b.total - a.total)
    yearData.value = { monthly, byEmployee }
  } catch (e) {
    console.error('[SalaryManagement] loadYearData error:', e)
    toast('年度数据加载失败: ' + (e.message || e), 'error')
    yearData.value = { monthly: Array.from({ length: 12 }, () => ({ accrued: 0, paid: 0, count: 0 })), byEmployee: [] }
  } finally {
    yearLoading.value = false
  }
}

// 点击柱子跳到月份详情
function drillToMonth(m) {
  const mm = String(m).padStart(2, '0')
  payMonth.value = `${yearPick.value}-${mm}`
  viewMode.value = 'monthly'
  loadSalaries()
}

// 导出全年员工汇总 CSV
function exportYearCsv() {
  // 跟着当前搜索走：有搜索就只导出匹配到的员工；没搜索就全量
  const empList = filteredYearEmployees.value
  if (empList.length === 0) {
    toast('无数据可导出', 'warning')
    return
  }
  const header = ['姓名', ...Array.from({ length: 12 }, (_, i) => `${i + 1}月`), '合计']
  const rows = empList.map(emp => [
    emp.name,
    ...emp.months.map(v => (v > 0 ? v.toFixed(2) : '')),
    emp.total.toFixed(2),
  ])
  // 汇总行：根据当前导出范围内的员工重新聚合（搜索后不再显示全年合计）
  const monthSum = Array(12).fill(0)
  let totalSum = 0
  for (const emp of empList) {
    for (let i = 0; i < 12; i++) monthSum[i] += emp.months[i] || 0
    totalSum += emp.total || 0
  }
  rows.push([
    '合计',
    ...monthSum.map(v => (v > 0 ? v.toFixed(2) : '')),
    totalSum.toFixed(2),
  ])
  const csv = [header, ...rows]
    .map(r => r.map(c => {
      const s = String(c ?? '')
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
    }).join(','))
    .join('\n')
  // 加 UTF-8 BOM 方便 Excel 打开中文不乱码
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  const suffix = yearEmpSearch.value.trim() ? `_筛选_${yearEmpSearch.value.trim()}` : ''
  a.download = `工资年度汇总_${yearPick.value}${suffix}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
  toast(`已导出 ${empList.length} 人年度汇总`, 'success')
}

// 导出当前月份工资 CSV（含筛选状态）
function exportMonthCsv() {
  const rows = displayedRecords.value
  if (rows.length === 0) {
    toast('当前筛选下没有可导出的记录', 'warning')
    return
  }
  // 基本工资导出聚合值(底薪+岗位+职务)，额外拆一列"底薪"保留原始底薪以便对账
  const header = ['姓名', '应发月份', '基本工资', '底薪', '实发金额', '发薪日期', '发薪账户', '状态', '备注']
  const body = rows.map(r => [
    r.employee_name || '',
    r.pay_month || '',
    computedBaseSalary(r).toFixed(2),
    Number(r.base_salary || 0).toFixed(2),
    Number(r.actual_amount || 0).toFixed(2),
    r.pay_date || '',
    getAccountName(r.account_id) || '',
    rowStatusLabel(r),
    r.note || '',
  ])
  const csv = [header, ...body]
    .map(row => row.map(c => {
      const s = String(c ?? '')
      return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
    }).join(','))
    .join('\n')
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `工资_${payMonth.value}.csv`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
  toast(`已导出 ${rows.length} 条`, 'success')
}

// ─── F: 统计卡片 ───
// 发薪规则:次月 15 号发上月工资
// 欠发(逾期) = 今天 > 应发月份的次月 15 号,且 pay_date 为空
//   例:3 月工资截止日是 4 月 15 号,4 月 16 号起未发则算欠发
function payCutoffDate(payMonth) {
  // payMonth: "yyyy-mm" → 次月 15 号 00:00
  if (!payMonth) return null
  const [y, m] = payMonth.split('-').map(Number)
  if (!y || !m) return null
  // JS 月份 0-based;payMonth 的 "次月" = JS 的 m(因为 m 是 1-based)
  // → new Date(y, m, 15) 即 payMonth 次月 15 号
  return new Date(y, m, 15)
}

function isOverdue(row) {
  if (row.pay_date) return false
  const cutoff = payCutoffDate(row.pay_month)
  if (!cutoff) return false
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return today > cutoff
}

const stats = computed(() => {
  let accrued = 0, paid = 0, pending = 0, overdue = 0
  let paidCount = 0, pendingCount = 0, overdueCount = 0
  for (const r of records.value) {
    const amt = Number(r.actual_amount || 0)
    accrued += amt
    if (r.pay_date) {
      paid += amt
      paidCount++
    } else {
      pending += amt
      pendingCount++
      if (isOverdue(r)) {
        overdue += amt
        overdueCount++
      }
    }
  }
  return { accrued, paid, pending, overdue, paidCount, pendingCount, overdueCount }
})

// ─── 数据加载 ───
async function loadSalaries() {
  loading.value = true
  loadError.value = ''
  selectedIds.value = new Set()
  try {
    // 先尝试带 account_id 查询(新版表结构);如果列不存在就降级到旧 select
    let data, error
    ;({ data, error } = await supabase
      .from('salaries')
      .select('id, employee_name, base_salary, actual_amount, pay_month, pay_date, note, account_id')
      .is('deleted_at', null)
      .eq('pay_month', payMonth.value)
      .order('employee_name', { ascending: true }))
    if (error && /account_id|column/i.test(error.message || '')) {
      console.warn('[SalaryManagement] salaries.account_id 列不存在,降级查询')
      ;({ data, error } = await supabase
        .from('salaries')
        .select('id, employee_name, base_salary, actual_amount, pay_month, pay_date, note')
        .is('deleted_at', null)
        .eq('pay_month', payMonth.value)
        .order('employee_name', { ascending: true }))
    }
    if (error) throw error
    records.value = data || []
  } catch (e) {
    console.error('[SalaryManagement] loadSalaries error:', e)
    // 把完整错误摊在页面上,方便 debug
    const details = []
    if (e.message) details.push(`message: ${e.message}`)
    if (e.code) details.push(`code: ${e.code}`)
    if (e.details) details.push(`details: ${e.details}`)
    if (e.hint) details.push(`hint: ${e.hint}`)
    loadError.value = details.join(' | ') || String(e)
    toast('加载工资数据失败: ' + (e.message || e), 'error')
  } finally {
    loading.value = false
  }
}

// ─── E: 搜索 + 状态筛选 + 排序 ───
const search = ref('')
const statusFilter = ref('all')

// ─── 工资条弹窗 ───
const showPayslipModal = ref(false)
const payslipRows = ref([])

function openPayslipModal(rows) {
  payslipRows.value = rows
  showPayslipModal.value = true
}

function batchPayslip() {
  const rows = displayedRecords.value.filter(r => selectedIds.value.has(r.id))
  if (rows.length === 0) {
    toast('未选择记录', 'warning')
    return
  }
  openPayslipModal(rows)
}

// 生成文本版工资条（微信粘贴发给员工用）
// 工资条：把 note 里的【拆分】前缀行去掉，只留真正的备注文本
function payslipNoteClean(note) {
  if (!note) return ''
  return (note || '').split('\n').filter(l => !l.startsWith('【拆分】')).join('\n').trim()
}

// 工资条：从 note 的【拆分】行里解析出所有加项/减项
// 实际写入格式：`【拆分】底薪 3500.00 + 岗位 1400.00 + 绩效 500.00 - 社保 280.00 - 个税 45.00 = 实发 5075.00`
// 旧版只认 基本/奖金/津贴/社保/公积金/个税/其他 六个 token，但 Excel 导入实际用的是 12 加项 + 8 扣项，
// 所以以前工资条 99% 情况下"明细空白"——通用 tokenizer 一并搞定。
function payslipBreakdownRows(note) {
  if (!note) return []
  const line = (note.split('\n').find(l => l.startsWith('【拆分】')) || '').replace(/^【拆分】/, '')
  if (!line) return []
  // 只取 `= 实发` 之前的部分，避免把"实发 5075"当成加项再加一遍
  const body = line.split(/\s*=\s*实发/)[0]
  const rows = []
  // 第一项：底薪 N（没有加减号前缀）
  const mBase = body.match(/^\s*底薪\s+([0-9]+(?:\.[0-9]+)?)/)
  if (mBase && Number(mBase[1])) rows.push({ label: '底薪', value: Number(mBase[1]), isPlus: true })
  // 后续：+ 标签 N / - 标签 N。标签是连续非空白字符（全部在 FIELD_LABELS 内，不会含空格或 +/-）
  const segRE = /([+\-])\s*(\S+?)\s+([0-9]+(?:\.[0-9]+)?)/g
  let m
  while ((m = segRE.exec(body)) !== null) {
    const value = Number(m[3])
    if (!m[2] || !Number.isFinite(value) || value === 0) continue
    rows.push({ label: m[2], value, isPlus: m[1] === '+' })
  }
  return rows
}

// 基于 payslipBreakdownRows 再算一下小计（应发 / 扣款），工资条头部要显示
function payslipBreakdownTotals(note) {
  const rows = payslipBreakdownRows(note)
  let gross = 0
  let deduct = 0
  for (const r of rows) {
    if (r.isPlus) gross += r.value
    else deduct += r.value
  }
  return { gross, deduct, hasData: rows.length > 0 }
}

function buildPayslipText(r) {
  const lines = [
    `工资条 · ${r.pay_month}`,
    `姓名：${r.employee_name}`,
  ]
  const rows = payslipBreakdownRows(r.note)
  if (rows.length > 0) {
    const totals = payslipBreakdownTotals(r.note)
    lines.push('── 明细 ──')
    for (const it of rows) {
      lines.push(`${it.isPlus ? '+' : '-'} ${it.label}：¥${it.value.toFixed(2)}`)
    }
    lines.push(`应发合计：¥${totals.gross.toFixed(2)}`)
    lines.push(`扣款合计：¥${totals.deduct.toFixed(2)}`)
  } else {
    // 无明细时退回到"基本工资"字段（即 raw 底薪，因为没有岗位/职务明细）
    lines.push(`基本工资：¥${Number(r.base_salary || 0).toFixed(2)}`)
  }
  // 在无论有无明细的情况下都显示聚合基本工资（底薪+岗位+职务），与列表保持一致
  if (rows.length > 0 && baseSalaryExtras(r) > 0) {
    lines.push(`基本工资合计(底薪+岗位+职务)：¥${computedBaseSalary(r).toFixed(2)}`)
  }
  lines.push(`实发金额：¥${Number(r.actual_amount || 0).toFixed(2)}`)
  lines.push(`发放状态：${r.pay_date ? `已发放（${formatDate(r.pay_date, 'date')}）` : '待发放'}`)
  const acc = getAccountName(r.account_id)
  if (acc) lines.push(`发放账户：${acc}`)
  const noteClean = payslipNoteClean(r.note)
  if (noteClean) lines.push(`备注：${noteClean}`)
  return lines.join('\n')
}

function copyPayslipText() {
  const texts = payslipRows.value.map(buildPayslipText).join('\n\n────────\n\n')
  navigator.clipboard?.writeText(texts).then(() => {
    toast(`已复制 ${payslipRows.value.length} 份工资条到剪贴板`, 'success')
  }).catch(() => {
    toast('复制失败，请手动选择文本复制', 'error')
  })
}

function printPayslip() {
  // 通过动态 style 隐藏 overlay 之外的元素，只打印弹窗内容
  const style = document.createElement('style')
  style.id = 'payslip-print-style'
  style.textContent = `
    @media print {
      body * { visibility: hidden !important; }
      .payslip-overlay, .payslip-overlay * { visibility: visible !important; }
      .payslip-overlay { position: absolute !important; inset: 0 !important; background: white !important; }
      .payslip-overlay > div { box-shadow: none !important; max-width: 100% !important; max-height: none !important; }
      .payslip-hide { display: none !important; }
      .payslip-card { page-break-inside: avoid; margin-bottom: 12px; }
    }
  `
  document.head.appendChild(style)
  setTimeout(() => {
    window.print()
    setTimeout(() => style.remove(), 500)
  }, 50)
}
const sortBy = ref('employee_name')
const sortDir = ref('asc')

function toggleSort(field) {
  if (sortBy.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortDir.value = 'asc'
  }
}

function sortIndicator(field) {
  if (sortBy.value !== field) return ''
  return sortDir.value === 'asc' ? '▲' : '▼'
}

// 卡片点击筛选：'all' | 'paid' | 'pending' | 'overdue'
// 和 statusFilter 协同：点击卡片会同步 statusFilter，但 overdue 是 statusFilter 之外的细分
const cardFilter = ref('all')

function applyCardFilter(kind) {
  // 再次点击同一张卡片 = 取消筛选
  if (cardFilter.value === kind) {
    cardFilter.value = 'all'
    statusFilter.value = 'all'
    return
  }
  cardFilter.value = kind
  if (kind === 'paid') statusFilter.value = 'paid'
  else if (kind === 'pending' || kind === 'overdue') statusFilter.value = 'pending'
  else statusFilter.value = 'all'
  // 清掉多选，避免老的选择跑到筛后看不到但仍参与批量操作的诡异
  clearSelection()
}

const filteredRecords = computed(() => {
  const kw = search.value.trim().toLowerCase()
  return records.value.filter(r => {
    // 状态
    if (statusFilter.value === 'paid' && !r.pay_date) return false
    if (statusFilter.value === 'pending' && r.pay_date) return false
    // 卡片细分：欠发 = 未发 且 已过次月 15 号
    if (cardFilter.value === 'overdue' && !isOverdue(r)) return false
    // 搜索
    if (kw) {
      const text = `${r.employee_name || ''} ${r.note || ''}`.toLowerCase()
      if (!text.includes(kw)) return false
    }
    return true
  })
})

const displayedRecords = computed(() => {
  const arr = filteredRecords.value.slice()
  const field = sortBy.value
  const dir = sortDir.value === 'asc' ? 1 : -1
  // 基本工资排序按聚合值(底薪+岗位+职务)，让 UI 看到的顺序与列值一致
  const getVal = (r) => field === 'base_salary' ? computedBaseSalary(r) : r[field]
  arr.sort((a, b) => {
    const va = getVal(a)
    const vb = getVal(b)
    if (typeof va === 'number' || typeof vb === 'number') {
      return (Number(va || 0) - Number(vb || 0)) * dir
    }
    return String(va || '').localeCompare(String(vb || ''), 'zh-CN') * dir
  })
  return arr
})

function rowStatusLabel(row) {
  if (row.pay_date) return '已发放'
  if (isOverdue(row)) return '欠发'
  return '已计提'
}

function rowStatusClass(row) {
  if (row.pay_date) return 'bg-green-50 text-green-700'
  if (isOverdue(row)) return 'bg-red-50 text-red-700'
  return 'bg-yellow-50 text-yellow-700'
}

// ─── C: 批量选择 ───
const selectedIds = ref(new Set())
const headCheckbox = ref(null)

const allSelected = computed(() => displayedRecords.value.length > 0 && displayedRecords.value.every(r => selectedIds.value.has(r.id)))
const someSelected = computed(() => displayedRecords.value.some(r => selectedIds.value.has(r.id)))

// 手动把 indeterminate 写到 DOM property(避免 :indeterminate.prop 兼容性风险)
watch([allSelected, someSelected], ([all, some]) => {
  if (headCheckbox.value) {
    headCheckbox.value.indeterminate = some && !all
  }
})

function toggleSelect(id) {
  const next = new Set(selectedIds.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  selectedIds.value = next
}

function toggleAll() {
  if (allSelected.value) {
    const next = new Set(selectedIds.value)
    for (const r of displayedRecords.value) next.delete(r.id)
    selectedIds.value = next
  } else {
    const next = new Set(selectedIds.value)
    for (const r of displayedRecords.value) next.add(r.id)
    selectedIds.value = next
  }
}

function clearSelection() {
  selectedIds.value = new Set()
}

// ─── 软删 + 撤销机制 ───
// 没有"硬删"这一步。deleted_at 设成时间戳后，8 秒内点"撤销"就把它置回 null。
// 撤销浮条期间如果用户又做下一个删除，旧的自动关闭（不阻塞新操作）
// refunds 记录"删除时退回账户的支出"，撤销时按相反方向重新扣回账户
const pendingUndo = ref(null) // { kind, rows: [{id, employee_name, pay_month}], refunds: [{expense_id, account_id, amount}], expiresAt }
const undoSecondsLeft = ref(0)
let _undoCloseTimer = null
let _undoTickTimer = null

// 删除工资时：找到与本条工资对应的已付款支出记录，退回账户余额并软删支出
// 匹配条件：同收款人 + 类别=工资 + 同发薪日期 + 备注里带本月份标记
// 返回 [{ expense_id, account_id, amount }]，供撤销时原路回滚
async function refundExpensesForSalary(row) {
  const refunds = []
  // 没发过薪（pay_date 空）→ 无关联支出可退
  if (!row?.pay_date || !row?.employee_name || !row?.pay_month) return refunds
  try {
    const { data: exps, error } = await supabase
      .from('expenses')
      .select('id, amount, account_id')
      .eq('payee', row.employee_name)
      .eq('category', '工资')
      .eq('expense_date', row.pay_date)
      .ilike('note', `%(${row.pay_month})%`)
      .is('deleted_at', null)
    if (error) throw error
    for (const ex of (exps || [])) {
      const amt = Number(ex.amount || 0)
      if (!ex.id || !ex.account_id || !Number.isFinite(amt) || amt <= 0) continue
      // 先退款再软删支出：万一软删失败，至少钱在账户里（可以对账修），
      // 反过来如果先软删再退款失败，支出没了钱也没退，更难查。
      try {
        await accountStore.updateBalance(ex.account_id, amt, '删除工资退款', 'salary', row.id)
      } catch (e) {
        console.warn('[refundExpensesForSalary] 退款失败:', e)
        continue // 这条退不了就不动它，不要污染支出状态
      }
      try {
        const { error: delErr } = await supabase
          .from('expenses')
          .update({ deleted_at: new Date().toISOString() })
          .eq('id', ex.id)
        if (delErr) {
          // 软删失败：把刚退的钱再扣回来，保持账目一致
          try { await accountStore.updateBalance(ex.account_id, -amt, '退款回滚', 'salary', row.id) } catch {}
          throw delErr
        }
      } catch (e) {
        console.warn('[refundExpensesForSalary] 软删支出失败，已回滚退款:', e)
        continue
      }
      refunds.push({ expense_id: ex.id, account_id: ex.account_id, amount: amt })
    }
  } catch (e) {
    console.error('[refundExpensesForSalary] 查询支出失败:', e)
  }
  return refunds
}

function stageUndo(rows, kind, refunds = []) {
  // 若上一个撤销浮条还在，直接关掉（新操作优先）
  if (_undoCloseTimer) { clearTimeout(_undoCloseTimer); _undoCloseTimer = null }
  if (_undoTickTimer) { clearInterval(_undoTickTimer); _undoTickTimer = null }
  pendingUndo.value = {
    kind,
    rows: rows.map(r => ({ id: r.id, employee_name: r.employee_name, pay_month: r.pay_month })),
    refunds: refunds.slice(),
    expiresAt: Date.now() + 8000,
  }
  undoSecondsLeft.value = 8
  _undoTickTimer = setInterval(() => {
    // 防御：pendingUndo 在别处被置 null 但 interval 还在队列里
    if (!pendingUndo.value) {
      clearInterval(_undoTickTimer)
      _undoTickTimer = null
      return
    }
    const left = Math.ceil((pendingUndo.value.expiresAt - Date.now()) / 1000)
    undoSecondsLeft.value = Math.max(0, left)
  }, 250)
  _undoCloseTimer = setTimeout(() => {
    pendingUndo.value = null
    if (_undoTickTimer) { clearInterval(_undoTickTimer); _undoTickTimer = null }
  }, 8000)
}

async function undoDelete() {
  const snap = pendingUndo.value
  if (!snap) return
  // 立即关浮条，避免用户连点
  pendingUndo.value = null
  if (_undoCloseTimer) { clearTimeout(_undoCloseTimer); _undoCloseTimer = null }
  if (_undoTickTimer) { clearInterval(_undoTickTimer); _undoTickTimer = null }
  try {
    const ids = snap.rows.map(r => r.id)
    const { error } = await supabase.from('salaries').update({ deleted_at: null }).in('id', ids)
    if (error) throw error

    // 同步回滚退款：把删除时退回的钱重新扣走，把软删的支出恢复
    const refundList = snap.refunds || []
    let reReducedCount = 0
    let reReduceFailed = 0
    for (const rf of refundList) {
      if (!rf?.expense_id || !rf?.account_id || !rf?.amount) continue
      try {
        await accountStore.updateBalance(rf.account_id, -Number(rf.amount), '撤销工资删除-重新扣款', 'salary', null)
        const { error: restoreErr } = await supabase
          .from('expenses')
          .update({ deleted_at: null })
          .eq('id', rf.expense_id)
        if (restoreErr) {
          // 支出恢复失败：把刚扣的钱退回去
          try { await accountStore.updateBalance(rf.account_id, Number(rf.amount), '撤销回滚', 'salary', null) } catch {}
          throw restoreErr
        }
        reReducedCount++
      } catch (e) {
        console.warn('[undoDelete] 撤销退款失败:', e)
        reReduceFailed++
      }
    }

    let msg = `已撤销，恢复 ${ids.length} 条`
    if (reReducedCount > 0) msg += `，重新扣款 ${reReducedCount} 笔`
    if (reReduceFailed > 0) msg += `（${reReduceFailed} 笔撤销失败，请手工核对账户）`
    toast(msg, reReduceFailed > 0 ? 'warning' : 'success')
    await loadSalaries()
    await accountStore.fetchAccounts().catch(() => {})
  } catch (e) {
    console.error('[SalaryManagement] undoDelete error:', e)
    toast('撤销失败: ' + e.message, 'error')
  }
}

async function batchDelete() {
  const ids = Array.from(selectedIds.value)
  if (ids.length === 0) return
  // 保存快照用于撤销显示
  const snapshot = records.value.filter(r => selectedIds.value.has(r.id))
  try {
    // 1) 先逐条退款（串行以避免并发改同一账户余额）并软删对应支出
    const refunds = []
    for (const row of snapshot) {
      const rs = await refundExpensesForSalary(row)
      for (const r of rs) refunds.push(r)
    }
    // 2) 软删工资记录
    const { error } = await supabase
      .from('salaries')
      .update({ deleted_at: new Date().toISOString() })
      .in('id', ids)
    if (error) throw error
    clearSelection()
    await loadSalaries()
    if (refunds.length > 0) {
      const totalRefund = refunds.reduce((s, r) => s + Number(r.amount || 0), 0)
      toast(`已删除 ${ids.length} 条，退回账户 ¥${totalRefund.toFixed(2)}（${refunds.length} 笔支出）`, 'success')
    }
    stageUndo(snapshot, 'batch', refunds)
  } catch (e) {
    console.error('[SalaryManagement] batchDelete error:', e)
    toast('批量删除失败: ' + e.message, 'error')
  }
}

// ─── B: 复制上月 ───
const copying = ref(false)
async function copyLastMonth() {
  const [y, m] = payMonth.value.split('-').map(Number)
  const lastDate = new Date(y, m - 2, 1) // m 是 1-based，减 2 等于上月的 JS 索引
  const lastMonth = `${lastDate.getFullYear()}-${String(lastDate.getMonth() + 1).padStart(2, '0')}`
  if (!confirm(`把 ${lastMonth} 的工资名单复制到 ${payMonth.value}？（已存在的同名员工会被跳过）`)) return
  copying.value = true
  try {
    const { data: last, error } = await supabase
      .from('salaries')
      .select('employee_name, base_salary, actual_amount, note')
      .is('deleted_at', null)
      .eq('pay_month', lastMonth)
    if (error) throw error
    if (!last || last.length === 0) {
      toast(`${lastMonth} 没有工资记录可复制`, 'warning')
      return
    }
    const existingNames = new Set(records.value.map(r => r.employee_name))
    const toInsert = last.filter(r => !existingNames.has(r.employee_name))
    if (toInsert.length === 0) {
      toast('上月员工本月都已存在，未新增', 'warning')
      return
    }
    const { data: { session } } = await supabase.auth.getSession()
    const userId = session?.user?.id
    const rows = toInsert.map(r => ({
      employee_name: r.employee_name,
      base_salary: r.base_salary,
      actual_amount: r.actual_amount,
      pay_month: payMonth.value,
      pay_date: null,
      note: r.note,
    }))
    const { error: insErr } = await supabase.from('salaries').insert(rows)
    if (insErr) throw insErr
    const skipped = last.length - toInsert.length
    const names = toInsert.map(r => r.employee_name).filter(Boolean)
    const preview = names.slice(0, 3).join('、')
    const extra = names.length > 3 ? ` 等 ${names.length} 人` : ''
    const skipMsg = skipped > 0 ? `，跳过 ${skipped} 条同名` : ''
    toast(`已从 ${lastMonth} 复制 ${preview}${extra}${skipMsg}`, 'success')
    await loadSalaries()
  } catch (e) {
    console.error('[SalaryManagement] copyLastMonth error:', e)
    toast('复制上月失败: ' + e.message, 'error')
  } finally {
    copying.value = false
  }
}

// ─── Excel 导入 ───
const showPreview = ref(false)
const previewRows = ref([])
const importing = ref(false)
const pendingWorkbook = ref(null)
const availableSheets = ref([])
const selectedSheet = ref('')

const validPreviewRows = computed(() => previewRows.value.filter(r => r._valid))
const invalidPreviewCount = computed(() => previewRows.value.length - validPreviewRows.value.length)

function closePreview() {
  showPreview.value = false
  previewRows.value = []
  pendingWorkbook.value = null
  availableSheets.value = []
  selectedSheet.value = ''
}

// 列名规范化:支持常见中英文写法 + 多行合并表头
// 返回值扩展为细分字段，包括"加项 add_*"与"扣项 ded_*"，由 parseSheet 汇总成 breakdown
// 优先级：同一字段识别到多列时，优先取更"终态"的列（比如 实发 > 应发 > 合计）
function normalizeColumn(name) {
  const raw = String(name || '').trim().toLowerCase()
  if (!raw) return null
  // 清洗：全角/半角空格、所有分隔符、方括号、点号、加号（"职务+加班" → "职务加班"）
  const n = raw
    .replace(/[\s/\\()()\[\]【】\-_·、，,:：;；.。+＋]+/g, '')
    .replace(/\u3000/g, '') // 全角空格

  // 工号/编号类 → 跳过（不作为任何字段）
  if (/(工号|工卡|编号|empid|empno|employeeid)$/.test(n)) return null
  // 纯 id 列
  if (n === 'id' || n === '序号' || n === '序列') return null
  // 银行信息/辅助（不导入）
  if (/开户人|银行卡号|银行支行|开户行|代发$|卡付$|现付$/.test(n)) return null
  // 中间计算列：合计 / 差异 / "职务+加班" / "考勤绩效" 总计 —— 必须先排除
  if (/^合计\d*$|^差异$|实发差异|^职务加班$|^考勤绩效$|^小计$/.test(n)) return null

  // 姓名列（放在前面，避免被后续"员工"规则误吞）
  if (/姓名|名字|fullname|员工名|name$/.test(n)) return 'employee_name'
  if (/^员工$|^姓名$|^职员$/.test(n)) return 'employee_name'

  // 发薪月份/实际发薪日期
  if (/发薪月份|应发月份|所属月|归属月|工资月份|薪资月份|月份|paymonth|month/.test(n)) return 'pay_month'
  if (/发薪日期|实发日期|实际发薪|发放日期|支付日期|paydate|paymentdate/.test(n)) return 'pay_date'

  // ═══ 终态金额：优先级 实发 > 应发 > 兜底"工资" ═══
  // 实发/净发：最终到手 → actual_amount（最高优先级）
  if (/实发|实付|净发|净额|到手|net|takehome|实领|实收/.test(n)) return 'actual_amount'
  // 应发：所有加项合计（未扣社保前） → gross_amount（次优先级）
  if (/应发|应付工资|grosspay|gross/.test(n)) return 'gross_amount'
  // "工资" 单字段兜底（没有"基本/底/应发/实发"前缀时）
  if (/^(工资|薪资|薪水|月工资|月薪资)$/.test(n)) return 'actual_amount'
  // 应扣合计 → ded_total（汇总扣项列，纯参考，不计算）
  if (/应扣|扣款合计|扣项合计/.test(n)) return 'ded_total'

  // ═══ 基本底薪（最窄定义：只认"底薪/基本工资"，不吞"岗位/职务"） ═══
  // 兼容合并表头 "基本工资 / 底薪" → 清洗后 "基本工资底薪"
  if (/^底薪$|^基本工资$|^基础工资$|^标准工资$|^月薪$|^base$|^basicsalary$|^basic$|^基本工资底薪$/.test(n)) return 'base_salary'

  // ═══ 加项（breakdown 加法） ═══
  if (/岗位工资/.test(n)) return 'add_position'
  if (/职务工资/.test(n)) return 'add_duty'
  if (/加班工资|加班费/.test(n) && !/节假日/.test(n)) return 'add_overtime'
  if (/节假日加班|法定.*加班/.test(n)) return 'add_holiday_ot'
  if (/绩效工资|绩效奖金|绩效$/.test(n)) return 'add_performance'
  if (/工龄补贴|工龄工资/.test(n)) return 'add_seniority'
  if (/销售提成|提成$/.test(n)) return 'add_commission'
  if (/全勤奖|全勤$/.test(n)) return 'add_attendance'
  if (/餐费补助|餐补|餐费|饭补/.test(n)) return 'add_meal'
  if (/岗位津贴/.test(n)) return 'add_allowance'
  if (/交通补贴|车补|话补|通讯补贴/.test(n)) return 'add_transport'
  if (/其他补贴|其他津贴|奖金$/.test(n)) return 'add_other'

  // ═══ 扣项（breakdown 减法） ═══
  if (/^社保$|养老保险|医疗保险|失业保险|工伤保险|生育保险|五险/.test(n)) return 'ded_social'
  if (/公积金|住房公积金/.test(n)) return 'ded_housing'
  if (/个人所得税|个税$|所得税/.test(n)) return 'ded_tax'
  if (/考勤.*扣款|考勤绩效$/.test(n)) return 'ded_attendance'
  if (/旷工扣款/.test(n)) return 'ded_absence'
  if (/请假扣款/.test(n)) return 'ded_leave'
  if (/住宿费|代扣.*水电/.test(n)) return 'ded_dorm'
  if (/其他扣款/.test(n)) return 'ded_other'

  // ═══ 考勤类（不参与金额计算，塞 note） ═══
  if (/出勤天数|出勤日|实际出勤|实际上班|加班天数|加班日|请假天数|迟到|早退|漏打卡|旷工天数|法定假|假期|实休|未休/.test(n)) {
    return null // 考勤信息目前不导入；之后要的话加 attendance_* 字段
  }

  // ═══ 备注/部门/岗位（塞进 note） ═══
  if (/备注|note|remark|说明|附注|摘要/.test(n)) return 'note'
  if (/部门|department|dept|岗位|职位|position|职务|小组|分组|入职日期|工龄/.test(n)) return 'note'
  return null
}

function num(v) {
  if (v == null || v === '') return 0
  let s = String(v).trim()
  if (!s) return 0
  if (/^#[A-Z/]+!?$/i.test(s)) return 0
  let neg = false
  if (/^\(.*\)$/.test(s)) {
    neg = true
    s = s.slice(1, -1)
  }
  const cleaned = s.replace(/[¥￥$,,\s元RMB]/gi, '')
  const n = Number(cleaned)
  if (isNaN(n)) return 0
  return neg ? -n : n
}

// 将 Excel 里可能的各种月份格式归一为 YYYY-MM
// 支持："2025-03" "2025/3" "2025年3月" "2025.3" "2025 年 3 月" "03/2025" "202503"
// Excel 序列日期直接认识（sheet_to_json 用 raw:false 时大部分已转字符串，但兜底处理）
function normalizeMonth(v) {
  if (v == null || v === '') return ''
  if (v instanceof Date && !isNaN(v)) {
    return `${v.getFullYear()}-${String(v.getMonth() + 1).padStart(2, '0')}`
  }
  const s = String(v).trim()
  if (!s) return ''
  // 2025-03 / 2025/3 / 2025.3 / 2025年3月
  let m = s.match(/(\d{4})\s*[-/.年]\s*(\d{1,2})\s*月?/)
  if (m) return `${m[1]}-${String(Number(m[2])).padStart(2, '0')}`
  // 03/2025 或 3-2025
  m = s.match(/^(\d{1,2})\s*[-/.]\s*(\d{4})$/)
  if (m) return `${m[2]}-${String(Number(m[1])).padStart(2, '0')}`
  // 202503（连写）
  m = s.match(/^(\d{4})(\d{2})$/)
  if (m) return `${m[1]}-${m[2]}`
  return ''
}

// 归一为 YYYY-MM-DD；支持 Date、Excel 字符串日期、中文"2025年3月15日"
function normalizeDate(v) {
  if (v == null || v === '') return ''
  if (v instanceof Date && !isNaN(v)) {
    return v.toISOString().slice(0, 10)
  }
  const s = String(v).trim()
  if (!s) return ''
  let m = s.match(/(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?/)
  if (m) {
    const mm = String(Number(m[2])).padStart(2, '0')
    const dd = String(Number(m[3])).padStart(2, '0')
    return `${m[1]}-${mm}-${dd}`
  }
  // Excel 偶尔吐出 ISO：
  m = s.match(/^(\d{4}-\d{2}-\d{2})/)
  if (m) return m[1]
  return ''
}

function isEmptyRow(row) {
  return !row || row.every(c => c == null || String(c).trim() === '')
}

function looksLikeHeaderRow(row) {
  if (!row || row.length === 0) return false
  let textCount = 0
  let numCount = 0
  for (const c of row) {
    const s = String(c || '').trim()
    if (!s) continue
    if (/^-?\d[\d.,]*$/.test(s.replace(/[¥￥$,,\s元RMB]/gi, ''))) {
      numCount++
    } else {
      textCount++
    }
  }
  return textCount > 0 && numCount === 0
}

function parseSheet(sheetName) {
  const wb = pendingWorkbook.value
  if (!wb) return
  const ws = wb.Sheets[sheetName]
  if (!ws) {
    toast(`Sheet "${sheetName}" 不存在`, 'error')
    return
  }
  const rawRows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '', raw: false })
  if (rawRows.length < 2) {
    previewRows.value = []
    toast(`Sheet "${sheetName}" 内容太少，至少需要表头行 + 1 行数据`, 'warning')
    return
  }

  let headerRowIdx = -1
  for (let i = 0; i < Math.min(rawRows.length, 8); i++) {
    const row = rawRows[i]
    if (row.some(c => /姓名|员工|name/i.test(String(c || '')))) {
      headerRowIdx = i
      break
    }
  }
  if (headerRowIdx < 0) headerRowIdx = 0

  const topRow = rawRows[headerRowIdx].map(c => String(c || '').trim())
  let subRow = null
  let dataStartIdx = headerRowIdx + 1
  if (
    headerRowIdx + 1 < rawRows.length &&
    looksLikeHeaderRow(rawRows[headerRowIdx + 1])
  ) {
    subRow = rawRows[headerRowIdx + 1].map(c => String(c || '').trim())
    dataStartIdx = headerRowIdx + 2
  }

  const maxLen = Math.max(topRow.length, subRow ? subRow.length : 0)
  const headers = []
  for (let i = 0; i < maxLen; i++) {
    const top = topRow[i] || ''
    const sub = subRow ? (subRow[i] || '') : ''
    if (top && sub) headers.push(`${top} / ${sub}`)
    else headers.push(top || sub)
  }

  // 字段 -> 列下标数组。除了基础五项，加项/扣项按细分 key 分别收集
  const ADD_KEYS = ['add_position','add_duty','add_overtime','add_holiday_ot','add_performance','add_seniority','add_commission','add_attendance','add_meal','add_allowance','add_transport','add_other']
  const DED_KEYS = ['ded_social','ded_housing','ded_tax','ded_attendance','ded_absence','ded_leave','ded_dorm','ded_other']
  const fieldCols = { employee_name: [], base_salary: [], actual_amount: [], gross_amount: [], ded_total: [], note: [], pay_month: [], pay_date: [] }
  for (const k of ADD_KEYS) fieldCols[k] = []
  for (const k of DED_KEYS) fieldCols[k] = []
  headers.forEach((h, idx) => {
    const f = normalizeColumn(h)
    if (f && fieldCols[f]) {
      fieldCols[f].push(idx)
    }
  })

  // 实发没识别到但应发识别到 → 降级：用应发当实发（没扣款栏的简易表）
  const hasActual = fieldCols.actual_amount.length > 0 || fieldCols.gross_amount.length > 0
  if (fieldCols.employee_name.length === 0 || !hasActual) {
    previewRows.value = []
    toast(`Sheet "${sheetName}" 未识别到"姓名"或"实发/应发金额"列`, 'warning')
    return
  }

  // 细分列中文名（用于 note 里的【拆分】行和预览展示）
  const FIELD_LABELS = {
    add_position: '岗位', add_duty: '职务', add_overtime: '加班', add_holiday_ot: '节假日加班',
    add_performance: '绩效', add_seniority: '工龄', add_commission: '提成', add_attendance: '全勤',
    add_meal: '餐补', add_allowance: '岗位津贴', add_transport: '交通', add_other: '其他补贴',
    ded_social: '社保', ded_housing: '公积金', ded_tax: '个税', ded_attendance: '考勤扣款',
    ded_absence: '旷工扣款', ded_leave: '请假扣款', ded_dorm: '住宿', ded_other: '其他扣款',
  }

  const parsed = []
  for (let i = dataStartIdx; i < rawRows.length; i++) {
    const row = rawRows[i]
    if (isEmptyRow(row)) continue

    let employee_name = ''
    for (const colIdx of fieldCols.employee_name) {
      const v = String(row[colIdx] || '').trim()
      if (v) { employee_name = v; break }
    }

    let base_salary = 0
    for (const colIdx of fieldCols.base_salary) base_salary += num(row[colIdx])

    // 实发：只取识别成"实发"的列；只要有一列有值就用它（多列求第一个非零）
    let actual_amount = 0
    for (const colIdx of fieldCols.actual_amount) {
      const v = num(row[colIdx])
      if (v !== 0) { actual_amount = v; break }
    }
    // 应发：参考值，若实发缺就顶替
    let gross_amount = 0
    for (const colIdx of fieldCols.gross_amount) {
      const v = num(row[colIdx])
      if (v !== 0) { gross_amount = v; break }
    }
    if (!actual_amount && gross_amount) {
      // 没有实发列，用应发兜底（简易表场景）
      actual_amount = gross_amount
    }

    // 聚合加项/扣项到细分 key
    const addItems = {} // { add_position: 1400, ... }
    const dedItems = {}
    let addSum = 0
    let dedSum = 0
    for (const k of ADD_KEYS) {
      let s = 0
      for (const colIdx of fieldCols[k]) s += num(row[colIdx])
      if (s !== 0) { addItems[k] = s; addSum += s }
    }
    for (const k of DED_KEYS) {
      let s = 0
      for (const colIdx of fieldCols[k]) s += num(row[colIdx])
      if (s !== 0) { dedItems[k] = s; dedSum += s }
    }

    // 拼【拆分】行：底薪 X + 岗位 Y + ... - 社保 A - 个税 B = 实发 Z
    const partsArr = [`底薪 ${base_salary.toFixed(2)}`]
    for (const k of ADD_KEYS) {
      if (addItems[k]) partsArr.push(`+ ${FIELD_LABELS[k]} ${addItems[k].toFixed(2)}`)
    }
    for (const k of DED_KEYS) {
      if (dedItems[k]) partsArr.push(`- ${FIELD_LABELS[k]} ${dedItems[k].toFixed(2)}`)
    }
    const hasAnyBreakdown = Object.keys(addItems).length + Object.keys(dedItems).length > 0
    const breakdownLine = hasAnyBreakdown
      ? `【拆分】${partsArr.join(' ')} = 实发 ${actual_amount.toFixed(2)}`
      : ''

    const noteParts = []
    if (breakdownLine) noteParts.push(breakdownLine)
    for (const colIdx of fieldCols.note) {
      const v = String(row[colIdx] || '').trim()
      if (v) noteParts.push(v)
    }
    const note = noteParts.join('\n')

    // 可选：Excel 内直接指定发薪月份/实际发薪日期
    let pay_month = ''
    for (const colIdx of fieldCols.pay_month) {
      const v = normalizeMonth(row[colIdx])
      if (v) { pay_month = v; break }
    }
    let pay_date = ''
    for (const colIdx of fieldCols.pay_date) {
      const v = normalizeDate(row[colIdx])
      if (v) { pay_date = v; break }
    }

    const obj = {
      employee_name, base_salary, actual_amount, note, pay_month, pay_date,
      // 下列字段仅在预览时展示/校验，不直接入库（通过 note 的【拆分】行持久化）
      _gross: gross_amount || (base_salary + addSum),
      _addSum: addSum,
      _dedSum: dedSum,
      _addItems: addItems,
      _dedItems: dedItems,
    }

    if (!obj.employee_name) {
      const hasAnyData = row.some(c => String(c || '').trim() !== '')
      if (!hasAnyData) continue
      obj._valid = false
      obj._reason = '姓名为空'
    } else if (/合计|小计|总计|汇总|总额|总数|总人/.test(obj.employee_name)) {
      obj._valid = false
      obj._reason = '汇总行，跳过'
    } else if (/^[销技财人行运产工市后客]\S{0,3}部$|^[销技财人行运产工市后客]\S{0,3}组$|^[一二三四五六七八九十0-9]+部$/.test(obj.employee_name) && actual_amount === 0) {
      obj._valid = false
      obj._reason = '部门分组行，跳过'
    } else if (obj.actual_amount <= 0) {
      obj._valid = false
      obj._reason = '实发金额为 0'
    } else {
      obj._valid = true
    }
    parsed.push(obj)
  }
  previewRows.value = parsed
}

// 预览弹窗里展示【拆分】明细用（和 parseSheet 里的 FIELD_LABELS 一致）
const PREVIEW_LABELS = {
  add_position: '岗位', add_duty: '职务', add_overtime: '加班', add_holiday_ot: '节假日加班',
  add_performance: '绩效', add_seniority: '工龄', add_commission: '提成', add_attendance: '全勤',
  add_meal: '餐补', add_allowance: '岗位津贴', add_transport: '交通', add_other: '其他补贴',
  ded_social: '社保', ded_housing: '公积金', ded_tax: '个税', ded_attendance: '考勤扣款',
  ded_absence: '旷工扣款', ded_leave: '请假扣款', ded_dorm: '住宿', ded_other: '其他扣款',
}
function hasBreakdownItems(r) {
  return !!(r && ((r._addItems && Object.keys(r._addItems).length > 0) || (r._dedItems && Object.keys(r._dedItems).length > 0)))
}
function formatBreakdownShort(r) {
  const parts = []
  if (r._addItems) {
    for (const [k, v] of Object.entries(r._addItems)) {
      if (v) parts.push(`+${PREVIEW_LABELS[k] || k}${Number(v).toFixed(0)}`)
    }
  }
  if (r._dedItems) {
    for (const [k, v] of Object.entries(r._dedItems)) {
      if (v) parts.push(`-${PREVIEW_LABELS[k] || k}${Number(v).toFixed(0)}`)
    }
  }
  return parts.join(' ')
}
function formatBreakdownTitle(r) {
  // 鼠标悬停显示完整拆分（带两位小数），方便核对
  const parts = [`底薪 ${Number(r.base_salary || 0).toFixed(2)}`]
  if (r._addItems) {
    for (const [k, v] of Object.entries(r._addItems)) {
      if (v) parts.push(`+ ${PREVIEW_LABELS[k] || k} ${Number(v).toFixed(2)}`)
    }
  }
  if (r._dedItems) {
    for (const [k, v] of Object.entries(r._dedItems)) {
      if (v) parts.push(`- ${PREVIEW_LABELS[k] || k} ${Number(v).toFixed(2)}`)
    }
  }
  return parts.join(' ') + ` = 实发 ${Number(r.actual_amount || 0).toFixed(2)}`
}

// 用户在预览弹窗里直接改了某行的姓名/实发金额后，重算 _valid / _reason
// 让用户看到"现在这行能不能被导入"的实时反馈
function revalidatePreviewRow(r) {
  const name = String(r.employee_name || '').trim()
  const amt = Number(r.actual_amount) || 0
  if (!name) {
    r._valid = false
    r._reason = '姓名为空'
    return
  }
  if (/合计|小计|总计|汇总|总额|总数|总人/.test(name)) {
    r._valid = false
    r._reason = '汇总行，跳过'
    return
  }
  if (amt <= 0) {
    r._valid = false
    r._reason = '实发金额为 0'
    return
  }
  r._valid = true
  r._reason = ''
}

// 密码输入弹窗状态
const showPwdModal = ref(false)
const pwdInput = ref('')
const pwdError = ref('')
const pendingFileBinary = ref(null) // 保存二进制内容,供用户输入密码后重试
const pendingFileName = ref('')

// 尝试用指定密码解析(密码为空等价于无密码)
function tryParseWorkbook(binary, password) {
  const opts = { type: 'binary' }
  if (password) opts.password = password
  return XLSX.read(binary, opts)
}

// 用解析成功的 workbook 填充 preview
function fillPreviewFromWorkbook(wb) {
  pendingWorkbook.value = wb
  availableSheets.value = wb.SheetNames.slice()
  selectedSheet.value = wb.SheetNames[0]
  parseSheet(selectedSheet.value)
  showPreview.value = true
  if (validPreviewRows.value.length === 0 && availableSheets.value.length > 1) {
    toast(`首个 Sheet 未解析到有效行，可在弹窗顶部切换其他 Sheet`, 'warning')
  } else if (validPreviewRows.value.length === 0) {
    toast('未解析到任何有效行', 'warning')
  }
}

function handleFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = (ev) => {
    const binary = ev.target.result
    pendingFileBinary.value = binary
    pendingFileName.value = file.name
    try {
      const wb = tryParseWorkbook(binary, '')
      if (!wb || !wb.SheetNames || wb.SheetNames.length === 0) {
        toast('未读到任何 Sheet', 'error')
        return
      }
      fillPreviewFromWorkbook(wb)
    } catch (err) {
      console.error('[SalaryManagement] excel parse error:', err)
      if (/password|encrypt/i.test(err.message || '')) {
        // 加密文件 → 弹密码输入框
        pwdInput.value = ''
        pwdError.value = ''
        showPwdModal.value = true
      } else {
        toast('文件解析失败: ' + err.message, 'error')
      }
    }
  }
  reader.readAsBinaryString(file)
  if (fileInput.value) fileInput.value.value = ''
}

// 密码输入后重试
function submitPwd() {
  if (!pendingFileBinary.value) {
    showPwdModal.value = false
    return
  }
  try {
    const wb = tryParseWorkbook(pendingFileBinary.value, pwdInput.value)
    if (!wb || !wb.SheetNames || wb.SheetNames.length === 0) {
      pwdError.value = '未读到任何 Sheet'
      return
    }
    showPwdModal.value = false
    fillPreviewFromWorkbook(wb)
  } catch (err) {
    console.error('[SalaryManagement] excel parse (pwd) error:', err)
    const msg = String(err.message || err)
    // SheetJS 社区版对 .xlsx AES 加密不支持,只支持 .xls 的 XOR/RC4
    if (/\.xlsx|ECMA-376|agile/i.test(msg) || pendingFileName.value.toLowerCase().endsWith('.xlsx')) {
      pwdError.value = 'xlsx 的 AES 加密本系统暂不支持。请在 Excel 里另存为"无密码"版本再上传(文件 → 另存为 → 工具 → 常规选项 → 清空密码)。'
    } else if (/password|密码/i.test(msg)) {
      pwdError.value = '密码错误，请重试'
    } else {
      pwdError.value = '解析失败: ' + msg
    }
  }
}

function cancelPwd() {
  showPwdModal.value = false
  pendingFileBinary.value = null
  pendingFileName.value = ''
  pwdInput.value = ''
  pwdError.value = ''
}

const importError = ref('')

async function confirmImport() {
  if (validPreviewRows.value.length === 0) return
  importing.value = true
  importError.value = ''
  try {
    const rows = validPreviewRows.value.map(r => ({
      employee_name: r.employee_name,
      base_salary: r.base_salary || null,
      actual_amount: r.actual_amount,
      // 若 Excel 指定了月份 / 发薪日期则尊重，否则走界面当前 payMonth
      pay_month: r.pay_month || payMonth.value,
      pay_date: r.pay_date || null,
      note: r.note || null,
    }))
    const { error } = await supabase.from('salaries').insert(rows)
    if (error) throw error
    toast(`导入成功：${rows.length} 条`, 'success')
    closePreview()
    await loadSalaries()
  } catch (e) {
    console.error('[SalaryManagement] import error:', e)
    const details = []
    if (e.message) details.push(`message: ${e.message}`)
    if (e.code) details.push(`code: ${e.code}`)
    if (e.details) details.push(`details: ${e.details}`)
    if (e.hint) details.push(`hint: ${e.hint}`)
    importError.value = details.join(' | ') || String(e)
    toast('导入失败: ' + (e.message || e), 'error')
  } finally {
    importing.value = false
  }
}

// ─── 模板下载 ───
function downloadTemplate() {
  // 发薪月份/发薪日期 为可选列：留空则按界面当前月份导入；填写则覆盖
  const wsData = [
    ['姓名', '基本工资', '实发金额', '发薪月份(可选)', '发薪日期(可选)', '备注'],
    ['示例员工A', 5000, 5500, payMonth.value, '', '岗位津贴 500'],
    ['示例员工B', 6000, 6300, '', '', ''],
  ]
  const ws = XLSX.utils.aoa_to_sheet(wsData)
  ws['!cols'] = [{ wch: 15 }, { wch: 12 }, { wch: 12 }, { wch: 16 }, { wch: 16 }, { wch: 20 }]
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, '工资表')
  XLSX.writeFile(wb, `工资导入模板_${payMonth.value}.xlsx`)
}

// ─── 单条增删改 ───
const showModal = ref(false)
const submitting = ref(false)
const formError = ref('')
const editingId = ref(null)
const form = reactive({
  employee_name: '', base_salary: 0, actual_amount: 0, pay_month: '', pay_date: '', note: '',
  // Phase 2-J: 详细拆分（不落库，通过 note 文本持久化）
  breakdown: { bonus: 0, allowance: 0, social: 0, housing: 0, tax: 0, other: 0 },
})
const breakdownExpanded = ref(false)
// 历史员工姓名聚合（D 员工主数据的轻量实现）
const knownEmployees = ref([])

async function refreshKnownEmployees() {
  try {
    const { data, error } = await supabase
      .from('salaries')
      .select('employee_name')
      .is('deleted_at', null)
      .not('employee_name', 'is', null)
      .limit(5000)
    if (error) return
    const set = new Set()
    for (const r of data || []) {
      const name = (r.employee_name || '').trim()
      if (name) set.add(name)
    }
    knownEmployees.value = Array.from(set).sort()
  } catch (e) {
    console.warn('[SalaryManagement] refreshKnownEmployees failed:', e)
  }
}

// ─── 细分字段：公式 + 解析 ───
// 在备注里用形如 "【拆分】基本 8000 + 奖金 2000 - 社保 500 - 个税 200 = 9300" 的标记行持久化
const BREAKDOWN_PREFIX = '【拆分】'

const breakdownHasValue = computed(() => {
  const b = form.breakdown
  return !!(b.bonus || b.allowance || b.social || b.housing || b.tax || b.other)
})

const breakdownComputed = computed(() => {
  const base = Number(form.base_salary) || 0
  const b = form.breakdown
  return base
    + (Number(b.bonus) || 0)
    + (Number(b.allowance) || 0)
    - (Number(b.social) || 0)
    - (Number(b.housing) || 0)
    - (Number(b.tax) || 0)
    - (Number(b.other) || 0)
})

const breakdownFormula = computed(() => {
  const parts = [`基本 ${Number(form.base_salary || 0).toFixed(2)}`]
  const b = form.breakdown
  if (Number(b.bonus))    parts.push(`+ 奖金 ${Number(b.bonus).toFixed(2)}`)
  if (Number(b.allowance))parts.push(`+ 津贴 ${Number(b.allowance).toFixed(2)}`)
  if (Number(b.social))   parts.push(`- 社保 ${Number(b.social).toFixed(2)}`)
  if (Number(b.housing))  parts.push(`- 公积金 ${Number(b.housing).toFixed(2)}`)
  if (Number(b.tax))      parts.push(`- 个税 ${Number(b.tax).toFixed(2)}`)
  if (Number(b.other))    parts.push(`- 其他 ${Number(b.other).toFixed(2)}`)
  return parts.join(' ') + ` = ${breakdownComputed.value.toFixed(2)}`
})

function applyBreakdownToActual() {
  form.actual_amount = Math.round(breakdownComputed.value * 100) / 100
  // 把公式行写入 note（替换已存在的拆分行）
  const formulaLine = `${BREAKDOWN_PREFIX}${breakdownFormula.value}`
  const noteLines = (form.note || '').split('\n').filter(l => !l.startsWith(BREAKDOWN_PREFIX))
  form.note = [formulaLine, ...noteLines].join('\n').trim()
  toast('已应用到实发金额', 'success')
}

// 编辑时从 note 反向解析 breakdown
function parseBreakdownFromNote(note) {
  const reset = { bonus: 0, allowance: 0, social: 0, housing: 0, tax: 0, other: 0 }
  if (!note) return reset
  const line = note.split('\n').find(l => l.startsWith(BREAKDOWN_PREFIX))
  if (!line) return reset
  // 匹配 "奖金 1000" / "- 社保 500" 等
  const mapping = { '奖金': 'bonus', '津贴': 'allowance', '社保': 'social', '公积金': 'housing', '个税': 'tax', '其他': 'other' }
  for (const [cn, key] of Object.entries(mapping)) {
    const m = line.match(new RegExp(`${cn}\\s*([0-9.]+)`))
    if (m) reset[key] = Number(m[1]) || 0
  }
  return reset
}

function resetForm() {
  form.employee_name = ''
  form.base_salary = 0
  form.actual_amount = 0
  form.pay_month = payMonth.value
  form.pay_date = ''
  form.note = ''
  form.breakdown = { bonus: 0, allowance: 0, social: 0, housing: 0, tax: 0, other: 0 }
  breakdownExpanded.value = false
}

function openCreateModal() {
  editingId.value = null
  resetForm()
  formError.value = ''
  showModal.value = true
  refreshKnownEmployees()
}

function openEditModal(row) {
  editingId.value = row.id
  form.employee_name = row.employee_name
  form.base_salary = Number(row.base_salary || 0)
  form.actual_amount = Number(row.actual_amount || 0)
  form.pay_month = row.pay_month || payMonth.value
  form.pay_date = row.pay_date || ''
  form.note = row.note || ''
  form.breakdown = parseBreakdownFromNote(row.note)
  // 如果 note 里有拆分行，自动展开面板
  breakdownExpanded.value = (form.note || '').includes(BREAKDOWN_PREFIX)
  formError.value = ''
  showModal.value = true
  refreshKnownEmployees()
}

async function submitForm() {
  submitting.value = true
  formError.value = ''
  try {
    const payload = {
      employee_name: form.employee_name.trim(),
      base_salary: form.base_salary || null,
      actual_amount: form.actual_amount,
      pay_month: form.pay_month,
      pay_date: form.pay_date || null,
      note: form.note || null,
    }
    if (editingId.value) {
      const { error } = await supabase.from('salaries').update(payload).eq('id', editingId.value)
      if (error) throw error
      toast('更新成功', 'success')
    } else {
      const { error } = await supabase.from('salaries').insert(payload)
      if (error) throw error
      toast('新增成功', 'success')
    }
    showModal.value = false
    await loadSalaries()
  } catch (e) {
    console.error('[SalaryManagement] submit error:', e)
    const details = []
    if (e.message) details.push(`message: ${e.message}`)
    if (e.code) details.push(`code: ${e.code}`)
    if (e.details) details.push(`details: ${e.details}`)
    if (e.hint) details.push(`hint: ${e.hint}`)
    formError.value = details.join(' | ') || String(e)
    toast('保存失败: ' + (e.message || e), 'error')
  } finally {
    submitting.value = false
  }
}

async function handleDelete(row) {
  // 不再弹 confirm，直接软删并显示"撤销"浮条（stageUndo 负责 8s 内可回滚）
  // 如果是已发放的工资（pay_date 非空），需要把关联的支出退回账户余额
  try {
    // 1) 先退款（找到关联的已付款支出 → 退回账户 → 软删支出）
    const refunds = await refundExpensesForSalary(row)
    // 2) 再软删工资记录
    const { error } = await supabase.from('salaries').update({ deleted_at: new Date().toISOString() }).eq('id', row.id)
    if (error) throw error
    await loadSalaries()
    if (refunds.length > 0) {
      const totalRefund = refunds.reduce((s, r) => s + Number(r.amount || 0), 0)
      toast(`已删除 ${row.employee_name} 的工资，退回账户 ¥${totalRefund.toFixed(2)}`, 'success')
    }
    stageUndo([row], 'single', refunds)
  } catch (e) {
    console.error('[SalaryManagement] delete error:', e)
    toast('删除失败: ' + e.message, 'error')
  }
}

// ─── A: 发放工资链路 ───
const showPayModal = ref(false)
const paying = ref(false)
const payTargets = ref([]) // 待发放的 salary 行
// splits: 单人模式下可以多行 {account_id, amount}；批量模式固定 1 行 {account_id, amount:0（忽略）}
const payForm = reactive({ splits: [], pay_date: '' })
// 批量发放进度（实时更新按钮文案）
const payProgress = reactive({ done: 0, total: 0 })

// 并发执行器（支持中断）：最多 limit 条路同时跑，相比串行 for-await 快数倍
// worker(item, idx, abort) 里调用 abort() 可以让"还没开始的"任务停下来
// 正在跑的 in-flight 任务会自己走完；未领取的 items 在结果里对应 undefined
// 返回 { results: [{ ok, value } | { ok: false, error } | undefined], aborted: boolean }
async function runConcurrent(items, worker, limit = 4) {
  const results = new Array(items.length)
  let cursor = 0
  let aborted = false
  const abort = () => { aborted = true }
  const runOne = async () => {
    while (cursor < items.length && !aborted) {
      const idx = cursor++
      try {
        results[idx] = { ok: true, value: await worker(items[idx], idx, abort) }
      } catch (e) {
        results[idx] = { ok: false, error: e }
      }
    }
  }
  const workers = Array.from({ length: Math.min(limit, items.length) }, runOne)
  await Promise.all(workers)
  return { results, aborted }
}

const accountOptions = computed(() => {
  // 只列出活跃且非资产科目(排除往来/受限)，避免误选
  return (accountStore.accounts || []).filter(a => {
    if (a.status && a.status !== 'active') return false
    return true
  })
})

function getAccountName(id) {
  if (!id) return ''
  const a = (accountStore.accounts || []).find(x => x.id === id)
  return a?.short_name || a?.code || '--'
}

// 单行在批量/单人不同模式下，"需要金额"不一样：
// 单人模式下，当前行的 amount 就是本行要扣的钱；批量模式下所有人共用一个账户，
// 需要 = 全部实发合计
function splitRowNeed(idx) {
  if (isSinglePay.value) return Number(payForm.splits[idx]?.amount) || 0
  return payTotalAmount.value
}

// option 文案：给每个账户前面加 ⚠（余额不足）/ 空白（足够）。
// 批量模式下所有 option 统一按 payTotalAmount 做判断；
// 单人模式按当前行最大 amount 做参考（保守：只要有一行不够，就提示）
// 性能：把 need 抽成 computed，避免在 v-for 的 option 上每次重新 reduce
const accountOptionNeed = computed(() => {
  if (isSinglePay.value) {
    let max = 0
    for (const s of payForm.splits) {
      const a = Number(s.amount) || 0
      if (a > max) max = a
    }
    return max
  }
  return payTotalAmount.value
})
function accountOptionLabel(a) {
  const need = accountOptionNeed.value
  const bal = Number(a.balance || 0)
  const name = a.short_name || a.code || '--'
  const balText = bal.toFixed(2)
  if (need > 0 && bal < need) return `⚠ ${name}（余额 ¥${balText}）`
  if (bal <= 0) return `⚠ ${name}（余额 ¥${balText}）`
  return `${name}（余额 ¥${balText}）`
}

// 已选账户对应的余额提示样式：返回 { ok, warn, text } 用于行尾小徽章
function splitRowBadge(idx) {
  const accId = payForm.splits[idx]?.account_id
  if (!accId) return null
  const a = (accountStore.accounts || []).find(x => x.id === accId)
  if (!a) return null
  const bal = Number(a.balance || 0)
  const need = splitRowNeed(idx)
  if (need <= 0) return { ok: true, text: `余额 ¥${bal.toFixed(2)}` }
  if (bal >= need) return { ok: true, text: `余额 ¥${bal.toFixed(2)}` }
  const gap = Math.max(0, need - bal)
  return { warn: true, text: `差 ¥${gap.toFixed(2)}` }
}

// 模板侧用这个缓存版本：避免 v-if/v-class/文案三处分别调函数
const splitRowBadges = computed(() => payForm.splits.map((_, i) => splitRowBadge(i)))

const payTotalAmount = computed(() => payTargets.value.reduce((s, r) => s + Number(r.actual_amount || 0), 0))
const isSinglePay = computed(() => payTargets.value.length === 1)

const splitAllocated = computed(() => {
  if (!isSinglePay.value) return payTotalAmount.value
  return payForm.splits.reduce((s, x) => s + (Number(x.amount) || 0), 0)
})

// 差额：正数表示应发 > 已分配（缺），负数表示应发 < 已分配（多）。保留两位小数避免浮点误差
const splitMismatch = computed(() => {
  const diff = payTotalAmount.value - splitAllocated.value
  return Math.round(diff * 100) / 100
})

// 对每个 split 单独校验余额。返回合并的告警字符串（或 ''）
const payBalanceWarn = computed(() => {
  // 按账户聚合待发金额，支持同一员工从同一账户拆多行的极端场景
  const needByAccount = new Map()
  if (isSinglePay.value) {
    for (const s of payForm.splits) {
      if (!s.account_id) continue
      const amt = Number(s.amount) || 0
      if (amt <= 0) continue
      needByAccount.set(s.account_id, (needByAccount.get(s.account_id) || 0) + amt)
    }
  } else {
    // 批量模式：只有一个账户，金额 = 所有员工之和
    const accId = payForm.splits[0]?.account_id
    if (!accId) return ''
    needByAccount.set(accId, payTotalAmount.value)
  }
  const warns = []
  for (const [accId, need] of needByAccount) {
    const acc = (accountStore.accounts || []).find(a => a.id === accId)
    if (!acc) continue
    const balance = Number(acc.balance || 0)
    if (balance < need) {
      warns.push(`${acc.short_name || acc.code}余额 ¥${balance.toFixed(2)} < 需发 ¥${need.toFixed(2)}（差额 ¥${(need - balance).toFixed(2)}）`)
    }
  }
  return warns.join('；')
})

// 能否提交发放按钮
const canSubmitPay = computed(() => {
  if (payTargets.value.length === 0) return false
  if (!payForm.pay_date) return false
  if (payForm.splits.length === 0) return false
  // 所有 split 必须选了账户
  if (payForm.splits.some(s => !s.account_id)) return false
  if (isSinglePay.value) {
    // 金额必须对得上
    if (splitMismatch.value !== 0) return false
    // 每行金额必须 > 0
    if (payForm.splits.some(s => !(Number(s.amount) > 0))) return false
  }
  return true
})

function addSplit() {
  if (!isSinglePay.value) return
  // 智能填充：
  // 1. 如果已有行里有"金额超过账户余额"的情况，把溢出部分切到新行（典型场景：现金账户钱不够）
  // 2. 否则退化为用当前差额填充
  let overflow = 0
  for (const s of payForm.splits) {
    if (!s.account_id) continue
    const acc = (accountStore.accounts || []).find(a => a.id === s.account_id)
    if (!acc) continue
    const bal = Number(acc.balance || 0)
    const amt = Number(s.amount) || 0
    if (amt > bal) {
      // 把超支部分切出来，该行只发账户能覆盖的金额
      overflow += (amt - bal)
      s.amount = Math.round(bal * 100) / 100
    }
  }
  const fill = overflow > 0
    ? overflow
    : (splitMismatch.value > 0 ? splitMismatch.value : 0)
  payForm.splits.push({ account_id: '', amount: Math.round(fill * 100) / 100 })
}

function removeSplit(idx) {
  if (!isSinglePay.value) return
  if (payForm.splits.length <= 1) return
  payForm.splits.splice(idx, 1)
}

function autoFillLastSplit() {
  if (!isSinglePay.value) return
  if (payForm.splits.length === 0) return
  const last = payForm.splits[payForm.splits.length - 1]
  const newAmt = (Number(last.amount) || 0) + splitMismatch.value
  // 保留 2 位小数
  last.amount = Math.round(newAmt * 100) / 100
}

function todayStr() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function openPayModal(row) {
  payTargets.value = [row]
  payForm.splits = [{ account_id: row.account_id || '', amount: Number(row.actual_amount || 0) }]
  payForm.pay_date = todayStr()
  showPayModal.value = true
}

function openPayModalBatch() {
  const rows = displayedRecords.value.filter(r => selectedIds.value.has(r.id) && !r.pay_date)
  if (rows.length === 0) {
    toast('所选记录都已发放', 'warning')
    return
  }
  payTargets.value = rows
  // 批量模式：只允许一个账户，金额在 splits[0].amount 不参与计算（按每条 salary 的 actual_amount 发）
  payForm.splits = [{ account_id: '', amount: 0 }]
  payForm.pay_date = todayStr()
  showPayModal.value = true
}

async function submitPay() {
  if (!canSubmitPay.value || payTargets.value.length === 0) return
  if (payBalanceWarn.value) {
    if (!confirm(`账户余额不足：\n${payBalanceWarn.value}\n\n仍继续发放？`)) return
  }
  paying.value = true
  const successIds = []
  const failures = []
  try {
    // 把 pay_date 统一成 noon timestamp，发薪日落在那天而不是 00:00 边界
    const payDateTs = new Date(payForm.pay_date + 'T12:00:00').toISOString()

    if (isSinglePay.value) {
      // ── 单人模式：一个员工可能由多个账户拆分发放 ──
      const row = payTargets.value[0]
      const expenseIds = [] // 这次成功创建的 expense id，任何一笔失败要把前面的全部回滚
      let allPaid = false
      try {
        for (const s of payForm.splits) {
          const amt = Number(s.amount) || 0
          if (amt <= 0) continue
          const expense = await expensesStore.createExpense({
            category: '工资',
            amount: amt,
            payee: row.employee_name,
            account_id: s.account_id,
            note: payForm.splits.length > 1
              ? `工资发放(拆分 ${expenseIds.length + 1}/${payForm.splits.length}): ${row.employee_name} (${row.pay_month})`
              : `工资发放: ${row.employee_name} (${row.pay_month})`,
            expense_date: payForm.pay_date,
          })
          expenseIds.push(expense?.id)
          // 回写 paid_at 到发薪日
          if (expense?.id) {
            try {
              await supabase.from('expenses').update({ paid_at: payDateTs }).eq('id', expense.id)
            } catch (e) {
              console.warn('[SalaryManagement] backfill paid_at failed:', e)
            }
          }
        }
        allPaid = true
      } catch (e) {
        // 任意一笔失败：把这次已创建的 expense 软删除（触发余额回补由 createExpense 的回滚逻辑已处理）
        // 这里 expense 已经 insert 成功，需要显式删除 + 退款
        console.error('[SalaryManagement] split pay failed, rolling back:', e)
        for (const eid of expenseIds) {
          if (!eid) continue
          try {
            // 查询 expense 细节，退回账户
            const { data: ex } = await supabase.from('expenses').select('amount, account_id').eq('id', eid).single()
            if (ex?.account_id && ex?.amount) {
              try {
                const { useAccountStore: _u } = await import('../stores/accounts')
                await _u().updateBalance(ex.account_id, Number(ex.amount))
              } catch (uerr) { console.warn('rollback balance failed:', uerr) }
            }
            await supabase.from('expenses').update({ deleted_at: new Date().toISOString() }).eq('id', eid)
          } catch (rerr) {
            console.warn('rollback expense failed:', rerr)
          }
        }
        failures.push(`${row.employee_name}: ${e.message || e}`)
      }

      if (allPaid) {
        // 标记 salary。account_id 记主账户（split 最多的那个）
        const mainAcc = payForm.splits.reduce((best, s) => {
          const amt = Number(s.amount) || 0
          return amt > (Number(best?.amount) || 0) ? s : best
        }, payForm.splits[0])
        let { error: updErr } = await supabase
          .from('salaries')
          .update({ pay_date: payForm.pay_date, account_id: mainAcc?.account_id })
          .eq('id', row.id)
        if (updErr && /account_id|column/i.test(updErr.message || '')) {
          ;({ error: updErr } = await supabase
            .from('salaries')
            .update({ pay_date: payForm.pay_date })
            .eq('id', row.id))
        }
        if (updErr) {
          failures.push(`${row.employee_name}: 回写 salary 失败 ${updErr.message}`)
        } else {
          successIds.push(row.id)
        }
      }
    } else {
      // ── 批量模式：所有员工从同一账户发放，每人一条支出记录 ──
      const accId = payForm.splits[0]?.account_id

      // 提交前预检：刷新一次账户余额，预估有多少人会因余额不足失败
      try { await accountStore.fetchAccounts() } catch {}
      const acc = (accountStore.accounts || []).find(a => a.id === accId)
      const fresh = Number(acc?.balance || 0)
      const needed = payTotalAmount.value
      if (fresh < needed) {
        // 按金额从小到大能发几个人就发几个（让多人有工资比让少数人没有工资更合理）
        const sorted = [...payTargets.value].sort((a, b) => Number(a.actual_amount || 0) - Number(b.actual_amount || 0))
        let running = 0
        let canPayCount = 0
        for (const r of sorted) {
          const amt = Number(r.actual_amount || 0)
          if (running + amt <= fresh) { running += amt; canPayCount++ }
          else break
        }
        const failCount = payTargets.value.length - canPayCount
        const msg = `账户「${acc?.short_name || acc?.code || ''}」余额 ¥${fresh.toFixed(2)}，` +
          `需发 ¥${needed.toFixed(2)}。\n` +
          `预计约 ${canPayCount}/${payTargets.value.length} 人可成功，${failCount} 人会因余额不足失败。\n\n` +
          `继续发放？（失败的人会保留"未发"状态，可以换账户后重试）`
        if (!confirm(msg)) return
      }

      // 并发池执行。4 条路同时跑，相比串行大幅提速。
      // 一旦出现"余额不足"，立即 abort——池子里还没领取的任务全部跳过，
      // in-flight 的任务各自走完。user 会被问是否换账户继续还是结束
      payProgress.total = payTargets.value.length
      payProgress.done = 0

      const { results, aborted } = await runConcurrent(payTargets.value, async (row, _idx, abort) => {
        try {
          const expense = await expensesStore.createExpense({
            category: '工资',
            amount: Number(row.actual_amount || 0),
            payee: row.employee_name,
            account_id: accId,
            note: `工资发放: ${row.employee_name} (${row.pay_month})`,
            expense_date: payForm.pay_date,
          })
          if (expense?.id) {
            try {
              await supabase.from('expenses').update({ paid_at: payDateTs }).eq('id', expense.id)
            } catch (e) {
              console.warn('[SalaryManagement] backfill paid_at failed:', e)
            }
          }
          let { error: updErr } = await supabase
            .from('salaries')
            .update({ pay_date: payForm.pay_date, account_id: accId })
            .eq('id', row.id)
          if (updErr && /account_id|column/i.test(updErr.message || '')) {
            ;({ error: updErr } = await supabase
              .from('salaries')
              .update({ pay_date: payForm.pay_date })
              .eq('id', row.id))
          }
          if (updErr) throw updErr
          payProgress.done++
          return row.id
        } catch (e) {
          // 余额不足 → 立即终止后续任务，让调用方弹"换账户 or 结束"
          if (/余额不足|insufficient|balance/i.test(e?.message || '')) {
            abort()
          }
          throw e
        }
      }, 4)

      // 收集成功/失败/未处理（被 abort 跳过的）
      const unprocessed = []
      for (let i = 0; i < results.length; i++) {
        const r = results[i]
        const row = payTargets.value[i]
        if (!r) {
          unprocessed.push(row)
        } else if (r.ok) {
          successIds.push(r.value)
        } else {
          // 余额不足是预期内的停机信号，不用红色错误日志
          const isBal = /余额不足|insufficient|balance/i.test(r.error?.message || '')
          if (isBal) console.warn(`[SalaryManagement] ${row.employee_name} 余额不足，已停止批量发放`)
          else console.error(`[SalaryManagement] pay ${row.employee_name} failed:`, r.error)
          failures.push(`${row.employee_name}: ${r.error?.message || r.error}`)
        }
      }

      // 触发了 abort 且还有剩余未发 → 问用户换账户还是结束
      if (aborted && unprocessed.length > 0) {
        const remain = unprocessed.reduce((s, r) => s + Number(r.actual_amount || 0), 0)
        const msg = `账户余额不够，已自动暂停批量发放。\n\n` +
          `已成功: ${successIds.length} 人\n` +
          `失败: ${failures.length} 人\n` +
          `未发: ${unprocessed.length} 人 (¥${remain.toFixed(2)})\n\n` +
          `点【确定】换一个账户继续发剩下的\n点【取消】就到此为止`
        if (confirm(msg)) {
          // 换账户继续：把目标替换成未发的，清空账户让用户重选
          try { await accountStore.fetchAccounts() } catch {}
          payTargets.value = unprocessed
          payForm.splits = [{ account_id: '', amount: 0 }]
          payProgress.done = 0
          payProgress.total = 0
          // 提前刷新一次列表，让已发成功的立即可见
          await loadSalaries()
          if (successIds.length > 0) {
            toast(`已发放 ${successIds.length} 条，剩余 ${unprocessed.length} 人请选择新账户`, 'warning')
          }
          return // 退出 submitPay，弹窗不关，等待用户选新账户再提交
        }
        // 选"到此为止" → 落到下面正常汇总 toast + 关弹窗的流程
      }
    }

    if (successIds.length > 0 && failures.length === 0) {
      toast(`已发放 ${successIds.length} 条，合计 ${formatMoney(payTotalAmount.value)}`, 'success')
    } else if (successIds.length > 0 && failures.length > 0) {
      toast(`部分成功：${successIds.length} 成功 / ${failures.length} 失败\n${failures.slice(0, 3).join('\n')}`, 'warning')
    } else {
      toast(`发放失败：${failures.slice(0, 3).join('\n')}`, 'error')
    }

    showPayModal.value = false
    clearSelection()
    // 刷新账户余额缓存(保证下次开弹窗看到最新余额)
    try { await accountStore.fetchAccounts() } catch {}
    await loadSalaries()
  } finally {
    paying.value = false
    payProgress.done = 0
    payProgress.total = 0
  }
}

onMounted(async () => {
  // 加载账户列表(发放选项需要)
  try {
    if (!accountStore.accounts?.length) await accountStore.fetchAccounts()
  } catch (e) {
    console.warn('[SalaryManagement] load accounts failed:', e)
  }
  await loadSalaries()
})

// 切路由时清理撤销定时器，防止泄漏 / 切回来还在跑
onUnmounted(() => {
  if (_undoCloseTimer) { clearTimeout(_undoCloseTimer); _undoCloseTimer = null }
  if (_undoTickTimer) { clearInterval(_undoTickTimer); _undoTickTimer = null }
  pendingUndo.value = null
})
</script>
