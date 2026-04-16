<template>
  <div class="p-4 md:p-6 space-y-6">
    <!-- 顶部标题 + 操作按钮 -->
    <div class="flex items-center justify-between mb-3">
      <h1 class="text-xl font-bold text-gray-800 truncate">🏪 电商店铺</h1>
      <div class="flex items-center gap-2 shrink-0">
        <input type="date" v-model="selectedDate" class="hidden md:block px-3 py-1.5 border border-gray-200 rounded-lg text-sm" />
        <!-- 移动端更多菜单 -->
        <div class="relative md:hidden">
          <button @click="showMobileMenu = !showMobileMenu" class="px-2.5 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">
            ⋯
          </button>
          <div v-if="showMobileMenu" class="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-lg border border-gray-100 py-1 z-50 min-w-[140px]">
            <div class="px-4 py-2 border-b border-gray-100">
              <input type="date" v-model="selectedDate" class="w-full px-2 py-1.5 border border-gray-200 rounded-lg text-sm" />
            </div>
            <button v-if="canEdit" @click="showAddStore = true; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer">+ 新建店铺</button>
          </div>
        </div>
        <button v-if="canEdit" @click="showAddStore = true" class="bg-blue-600 text-white px-3 py-1.5 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer whitespace-nowrap">+ 新建店铺</button>
      </div>
    </div>
    <!-- 标签栏（可横向滚动） -->
    <div class="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none -mx-1 px-1">
      <button @click="activeTab = 'overview'" :class="tabClass('overview')" class="shrink-0 whitespace-nowrap">数据看板</button>
      <button @click="activeTab = 'stores'" :class="tabClass('stores')" class="shrink-0 whitespace-nowrap">店铺管理</button>
      <button @click="activeTab = 'withdrawals'" :class="tabClass('withdrawals')" class="shrink-0 whitespace-nowrap">提现记录</button>
      <input type="date" v-model="selectedDate" class="md:hidden shrink-0 px-2 py-1 border border-gray-200 rounded-lg text-xs" />
    </div>
    <!-- 移动端菜单遮罩 -->
    <div v-if="showMobileMenu" class="fixed inset-0 z-40 md:hidden" @click="showMobileMenu = false"></div>

    <!-- ==================== 数据看板 ==================== -->
    <div v-if="activeTab === 'overview'">
      <!-- 汇总卡片 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div class="text-xs text-gray-500 mb-1">今日销售额</div>
          <div class="text-lg font-bold text-blue-600">¥{{ formatNum(todayStats.total_sales) }}</div>
          <div class="text-xs text-gray-500">{{ todayStats.total_orders }} 单</div>
        </div>
        <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div class="text-xs text-gray-500 mb-1">今日退款</div>
          <div class="text-lg font-bold text-red-500">¥{{ formatNum(todayStats.total_refund) }}</div>
        </div>
        <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div class="text-xs text-gray-500 mb-1">今日净收入</div>
          <div class="text-lg font-bold text-green-600">¥{{ formatNum(todayStats.total_net) }}</div>
        </div>
        <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
          <div class="text-xs text-gray-500 mb-1">可提现金额</div>
          <div class="text-lg font-bold text-purple-600">¥{{ formatNum(totalWithdrawable) }}</div>
          <div class="text-xs text-gray-500">已过结算周期</div>
        </div>
      </div>

      <!-- 已提现汇总 -->
      <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100 mb-6">
        <div class="flex flex-wrap items-center gap-3">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-gray-700">已提现</span>
            <input type="month" v-model="withdrawnMonth" class="px-2 py-1 border border-gray-200 rounded-lg text-sm" />
          </div>
          <div class="text-xl font-bold text-orange-600">¥{{ formatNum(monthlyWithdrawnTotal) }}</div>
          <div class="text-xs text-gray-500">{{ withdrawnMonth }} 到账合计</div>
        </div>
      </div>

      <!-- 按平台分组展示 -->
      <div v-for="(platformStores, platform) in storesByPlatform" :key="platform" class="mb-4">
        <div class="flex items-center justify-between bg-gray-50 rounded-t-lg px-4 py-2 cursor-pointer" @click="togglePlatform(platform)">
          <span class="font-medium text-sm text-gray-700">
            {{ platformLabel(platform) }}
            <span class="text-xs text-gray-500 ml-1">{{ platformStores.length }}个店铺 · T+{{ platformStores[0]?.settlement_days || 15 }}</span>
          </span>
          <span class="text-sm font-semibold text-gray-600">
            ¥{{ formatNum(platformStores.reduce((s, d) => s + getStoreDaySales(d.id), 0)) }}
          </span>
        </div>
        <div v-show="expandedPlatforms[platform]" class="border border-t-0 border-gray-200 rounded-b-lg overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 text-gray-500 text-xs">
                <th class="px-4 py-2 text-left">店铺</th>
                <th class="px-3 py-2 text-right">订单数</th>
                <th class="px-3 py-2 text-right">销售额</th>
                <th class="px-3 py-2 text-right">退款</th>
                <th class="px-3 py-2 text-right">净收入</th>
                <th class="px-3 py-2 text-right">店铺余额</th>
                <th class="px-3 py-2 text-right">可提现</th>
                <th class="px-3 py-2 text-right">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="store in platformStores" :key="store.id" class="border-t border-gray-100 hover:bg-gray-50">
                <td class="px-4 py-2.5">
                  <div class="font-medium text-gray-800">{{ store.short_name }}</div>
                  <div class="text-xs text-gray-500">{{ store.balance ? '余额 ¥' + formatNum(store.balance) : '' }}</div>
                </td>
                <td class="px-3 py-2.5 text-right">{{ getStoreDayStat(store.id, 'order_count') }}</td>
                <td class="px-3 py-2.5 text-right text-blue-600">{{ formatNum(getStoreDaySales(store.id)) }}</td>
                <td class="px-3 py-2.5 text-right text-red-400">{{ formatNum(getStoreDayStat(store.id, 'refund_amount')) }}</td>
                <td class="px-3 py-2.5 text-right font-medium text-green-600">{{ formatNum(getStoreDayStat(store.id, 'net_income')) }}</td>
                <td class="px-3 py-2.5 text-right text-gray-500">¥{{ formatNum(store.balance) }}</td>
                <td class="px-3 py-2.5 text-right">
                  <span :class="store.withdrawable_amount > 0 ? 'text-purple-600 font-medium' : 'text-gray-500'">
                    ¥{{ formatNum(store.withdrawable_amount) }}
                  </span>
                </td>
                <td class="px-3 py-2.5 text-right">
                  <button @click="openStoreDetail(store)" class="text-green-600 text-xs px-2 py-1 rounded hover:bg-green-50 transition cursor-pointer">明细</button>
                  <button v-if="canEdit" @click="openWithdraw(store)" class="text-blue-600 text-xs px-2 py-1 rounded hover:bg-blue-50 transition cursor-pointer ml-1">提现</button>
                  <button v-if="canEdit" @click="openEditStore(store)" class="text-gray-500 text-xs px-2 py-1 rounded hover:bg-gray-100 transition cursor-pointer ml-1">编辑</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- ==================== 店铺管理 ==================== -->
    <div v-if="activeTab === 'stores'">
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-500 text-xs">
              <th class="px-4 py-3 text-left">店铺名称</th>
              <th class="px-4 py-3 text-left">平台</th>
              <th class="px-4 py-3 text-right">店铺余额</th>
              <th class="px-4 py-3 text-right">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="store in stores" :key="store.id" class="border-t border-gray-100 hover:bg-gray-50">
              <td class="px-4 py-3 font-medium text-gray-800">{{ store.short_name }}</td>
              <td class="px-4 py-3 text-gray-600">{{ platformLabel(store.ecommerce_platform) }}</td>
              <td class="px-4 py-3 text-right font-medium">¥{{ formatNum(store.balance) }}</td>
              <td class="px-4 py-3 text-right">
                <button @click="openStoreDetail(store)" class="text-green-600 text-xs px-2 py-1 rounded hover:bg-green-50 cursor-pointer">明细</button>
                <button v-if="canEdit" @click="openWithdraw(store)" class="text-purple-600 text-xs px-2 py-1 rounded hover:bg-purple-50 cursor-pointer ml-1">提现</button>
                <button v-if="canEdit" @click="openEditStore(store)" class="text-blue-600 text-xs px-2 py-1 rounded hover:bg-blue-50 cursor-pointer ml-1">编辑</button>
              </td>
            </tr>
            <tr v-if="!stores.length" class="text-center text-gray-500 py-8">
              <td colspan="4">暂无电商店铺</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 提现记录 ==================== -->
    <div v-if="activeTab === 'withdrawals'">
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50 text-gray-500 text-xs">
              <th class="px-4 py-3 text-left">时间</th>
              <th class="px-4 py-3 text-left">店铺</th>
              <th class="px-4 py-3 text-right">提现金额</th>
              <th class="px-4 py-3 text-right">手续费</th>
              <th class="px-4 py-3 text-right">实际到账</th>
              <th class="px-4 py-3 text-left">到账账户</th>
              <th class="px-4 py-3 text-left">备注</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="w in withdrawals" :key="w.id" class="border-t border-gray-100 hover:bg-gray-50">
              <td class="px-4 py-3 text-gray-500 text-xs">{{ formatDate(w.withdrawn_at) }}</td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ w.from_store?.short_name || '-' }}</td>
              <td class="px-4 py-3 text-right font-medium">¥{{ formatNum(w.amount) }}</td>
              <td class="px-4 py-3 text-right text-red-400">¥{{ formatNum(calcTotalFee(w.fee_detail)) }}</td>
              <td class="px-4 py-3 text-right font-medium text-green-600">¥{{ formatNum(w.actual_arrival) }}</td>
              <td class="px-4 py-3 text-gray-600 text-xs">{{ w.to_account?.short_name || '-' }}</td>
              <td class="px-4 py-3 text-gray-500 text-xs">{{ w.remark || '' }}</td>
            </tr>
            <tr v-if="!withdrawals.length" class="text-center text-gray-500 py-8">
              <td colspan="7">暂无提现记录</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ==================== 提现弹窗 ==================== -->
    <div v-if="showWithdrawModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-[60] pb-16 md:pb-0" @click.self="showWithdrawModal = false">
      <div class="bg-white rounded-2xl w-full max-w-md mx-4 max-h-[80vh] flex flex-col overflow-hidden">
        <div class="shrink-0 px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="font-bold text-gray-800">💰 提现 — {{ withdrawForm.storeName }}</h2>
          <button @click="showWithdrawModal = false" class="text-gray-500 hover:text-gray-600 cursor-pointer text-xl">&times;</button>
        </div>
        <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
          <!-- 当前店铺余额 -->
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="text-xs text-gray-500">当前店铺余额</div>
            <div class="text-xl font-bold text-green-600">¥{{ formatNum(withdrawForm.storeBalance) }}</div>
            <div class="text-xs text-gray-400 mt-1">提现后店铺余额最低为 ¥0，不会变负</div>
          </div>

          <!-- 提现金额（实际到账金额） -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">提现金额（实际到账）</label>
            <input v-model.number="withdrawForm.amount" type="number" step="0.01" min="0"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
              placeholder="平台实际打款金额" />
          </div>

          <!-- 到账账户 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">到账账户</label>
            <select v-model="withdrawForm.toAccountId" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm">
              <option value="">请选择</option>
              <option v-for="acc in cashAccounts" :key="acc.id" :value="acc.id">{{ acc.short_name }} (余额 ¥{{ formatNum(acc.balance) }})</option>
            </select>
          </div>

          <!-- 手续费 -->
          <div class="bg-orange-50 rounded-lg p-3 space-y-3">
            <div class="text-sm font-medium text-orange-800">💳 平台手续费（选填，将计入支出）</div>
            <div class="flex gap-3">
              <div class="flex-1">
                <label class="block text-xs text-gray-500 mb-1">手续费金额</label>
                <input v-model.number="withdrawForm.feeAmount" type="number" step="0.01" min="0"
                  class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
                  placeholder="0.00" />
              </div>
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">手续费备注</label>
              <input v-model="withdrawForm.feeRemark" type="text"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm"
                placeholder="如：抖音技术服务费、支付手续费" />
            </div>
          </div>

          <!-- 提现预览 -->
          <div v-if="withdrawForm.amount > 0" class="bg-blue-50 rounded-lg p-3 space-y-1.5">
            <div class="text-sm font-medium text-blue-800 mb-1">📋 提现预览</div>
            <div class="flex justify-between text-xs">
              <span class="text-gray-600">{{ withdrawForm.storeName }} 余额</span>
              <span class="text-gray-700">¥{{ formatNum(withdrawForm.storeBalance) }} → ¥{{ formatNum(Math.max(0, withdrawForm.storeBalance - (withdrawForm.amount || 0) - (withdrawForm.feeAmount || 0))) }}</span>
            </div>
            <div class="flex justify-between text-xs">
              <span class="text-gray-600">{{ cashAccounts.find(a => a.id === withdrawForm.toAccountId)?.short_name || '目标账户' }}</span>
              <span class="text-green-600 font-medium">+¥{{ formatNum(withdrawForm.amount) }}（真实收入）</span>
            </div>
            <div v-if="withdrawForm.feeAmount > 0" class="flex justify-between text-xs">
              <span class="text-gray-600">手续费支出</span>
              <span class="text-orange-600">¥{{ formatNum(withdrawForm.feeAmount) }}</span>
            </div>
            <div class="border-t border-blue-200 pt-1.5 flex justify-between text-xs font-medium">
              <span class="text-gray-700">店铺余额扣除合计</span>
              <span class="text-red-500">-¥{{ formatNum((withdrawForm.amount || 0) + (withdrawForm.feeAmount || 0)) }}</span>
            </div>
          </div>

          <!-- 备注 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">提现备注（选填）</label>
            <input v-model="withdrawForm.remark" type="text" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" placeholder="如：4月第1次提现" />
          </div>
        </div>
        <div class="shrink-0 px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="showWithdrawModal = false" class="px-4 py-2 text-gray-600 text-sm rounded-lg hover:bg-gray-100 cursor-pointer">取消</button>
          <button @click="doWithdraw" :disabled="!canSubmitWithdraw" class="px-4 py-2 bg-purple-600 text-white text-sm rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">确认提现</button>
        </div>
      </div>
    </div>

    <!-- ==================== 新建/编辑店铺弹窗 ==================== -->
    <div v-if="showAddStore || showEditStoreModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-[60] pb-16 md:pb-0" @click.self="closeStoreModal">
      <div class="bg-white rounded-2xl w-full max-w-md mx-4 max-h-[85vh] flex flex-col overflow-hidden">
        <div class="shrink-0 px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="font-bold text-gray-800">{{ showEditStoreModal ? '编辑店铺' : '新建店铺' }}</h2>
          <button @click="closeStoreModal" class="text-gray-500 hover:text-gray-600 cursor-pointer text-xl">&times;</button>
        </div>
        <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">店铺名称</label>
            <input v-model="storeForm.name" type="text" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm" placeholder="如：抖店-王孟南台球教学店" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">平台</label>
            <select v-model="storeForm.ecommerce_platform" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm">
              <option value="douyin">抖音</option>
              <option value="kuaishou">快手</option>
              <option value="shipinhao">视频号</option>
              <option value="taobao">淘宝</option>
              <option value="youzan">有赞</option>
              <option value="xiaohongshu">小红书</option>
              <option value="jd">京东</option>
              <option value="weidian">微店</option>
              <option value="other">其他</option>
            </select>
          </div>
          <!-- 负责人代号由后台默认写 '—'，不在此表单暴露 -->

          <!-- 智能记账：提现关键词 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              提现关键词
              <span class="text-xs text-gray-400 font-normal">（智能记账识别该店铺提现，用逗号/空格分隔录入）</span>
            </label>
            <div class="flex items-center gap-2">
              <input
                v-model="newWithdrawKw"
                @keydown.enter.prevent="addWithdrawKeyword"
                type="text"
                class="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm"
                placeholder="如：抖店提现、小店提现"
              />
              <button @click="addWithdrawKeyword" type="button" class="px-3 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm rounded-lg cursor-pointer shrink-0">+ 添加</button>
            </div>
            <div v-if="storeForm.withdraw_keywords && storeForm.withdraw_keywords.length" class="flex flex-wrap gap-1.5 mt-2">
              <span v-for="(kw, i) in storeForm.withdraw_keywords" :key="'wk'+i"
                class="inline-flex items-center gap-1 bg-teal-50 text-teal-700 text-xs px-2 py-1 rounded border border-teal-200">
                {{ kw }}
                <button @click="removeWithdrawKeyword(i)" type="button" class="hover:text-teal-900 cursor-pointer">&times;</button>
              </span>
            </div>
          </div>

          <!-- 默认提现账户 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              默认提现账户
              <span class="text-xs text-gray-400 font-normal">（智能记账时自动预选，留空则第一次提现后自动记住）</span>
            </label>
            <select
              v-model="storeForm.default_withdraw_account_id"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm cursor-pointer bg-white"
            >
              <option value="">不设默认</option>
              <option v-for="a in cashAccounts" :key="a.id" :value="a.id">
                {{ a.short_name || a.code }}
              </option>
            </select>
          </div>
        </div>
        <div class="shrink-0 px-6 py-4 border-t border-gray-100 flex justify-end gap-2">
          <button @click="closeStoreModal" class="px-4 py-2 text-gray-600 text-sm rounded-lg hover:bg-gray-100 cursor-pointer">取消</button>
          <button @click="saveStore" :disabled="!storeForm.name || savingStore" class="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">{{ savingStore ? '保存中...' : (showEditStoreModal ? '保存' : '创建') }}</button>
        </div>
      </div>
    </div>
    <!-- 导入功能已移至「电商订单」页面 -->
    <!-- ==================== 店铺明细弹窗 ==================== -->
    <div v-if="showStoreDetail" class="fixed inset-0 bg-black/40 flex items-center justify-center z-[60] pb-16 md:pb-0" @click.self="showStoreDetail = false">
      <div class="bg-white rounded-2xl w-full max-w-2xl mx-4 max-h-[90vh] flex flex-col overflow-hidden">
        <div class="shrink-0 px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <div>
            <h2 class="font-bold text-gray-800">📋 {{ storeDetail.storeName }} 明细</h2>
            <div class="text-xs text-gray-500 mt-0.5">当前余额：<span class="font-medium" :class="storeDetail.balance >= 0 ? 'text-green-600' : 'text-red-500'">¥{{ formatNum(storeDetail.balance) }}</span></div>
          </div>
          <button @click="showStoreDetail = false" class="text-gray-500 hover:text-gray-600 cursor-pointer text-xl">&times;</button>
        </div>

        <!-- 标题说明 -->
        <div class="shrink-0 px-6 pt-3">
          <span class="px-3 py-1 rounded-lg text-xs bg-purple-100 text-purple-700 font-medium">提现明细</span>
        </div>

        <!-- 明细列表 -->
        <div class="flex-1 overflow-y-auto px-6 py-3">
          <div v-if="storeDetail.loading" class="text-center text-gray-400 py-8">加载中...</div>
          <div v-else-if="storeDetail.records.length === 0" class="text-center text-gray-400 py-8">暂无提现记录</div>
          <div v-else class="space-y-2">
            <div v-for="(record, idx) in storeDetail.records" :key="idx"
              class="flex items-center justify-between p-3 rounded-lg border border-gray-100 hover:bg-gray-50">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="px-1.5 py-0.5 rounded text-[10px] font-medium"
                    :class="{
                      'bg-purple-50 text-purple-600': record.type === 'withdrawal',
                      'bg-orange-50 text-orange-600': record.type === 'fee',
                    }">{{ {withdrawal:'提现',fee:'手续费'}[record.type] || '提现' }}</span>
                  <span class="text-xs text-gray-500">{{ record.time }}</span>
                </div>
                <div class="text-sm text-gray-800 mt-1 truncate">{{ record.desc }}</div>
                <div v-if="record.sub" class="text-xs text-gray-400 mt-0.5 truncate">{{ record.sub }}</div>
              </div>
              <div class="text-right ml-3 shrink-0">
                <div class="font-medium text-sm" :class="record.amount >= 0 ? 'text-green-600' : 'text-red-500'">
                  {{ record.amount >= 0 ? '+' : '' }}¥{{ formatNum(Math.abs(record.amount)) }}
                </div>
                <div v-if="record.balanceAfter != null" class="text-[10px] text-gray-400">余额 ¥{{ formatNum(record.balanceAfter) }}</div>
              </div>
            </div>
          </div>
        </div>

        <div class="shrink-0 px-6 py-3 border-t border-gray-100 flex justify-between items-center">
          <div class="text-xs text-gray-500">共 {{ storeDetail.records.length }} 条记录</div>
          <button @click="showStoreDetail = false" class="px-4 py-2 text-gray-600 text-sm rounded-lg hover:bg-gray-100 cursor-pointer">关闭</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import * as XLSX from 'xlsx'
import { supabase } from '../lib/supabase'
import { parseEcommerceExcel, importEcommerceOrders } from '../lib/ecommerceOrderImporter'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { PLATFORM_FEE_RATES, PLATFORM_LABELS, calcWithdrawFees } from '../lib/platformFees'
import { performStoreWithdrawal } from '../lib/storeWithdrawal'

const auth = useAuthStore()
const accountStore = useAccountStore()
const role = computed(() => auth.profile?.role || '')
const canEdit = computed(() => ['admin', 'finance', 'manager'].includes(role.value))

// 状态
const activeTab = ref('overview')
const showMobileMenu = ref(false)
const selectedDate = ref(new Date().toISOString().split('T')[0])
const stores = ref([])
const dailyStats = ref([])
const withdrawals = ref([])
const cashAccounts = ref([])
const expandedPlatforms = ref({ douyin: true, kuaishou: true, shipinhao: true })
const loading = ref(false)

// 已提现月度汇总
const withdrawnMonth = ref(new Date().toISOString().substring(0, 7)) // '2026-04'
const monthlyWithdrawnData = ref([])
const monthlyWithdrawnTotal = computed(() => monthlyWithdrawnData.value.reduce((s, w) => s + Number(w.actual_arrival || 0), 0))

// 提现弹窗
const showWithdrawModal = ref(false)
const withdrawForm = ref({ storeId: '', storeName: '', platform: '', withdrawableAmount: 0, amount: null, toAccountId: '', remark: '' })

// 店铺明细弹窗
const showStoreDetail = ref(false)
const storeDetail = ref({ storeId: '', storeName: '', balance: 0, tab: 'all', loading: false, records: [] })


// 店铺弹窗
const showAddStore = ref(false)
const showEditStoreModal = ref(false)
const editingStoreId = ref(null)
const savingStore = ref(false)
const storeForm = ref({
  name: '',
  ecommerce_platform: 'douyin',
  settlement_days: 15,
  withdrawal_account_id: '',
  withdraw_keywords: [],          // 店铺提现关键词（JSONB 数组，智能记账自动匹配用）
  default_withdraw_account_id: '',// 默认提现到账账户
})
const newWithdrawKw = ref('')

// 计算属性
const storesByPlatform = computed(() => {
  const groups = {}
  stores.value.forEach(s => {
    const key = s.ecommerce_platform || 'other'
    if (!groups[key]) groups[key] = []
    groups[key].push(s)
  })
  return groups
})

const todayStats = computed(() => {
  const date = selectedDate.value
  const dayStats = dailyStats.value.filter(d => d.order_date === date)
  return {
    total_orders: dayStats.reduce((sum, d) => sum + Number(d.order_count || 0), 0),
    total_sales: dayStats.reduce((sum, d) => sum + Number(d.sales_amount || 0), 0),
    total_refund: dayStats.reduce((sum, d) => sum + Number(d.refund_amount || 0), 0),
    total_net: dayStats.reduce((sum, d) => sum + Number(d.net_income || 0), 0),
  }
})

const totalWithdrawable = computed(() => stores.value.reduce((sum, s) => sum + Number(s.withdrawable_amount || 0), 0))

const withdrawFeeRates = computed(() => {
  const p = withdrawForm.value.platform
  return PLATFORM_FEE_RATES[p] || { technical: 0, payment: 0, withdraw: 0 }
})

const withdrawFees = computed(() => {
  return calcWithdrawFees(withdrawForm.value.amount || 0, withdrawForm.value.platform)
})

const canSubmitWithdraw = computed(() => {
  return withdrawForm.value.amount > 0 && withdrawForm.value.toAccountId
})

// 方法
function tabClass(tab) {
  return activeTab.value === tab
    ? 'px-3 py-1.5 rounded-lg text-sm font-medium bg-blue-600 text-white cursor-pointer'
    : 'px-3 py-1.5 rounded-lg text-sm text-gray-600 hover:bg-gray-100 cursor-pointer'
}

function platformLabel(key) {
  return PLATFORM_LABELS[key] || key || '未知'
}

function formatNum(n) {
  return Number(n || 0).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function formatDate(d) {
  if (!d) return '-'
  return new Date(d).toLocaleString('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function togglePlatform(key) {
  expandedPlatforms.value[key] = !expandedPlatforms.value[key]
}

function getStoreDayStat(accountId, field) {
  const stat = dailyStats.value.find(d => d.account_id === accountId && d.order_date === selectedDate.value)
  return stat ? Number(stat[field] || 0) : 0
}

function getStoreDaySales(accountId) {
  return getStoreDayStat(accountId, 'sales_amount')
}

function calcTotalFee(feeDetail) {
  if (!feeDetail) return 0
  if (Array.isArray(feeDetail)) {
    return feeDetail.reduce((s, f) => s + Number(f.amount || 0), 0)
  }
  return Number(feeDetail.technical_fee || 0) + Number(feeDetail.payment_fee || 0) + Number(feeDetail.withdraw_fee || 0) + Number(feeDetail.other_fee || 0)
}

function getWithdrawalAccountName(id) {
  if (!id) return '未绑定'
  const acc = cashAccounts.value.find(a => a.id === id)
  return acc ? acc.short_name : '未找到'
}

function autoCalcWithdrawFees() {
  // 费用自动计算在 computed 里已处理
}

// 提现
function openWithdraw(store) {
  withdrawForm.value = {
    storeId: store.id,
    storeName: store.short_name,
    platform: store.ecommerce_platform,
    storeBalance: Number(store.balance || 0),
    amount: null,
    toAccountId: '',
    feeAmount: null,
    feeRemark: '',
    remark: '',
  }
  showWithdrawModal.value = true
}

// 店铺明细
async function openStoreDetail(store) {
  showStoreDetail.value = true
  storeDetail.value = {
    storeId: store.id,
    storeName: store.short_name,
    balance: Number(store.balance || 0),
    loading: true,
    records: [],
  }

  try {
    const records = []

    // 查提现相关的操作日志
    const { data: logs } = await supabase
      .from('operation_logs')
      .select('id, action, description, amount, balance_before, balance_after, created_at')
      .eq('account_id', store.id)
      .like('action', '%withdrawal%')
      .order('created_at', { ascending: false })
      .limit(200)

    for (const l of (logs || [])) {
      records.push({
        type: 'withdrawal',
        time: formatDate(l.created_at),
        desc: l.description || '提现',
        sub: null,
        amount: Number(l.amount || 0),
        balanceAfter: l.balance_after,
        sortTime: l.created_at,
      })
    }

    // 同时查 expenses 中该店铺的手续费记录
    const { data: fees } = await supabase
      .from('expenses')
      .select('id, amount, note, payee, created_at')
      .eq('category', '电商手续费')
      .eq('payee', store.short_name)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(200)

    for (const f of (fees || [])) {
      records.push({
        type: 'fee',
        time: formatDate(f.created_at),
        desc: f.note || '平台手续费',
        sub: null,
        amount: -Number(f.amount || 0),
        balanceAfter: null,
        sortTime: f.created_at,
      })
    }

    // 按时间倒序排列
    records.sort((a, b) => (b.sortTime || '').localeCompare(a.sortTime || ''))
    storeDetail.value.records = records
  } catch (e) {
    console.error('加载店铺明细失败:', e)
  } finally {
    storeDetail.value.loading = false
  }
}

async function doWithdraw() {
  const f = withdrawForm.value
  if (!f.amount || f.amount <= 0 || !f.toAccountId) return

  const feeAmount = Number(f.feeAmount || 0)
  const targetName = cashAccounts.value.find(a => a.id === f.toAccountId)?.short_name || ''

  try {
    const result = await performStoreWithdrawal({
      storeId: f.storeId,
      storeName: f.storeName,
      toAccountId: f.toAccountId,
      toAccountName: targetName,
      amount: f.amount,
      feeAmount,
      feeRemark: f.feeRemark,
      remark: f.remark,
    })

    // 同步 Pinia：这次如果自动写了默认提现账户，本地也更新
    if (result?.defaultTargetSaved) {
      const idx = accountStore.accounts.findIndex(a => a.id === f.storeId)
      if (idx >= 0) accountStore.accounts[idx].default_withdraw_account_id = f.toAccountId
    }

    showWithdrawModal.value = false
    const feeMsg = feeAmount > 0 ? `（手续费 ¥${feeAmount.toFixed(2)} 已计入支出）` : ''
    const defMsg = result?.defaultTargetSaved ? `，已记为 ${f.storeName} 的默认提现账户` : ''
    toast(`提现成功！¥${f.amount.toFixed(2)} 已转入 ${targetName}${feeMsg}${defMsg}`, 'success')
    await loadData()
    await loadMonthlyWithdrawn()
  } catch (e) {
    toast('提现失败：' + (e.message || ''), 'error')
  }
}

// 店铺管理
function openEditStore(store) {
  editingStoreId.value = store.id
  // 编辑时 short_name 在 accounts.short_name；提现关键词/默认账户直接从 accountStore 取最新值
  const acc = accountStore.accounts.find(a => a.id === store.id) || store
  storeForm.value = {
    name: store.short_name,
    ecommerce_platform: store.ecommerce_platform,
    withdraw_keywords: Array.isArray(acc.withdraw_keywords) ? [...acc.withdraw_keywords] : [],
    default_withdraw_account_id: acc.default_withdraw_account_id || '',
  }
  newWithdrawKw.value = ''
  showEditStoreModal.value = true
}

function closeStoreModal() {
  showAddStore.value = false
  showEditStoreModal.value = false
  editingStoreId.value = null
  storeForm.value = {
    name: '',
    ecommerce_platform: 'douyin',
    withdraw_keywords: [],
    default_withdraw_account_id: '',
  }
  newWithdrawKw.value = ''
}

function addWithdrawKeyword() {
  const kw = (newWithdrawKw.value || '').trim()
  if (!kw) return
  const list = storeForm.value.withdraw_keywords || []
  if (list.some(k => (k || '').toLowerCase() === kw.toLowerCase())) {
    toast(`关键词「${kw}」已存在`, 'warning')
    return
  }
  list.push(kw)
  storeForm.value.withdraw_keywords = list
  newWithdrawKw.value = ''
}

function removeWithdrawKeyword(i) {
  storeForm.value.withdraw_keywords.splice(i, 1)
}

// ecommerce_platform（UI 9 选）→ platform（DB CHECK 7 选）映射
// DB 约束只允许: alipay / bank / douyin / kuaishou / weixin_video / youzan / other
function mapPlatform(ecom) {
  switch (ecom) {
    case 'douyin':       return 'douyin'
    case 'kuaishou':     return 'kuaishou'
    case 'shipinhao':    return 'weixin_video'
    case 'youzan':       return 'youzan'
    // taobao / xiaohongshu / jd / weidian / other 统一归到 other
    default:             return 'other'
  }
}

async function saveStore() {
  const f = storeForm.value
  if (!f.name) return
  if (savingStore.value) return // 防止双击重复提交
  savingStore.value = true

  const platform = mapPlatform(f.ecommerce_platform)
  // 电商店铺默认 owner_code = '—'，用户表单不暴露此字段
  const ownerCode = '—'

  try {
    if (showEditStore.value) {
      // 编辑：走 Pinia store，保证本页本地列表 + 全局 accountStore 同步更新
      await accountStore.updateAccount(editingStoreId.value, {
        short_name: f.name,
        ecommerce_platform: f.ecommerce_platform,
        platform,
        withdraw_keywords: f.withdraw_keywords || [],
        default_withdraw_account_id: f.default_withdraw_account_id || null,
      })
      toast('店铺已更新', 'success')
    } else {
      // 新建：先查是否已有同名活跃店铺，避免双击/并发重复
      const { data: dup, error: dupErr } = await supabase
        .from('accounts')
        .select('id')
        .eq('short_name', f.name)
        .eq('category', 'ecommerce')
        .eq('status', 'active')
        .maybeSingle()
      if (dupErr) throw dupErr
      if (dup) {
        toast(`已存在同名店铺「${f.name}」，请勿重复创建`, 'warning')
        return
      }

      // 走 Pinia accountStore.createAccount：插入后立刻 push 进共享账户数组，
      // 其他已挂载的视图（如智能记账的"店铺提现"）能即时看到新店铺
      await accountStore.createAccount({
        short_name: f.name,
        code: f.name,
        owner_code: ownerCode,
        platform,
        ecommerce_platform: f.ecommerce_platform,
        category: 'ecommerce',
        balance: 0,
        opening_balance: 0,
        status: 'active',
        withdraw_keywords: f.withdraw_keywords || [],
        default_withdraw_account_id: f.default_withdraw_account_id || null,
      })
      toast('店铺已创建', 'success')
    }
    closeStoreModal()
    await loadData()
  } catch (e) {
    toast('保存失败：' + (e.message || ''), 'error')
  } finally {
    savingStore.value = false
  }
}

const showEditStore = computed(() => !!editingStoreId.value)

// Import modal state
const showImportModal = ref(false)
const importPlatform = ref('auto')
const importFileName = ref('')
const importParsed = ref(null)
const importSalesCount = ref(0)
const importAfterSalesCount = ref(0)
const importEffectiveCount = ref(0)
const importSkipped = ref(0)
const importing = ref(false)
const importProgress = ref(null)
const importResult = ref(null)

const importPlatformOptions = [
  { key: 'auto', label: '自动识别(根据Sheet名称)' },
  { key: 'douyin', label: '抖音' },
  { key: 'kuaishou', label: '快手' },
  { key: 'shipinhao', label: '视频号' },
]

function handleImportDrop(e) {
  const file = e.dataTransfer?.files?.[0]
  if (file) processImportFile(file)
}

function handleImportFile(e) {
  const file = e.target?.files?.[0]
  if (file) processImportFile(file)
}

async function processImportFile(file) {
  importFileName.value = file.name
  importResult.value = null
  importProgress.value = null

  try {
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data, { type: 'array' })

    const options = {
      autoDetect: importPlatform.value === 'auto',
      forcePlatform: importPlatform.value === 'auto' ? null : importPlatform.value,
    }

    const parsed = parseEcommerceExcel(workbook, options)
    importParsed.value = parsed
    importSalesCount.value = parsed.salesOrders.length
    importAfterSalesCount.value = parsed.afterSalesOrders.length
    importSkipped.value = parsed.skipped

    // Calculate effective count (sales not matched by after-sales)
    const afterSalesOrderNos = new Set(parsed.afterSalesOrders.map(a => a.external_order_no))
    const effectiveOrders = parsed.salesOrders.filter(s => !afterSalesOrderNos.has(s.external_order_no))
    importEffectiveCount.value = effectiveOrders.length
  } catch (e) {
    toast('文件解析失败: ' + e.message, 'error')
  }
}

async function doImport() {
  if (!importParsed.value) return
  importing.value = true
  importProgress.value = { message: '准备导入...', percent: 0 }

  try {
    const result = await importEcommerceOrders({
      salesOrders: importParsed.value.salesOrders,
      afterSalesOrders: importParsed.value.afterSalesOrders,
      supabase,
      onProgress: (p) => {
        const total = (importParsed.value.salesOrders.length || 1) + (importParsed.value.afterSalesOrders.length || 0)
        const current = p.type === 'aftersales'
          ? (importParsed.value.salesOrders.length + p.current)
          : p.current
        importProgress.value = {
          message: p.type === 'sales' ? `导入销售订单 ${p.current}/${p.total}` : `处理售后 ${p.current}/${p.total}`,
          percent: Math.round((current / total) * 100),
        }
      },
    })
    importResult.value = result
    importProgress.value = null
    // Reload data
    await loadData()
  } catch (e) {
    toast('导入失败: ' + e.message, 'error')
  } finally {
    importing.value = false
  }
}

function closeImport() {
  showImportModal.value = false
  importParsed.value = null
  importResult.value = null
  importProgress.value = null
  importFileName.value = ''
}

// Toast
import { useToast } from '../composables/useToast'
const { toast: _globalToast } = useToast()
function toast(msg, type = 'success') {
  _globalToast(msg, type, 3000)
}

// 按日期聚合电商订单统计
async function fetchDailyStats(date) {
  const startOfDay = date + 'T00:00:00+08:00'
  const endOfDay = date + 'T23:59:59+08:00'

  // Get ecommerce orders for that day
  const { data: orders } = await supabase
    .from('orders')
    .select('id, account_id, platform_type, platform_store, payment_amount, status, created_at')
    .not('platform_type', 'is', null)
    .gte('created_at', startOfDay)
    .lte('created_at', endOfDay)

  // Get refunds for those orders
  const orderIds = (orders || []).map(o => o.id)
  let refundMap = {}
  if (orderIds.length > 0) {
    // Batch fetch refunds
    const BATCH = 200
    for (let i = 0; i < orderIds.length; i += BATCH) {
      const chunk = orderIds.slice(i, i + BATCH)
      const { data: refunds } = await supabase
        .from('refunds')
        .select('order_id, refund_amount')
        .in('order_id', chunk)
        .eq('status', 'completed')
      for (const r of (refunds || [])) {
        refundMap[r.order_id] = (refundMap[r.order_id] || 0) + Number(r.refund_amount)
      }
    }
  }

  // Aggregate by account_id
  const statsMap = {}
  for (const o of (orders || [])) {
    const key = o.account_id || 'unknown'
    if (!statsMap[key]) {
      statsMap[key] = {
        order_date: date,
        account_id: o.account_id,
        store_name: o.platform_store || '未知店铺',
        ecommerce_platform: o.platform_type,
        order_count: 0,
        sales_amount: 0,
        refund_amount: 0,
        net_income: 0,
      }
    }
    statsMap[key].order_count++
    statsMap[key].sales_amount += Number(o.payment_amount || 0)
    const refAmt = refundMap[o.id] || 0
    statsMap[key].refund_amount += refAmt
  }

  // Calculate net
  for (const s of Object.values(statsMap)) {
    s.net_income = s.sales_amount - s.refund_amount
  }

  return Object.values(statsMap)
}

// 加载数据
async function loadData() {
  loading.value = true
  try {
    // 并行加载
    const [storesRes, statsRes, cashRes] = await Promise.allSettled([
      // 电商店铺
      supabase
        .from('accounts')
        .select('id, short_name, platform, ecommerce_platform, balance, status')
        .eq('status', 'active')
        .not('ecommerce_platform', 'is', null)
        .order('ecommerce_platform'),
      // 日统计（直接查 orders 表聚合）
      fetchDailyStats(selectedDate.value).catch(e => { console.warn('fetchDailyStats failed:', e); return [] }),
      // 现金账户
      supabase
        .from('accounts')
        .select('id, short_name, platform, balance')
        .is('ecommerce_platform', null)
        .eq('status', 'active')
        .order('short_name'),
    ])

    const storesData = storesRes.status === 'fulfilled' ? (storesRes.value?.data || []) : []
    const statsData = statsRes.status === 'fulfilled' ? (statsRes.value || []) : []
    const cashData = cashRes.status === 'fulfilled' ? (cashRes.value?.data || []) : []

    console.log('[Ecommerce] loadData results:', { stores: storesData.length, stats: statsData.length, cash: cashData.length })

    cashAccounts.value = cashData

    // 加载提现记录（从 operation_logs）
    try {
      const { data: wLogs } = await supabase
        .from('operation_logs')
        .select('id, action, description, amount, account_id, account_name, balance_before, balance_after, detail, created_at')
        .eq('action', 'ecommerce_withdrawal')
        .order('created_at', { ascending: false })
        .limit(200)
      withdrawals.value = (wLogs || []).map(l => ({
        id: l.id,
        withdrawn_at: l.created_at,
        from_store: { short_name: l.account_name || '—' },
        amount: Math.abs(Number(l.amount || 0)),
        fee_detail: l.detail?.feeAmount ? [{ amount: l.detail.feeAmount, label: l.detail.feeRemark || '手续费' }] : [],
        actual_arrival: Number(l.detail?.withdrawAmount || 0),
        to_account: { short_name: l.detail?.toAccount || '—' },
        remark: l.detail?.remark || '',
      }))
    } catch (_) {
      withdrawals.value = []
    }

    // 加载店铺列表
    stores.value = storesData.map(store => ({
      ...store,
      settlement_days: 15,
      withdrawable_amount: Math.max(0, Number(store.balance || 0)),
    }))
    dailyStats.value = statsData

    // 加载月度已提现
    await loadMonthlyWithdrawn()
  } catch (e) {
    console.error('加载电商数据失败:', e)
  } finally {
    loading.value = false
  }
}

// 加载月度已提现数据
async function loadMonthlyWithdrawn() {
  try {
    const ym = withdrawnMonth.value // '2026-04'
    const startISO = `${ym}-01T00:00:00`
    // 计算月末
    const [y, m] = ym.split('-').map(Number)
    const endDate = new Date(y, m, 0) // 月末日期
    const endISO = `${ym}-${String(endDate.getDate()).padStart(2, '0')}T23:59:59`
    const { data, error } = await supabase
      .from('withdrawals')
      .select('actual_arrival, amount, store_name, created_at')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO)
    if (error) {
      console.warn('月度提现查询失败:', error.message)
      monthlyWithdrawnData.value = []
    } else {
      monthlyWithdrawnData.value = data || []
    }
  } catch (e) {
    console.warn('月度提现查询异常:', e.message)
    monthlyWithdrawnData.value = []
  }
}

// 监听日期变化
watch(selectedDate, async () => {
  dailyStats.value = await fetchDailyStats(selectedDate.value)
})

// 监听提现月份变化
watch(withdrawnMonth, () => {
  loadMonthlyWithdrawn()
})

onMounted(() => {
  if (auth.isLoggedIn) {
    loadData()
  } else {
    const unwatch = watch(() => auth.isLoggedIn, (val) => {
      if (val) { loadData(); unwatch() }
    })
  }
})
</script>
