<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6 flex-wrap gap-3">
      <h1 class="text-xl font-bold text-gray-800">🏦 账户管理</h1>
      <div class="flex items-center gap-2">
        <button v-if="canManage" @click="openSortModal" class="px-3 py-2 bg-white text-gray-500 rounded-lg text-sm border border-gray-200 hover:bg-gray-50 transition cursor-pointer">🔀 排序</button>
        <button
          v-if="authStore.isFinance"
          @click="showBatchOpeningModal = true"
          class="px-3 py-2 bg-white text-amber-600 rounded-lg text-sm border border-amber-200 hover:bg-amber-50 transition cursor-pointer"
          title="批量重设所有账户的期初余额"
        >🔢 批量期初</button>
        <button
          v-if="canManage"
          @click="openModal()"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
        >
          ➕ 添加账户
        </button>
      </div>
    </div>

    <!-- 今日余额变动 -->
    <div v-if="todayTransferData.loaded" class="bg-white rounded-xl p-3 mb-4 border border-gray-100 flex items-center gap-3">
      <div class="w-1 h-8 rounded-full bg-blue-400"></div>
      <div class="text-sm">
        <span class="text-gray-500">今日转账</span>
        <span v-if="todayTransferData.count > 0" class="ml-2 font-semibold text-gray-800">{{ todayTransferData.count }} 笔</span>
        <span v-if="todayTransferData.count > 0" class="ml-2 text-blue-500">{{ '¥' + todayTransferData.total.toFixed(2) }}</span>
        <span v-else class="ml-2 text-gray-300">无</span>
      </div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 gap-4 mb-5">
      <div @click="filters.category = 'personal'"
        :class="filters.category === 'personal' ? 'border-blue-300 ring-2 ring-blue-100' : 'border-gray-100'"
        class="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-sm transition">
        <div class="text-xs text-gray-500 mb-1">👤 个人账户</div>
        <div class="text-2xl font-bold" :class="personalTotal >= 0 ? 'text-green-600' : 'text-red-500'">{{ formatMoney(personalTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">{{ personalCount }} 个账户</div>
      </div>
      <div @click="filters.category = 'company'"
        :class="filters.category === 'company' ? 'border-blue-300 ring-2 ring-blue-100' : 'border-gray-100'"
        class="bg-white rounded-xl border p-4 cursor-pointer hover:shadow-sm transition">
        <div class="text-xs text-gray-500 mb-1">🏢 企业账户</div>
        <div class="text-2xl font-bold" :class="companyTotal >= 0 ? 'text-green-600' : 'text-red-500'">{{ formatMoney(companyTotal) }}</div>
        <div class="text-xs text-gray-500 mt-1">{{ companyCount }} 个账户</div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-2 mb-4">
      <button
        @click="activeTab = 'active'"
        :class="activeTab === 'active' ? 'bg-green-50 text-green-700 border-green-300 font-medium' : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'"
        class="px-4 py-2 rounded-lg text-sm border transition cursor-pointer"
      >✅ 活跃账户</button>
      <button
        @click="activeTab = 'frozen'"
        :class="activeTab === 'frozen' ? 'bg-gray-100 text-gray-700 border-gray-400 font-medium' : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'"
        class="px-4 py-2 rounded-lg text-sm border transition cursor-pointer"
      >🔒 已停用账户</button>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input
        v-model="filters.keyword"
        placeholder="🔍 搜索账户简称..."
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-full sm:w-56 outline-none focus:ring-2 focus:ring-blue-500"
      >
      <select
        v-model="filters.platform"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">全部平台</option>
        <option v-for="(label, key) in PLATFORM_LABELS" :key="key" :value="key">{{ platformIcon(key) }} {{ label }}</option>
      </select>
      <select
        v-model="filters.category"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">全部分类</option>
        <option value="personal">👤 个人账户</option>
        <option value="company">🏢 企业账户</option>
      </select>
      <button
        @click="filters.hideZeroBalance = !filters.hideZeroBalance"
        :class="filters.hideZeroBalance ? 'bg-orange-100 text-orange-700 border-orange-300' : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'"
        class="px-3 py-2 border rounded-lg text-sm cursor-pointer transition"
      >
        {{ filters.hideZeroBalance ? '💰 显示零余额' : '💵 隐藏零余额' }}
      </button>
      <!-- Batch actions -->
      <template v-if="selectedIds.length > 0">
        <span class="text-sm text-blue-600 font-medium">已选 {{ selectedIds.length }} 项</span>
        <button @click="batchAction('freeze')" class="px-3 py-2 bg-orange-50 text-orange-600 border border-orange-200 rounded-lg text-sm cursor-pointer transition hover:bg-orange-100">🔒 批量停用</button>
        <button @click="batchAction('activate')" class="px-3 py-2 bg-green-50 text-green-600 border border-green-200 rounded-lg text-sm cursor-pointer transition hover:bg-green-100">🔓 批量启用</button>
        <button v-if="canDelete" @click="batchAction('delete')" class="px-3 py-2 bg-red-50 text-red-600 border border-red-200 rounded-lg text-sm cursor-pointer transition hover:bg-red-100">🗑️ 批量删除</button>
        <button @click="selectedIds = []" class="px-3 py-2 text-gray-500 border border-gray-200 rounded-lg text-sm cursor-pointer transition hover:bg-gray-50">✕ 取消</button>
      </template>
      <span class="text-sm text-gray-500 ml-auto">
        共 {{ filteredAccounts.length }} 个账户
      </span>
    </div>

    <!-- Loading -->
    <Skeleton v-if="loading" type="card" :count="6" card-grid-class="grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6" />

    <!-- Account List View -->
    <div v-if="!loading" class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50 border-b border-gray-100">
          <tr>
            <th class="px-4 py-3 text-left w-8">
              <input
                type="checkbox"
                :checked="selectedIds.length === filteredAccounts.length && filteredAccounts.length > 0"
                @change="selectedIds = $event.target.checked ? filteredAccounts.map(a => a.id) : []"
                class="rounded cursor-pointer"
              >
            </th>
            <th class="px-3 py-3 text-left text-gray-500 font-medium text-sm">简称</th>
            <th class="px-3 py-3 text-left text-gray-500 font-medium text-sm hidden md:table-cell">平台</th>
            <th class="px-3 py-3 text-right text-gray-500 font-medium text-sm">余额</th>
            <th class="px-3 py-3 text-center text-gray-500 font-medium text-sm hidden sm:table-cell">状态</th>
            <th class="px-3 py-3 text-left text-gray-500 font-medium text-sm hidden lg:table-cell">关键词</th>
            <th class="px-3 py-3 text-center text-gray-500 font-medium text-sm hidden md:table-cell">信息</th>
            <th class="px-3 py-3 text-right text-gray-500 font-medium text-sm">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="acc in filteredAccounts"
            :key="acc.id"
            class="border-b border-gray-50 hover:bg-gray-50/60 transition cursor-pointer"
            @click="openModal(acc)"
          >
            <td class="px-4 py-3" @click.stop>
              <input
                type="checkbox"
                :checked="selectedIds.includes(acc.id)"
                @change="toggleSelect(acc.id)"
                class="rounded cursor-pointer"
              >
            </td>
            <td class="px-3 py-2.5 font-medium text-gray-800 text-sm">{{ acc.short_name || acc.code }}</td>
            <td class="px-3 py-2.5 text-sm hidden md:table-cell">{{ platformIcon(acc.platform) }} {{ platformLabel(acc.platform) }}</td>
            <td class="px-3 py-2.5 text-right font-bold text-sm" :class="acc.balance >= 0 ? 'text-green-600' : 'text-red-500'">{{ formatMoney(acc.balance) }}</td>
            <td class="px-3 py-2.5 text-center hidden sm:table-cell">
              <span class="text-xs px-2 py-0.5 rounded-full" :class="acc.status === 'active' ? 'bg-green-50 text-green-600' : 'bg-gray-100 text-gray-500'">
                {{ acc.status === 'active' ? '活跃' : '停用' }}
              </span>
            </td>
            <td class="px-3 py-2.5 hidden lg:table-cell">
              <div class="flex flex-wrap gap-0.5">
                <span v-for="kw in (acc.expense_keywords || [])" :key="'e'+kw" class="text-[10px] px-1.5 py-0.5 bg-red-50 text-red-600 rounded">{{ kw }}</span>
                <span v-for="kw in (acc.income_keywords || [])" :key="'i'+kw" class="text-[10px] px-1.5 py-0.5 bg-green-50 text-green-600 rounded">{{ kw }}</span>
                <span v-for="rule in (acc.transfer_rules || [])" :key="'t'+rule.keyword" class="text-[10px] px-1.5 py-0.5 bg-blue-50 text-blue-600 rounded">{{ rule.keyword }}</span>
                <span v-if="!acc.expense_keywords?.length && !acc.income_keywords?.length && !acc.transfer_rules?.length" class="text-[10px] text-gray-300">未设置</span>
              </div>
            </td>
            <td class="px-3 py-2.5 text-center hidden md:table-cell">
              <span v-if="isIncomplete(acc)" class="inline-block w-2 h-2 bg-red-500 rounded-full" title="信息不完整"></span>
              <span v-else class="inline-block w-2 h-2 bg-green-400 rounded-full" title="信息完整"></span>
            </td>
            <td class="px-3 py-2.5 text-right whitespace-nowrap" @click.stop>
              <button @click="openModal(acc)" class="text-blue-500 hover:text-blue-700 text-xs cursor-pointer" title="详情">详情</button>
              <button @click="viewTransactions(acc)" class="text-gray-500 hover:text-purple-500 cursor-pointer text-xs ml-1" title="交易明细">📊</button>
              <button
                v-if="authStore.isFinance"
                @click="openOpeningBalanceModal(acc)"
                class="text-gray-400 hover:text-blue-600 cursor-pointer text-xs ml-1"
                title="重设期初余额（新财年/数据清空后校准）"
              >📌 期初</button>
              <button @click="toggleFreeze(acc)" class="text-gray-500 hover:text-orange-500 cursor-pointer text-xs ml-1">{{ acc.status === 'active' ? '🔒' : '🔓' }}</button>
              <button v-if="canDelete" @click="handleDelete(acc)" class="text-gray-500 hover:text-red-500 cursor-pointer text-xs ml-1">🗑️</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Empty State -->
    <div
      v-if="filteredAccounts.length === 0 && !loading"
      class="bg-white rounded-xl border border-gray-100 p-12 text-center"
    >
      <div class="text-4xl mb-4">📭</div>
      <div class="text-gray-500">暂无匹配的账户</div>
      <div class="text-sm text-gray-500 mt-1">尝试调整筛选条件</div>
    </div>

    <!-- Add/Edit Modal -->
    <Teleport to="body">
      <div
        v-if="showModal"
        class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4"
        @click.self="closeModal"
      >
        <div class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
          <!-- Modal Header -->
          <div class="flex items-center justify-between p-5 border-b border-gray-100">
            <h2 class="text-lg font-bold text-gray-800">
              {{ isEditing ? '✏️ 编辑账户' : '➕ 添加账户' }}
            </h2>
            <button @click="closeModal" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
          </div>

          <!-- Modal Body -->
          <div class="p-5 space-y-4">
            <!-- Platform Select -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">收款平台 <span class="text-red-400">*</span></label>
              <select
                v-model="form.platform"
                @change="autoCategory"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">请选择平台</option>
                <option v-for="(label, key) in PLATFORM_LABELS" :key="key" :value="key">
                  {{ platformIcon(key) }} {{ label }}
                </option>
              </select>
            </div>

            <!-- Category Select -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">账户分类</label>
              <select
                v-model="form.category"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="company">🏢 企业账户</option>
                <option value="personal">👤 个人账户</option>
              </select>
              <p class="text-xs text-gray-500 mt-1">选择平台后会自动推荐分类，你也可以手动调整</p>
            </div>

            <!-- Short Name -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">账户简称 <span class="text-red-400">*</span></label>
              <input
                v-model="form.short_name"
                placeholder="如：南1微信、楠支付宝"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              >
              <p class="text-xs text-gray-500 mt-1">账户简称必须唯一，用于快速识别账户</p>
            </div>

            <!-- Real Name Certification (optional) -->
            <div class="border-t border-gray-100 pt-4">
              <div class="text-xs text-gray-500 mb-3">实名认证信息（选填）</div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-medium text-gray-600 mb-1">认证人姓名</label>
                  <input
                    v-model="form.real_name"
                    placeholder="选填"
                    class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                  >
                </div>
                <div>
                  <label class="block text-xs font-medium text-gray-600 mb-1">手机号</label>
                  <input
                    v-model="form.cert_phone"
                    placeholder="选填"
                    class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                  >
                </div>
              </div>
              <div class="mt-3">
                <label class="block text-xs font-medium text-gray-600 mb-1">身份证号</label>
                <input
                  v-model="form.id_number"
                  placeholder="选填"
                  class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                >
              </div>
            </div>

            <!-- Initial Balance (only for new accounts) -->
            <div v-if="!isEditing">
              <label class="block text-sm font-medium text-gray-700 mb-1">初始余额</label>
              <input
                v-model.number="form.balance"
                type="number"
                step="0.01"
                placeholder="默认 0"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              >
            </div>

            <!-- 🔑 智能识别关键词 -->
            <div class="border-t border-gray-100 pt-4">
              <div class="flex items-center gap-2 mb-3">
                <span class="text-base">🔑</span>
                <span class="text-sm font-semibold text-gray-700">智能识别关键词</span>
              </div>
              <p class="text-xs text-gray-500 mb-3">设置关键词后，在文本模式输入时可自动识别此账户的收支和转账。关键词全局唯一，不可重复。</p>

              <!-- 支出关键词 -->
              <div class="mb-3">
                <label class="block text-xs font-medium text-gray-600 mb-1">💸 支出关键词</label>
                <div class="flex flex-wrap gap-1.5 mb-1.5">
                  <span v-for="(kw, i) in form.expense_keywords" :key="'ek'+i"
                    class="inline-flex items-center gap-1 bg-red-50 text-red-700 text-xs px-2 py-1 rounded-full">
                    {{ kw }}
                    <button @click="form.expense_keywords.splice(i, 1)" class="hover:text-red-900 cursor-pointer">&times;</button>
                  </span>
                </div>
                <div class="flex gap-1.5">
                  <input v-model="newExpenseKw" @keydown.enter.prevent="addKeyword('expense')" placeholder="如：宝付、卡付" class="flex-1 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-red-400">
                  <button @click="addKeyword('expense')" class="px-2.5 py-1.5 bg-red-50 text-red-600 rounded-lg text-xs hover:bg-red-100 cursor-pointer">添加</button>
                </div>
                <p v-if="keywordError.expense" class="text-xs text-red-500 mt-1">{{ keywordError.expense }}</p>
              </div>

              <!-- 收入关键词 -->
              <div class="mb-3">
                <label class="block text-xs font-medium text-gray-600 mb-1">💰 收入关键词</label>
                <div class="flex flex-wrap gap-1.5 mb-1.5">
                  <span v-for="(kw, i) in form.income_keywords" :key="'ik'+i"
                    class="inline-flex items-center gap-1 bg-green-50 text-green-700 text-xs px-2 py-1 rounded-full">
                    {{ kw }}
                    <button @click="form.income_keywords.splice(i, 1)" class="hover:text-green-900 cursor-pointer">&times;</button>
                  </span>
                </div>
                <div class="flex gap-1.5">
                  <input v-model="newIncomeKw" @keydown.enter.prevent="addKeyword('income')" placeholder="如：宝收、卡收" class="flex-1 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-green-400">
                  <button @click="addKeyword('income')" class="px-2.5 py-1.5 bg-green-50 text-green-600 rounded-lg text-xs hover:bg-green-100 cursor-pointer">添加</button>
                </div>
                <p v-if="keywordError.income" class="text-xs text-red-500 mt-1">{{ keywordError.income }}</p>
              </div>

              <!-- 转账规则 -->
              <div class="mb-3">
                <label class="block text-xs font-medium text-gray-600 mb-1">🔄 转账关键词</label>
                <div class="space-y-1.5 mb-1.5">
                  <div v-for="(rule, i) in form.transfer_rules" :key="'tr'+i"
                    class="flex items-center gap-1.5 bg-blue-50 text-blue-700 text-xs px-2.5 py-1.5 rounded-lg">
                    <span class="font-medium">{{ rule.keyword }}</span>
                    <span class="text-blue-400">→</span>
                    <span>{{ getAccountName(rule.target_account_id) }}</span>
                    <button @click="form.transfer_rules.splice(i, 1)" class="ml-auto hover:text-blue-900 cursor-pointer">&times;</button>
                  </div>
                </div>
                <div class="flex gap-1.5">
                  <input v-model="newTransferKw" placeholder="关键词如：转卡" class="w-24 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-blue-400">
                  <select v-model="newTransferTarget" class="flex-1 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-blue-400">
                    <option value="">→ 转入账户</option>
                    <option v-for="acc in otherAccounts" :key="acc.id" :value="acc.id">{{ acc.short_name || acc.code }}</option>
                  </select>
                  <button @click="addTransferRule" class="px-2.5 py-1.5 bg-blue-50 text-blue-600 rounded-lg text-xs hover:bg-blue-100 cursor-pointer">添加</button>
                </div>
                <p v-if="keywordError.transfer" class="text-xs text-red-500 mt-1">{{ keywordError.transfer }}</p>
              </div>
            </div>

            <!-- Note -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
              <textarea
                v-model="form.note"
                placeholder="选填"
                rows="2"
                class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
              ></textarea>
            </div>

            <!-- Balance method toggle (admin only, editing only) -->
            <div v-if="isEditing && authStore.isAdmin" class="border-t border-gray-100 pt-4">
              <div class="flex items-center gap-2">
                <label class="text-sm font-medium text-gray-700">修改余额</label>
                <input
                  v-model.number="form.balance"
                  type="number"
                  step="0.01"
                  class="flex-1 px-3 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                >
              </div>
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="flex justify-end gap-3 p-5 border-t border-gray-100">
            <button
              @click="closeModal"
              class="px-4 py-2 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer"
            >
              取消
            </button>
            <button
              @click="saveAccount"
              :disabled="saving"
              class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ saving ? '保存中...' : '保存' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Account Transactions Modal -->
    <AccountTransactions
      :visible="showTxn"
      :accountId="txnAccountId"
      :accountName="txnAccountName"
      :currentBalance="txnAccountBalance"
      @close="showTxn = false"
    />

    <!-- 期初余额弹窗 -->
    <OpeningBalanceModal
      :visible="showOpeningModal"
      :account="openingAccount"
      @close="showOpeningModal = false"
      @saved="onOpeningSaved"
    />

    <!-- 批量期初弹窗 -->
    <BatchOpeningBalanceModal
      :visible="showBatchOpeningModal"
      @close="showBatchOpeningModal = false"
      @saved="onBatchOpeningSaved"
    />
  </div>

  <!-- 排序弹窗 -->
  <Teleport to="body">
    <div v-if="showSortModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" @click.self="showSortModal = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[80vh] flex flex-col">
        <div class="flex items-center justify-between p-5 border-b">
          <h2 class="font-bold text-gray-800">🔀 账户排序</h2>
          <button @click="showSortModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <div class="p-5 text-sm text-gray-500 border-b bg-gray-50">
          为每个账户输入排序序号（1排最前），全部填完后点确认
        </div>
        <div class="flex-1 overflow-y-auto p-4 space-y-1">
          <div v-for="(acc, idx) in allAccounts" :key="acc.id" class="flex items-center gap-3 py-2 px-2 rounded-lg hover:bg-gray-50">
            <span class="text-gray-500 text-xs w-6 text-center">{{ idx + 1 }}</span>
            <span class="flex-1 text-sm text-gray-700 truncate">{{ acc.short_name || acc.code }}</span>
            <span class="text-xs text-gray-500">{{ platformIcon(acc.platform) }} {{ PLATFORM_LABELS[acc.platform] || '' }}</span>
            <input
              type="number"
              min="1"
              v-model.number="sortMap[acc.id]"
              class="w-16 px-2 py-1.5 border border-gray-200 rounded-lg text-sm text-center outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="—"
            />
          </div>
        </div>
        <div class="p-5 border-t flex justify-end gap-3">
          <button @click="showSortModal = false" class="px-4 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer">取消</button>
          <button @click="applySort" :disabled="sortSaving" class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-40 cursor-pointer">
            {{ sortSaving ? '保存中...' : '确认排序' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, onMounted, reactive, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useAccountStore } from '../stores/accounts'
import { supabase } from '../lib/supabase'
import { formatMoney, PLATFORM_LABELS, toast, formatDate } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'
import AccountTransactions from '../components/AccountTransactions.vue'
import OpeningBalanceModal from '../components/OpeningBalanceModal.vue'
import BatchOpeningBalanceModal from '../components/BatchOpeningBalanceModal.vue'
import { usePermission } from '../composables/usePermission'

const { canDelete, isAdmin, loadRole } = usePermission()

const authStore = useAuthStore()
const accountStore = useAccountStore()

// --- State ---
const loading = ref(true)
const saving = ref(false)
const showModal = ref(false)

const selectedIds = ref([])

const showTxn = ref(false)
const txnAccountId = ref('')
const txnAccountName = ref('')
const txnAccountBalance = ref(0)

// 期初余额弹窗
const showOpeningModal = ref(false)
const openingAccount = ref(null)

function openOpeningBalanceModal(acc) {
  if (!authStore.isFinance) return
  openingAccount.value = acc
  showOpeningModal.value = true
}

function onOpeningSaved() {
  // 组件内部已 fetchAccounts + toast，这里留作扩展位
}

// 批量期初弹窗
const showBatchOpeningModal = ref(false)
function onBatchOpeningSaved() {
  // 组件内部已 fetchAccounts + toast
}

const isEditing = ref(false)
const editingId = ref(null)
const flippedCards = reactive({})
const editingBalanceId = ref(null)
const editingBalanceVal = ref(null)

// --- 今日转账数据 ---
const todayTransferData = reactive({ total: 0, count: 0, loaded: false })

async function loadTodayTransfers() {
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
      .from('account_transfers')
      .select('amount')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO)
    if (data && data.length > 0) {
      todayTransferData.total = data.reduce((s, r) => s + (Number(r.amount) || 0), 0)
      todayTransferData.count = data.length
    } else {
      todayTransferData.total = 0
      todayTransferData.count = 0
    }
    todayTransferData.loaded = true
  } catch (e) {
    console.error('加载今日转账失败:', e)
  }
}

const activeTab = ref('active')

const filters = reactive({
  keyword: '',
  platform: '',
  category: 'personal',
  status: '',
  hideZeroBalance: false,
})

const defaultForm = () => ({
  platform: '',
  category: '',
  short_name: '',
  real_name: '',
  cert_phone: '',
  id_number: '',
  balance: 0,
  payment_alias: '',
  note: '',
  income_keywords: [],
  expense_keywords: [],
  transfer_rules: [],
})

// 关键词编辑状态
const newExpenseKw = ref('')
const newIncomeKw = ref('')
const newTransferKw = ref('')
const newTransferTarget = ref('')
const keywordError = reactive({ expense: '', income: '', transfer: '' })

// 获取除当前编辑账户外的其他账户（用于转账目标选择）
const otherAccounts = computed(() => {
  return allAccounts.value.filter(a => a.id !== editingId.value && a.status !== 'deleted')
})

function getAccountName(id) {
  const acc = allAccounts.value.find(a => a.id === id)
  return acc ? (acc.short_name || acc.code) : '未知账户'
}

// 检查关键词是否已被其他账户使用
function isKeywordTaken(kw) {
  for (const acc of allAccounts.value) {
    if (acc.id === editingId.value) continue
    const ek = acc.expense_keywords || []
    const ik = acc.income_keywords || []
    const tr = (acc.transfer_rules || []).map(r => r.keyword)
    if (ek.includes(kw)) return `已被「${acc.short_name}」的支出关键词使用`
    if (ik.includes(kw)) return `已被「${acc.short_name}」的收入关键词使用`
    if (tr.includes(kw)) return `已被「${acc.short_name}」的转账关键词使用`
  }
  // 也检查当前表单内是否重复
  if (form.expense_keywords.includes(kw) || form.income_keywords.includes(kw) || form.transfer_rules.some(r => r.keyword === kw)) {
    return '此关键词已在当前账户中使用'
  }
  return null
}

function addKeyword(type) {
  const kw = type === 'expense' ? newExpenseKw.value.trim() : newIncomeKw.value.trim()
  if (!kw) return
  keywordError[type] = ''
  const taken = isKeywordTaken(kw)
  if (taken) {
    keywordError[type] = `「${kw}」${taken}`
    return
  }
  if (type === 'expense') {
    form.expense_keywords.push(kw)
    newExpenseKw.value = ''
  } else {
    form.income_keywords.push(kw)
    newIncomeKw.value = ''
  }
}

function addTransferRule() {
  const kw = newTransferKw.value.trim()
  const target = newTransferTarget.value
  keywordError.transfer = ''
  if (!kw) { keywordError.transfer = '请填写转账关键词'; return }
  if (!target) { keywordError.transfer = '请选择转入账户'; return }
  const taken = isKeywordTaken(kw)
  if (taken) { keywordError.transfer = `「${kw}」${taken}`; return }
  form.transfer_rules.push({ keyword: kw, target_account_id: target })
  newTransferKw.value = ''
  newTransferTarget.value = ''
}

const form = reactive(defaultForm())

// --- Platform helpers ---
const PLATFORM_ICONS = {
  wechat: '🟢',
  alipay: '🔵',
  youzan: '🟠',
  douyin: '⚫',
  taobao: '🟡',
  kuaishou: '🟣',
  weixin_video: '🟤',
  shipinhao: '🟤',
  jd: '🟠',
  bank: '🏦',
  cash: '💵',
  other: '⚪',
}

// --- Account category ---
const ECOMMERCE_PLATFORMS = ['douyin', 'weixin_video', 'shipinhao', 'taobao', 'kuaishou', 'youzan', 'jd', 'xiaohongshu', 'pinduoduo']
const PERSONAL_PLATFORMS = ['wechat', 'alipay', 'cash', 'bank']
const CATEGORY_LABELS = { ecommerce: '🛒 电商账户', company: '🏢 企业账户', personal: '👤 个人账户' }

function getAccountCategory(acc) {
  if (acc.category) return acc.category
  // 根据 platform 自动推断
  if (ECOMMERCE_PLATFORMS.includes(acc.platform)) return 'ecommerce'
  if (PERSONAL_PLATFORMS.includes(acc.platform)) return 'personal'
  return 'company'
}

function autoCategory() {
  if (form.platform && !form.category) {
    if (ECOMMERCE_PLATFORMS.includes(form.platform)) form.category = 'ecommerce'
    else if (PERSONAL_PLATFORMS.includes(form.platform)) form.category = 'personal'
    else form.category = 'company'
  }
}

function categoryLabel(cat) {
  return CATEGORY_LABELS[cat] || '🏢 企业账户'
}

function platformIcon(platform) {
  return PLATFORM_ICONS[platform] || '⚪'
}

function platformLabel(platform) {
  return PLATFORM_LABELS[platform] || platform || '其他'
}

function platformIconBg(platform) {
  const map = {
    wechat: 'bg-green-500',
    alipay: 'bg-blue-500',
    douyin: 'bg-gray-800',
    taobao: 'bg-orange-400',
    kuaishou: 'bg-purple-500',
    weixin_video: 'bg-amber-500',
    shipinhao: 'bg-amber-500',
    bank: 'bg-slate-500',
    cash: 'bg-teal-400',
    youzan: 'bg-rose-400',
    other: 'bg-gray-400',
  }
  return map[platform] || map.other
}

function platformGradient(platform) {
  const map = {
    wechat: 'linear-gradient(135deg, #07c160, #06ad56)',
    alipay: 'linear-gradient(135deg, #1677ff, #0958d9)',
    douyin: 'linear-gradient(135deg, #1a1a2e, #16213e)',
    taobao: 'linear-gradient(135deg, #ff6a00, #ee0979)',
    kuaishou: 'linear-gradient(135deg, #ff4906, #ff0000)',
    weixin_video: 'linear-gradient(135deg, #fa9d3b, #f27121)',
    shipinhao: 'linear-gradient(135deg, #fa9d3b, #f27121)',
    bank: 'linear-gradient(135deg, #4a5568, #2d3748)',
    cash: 'linear-gradient(135deg, #38b2ac, #319795)',
    youzan: 'linear-gradient(135deg, #e11d48, #be123c)',
    jd: 'linear-gradient(135deg, #dc2626, #b91c1c)',
    other: 'linear-gradient(135deg, #94a3b8, #64748b)',
  }
  return map[platform] || map.other
}

// --- Computed ---
const canManage = computed(() => {
  const role = authStore.profile?.role
  return ['admin', 'finance'].includes(role)
})

const allAccounts = computed(() => accountStore.accounts)

const filteredAccounts = computed(() => {
  return allAccounts.value.filter(acc => {
    // 排除电商账户（电商账户在"电商管理"页面管理）
    if (acc.ecommerce_platform) return false
    // Tab 过滤
    if (activeTab.value === 'active' && acc.status !== 'active') return false
    if (activeTab.value === 'frozen' && acc.status !== 'frozen') return false
    const cat = getAccountCategory(acc)
    if (filters.category && cat !== filters.category) return false
    if (filters.platform && acc.platform !== filters.platform) return false
    if (filters.hideZeroBalance && Number(acc.balance || 0) === 0) return false
    if (filters.keyword) {
      const kw = filters.keyword.toLowerCase()
      const name = (acc.short_name || acc.code || '').toLowerCase()
      if (!name.includes(kw)) return false
    }
    return true
  })
})

const personalTotal = computed(() => {
  return allAccounts.value
    .filter(a => !a.ecommerce_platform && getAccountCategory(a) === 'personal' && a.status === 'active')
    .reduce((sum, a) => sum + (Number(a.balance) || 0), 0)
})
const personalCount = computed(() => allAccounts.value.filter(a => !a.ecommerce_platform && getAccountCategory(a) === 'personal' && a.status === 'active').length)
const companyTotal = computed(() => {
  return allAccounts.value
    .filter(a => !a.ecommerce_platform && getAccountCategory(a) === 'company' && a.status === 'active')
    .reduce((sum, a) => sum + (Number(a.balance) || 0), 0)
})
const companyCount = computed(() => allAccounts.value.filter(a => !a.ecommerce_platform && getAccountCategory(a) === 'company' && a.status === 'active').length)

// 电商账户待结算资金（余额合计）
const ecommercePendingBalance = computed(() => {
  return allAccounts.value
    .filter(a => a.ecommerce_platform && a.status === 'active')
    .reduce((sum, a) => sum + (Number(a.balance) || 0), 0)
})
const ecommerceCount = computed(() => allAccounts.value.filter(a => a.ecommerce_platform && a.status === 'active').length)

// --- Methods ---
function highlightKeyword(text) {
  if (!filters.keyword || !text) return text || ''
  const kw = filters.keyword.trim()
  const regex = new RegExp(`(${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
  return text.replace(regex, '<span class="bg-yellow-200 rounded px-0.5">$1</span>')
}

// --- Balance Change Logs ---
async function approveLog(log) {
  // 审核通过：更新余额 + 更新日志状态
  await supabase.from('accounts').update({ balance: Number(log.new_balance) }).eq('id', log.account_id)
  await supabase.from('balance_change_logs').update({
    status: 'approved',
    approved_by: authStore.profile?.id,
    approved_at: new Date().toISOString(),
  }).eq('id', log.id)
  // 操作日志
  try {
    const { logOperation } = await import('../utils/operationLogger')
    const diff = Number(log.new_balance) - Number(log.old_balance)
    const sign = diff >= 0 ? '+' : ''
    logOperation({
      action: 'manual_balance',
      module: '账户',
      description: `审批余额修改，${log.account_name}，余额 ${Number(log.old_balance).toFixed(2)} ${sign}${diff.toFixed(2)} → ${Number(log.new_balance).toFixed(2)}，发起人：${log.requested_by_name || ''}`,
      detail: { account_id: log.account_id, account_name: log.account_name, old_balance: log.old_balance, new_balance: log.new_balance, requested_by: log.requested_by, approved_by: authStore.profile?.id, log_id: log.id },
      amount: Math.abs(diff),
      accountId: log.account_id,
      accountName: log.account_name,
    })
  } catch (e) { console.warn("[silent catch]", e?.message || e) }
  // 刷新列表
  await accountStore.fetchAccounts()
  log.status = 'approved'
  log.approved_by_name = authStore.profile?.name || '管理员'
  toast('审核通过，余额已更新', 'success')
}

async function rejectLog(log) {
  await supabase.from('balance_change_logs').update({
    status: 'rejected',
    approved_by: authStore.profile?.id,
    approved_at: new Date().toISOString(),
  }).eq('id', log.id)
  log.status = 'rejected'
  log.approved_by_name = authStore.profile?.name || '管理员'
  toast('已驳回', 'success')
}

function maskIdNumber(id) {
  if (!id || id.length < 8) return id || ''
  return id.substring(0, 4) + '****' + id.substring(id.length - 4)
}

function toggleSelect(id) {
  const idx = selectedIds.value.indexOf(id)
  if (idx >= 0) selectedIds.value.splice(idx, 1)
  else selectedIds.value.push(id)
}

async function batchAction(action) {
  if (!confirm(`确定要对 ${selectedIds.value.length} 个账户执行此操作吗？`)) return
  const ids = [...selectedIds.value]
  try {
    if (action === 'freeze') {
      await supabase.from('accounts').update({ status: 'frozen' }).in('id', ids)
      toast(`已停用 ${ids.length} 个账户`, 'success')
    } else if (action === 'activate') {
      await supabase.from('accounts').update({ status: 'active' }).in('id', ids)
      toast(`已启用 ${ids.length} 个账户`, 'success')
    } else if (action === 'delete') {
      const withBalance = ids.filter(id => {
        const acc = allAccounts.value.find(a => a.id === id)
        return acc && Number(acc.balance || 0) > 0
      })
      if (withBalance.length > 0) {
        toast(`${withBalance.length} 个账户仍有余额，请先处理`, 'warning')
        return
      }
      await supabase.from('accounts').update({ status: 'deleted' }).in('id', ids)
      toast(`已删除 ${ids.length} 个账户`, 'success')
    }
    accountStore._forceRefresh = true
    await accountStore.fetchAccounts()
    selectedIds.value = []
  } catch (e) {
    toast('操作失败: ' + (e.message || ''), 'error')
  }
}

function isIncomplete(acc) {
  return !acc.short_name || !acc.real_name || !acc.cert_phone || !acc.id_number
}

function viewTransactions(account) {
  txnAccountId.value = account.id
  txnAccountName.value = account.short_name || account.code
  txnAccountBalance.value = account.balance || 0
  showTxn.value = true
}

function flipCard(id) {
  flippedCards[id] = !flippedCards[id]
}

function openModal(acc = null) {
  if (acc) {
    isEditing.value = true
    editingId.value = acc.id
    Object.assign(form, {
      platform: acc.platform || '',
      category: acc.category || getAccountCategory(acc),
      short_name: acc.short_name || acc.code || '',
      real_name: acc.real_name || '',
      cert_phone: acc.cert_phone || '',
      id_number: acc.id_number || '',
      balance: acc.balance || 0,
      payment_alias: acc.payment_alias ? acc.payment_alias.replace(/付$/, '') : '',
      note: acc.note || '',
      income_keywords: [...(acc.income_keywords || [])],
      expense_keywords: [...(acc.expense_keywords || [])],
      transfer_rules: [...(acc.transfer_rules || [])].map(r => ({ ...r })),
    })
    // 清空临时输入
    newExpenseKw.value = ''
    newIncomeKw.value = ''
    newTransferKw.value = ''
    newTransferTarget.value = ''
    Object.assign(keywordError, { expense: '', income: '', transfer: '' })
  } else {
    isEditing.value = false
    editingId.value = null
    Object.assign(form, defaultForm())
  }
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  isEditing.value = false
  editingId.value = null
  Object.assign(form, defaultForm())
  newExpenseKw.value = ''
  newIncomeKw.value = ''
  newTransferKw.value = ''
  newTransferTarget.value = ''
  Object.assign(keywordError, { expense: '', income: '', transfer: '' })
}

async function saveAccount() {
  if (!form.platform) {
    toast('请选择收款平台', 'warning')
    return
  }
  if (!form.short_name?.trim()) {
    toast('请填写账户简称', 'warning')
    return
  }

  saving.value = true
  try {
    if (isEditing.value) {
      const payload = {
        platform: form.platform,
        short_name: form.short_name.trim(),
        real_name: form.real_name?.trim() || null,
        cert_phone: form.cert_phone?.trim() || null,
        id_number: form.id_number?.trim() || null,
        payment_alias: (form.payment_alias?.trim() || null),
        note: form.note?.trim() || null,
        category: form.category || null,
        income_keywords: form.income_keywords || [],
        expense_keywords: form.expense_keywords || [],
        transfer_rules: form.transfer_rules || [],
      }
      // 手动模式下余额有变化，记录日志
      const oldAcc = allAccounts.value.find(a => a.id === editingId.value)
      if (oldAcc && authStore.isAdmin && Number(oldAcc.balance) !== Number(form.balance)) {
        const isAdmin = authStore.isAdmin
        if (isAdmin) {
          // admin直接改余额
          payload.balance = Number(form.balance)
          await supabase.from('balance_change_logs').insert({
            account_id: editingId.value,
            account_name: form.short_name.trim(),
            old_balance: Number(oldAcc.balance),
            new_balance: Number(form.balance),
            requested_by: authStore.profile?.id,
            approved_by: authStore.profile?.id,
            status: 'approved',
            reason: '管理员直接修改',
            approved_at: new Date().toISOString(),
          })
          // 操作日志
          try {
            const { logOperation } = await import('../utils/operationLogger')
            const diff = Number(form.balance) - Number(oldAcc.balance)
            const sign = diff >= 0 ? '+' : ''
            logOperation({
              action: 'manual_balance',
              module: '账户',
              description: `手动修改余额，${form.short_name.trim()}，余额 ${Number(oldAcc.balance).toFixed(2)} ${sign}${diff.toFixed(2)} → ${Number(form.balance).toFixed(2)}`,
              detail: { account_id: editingId.value, account_name: form.short_name.trim(), old_balance: Number(oldAcc.balance), new_balance: Number(form.balance), reason: '管理员直接修改' },
              amount: Math.abs(diff),
              accountId: editingId.value,
              accountName: form.short_name.trim(),
            })
          } catch (e) { console.warn("[silent catch]", e?.message || e) }
        } else {
          // finance发起审核请求，余额不改
          await supabase.from('balance_change_logs').insert({
            account_id: editingId.value,
            account_name: form.short_name.trim(),
            old_balance: Number(oldAcc.balance),
            new_balance: Number(form.balance),
            requested_by: authStore.profile?.id,
            status: 'pending',
            reason: '财务申请修改',
          })
          toast('余额修改申请已提交，等待审核', 'success')
          closeModal()
          saving.value = false
          return
        }
      }
      await accountStore.updateAccount(editingId.value, payload)
      toast('账户已更新', 'success')
    } else {
      const payload = {
        platform: form.platform,
        short_name: form.short_name.trim(),
        code: form.short_name.trim(),
        owner_code: '—',  // DB NOT NULL，表单不暴露此字段，与电商店铺创建保持一致
        real_name: form.real_name?.trim() || null,
        cert_phone: form.cert_phone?.trim() || null,
        id_number: form.id_number?.trim() || null,
        balance: Number(form.balance) || 0,
        opening_balance: Number(form.balance) || 0,
        status: 'active',
        payment_alias: (form.payment_alias?.trim() || null),
        note: form.note?.trim() || null,
        category: form.category || null,
        income_keywords: form.income_keywords || [],
        expense_keywords: form.expense_keywords || [],
        transfer_rules: form.transfer_rules || [],
      }
      await accountStore.createAccount(payload)
      toast('账户已添加', 'success')
    }
    closeModal()
    // Force refresh to get latest data
    accountStore._forceRefresh = true
    await accountStore.fetchAccounts()
  } catch (e) {
    console.error(e)
    if (e.message?.includes('unique') || e.message?.includes('duplicate')) {
      toast('账户简称已存在，请使用其他名称', 'warning')
    } else {
      toast(e.message || '保存失败', 'error')
    }
  } finally {
    saving.value = false
  }
}

// --- 排序 ---
const showSortModal = ref(false)
const sortMap = reactive({})
const sortSaving = ref(false)

function openSortModal() {
  // 初始化：用现有 sequence 填充，没有的留空
  allAccounts.value.forEach(acc => {
    sortMap[acc.id] = acc.sequence || 0
  })
  showSortModal.value = true
}

async function applySort() {
  // 检查是否全部填了
  const filled = allAccounts.value.filter(a => sortMap[a.id] && sortMap[a.id] > 0)
  if (filled.length === 0) {
    toast('请至少为一个账户填写排序序号', 'warning')
    return
  }
  sortSaving.value = true
  try {
    // 逐个更新 sequence
    for (const acc of filled) {
      await supabase.from('accounts').update({ sequence: sortMap[acc.id] }).eq('id', acc.id)
    }
    // 刷新
    accountStore._forceRefresh = true
    await accountStore.fetchAccounts()
    toast(`已更新 ${filled.length} 个账户的排序`, 'success')
    showSortModal.value = false
  } catch (e) {
    console.error('排序失败:', e)
    toast('排序失败', 'error')
  } finally {
    sortSaving.value = false
  }
}

async function toggleFreeze(acc) {
  const newStatus = acc.status === 'active' ? 'frozen' : 'active'
  const action = newStatus === 'frozen' ? '停用' : '启用'
  try {
    await accountStore.updateAccount(acc.id, { status: newStatus })
    toast(`账户已${action}`, 'success')
  } catch (e) {
    console.error(e)
    toast(`${action}失败: ${e.message || '未知错误'}`, 'error')
  }
}

async function handleDelete(acc) {
  const bal = Number(acc.balance || 0)
  if (bal > 0) {
    toast(`账户余额 ¥${bal.toFixed(2)}，请先转出或对账清零后再删除`, 'warning')
    return
  }
  if (!confirm(`确定要删除账户「${acc.short_name || acc.code}」吗？`)) return
  try {
    await accountStore.deleteAccount(acc.id)
    toast('账户已删除', 'success')
  } catch (e) {
    toast(e.message || '删除失败', 'error')
  }
}

function startEditBalance(acc) {
  editingBalanceId.value = acc.id
  editingBalanceVal.value = acc.balance || 0
}

function cancelBalanceEdit() {
  editingBalanceId.value = null
  editingBalanceVal.value = null
}

async function saveBalanceEdit(acc) {
  try {
    await accountStore.updateAccount(acc.id, { balance: Number(editingBalanceVal.value) || 0 })
    toast('余额已更新', 'success')
    cancelBalanceEdit()
  } catch (e) {
    console.error(e)
    toast('余额更新失败: ' + (e.message || ''), 'error')
  }
}

// --- Init ---
onMounted(async () => {
  loadRole()
  loading.value = true
  try {
    accountStore._forceRefresh = true
    await Promise.all([
      accountStore.fetchAccounts(),
      loadTodayTransfers(),
    ])
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
/* Card flip container */
.account-card-container {
  perspective: 800px;
  height: 150px;
}

.account-card-inner {
  position: relative;
  width: 100%;
  height: 100%;
  transition: transform 0.7s cubic-bezier(0.4, 0.0, 0.2, 1);
  transform-style: preserve-3d;
}

.account-card-inner.is-flipped {
  transform: rotateY(180deg);
}

.account-card-front,
.account-card-back {
  position: absolute;
  inset: 0;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
  background: white;
  border-radius: 16px;
  overflow: hidden;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.account-card-front {
  border: none;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.account-card-back {
  border: 1px solid #f0f0f0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  transform: rotateY(180deg);
}

.account-card-container:hover .account-card-front {
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.2);
  transform: translateY(-2px);
}

.account-card-container:hover .is-flipped {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
}
</style>
