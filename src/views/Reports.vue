<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">📊 财务报表</h1>
      <button v-if="!loading && hasData" @click="exportExcel"
        class="px-4 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 cursor-pointer">
        📥 导出Excel
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 mb-4 bg-gray-100 p-1 rounded-lg">
      <button v-for="tab in tabs" :key="tab.key" @click="switchTab(tab.key)"
        class="flex-1 px-3 py-2 text-sm rounded-md transition-all cursor-pointer"
        :class="activeTab === tab.key ? 'bg-white text-blue-600 font-semibold shadow-sm' : 'text-gray-500 hover:text-gray-700'">
        {{ tab.icon }} {{ tab.label }}
      </button>
    </div>

    <!-- Date Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <label class="text-sm text-gray-500">起始日期：</label>
      <input v-model="startDate" type="date"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
      <span class="text-gray-500">—</span>
      <label class="text-sm text-gray-500">截止日期：</label>
      <input v-model="endDate" type="date"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
      <div class="flex gap-1 ml-2">
        <button @click="setQuickRange('this_month')" class="px-2 py-1 text-xs rounded bg-gray-100 hover:bg-blue-100 hover:text-blue-700 cursor-pointer">本月</button>
        <button @click="setQuickRange('last_month')" class="px-2 py-1 text-xs rounded bg-gray-100 hover:bg-blue-100 hover:text-blue-700 cursor-pointer">上月</button>
        <button @click="setQuickRange('this_quarter')" class="px-2 py-1 text-xs rounded bg-gray-100 hover:bg-blue-100 hover:text-blue-700 cursor-pointer">本季度</button>
        <button @click="setQuickRange('this_year')" class="px-2 py-1 text-xs rounded bg-gray-100 hover:bg-blue-100 hover:text-blue-700 cursor-pointer">本年</button>
      </div>
      <button @click="loadReport" class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer ml-auto">
        🔄 查询
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
      <div class="text-2xl mb-2 animate-pulse">📊</div>
      <div class="text-gray-500 text-sm">加载报表数据...</div>
    </div>

    <!-- ==================== Tab 1: 收支概览 ==================== -->
    <template v-else-if="activeTab === 'overview' && overviewData">
      <!-- Summary Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">💰 总收入</div>
          <div class="text-2xl font-bold text-green-600">{{ fmt(overviewData.totalIncome) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">💸 总支出</div>
          <div class="text-2xl font-bold text-red-600">{{ fmt(overviewData.totalExpense) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">📊 净利润</div>
          <div class="text-2xl font-bold" :class="overviewData.netProfit >= 0 ? 'text-blue-600' : 'text-red-600'">{{ fmt(overviewData.netProfit) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1">📈 利润率</div>
          <div class="text-2xl font-bold text-purple-600">{{ overviewData.profitRate }}%</div>
        </div>
      </div>

      <!-- Daily Breakdown Table -->
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-100">
          <h2 class="font-bold text-gray-700">每日收支明细</h2>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left font-medium text-gray-600">日期</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">收入</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">支出</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">净利润</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in overviewData.daily" :key="row.date"
                class="border-t border-gray-50 hover:bg-gray-50/60 transition">
                <td class="px-4 py-3">{{ row.date }}</td>
                <td class="px-4 py-3 text-right font-mono text-green-600">{{ fmt(row.income) }}</td>
                <td class="px-4 py-3 text-right font-mono text-red-600">{{ fmt(row.expense) }}</td>
                <td class="px-4 py-3 text-right font-mono" :class="row.profit >= 0 ? 'text-blue-600' : 'text-red-600'">{{ fmt(row.profit) }}</td>
              </tr>
              <tr v-if="overviewData.daily.length === 0">
                <td colspan="4" class="px-4 py-12 text-center text-gray-500">暂无数据</td>
              </tr>
              <!-- Totals row -->
              <tr v-if="overviewData.daily.length > 0" class="bg-gray-50 font-bold border-t-2 border-gray-200">
                <td class="px-4 py-3">合计</td>
                <td class="px-4 py-3 text-right font-mono text-green-700">{{ fmt(overviewData.totalIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-red-700">{{ fmt(overviewData.totalExpense) }}</td>
                <td class="px-4 py-3 text-right font-mono" :class="overviewData.netProfit >= 0 ? 'text-blue-700' : 'text-red-700'">{{ fmt(overviewData.netProfit) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ==================== Tab 2: 利润表 ==================== -->
    <template v-else-if="activeTab === 'income' && incomeData">
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 bg-gradient-to-r from-blue-50 to-white">
          <h2 class="text-lg font-bold text-gray-800">利润表</h2>
          <p class="text-sm text-gray-500">{{ startDate }} 至 {{ endDate }}</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" id="income-table">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left font-semibold text-gray-600 w-16">行次</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">项目</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">金额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr>
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2 font-semibold">一、营业收入</td>
                <td class="px-6 py-2 text-right font-mono text-blue-700">{{ fmt(incomeData.revenue) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2 pl-10">减：营业成本</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.cost) }}</td>
              </tr>
              <tr class="bg-blue-50/50 font-bold">
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">二、毛利润</td>
                <td class="px-6 py-2 text-right font-mono" :class="incomeData.grossProfit >= 0 ? 'text-blue-700' : 'text-red-600'">{{ fmt(incomeData.grossProfit) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2 font-semibold">减：营业费用合计</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.expenses) }}</td>
              </tr>
              <tr v-for="(exp, idx) in incomeData.expensesDetail" :key="idx">
                <td></td>
                <td class="px-6 py-1.5 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1.5 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">5</td>
                <td class="px-6 py-2 pl-10">减：退款金额</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.refunds) }}</td>
              </tr>
              <tr class="bg-gradient-to-r from-green-50 to-emerald-50 font-bold text-lg">
                <td class="px-6 py-3 text-gray-500">6</td>
                <td class="px-6 py-3">三、净利润</td>
                <td class="px-6 py-3 text-right font-mono" :class="incomeData.netProfit >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmt(incomeData.netProfit) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ==================== Tab 3: 资产负债表 ==================== -->
    <template v-else-if="activeTab === 'balance' && balanceData">
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 bg-gradient-to-r from-blue-50 to-white">
          <h2 class="text-lg font-bold text-gray-800">资产负债表</h2>
          <p class="text-sm text-gray-500">截止日期：{{ endDate }}</p>
          <span class="inline-block mt-1 px-2 py-0.5 text-xs rounded-full"
            :class="balanceData.balanced ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'">
            {{ balanceData.balanced ? '✅ 平衡验证通过' : 'ℹ️ 仅统计了现金及已录入项目' }}
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" id="balance-table">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left font-semibold text-gray-600 w-16">项目</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">行次</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">期末余额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr class="bg-blue-50/50"><td colspan="3" class="px-6 py-2 font-bold text-blue-800">资产</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2">货币资金（现金）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.cash) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">资产合计</td>
                <td class="px-6 py-2 text-right font-mono text-blue-700">{{ fmt(balanceData.assets.total) }}</td>
              </tr>
              <tr class="bg-orange-50/50"><td colspan="3" class="px-6 py-2 font-bold text-orange-800">负债</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2">应付账款</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(0) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">股东垫资</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.shareholderLoans) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">负债合计</td>
                <td class="px-6 py-2 text-right font-mono text-orange-700">{{ fmt(balanceData.liabilities.total) }}</td>
              </tr>
              <tr class="bg-green-50/50"><td colspan="3" class="px-6 py-2 font-bold text-green-800">所有者权益</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2">留存收益（累计利润）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.equity.retainedEarnings) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">所有者权益合计</td>
                <td class="px-6 py-2 text-right font-mono text-green-700">{{ fmt(balanceData.equity.total) }}</td>
              </tr>
              <tr class="bg-blue-50 font-bold text-lg">
                <td class="px-6 py-3"></td>
                <td class="px-6 py-3">负债及所有者权益合计</td>
                <td class="px-6 py-3 text-right font-mono text-blue-700">{{ fmt(balanceData.liabilities.total + balanceData.equity.total) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Detail Cards -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
        <div v-if="balanceData.assets.cashDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3">💰 账户余额明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">账户</th><th class="text-left pb-2">平台</th><th class="text-right pb-2">余额</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.assets.cashDetail" :key="item.short_name">
                <td class="py-1.5">{{ item.short_name || item.code }}</td>
                <td class="py-1.5 text-gray-500">{{ item.platform || '-' }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.balance) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.liabilities.loansDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3">🏦 股东垫资明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">股东</th><th class="text-right pb-2">垫资额</th><th class="text-right pb-2">已还</th><th class="text-right pb-2">剩余</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.liabilities.loansDetail" :key="item.shareholder_name">
                <td class="py-1.5">{{ item.shareholder_name }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.loan_amount) }}</td>
                <td class="py-1.5 text-right font-mono text-green-600">{{ fmt(item.repaid_principal) }}</td>
                <td class="py-1.5 text-right font-mono text-red-600">{{ fmt(item.remaining_principal) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ==================== Tab 4: 现金流量表 ==================== -->
    <template v-else-if="activeTab === 'cashflow' && cashflowData">
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 bg-gradient-to-r from-blue-50 to-white">
          <h2 class="text-lg font-bold text-gray-800">现金流量表</h2>
          <p class="text-sm text-gray-500">{{ startDate }} 至 {{ endDate }}</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" id="cashflow-table">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left font-semibold text-gray-600 w-16">行次</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">项目</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">金额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr class="bg-blue-50/50"><td colspan="3" class="px-6 py-2 font-bold text-blue-800">一、经营活动产生的现金流量</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2">销售商品、提供劳务收到的现金</td>
                <td class="px-6 py-2 text-right font-mono text-green-600">{{ fmt(cashflowData.operating.cashIn) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2">购买商品、接受劳务支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.cashOutExpenses) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">支付退款</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.cashOutRefunds) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">经营活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.operating.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmt(cashflowData.operating.net) }}</td>
              </tr>
              <tr class="bg-purple-50/50"><td colspan="3" class="px-6 py-2 font-bold text-purple-800">二、投资活动产生的现金流量</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2">购建固定资产、设备支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.investing.equipmentExpense) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">投资活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.investing.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmt(cashflowData.investing.net) }}</td>
              </tr>
              <tr class="bg-orange-50/50"><td colspan="3" class="px-6 py-2 font-bold text-orange-800">三、筹资活动产生的现金流量</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">5</td>
                <td class="px-6 py-2">股东垫资收到的现金</td>
                <td class="px-6 py-2 text-right font-mono text-green-600">{{ fmt(cashflowData.financing.loanNew) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">6</td>
                <td class="px-6 py-2">偿还股东垫资支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.financing.loanRepay) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">筹资活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.financing.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmt(cashflowData.financing.net) }}</td>
              </tr>
              <tr class="bg-gradient-to-r from-blue-50 to-indigo-50 font-bold text-lg">
                <td class="px-6 py-3 text-gray-500">7</td>
                <td class="px-6 py-3">四、现金及现金等价物净增加额</td>
                <td class="px-6 py-3 text-right font-mono" :class="cashflowData.netChange >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmt(cashflowData.netChange) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ==================== Tab 5: 权益变动表 ==================== -->
    <template v-else-if="activeTab === 'equity' && equityData">
      <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 bg-gradient-to-r from-blue-50 to-white">
          <h2 class="text-lg font-bold text-gray-800">所有者权益变动表</h2>
          <p class="text-sm text-gray-500">{{ startDate }} 至 {{ endDate }}</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" id="equity-table">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left font-semibold text-gray-600 w-16">行次</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">项目</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">金额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr>
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2">期初所有者权益余额</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(equityData.beginningEquity) }}</td>
              </tr>
              <tr class="bg-blue-50/50">
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2">加：本期净利润</td>
                <td class="px-6 py-2 text-right font-mono" :class="equityData.netIncome >= 0 ? 'text-green-600' : 'text-red-600'">{{ fmt(equityData.netIncome) }}</td>
              </tr>
              <tr class="bg-orange-50/50">
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">加：本期垫资净变动</td>
                <td class="px-6 py-2 text-right font-mono" :class="equityData.loanChanges >= 0 ? 'text-green-600' : 'text-red-600'">{{ fmt(equityData.loanChanges) }}</td>
              </tr>
              <tr class="bg-gradient-to-r from-green-50 to-emerald-50 font-bold text-lg">
                <td class="px-6 py-3 text-gray-500">4</td>
                <td class="px-6 py-3">期末所有者权益余额</td>
                <td class="px-6 py-3 text-right font-mono text-blue-700">{{ fmt(equityData.endingEquity) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Shareholder Allocation -->
      <div class="bg-white rounded-xl border border-gray-100 mt-4 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100">
          <h3 class="font-bold text-gray-800">👥 股东权益分配</h3>
          <p class="text-xs text-gray-500 mt-1">任凯智 60%（董事长） / 王孟南 40%（IP）</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" id="equity-share-table">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">股东</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">持股比例</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">权益份额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="s in equityData.shareholders" :key="s.name">
                <td class="px-6 py-3 font-semibold">{{ s.name }}</td>
                <td class="px-6 py-3">{{ s.share }}</td>
                <td class="px-6 py-3 text-right font-mono text-lg" :class="s.equity >= 0 ? 'text-blue-700' : 'text-red-700'">{{ fmt(s.equity) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Empty State -->
    <div v-if="!loading && !hasData" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
      <div class="text-4xl mb-3">📊</div>
      <div class="text-gray-500">请选择日期范围后点击「查询」生成财务报表</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import * as XLSX from 'xlsx'

const auth = useAuthStore()

// ── State ──
const tabs = [
  { key: 'overview', icon: '📈', label: '收支概览' },
  { key: 'income', icon: '📊', label: '利润表' },
  { key: 'balance', icon: '📋', label: '资产负债表' },
  { key: 'cashflow', icon: '💰', label: '现金流量表' },
  { key: 'equity', icon: '👥', label: '权益变动表' },
]

const activeTab = ref('overview')
const loading = ref(false)
const startDate = ref('')
const endDate = ref('')

// Report data per tab
const overviewData = ref(null)
const incomeData = ref(null)
const balanceData = ref(null)
const cashflowData = ref(null)
const equityData = ref(null)

const hasData = computed(() => {
  switch (activeTab.value) {
    case 'overview': return !!overviewData.value
    case 'income': return !!incomeData.value
    case 'balance': return !!balanceData.value
    case 'cashflow': return !!cashflowData.value
    case 'equity': return !!equityData.value
    default: return false
  }
})

// ── Expense labels ──
const EXPENSE_LABELS = {
  salary: '工资薪酬', rent: '场地租金', equipment: '设备采购', marketing: '营销推广',
  logistics: '物流快递', office: '办公费用', tax: '税费', insurance: '保险',
  water_electric: '水电费', travel: '差旅费用', meal: '餐费', commission: '提成支出',
  platform_fee: '平台费用', maintenance: '维修保养', material: '原材料', packaging: '包装费用',
  storage: '仓储费用', shipping: '物流', daily: '日常', refund: '退款', other: '其他费用',
}

function expenseLabel(cat) {
  if (!cat) return '其他费用'
  if (/^[\u4e00-\u9fff]/.test(cat) && !EXPENSE_LABELS[cat]) return cat
  return EXPENSE_LABELS[cat] || cat
}

// ── Formatting ──
function fmt(val) {
  if (val == null) return '¥0.00'
  const num = parseFloat(val)
  if (isNaN(num)) return '¥0.00'
  return '¥' + Math.abs(num).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function fmtDate(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// ── Quick date ranges ──
function setQuickRange(range) {
  const now = new Date()
  let s, e
  switch (range) {
    case 'this_month':
      s = new Date(now.getFullYear(), now.getMonth(), 1)
      e = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      break
    case 'last_month':
      s = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      e = new Date(now.getFullYear(), now.getMonth(), 0)
      break
    case 'this_quarter': {
      const q = Math.floor(now.getMonth() / 3)
      s = new Date(now.getFullYear(), q * 3, 1)
      e = new Date(now.getFullYear(), q * 3 + 3, 0)
      break
    }
    case 'this_year':
      s = new Date(now.getFullYear(), 0, 1)
      e = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      break
    default:
      return
  }
  startDate.value = fmtDate(s)
  endDate.value = fmtDate(e)
  loadReport()
}

function switchTab(key) {
  activeTab.value = key
  // If we have dates set but no data for this tab, auto-load
  if (startDate.value && endDate.value && !hasData.value) {
    loadReport()
  }
}

// ── Data Loading ──

/** Helper: safe number from possibly null DB values */
function num(v) {
  return parseFloat(v) || 0
}

/** Generate all dates between start and end as YYYY-MM-DD strings */
function dateRange(start, end) {
  const dates = []
  const cur = new Date(start + 'T00:00:00')
  const endD = new Date(end + 'T00:00:00')
  while (cur <= endD) {
    dates.push(fmtDate(cur))
    cur.setDate(cur.getDate() + 1)
  }
  return dates
}

async function loadReport() {
  if (!startDate.value || !endDate.value) return
  if (!auth.isLoggedIn) return

  loading.value = true
  try {
    switch (activeTab.value) {
      case 'overview': await loadOverview(); break
      case 'income': await loadIncome(); break
      case 'balance': await loadBalance(); break
      case 'cashflow': await loadCashflow(); break
      case 'equity': await loadEquity(); break
    }
  } catch (err) {
    console.error('报表加载失败:', err)
  } finally {
    loading.value = false
  }
}

// ── Tab 1: 收支概览 ──
async function loadOverview() {
  // Fetch orders (income)
  const { data: orders, error: ordErr } = await supabase
    .from('orders')
    .select('amount, created_at')
    .in('status', ['completed', 'partially_refunded'])
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (ordErr) { console.error('orders query error:', ordErr); return }

  // Fetch expenses
  const { data: expenses, error: expErr } = await supabase
    .from('expenses')
    .select('amount, paid_at, created_at')
    .eq('status', 'paid')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (expErr) { console.error('expenses query error:', expErr); return }

  // Group by date
  const incomeByDate = {}
  const expenseByDate = {}

  for (const o of (orders || [])) {
    const d = o.created_at ? o.created_at.substring(0, 10) : null
    if (d) incomeByDate[d] = (incomeByDate[d] || 0) + num(o.amount)
  }

  for (const e of (expenses || [])) {
    const d = (e.paid_at || e.created_at || '').substring(0, 10)
    if (d) expenseByDate[d] = (expenseByDate[d] || 0) + num(e.amount)
  }

  // Build daily rows for all dates in range
  const allDates = dateRange(startDate.value, endDate.value)
  const daily = []
  let totalIncome = 0
  let totalExpense = 0

  for (const date of allDates) {
    const inc = incomeByDate[date] || 0
    const exp = expenseByDate[date] || 0
    if (inc === 0 && exp === 0) continue // skip empty days
    totalIncome += inc
    totalExpense += exp
    daily.push({ date, income: inc, expense: exp, profit: inc - exp })
  }

  const netProfit = totalIncome - totalExpense
  const profitRate = totalIncome > 0 ? ((netProfit / totalIncome) * 100).toFixed(1) : '0.0'

  overviewData.value = { totalIncome, totalExpense, netProfit, profitRate, daily }
}

// ── Tab 2: 利润表 ──
async function loadIncome() {
  // Revenue from orders
  const { data: orders, error: ordErr } = await supabase
    .from('orders')
    .select('id, amount')
    .in('status', ['completed', 'partially_refunded'])
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (ordErr) { console.error('orders error:', ordErr); return }

  const revenue = (orders || []).reduce((s, o) => s + num(o.amount), 0)
  const orderIds = (orders || []).map(o => o.id)

  // Cost from order_items (only for completed orders)
  let cost = 0
  if (orderIds.length > 0) {
    const { data: items, error: itemErr } = await supabase
      .from('order_items')
      .select('unit_cost, quantity, order_id')
      .in('order_id', orderIds)
    if (itemErr) { console.error('order_items error:', itemErr) }
    else {
      cost = (items || []).reduce((s, i) => s + num(i.unit_cost) * num(i.quantity), 0)
    }
  }

  const grossProfit = revenue - cost

  // Expenses by category
  const { data: expenseRows, error: expErr } = await supabase
    .from('expenses')
    .select('amount, category')
    .eq('status', 'paid')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (expErr) { console.error('expenses error:', expErr); return }

  const catMap = {}
  let totalExpenses = 0
  for (const e of (expenseRows || [])) {
    const cat = e.category || 'other'
    catMap[cat] = (catMap[cat] || 0) + num(e.amount)
    totalExpenses += num(e.amount)
  }
  const expensesDetail = Object.entries(catMap)
    .map(([category, amount]) => ({ category, amount }))
    .sort((a, b) => b.amount - a.amount)

  // Refunds
  const { data: refundRows, error: refErr } = await supabase
    .from('refunds')
    .select('refund_amount')
    .eq('status', 'completed')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (refErr) { console.error('refunds error:', refErr); return }

  const refunds = (refundRows || []).reduce((s, r) => s + num(r.refund_amount), 0)
  const netProfit = grossProfit - totalExpenses - refunds

  incomeData.value = { revenue, cost, grossProfit, expenses: totalExpenses, expensesDetail, refunds, netProfit }
}

// ── Tab 3: 资产负债表 ──
async function loadBalance() {
  // Accounts (assets)
  const { data: accounts, error: accErr } = await supabase
    .from('accounts')
    .select('short_name, code, balance, platform, status')
    .eq('status', 'active')
  if (accErr) { console.error('accounts error:', accErr); return }

  const cashTotal = (accounts || []).reduce((s, a) => s + num(a.balance), 0)

  // Shareholder loans (liabilities)
  const { data: loans, error: loanErr } = await supabase
    .from('shareholder_loans')
    .select('shareholder_name, loan_amount, repaid_principal, remaining_principal, status')
    .eq('status', 'active')
  if (loanErr) { console.error('shareholder_loans error:', loanErr); return }

  const shareholderLoans = (loans || []).reduce((s, l) => s + num(l.remaining_principal), 0)

  const assetsTotal = cashTotal
  const liabilitiesTotal = shareholderLoans
  const retainedEarnings = assetsTotal - liabilitiesTotal
  const equityTotal = retainedEarnings
  const balanced = Math.abs(assetsTotal - (liabilitiesTotal + equityTotal)) < 0.01

  balanceData.value = {
    balanced,
    assets: { cash: cashTotal, total: assetsTotal, cashDetail: accounts || [] },
    liabilities: { shareholderLoans, total: liabilitiesTotal, loansDetail: loans || [] },
    equity: { retainedEarnings, total: equityTotal },
  }
}

// ── Tab 4: 现金流量表 ──
async function loadCashflow() {
  // Operating: cash in from orders
  const { data: orders, error: ordErr } = await supabase
    .from('orders')
    .select('amount')
    .in('status', ['completed', 'partially_refunded'])
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (ordErr) { console.error('orders error:', ordErr); return }
  const cashIn = (orders || []).reduce((s, o) => s + num(o.amount), 0)

  // Operating: cash out expenses (exclude equipment for investing)
  const { data: allExpenses, error: expErr } = await supabase
    .from('expenses')
    .select('amount, category')
    .eq('status', 'paid')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (expErr) { console.error('expenses error:', expErr); return }

  let cashOutExpenses = 0
  let equipmentExpense = 0
  for (const e of (allExpenses || [])) {
    const amt = num(e.amount)
    if (e.category === 'equipment') {
      equipmentExpense += amt
    } else {
      cashOutExpenses += amt
    }
  }

  // Operating: refunds
  const { data: refundRows, error: refErr } = await supabase
    .from('refunds')
    .select('refund_amount')
    .eq('status', 'completed')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (refErr) { console.error('refunds error:', refErr); return }
  const cashOutRefunds = (refundRows || []).reduce((s, r) => s + num(r.refund_amount), 0)

  const operatingNet = cashIn - cashOutExpenses - cashOutRefunds
  const investingNet = -equipmentExpense

  // Financing: shareholder loans in period
  const { data: newLoans, error: nlErr } = await supabase
    .from('shareholder_loans')
    .select('loan_amount, repaid_principal')
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (nlErr) { console.error('shareholder_loans error:', nlErr); return }

  const loanNew = (newLoans || []).reduce((s, l) => s + num(l.loan_amount), 0)
  const loanRepay = (newLoans || []).reduce((s, l) => s + num(l.repaid_principal), 0)
  const financingNet = loanNew - loanRepay

  const netChange = operatingNet + investingNet + financingNet

  cashflowData.value = {
    operating: { cashIn, cashOutExpenses, cashOutRefunds, net: operatingNet },
    investing: { equipmentExpense, net: investingNet },
    financing: { loanNew, loanRepay, net: financingNet },
    netChange,
  }
}

// ── Tab 5: 权益变动表 ──
async function loadEquity() {
  // We need: beginning equity, net income in period, loan changes in period
  // Beginning equity = assets at start - liabilities at start (simplified: current accounts - current loans)
  // For simplicity, we compute ending equity from current balance sheet and net income from income statement

  // Current assets = sum of accounts.balance (same as balance sheet)
  const { data: accounts, error: accErr } = await supabase
    .from('accounts')
    .select('balance')
    .eq('status', 'active')
  if (accErr) { console.error('accounts error:', accErr); return }
  const currentAssets = (accounts || []).reduce((s, a) => s + num(a.balance), 0)

  // Current liabilities = shareholder loans remaining
  const { data: loans, error: loanErr } = await supabase
    .from('shareholder_loans')
    .select('remaining_principal')
    .eq('status', 'active')
  if (loanErr) { console.error('shareholder_loans error:', loanErr); return }
  const currentLiabilities = (loans || []).reduce((s, l) => s + num(l.remaining_principal), 0)
  const endingEquity = currentAssets - currentLiabilities

  // Net income in period (replicate income statement logic)
  const { data: orders, error: ordErr } = await supabase
    .from('orders')
    .select('id, amount')
    .in('status', ['completed', 'partially_refunded'])
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  if (ordErr) { console.error('orders error:', ordErr); return }
  const revenue = (orders || []).reduce((s, o) => s + num(o.amount), 0)
  const orderIds = (orders || []).map(o => o.id)

  let cost = 0
  if (orderIds.length > 0) {
    const { data: items } = await supabase
      .from('order_items')
      .select('unit_cost, quantity')
      .in('order_id', orderIds)
    cost = (items || []).reduce((s, i) => s + num(i.unit_cost) * num(i.quantity), 0)
  }

  const { data: expenseRows } = await supabase
    .from('expenses')
    .select('amount')
    .eq('status', 'paid')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  const totalExpenses = (expenseRows || []).reduce((s, e) => s + num(e.amount), 0)

  const { data: refundRows } = await supabase
    .from('refunds')
    .select('refund_amount')
    .eq('status', 'completed')
    .is('deleted_at', null)
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  const totalRefunds = (refundRows || []).reduce((s, r) => s + num(r.refund_amount), 0)

  const netIncome = revenue - cost - totalExpenses - totalRefunds

  // Loan changes in period
  const { data: periodLoans } = await supabase
    .from('shareholder_loans')
    .select('loan_amount, repaid_principal')
    .gte('created_at', startDate.value + 'T00:00:00')
    .lte('created_at', endDate.value + 'T23:59:59')
  const loanNew = (periodLoans || []).reduce((s, l) => s + num(l.loan_amount), 0)
  const loanRepay = (periodLoans || []).reduce((s, l) => s + num(l.repaid_principal), 0)
  const loanChanges = loanNew - loanRepay

  // Beginning equity = ending - net income - loan changes
  const beginningEquity = endingEquity - netIncome - loanChanges

  const shareholders = [
    { name: '任凯智', share: '60%', equity: Math.round(endingEquity * 0.6 * 100) / 100 },
    { name: '王孟南', share: '40%', equity: Math.round(endingEquity * 0.4 * 100) / 100 },
  ]

  equityData.value = { beginningEquity, netIncome, loanChanges, endingEquity, shareholders }
}

// ── Excel Export ──
function exportExcel() {
  try {
    const wb = XLSX.utils.book_new()

    if (activeTab.value === 'overview' && overviewData.value) {
      const d = overviewData.value
      const wsData = [
        ['收支概览', '', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', '', ''],
        ['总收入: ' + fmt(d.totalIncome), '总支出: ' + fmt(d.totalExpense), '净利润: ' + fmt(d.netProfit), '利润率: ' + d.profitRate + '%'],
        ['', '', '', ''],
        ['日期', '收入', '支出', '净利润'],
        ...d.daily.map(r => [r.date, r.income, r.expense, r.profit]),
        ['', '', '', ''],
        ['合计', d.totalIncome, d.totalExpense, d.netProfit],
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 14 }, { wch: 14 }, { wch: 14 }, { wch: 14 }]
      XLSX.utils.book_append_sheet(wb, ws, '收支概览')
    }

    if (activeTab.value === 'income' && incomeData.value) {
      const d = incomeData.value
      const wsData = [
        ['利润表', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', ''],
        ['', '', ''],
        ['项目', '行次', '金额'],
        ['一、营业收入', '1', d.revenue],
        ['减：营业成本', '2', -d.cost],
        ['二、毛利润', '3', d.grossProfit],
        ['减：营业费用合计', '4', -d.expenses],
        ...(d.expensesDetail || []).map(e => ['  ' + expenseLabel(e.category), '', e.amount]),
        ['减：退款金额', '5', -d.refunds],
        ['三、净利润', '6', d.netProfit],
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 30 }, { wch: 8 }, { wch: 18 }]
      XLSX.utils.book_append_sheet(wb, ws, '利润表')
    }

    if (activeTab.value === 'balance' && balanceData.value) {
      const d = balanceData.value
      const wsData = [
        ['资产负债表', '', ''],
        ['截止日期: ' + endDate.value, '', ''],
        ['', '', ''],
        ['项目', '行次', '期末余额'],
        ['资产', '', ''],
        ['  货币资金（现金）', '1', d.assets.cash],
        ['资产合计', '', d.assets.total],
        ['', '', ''],
        ['负债', '', ''],
        ['  应付账款', '2', 0],
        ['  股东垫资', '3', d.liabilities.shareholderLoans],
        ['负债合计', '', d.liabilities.total],
        ['', '', ''],
        ['所有者权益', '', ''],
        ['  留存收益', '4', d.equity.retainedEarnings],
        ['所有者权益合计', '', d.equity.total],
        ['', '', ''],
        ['负债及所有者权益合计', '', d.liabilities.total + d.equity.total],
        ['', '', ''],
        ['平衡验证: ' + (d.balanced ? '通过' : '不通过'), '', ''],
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 30 }, { wch: 8 }, { wch: 18 }]
      XLSX.utils.book_append_sheet(wb, ws, '资产负债表')
    }

    if (activeTab.value === 'cashflow' && cashflowData.value) {
      const d = cashflowData.value
      const wsData = [
        ['现金流量表', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', ''],
        ['', '', ''],
        ['项目', '行次', '金额'],
        ['一、经营活动产生的现金流量', '', ''],
        ['  销售商品、提供劳务收到的现金', '1', d.operating.cashIn],
        ['  购买商品、接受劳务支付的现金', '2', -d.operating.cashOutExpenses],
        ['  支付退款', '3', -d.operating.cashOutRefunds],
        ['经营活动现金流量净额', '', d.operating.net],
        ['', '', ''],
        ['二、投资活动产生的现金流量', '', ''],
        ['  购建固定资产、设备支付的现金', '4', -d.investing.equipmentExpense],
        ['投资活动现金流量净额', '', d.investing.net],
        ['', '', ''],
        ['三、筹资活动产生的现金流量', '', ''],
        ['  股东垫资收到的现金', '5', d.financing.loanNew],
        ['  偿还股东垫资支付的现金', '6', -d.financing.loanRepay],
        ['筹资活动现金流量净额', '', d.financing.net],
        ['', '', ''],
        ['四、现金及现金等价物净增加额', '7', d.netChange],
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 35 }, { wch: 8 }, { wch: 18 }]
      XLSX.utils.book_append_sheet(wb, ws, '现金流量表')
    }

    if (activeTab.value === 'equity' && equityData.value) {
      const d = equityData.value
      const wsData = [
        ['所有者权益变动表', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', ''],
        ['', '', ''],
        ['项目', '行次', '金额'],
        ['期初所有者权益余额', '1', d.beginningEquity],
        ['加：本期净利润', '2', d.netIncome],
        ['加：本期垫资净变动', '3', d.loanChanges],
        ['期末所有者权益余额', '4', d.endingEquity],
        ['', '', ''],
        ['股东权益分配', '持股比例', '权益份额'],
        ...d.shareholders.map(s => [s.name, s.share, s.equity]),
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 30 }, { wch: 12 }, { wch: 18 }]
      XLSX.utils.book_append_sheet(wb, ws, '所有者权益变动表')
    }

    const tabNames = { overview: '收支概览', income: '利润表', balance: '资产负债表', cashflow: '现金流量表', equity: '权益变动表' }
    const fileName = `${tabNames[activeTab.value]}_${startDate.value}_${endDate.value}.xlsx`
    XLSX.writeFile(wb, fileName)
  } catch (e) {
    console.error('导出失败:', e)
  }
}

// ── Initialization ──
function initDates() {
  const now = new Date()
  const s = new Date(now.getFullYear(), now.getMonth(), 1)
  const e = new Date(now.getFullYear(), now.getMonth() + 1, 0)
  startDate.value = fmtDate(s)
  endDate.value = fmtDate(e)
}

onMounted(() => {
  initDates()
  if (auth.isLoggedIn) {
    loadReport()
  }
})

// Watch for auth state to become ready
watch(() => auth.isLoggedIn, (loggedIn) => {
  if (loggedIn && startDate.value && endDate.value && !hasData.value) {
    loadReport()
  }
})
</script>
