<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-4 md:mb-6">
      <h1 class="text-lg md:text-xl font-bold text-gray-800 truncate">💸 支出管理</h1>
      <div class="flex items-center gap-2 shrink-0">
        <!-- 桌面端按钮 -->
        <div v-if="canDeleteExpenses" class="hidden md:inline-flex items-center gap-1">
          <select v-model="testCount" class="text-xs border border-dashed border-gray-300 rounded px-2 py-1 text-gray-500 bg-transparent outline-none cursor-pointer">
            <option :value="1">1条</option>
            <option :value="5">5条</option>
            <option :value="10">10条</option>
            <option :value="20">20条</option>
          </select>
          <button @click="generateTestData(testCount)" class="text-xs px-2 py-1 border border-dashed border-gray-300 rounded text-gray-500 hover:bg-gray-50 hover:text-gray-600 cursor-pointer">
            🎲 随机测试
          </button>
        </div>
        <button
          v-if="canDeleteExpenses"
          @click="showTextMode = !showTextMode"
          class="hidden md:inline-flex px-4 py-2 rounded-lg text-sm transition cursor-pointer whitespace-nowrap"
          :class="showTextMode ? 'bg-purple-600 text-white hover:bg-purple-700' : 'bg-purple-50 text-purple-700 hover:bg-purple-100'"
        >
          📋 文本模式
        </button>
        <button
          @click="showCategoryModal = true"
          class="hidden md:inline-flex border border-gray-200 text-gray-600 px-4 py-2 rounded-lg text-sm hover:bg-gray-50 transition cursor-pointer whitespace-nowrap"
        >
          🏷️ 类别
        </button>
        <!-- 移动端更多菜单 -->
        <div class="relative md:hidden">
          <button @click="showMobileMenu = !showMobileMenu" class="px-2.5 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">
            ⋯
          </button>
          <div v-if="showMobileMenu" class="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-lg border border-gray-100 py-1 z-50 min-w-[140px]">
            <button v-if="canDeleteExpenses" @click="showTextMode = !showTextMode; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">📋 文本模式</button>
            <button @click="showCategoryModal = true; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">🏷️ 类别</button>
            <button v-if="canDeleteExpenses" @click="generateTestData(testCount); showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm text-gray-400 hover:bg-gray-50 cursor-pointer">🎲 随机测试</button>
          </div>
        </div>
        <button
          @click="openCreateModal"
          class="bg-blue-600 text-white px-3 md:px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer whitespace-nowrap"
        >
          + 新建
        </button>
      </div>
    </div>
    <!-- 移动端菜单遮罩 -->
    <div v-if="showMobileMenu" class="fixed inset-0 z-40 md:hidden" @click="showMobileMenu = false"></div>

    <!-- Text Mode Panel -->
    <div v-if="showTextMode" class="mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-semibold text-gray-700">📋 粘贴支出文本</h3>
          <button @click="showTextMode = false" class="text-gray-500 hover:text-gray-600 text-sm cursor-pointer">收起 ✕</button>
        </div>
        <textarea
          v-model="rawText"
          rows="5"
          placeholder="粘贴支出文本，每行一条（格式：账户简称 金额 备注，可包含日期如'3月15日'）"
          class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500 resize-none font-mono"
        ></textarea>
        <div class="flex items-center gap-3 mt-3">
          <div class="flex items-center gap-2">
            <span class="text-xs text-gray-500">📅 统一月份：</span>
            <input
              type="month"
              v-model="expenseMonthStr"
              class="px-2 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-1 focus:ring-purple-500"
            >
            <span class="text-xs text-gray-500">（文本中可用"X月X日"指定日期）</span>
          </div>
        </div>
        <div class="flex items-center gap-2 mt-2">
          <button
            @click="handleParseExpenses"
            :disabled="!rawText.trim()"
            class="px-4 py-2 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer transition"
          >
            🔍 解析
          </button>
          <button
            @click="rawText = ''; parsedExpenses = []; parseError = ''"
            class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer transition"
          >
            清空
          </button>
        </div>

        <!-- Parsed Preview -->
        <div v-if="parsedExpenses.length > 0" class="mt-4 space-y-3">
          <div class="text-xs text-gray-500 mb-1">解析到 {{ parsedExpenses.length }} 条记录，可编辑后确认提交：</div>
          <div
            v-for="(exp, idx) in parsedExpenses"
            :key="idx"
            :class="[
              'border rounded-lg p-4',
              exp._type === 'transfer' ? 'border-blue-200 bg-blue-50/30' :
              exp._type === 'income' ? 'border-green-200 bg-green-50/30' :
              'border-purple-100 bg-purple-50/30'
            ]"
          >
            <div class="text-xs text-gray-500 font-mono bg-gray-50 rounded px-2 py-1 mb-2 break-all whitespace-pre-wrap">{{ exp._rawText }}</div>
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <span class="text-xs font-semibold" :class="exp._type === 'transfer' ? 'text-blue-600' : exp._type === 'income' ? 'text-green-600' : 'text-purple-600'">
                  {{ exp._type === 'transfer' ? '🔄 转账' : exp._type === 'income' ? '💰 收入' : '💸 支出' }} {{ idx + 1 }}
                </span>
                <span v-if="exp._type === 'transfer'" class="text-xs text-blue-400">（非支出，建议用转账页记录）</span>
              </div>
              <button
                @click="submitParsedExpense(idx)"
                :disabled="submittingParsed"
                class="px-3 py-1 bg-green-600 text-white rounded-md text-xs hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition"
              >
                ✅ 确认提交
              </button>
            </div>
            <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
              <div>
                <span class="text-gray-500 text-xs">付款账户：</span>
                <SearchableSelect
                  v-model="exp.account_id"
                  :options="activeAccounts"
                  label-key="code"
                  value-key="id"
                  placeholder="选择付款账户"
                  search-placeholder="搜索账户..."
                  drop-up
                />
              </div>
              <div>
                <span class="text-gray-500 text-xs">金额：</span>
                <input
                  v-model.number="exp.amount"
                  type="number"
                  min="0.01"
                  step="0.01"
                  class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white"
                />
              </div>
              <div>
                <span class="text-gray-500 text-xs">类别：</span>
                <select v-model="exp.category" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer">
                  <option value="">请选择类别</option>
                  <option v-for="cat in categories" :key="cat.id || cat.name" :value="cat.name">{{ cat.name }}</option>
                </select>
              </div>
              <div>
                <span class="text-gray-500 text-xs">收款方：</span>
                <input v-model="exp.payee" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div class="col-span-2">
                <span class="text-gray-500 text-xs">备注：</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-xs">日期：</span>
                <span class="text-sm text-gray-600">{{ exp.date || '今天' }}</span>
              </div>
            </div>
          </div>

          <!-- Batch submit -->
          <div class="flex items-center justify-between pt-2">
            <span class="text-xs text-gray-500">
              共 {{ parsedExpenses.length }} 条，合计 {{ formatMoney(parsedExpenses.reduce((s, e) => s + (Number(e.amount) || 0), 0)) }}
            </span>
            <button
              @click="submitAllParsedExpenses"
              :disabled="submittingParsed"
              class="px-5 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition"
            >
              {{ submittingParsed ? '提交中...' : '✅ 全部提交' }}
            </button>
          </div>
        </div>

        <!-- Parse Error -->
        <div v-if="parseError" class="mt-3 text-red-500 text-sm bg-red-50 rounded-lg px-3 py-2">
          ⚠️ {{ parseError }}
        </div>
      </div>
    </div>

    <!-- 今日支出汇总 -->
    <div v-if="todayExpenseData.loaded" class="bg-white rounded-xl p-3 mb-4 border border-gray-100 flex items-center gap-3">
      <div class="w-1 h-8 rounded-full bg-red-400"></div>
      <div class="text-sm">
        <span class="text-gray-500">今日支出</span>
        <span class="ml-2 font-semibold text-gray-800">{{ '¥' + todayExpenseData.total.toFixed(2) }}</span>
        <span class="ml-2 text-gray-300 text-xs">{{ todayExpenseData.count }} 笔</span>
      </div>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4 mb-4 md:mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4 md:p-5">
        <div class="text-sm text-gray-500 mb-1">📊 本月支出总额</div>
        <div class="text-2xl font-bold text-red-600">{{ formatMoney(monthTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">共 {{ monthCount }} 笔</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">⏳ 待审批笔数</div>
        <div class="text-2xl font-bold text-orange-500">{{ pendingCount }}</div>
        <div class="text-xs text-gray-500 mt-1">需要审批的支出</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">✅ 已付款笔数</div>
        <div class="text-2xl font-bold text-green-600">{{ paidCount }}</div>
        <div class="text-xs text-gray-500 mt-1">已完成付款</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">🔔 审批中金额</div>
        <div class="text-2xl font-bold text-amber-500">{{ formatMoney(approvalPendingTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">>¥2,000 待审批</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-3 md:p-4 mb-4">
      <div class="flex gap-2 md:gap-3 items-center flex-wrap">
        <select v-model="filters.searchField" class="px-2 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 bg-white cursor-pointer">
          <option value="">全部字段</option>
          <option value="payee">收款方</option>
          <option value="account_name">付款账户</option>
          <option value="note">备注</option>
          <option value="category">类别</option>
        </select>
        <div class="relative flex items-center">
          <input
            v-model="filters.search"
            placeholder="搜索收款方/备注/编号"
            class="px-3 py-2 pr-9 border border-gray-200 rounded-lg text-sm w-full md:w-52 outline-none focus:ring-2 focus:ring-blue-500"
            @keyup.enter="loadPage(1)"
          />
          <button @click="loadPage(1)" class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-600 cursor-pointer" title="搜索">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
          </button>
        </div>
        <div class="flex gap-2 items-center overflow-x-auto flex-1 min-w-0 pb-1 md:pb-0">
          <select
            v-model="filters.status"
            class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0 cursor-pointer"
            @change="loadPage(1)"
          >
            <option value="">全部状态</option>
            <option value="pending">待审批</option>
            <option value="approved">已批准</option>
            <option value="paid">已付款</option>
            <option value="rejected">已驳回</option>
          </select>
          <select
            v-model="filters.category"
            class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0 cursor-pointer"
            @change="loadPage(1)"
          >
            <option value="">全部类别</option>
            <option v-for="cat in categories" :key="cat.id || cat.name" :value="cat.name">{{ cat.name }}</option>
          </select>
          <input
            v-model="filters.dateFrom"
            type="date"
            class="px-2 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0"
            @change="loadPage(1)"
          >
          <input
            v-model="filters.dateTo"
            type="date"
            class="px-2 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0"
            @change="loadPage(1)"
          >
          <button
            v-if="hasActiveFilters"
            @click="resetFilters"
            class="text-sm text-blue-600 hover:text-blue-700 cursor-pointer flex-shrink-0 whitespace-nowrap"
          >
            清除
          </button>
          <button
            @click="handleExportExpenses"
            class="bg-green-600 text-white px-3 py-2 rounded-lg text-sm hover:bg-green-700 transition cursor-pointer flex-shrink-0"
          >
            📥 导出CSV
          </button>
        </div>
      </div>
      <div class="text-sm text-gray-500 mt-2 text-right">{{ pagination.total }} 条</div>
    </div>

    <!-- Action Bar -->
    <div v-if="selectedExpenses.length > 0 && canDeleteExpenses" class="bg-red-50 border border-red-100 rounded-xl px-4 py-3 mb-4 flex items-center gap-3">
      <span class="text-red-600 text-sm font-medium">已选 {{ selectedExpenses.length }} 条</span>
      <button @click="handleBatchDeleteExpenses" class="bg-red-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-red-700 transition cursor-pointer">删除选中</button>
      <button @click="selectedExpenses = []" class="text-gray-500 text-sm hover:text-gray-700 cursor-pointer">取消选择</button>
    </div>

    <!-- Expenses Table (desktop) -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden hidden md:block">
      <!-- Loading -->
      <Skeleton v-if="store.loading && expenses.length === 0" type="table" :rows="6" :columns="5" />

      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th v-if="canDeleteExpenses" class="px-4 py-3 text-center w-10">
              <input type="checkbox" :checked="selectedExpenses.length === expenses.length && expenses.length > 0" @change="e => selectedExpenses = e.target.checked ? expenses.map(x => x.id) : []" class="rounded cursor-pointer">
            </th>
            <th class="px-4 py-3 text-left font-medium">时间</th>
            <th class="px-4 py-3 text-left font-medium">类别</th>
            <th class="px-4 py-3 text-left font-medium">收款方</th>
            <th class="px-4 py-3 text-left font-medium">付款账户</th>
            <th class="px-4 py-3 text-right font-medium">金额</th>
            <th class="px-4 py-3 text-center font-medium">状态</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="expense in expenses"
            :key="expense.id"
            class="border-t border-gray-50 hover:bg-gray-50/70 transition"
          >
            <td v-if="canDeleteExpenses" class="px-4 py-3 text-center">
              <input type="checkbox" :value="expense.id" v-model="selectedExpenses" class="rounded cursor-pointer">
            </td>
            <td class="px-4 py-3 text-gray-500 whitespace-nowrap">
              {{ formatDate(expense.created_at) }}
            </td>
            <td class="px-4 py-3">
              <span class="bg-gray-100 text-gray-700 px-2 py-0.5 rounded text-xs font-medium">
                {{ EXPENSE_CATEGORIES[expense.category] || expense.category }}
              </span>
            </td>
            <td class="px-4 py-3 text-gray-800">
              <div>{{ expense.payee }}</div>
              <div v-if="expense.note" class="text-xs text-gray-500 mt-0.5 line-clamp-1">{{ expense.note }}</div>
            </td>
            <td class="px-4 py-3 text-gray-600 text-sm">
              <div>{{ getAccountName(expense.account_id) }}</div>
              <div v-if="expense.balance_after != null" class="text-xs text-gray-500">余额 {{ Number(expense.balance_after).toFixed(2) }}</div>
            </td>
            <td class="px-4 py-3 text-right">
              <span class="font-medium text-red-600">{{ formatMoney(expense.amount) }}</span>
              <span
                v-if="expense.status === 'pending' && expense.amount > 2000"
                class="ml-1 text-xs text-orange-500 font-medium"
              >需审批</span>
            </td>
            <td class="px-4 py-3 text-center">
              <span
                :class="EXPENSE_STATUS[expense.status]?.class || 'text-gray-500 bg-gray-50'"
                class="px-2 py-0.5 rounded-full text-xs font-medium inline-block"
              >
                {{ EXPENSE_STATUS[expense.status]?.label || expense.status }}
              </span>
            </td>
            <td class="px-4 py-3 text-center whitespace-nowrap">
              <!-- Pending: Approve / Reject -->
              <template v-if="expense.status === 'pending' && canApprove">
                <button
                  @click="handleApprove(expense, true)"
                  class="text-green-600 hover:text-green-700 text-xs font-medium mr-2 cursor-pointer"
                >
                  ✅ 批准
                </button>
                <button
                  @click="handleApprove(expense, false)"
                  class="text-red-500 hover:text-red-600 text-xs font-medium cursor-pointer"
                >
                  ❌ 驳回
                </button>
              </template>
              <!-- Approved: Confirm Payment -->
              <template v-if="expense.status === 'approved' && canApprove">
                <button
                  @click="openPayModal(expense)"
                  class="text-blue-600 hover:text-blue-700 text-xs font-medium cursor-pointer"
                >
                  💰 确认付款
                </button>
              </template>
              <!-- Paid: show paid info -->
              <template v-if="expense.status === 'paid'">
                <span class="text-xs text-gray-500">
                  {{ formatDate(expense.paid_at, 'date') }} 付款
                </span>
              </template>
              <!-- Rejected: allow finance to re-edit -->
              <template v-if="expense.status === 'rejected' && canApprove">
                <button
                  @click="openReeditModal(expense)"
                  class="text-blue-600 hover:text-blue-700 text-xs font-medium cursor-pointer"
                >
                  📝 重新编辑
                </button>
              </template>
              <template v-if="expense.status === 'rejected' && !canApprove">
                <span class="text-xs text-gray-500">已驳回</span>
              </template>
              <template v-if="expense.status === 'pending' && !canApprove">
                <span class="text-xs text-gray-500">待审批</span>
              </template>
              <button
                v-if="canDeleteExpenses"
                @click="handleDeleteExpense(expense)"
                class="text-red-400 hover:text-red-600 text-xs px-2 py-1 rounded hover:bg-red-50 transition cursor-pointer"
              >删除</button>
            </td>
          </tr>

          <!-- Empty State -->
          <tr v-if="expenses.length === 0 && !store.loading">
            <td :colspan="canDeleteExpenses ? 7 : 6" class="px-4 py-12 text-center">
              <div class="text-4xl mb-3">📭</div>
              <div class="text-gray-500">暂无支出记录</div>
              <div class="text-xs text-gray-300 mt-1">点击右上角新建支出</div>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination -->
      <div
        v-if="pagination.total > pagination.pageSize"
        class="border-t border-gray-100 px-4 py-3 flex items-center justify-between"
      >
        <span class="text-xs text-gray-500">
          第 {{ (pagination.page - 1) * pagination.pageSize + 1 }}-{{ Math.min(pagination.page * pagination.pageSize, pagination.total) }} 条
        </span>
        <div class="flex gap-1">
          <button
            @click="loadPage(pagination.page - 1)"
            :disabled="pagination.page <= 1"
            class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
          >
            上一页
          </button>
          <template v-for="p in visiblePages" :key="p">
            <button
              v-if="p !== '...'"
              @click="loadPage(p)"
              :class="[
                'px-3 py-1.5 text-xs rounded-lg cursor-pointer',
                p === pagination.page
                  ? 'bg-blue-600 text-white'
                  : 'border border-gray-200 hover:bg-gray-50'
              ]"
            >
              {{ p }}
            </button>
            <span v-else class="px-1 text-gray-500 text-xs">...</span>
          </template>
          <button
            @click="loadPage(pagination.page + 1)"
            :disabled="pagination.page >= totalPages"
            class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
          >
            下一页
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile Card List -->
    <div class="md:hidden space-y-2">
      <div v-if="store.loading && expenses.length === 0" class="space-y-2">
        <div v-for="i in 5" :key="i" class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="h-4 w-24 bg-gray-100 rounded animate-pulse mb-2"></div>
          <div class="h-6 w-32 bg-gray-100 rounded animate-pulse"></div>
        </div>
      </div>
      <div
        v-for="expense in expenses"
        :key="'m-' + expense.id"
        class="bg-white rounded-xl border border-gray-100 p-3 shadow-sm"
      >
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-semibold text-gray-800 truncate flex-1 mr-2">{{ expense.payee || '--' }}</span>
          <span
            :class="EXPENSE_STATUS[expense.status]?.class || 'text-gray-500 bg-gray-50'"
            class="px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0"
          >
            {{ EXPENSE_STATUS[expense.status]?.label || expense.status }}
          </span>
        </div>
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs text-gray-500">
            {{ EXPENSE_CATEGORIES[expense.category] || expense.category }}
            <span v-if="expense.note"> · {{ expense.note }}</span>
          </span>
          <span class="font-semibold text-red-600 text-sm">{{ formatMoney(expense.amount) }}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-xs text-gray-500">{{ formatDate(expense.created_at) }}</span>
          <div class="flex items-center gap-2">
            <template v-if="expense.status === 'pending' && canApprove">
              <button @click="handleApprove(expense, true)" class="text-green-600 text-xs px-2 py-1 rounded hover:bg-green-50 cursor-pointer">批准</button>
              <button @click="handleApprove(expense, false)" class="text-red-500 text-xs px-2 py-1 rounded hover:bg-red-50 cursor-pointer">驳回</button>
            </template>
            <template v-if="expense.status === 'approved' && canApprove">
              <button @click="openPayModal(expense)" class="text-blue-600 text-xs px-2 py-1 rounded hover:bg-blue-50 cursor-pointer">付款</button>
            </template>
            <template v-if="expense.status === 'rejected' && canApprove">
              <button @click="openReeditModal(expense)" class="text-blue-600 text-xs px-2 py-1 rounded hover:bg-blue-50 cursor-pointer">编辑</button>
            </template>
            <button v-if="canDeleteExpenses" @click="handleDeleteExpense(expense)" class="text-red-400 text-xs px-2 py-1 rounded hover:bg-red-50 cursor-pointer">删除</button>
          </div>
        </div>
      </div>
      <div v-if="expenses.length === 0 && !store.loading" class="bg-white rounded-xl border border-gray-100 p-8 text-center text-gray-500">
        <div class="text-4xl mb-3">📭</div>
        <div>暂无支出记录</div>
      </div>

      <!-- Mobile Pagination -->
      <div v-if="pagination.total > pagination.pageSize" class="flex items-center justify-center gap-2 pt-2">
        <button
          @click="loadPage(pagination.page - 1)"
          :disabled="pagination.page <= 1"
          class="px-3 py-2 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
        >上一页</button>
        <span class="text-xs text-gray-500">{{ pagination.page }} / {{ totalPages }}</span>
        <button
          @click="loadPage(pagination.page + 1)"
          :disabled="pagination.page >= totalPages"
          class="px-3 py-2 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
        >下一页</button>
      </div>
    </div>

    <!-- Create Expense Modal -->
    <div
      v-if="showCreateModal"
      class="fixed inset-0 bg-black/30 flex items-center justify-center z-50"
      @click.self="showCreateModal = false"
    >
      <div class="bg-white rounded-none md:rounded-2xl shadow-2xl w-full md:max-w-lg md:mx-4 overflow-hidden flex flex-col ">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="font-bold text-gray-800">{{ editingExpenseId ? '重新编辑支出' : '新建支出' }}</h2>
          <button @click="showCreateModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleCreate" class="p-6 space-y-4">
          <!-- Category -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">支出类别 <span class="text-red-400">*</span></label>
            <select
              v-model="form.category"
              required
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
            >
              <option value="" disabled>请选择类别</option>
              <option v-for="cat in categories" :key="cat.id || cat.name" :value="cat.name">{{ cat.name }}</option>
            </select>
          </div>

          <!-- Amount -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">金额 <span class="text-red-400">*</span></label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">¥</span>
              <input
                v-model.number="form.amount"
                type="number"
                min="0.01"
                step="0.01"
                required
                placeholder="0.00"
                class="w-full pl-8 pr-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              >
            </div>
            <p v-if="form.amount > 2000" class="text-xs text-orange-500 mt-1">
              ⚠️ 金额超过 ¥2,000，提交后将进入审批流程
            </p>
          </div>

          <!-- Payee -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">收款方 <span class="text-red-400">*</span></label>
            <input
              v-model="form.payee"
              required
              placeholder="请输入收款方名称"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <!-- Payment Account -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">付款账户</label>
            <SearchableSelect
              v-model="form.account_id"
              :options="activeAccounts"
              label-key="code"
              value-key="id"
              placeholder="请选择付款账户"
              search-placeholder="搜索账户名称..."
              drop-up
            />
          </div>

          <!-- Receipt URL -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">票据链接</label>
            <input
              v-model="form.receipt_url"
              type="url"
              placeholder="https://example.com/receipt.jpg"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
            <p class="text-xs text-gray-500 mt-1">暂时使用 URL 输入，V2 支持文件上传</p>
          </div>

          <!-- Notes -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea
              v-model="form.note"
              rows="3"
              placeholder="可选：填写备注信息"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            ></textarea>
          </div>

          <!-- Submit -->
          <div class="flex gap-3 pt-2">
            <button
              type="button"
              @click="showCreateModal = false"
              class="flex-1 px-4 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer"
            >
              取消
            </button>
            <button
              type="submit"
              :disabled="submitting"
              class="flex-1 px-4 py-2.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ submitting ? '提交中...' : (form.amount > 2000 ? '提交审批' : '确认提交') }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Confirm Payment Modal -->
    <div
      v-if="showPayModal"
      class="fixed inset-0 bg-black/30 flex items-center justify-center z-50"
      @click.self="showPayModal = false"
    >
      <div class="bg-white rounded-none md:rounded-2xl shadow-2xl w-full md:max-w-md md:mx-4  max-h-[80vh] overflow-hidden flex flex-col">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <h2 class="font-bold text-gray-800">💰 确认付款</h2>
          <button @click="showPayModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="p-6 space-y-4 overflow-y-auto flex-1">
          <div class="bg-gray-50 rounded-lg p-4 text-sm">
            <div class="text-gray-500 mb-1">收款方</div>
            <div class="font-medium text-gray-800">{{ payingExpense?.payee }}</div>
            <div class="text-gray-500 mt-2 mb-1">金额</div>
            <div class="font-bold text-red-600 text-lg">{{ formatMoney(payingExpense?.amount) }}</div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">付款账户 <span class="text-red-400">*</span></label>
            <SearchableSelect
              v-model="payAccountId"
              :options="activeAccounts"
              label-key="code"
              value-key="id"
              placeholder="请选择付款账户"
              search-placeholder="搜索账户名称..."
              drop-up
            />
          </div>

          <div class="flex gap-3 pt-2">
            <button
              type="button"
              @click="showPayModal = false"
              class="flex-1 px-4 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer"
            >
              取消
            </button>
            <button
              @click="handleMarkPaid"
              :disabled="!payAccountId || paying"
              class="flex-1 px-4 py-2.5 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ paying ? '处理中...' : '确认已付款' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <!-- Category Management Modal -->
    <div
      v-if="showCategoryModal"
      class="fixed inset-0 bg-black/30 flex items-center justify-center z-50"
      @click.self="showCategoryModal = false"
    >
      <div class="bg-white rounded-none md:rounded-2xl shadow-2xl w-full md:max-w-2xl md:mx-4 max-h-[85vh] overflow-hidden flex flex-col ">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between flex-shrink-0">
          <h2 class="font-bold text-gray-800">🏷️ 支出类别管理</h2>
          <button @click="showCategoryModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <div class="p-6 space-y-4 overflow-y-auto flex-1">
          <!-- Add new category -->
          <form @submit.prevent="handleCreateCategory" class="flex gap-3 items-end">
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700 mb-1">新增类别</label>
              <input v-model="newCategoryName" placeholder="输入类别名称" maxlength="50"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <button type="submit" :disabled="creatingCategory"
              class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 cursor-pointer whitespace-nowrap">
              {{ creatingCategory ? '添加中...' : '添加' }}
            </button>
          </form>

          <!-- Category list -->
          <div class="border border-gray-100 rounded-xl overflow-hidden">
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-gray-50 text-gray-600">
                  <th class="px-4 py-2 text-left font-medium">类别名称</th>
                  <th class="px-4 py-2 text-left font-medium">状态</th>
                  <th class="px-4 py-2 text-center font-medium">操作</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="cat in categories" :key="cat.id" class="border-t border-gray-50 hover:bg-gray-50">
                  <!-- Edit mode -->
                  <td v-if="editingCatId === cat.id" class="px-4 py-2">
                    <div class="flex items-center gap-2">
                      <input v-model="editingCatName" @keyup.enter="saveCategoryEdit(cat)" @keyup.escape="cancelCategoryEdit"
                        class="px-2 py-1 border border-blue-300 rounded text-sm outline-none focus:ring-2 focus:ring-blue-500 w-36" />
                      <button @click="saveCategoryEdit(cat)" class="text-green-600 text-xs cursor-pointer">保存</button>
                      <button @click="cancelCategoryEdit" class="text-gray-500 text-xs cursor-pointer">取消</button>
                    </div>
                  </td>
                  <td v-else class="px-4 py-2 text-gray-800 font-medium">{{ cat.name }}</td>
                  <td class="px-4 py-2">
                    <span :class="cat.status === 'active' ? 'text-green-600 bg-green-50' : 'text-gray-500 bg-gray-100'"
                      class="px-2 py-0.5 rounded text-xs">
                      {{ cat.status === 'active' ? '启用' : '停用' }}
                    </span>
                  </td>
                  <td class="px-4 py-2 text-center whitespace-nowrap" v-if="editingCatId !== cat.id">
                    <button @click="startCategoryEdit(cat)" class="text-blue-600 text-xs cursor-pointer mr-2">编辑</button>
                    <button v-if="cat.status === 'active'" @click="toggleCategoryStatus(cat)"
                      class="text-orange-600 text-xs cursor-pointer mr-2">停用</button>
                    <button v-else @click="toggleCategoryStatus(cat)"
                      class="text-green-600 text-xs cursor-pointer mr-2">启用</button>
                    <button @click="handleDeleteCategory(cat)" class="text-red-500 text-xs cursor-pointer">删除</button>
                  </td>
                </tr>
                <tr v-if="!categoriesLoading && categories.length === 0">
                  <td colspan="3" class="px-4 py-8 text-center text-gray-500">暂无支出类别</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import { useExpenseStore } from '../stores/expenses'
import { useAccountStore } from '../stores/accounts'
import SearchableSelect from '../components/SearchableSelect.vue'
import { useAuthStore } from '../stores/auth'
import Skeleton from '../components/Skeleton.vue'
import { supabase } from '../lib/supabase'
import { formatMoney, EXPENSE_CATEGORIES, EXPENSE_STATUS, toast, formatDate, debounce } from '../lib/utils'
import { usePermission } from '../composables/usePermission'
import { randomPick, randomAmount, todayDate, PAYEES } from '../lib/testDataHelper'
import { dayEnd } from '../utils/dateRange'

const store = useExpenseStore()
const accountStore = useAccountStore()
function getAccountName(id) { return accountStore.accounts.find(a => a.id === id)?.short_name || accountStore.accounts.find(a => a.id === id)?.name || '--' }
function getAccountBalance(id) { const acc = accountStore.accounts.find(a => a.id === id); return acc ? Number(acc.balance || 0).toFixed(2) : '--' }
const authStore = useAuthStore()

// --- Text Mode (Batch Expense Entry) ---
const showTextMode = ref(false)
const showMobileMenu = ref(false)
const rawText = ref('')
const parsedExpenses = ref([])
const expenseMonth = ref(new Date()) // 默认本月
const expenseMonthStr = computed({
  get: () => {
    const d = expenseMonth.value
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
  },
  set: (val) => {
    const [y, m] = val.split('-').map(Number)
    expenseMonth.value = new Date(y, m - 1, 1)
  },
})
const parseError = ref('')
const submittingParsed = ref(false)

// --- 今日数据 ---
const todayExpenseData = reactive({ total: 0, count: 0, loaded: false })

async function loadTodayExpense() {
  try {
    const now = new Date()
    let dayStart
    if (now.getHours() < 6) {
      dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 6, 0, 0)
    } else {
      dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 6, 0, 0)
    }
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + 1)
    const startISO = dayStart.toISOString()
    const endISO = dayEnd.toISOString()

    const { data } = await supabase
      .from('expenses')
      .select('amount')
      .eq('status', 'paid')
      .gte('paid_at', startISO)
      .lte('paid_at', endISO)
    if (data && data.length > 0) {
      todayExpenseData.total = data.reduce((s, r) => s + (Number(r.amount) || 0), 0)
      todayExpenseData.count = data.length
    } else {
      todayExpenseData.total = 0
      todayExpenseData.count = 0
    }
    todayExpenseData.loaded = true
  } catch (e) {
    console.error('加载今日支出失败:', e)
  }
}

// Category keyword mapping for text parsing
const CATEGORY_KEYWORD_MAP = {
  '采购成本': ['采购', '进货', '拿货', '成本', '杆头成本', '皮头', '胶带', '球杆'],
  '物流快递': ['物流', '快递', '运费', '邮费', '发货', '物流费'],
  '售后赔偿': ['售后', '赔偿', '退款', '补发', '售后赔偿'],
  '水电费': ['水电', '电费', '水费', '水电费'],
  '房租物业': ['房租', '物业', '租金', '房租物业'],
  '工资': ['工资', '薪水', '薪资', '人员工资'],
  '税费': ['税', '税费', '发票'],
  '营销': ['推广', '广告', '营销', '推广营销', '团建', '活动', '直播', '投流'],
  '培训学习': ['培训', '学习', '课程', '培训学习'],
  '设备': ['设备', '电脑', '打印机', '设备费'],
  '平台费': ['平台', '服务费', '平台费', '平台服务费', '有赞', '抖店'],
  '退款': ['退款'],
  '日常': ['日常', '耗材', '办公', '文具', '办公耗材'],
  '其他': [],
}

function matchCategory(text) {
  const lower = text.toLowerCase()
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORD_MAP)) {
    for (const kw of keywords) {
      if (lower.includes(kw)) return category
    }
  }
  return 'other'
}

function parseExpenseText(text) {
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
  const results = []

  // Build account name map (longest first for greedy matching)
  const activeAccs = accountStore.getActiveAccounts()
  const accountNameMap = {}
  for (const a of activeAccs) {
    const names = [(a.short_name || a.code)].filter(Boolean)
    if (a.payment_alias) names.push(a.payment_alias)
    for (const n of names) {
      if (!accountNameMap[n] || n.length > (accountNameMap[n] || '').length) {
        accountNameMap[n] = { id: a.id, label: a.short_name || a.code }
      }
    }
  }
  const accountNames = Object.keys(accountNameMap).sort((a, b) => b.length - a.length)

  for (const line of lines) {
    // === 智能模式：先判断是"关键词开头"还是"账户名开头" ===
    const isKeywordStart = /^(卡付|卡收|宝付|宝收|南\d*入账|转账|转卡|转余利宝|转中信|转支付宝|转平安|(.{1,4})公户(收|支出)?)/.test(line)
    
    if (isKeywordStart) {
      // === 关键词开头格式（老王Excel格式） ===
      // 格式: 关键词 日期 金额 备注 账户

      // 1. 类型判断
      let type = 'expense'
      if (/到账$|到账-|公户收/.test(line)) {
        // "XX到账" = 提现转账（平台→银行卡/公户），不是收入
        type = 'transfer'
      } else if (/下单|其他收入/.test(line) || /收入/.test(line)) {
        type = 'income'
      } else if (/^(转卡|转余利宝|转中信|转支付宝|转平安|任公户.*转|公户.*转)/.test(line)) {
        type = 'transfer'
      }

      // 2. 金额提取（支持万单位、逗号分隔）
      let amount = 0
      const wan = line.match(/([\d.]+)\s*万/)
      if (wan && parseFloat(wan[1]) > 0) {
        amount = parseFloat(wan[1]) * 10000
      } else {
        const m = line.match(/[￥¥]?\s*([\d,]+\.?\d*)\s*元/)
        if (m && parseFloat(m[1]) > 0) {
          amount = parseFloat(m[1].replace(/,/g, ''))
        }
      }

      // 3. 账户匹配（先末尾精确匹配，再全文模糊匹配，取最长命中）
      let matchedAccountId = ''
      let matchedAccount = ''
      const stripped = line.replace(/[￥¥]\s*[\d,.]+\s*(万?)\s*元?\s*$/, '').replace(/\s+$/, '')
      // 先尝试末尾精确
      for (const name of accountNames) {
        if (stripped.endsWith(name)) {
          matchedAccountId = accountNameMap[name].id
          matchedAccount = accountNameMap[name].label
          break
        }
      }
      // 末尾没命中，全文模糊匹配（取最长）
      if (!matchedAccountId) {
        for (const name of accountNames) {
          if (stripped.includes(name) && name.length > 2) {
            matchedAccountId = accountNameMap[name].id
            matchedAccount = accountNameMap[name].label
            break
          }
        }
      }

      // 4. 日期提取
      let date = null
      const dm = line.match(/(\d{1,2})月(\d{1,2})日/)
      if (dm) date = dm[0]

      // 5. 备注提取（去掉关键词、日期、金额、账户）
      let note = line
      note = note.replace(/（基本户）任公户\s*转（一般户）任公户/, '基本户→一般户')
      note = note.replace(/（基本户）任公户/, '')
      note = note.replace(/（一般户）任公户支出/, '')
      note = note.replace(/(.{1,4}公户)(收|支出)?/, '')
      // 关键词
      note = note.replace(/^(卡付|卡收|宝付|宝收|南\d*入账|转账|转卡|转余利宝|转中信|转支付宝|转平安)\s*/, '')
      // 日期
      note = note.replace(/\d{1,2}月?\d{0,2}日?\s*/, '')
      // 金额
      note = note.replace(/[￥¥]?\s*[\d,.]+\.?\d*\s*(万?)\s*元?\s*/g, '')
      // 账户
      for (const name of accountNames) note = note.replace(new RegExp(name + '\\s*$'), '')
      note = note.replace(/下单\s*其他收入\s*$/, '').replace(/其他收入\s*$/, '').replace(/\s+/g, ' ').trim()

      results.push({
        _rawText: line,
        _type: type, // income/expense/transfer
        account_id: matchedAccountId,
        account_label: matchedAccount || '未匹配',
        amount: amount || null,
        category: type === 'expense' ? matchCategory(note) : 'other',
        payee: '',
        note,
        date: date || null,
      })
    } else {
      // === 原有模式：账户名开头 ===
      let remaining = line

      let matchedAccount = null
      let matchedAccountId = null
      for (const { name, accountId, label } of accountNames.map(n => ({ name: n, accountId: accountNameMap[n].id, label: accountNameMap[n].label }))) {
        if (remaining.startsWith(name)) {
          matchedAccount = label
          matchedAccountId = accountId
          remaining = remaining.slice(name.length).trim()
          break
        }
      }

      let expenseDate = null
      const fullMonthDate = remaining.match(/(\d{1,2})月(\d{1,2})日?/)
      if (fullMonthDate) {
        const m = parseInt(fullMonthDate[1])
        const d = parseInt(fullMonthDate[2])
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          expenseDate = fullMonthDate[0]
          remaining = remaining.slice(0, fullMonthDate.index) + remaining.slice(fullMonthDate.index + fullMonthDate[0].length).trim()
        }
      }
      if (!expenseDate) {
        const dayMatch = remaining.match(/(\d{1,2})日/)
        if (dayMatch) {
          const d = parseInt(dayMatch[1])
          if (d >= 1 && d <= 31) {
            expenseDate = dayMatch[0]
            remaining = remaining.slice(0, dayMatch.index) + remaining.slice(dayMatch.index + dayMatch[0].length).trim()
          }
        }
      }

      let amount = 0
      let amountConsumed = ''
      const amtYuan = remaining.match(/[￥¥]?(\d[\d,]*\.?\d*)\s*[元￥¥]?/)
      if (amtYuan && parseFloat(amtYuan[1]) > 0) {
        amount = parseFloat(amtYuan[1].replace(/,/g, ''))
        amountConsumed = amtYuan[0]
      } else {
        const amtCN = remaining.match(/(\d[\d,]*\.?\d*)([\u4e00-\u9fff])/)
        if (amtCN && parseFloat(amtCN[1]) > 0) {
          amount = parseFloat(amtCN[1].replace(/,/g, ''))
          amountConsumed = amtCN[1] + amtCN[2]
        } else {
          const amtSpace = remaining.match(/(\d[\d,]*\.?\d*)\s+(?=[\u4e00-\u9fff])/)
          if (amtSpace && parseFloat(amtSpace[1]) > 0) {
            amount = parseFloat(amtSpace[1].replace(/,/g, ''))
            amountConsumed = amtSpace[1] + ' '
          } else {
            const amtEnd = remaining.match(/(\d[\d,]*\.?\d*)$/)
            if (amtEnd && parseFloat(amtEnd[1]) > 0) {
              amount = parseFloat(amtEnd[1].replace(/,/g, ''))
              amountConsumed = amtEnd[0]
            }
          }
        }
      }
      if (amountConsumed) {
        const idx = remaining.indexOf(amountConsumed)
        if (idx >= 0) {
          remaining = remaining.slice(0, idx) + remaining.slice(idx + amountConsumed.length).trim()
        }
      }

      const category = matchCategory(line)

      let note = remaining.replace(/\s+/g, ' ').trim()
      note = note.replace(/元$/, '').trim()

      results.push({
        _rawText: line,
        _type: 'expense',
        account_id: matchedAccountId || '',
        account_label: matchedAccount || '未匹配',
        amount: amount || null,
        category,
        payee: '',
        note,
        date: expenseDate || null,
      })
    }
  }

  return results
}

function handleParseExpenses() {
  parseError.value = ''
  if (!rawText.value.trim()) return
  try {
    const expenses = parseExpenseText(rawText.value)
    if (expenses.length === 0) {
      parseError.value = '未能解析出任何支出，请检查文本格式'
      parsedExpenses.value = []
      return
    }
    parsedExpenses.value = expenses.map(exp => {
      // 计算实际付款日期
      if (exp.date) {
        const dm = exp.date.match(/(\d{1,2})月(\d{1,2})/)
        if (dm) {
          const year = expenseMonth.value.getFullYear()
          const month = parseInt(dm[1]) - 1
          const day = parseInt(dm[2])
          exp.expense_date = new Date(year, month, day).toISOString().slice(0, 10)
        }
      } else {
        // 没有日期，用月份选择器的当月当天
        exp.expense_date = new Date().toISOString().slice(0, 10)
      }
      return exp
    })
  } catch (e) {
    console.error('解析失败:', e)
    parseError.value = '解析出错: ' + (e.message || '未知错误')
    parsedExpenses.value = []
  }
}

async function submitParsedExpense(idx) {
  const exp = parsedExpenses.value[idx]
  if (!exp || !exp.amount) {
    toast('请填写金额', 'warning')
    return
  }
  if (!exp.payee && !exp.note) {
    toast('请填写收款方或备注', 'warning')
    return
  }
  submittingParsed.value = true
  try {
    const payload = {
      category: exp.category || 'other',
      amount: Number(exp.amount),
      payee: exp.payee || exp.note || '未填写',
      account_id: exp.account_id || null,
      note: exp.note || null,
      expense_date: exp.expense_date || new Date().toISOString().slice(0, 10),
    }
    await store.createExpense(payload)
    parsedExpenses.value.splice(idx, 1)
    toast('支出已创建', 'success')
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    toast('创建失败：' + (e.message || ''), 'error')
  } finally {
    submittingParsed.value = false
  }
}

async function submitAllParsedExpenses() {
  const valid = parsedExpenses.value.filter(e => e.amount && (e.payee || e.note))
  if (valid.length === 0) {
    toast('没有可提交的支出（请确保每条都有金额和收款方/备注）', 'warning')
    return
  }
  if (!confirm(`确认批量提交 ${valid.length} 条支出？`)) return
  submittingParsed.value = true
  let successCount = 0
  let failCount = 0
  for (const exp of valid) {
    try {
      const payload = {
        category: exp.category || 'other',
        amount: Number(exp.amount),
        payee: exp.payee || exp.note || '未填写',
        account_id: exp.account_id || null,
        note: exp.note || null,
      }
      await store.createExpense(payload)
      successCount++
    } catch (e) {
      failCount++
      console.error('提交失败:', e)
    }
  }
  submittingParsed.value = false
  parsedExpenses.value = []
  toast(`成功提交 ${successCount} 条${failCount > 0 ? `，失败 ${failCount} 条` : ''}`, successCount > 0 ? 'success' : 'error')
  await loadPage(pagination.value.page)
  await fetchStats()
}

// --- Filters ---
const filters = reactive({
  status: '',
  category: '',
  dateFrom: '',
  dateTo: '',
  search: '',
  searchField: '',
})

const hasActiveFilters = computed(() => {
  return filters.status || filters.category || filters.dateFrom || filters.dateTo || filters.search
})

function resetFilters() {
  filters.status = ''
  filters.category = ''
  filters.dateFrom = ''
  filters.dateTo = ''
  filters.search = ''
  loadPage(1)
}

// --- Data ---
const expenses = computed(() => store.expenses)
const pagination = computed(() => store.pagination)

const totalPages = computed(() => {
  return Math.ceil(pagination.value.total / pagination.value.pageSize) || 1
})

const visiblePages = computed(() => {
  const total = totalPages.value
  const current = pagination.value.page
  const pages = []
  if (total <= 7) {
    for (let i = 1; i <= total; i++) pages.push(i)
  } else {
    pages.push(1)
    if (current > 3) pages.push('...')
    const start = Math.max(2, current - 1)
    const end = Math.min(total - 1, current + 1)
    for (let i = start; i <= end; i++) pages.push(i)
    if (current < total - 2) pages.push('...')
    pages.push(total)
  }
  return pages
})

// --- Stats ---
const now = new Date()
const monthStart = computed(() => {
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
})

// We compute stats from all expenses fetched (server side would be better, but we compute from the store's full data)
// Since fetchExpenses is paginated, we need a separate fetch for stats
const stats = reactive({
  monthTotal: 0,
  monthCount: 0,
  pendingCount: 0,
  paidCount: 0,
  approvalPendingTotal: 0,
})

const monthTotal = computed(() => stats.monthTotal)
const monthCount = computed(() => stats.monthCount)
const pendingCount = computed(() => stats.pendingCount)
const paidCount = computed(() => stats.paidCount)
const approvalPendingTotal = computed(() => stats.approvalPendingTotal)

async function fetchStats() {
  try {
    const { data: monthData } = await supabase
      .from('expenses')
      .select('amount, status')
      .gte('created_at', monthStart.value)
    if (monthData) {
      stats.monthTotal = monthData.reduce((s, e) => s + (e.amount || 0), 0)
      stats.monthCount = monthData.length
      stats.paidCount = monthData.filter(e => e.status === 'paid').length
      stats.pendingCount = monthData.filter(e => e.status === 'pending').length
      stats.approvalPendingTotal = monthData
        .filter(e => e.status === 'pending' && e.amount > 2000)
        .reduce((s, e) => s + (e.amount || 0), 0)
    }
  } catch (e) {
    console.error('Failed to fetch stats:', e)
  }
}

// --- Permissions ---
const canApprove = computed(() => authStore.canApprove || authStore.isFinance)
const canDeleteExpenses = computed(() => ['finance', 'admin', 'manager'].includes(authStore.profile?.role))

// --- Delete ---
const selectedExpenses = ref([])

// --- Accounts ---
const activeAccounts = computed(() => {
  const accs = accountStore.getActiveAccounts()
  // 统计最近使用的账户频率（从已加载的支出列表）
  const usageCount = {}
  for (const exp of expenses.value) {
    if (exp.account_id) {
      usageCount[exp.account_id] = (usageCount[exp.account_id] || 0) + 1
    }
  }
  // 按使用频率排序（高频在前），同频的保持原序
  return accs.map(a => ({
    ...a,
    code: `${a.short_name || a.code}（¥${Number(a.balance || 0).toFixed(2)}）`,
  })).sort((a, b) => (usageCount[b.id] || 0) - (usageCount[a.id] || 0))
})

// --- Load data ---
async function loadPage(page = 1) {
  // 转义搜索关键词，防止 PostgREST 注入
  const safeSearch = (filters.search || '').replace(/[,%().*]/g, '')
  await store.fetchExpenses({
    status: filters.status || undefined,
    category: filters.category || undefined,
    dateFrom: filters.dateFrom || undefined,
    dateTo: filters.dateTo || undefined,
    search: safeSearch || undefined,
    page,
    pageSize: 20,
  })
}


// --- CSV Export ---
async function handleExportExpenses() {
  try {
    toast('正在导出...', 'info')
    const safeSearch = (filters.search || '').replace(/[,%().*]/g, '')
    let query = supabase
      .from('expenses')
      .select('id, created_at, category, payee, amount, account_id, status, note, approver_id, expense_no')
      .order('created_at', { ascending: false })
      .limit(5000)

    if (filters.status) query = query.eq('status', filters.status)
    if (filters.category) query = query.eq('category', filters.category)
    if (filters.dateFrom) query = query.gte('created_at', filters.dateFrom)
    if (filters.dateTo) query = query.lte('created_at', dayEnd(filters.dateTo))
    if (safeSearch) {
      const { data: matchedAccounts } = await supabase
        .from('accounts')
        .select('id')
        .or(`short_name.ilike.%${safeSearch}%,code.ilike.%${safeSearch}%`)
        .limit(50)
      const accIds = (matchedAccounts || []).map(a => a.id)
      let orParts = `payee.ilike.%${safeSearch}%,note.ilike.%${safeSearch}%,expense_no.ilike.%${safeSearch}%`
      if (accIds.length > 0) orParts += `,account_id.in.(${accIds.join(',')})`
      query = query.or(orParts)
    }

    const { data, error } = await query
    if (error) throw error
    const rows = data || []

    // Get account names for mapping
    const allAccIds = [...new Set(rows.map(r => r.account_id).filter(Boolean))]
    let accMap = {}
    if (allAccIds.length > 0) {
      const { data: accs } = await supabase.from('accounts').select('id, short_name, code').in('id', allAccIds)
      ;(accs || []).forEach(a => { accMap[a.id] = a.short_name || a.code })
    }

    const header = ['日期', '类别', '收款方', '金额', '付款账户', '状态', '编号', '备注']
    const body = rows.map(e => [
      formatDate(e.created_at),
      EXPENSE_CATEGORIES[e.category] || e.category || '',
      e.payee || '',
      Number(e.amount).toFixed(2),
      accMap[e.account_id] || '',
      EXPENSE_STATUS[e.status]?.label || e.status || '',
      e.expense_no || '',
      e.note || '',
    ])

    const BOM = '\uFEFF'
    const csv = BOM + [header, ...body].map(row =>
      row.map(cell => `"${String(cell ?? '').replace(/"/g, '""')}"`).join(',')
    ).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    const today = new Date().toISOString().slice(0, 10)
    link.download = `支出_${today}.csv`
    link.click()
    URL.revokeObjectURL(link.href)
    toast(`已导出 ${rows.length} 条数据`, 'success')
  } catch (e) {
    console.error('导出失败:', e)
    toast('导出失败：' + (e.message || ''), 'error')
  }
}

// --- Create Modal ---
const showCreateModal = ref(false)
const editingExpenseId = ref(null)
const submitting = ref(false)

const testCount = ref(5)

// ---------- 随机测试数据生成 ----------
async function generateTestData(count) {
  try {
    let accs = accountStore.getActiveAccounts()
    if (!accs.length) { toast('没有可用账户', 'warning'); return }
    // 查询支出类别
    const { data: cats } = await supabase.from('expense_categories').select('name').eq('status', 'active')
    const catList = (cats || []).map(c => c.name)
    if (!catList.length) catList.push('其他')
    let success = 0
    for (let i = 0; i < count; i++) {
      const acc = randomPick(accs)
      const amt = randomAmount(50, 2000) // keep <=2000 so store auto-pays
      const payload = {
        category: randomPick(catList),
        amount: amt,
        payee: randomPick(PAYEES),
        account_id: acc.id,
        expense_date: todayDate(),
        note: '测试数据',
      }
      await store.createExpense(payload)
      success++
    }
    await loadPage(pagination.value.page)
    await fetchStats()
    toast(`成功生成 ${success} 条测试支出`, 'success')
  } catch (e) {
    console.error(e)
    toast('生成测试数据失败：' + (e.message || ''), 'error')
  }
}

const form = reactive({
  category: '',
  amount: null,
  payee: '',
  account_id: '',
  receipt_url: '',
  note: '',
})

function openCreateModal() {
  editingExpenseId.value = null
  form.category = ''
  form.amount = null
  form.payee = ''
  form.account_id = ''
  form.receipt_url = ''
  form.note = ''
  showCreateModal.value = true
}

function openReeditModal(expense) {
  editingExpenseId.value = expense.id
  form.category = expense.category || ''
  form.amount = expense.amount
  form.payee = expense.payee || ''
  form.account_id = expense.account_id || ''
  form.receipt_url = expense.receipt_url || ''
  form.note = expense.note || ''
  showCreateModal.value = true
}

async function handleCreate() {
  if (!form.category || !form.amount || !form.payee) return
  submitting.value = true
  try {
    const amount = Number(form.amount)
    const payload = {
      category: form.category,
      amount,
      payee: form.payee,
      account_id: form.account_id || null,
      receipt_url: form.receipt_url || null,
      note: form.note || null,
    }
    
    if (editingExpenseId.value) {
      // 重新编辑驳回的支出：更新内容，重置为 pending
      const { error } = await supabase
        .from('expenses')
        .update({
          category: payload.category,
          amount: payload.amount,
          payee: payload.payee,
          account_id: payload.account_id,
          receipt_url: payload.receipt_url,
          note: payload.note,
          status: 'pending',
          approver_id: null,
          approved_at: null,
        })
        .eq('id', editingExpenseId.value)
      if (error) throw error
      toast('支出已重新提交审批', 'success')
    } else {
      // 状态由 Store 的 createExpense 自动判定
      await store.createExpense(payload)
      toast('支出已提交', 'success')
    }
    
    // 记录操作日志
    try {
      const { logOperation } = await import('../utils/operationLogger')
      const accName = accounts.value.find(a => a.id === form.account_id)?.short_name || ''
      await logOperation({
        action: editingExpenseId.value ? 'update_expense' : 'create_expense',
        module: '支出',
        description: `${editingExpenseId.value ? '编辑' : '创建'}支出 ¥${Number(form.amount).toFixed(2)}，收款方：${form.payee}，分类：${form.category}，账户：${accName}`,
        detail: { amount: form.amount, payee: form.payee, category: form.category, account: accName },
        amount: form.amount,
        accountId: form.account_id || null,
        accountName: accName,
      })
    } catch (_) {}

    showCreateModal.value = false
    editingExpenseId.value = null
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    console.error(e)
    toast('操作失败：' + (e.message || '未知错误'), 'error')
  } finally {
    submitting.value = false
  }
}

// --- Approve / Reject ---
const approvingId = ref(null)

async function handleApprove(expense, approved) {
  if (approvingId.value) return
  approvingId.value = expense.id
  try {
    await store.approveExpense(expense.id, approved)
    toast(approved ? '已批准' : '已驳回', approved ? 'success' : 'warning')
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    console.error(e)
    toast('操作失败：' + (e.message || '未知错误'), 'error')
  } finally {
    approvingId.value = null
  }
}

// --- Pay Modal ---
const showPayModal = ref(false)
const payingExpense = ref(null)
const payAccountId = ref('')
const paying = ref(false)

function openPayModal(expense) {
  payingExpense.value = expense
  payAccountId.value = expense.account_id || ''
  showPayModal.value = true
}

async function handleMarkPaid() {
  if (!payAccountId.value || paying.value) return
  // 余额校验
  const account = accountStore.accounts.find(a => a.id === payAccountId.value)
  if (account && Number(account.balance) < Number(payingExpense.value.amount)) {
    toast(`余额不足！账户 ${account.code} 余额 ¥${Number(account.balance).toFixed(2)}，需要 ¥${Number(payingExpense.value.amount).toFixed(2)}`, 'warning')
    return
  }
  paying.value = true
  try {
    await store.markAsPaid(payingExpense.value.id, payAccountId.value)
    showPayModal.value = false
    toast('已确认付款', 'success')
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    console.error(e)
    toast('付款确认失败：' + (e.message || '未知错误'), 'error')
  } finally {
    paying.value = false
  }
}

// --- Delete ---
async function handleDeleteExpense(expense) {
  if (!confirm('确定要删除此支出记录吗？')) return
  try {
    // 先软删除
    const { error } = await supabase.rpc('delete_expense', { p_id: expense.id })
    if (error) throw error
    // 如果已付款且有关联账户，退回余额
    let balResult = null
    if (expense.status === 'paid' && expense.account_id && expense.amount) {
      try {
        const { useAccountStore } = await import('../stores/accounts')
        balResult = await useAccountStore().updateBalance(expense.account_id, Number(expense.amount))
      } catch (e) { console.warn('余额回退失败:', e) }
    }
    // 操作日志
    try {
      const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
      const accInfo = expense.account_id ? await getAccountBalance(expense.account_id) : null
      const accName = accInfo?.name || ''
      const balText = balResult?.old_balance != null && balResult?.new_balance != null
        ? `，余额 ${Number(balResult.old_balance).toFixed(2)} + ${Math.abs(Number(balResult.new_balance) - Number(balResult.old_balance)).toFixed(2)} → ${Number(balResult.new_balance).toFixed(2)}`
        : ''
      await logOperation({
        action: 'delete_expense',
        module: '支出',
        description: `删除支出 ${expense.expense_no || ''}，金额 ${Number(expense.amount || 0).toFixed(2)}，类别：${expense.category || ''}，账户：${accName}${balText}`,
        detail: { expense_id: expense.id, amount: expense.amount, category: expense.category, account_id: expense.account_id, account_name: accName, balance_before: balResult?.old_balance, balance_after: balResult?.new_balance },
        amount: expense.amount,
        accountId: expense.account_id,
        accountName: accName,
      })
    } catch (_) {}
    toast('支出已删除', 'success')
    expenses.value = expenses.value.filter(e => e.id !== expense.id)
    selectedExpenses.value = selectedExpenses.value.filter(id => id !== expense.id)
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    toast(e.message || '操作失败', 'error')
  }
}

async function handleBatchDeleteExpenses() {
  if (!confirm(`确定要删除选中的 ${selectedExpenses.value.length} 条支出记录吗？`)) return
  // 收集已付款的支出信息（用于余额退回和日志记录）
  const paidExpenses = expenses.value.filter(e => selectedExpenses.value.includes(e.id) && e.status === 'paid' && e.account_id && e.amount)
  try {
    const { data, error } = await supabase.rpc('batch_delete_expenses', { p_ids: selectedExpenses.value })
    if (error) throw error
    // 退回已付款支出的余额并记录日志
    const { useAccountStore } = await import('../stores/accounts')
    const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
    for (const exp of paidExpenses) {
      let balResult = null
      try { balResult = await useAccountStore().updateBalance(exp.account_id, Number(exp.amount)) } catch (_) {}
      try {
        const accInfo = exp.account_id ? await getAccountBalance(exp.account_id) : null
        const accName = accInfo?.name || ''
        const balText = balResult?.old_balance != null && balResult?.new_balance != null
          ? `，余额 ${Number(balResult.old_balance).toFixed(2)} + ${Math.abs(Number(balResult.new_balance) - Number(balResult.old_balance)).toFixed(2)} → ${Number(balResult.new_balance).toFixed(2)}`
          : ''
        await logOperation({
          action: 'delete_expense',
          module: '支出',
          description: `[批量删除] 删除支出 ${exp.expense_no || ''}，金额 ${Number(exp.amount || 0).toFixed(2)}，类别：${exp.category || ''}，账户：${accName}${balText}`,
          detail: { expense_id: exp.id, amount: exp.amount, category: exp.category, account_id: exp.account_id, account_name: accName, balance_before: balResult?.old_balance, balance_after: balResult?.new_balance },
          amount: exp.amount,
          accountId: exp.account_id,
          accountName: accName,
        })
      } catch (_) {}
    }
    toast(`已删除 ${data?.deleted || 0} 条支出记录`, 'success')
    selectedExpenses.value = []
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    toast('批量删除失败：' + (e.message || ''), 'error')
  }
}

// --- Category Management ---
const showCategoryModal = ref(false)
const categories = ref([])
const categoriesLoading = ref(false)
const creatingCategory = ref(false)
const newCategoryName = ref('')
const editingCatId = ref(null)
const editingCatName = ref('')

async function loadCategories() {
  categoriesLoading.value = true
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .select('*')
      .order('created_at', { ascending: true })
    if (error) throw error
    categories.value = data || []
  } catch (e) {
    console.error('加载支出类别失败:', e)
  } finally {
    categoriesLoading.value = false
  }
}

async function handleCreateCategory() {
  const name = newCategoryName.value.trim()
  if (!name) return
  creatingCategory.value = true
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .insert({ name })
      .select()
      .single()
    if (error) {
      if (error.code === '23505') toast('该类别名称已存在', 'warning')
      else throw error
      return
    }
    categories.value.push(data)
    newCategoryName.value = ''
    toast('类别已添加', 'success')
  } catch (e) {
    toast('添加失败：' + (e.message || ''), 'error')
  } finally {
    creatingCategory.value = false
  }
}

async function startCategoryEdit(item) {
  editingCatId.value = item.id
  editingCatName.value = item.name
}

function cancelCategoryEdit() {
  editingCatId.value = null
  editingCatName.value = ''
}

async function saveCategoryEdit(item) {
  const name = editingCatName.value.trim()
  if (!name) { toast('类别名称不能为空', 'warning'); return }
  if (name === item.name) { cancelCategoryEdit(); return }
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .update({ name })
      .eq('id', item.id)
      .select()
      .single()
    if (error) {
      if (error.code === '23505') toast('该类别名称已存在', 'warning')
      else throw error
      return
    }
    item.name = data.name
    item.updated_at = data.updated_at
    cancelCategoryEdit()
    toast('类别已更新', 'success')
  } catch (e) {
    toast('更新失败：' + (e.message || ''), 'error')
  }
}

async function toggleCategoryStatus(item) {
  const newStatus = item.status === 'active' ? 'inactive' : 'active'
  const action = newStatus === 'inactive' ? '停用' : '启用'
  if (!confirm(`确认要${action}「${item.name}」吗？`)) return
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .update({ status: newStatus })
      .eq('id', item.id)
      .select()
      .single()
    if (error) throw error
    item.status = data.status
    toast(`已${action}`, 'success')
  } catch (e) {
    toast('操作失败', 'error')
  }
}

async function handleDeleteCategory(item) {
  try {
    const { count, error: countError } = await supabase
      .from('expenses')
      .select('id', { count: 'exact', head: true })
      .eq('category', item.name)
    if (countError) throw countError
    if (count > 0) {
      toast(`该类别下有 ${count} 条支出记录，无法删除。请先停用该类别。`, 'warning')
      return
    }
  } catch (e) {
    toast('检查失败，请稍后重试', 'error')
    return
  }
  if (!confirm(`确认要删除「${item.name}」吗？此操作不可恢复。`)) return
  try {
    const { error } = await supabase
      .from('expense_categories')
      .delete()
      .eq('id', item.id)
    if (error) throw error
    categories.value = categories.value.filter(c => c.id !== item.id)
    toast('类别已删除', 'success')
  } catch (e) {
    toast('删除失败：' + (e.message || ''), 'error')
  }
}

// --- Lifecycle ---
onMounted(async () => {
  await Promise.all([
    store.fetchExpenses(),
    accountStore.fetchAccounts(),
    fetchStats(),
    loadCategories(),
    loadTodayExpense(),
  ])
})
</script>
