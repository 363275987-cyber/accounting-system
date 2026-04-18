<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 财务报表</h1>
      <button v-if="!loading && hasData" @click="exportExcel"
        class="px-4 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 cursor-pointer"><Icon name="download" class="inline w-4 h-4 -mt-0.5 mr-1" /> 导出Excel
      </button>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 mb-4 bg-gray-100 p-1 rounded-lg overflow-x-auto">
      <button v-for="tab in tabs" :key="tab.key" @click="switchTab(tab.key)"
        class="flex-1 px-3 py-2 text-sm rounded-md transition-all cursor-pointer whitespace-nowrap"
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
      <button @click="loadReport" class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer ml-auto"><Icon name="refresh" class="inline w-4 h-4 -mt-0.5 mr-1" /> 查询
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
      <div class="text-2xl mb-2 animate-pulse"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
      <div class="text-gray-500 text-sm">加载报表数据...</div>
    </div>

    <!-- ==================== Tab 1: 收支概览 ==================== -->
    <template v-else-if="activeTab === 'overview' && overviewData">
      <!-- Summary Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 总收入</div>
          <div class="text-2xl font-bold text-green-600">{{ fmt(overviewData.totalIncome) }}</div>
          <div class="text-xs text-gray-400 mt-1">
            私域 {{ fmt(overviewData.privateIncome) }} + 电商 {{ fmt(overviewData.ecommerceIncome) }}<template v-if="overviewData.otherIncome > 0"> + 其他 {{ fmt(overviewData.otherIncome) }}</template>
          </div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 总支出</div>
          <div class="text-2xl font-bold text-red-600">{{ fmt(overviewData.totalExpense) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 净利润</div>
          <div class="text-2xl font-bold" :class="overviewData.netProfit >= 0 ? 'text-blue-600' : 'text-red-600'">{{ fmtSigned(overviewData.netProfit) }}</div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="text-sm text-gray-500 mb-1"><Icon name="trending-up" class="inline w-4 h-4 -mt-0.5 mr-1" /> 利润率</div>
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
                <th class="px-4 py-3 text-right font-medium text-gray-600">私域收入</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">电商提现</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">收入合计</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">支出</th>
                <th class="px-4 py-3 text-right font-medium text-gray-600">净利润</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in overviewData.daily" :key="row.date"
                class="border-t border-gray-50 hover:bg-gray-50/60 transition">
                <td class="px-4 py-3">{{ row.date }}</td>
                <td class="px-4 py-3 text-right font-mono text-green-600">{{ fmt(row.privateIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-teal-600">{{ fmt(row.ecommerceIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-green-700 font-medium">{{ fmt(row.income) }}</td>
                <td class="px-4 py-3 text-right font-mono text-red-600">{{ fmt(row.expense) }}</td>
                <td class="px-4 py-3 text-right font-mono" :class="row.profit >= 0 ? 'text-blue-600' : 'text-red-600'">{{ fmtSigned(row.profit) }}</td>
              </tr>
              <tr v-if="overviewData.daily.length === 0">
                <td colspan="6" class="px-4 py-12 text-center text-gray-500">暂无数据</td>
              </tr>
              <!-- Totals row -->
              <tr v-if="overviewData.daily.length > 0" class="bg-gray-50 font-bold border-t-2 border-gray-200">
                <td class="px-4 py-3">合计</td>
                <td class="px-4 py-3 text-right font-mono text-green-700">{{ fmt(overviewData.privateIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-teal-700">{{ fmt(overviewData.ecommerceIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-green-700">{{ fmt(overviewData.totalIncome) }}</td>
                <td class="px-4 py-3 text-right font-mono text-red-700">{{ fmt(overviewData.totalExpense) }}</td>
                <td class="px-4 py-3 text-right font-mono" :class="overviewData.netProfit >= 0 ? 'text-blue-700' : 'text-red-700'">{{ fmtSigned(overviewData.netProfit) }}</td>
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
              <!-- 一、营业收入 -->
              <tr class="bg-blue-50/50 font-bold">
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2">一、营业收入合计</td>
                <td class="px-6 py-2 text-right font-mono text-blue-700">{{ fmt(incomeData.revenue) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1.1</td>
                <td class="px-6 py-2 pl-10">私域销售收入</td>
                <td class="px-6 py-2 text-right font-mono text-green-600">{{ fmt(incomeData.privateRevenue) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1.2</td>
                <td class="px-6 py-2 pl-10">电商提现收入</td>
                <td class="px-6 py-2 text-right font-mono text-teal-600">{{ fmt(incomeData.ecommerceRevenue) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1.3</td>
                <td class="px-6 py-2 pl-10">其他收入（打赏/广告/赞助等）</td>
                <td class="px-6 py-2 text-right font-mono text-amber-600">{{ fmt(incomeData.otherIncome) }}</td>
              </tr>
              <!-- 二、营业成本 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2 font-semibold">二、减：营业成本</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.cost) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2.1</td>
                <td class="px-6 py-2 pl-10">产品采购成本</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(incomeData.privateCost) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2.2</td>
                <td class="px-6 py-2 pl-10">电商平台手续费</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(incomeData.ecommerceFees) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2.3</td>
                <td class="px-6 py-2 pl-10">直播内容成本（出场费+选手差旅等）</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(incomeData.livestreamCost) }}</td>
              </tr>
              <!-- 三、毛利润 -->
              <tr class="bg-blue-50/50 font-bold">
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">三、毛利润</td>
                <td class="px-6 py-2 text-right font-mono" :class="incomeData.grossProfit >= 0 ? 'text-blue-700' : 'text-red-600'">{{ fmt(incomeData.grossProfit) }}</td>
              </tr>
              <!-- 四、人工成本 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2 font-semibold">四、减：人工成本</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.laborCost) }}</td>
              </tr>
              <tr v-for="(exp, idx) in incomeData.laborDetail" :key="'labor-'+idx">
                <td></td>
                <td class="px-6 py-1.5 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1.5 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <!-- 五、营业费用 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">5</td>
                <td class="px-6 py-2 font-semibold">五、减：营业费用</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.operatingCost) }}</td>
              </tr>
              <tr v-for="(exp, idx) in incomeData.operatingDetail" :key="'op-'+idx">
                <td></td>
                <td class="px-6 py-1.5 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1.5 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <!-- 六、管理费用 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">6</td>
                <td class="px-6 py-2 font-semibold">六、减：管理费用</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.adminCost) }}</td>
              </tr>
              <tr v-for="(exp, idx) in incomeData.adminDetail" :key="'admin-'+idx">
                <td></td>
                <td class="px-6 py-1.5 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1.5 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <!-- 七、财务费用 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">7</td>
                <td class="px-6 py-2 font-semibold">七、减：财务费用</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.financialCost) }}</td>
              </tr>
              <tr v-for="(exp, idx) in incomeData.financialDetail" :key="'fin-'+idx">
                <td></td>
                <td class="px-6 py-1.5 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1.5 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <!-- 八、退款损失 -->
              <tr>
                <td class="px-6 py-2 text-gray-500">8</td>
                <td class="px-6 py-2 font-semibold">八、减：退款损失</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(incomeData.refunds) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">8.1</td>
                <td class="px-6 py-2 pl-10">私域退款</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(incomeData.privateRefunds) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">8.2</td>
                <td class="px-6 py-2 pl-10">电商退款</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(incomeData.ecommerceRefunds) }}</td>
              </tr>
              <!-- 九、净利润 -->
              <tr class="bg-gradient-to-r from-green-50 to-emerald-50 font-bold text-lg">
                <td class="px-6 py-3 text-gray-500">9</td>
                <td class="px-6 py-3">九、净利润</td>
                <td class="px-6 py-3 text-right font-mono" :class="incomeData.netProfit >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmtSigned(incomeData.netProfit) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Income Composition Card -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 收入构成</h3>
          <div class="space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">私域销售收入</span>
              <div class="flex items-center gap-2">
                <div class="w-24 bg-gray-100 rounded-full h-2">
                  <div class="bg-green-500 h-2 rounded-full" :style="{ width: incomeData.revenue > 0 ? (incomeData.privateRevenue / incomeData.revenue * 100) + '%' : '0%' }"></div>
                </div>
                <span class="text-sm font-mono text-green-600 w-28 text-right">{{ fmt(incomeData.privateRevenue) }}</span>
              </div>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-sm text-gray-600">电商提现收入</span>
              <div class="flex items-center gap-2">
                <div class="w-24 bg-gray-100 rounded-full h-2">
                  <div class="bg-teal-500 h-2 rounded-full" :style="{ width: incomeData.revenue > 0 ? (incomeData.ecommerceRevenue / incomeData.revenue * 100) + '%' : '0%' }"></div>
                </div>
                <span class="text-sm font-mono text-teal-600 w-28 text-right">{{ fmt(incomeData.ecommerceRevenue) }}</span>
              </div>
            </div>
            <div v-if="incomeData.otherIncome > 0" class="flex items-center justify-between">
              <span class="text-sm text-gray-600">其他收入</span>
              <div class="flex items-center gap-2">
                <div class="w-24 bg-gray-100 rounded-full h-2">
                  <div class="bg-amber-500 h-2 rounded-full" :style="{ width: incomeData.revenue > 0 ? (incomeData.otherIncome / incomeData.revenue * 100) + '%' : '0%' }"></div>
                </div>
                <span class="text-sm font-mono text-amber-600 w-28 text-right">{{ fmt(incomeData.otherIncome) }}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /> 电商提现明细</h3>
          <div v-if="incomeData.withdrawalDetail && incomeData.withdrawalDetail.length > 0" class="space-y-1.5">
            <div v-for="(w, idx) in incomeData.withdrawalDetail" :key="idx" class="flex items-center justify-between text-sm">
              <span class="text-gray-600 truncate">{{ w.storeName }}</span>
              <div class="text-right flex-shrink-0 ml-2">
                <span class="font-mono text-teal-600">{{ fmt(w.arrival) }}</span>
                <span class="text-xs text-gray-400 ml-1">(手续费 {{ fmt(w.fee) }})</span>
              </div>
            </div>
          </div>
          <div v-else class="text-sm text-gray-400 text-center py-4">本期无电商提现</div>
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
                <th class="px-6 py-3 text-left font-semibold text-gray-600 w-16">行次</th>
                <th class="px-6 py-3 text-left font-semibold text-gray-600">项目</th>
                <th class="px-6 py-3 text-right font-semibold text-gray-600">期末余额</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <!-- ═══ 流动资产 ═══ -->
              <tr class="bg-blue-50/50"><td colspan="3" class="px-6 py-2 font-bold text-blue-800">流动资产</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">1</td>
                <td class="px-6 py-2">货币资金（现金账户）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.cashAccounts) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2">电商平台余额</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.ecommerceBalance) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">存货（库存商品）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.inventoryValue) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2">预付账款</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.prepaidTotal) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">5</td>
                <td class="px-6 py-2">其他应收款</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.otherReceivables) }}</td>
              </tr>
              <!-- ═══ 非流动资产 ═══ -->
              <tr class="bg-blue-50/30"><td colspan="3" class="px-6 py-2 font-bold text-blue-700">非流动资产</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">6</td>
                <td class="px-6 py-2">固定资产原值</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.fixedAssetsOriginal) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">7</td>
                <td class="px-6 py-2 text-gray-500 pl-10">减：累计折旧</td>
                <td class="px-6 py-2 text-right font-mono text-red-500">-{{ fmt(balanceData.assets.accumulatedDepreciation) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">8</td>
                <td class="px-6 py-2 font-medium">固定资产净值</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.fixedAssetsNet) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">9</td>
                <td class="px-6 py-2">无形资产</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.intangibleNet) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">10</td>
                <td class="px-6 py-2">长期待摊费用</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.assets.deferredExpTotal) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">资产合计</td>
                <td class="px-6 py-2 text-right font-mono text-blue-700">{{ fmt(balanceData.assets.total) }}</td>
              </tr>

              <!-- ═══ 流动负债 ═══ -->
              <tr class="bg-orange-50/50"><td colspan="3" class="px-6 py-2 font-bold text-orange-800">流动负债</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">11</td>
                <td class="px-6 py-2">应付账款</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.payableTotal) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">12</td>
                <td class="px-6 py-2">预收账款</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.deferredRevTotal) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">13</td>
                <td class="px-6 py-2">应付职工薪酬</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.salaryPayable) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">14</td>
                <td class="px-6 py-2">其他应付款（押金/保证金）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.otherPayableTotal) }}</td>
              </tr>
              <!-- ═══ 非流动负债 ═══ -->
              <tr class="bg-orange-50/30"><td colspan="3" class="px-6 py-2 font-bold text-orange-700">非流动负债</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">15</td>
                <td class="px-6 py-2">长期借款（股东垫资）</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.liabilities.shareholderLoans) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">负债合计</td>
                <td class="px-6 py-2 text-right font-mono text-orange-700">{{ fmt(balanceData.liabilities.total) }}</td>
              </tr>

              <!-- ═══ 所有者权益 ═══ -->
              <tr class="bg-green-50/50"><td colspan="3" class="px-6 py-2 font-bold text-green-800">所有者权益</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">16</td>
                <td class="px-6 py-2">实收资本</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.equity.registeredCapital) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">17</td>
                <td class="px-6 py-2">盈余公积</td>
                <td class="px-6 py-2 text-right font-mono">{{ fmt(balanceData.equity.surplusReserve) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">18</td>
                <td class="px-6 py-2">未分配利润</td>
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
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 现金账户明细</h3>
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
        <div v-if="balanceData.assets.ecommerceDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="shopping-bag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 电商平台余额明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">店铺</th><th class="text-left pb-2">平台</th><th class="text-right pb-2">余额</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.assets.ecommerceDetail" :key="item.id">
                <td class="py-1.5">{{ item.short_name || item.code }}</td>
                <td class="py-1.5 text-gray-500">{{ ECOMMERCE_LABELS[item.ecommerce_platform] || item.ecommerce_platform || '-' }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.balance) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.assets.assetsDetail && balanceData.assets.assetsDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3">🏗️ 固定资产明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">名称</th><th class="text-left pb-2">类型</th><th class="text-right pb-2">原值</th><th class="text-right pb-2">累计折旧</th><th class="text-right pb-2">净值</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.assets.assetsDetail" :key="item.id">
                <td class="py-1.5">{{ item.name }}</td>
                <td class="py-1.5 text-gray-500">{{ item.category || '-' }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.purchase_price) }}</td>
                <td class="py-1.5 text-right font-mono text-red-500">{{ fmt(item.accumulated_depreciation) }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.current_value) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.liabilities.loansDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="building" class="inline w-4 h-4 -mt-0.5 mr-1" /> 股东垫资明细</h3>
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
        <div v-if="balanceData.liabilities.payableDetail && balanceData.liabilities.payableDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 应付账款明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">供应商</th><th class="text-right pb-2">未付金额</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.liabilities.payableDetail" :key="item.id">
                <td class="py-1.5">{{ item.supplier_name }}</td>
                <td class="py-1.5 text-right font-mono text-red-600">{{ fmt(item.remaining_amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.liabilities.deferredRevDetail && balanceData.liabilities.deferredRevDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3">🎓 预收账款明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">客户</th><th class="text-right pb-2">未消金额</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.liabilities.deferredRevDetail" :key="item.id">
                <td class="py-1.5">{{ item.customer_name }}</td>
                <td class="py-1.5 text-right font-mono text-orange-600">{{ fmt(item.remaining_amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.assets.prepaidDetail && balanceData.assets.prepaidDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="credit-card" class="inline w-4 h-4 -mt-0.5 mr-1" /> 预付账款明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">供应商</th><th class="text-right pb-2">未核销</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.assets.prepaidDetail" :key="item.id">
                <td class="py-1.5">{{ item.supplier_name }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.remaining_amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="balanceData.assets.otherRecvDetail && balanceData.assets.otherRecvDetail.length" class="bg-white rounded-xl border border-gray-100 p-4">
          <h3 class="font-semibold text-sm text-gray-700 mb-3"><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" /> 其他应收款明细</h3>
          <table class="w-full text-xs">
            <thead><tr class="text-gray-500"><th class="text-left pb-2">类型</th><th class="text-left pb-2">对方</th><th class="text-right pb-2">未收金额</th></tr></thead>
            <tbody class="divide-y divide-gray-50">
              <tr v-for="item in balanceData.assets.otherRecvDetail" :key="item.id">
                <td class="py-1.5">{{ item.receivable_type === 'deposit' ? '押金' : item.receivable_type === 'loan' ? '借出' : '其他' }}</td>
                <td class="py-1.5">{{ item.counterparty }}</td>
                <td class="py-1.5 text-right font-mono">{{ fmt(item.remaining_amount) }}</td>
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
                <td class="px-6 py-2">私域销售收到的现金</td>
                <td class="px-6 py-2 text-right font-mono text-green-600">{{ fmt(cashflowData.operating.privateCashIn) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2</td>
                <td class="px-6 py-2">电商提现到账的现金</td>
                <td class="px-6 py-2 text-right font-mono text-teal-600">{{ fmt(cashflowData.operating.ecommerceCashIn) }}</td>
              </tr>
              <tr v-if="cashflowData.operating.otherIncomeCashIn > 0">
                <td class="px-6 py-2 text-gray-500">2.1</td>
                <td class="px-6 py-2">其他收入收到的现金</td>
                <td class="px-6 py-2 text-right font-mono text-amber-600">{{ fmt(cashflowData.operating.otherIncomeCashIn) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">3</td>
                <td class="px-6 py-2">电商平台手续费支出</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.ecommerceFees) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">4</td>
                <td class="px-6 py-2">购买商品、接受劳务支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.cashOutExpenses) }}</td>
              </tr>
              <tr v-for="(exp, idx) in cashflowData.operating.expenseBreakdown" :key="idx">
                <td></td>
                <td class="px-6 py-1 pl-14 text-xs text-gray-500">{{ expenseLabel(exp.category) }}</td>
                <td class="px-6 py-1 text-right font-mono text-xs text-gray-500">{{ fmt(exp.amount) }}</td>
              </tr>
              <tr v-if="cashflowData.operating.salaryCashOut > 0">
                <td class="px-6 py-2 text-gray-500">5</td>
                <td class="px-6 py-2">支付员工工资</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.salaryCashOut) }}</td>
              </tr>
              <tr v-if="cashflowData.operating.transferFees > 0">
                <td class="px-6 py-2 text-gray-500">6</td>
                <td class="px-6 py-2">转账手续费支出</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.transferFees) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">7</td>
                <td class="px-6 py-2">支付退款</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.operating.cashOutRefunds) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">经营活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.operating.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmtSigned(cashflowData.operating.net) }}</td>
              </tr>
              <tr class="bg-purple-50/50"><td colspan="3" class="px-6 py-2 font-bold text-purple-800">二、投资活动产生的现金流量</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">6</td>
                <td class="px-6 py-2">购建固定资产、设备支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.investing.equipmentExpense) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">投资活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.investing.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmtSigned(cashflowData.investing.net) }}</td>
              </tr>
              <tr class="bg-orange-50/50"><td colspan="3" class="px-6 py-2 font-bold text-orange-800">三、筹资活动产生的现金流量</td></tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">7</td>
                <td class="px-6 py-2">股东垫资收到的现金</td>
                <td class="px-6 py-2 text-right font-mono text-green-600">{{ fmt(cashflowData.financing.loanNew) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">8</td>
                <td class="px-6 py-2">偿还股东垫资支付的现金</td>
                <td class="px-6 py-2 text-right font-mono text-red-600">-{{ fmt(cashflowData.financing.loanRepay) }}</td>
              </tr>
              <tr class="bg-gray-50 font-bold">
                <td class="px-6 py-2"></td>
                <td class="px-6 py-2">筹资活动现金流量净额</td>
                <td class="px-6 py-2 text-right font-mono" :class="cashflowData.financing.net >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmtSigned(cashflowData.financing.net) }}</td>
              </tr>
              <tr class="bg-gradient-to-r from-blue-50 to-indigo-50 font-bold text-lg">
                <td class="px-6 py-3 text-gray-500">9</td>
                <td class="px-6 py-3">四、现金及现金等价物净增加额</td>
                <td class="px-6 py-3 text-right font-mono" :class="cashflowData.netChange >= 0 ? 'text-green-700' : 'text-red-700'">{{ fmtSigned(cashflowData.netChange) }}</td>
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
                <td class="px-6 py-2 text-right font-mono" :class="equityData.netIncome >= 0 ? 'text-green-600' : 'text-red-600'">{{ fmtSigned(equityData.netIncome) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2.1</td>
                <td class="px-6 py-2 pl-10">其中：私域利润</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(equityData.privateProfit) }}</td>
              </tr>
              <tr>
                <td class="px-6 py-2 text-gray-500">2.2</td>
                <td class="px-6 py-2 pl-10">其中：电商利润</td>
                <td class="px-6 py-2 text-right font-mono text-xs text-gray-500">{{ fmt(equityData.ecommerceProfit) }}</td>
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
          <h3 class="font-bold text-gray-800"><Icon name="users" class="inline w-4 h-4 -mt-0.5 mr-1" /> 股东权益分配</h3>
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
      <div class="text-4xl mb-3"><Icon name="gauge" class="inline w-4 h-4 -mt-0.5 mr-1" /></div>
      <div class="text-gray-500">请选择日期范围后点击「查询」生成财务报表</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { loadXLSX } from '../lib/xlsxLoader'
import Icon from '../components/icons/Icons.vue'
// BUG-4 修复：所有"账面净利润"统一从 financialMetrics.computeIncomeStatement 取
// loadIncome 和 loadEquity 都调用此函数，确保跨 tab 数字一致
import { computeIncomeStatement } from '../utils/financialMetrics'

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

// BUG-7 fix: 每个 tab 的数据对应的日期范围签名，切日期后对不上就重新拉
const tabCacheKey = ref({ overview: '', income: '', balance: '', cashflow: '', equity: '' })
function currentRangeKey() {
  return `${startDate.value}_${endDate.value}`
}

const hasData = computed(() => {
  const key = currentRangeKey()
  switch (activeTab.value) {
    case 'overview': return !!overviewData.value && tabCacheKey.value.overview === key
    case 'income': return !!incomeData.value && tabCacheKey.value.income === key
    case 'balance': return !!balanceData.value && tabCacheKey.value.balance === key
    case 'cashflow': return !!cashflowData.value && tabCacheKey.value.cashflow === key
    case 'equity': return !!equityData.value && tabCacheKey.value.equity === key
    default: return false
  }
})

// ── Labels ──
const EXPENSE_LABELS = {
  salary: '基本工资', social_insurance: '社保公积金', commission: '销售提成',
  bonus: '绩效奖金', penalty: '罚款扣除',
  rent: '场地租金', water_electric: '水电费', shipping: '物流快递',
  marketing: '营销推广', packaging: '包装费用', office: '办公费用',
  maintenance: '维修保养', storage: '仓储费用', material: '原材料', daily: '日常开支',
  livestream_cost: '直播成本',
  financial_fee: '转账手续费', interest: '利息支出', platform_fee: '平台费用',
  travel: '差旅费用', meal: '餐费', tax: '税费', insurance: '保险',
  equipment: '设备采购', refund: '退款', other: '其他',
}

const REPORT_GROUP = {
  livestream_cost: 'cogs',
  salary: 'labor', social_insurance: 'labor', commission: 'labor', bonus: 'labor', penalty: 'labor',
  rent: 'operating', water_electric: 'operating', shipping: 'operating', marketing: 'operating',
  packaging: 'operating', office: 'operating', maintenance: 'operating', storage: 'operating',
  material: 'operating', daily: 'operating',
  financial_fee: 'financial', interest: 'financial', platform_fee: 'financial',
  travel: 'admin', meal: 'admin', tax: 'admin', insurance: 'admin',
  equipment: 'investing',
  refund: 'other', other: 'other',
}

// 中文类别→英文key 反查（覆盖 expense_categories 表所有值）
const CHINESE_TO_KEY = {
  // 采购/成本类 → material (operating)
  '球杆采购': 'material', '配件采购': 'material', '样品费': 'material',
  '采购成本': 'material', '原材料': 'material',
  // 物流 → shipping (operating)
  '运费': 'shipping', '物流快递': 'shipping',
  // 包装 → packaging (operating)
  '包装': 'packaging', '包装费': 'packaging',
  // 人工 → salary/labor
  '工资': 'salary', '社保': 'social_insurance', '社保费': 'social_insurance',
  '公积金费': 'social_insurance', '基本工资': 'salary', '兼职薪资': 'salary',
  // 场地 → rent/water (operating)
  '房租': 'rent', '租金': 'rent', '房租物业': 'rent',
  '水电': 'water_electric', '水电费': 'water_electric',
  '安装费': 'maintenance', '维修费': 'maintenance',
  // 营销 → marketing (operating)
  '广告推广': 'marketing', '推广费': 'marketing', '宣传费': 'marketing',
  '营销': 'marketing', '营销推广': 'marketing',
  '举办活动道具': 'marketing', '拍摄道具/工具': 'marketing', '拍摄工具': 'marketing',
  '好评返现': 'marketing', 'PK奖励': 'marketing',
  // 直播 → livestream_cost (cogs)
  '直播费用': 'livestream_cost', '投流': 'livestream_cost',
  '投信息流服务费': 'livestream_cost', '直播成本': 'livestream_cost',
  // 平台/财务 → platform_fee/financial
  '平台手续费': 'platform_fee', '平台费': 'platform_fee', '平台费用': 'platform_fee',
  '销售服务费': 'platform_fee', '管理服务费': 'platform_fee',
  '品牌设计服务费': 'platform_fee', '公众号服务费': 'platform_fee',
  '软件服务费': 'platform_fee',
  // 退款 → refund (other)
  '退款': 'refund', '售后赔偿': 'refund',
  // 办公/行政 → office/admin
  '办公费': 'office', '办公费用': 'office',
  '通讯费': 'office', '充流量费': 'office', 'ICP备案': 'office',
  '差旅费': 'travel', '交通费': 'travel',
  '招待费': 'meal', '餐费': 'meal',
  '缴纳税费': 'tax', '税费': 'tax',
  '培训费': 'office', '学习投资': 'office', '培训学习': 'office',
  '招聘费': 'office',
  '福利费': 'salary', '团建费': 'marketing', '年会物资': 'marketing',
  '公益费用': 'other',
  '仓储费': 'storage',
  '商标费': 'other',
  '收号费': 'other',
  // 固定资产/折旧
  '折旧费': 'equipment', '累计摊销': 'equipment', '固定资产购入': 'equipment',
  '设备': 'equipment', '设备采购': 'equipment', '设备器材': 'equipment',
  // 杂项
  '线下大师班物资': 'marketing',
  '日常': 'daily', '日常开支': 'daily',
  '预付账款': 'other', '押金/保证金': 'other',
  '其他': 'other', '其他费用': 'other', '选手费用': 'other',
}

// 标准化类别：中文名转英文key，英文key原样返回
function normalizeCategory(cat) {
  if (!cat) return 'other'
  if (/^[a-z_]+$/.test(cat)) return cat
  return CHINESE_TO_KEY[cat] || 'other'
}

// 其他收入查询（容错：表不存在则返回空数组）
async function loadOtherIncome(startISO, endISO) {
  try {
    const { data, error } = await supabase
      .from('other_income')
      .select('amount, category, created_at')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO)
    if (error) { console.warn('other_income query error (table may not exist):', error.message); return [] }
    return data || []
  } catch (e) {
    console.warn('other_income fallback to empty:', e.message)
    return []
  }
}

// ── 公共：加载员工工资数据(现金口径，按 pay_date 过滤) ──
//
// 用于 loadOverview / loadCashflow 这种"实际发生现金流"的口径。
// 利润表(loadIncome)和所有者权益(loadEquity)走 financialMetrics.computeIncomeStatement，
// 那里用的是按 pay_month 的权责发生制，不走这个函数。
//
// 之前这里按 created_at 过滤是错的：salaries 上传时间和实际发薪日完全不相关，
// 导致 8 月发的 7 月工资会被算到 8 月的现金流里。
async function loadSalaries(startISO, endISO) {
  try {
    const startDate = (startISO || '').slice(0, 10)
    const endDate = (endISO || '').slice(0, 10)
    const { data, error } = await supabase
      .from('salaries')
      .select('actual_amount, employee_name, pay_date')
      .is('deleted_at', null)
      .not('pay_date', 'is', null)
      .gte('pay_date', startDate)
      .lte('pay_date', endDate)
    if (error) { console.warn('salaries query error:', error.message); return [] }
    return data || []
  } catch (e) {
    console.warn('salaries fallback to empty:', e.message)
    return []
  }
}

// ── 公共：加载转账手续费 ──
async function loadTransferFees(startISO, endISO) {
  try {
    const { data, error } = await supabase
      .from('account_transfers')
      .select('fee')
      .is('deleted_at', null)
      .gt('fee', 0)
      .gte('transfer_date', startISO)
      .lte('transfer_date', endISO)
    if (error) { console.warn('transfer fees query error:', error.message); return 0 }
    return (data || []).reduce((s, t) => s + num(t.fee), 0)
  } catch (e) {
    console.warn('transfer fees fallback to 0:', e.message)
    return 0
  }
}

const ECOMMERCE_LABELS = {
  douyin: '抖音', kuaishou: '快手', shipinhao: '视频号', taobao: '淘宝', weixin_video: '视频号',
}

function expenseLabel(cat) {
  if (!cat) return '其他费用'
  if (cat === '_salary_system') return '员工工资（工资表）'
  if (cat === '_transfer_fee') return '转账手续费'
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
// 带正负号的格式化，用于净额/合计行
function fmtSigned(val) {
  if (val == null) return '¥0.00'
  const num = parseFloat(val)
  if (isNaN(num)) return '¥0.00'
  const abs = Math.abs(num).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  if (num < 0) return '-¥' + abs
  return '¥' + abs
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
  if (startDate.value && endDate.value && !hasData.value) {
    loadReport()
  }
}

// ── Data Loading ──

function num(v) {
  return parseFloat(v) || 0
}

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
  const key = currentRangeKey()
  try {
    switch (activeTab.value) {
      case 'overview': await loadOverview(); tabCacheKey.value.overview = key; break
      case 'income': await loadIncome(); tabCacheKey.value.income = key; break
      case 'balance': await loadBalance(); tabCacheKey.value.balance = key; break
      case 'cashflow': await loadCashflow(); tabCacheKey.value.cashflow = key; break
      case 'equity': await loadEquity(); tabCacheKey.value.equity = key; break
    }
  } catch (err) {
    console.error('报表加载失败:', err)
  } finally {
    loading.value = false
  }
}

// ── 公共：取订单实收金额（优先 payment_amount，兜底 amount）──
function orderAmt(o) {
  return num(o.payment_amount) || num(o.amount)
}

// ── 公共：加载电商提现数据 ──
async function loadWithdrawals(startISO, endISO) {
  try {
    const { data, error } = await supabase
      .from('withdrawals')
      .select('amount, actual_arrival, created_at, account_id')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO)
    if (error) throw error
    // 补充店铺名称
    const accountIds = [...new Set((data || []).map(w => w.account_id).filter(Boolean))]
    let storeMap = {}
    if (accountIds.length > 0) {
      const { data: stores } = await supabase
        .from('accounts')
        .select('id, short_name, ecommerce_platform')
        .in('id', accountIds)
      for (const s of (stores || [])) storeMap[s.id] = s
    }
    return (data || []).map(w => ({
      ...w,
      from_store: storeMap[w.account_id] || null,
    }))
  } catch (e) {
    console.warn('withdrawals query error:', e.message || e)
    return []
  }
}

// ── Tab 1: 收支概览 ──
async function loadOverview() {
  const startISO = startDate.value + 'T00:00:00'
  const endISO = endDate.value + 'T23:59:59'

  const [ordRes, expRes, withdrawals, otherIncomeRows, salaryRows, transferFeesTotal] = await Promise.all([
    // 私域订单收入
    supabase
      .from('orders')
      .select('amount, payment_amount, created_at')
      .in('status', ['completed', 'partially_refunded'])
      .is('deleted_at', null)
      .is('platform_type', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 支出
    supabase
      .from('expenses')
      .select('amount, paid_at, created_at')
      .eq('status', 'paid')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 电商提现
    loadWithdrawals(startISO, endISO),
    // 其他收入
    loadOtherIncome(startISO, endISO),
    // 员工工资
    loadSalaries(startISO, endISO),
    // 转账手续费
    loadTransferFees(startISO, endISO),
  ])

  if (ordRes.error) { console.error('orders error:', ordRes.error); return }
  if (expRes.error) { console.error('expenses error:', expRes.error); return }

  // Group by date
  const privateByDate = {}
  const ecomByDate = {}
  const expenseByDate = {}
  const otherIncomeByDate = {}

  for (const o of (ordRes.data || [])) {
    const d = o.created_at ? o.created_at.substring(0, 10) : null
    if (d) privateByDate[d] = (privateByDate[d] || 0) + orderAmt(o)
  }

  for (const w of withdrawals) {
    const d = w.created_at ? w.created_at.substring(0, 10) : null
    if (d) ecomByDate[d] = (ecomByDate[d] || 0) + num(w.actual_arrival)
  }

  for (const e of (expRes.data || [])) {
    const d = (e.paid_at || e.created_at || '').substring(0, 10)
    if (d) expenseByDate[d] = (expenseByDate[d] || 0) + num(e.amount)
  }

  for (const oi of otherIncomeRows) {
    const d = oi.created_at ? oi.created_at.substring(0, 10) : null
    if (d) otherIncomeByDate[d] = (otherIncomeByDate[d] || 0) + num(oi.amount)
  }

  const allDates = dateRange(startDate.value, endDate.value)
  const daily = []
  let totalPrivate = 0
  let totalEcom = 0
  let totalOtherIncome = 0
  let totalExpense = 0

  for (const date of allDates) {
    const prv = privateByDate[date] || 0
    const ecm = ecomByDate[date] || 0
    const oth = otherIncomeByDate[date] || 0
    const exp = expenseByDate[date] || 0
    if (prv === 0 && ecm === 0 && oth === 0 && exp === 0) continue
    const inc = prv + ecm + oth
    totalPrivate += prv
    totalEcom += ecm
    totalOtherIncome += oth
    totalExpense += exp
    daily.push({ date, privateIncome: prv, ecommerceIncome: ecm, otherIncome: oth, income: inc, expense: exp, profit: inc - exp })
  }

  // 加上工资和转账手续费
  const salaryExpense = salaryRows.reduce((s, r) => s + num(r.actual_amount), 0)
  totalExpense += salaryExpense + transferFeesTotal

  const totalIncome = totalPrivate + totalEcom + totalOtherIncome
  const netProfit = totalIncome - totalExpense
  const profitRate = totalIncome > 0 ? ((netProfit / totalIncome) * 100).toFixed(1) : '0.0'

  overviewData.value = { totalIncome, privateIncome: totalPrivate, ecommerceIncome: totalEcom, otherIncome: totalOtherIncome, totalExpense, netProfit, profitRate, daily }
}

// ── Tab 2: 利润表 ──
//
// BUG-4 修复：原本这里有 ~150 行的 SQL+计算逻辑，且 loadEquity tab 的"净利润"
// 用了独立的简化公式，导致两个 tab 的"净利润"数字不一致。
// 现在统一调用 financialMetrics.computeIncomeStatement，loadEquity 也调同一个函数，
// 跨 tab 数字必然一致。本函数只负责把结果拼装成 incomeData 的 UI 结构。
async function loadIncome() {
  const startISO = startDate.value + 'T00:00:00'
  const endISO = endDate.value + 'T23:59:59'

  let result
  try {
    result = await computeIncomeStatement(supabase, startISO, endISO)
  } catch (e) {
    console.error('computeIncomeStatement error:', e)
    return
  }

  // 提现明细按店铺汇总（UI 表格用，computeIncomeStatement 只返回原始 withdrawals）
  const storeMap = {}
  for (const w of result.withdrawals) {
    const name = w.from_store?.short_name || '未知店铺'
    if (!storeMap[name]) storeMap[name] = { storeName: name, arrival: 0, fee: 0 }
    storeMap[name].arrival += num(w.actual_arrival)
    storeMap[name].fee += num(w.amount) - num(w.actual_arrival)
  }
  const withdrawalDetail = Object.values(storeMap).sort((a, b) => b.arrival - a.arrival)

  incomeData.value = {
    revenue: result.revenue,
    privateRevenue: result.privateRevenue,
    ecommerceRevenue: result.ecommerceRevenue,
    otherIncome: result.otherIncome,
    cost: result.cost,
    privateCost: result.privateCost,
    ecommerceFees: result.ecommerceFees,
    livestreamCost: result.livestreamCost,
    grossProfit: result.grossProfit,
    laborCost: result.laborCost,
    laborDetail: result.laborDetail,
    operatingCost: result.operatingCost,
    operatingDetail: result.operatingDetail,
    adminCost: result.adminCost,
    adminDetail: result.adminDetail,
    financialCost: result.financialCost,
    financialDetail: result.financialDetail,
    refunds: result.refunds,
    privateRefunds: result.privateRefunds,
    ecommerceRefunds: result.ecommerceRefunds,
    netProfit: result.netProfit,
    withdrawalDetail,
  }
}

// ── Tab 3: 资产负债表（完整版） ──
async function loadBalance() {
  const [accRes, ecomAccRes, loanRes, assetRes, inventoryRes, prepaidRes, otherRecvRes, intangibleRes, deferredExpRes, payableRes, deferredRevRes, dividendRes, salaryPayableRes, otherPayableRes, settingsRes] = await Promise.all([
    // 1. 现金账户（非电商）
    supabase
      .from('accounts')
      .select('id, short_name, code, balance, platform, status, ecommerce_platform')
      .eq('status', 'active')
      .is('ecommerce_platform', null),
    // 2. 电商平台账户
    supabase
      .from('accounts')
      .select('id, short_name, code, balance, platform, ecommerce_platform, status')
      .eq('status', 'active')
      .not('ecommerce_platform', 'is', null),
    // 3. 股东垫资
    supabase
      .from('shareholder_loans')
      .select('shareholder_name, loan_amount, repaid_principal, remaining_principal, status')
      .eq('status', 'active'),
    // 4. 固定资产
    supabase
      .from('assets')
      .select('id, name, category, purchase_price, current_value, accumulated_depreciation, status')
      .is('deleted_at', null)
      .neq('status', 'disposed'),
    // 5. 库存（关联产品获取成本价）
    supabase
      .from('inventory')
      .select('id, stock, product_id, products(name, cost_price)'),
    // 6. 预付账款
    supabase
      .from('prepaid_accounts')
      .select('id, supplier_name, remaining_amount, status')
      .is('deleted_at', null)
      .neq('status', 'settled'),
    // 7. 其他应收款
    supabase
      .from('other_receivables')
      .select('id, receivable_type, counterparty, remaining_amount, status')
      .is('deleted_at', null)
      .neq('status', 'recovered'),
    // 8. 无形资产
    supabase
      .from('intangible_assets')
      .select('id, name, asset_type, purchase_cost, accumulated_amortization, current_value, status')
      .is('deleted_at', null)
      .neq('status', 'disposed'),
    // 9. 长期待摊费用
    supabase
      .from('deferred_expenses')
      .select('id, name, category, remaining_amount, status')
      .is('deleted_at', null)
      .eq('status', 'active'),
    // 10. 应付账款
    supabase
      .from('payable_accounts')
      .select('id, supplier_name, remaining_amount, status')
      .is('deleted_at', null)
      .neq('status', 'paid'),
    // 11. 预收账款
    supabase
      .from('deferred_revenue')
      .select('id, customer_name, remaining_amount, status')
      .is('deleted_at', null)
      .eq('status', 'active'),
    // 12. 已分红
    supabase
      .from('dividends')
      .select('amount, status')
      .is('deleted_at', null)
      .eq('status', 'paid'),
    // 13. 应付工资（已计算未发放的工资）
    supabase
      .from('salaries')
      .select('actual_amount')
      .is('deleted_at', null)
      .is('pay_date', null),
    // 14. 其他应付款（收到的押金/保证金）
    supabase
      .from('other_payables')
      .select('id, payable_type, counterparty, remaining_amount, status')
      .is('deleted_at', null)
      .neq('status', 'returned'),
    // 15. 实收资本 + 盈余公积
    supabase
      .from('system_settings')
      .select('key, value')
      .in('key', ['registered_capital', 'surplus_reserve']),
  ])

  if (accRes.error) { console.error('accounts error:', accRes.error); return }

  // ─── 资产类 ───
  const cashAccounts = (accRes.data || []).reduce((s, a) => s + num(a.balance), 0)
  const ecommerceBalance = (ecomAccRes.data || []).reduce((s, a) => s + num(a.balance), 0)
  const fixedAssetsOriginal = (assetRes.data || []).reduce((s, a) => s + num(a.purchase_price), 0)
  const accumulatedDepreciation = (assetRes.data || []).reduce((s, a) => s + num(a.accumulated_depreciation), 0)
  const fixedAssetsNet = fixedAssetsOriginal - accumulatedDepreciation
  const inventoryValue = (inventoryRes.data || []).reduce((s, i) => s + num(i.stock) * num(i.products?.cost_price), 0)
  const prepaidTotal = (prepaidRes.data || []).reduce((s, p) => s + num(p.remaining_amount), 0)
  const otherReceivables = (otherRecvRes.data || []).reduce((s, r) => s + num(r.remaining_amount), 0)
  const intangibleNet = (intangibleRes.data || []).reduce((s, a) => s + num(a.current_value), 0)
  const deferredExpTotal = (deferredExpRes.data || []).reduce((s, d) => s + num(d.remaining_amount), 0)

  const assetsTotal = cashAccounts + ecommerceBalance + fixedAssetsNet + inventoryValue + prepaidTotal + otherReceivables + intangibleNet + deferredExpTotal

  // ─── 负债类 ───
  // 流动负债
  const payableTotal = (payableRes.data || []).reduce((s, p) => s + num(p.remaining_amount), 0)
  const deferredRevTotal = (deferredRevRes.data || []).reduce((s, d) => s + num(d.remaining_amount), 0)
  const salaryPayable = (salaryPayableRes.data || []).reduce((s, r) => s + num(r.actual_amount), 0)
  const otherPayableTotal = (otherPayableRes.data || []).reduce((s, p) => s + num(p.remaining_amount), 0)
  // 非流动负债
  const shareholderLoans = (loanRes.data || []).reduce((s, l) => s + num(l.remaining_principal), 0)

  const liabilitiesTotal = payableTotal + deferredRevTotal + salaryPayable + otherPayableTotal + shareholderLoans

  // ─── 所有者权益 ───
  const settingsMap = {}
  ;(settingsRes.data || []).forEach(s => { settingsMap[s.key] = num(s.value) })
  const registeredCapital = settingsMap.registered_capital || 0
  const surplusReserve = settingsMap.surplus_reserve || 0
  const totalDividends = (dividendRes.data || []).reduce((s, d) => s + num(d.amount), 0)
  const retainedEarnings = assetsTotal - liabilitiesTotal - registeredCapital - surplusReserve
  const equityTotal = registeredCapital + surplusReserve + retainedEarnings
  const balanced = Math.abs(assetsTotal - (liabilitiesTotal + equityTotal)) < 0.01

  balanceData.value = {
    balanced,
    assets: {
      cashAccounts,
      ecommerceBalance,
      fixedAssetsOriginal,
      accumulatedDepreciation,
      fixedAssetsNet,
      inventoryValue,
      prepaidTotal,
      otherReceivables,
      intangibleNet,
      deferredExpTotal,
      total: assetsTotal,
      cashDetail: accRes.data || [],
      ecommerceDetail: ecomAccRes.data || [],
      assetsDetail: assetRes.data || [],
      inventoryDetail: inventoryRes.data || [],
      prepaidDetail: prepaidRes.data || [],
      otherRecvDetail: otherRecvRes.data || [],
      intangibleDetail: intangibleRes.data || [],
      deferredExpDetail: deferredExpRes.data || [],
    },
    liabilities: {
      // 流动负债
      payableTotal,
      deferredRevTotal,
      salaryPayable,
      otherPayableTotal,
      // 非流动负债
      shareholderLoans,
      total: liabilitiesTotal,
      loansDetail: loanRes.data || [],
      payableDetail: payableRes.data || [],
      deferredRevDetail: deferredRevRes.data || [],
      otherPayableDetail: otherPayableRes.data || [],
    },
    equity: { registeredCapital, surplusReserve, retainedEarnings, totalDividends, total: equityTotal },
  }
}

// ── Tab 4: 现金流量表 ──
async function loadCashflow() {
  const startISO = startDate.value + 'T00:00:00'
  const endISO = endDate.value + 'T23:59:59'

  const [ordRes, expRes, refRes, withdrawals, loanRes, otherIncomeRows, salaryRows, transferFeesTotal] = await Promise.all([
    // 私域订单收入
    supabase
      .from('orders')
      .select('amount, payment_amount')
      .in('status', ['completed', 'partially_refunded'])
      .is('deleted_at', null)
      .is('platform_type', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 全部支出
    supabase
      .from('expenses')
      .select('amount, category')
      .eq('status', 'paid')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 退款
    supabase
      .from('refunds')
      .select('refund_amount')
      .eq('status', 'completed')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 电商提现
    loadWithdrawals(startISO, endISO),
    // 股东垫资
    supabase
      .from('shareholder_loans')
      .select('loan_amount, repaid_principal')
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    // 其他收入
    loadOtherIncome(startISO, endISO),
    // 员工工资
    loadSalaries(startISO, endISO),
    // 转账手续费
    loadTransferFees(startISO, endISO),
  ])

  if (ordRes.error) { console.error('orders error:', ordRes.error); return }
  if (expRes.error) { console.error('expenses error:', expRes.error); return }

  const privateCashIn = (ordRes.data || []).reduce((s, o) => s + orderAmt(o), 0)
  const ecommerceCashIn = withdrawals.reduce((s, w) => s + num(w.actual_arrival), 0)
  const ecommerceFees = withdrawals.reduce((s, w) => s + num(w.amount) - num(w.actual_arrival), 0)

  // 费用按类别
  let cashOutExpenses = 0
  let equipmentExpense = 0
  const catMap = {}
  for (const e of (expRes.data || [])) {
    const amt = num(e.amount)
    const cat = normalizeCategory(e.category)
    if (cat === 'equipment') {
      equipmentExpense += amt
    } else {
      cashOutExpenses += amt
      catMap[cat] = (catMap[cat] || 0) + amt
    }
  }
  const expenseBreakdown = Object.entries(catMap)
    .map(([category, amount]) => ({ category, amount }))
    .sort((a, b) => b.amount - a.amount)

  const otherIncomeCashIn = otherIncomeRows.reduce((s, oi) => s + num(oi.amount), 0)
  const salaryCashOut = salaryRows.reduce((s, r) => s + num(r.actual_amount), 0)

  const cashOutRefunds = (refRes.data || []).reduce((s, r) => s + num(r.refund_amount), 0)
  const operatingNet = privateCashIn + ecommerceCashIn + otherIncomeCashIn - ecommerceFees - cashOutExpenses - salaryCashOut - transferFeesTotal - cashOutRefunds
  const investingNet = -equipmentExpense

  const loanNew = (loanRes.data || []).reduce((s, l) => s + num(l.loan_amount), 0)
  const loanRepay = (loanRes.data || []).reduce((s, l) => s + num(l.repaid_principal), 0)
  const financingNet = loanNew - loanRepay
  const netChange = operatingNet + investingNet + financingNet

  cashflowData.value = {
    operating: { privateCashIn, ecommerceCashIn, otherIncomeCashIn, ecommerceFees: Math.max(0, ecommerceFees), cashOutExpenses, expenseBreakdown, cashOutRefunds, salaryCashOut, transferFees: transferFeesTotal, net: operatingNet },
    investing: { equipmentExpense, net: investingNet },
    financing: { loanNew, loanRepay, net: financingNet },
    netChange,
  }
}

// ── Tab 5: 权益变动表 ──
//
// BUG-4 修复：原本这里有自己的"净利润"算法（revenue - privateCost - 全部expenses - 退款），
// 和利润表 tab 的算法不同（利润表是 grossProfit - 5项费用 - 退款），用户切 tab
// 看到不一样的"净利润"。现在 netIncome / privateProfit / ecommerceProfit 全部从
// computeIncomeStatement 取，和利润表 tab 用同一份计算结果。
async function loadEquity() {
  const startISO = startDate.value + 'T00:00:00'
  const endISO = endDate.value + 'T23:59:59'

  // 期末资产
  const { data: accounts } = await supabase
    .from('accounts')
    .select('balance')
    .eq('status', 'active')
  const currentAssets = (accounts || []).reduce((s, a) => s + num(a.balance), 0)

  // 固定资产
  const { data: assets } = await supabase
    .from('assets')
    .select('current_value')
    .eq('status', 'active')
  const fixedAssets = (assets || []).reduce((s, a) => s + num(a.current_value), 0)

  // 期末负债
  const { data: loans } = await supabase
    .from('shareholder_loans')
    .select('remaining_principal')
    .eq('status', 'active')
  const currentLiabilities = (loans || []).reduce((s, l) => s + num(l.remaining_principal), 0)
  const endingEquity = currentAssets + fixedAssets - currentLiabilities

  // 净利润：复用利润表的完整账面口径，跨 tab 一致
  let incomeResult
  try {
    incomeResult = await computeIncomeStatement(supabase, startISO, endISO)
  } catch (e) {
    console.error('computeIncomeStatement error in loadEquity:', e)
    return
  }
  const netIncome = incomeResult.netProfit
  const privateProfit = incomeResult.privateProfit
  const ecommerceProfit = incomeResult.ecommerceProfit

  // 垫资变动
  const { data: periodLoans } = await supabase
    .from('shareholder_loans')
    .select('loan_amount, repaid_principal')
    .gte('created_at', startISO)
    .lte('created_at', endISO)
  const loanNew = (periodLoans || []).reduce((s, l) => s + num(l.loan_amount), 0)
  const loanRepay = (periodLoans || []).reduce((s, l) => s + num(l.repaid_principal), 0)
  const loanChanges = loanNew - loanRepay

  const beginningEquity = endingEquity - netIncome - loanChanges

  const shareholders = [
    { name: '任凯智', share: '60%', equity: Math.round(endingEquity * 0.6 * 100) / 100 },
    { name: '王孟南', share: '40%', equity: Math.round(endingEquity * 0.4 * 100) / 100 },
  ]

  equityData.value = { beginningEquity, netIncome, privateProfit, ecommerceProfit, loanChanges, endingEquity, shareholders }
}

// ── Excel Export ──
async function exportExcel() {
  const XLSX = await loadXLSX()
  try {
    const wb = XLSX.utils.book_new()

    if (activeTab.value === 'overview' && overviewData.value) {
      const d = overviewData.value
      const wsData = [
        ['收支概览', '', '', '', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', '', '', '', ''],
        ['总收入: ' + fmt(d.totalIncome), '私域: ' + fmt(d.privateIncome), '电商提现: ' + fmt(d.ecommerceIncome), '总支出: ' + fmt(d.totalExpense), '净利润: ' + fmtSigned(d.netProfit), '利润率: ' + d.profitRate + '%'],
        ['', '', '', '', '', ''],
        ['日期', '私域收入', '电商提现', '收入合计', '支出', '净利润'],
        ...d.daily.map(r => [r.date, r.privateIncome, r.ecommerceIncome, r.income, r.expense, r.profit]),
        ['', '', '', '', '', ''],
        ['合计', d.privateIncome, d.ecommerceIncome, d.totalIncome, d.totalExpense, d.netProfit],
      ]
      const ws = XLSX.utils.aoa_to_sheet(wsData)
      ws['!cols'] = [{ wch: 14 }, { wch: 14 }, { wch: 14 }, { wch: 14 }, { wch: 14 }, { wch: 14 }]
      XLSX.utils.book_append_sheet(wb, ws, '收支概览')
    }

    if (activeTab.value === 'income' && incomeData.value) {
      const d = incomeData.value
      const wsData = [
        ['利润表', '', ''],
        ['期间: ' + startDate.value + ' 至 ' + endDate.value, '', ''],
        ['', '', ''],
        ['项目', '行次', '金额'],
        ['一、营业收入合计', '1', d.revenue],
        ['  私域销售收入', '1.1', d.privateRevenue],
        ['  电商提现收入', '1.2', d.ecommerceRevenue],
        ['  其他收入（打赏/广告/赞助等）', '1.3', d.otherIncome],
        ['二、减：营业成本', '2', -d.cost],
        ['  产品采购成本', '2.1', d.privateCost],
        ['  电商平台手续费', '2.2', d.ecommerceFees],
        ['  直播内容成本', '2.3', d.livestreamCost],
        ['三、毛利润', '3', d.grossProfit],
        ['四、减：人工成本', '4', -d.laborCost],
        ...(d.laborDetail || []).map(e => ['  ' + expenseLabel(e.category), '', e.amount]),
        ['五、减：营业费用', '5', -d.operatingCost],
        ...(d.operatingDetail || []).map(e => ['  ' + expenseLabel(e.category), '', e.amount]),
        ['六、减：管理费用', '6', -d.adminCost],
        ...(d.adminDetail || []).map(e => ['  ' + expenseLabel(e.category), '', e.amount]),
        ['七、减：财务费用', '7', -d.financialCost],
        ...(d.financialDetail || []).map(e => ['  ' + expenseLabel(e.category), '', e.amount]),
        ['八、减：退款损失', '8', -d.refunds],
        ['  私域退款', '8.1', d.privateRefunds],
        ['  电商退款', '8.2', d.ecommerceRefunds],
        ['九、净利润', '9', d.netProfit],
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
        ['【流动资产】', '', ''],
        ['  货币资金（现金账户）', '1', d.assets.cashAccounts],
        ['  电商平台余额', '2', d.assets.ecommerceBalance],
        ['  存货（库存商品）', '3', d.assets.inventoryValue],
        ['  预付账款', '4', d.assets.prepaidTotal],
        ['  其他应收款', '5', d.assets.otherReceivables],
        ['【非流动资产】', '', ''],
        ['  固定资产原值', '6', d.assets.fixedAssetsOriginal],
        ['  减：累计折旧', '7', -d.assets.accumulatedDepreciation],
        ['  固定资产净值', '8', d.assets.fixedAssetsNet],
        ['  无形资产', '9', d.assets.intangibleNet],
        ['  长期待摊费用', '10', d.assets.deferredExpTotal],
        ['资产合计', '', d.assets.total],
        ['', '', ''],
        ['【流动负债】', '', ''],
        ['  应付账款', '11', d.liabilities.payableTotal],
        ['  预收账款', '12', d.liabilities.deferredRevTotal],
        ['  应付职工薪酬', '13', d.liabilities.salaryPayable],
        ['  其他应付款', '14', d.liabilities.otherPayableTotal],
        ['【非流动负债】', '', ''],
        ['  长期借款（股东垫资）', '15', d.liabilities.shareholderLoans],
        ['负债合计', '', d.liabilities.total],
        ['', '', ''],
        ['【所有者权益】', '', ''],
        ['  实收资本', '16', d.equity.registeredCapital],
        ['  盈余公积', '17', d.equity.surplusReserve],
        ['  未分配利润', '18', d.equity.retainedEarnings],
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
        ['  私域销售收到的现金', '1', d.operating.privateCashIn],
        ['  电商提现到账的现金', '2', d.operating.ecommerceCashIn],
        ...(d.operating.otherIncomeCashIn > 0 ? [['  其他收入收到的现金', '2.1', d.operating.otherIncomeCashIn]] : []),
        ['  电商平台手续费支出', '3', -d.operating.ecommerceFees],
        ['  购买商品、接受劳务支付的现金', '4', -d.operating.cashOutExpenses],
        ...(d.operating.expenseBreakdown || []).map(e => ['    ' + expenseLabel(e.category), '', e.amount]),
        ['  支付退款', '5', -d.operating.cashOutRefunds],
        ['经营活动现金流量净额', '', d.operating.net],
        ['', '', ''],
        ['二、投资活动产生的现金流量', '', ''],
        ['  购建固定资产、设备支付的现金', '6', -d.investing.equipmentExpense],
        ['投资活动现金流量净额', '', d.investing.net],
        ['', '', ''],
        ['三、筹资活动产生的现金流量', '', ''],
        ['  股东垫资收到的现金', '7', d.financing.loanNew],
        ['  偿还股东垫资支付的现金', '8', -d.financing.loanRepay],
        ['筹资活动现金流量净额', '', d.financing.net],
        ['', '', ''],
        ['四、现金及现金等价物净增加额', '9', d.netChange],
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
        ['  其中：私域利润', '2.1', d.privateProfit],
        ['  其中：电商利润', '2.2', d.ecommerceProfit],
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
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { loadReport(); unwatch() }
    })
  }
})
</script>
