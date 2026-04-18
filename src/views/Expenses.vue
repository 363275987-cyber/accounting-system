<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-4 md:mb-6">
      <div></div>
      <div class="flex items-center gap-2 shrink-0">
        <!-- 桌面端按钮 -->
        <div v-if="canDeleteExpenses" class="hidden md:inline-flex items-center gap-1">
          <select v-model="testCount" class="text-xs border border-dashed border-gray-300 rounded px-2 py-1 text-gray-500 bg-transparent outline-none cursor-pointer">
            <option :value="1">1条</option>
            <option :value="5">5条</option>
            <option :value="10">10条</option>
            <option :value="20">20条</option>
          </select>
          <button @click="generateTestData(testCount)" class="text-xs px-2 py-1 border border-dashed border-gray-300 rounded text-gray-500 hover:bg-gray-50 hover:text-gray-600 cursor-pointer"><Icon name="dices" class="inline w-4 h-4 -mt-0.5 mr-1" /> 随机测试
          </button>
        </div>
        <button
          v-if="canDeleteExpenses"
          @click="showTextMode = !showTextMode"
          class="hidden md:inline-flex px-4 py-2 rounded-lg text-sm transition cursor-pointer whitespace-nowrap"
          :class="showTextMode ? 'bg-purple-600 text-white hover:bg-purple-700' : 'bg-purple-50 text-purple-700 hover:bg-purple-100'"
        ><Icon name="brain" class="inline w-4 h-4 -mt-0.5 mr-1" /> 智能记账
        </button>
        <button
          @click="showCategoryModal = true"
          class="hidden md:inline-flex border border-gray-200 text-gray-600 px-4 py-2 rounded-lg text-sm hover:bg-gray-50 transition cursor-pointer whitespace-nowrap"
        ><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 类别
        </button>
        <!-- 移动端更多菜单 -->
        <div class="relative md:hidden">
          <button @click="showMobileMenu = !showMobileMenu" class="px-2.5 py-2 rounded-lg text-sm border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">
            ⋯
          </button>
          <div v-if="showMobileMenu" class="absolute right-0 top-full mt-1 bg-white rounded-xl shadow-lg border border-gray-100 py-1 z-50 min-w-[140px]">
            <button v-if="canDeleteExpenses" @click="showTextMode = !showTextMode; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer"><Icon name="brain" class="inline w-4 h-4 -mt-0.5 mr-1" /> 智能记账</button>
            <button @click="showCategoryModal = true; showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 cursor-pointer"><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 类别</button>
            <button v-if="canDeleteExpenses" @click="generateTestData(testCount); showMobileMenu = false" class="w-full text-left px-4 py-2.5 text-sm text-gray-400 hover:bg-gray-50 cursor-pointer"><Icon name="dices" class="inline w-4 h-4 -mt-0.5 mr-1" /> 随机测试</button>
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
          <h3 class="text-sm font-semibold text-gray-700"><Icon name="clipboard" class="inline w-4 h-4 -mt-0.5 mr-1" /> 智能记账 — 粘贴文本自动识别</h3>
          <button @click="showTextMode = false" class="text-gray-500 hover:text-gray-600 text-sm cursor-pointer">收起 ✕</button>
        </div>
        <textarea
          v-model="rawText"
          rows="5"
          placeholder="每行一条，自动识别收入/支出/转账/资产等类型&#10;示例：&#10;宝付 3月15日 物流费 580元&#10;转卡 5000&#10;卡付 买球台 28000元&#10;宝收 李明 课程费 9800"
          class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500 resize-none font-mono"
        ></textarea>
        <div class="flex items-center gap-3 mt-3">
          <div class="flex items-center gap-2">
            <span class="text-xs text-gray-500"><Icon name="calendar" class="inline w-4 h-4 -mt-0.5 mr-1" /> 统一月份：</span>
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
          ><Icon name="search" class="inline w-4 h-4 -mt-0.5 mr-1" /> 解析
          </button>
          <button
            @click="rawText = ''; parsedExpenses = []; parseError = ''"
            class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer transition"
          >
            清空
          </button>
          <button
            @click="showKeywordManager = !showKeywordManager"
            class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer transition ml-auto"
          ><Icon name="settings" class="inline w-4 h-4 -mt-0.5 mr-1" /> 管理识别词
          </button>
        </div>

        <!-- 关键词管理面板 -->
        <div v-if="showKeywordManager" class="mt-3 bg-gray-50 rounded-lg border border-gray-200 p-4">
          <div class="flex items-center justify-between mb-3">
            <h4 class="text-sm font-semibold text-gray-700"><Icon name="settings" class="inline w-4 h-4 -mt-0.5 mr-1" /> 类型识别关键词</h4>
            <button @click="showKeywordManager = false" class="text-gray-400 hover:text-gray-600 text-sm cursor-pointer">✕</button>
          </div>
          <p class="text-xs text-gray-500 mb-3">当文本中包含以下关键词时，会自动识别为对应类型。你可以添加新词或删除不需要的。</p>

          <!-- 按类型分组展示 -->
          <div v-for="(group, gType) in groupedTypeKeywords" :key="gType" class="mb-3">
            <div class="text-xs font-semibold mb-1.5" :class="typeColorClass(gType)">
              {{ TYPE_LABELS[gType] || gType }}
            </div>
            <div class="flex flex-wrap gap-1.5 mb-1.5">
              <span v-for="kw in group" :key="kw.id"
                class="inline-flex items-center gap-1 text-[11px] px-2 py-0.5 rounded-full border"
                :class="typeTagClass(gType)">
                {{ kw.keyword }}
                <button @click="deleteTypeKeyword(kw.id)" class="hover:opacity-70 cursor-pointer">&times;</button>
              </span>
            </div>
          </div>

          <!-- 添加新关键词 -->
          <div class="flex gap-2 mt-3 pt-3 border-t border-gray-200">
            <select v-model="newKwType" class="px-2 py-1.5 border border-gray-200 rounded-lg text-xs bg-white cursor-pointer">
              <option value="fixed_asset">🏗️ 固定资产</option>
              <option value="prepaid">预付账款</option>
              <option value="deferred_revenue">🎓 预收账款</option>
              <option value="other_receivable">押金/借出</option>
              <option value="other_payable">收到押金</option>
              <option value="payable">应付账款</option>
              <option value="salary">工资</option>
              <option value="dividend">💎 分红</option>
            </select>
            <input v-model="newKwText" @keydown.enter.prevent="addTypeKeyword" placeholder="输入新关键词，如：球桌、买灯"
              class="flex-1 px-2.5 py-1.5 border border-gray-200 rounded-lg text-xs outline-none focus:ring-1 focus:ring-purple-400">
            <button @click="addTypeKeyword"
              class="px-3 py-1.5 bg-purple-600 text-white rounded-lg text-xs hover:bg-purple-700 cursor-pointer shrink-0">
              添加
            </button>
          </div>
          <p v-if="kwManagerError" class="text-xs text-red-500 mt-1">{{ kwManagerError }}</p>
        </div>

        <!-- Parsed Preview -->
        <div v-if="parsedExpenses.length > 0" class="mt-4 space-y-3">
          <div class="text-xs text-gray-500 mb-1">解析到 {{ parsedExpenses.length }} 条记录，可修改类型/字段后确认提交：</div>
          <div
            v-for="(exp, idx) in parsedExpenses"
            :key="idx"
            :class="['border rounded-lg p-4', txnCardClass(exp._type)]"
          >
            <!-- 原文 + 匹配置信度 -->
            <div class="flex items-center gap-2 mb-2">
              <div class="text-xs text-gray-500 font-mono bg-gray-50 rounded px-2 py-1 break-all whitespace-pre-wrap flex-1">{{ exp._rawText }}</div>
              <span v-if="exp._confidence >= 85" class="text-[9px] px-1.5 py-0.5 rounded-full bg-green-100 text-green-700 whitespace-nowrap">✓ 高</span>
              <span v-else-if="exp._confidence >= 50" class="text-[9px] px-1.5 py-0.5 rounded-full bg-blue-100 text-blue-700 whitespace-nowrap">~ 中</span>
              <span v-else-if="exp._confidence > 0" class="text-[9px] px-1.5 py-0.5 rounded-full bg-amber-100 text-amber-700 whitespace-nowrap"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 低</span>
              <span v-else class="text-[9px] px-1.5 py-0.5 rounded-full bg-red-100 text-red-700 whitespace-nowrap">? 未识别</span>
            </div>

            <!-- 头部：类型选择 + 提交按钮 -->
            <div class="flex items-center justify-between mb-3">
              <div class="flex items-center gap-2">
                <select v-model="exp._type" class="text-xs font-semibold border border-gray-200 rounded-lg px-2 py-1 bg-white cursor-pointer" @change="onTypeChange(exp)">
                  <option value="expense">支出</option>
                  <option value="income">收入</option>
                  <option value="transfer">转账</option>
                  <option value="withdrawal">💱 店铺提现</option>
                  <option value="fixed_asset">🏗️ 固定资产</option>
                  <option value="prepaid">预付账款</option>
                  <option value="deferred_revenue">🎓 预收课程费</option>
                  <option value="other_receivable">押金/借出</option>
                  <option value="other_payable">收到押金</option>
                  <option value="payable">应付账款</option>
                  <option value="salary">工资</option>
                  <option value="dividend">💎 分红</option>
                </select>
                <span class="text-[10px] text-gray-400">{{ idx + 1 }}/{{ parsedExpenses.length }}</span>
              </div>
              <div class="flex items-center gap-1.5">
                <button @click="parsedExpenses.splice(idx, 1)" class="px-2 py-1 text-gray-400 hover:text-red-500 text-xs cursor-pointer">🗑️</button>
                <button
                  @click="submitParsedExpense(idx)"
                  :disabled="submittingParsed || exp._submitting"
                  class="px-3 py-1 bg-green-600 text-white rounded-md text-xs hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition"
                >
                  {{ exp._submitting ? '提交中...' : '✅ 提交' }}
                </button>
              </div>
            </div>

            <!-- 学习提示：手动改了类型时显示 -->
            <div v-if="exp._typeChanged && exp._type !== 'expense' && exp._type !== 'income' && exp._type !== 'transfer'"
              class="flex items-center gap-2 mb-3 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
              <span class="text-xs text-amber-700 shrink-0"><Icon name="brain" class="inline w-4 h-4 -mt-0.5 mr-1" /> 记住这个词？</span>
              <input v-model="exp._learnKeyword" placeholder="输入要记住的关键词"
                class="flex-1 px-2 py-1 border border-amber-200 rounded text-xs bg-white outline-none focus:ring-1 focus:ring-amber-400" />
              <button @click="learnKeyword(exp)"
                class="px-2.5 py-1 bg-amber-500 text-white rounded text-xs hover:bg-amber-600 cursor-pointer shrink-0">
                记住
              </button>
              <button @click="exp._typeChanged = false" class="text-amber-400 hover:text-amber-600 text-xs cursor-pointer">✕</button>
            </div>

            <!-- 通用字段：账户 + 金额 + 日期 -->
            <div class="grid grid-cols-3 gap-2 text-sm mb-2">
              <div>
                <span class="text-gray-500 text-[10px]">{{ exp._type === 'withdrawal' ? '提现店铺' : exp._type === 'transfer' ? '转出账户' : exp._type === 'income' || exp._type === 'deferred_revenue' || exp._type === 'other_payable' ? '收款账户' : '付款账户' }}</span>
                <SearchableSelect
                  :model-value="exp.account_id"
                  @update:modelValue="(v) => handleAccountChange(exp, v)"
                  :options="exp._type === 'withdrawal' ? ecommerceAccounts : activeAccounts"
                  label-key="code"
                  value-key="id"
                  :placeholder="exp._type === 'withdrawal' ? '选择店铺' : '选择账户'"
                  search-placeholder="搜索..."
                  drop-up
                />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">金额</span>
                <input v-model.number="exp.amount" type="number" min="0.01" step="0.01" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">日期</span>
                <input v-model="exp.expense_date" type="date" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 🧠 账户关键词学习提示：用户手动改了账户时显示 -->
            <div v-if="exp._accountChanged && exp.account_id && (exp._type === 'expense' || exp._type === 'income')"
              class="flex items-center gap-2 mb-3 bg-emerald-50 border border-emerald-200 rounded-lg px-3 py-2">
              <span class="text-xs text-emerald-700 shrink-0"><Icon name="brain" class="inline w-4 h-4 -mt-0.5 mr-1" /> 记住「</span>
              <input v-model="exp._learnAccountKeyword" placeholder="关键词"
                class="flex-1 max-w-[10rem] px-2 py-1 border border-emerald-200 rounded text-xs bg-white outline-none focus:ring-1 focus:ring-emerald-400" />
              <span class="text-xs text-emerald-700 shrink-0">」→ {{ getAccountName(exp.account_id) }}（{{ exp._type === 'income' ? '收入' : '支出' }}）？</span>
              <button @click="learnAccountKeyword(exp)"
                class="px-2.5 py-1 bg-emerald-500 text-white rounded text-xs hover:bg-emerald-600 cursor-pointer shrink-0">
                记住
              </button>
              <button @click="exp._accountChanged = false" class="text-emerald-400 hover:text-emerald-600 text-xs cursor-pointer">✕</button>
            </div>

            <!-- ===== 按类型显示不同字段 ===== -->

            <!-- 普通支出 -->
            <div v-if="exp._type === 'expense'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">类别</span>
                <select v-model="exp.category" @change="onCategoryChange(exp)" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer"
                  :class="exp._confidence != null && exp._confidence < 50 ? 'border-amber-400 bg-amber-50' : ''">
                  <option value="">请选择</option>
                  <option v-for="cat in categories" :key="cat.id || cat.name" :value="cat.name">{{ cat.name }}</option>
                </select>
                <span v-if="exp._confidence != null && exp._confidence < 50" class="text-[9px] text-amber-600"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 低置信度，请确认</span>
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">收款方</span>
                <input v-model="exp.payee" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 收入 -->
            <div v-else-if="exp._type === 'income'" class="grid grid-cols-2 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">来源/付款人</span>
                <input v-model="exp.payee" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 转账 -->
            <div v-else-if="exp._type === 'transfer'" class="grid grid-cols-2 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">转入账户</span>
                <SearchableSelect
                  v-model="exp.target_account_id"
                  :options="activeAccounts"
                  label-key="code"
                  value-key="id"
                  placeholder="选择转入账户"
                  search-placeholder="搜索..."
                  drop-up
                />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 店铺提现 -->
            <div v-else-if="exp._type === 'withdrawal'" class="space-y-2">
              <div class="grid grid-cols-3 gap-2 text-sm">
                <div>
                  <span class="text-gray-500 text-[10px]">到账账户</span>
                  <SearchableSelect
                    v-model="exp.target_account_id"
                    :options="nonEcommerceAccounts"
                    label-key="code"
                    value-key="id"
                    placeholder="选择到账账户"
                    search-placeholder="搜索..."
                    drop-up
                  />
                </div>
                <div>
                  <span class="text-gray-500 text-[10px]">手续费</span>
                  <input v-model.number="exp.fee_amount" type="number" min="0" step="0.01" placeholder="0" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                </div>
                <div>
                  <span class="text-gray-500 text-[10px]">手续费备注</span>
                  <input v-model="exp.fee_remark" placeholder="如 平台手续费" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                </div>
              </div>
              <div class="grid grid-cols-1 gap-2 text-sm">
                <div>
                  <span class="text-gray-500 text-[10px]">提现备注</span>
                  <input v-model="exp.note" placeholder="如 8月提现" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                </div>
              </div>
              <div class="text-[10px] text-teal-700 bg-teal-50 border border-teal-200 rounded px-2 py-1.5">
                店铺将扣除 ¥{{ ((Number(exp.amount) || 0) + (Number(exp.fee_amount) || 0)).toFixed(2) }}
                = 到账 ¥{{ (Number(exp.amount) || 0).toFixed(2) }} + 手续费 ¥{{ (Number(exp.fee_amount) || 0).toFixed(2) }}
              </div>
            </div>

            <!-- 固定资产 -->
            <div v-else-if="exp._type === 'fixed_asset'" class="space-y-2">
              <div class="grid grid-cols-2 gap-2 text-sm">
                <div>
                  <span class="text-gray-500 text-[10px]">资产名称</span>
                  <input v-model="exp.asset_name" placeholder="如：星牌球台" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                </div>
                <div>
                  <span class="text-gray-500 text-[10px]">资产分类</span>
                  <select v-model="exp.asset_category" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer">
                    <option value="equipment">设备器材</option>
                    <option value="furniture">办公家具</option>
                    <option value="vehicle">交通工具</option>
                    <option value="electronics">电子设备</option>
                    <option value="other">其他</option>
                  </select>
                </div>
              </div>
              <div class="grid grid-cols-3 gap-2 text-sm">
                <div>
                  <span class="text-gray-500 text-[10px]">使用年限</span>
                  <div class="flex items-center gap-1">
                    <input v-model.number="exp.useful_life_years" type="number" min="1" max="50" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                    <span class="text-xs text-gray-400 shrink-0">年</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-500 text-[10px]">残值率</span>
                  <div class="flex items-center gap-1">
                    <input v-model.number="exp.residual_rate" type="number" min="0" max="100" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
                    <span class="text-xs text-gray-400 shrink-0">%</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-500 text-[10px]">月折旧额</span>
                  <div class="text-sm font-medium text-orange-600 py-1">
                    ¥{{ ((exp.amount * (1 - (exp.residual_rate || 5) / 100)) / ((exp.useful_life_years || 5) * 12)).toFixed(2) }}
                  </div>
                </div>
              </div>
            </div>

            <!-- 预付账款 -->
            <div v-else-if="exp._type === 'prepaid'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">供应商</span>
                <input v-model="exp.supplier" placeholder="供应商名称" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">预计到货日</span>
                <input v-model="exp.expected_date" type="date" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 预收课程费 -->
            <div v-else-if="exp._type === 'deferred_revenue'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">客户姓名</span>
                <input v-model="exp.customer_name" placeholder="客户姓名" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">总课时</span>
                <input v-model.number="exp.total_sessions" type="number" min="1" placeholder="10" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">课程类型</span>
                <select v-model="exp.course_type" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer">
                  <option value="1v1">线下1v1</option>
                  <option value="group">小班课</option>
                  <option value="online">线上课</option>
                </select>
              </div>
            </div>

            <!-- 押金/借出 (其他应收) -->
            <div v-else-if="exp._type === 'other_receivable'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">类型</span>
                <select v-model="exp.receivable_type" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer">
                  <option value="deposit">押金</option>
                  <option value="loan">借出</option>
                </select>
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">对方</span>
                <input v-model="exp.counterparty" placeholder="对方名称" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 收到押金 (其他应付) -->
            <div v-else-if="exp._type === 'other_payable'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">类型</span>
                <select v-model="exp.payable_type" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white cursor-pointer">
                  <option value="deposit">押金</option>
                  <option value="guarantee">保证金</option>
                </select>
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">对方</span>
                <input v-model="exp.counterparty" placeholder="对方名称" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 应付账款 -->
            <div v-else-if="exp._type === 'payable'" class="grid grid-cols-3 gap-2 text-sm">
              <div>
                <span class="text-gray-500 text-[10px]">供应商</span>
                <input v-model="exp.supplier" placeholder="供应商名称" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">到期日</span>
                <input v-model="exp.due_date" type="date" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
              <div>
                <span class="text-gray-500 text-[10px]">备注</span>
                <input v-model="exp.note" class="border border-gray-200 rounded px-2 py-1 text-sm w-full bg-white" />
              </div>
            </div>

            <!-- 📎 上传凭证（所有类型通用） -->
            <div class="mt-2 flex items-center gap-2 text-sm">
              <div v-if="exp.receipt_url" class="flex items-center gap-1.5 bg-green-50 border border-green-200 rounded px-2 py-1">
                <img v-if="/\.(jpg|jpeg|png|gif|webp)$/i.test(exp.receipt_url)" :src="exp.receipt_url" class="w-8 h-8 object-cover rounded" />
                <span v-else class="text-sm">📄</span>
                <span class="text-[10px] text-green-700 max-w-[100px] truncate">{{ exp.receipt_url.split('/').pop() }}</span>
                <button type="button" @click="exp.receipt_url = ''" class="text-red-400 hover:text-red-600 text-[10px] cursor-pointer">✕</button>
              </div>
              <label class="flex items-center gap-1 px-2 py-1 border border-dashed border-gray-300 rounded text-[10px] text-gray-500 hover:border-blue-400 hover:text-blue-500 cursor-pointer transition">
                <span>📷</span>
                <span>{{ exp._uploading ? '上传中...' : '上传凭证' }}</span>
                <input type="file" accept="image/*,.pdf" class="hidden" @change="handleReceiptUpload($event, exp)" :disabled="exp._uploading" />
              </label>
            </div>
          </div>

          <!-- Batch submit -->
          <div class="flex items-center justify-between pt-2">
            <span class="text-xs text-gray-500">
              共 {{ parsedExpenses.length }} 条，合计 ¥{{ parsedExpenses.reduce((s, e) => s + (Number(e.amount) || 0), 0).toLocaleString() }}
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
        <div v-if="parseError" class="mt-3 text-red-500 text-sm bg-red-50 rounded-lg px-3 py-2"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> {{ parseError }}
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
          ><Icon name="download" class="inline w-4 h-4 -mt-0.5 mr-1" /> 导出CSV
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
              <div class="flex items-center gap-1">
                {{ expense.payee }}
                <a v-if="expense.receipt_url" :href="expense.receipt_url" target="_blank" class="text-blue-500 hover:text-blue-700" title="查看凭证">📎</a>
              </div>
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
                ><Icon name="check-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 批准
                </button>
                <button
                  @click="handleApprove(expense, false)"
                  class="text-red-500 hover:text-red-600 text-xs font-medium cursor-pointer"
                ><Icon name="x-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 驳回
                </button>
              </template>
              <!-- Approved: Confirm Payment -->
              <template v-if="expense.status === 'approved' && canApprove">
                <button
                  @click="openPayModal(expense)"
                  class="text-blue-600 hover:text-blue-700 text-xs font-medium cursor-pointer"
                ><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 确认付款
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
                ><Icon name="edit" class="inline w-4 h-4 -mt-0.5 mr-1" /> 重新编辑
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
            <p v-if="form.amount > 2000 && !authStore.isAdmin" class="text-xs text-orange-500 mt-1"><Icon name="alert-triangle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 金额超过 ¥2,000，提交后将进入审批流程
            </p>
            <p v-if="authStore.isAdmin && form.amount > 2000" class="text-xs text-green-600 mt-1"><Icon name="check-circle" class="inline w-4 h-4 -mt-0.5 mr-1" /> 超级管理员：所有金额自动审批通过
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

          <!-- 上传凭证 -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">📎 上传凭证</label>
            <div class="space-y-2">
              <!-- 已上传的凭证预览 -->
              <div v-if="form.receipt_url" class="flex items-center gap-2 bg-green-50 border border-green-200 rounded-lg px-3 py-2">
                <img v-if="/\.(jpg|jpeg|png|gif|webp)$/i.test(form.receipt_url)" :src="form.receipt_url" class="w-12 h-12 object-cover rounded" />
                <span v-else class="text-lg">📄</span>
                <span class="text-xs text-green-700 flex-1 truncate">{{ form.receipt_url.split('/').pop() }}</span>
                <button type="button" @click="form.receipt_url = ''" class="text-red-400 hover:text-red-600 text-xs cursor-pointer">✕</button>
              </div>
              <!-- 上传按钮 -->
              <div class="flex gap-2">
                <label class="flex-1 flex items-center justify-center gap-2 px-3 py-2.5 border-2 border-dashed border-gray-300 rounded-lg text-sm text-gray-500 hover:border-blue-400 hover:text-blue-500 cursor-pointer transition">
                  <span>📷</span>
                  <span>{{ form._uploading ? '上传中...' : '拍照/选择图片' }}</span>
                  <input type="file" accept="image/*,.pdf" class="hidden" @change="handleReceiptUpload($event, form)" :disabled="form._uploading" />
                </label>
              </div>
              <!-- 或手动输入URL -->
              <details class="text-xs">
                <summary class="text-gray-400 cursor-pointer hover:text-gray-600">或手动输入链接</summary>
                <input
                  v-model="form.receipt_url"
                  type="url"
                  placeholder="https://example.com/receipt.jpg"
                  class="w-full mt-1 px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
                >
              </details>
            </div>
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
              {{ submitting ? '提交中...' : (form.amount > 2000 && !authStore.isAdmin ? '提交审批' : '确认提交') }}
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
          <h2 class="font-bold text-gray-800"><Icon name="wallet" class="inline w-4 h-4 -mt-0.5 mr-1" /> 确认付款</h2>
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
          <h2 class="font-bold text-gray-800"><Icon name="tag" class="inline w-4 h-4 -mt-0.5 mr-1" /> 支出类别管理</h2>
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
import { performStoreWithdrawal } from '../lib/storeWithdrawal'
import { formatMoney, EXPENSE_CATEGORIES, EXPENSE_STATUS, toast, formatDate, debounce } from '../lib/utils'
import { usePermission } from '../composables/usePermission'
import { randomPick, randomAmount, todayDate, PAYEES } from '../lib/testDataHelper'
import { dayEnd } from '../utils/dateRange'
import { ASSET_STATUS } from '../constants/enums'
import Icon from '../components/icons/Icons.vue'

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
      .is('deleted_at', null)
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
// ── 卡片样式映射 ──
function txnCardClass(type) {
  const map = {
    expense: 'border-purple-100 bg-purple-50/30',
    income: 'border-green-200 bg-green-50/30',
    transfer: 'border-blue-200 bg-blue-50/30',
    withdrawal: 'border-teal-200 bg-teal-50/30',
    fixed_asset: 'border-orange-200 bg-orange-50/30',
    prepaid: 'border-yellow-200 bg-yellow-50/30',
    deferred_revenue: 'border-emerald-200 bg-emerald-50/30',
    other_receivable: 'border-indigo-200 bg-indigo-50/30',
    other_payable: 'border-pink-200 bg-pink-50/30',
    payable: 'border-red-200 bg-red-50/30',
  }
  return map[type] || 'border-gray-200 bg-gray-50/30'
}

// 类别被手动修改时自动学习
function onCategoryChange(exp) {
  if (!exp.category || !exp._rawText) return
  // 从原文提取核心关键词用于学习
  const learnText = (exp.note || exp._rawText || '').toLowerCase().trim()
  if (learnText.length >= 2 && learnText.length <= 20) {
    saveLearnedCategory(learnText, exp.category)
    exp._confidence = 95
    exp._matchSource = 'learned'
    console.log(`[智能记账] 学习：「${learnText}」→「${exp.category}」`)
  }
  // 同时把原文中每个 2+ 字的词段都学习
  const words = learnText.split(/[\s,，、/]+/).filter(w => w.length >= 2)
  for (const w of words) {
    saveLearnedCategory(w, exp.category)
  }
}

// 切换类型时设置默认字段 + 触发学习提示
function onTypeChange(exp) {
  // 标记类型被手动修改，触发学习提示
  if (exp._type !== exp._originalType) {
    exp._typeChanged = true
    // 智能提取关键词：从原文中找出最可能的核心词
    exp._learnKeyword = extractLearnKeyword(exp._rawText, exp.note)
  } else {
    exp._typeChanged = false
  }

  if (exp._type === 'withdrawal') {
    // 切到店铺提现时，强制拉一次最新账户，防止新建的店铺没出现在下拉里
    accountStore._forceRefresh = true
    accountStore.fetchAccounts()
    // 若当前 account_id 不是电商店铺，清空让用户重新选
    const curAcc = accountStore.accounts.find(a => a.id === exp.account_id)
    if (!curAcc || curAcc.category !== 'ecommerce') {
      exp.account_id = ''
    }
    exp.fee_amount = exp.fee_amount != null ? exp.fee_amount : 0
    exp.fee_remark = exp.fee_remark || ''
    if (!exp.target_account_id) exp.target_account_id = ''
  } else if (exp._type === 'fixed_asset') {
    exp.asset_name = exp.asset_name || exp.note || ''
    exp.asset_category = exp.asset_category || 'equipment'
    exp.useful_life_years = exp.useful_life_years || 5
    exp.residual_rate = exp.residual_rate || 5
  } else if (exp._type === 'deferred_revenue') {
    exp.customer_name = exp.customer_name || exp.payee || ''
    exp.total_sessions = exp.total_sessions || 10
    exp.course_type = exp.course_type || '1v1'
  } else if (exp._type === 'other_receivable') {
    exp.receivable_type = exp.receivable_type || 'deposit'
    exp.counterparty = exp.counterparty || exp.payee || ''
  } else if (exp._type === 'other_payable') {
    exp.payable_type = exp.payable_type || 'deposit'
    exp.counterparty = exp.counterparty || exp.payee || ''
  } else if (exp._type === 'prepaid') {
    exp.supplier = exp.supplier || exp.payee || ''
  } else if (exp._type === 'payable') {
    exp.supplier = exp.supplier || exp.payee || ''
  }
}

// 从原文提取最可能的核心关键词（去掉日期、金额、账户名，留下有意义的词）
function extractLearnKeyword(rawText, note) {
  // 优先用清洗后的 note
  let text = (note || rawText || '').trim()
  // 去掉纯数字、日期、金额相关
  text = text.replace(/\d{1,2}月\d{1,2}日?/g, '')
  text = text.replace(/[￥¥]?\s*[\d,.]+\s*(万?)\s*元?/g, '')
  text = text.replace(/\s+/g, ' ').trim()
  // 如果剩余内容太长，取前4个字
  if (text.length > 6) text = text.slice(0, 6)
  return text
}

// 一键记住关键词
async function learnKeyword(exp) {
  const kw = (exp._learnKeyword || '').trim()
  if (!kw) { toast('请输入要记住的关键词', 'warning'); return }

  // 店铺提现：关键词挂在选中店铺的 withdraw_keywords 字段上（按店铺区分），
  // 不进全局 transaction_type_keywords 表
  if (exp._type === 'withdrawal') {
    if (!exp.account_id) { toast('请先选择提现店铺', 'warning'); return }
    const store = accountStore.accounts.find(a => a.id === exp.account_id)
    if (!store) { toast('店铺不存在', 'error'); return }
    if (store.category !== 'ecommerce') { toast('所选账户不是电商店铺', 'warning'); return }

    const existingKws = Array.isArray(store.withdraw_keywords) ? store.withdraw_keywords : []
    if (existingKws.some(k => (k || '').toLowerCase() === kw.toLowerCase())) {
      toast(`「${kw}」已在 ${store.short_name || store.code} 的提现关键词里`, 'warning')
      exp._typeChanged = false
      return
    }
    // 检查冲突：同一关键词挂在别的店铺上会导致解析歧义
    const conflict = accountStore.accounts.find(a => {
      if (a.id === store.id) return false
      const kws = Array.isArray(a.withdraw_keywords) ? a.withdraw_keywords : []
      return kws.some(k => (k || '').toLowerCase() === kw.toLowerCase())
    })
    if (conflict) {
      if (!confirm(`⚠️ 关键词「${kw}」已挂在另一个店铺「${conflict.short_name || conflict.code}」上。\n继续可能导致解析匹配错店铺。\n\n是否仍要添加？`)) return
    }
    try {
      await accountStore.updateAccount(store.id, { withdraw_keywords: [...existingKws, kw] })
      exp._typeChanged = false
      toast(`已记住：「${kw}」→ ${store.short_name || store.code}（店铺提现），下次自动识别`, 'success')
    } catch (e) {
      toast('保存失败: ' + (e.message || ''), 'error')
    }
    return
  }

  // 其余类型：走全局 transaction_type_keywords 表
  if (typeKeywords.value.some(t => t.keyword === kw)) {
    toast(`「${kw}」已存在`, 'warning')
    exp._typeChanged = false
    return
  }
  const { data, error } = await supabase.from('transaction_type_keywords').insert({
    transaction_type: exp._type,
    keyword: kw,
    target_table: TARGET_TABLE_MAP[exp._type] || 'expenses',
    description: `${TYPE_LABELS[exp._type] || exp._type}-${kw}（自动学习）`,
  }).select().single()
  if (error) {
    toast('保存失败: ' + (error.message || ''), 'error')
    return
  }
  typeKeywords.value.push(data)
  exp._typeChanged = false
  toast(`已记住：「${kw}」→ ${TYPE_LABELS[exp._type]}，下次自动识别`, 'success')
}

// ══════════════════════════════════════════════════════════
// 🧠 账户关键词智能学习
// 当用户在解析结果里手动切换账户时，触发学习提示框
// 确认后把关键词写入 accounts 表的 expense_keywords / income_keywords JSONB 字段
// ══════════════════════════════════════════════════════════

// 从原文提取"候选账户关键词"：优先抓最前面的 2-4 个中文字（通常是账户别名）
function extractAccountKeyword(rawText) {
  let text = (rawText || '').split('\t')[0] || ''  // 去掉 ￥ 金额
  text = text.replace(/\d{1,2}月\d{1,2}日?/g, '')
  text = text.replace(/\d{1,2}日/g, '')
  text = text.replace(/[￥¥]?\s*[\d,.]+\s*(万?)\s*元?/g, '')
  text = text.trim()
  // 取开头的连续中文 2-4 个字
  const head = text.match(/^[\u4e00-\u9fa5]{2,4}/)
  if (head) return head[0]
  // 退而求其次：取前 3 个字符
  return text.slice(0, 3)
}

// 账户下拉变化处理：判断是不是用户手动改的（和解析器填的不同）
function handleAccountChange(exp, newAccountId) {
  exp.account_id = newAccountId
  if (newAccountId && newAccountId !== exp._originalAccountId) {
    exp._accountChanged = true
    if (!exp._learnAccountKeyword) {
      exp._learnAccountKeyword = extractAccountKeyword(exp._rawText)
    }
  } else {
    exp._accountChanged = false
  }
  // 店铺提现：切换店铺时，若该店铺有默认提现账户且当前未指定目标，自动预选
  if (exp._type === 'withdrawal' && newAccountId && !exp.target_account_id) {
    const acc = accountStore.accounts.find(a => a.id === newAccountId)
    if (acc && acc.default_withdraw_account_id) {
      exp.target_account_id = acc.default_withdraw_account_id
    }
  }
}

// 一键把关键词学到账户上
async function learnAccountKeyword(exp) {
  const kw = (exp._learnAccountKeyword || '').trim()
  if (!kw) { toast('请输入要记住的关键词', 'warning'); return }
  if (!exp.account_id) { toast('请先选择账户', 'warning'); return }
  if (exp._type !== 'expense' && exp._type !== 'income') {
    toast('仅支持收入/支出类型的账户关键词学习', 'warning'); return
  }
  const account = accountStore.accounts.find(a => a.id === exp.account_id)
  if (!account) { toast('账户不存在', 'error'); return }

  const field = exp._type === 'income' ? 'income_keywords' : 'expense_keywords'
  const existingKws = Array.isArray(account[field]) ? account[field] : []
  if (existingKws.some(k => (k || '').toLowerCase() === kw.toLowerCase())) {
    toast(`「${kw}」已经在 ${account.short_name || account.code} 的${exp._type === 'income' ? '收入' : '支出'}关键词里了`, 'warning')
    exp._accountChanged = false
    return
  }

  // 检查关键词是否会和其他账户冲突（同一个词挂在多个账户上会解析错乱）
  const conflictAccount = accountStore.accounts.find(a => {
    if (a.id === account.id) return false
    const kws = Array.isArray(a[field]) ? a[field] : []
    return kws.some(k => (k || '').toLowerCase() === kw.toLowerCase())
  })
  if (conflictAccount) {
    if (!confirm(`⚠️ 关键词「${kw}」已经挂在另一个账户「${conflictAccount.short_name || conflictAccount.code}」上。\n继续会导致解析时可能匹配错账户。\n\n是否仍要添加？`)) {
      return
    }
  }

  const newKws = [...existingKws, kw]
  try {
    await accountStore.updateAccount(account.id, { [field]: newKws })
    toast(`已记住：「${kw}」→ ${account.short_name || account.code}（${exp._type === 'income' ? '收入' : '支出'}），下次自动识别`, 'success')
    exp._accountChanged = false
    exp._originalAccountId = exp.account_id  // 避免同一行再次触发学习提示
  } catch (e) {
    toast('保存失败: ' + (e.message || ''), 'error')
  }
}

// ── 从 DB 加载类型关键词 ──
const typeKeywords = ref([])
async function loadTypeKeywords() {
  const { data } = await supabase.from('transaction_type_keywords').select('*').order('keyword')
  typeKeywords.value = data || []
}
loadTypeKeywords()

// 根据文本匹配交易类型（先匹配 DB 关键词，再 fallback 到硬编码）
function matchTransactionType(text) {
  const lower = text.toLowerCase()
  // 按关键词长度降序匹配，长关键词优先
  const sorted = [...typeKeywords.value].sort((a, b) => b.keyword.length - a.keyword.length)
  for (const tk of sorted) {
    if (lower.includes(tk.keyword.toLowerCase())) {
      return { type: tk.transaction_type, description: tk.description }
    }
  }
  return null
}

// ── 关键词管理面板 ──
const showKeywordManager = ref(false)
const newKwType = ref('fixed_asset')
const newKwText = ref('')
const kwManagerError = ref('')

const TYPE_LABELS = {
  expense: '💸 支出', income: '💰 收入', transfer: '🔄 转账', withdrawal: '💱 店铺提现',
  fixed_asset: '🏗️ 固定资产', prepaid: '📦 预付账款', deferred_revenue: '🎓 预收账款',
  other_receivable: '💰 押金/借出', other_payable: '📥 收到押金', payable: '📋 应付账款',
  salary: '👥 工资', dividend: '💎 分红',
}

const TARGET_TABLE_MAP = {
  fixed_asset: 'assets', prepaid: 'prepaid_accounts', deferred_revenue: 'deferred_revenue',
  other_receivable: 'other_receivables', other_payable: 'other_payables', payable: 'payable_accounts',
  salary: 'salaries', dividend: 'dividends',
}

// 按类型分组
const groupedTypeKeywords = computed(() => {
  const groups = {}
  for (const kw of typeKeywords.value) {
    if (!groups[kw.transaction_type]) groups[kw.transaction_type] = []
    groups[kw.transaction_type].push(kw)
  }
  return groups
})

function typeColorClass(t) {
  const map = {
    fixed_asset: 'text-orange-600', prepaid: 'text-yellow-600', deferred_revenue: 'text-emerald-600',
    other_receivable: 'text-indigo-600', other_payable: 'text-pink-600', payable: 'text-red-600',
    salary: 'text-blue-600', dividend: 'text-purple-600',
  }
  return map[t] || 'text-gray-600'
}

function typeTagClass(t) {
  const map = {
    fixed_asset: 'bg-orange-50 text-orange-700 border-orange-200',
    prepaid: 'bg-yellow-50 text-yellow-700 border-yellow-200',
    deferred_revenue: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    other_receivable: 'bg-indigo-50 text-indigo-700 border-indigo-200',
    other_payable: 'bg-pink-50 text-pink-700 border-pink-200',
    payable: 'bg-red-50 text-red-700 border-red-200',
    salary: 'bg-blue-50 text-blue-700 border-blue-200',
    dividend: 'bg-purple-50 text-purple-700 border-purple-200',
  }
  return map[t] || 'bg-gray-50 text-gray-700 border-gray-200'
}

async function addTypeKeyword() {
  const kw = newKwText.value.trim()
  kwManagerError.value = ''
  if (!kw) { kwManagerError.value = '请输入关键词'; return }
  if (typeKeywords.value.some(t => t.keyword === kw)) {
    kwManagerError.value = `「${kw}」已存在`
    return
  }
  const { data, error } = await supabase.from('transaction_type_keywords').insert({
    transaction_type: newKwType.value,
    keyword: kw,
    target_table: TARGET_TABLE_MAP[newKwType.value] || 'expenses',
    description: `${TYPE_LABELS[newKwType.value] || newKwType.value}-${kw}`,
  }).select().single()
  if (error) {
    kwManagerError.value = error.message.includes('unique') ? `「${kw}」已存在` : '保存失败: ' + error.message
    return
  }
  typeKeywords.value.push(data)
  newKwText.value = ''
  toast(`关键词「${kw}」已添加`, 'success')
}

async function deleteTypeKeyword(id) {
  const kw = typeKeywords.value.find(t => t.id === id)
  if (!kw) return
  if (!confirm(`确定删除关键词「${kw.keyword}」？`)) return
  await supabase.from('transaction_type_keywords').delete().eq('id', id)
  typeKeywords.value = typeKeywords.value.filter(t => t.id !== id)
  toast('已删除', 'success')
}

// ══════════════════════════════════════════════════════════
// 智能类别匹配引擎 v2
// 三层匹配：① 用户学习记忆 → ② 扩展关键词库 → ③ DB类别名模糊匹配
// ══════════════════════════════════════════════════════════

// 第①层：用户学习记忆（localStorage）
// 当用户手动修改类别后自动记录，下次同样文本直接命中
const LEARNED_STORAGE_KEY = 'smart_entry_learned_categories'
function getLearnedCategories() {
  try { return JSON.parse(localStorage.getItem(LEARNED_STORAGE_KEY) || '{}') } catch { return {} }
}
function saveLearnedCategory(keyword, category) {
  const learned = getLearnedCategories()
  learned[keyword.toLowerCase()] = category
  // 限制最多保存500条，超出删最旧的
  const keys = Object.keys(learned)
  if (keys.length > 500) { delete learned[keys[0]] }
  localStorage.setItem(LEARNED_STORAGE_KEY, JSON.stringify(learned))
}

// 第②层：扩展关键词库（硬编码 + DB类别名衍生）
// 顺序即优先级，长关键词优先匹配（避免"直播"被"工资"截胡）
const CATEGORY_KEYWORD_MAP = {
  '直播费用': ['直播费用', '直播费', '直播', '控评', '出场费', '选手'],
  '投流': ['投流', '信息流', '投放', '千川', 'dou+', 'DOU+'],
  '球杆采购': ['球杆', '杆头', '皮头', '球杆采购'],
  '配件采购': ['配件', '胶带', '手套', '巧粉', '球袋', '铜嘴'],
  '运费': ['物流', '快递', '运费', '邮费', '发货', '顺丰', '中通', '圆通', '韵达', '极兔', '德邦'],
  '包装费': ['包装', '打包', '纸箱', '气泡膜'],
  '工资': ['工资', '薪水', '薪资', '人员工资', '兼职薪资', '底薪', '提成'],
  '社保费': ['社保', '公积金', '五险', '医保'],
  '房租': ['房租', '物业', '租金', '场地费', '场地租'],
  '水电': ['水电', '电费', '水费', '水电费', '网费', '宽带'],
  '广告推广': ['推广', '广告', '营销', '宣传', '引流'],
  '平台手续费': ['平台费', '服务费', '手续费', '有赞', '抖店', '星橙', '技术服务费', '佣金'],
  '退款': ['退款', '售后', '赔偿', '补发', '退货'],
  '办公费': ['办公费', '办公', 'A4纸', '文具', '耗材', '打印', '办公用品'],
  '缴纳税费': ['税费', '税款', '增值税', '所得税', '发票', '缴税'],
  '差旅费': ['差旅', '出差', '机票', '高铁', '火车票', '住宿'],
  '培训费': ['培训', '学习', '课程', '考试'],
  '维修费': ['维修', '维护', '修理', '换件'],
  '招待费': ['招待', '餐费', '饭费', '聚餐', '请客'],
  '样品费': ['样品', '打样'],
  '交通费': ['交通', '打车', '滴滴', '加油', '停车', '过路费', 'ETC'],
  '通讯费': ['通讯', '话费', '流量', '充流量'],
  '拍摄道具/工具': ['拍摄', '道具', '摄影', '补光灯', '三脚架'],
  '软件服务费': ['软件', '系统', '会员', '订阅', 'SaaS', 'ERP'],
  '团建费': ['团建聚餐', '团建活动', '团建', '年会聚餐', '年会'],
  '福利费': ['福利', '节日', '红包', '礼品'],
  '招聘费': ['招聘', 'BOSS直聘', '猎头'],
  '好评返现': ['好评', '返现', '好评返'],
  '收号费': ['收号', '买号'],
  '品牌设计服务费': ['设计', 'logo', 'LOGO', 'VI', '品牌设计'],
  '安装费': ['安装', '调试'],
  '商标费': ['商标', '专利'],
  '其他': [],
}

// 构建扁平化的关键词→类别索引（长关键词优先）
let _flatCategoryIndex = null
function getFlatCategoryIndex() {
  if (_flatCategoryIndex) return _flatCategoryIndex
  const pairs = []
  for (const [cat, kws] of Object.entries(CATEGORY_KEYWORD_MAP)) {
    for (const kw of kws) pairs.push({ kw: kw.toLowerCase(), cat })
  }
  // 长关键词优先匹配
  pairs.sort((a, b) => b.kw.length - a.kw.length)
  _flatCategoryIndex = pairs
  return pairs
}

// 第③层：DB类别名直接匹配（"直播费用"文本里包含DB类别名"直播费用"→直接命中）
// 在 loadCategories 之后自动可用
const dbCategoryNames = ref([])

function matchCategory(text) {
  const lower = text.toLowerCase()

  // ① 用户学习记忆（精确词匹配）
  const learned = getLearnedCategories()
  // 按关键词长度降序匹配（长词优先）
  const learnedKeys = Object.keys(learned).sort((a, b) => b.length - a.length)
  for (const kw of learnedKeys) {
    if (lower.includes(kw)) return { category: learned[kw], confidence: 95, source: 'learned' }
  }

  // ② 扩展关键词库
  const index = getFlatCategoryIndex()
  for (const { kw, cat } of index) {
    if (lower.includes(kw)) return { category: cat, confidence: 85, source: 'keyword' }
  }

  // ③ DB类别名直接匹配（如果文本包含某个完整类别名）
  // 按名称长度降序（"配件采购"优先于"采购"）
  const sortedDbNames = [...dbCategoryNames.value].sort((a, b) => b.length - a.length)
  for (const name of sortedDbNames) {
    if (lower.includes(name.toLowerCase())) return { category: name, confidence: 70, source: 'db_name' }
  }

  return { category: '其他', confidence: 0, source: 'none' }
}

// 从文本中智能提取收款方/对方名称
function extractPayee(text, matchedKw) {
  let cleaned = text
  // 去掉日期
  cleaned = cleaned.replace(/\d{1,2}月?\d{0,2}日?/g, '')
  // 去掉金额
  cleaned = cleaned.replace(/[￥¥]\s*[\d,.]+/g, '')
  cleaned = cleaned.replace(/\d[\d,.]*\s*[元万]/g, '')
  // 去掉已匹配的关键词
  if (matchedKw) cleaned = cleaned.replace(new RegExp(matchedKw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), '')
  cleaned = cleaned.trim()
  // 去掉常见的动词前缀
  cleaned = cleaned.replace(/^(付|交|给|转|买|购|充|缴|报销|支付)\s*/g, '')
  // 去掉常见的类型后缀词（工资、报销、费用等），以便提取人名
  cleaned = cleaned.replace(/(工资|薪水|薪资|报销|费用|分红|奖金|补贴|提成)\s*$/g, '')
  cleaned = cleaned.replace(/\s+/g, ' ').trim()
  // 如果剩余内容是 2-20 个字符，可能是人名/公司名
  if (cleaned.length >= 2 && cleaned.length <= 20 && !/^\d+$/.test(cleaned)) {
    return cleaned
  }
  return ''
}

// ══════════════════════════════════════════════════════════
// 账户模糊匹配：输入"达一般户"能命中"达公户-一般户"
// 策略：精确 > 子串包含 > 字符按顺序出现（子序列）
// 归一化：去掉空格/连字符/分隔符，比较更宽松
// ══════════════════════════════════════════════════════════
function fuzzyMatchAccount(input, accounts) {
  if (!input) return null
  const norm = s => (s || '').replace(/[\s\-_·•・—－]/g, '')
  const ni = norm(input)
  if (!ni) return null

  let best = null
  let bestScore = -1
  for (const acc of accounts) {
    const target = norm(acc.short_name || acc.code)
    if (!target) continue
    let score = -1
    if (target === ni) return acc
    if (target.includes(ni) || ni.includes(target)) {
      score = 1000 - Math.abs(target.length - ni.length)
    } else {
      // 子序列：输入字符按顺序出现在目标里
      let i = 0
      for (const c of target) {
        if (c === ni[i]) i++
        if (i === ni.length) break
      }
      if (i === ni.length) score = 500 - Math.abs(target.length - ni.length)
    }
    if (score > bestScore) { bestScore = score; best = acc }
  }
  return best
}

// ══════════════════════════════════════════════════════════
// 配对转账识别（两半）：
//   "达一般户支出300.01，达基本户收到300.01"
//   "达一般户-300，达基本户+300"
// ══════════════════════════════════════════════════════════
const OUT_VERBS = '支出|转出|付出|给出|扣款|扣除|划出|划走|出账|转走|付'
const IN_VERBS  = '收到|转入|入账|到账|收款|进账|打来|打入|汇入|增加'
function tryPairTransfer(line, accounts) {
  const parts = line.split(/[,,;;、\n]/).map(s => s.trim()).filter(Boolean)
  if (parts.length < 2) return null
  const outs = [], ins = []
  const reOut = new RegExp(`^(.+?)(?:${OUT_VERBS})\\s*([\\d,]+(?:\\.\\d+)?)\\s*(?:元)?$`)
  const reIn  = new RegExp(`^(.+?)(?:${IN_VERBS})\\s*([\\d,]+(?:\\.\\d+)?)\\s*(?:元)?$`)
  // 符号式：-300 出；+300 入
  const reNeg = /^(.+?)\s*[-－]\s*([\d,]+(?:\.\d+)?)\s*(?:元)?$/
  const rePos = /^(.+?)\s*[+＋]\s*([\d,]+(?:\.\d+)?)\s*(?:元)?$/
  for (const p of parts) {
    let m = p.match(reOut)
    if (m) { outs.push({ name: m[1].trim(), amount: parseFloat(m[2].replace(/,/g, '')) }); continue }
    m = p.match(reIn)
    if (m) { ins.push({ name: m[1].trim(), amount: parseFloat(m[2].replace(/,/g, '')) }); continue }
    m = p.match(reNeg)
    if (m) { outs.push({ name: m[1].trim(), amount: parseFloat(m[2].replace(/,/g, '')) }); continue }
    m = p.match(rePos)
    if (m) { ins.push({ name: m[1].trim(), amount: parseFloat(m[2].replace(/,/g, '')) }); continue }
  }
  if (outs.length === 0 || ins.length === 0) return null
  for (const o of outs) {
    for (const i of ins) {
      if (Math.abs(o.amount - i.amount) < 0.001) {
        const fromAcc = fuzzyMatchAccount(o.name, accounts)
        const toAcc = fuzzyMatchAccount(i.name, accounts)
        if (fromAcc && toAcc && fromAcc.id !== toAcc.id) {
          return {
            amount: o.amount,
            fromId: fromAcc.id, fromLabel: fromAcc.short_name || fromAcc.code,
            toId: toAcc.id,     toLabel: toAcc.short_name || toAcc.code,
            fromInput: o.name, toInput: i.name,
          }
        }
      }
    }
  }
  return null
}

// ══════════════════════════════════════════════════════════
// 单行转账识别（一行一笔）：
//   "达一般户→达基本户 300.01"           箭头式
//   "达一般户转达基本户 300"              单字"转"
//   "达一般户转到达基本户 300"            转到/转给/转至/转入
//   "达一般户转账到达基本户 300"          转账到/转账至/转账给
//   "达一般户划款到达基本户 300"          划款到/划到/划至
//   "达一般户打款到达基本户 300"          打款到/打到
//   "达一般户汇到达基本户 300"            汇到/汇至
//   "从达一般户到达基本户 300"            从 A 到 B
//   "达一般户 转 300 到 达基本户"         A 动词 金额 到 B
//   "300 达一般户→达基本户"               金额前置箭头
// ══════════════════════════════════════════════════════════
function tryInlineTransfer(line, accounts) {
  // 归一化：全角数字/小数点 → 半角
  const ln = line
    .replace(/[０-９]/g, c => String.fromCharCode(c.charCodeAt(0) - 0xff10 + 0x30))
    .replace(/．/g, '.')
    .trim()

  // 候选 pattern。顺序：先精确/复合动词，再单字 fallback
  const patterns = [
    // 1) 箭头式：A → B 300
    { re: /^(.+?)\s*(?:→|->|—>|=>|⇒|➡|➔|⟶)\s*(.+?)\s*([\d,]+(?:\.\d+)?)\s*(?:元)?$/, map: m => ({ from: m[1], to: m[2], amt: m[3] }) },
    // 2) 金额前置：300 A → B
    { re: /^([\d,]+(?:\.\d+)?)\s*(?:元)?\s+(.+?)\s*(?:→|->|⇒|➡)\s*(.+?)$/, map: m => ({ from: m[2], to: m[3], amt: m[1] }) },
    // 3) 从 A 到 B 300
    { re: /^从\s*(.+?)\s*(?:到|转到|转至|划至|汇至|打到|转|汇|划|打)\s*(.+?)\s+([\d,]+(?:\.\d+)?)\s*(?:元)?$/, map: m => ({ from: m[1], to: m[2], amt: m[3] }) },
    // 4) A <复合动词> B 金额
    { re: /^(.+?)\s*(?:转账到|转账至|转账给|转给|转至|转到|转入|划转到|划转至|划款到|划款至|打款到|打款至|打款给|汇款到|汇款至|汇到|汇至|汇给)\s*(.+?)\s*([\d,]+(?:\.\d+)?)\s*(?:元)?$/, map: m => ({ from: m[1], to: m[2], amt: m[3] }) },
    // 5) A <单字动词> 金额 到/给/至/入 B
    { re: /^(.+?)\s*(?:转|划|汇|打)\s*([\d,]+(?:\.\d+)?)\s*(?:元)?\s*(?:到|给|至|入|进)\s*(.+?)$/, map: m => ({ from: m[1], amt: m[2], to: m[3] }) },
    // 6) A 转 B 金额(最弱的 fallback)
    { re: /^(.+?)\s*(?:转|划|汇)\s*(.+?)\s+([\d,]+(?:\.\d+)?)\s*(?:元)?$/, map: m => ({ from: m[1], to: m[2], amt: m[3] }) },
  ]

  for (const p of patterns) {
    const m = ln.match(p.re)
    if (!m) continue
    const mapped = p.map(m)
    const fromName = mapped.from.trim()
    const toName = mapped.to.trim()
    const amount = parseFloat(String(mapped.amt).replace(/,/g, ''))
    if (!fromName || !toName || !amount || amount <= 0) continue
    const fromAcc = fuzzyMatchAccount(fromName, accounts)
    const toAcc = fuzzyMatchAccount(toName, accounts)
    if (fromAcc && toAcc && fromAcc.id !== toAcc.id) {
      return {
        amount,
        fromId: fromAcc.id, fromLabel: fromAcc.short_name || fromAcc.code,
        toId: toAcc.id, toLabel: toAcc.short_name || toAcc.code,
        fromInput: fromName, toInput: toName,
      }
    }
  }
  return null
}

function parseExpenseText(text) {
  const results = []

  // ── 构建关键词索引（从DB字段读取） ──
  const activeAccs = accountStore.getActiveAccounts()

  // 1. 账户名匹配表（含 short_name 和 payment_alias）
  const accountNameMap = {}
  for (const a of activeAccs) {
    const names = [(a.short_name || a.code)].filter(Boolean)
    if (a.payment_alias) names.push(a.payment_alias)
    for (const n of names) {
      accountNameMap[n] = { id: a.id, label: a.short_name || a.code }
    }
  }
  const accountNames = Object.keys(accountNameMap).sort((a, b) => b.length - a.length)

  // 2. 收入/支出/转账/提现关键词索引（从 accounts 的 JSONB 字段读取）
  const expenseKwMap = {}
  const incomeKwMap = {}
  const transferKwMap = {}
  const withdrawKwMap = {}              // 关键词 → 电商店铺
  const ecommerceNameMap = {}           // 电商店铺名 → 店铺（用于"搜到对应名称自动匹配"）
  for (const a of activeAccs) {
    const label = a.short_name || a.code
    for (const kw of (a.expense_keywords || [])) {
      expenseKwMap[kw] = { id: a.id, label }
    }
    for (const kw of (a.income_keywords || [])) {
      incomeKwMap[kw] = { id: a.id, label }
    }
    for (const rule of (a.transfer_rules || [])) {
      transferKwMap[rule.keyword] = { source_id: a.id, source_label: label, target_id: rule.target_account_id }
    }
    if (a.category === 'ecommerce') {
      for (const kw of (a.withdraw_keywords || [])) {
        withdrawKwMap[kw] = { source_id: a.id, source_label: label, target_id: a.default_withdraw_account_id || '' }
      }
      // 店铺名本身（以及 short_name 的中文主体）也纳入识别
      if (a.short_name && a.short_name.length >= 2) {
        ecommerceNameMap[a.short_name] = { source_id: a.id, source_label: label, target_id: a.default_withdraw_account_id || '' }
      }
    }
  }
  const allExpKws = Object.keys(expenseKwMap).sort((a, b) => b.length - a.length)
  const allIncKws = Object.keys(incomeKwMap).sort((a, b) => b.length - a.length)
  const allTransKws = Object.keys(transferKwMap).sort((a, b) => b.length - a.length)
  const allWithdrawKws = Object.keys(withdrawKwMap).sort((a, b) => b.length - a.length)
  const allEcommerceNames = Object.keys(ecommerceNameMap).sort((a, b) => b.length - a.length)

  // ══ Step 0: 拆分条目 ══
  // 格式：描述部分 ￥X,XXX.XX（一行可能多条，用 ￥ 金额作为分隔锚点）
  // 也支持旧格式（无 ￥ 后缀，纯文本每行一条）
  const entries = []
  const entryRegex = /([^￥¥\n]+?)\s*[￥¥]\s*([\d,]+\.?\d*)/g
  let m
  while ((m = entryRegex.exec(text)) !== null) {
    const desc = m[1].trim()
    const fmtAmount = parseFloat(m[2].replace(/,/g, ''))
    if (desc && fmtAmount > 0) {
      entries.push({ desc, fmtAmount })
    }
  }
  // 如果没有 ￥ 格式，回退到按行分割
  if (entries.length === 0) {
    const lines = text.split('\n').map(l => l.trim()).filter(Boolean)
    for (const line of lines) {
      entries.push({ desc: line, fmtAmount: 0 })
    }
  }

  for (const { desc, fmtAmount } of entries) {
    const line = desc

    // ── Step 0: 转账识别 ──
    // 先尝试配对式("A支出N, B收到N"),再尝试单行式("A→B N" / "A 转 B N" ...)
    const pair = tryPairTransfer(line, activeAccs) || tryInlineTransfer(line, activeAccs)
    if (pair) {
      const noteText = `${pair.fromInput} → ${pair.toInput}`.trim()
      results.push({
        _rawText: desc,
        _type: 'transfer',
        _originalType: 'transfer',
        _typeChanged: false,
        _learnKeyword: '',
        _confidence: 95,
        _matchSource: 'pair',
        _uploading: false,
        _originalAccountId: pair.fromId,
        _accountChanged: false,
        _learnAccountKeyword: '',
        account_id: pair.fromId,
        account_label: pair.fromLabel,
        amount: pair.amount,
        category: '',
        payee: '',
        note: noteText,
        receipt_url: '',
        _dayOfMonth: null,
        _monthNum: null,
        expense_date: new Date().toISOString().slice(0, 10),
        target_account_id: pair.toId,
      })
      continue
    }

    let type = 'expense'
    let matchedAccountId = ''
    let matchedAccount = ''
    let targetAccountId = ''

    // ── Step 1: 关键词匹配（优先级：店铺提现 > 店铺名 > 转账 > 收入 > 支出） ──
    let matchedKw = ''
    // 店铺自定义的提现关键词优先（最精确）
    for (const kw of allWithdrawKws) {
      if (line.includes(kw)) {
        type = 'withdrawal'
        matchedAccountId = withdrawKwMap[kw].source_id
        matchedAccount = withdrawKwMap[kw].source_label
        targetAccountId = withdrawKwMap[kw].target_id
        matchedKw = kw
        break
      }
    }
    // 命中店铺名 + "提现"字样 → withdrawal
    if (!matchedKw && /提现/.test(line)) {
      for (const name of allEcommerceNames) {
        if (line.includes(name)) {
          type = 'withdrawal'
          matchedAccountId = ecommerceNameMap[name].source_id
          matchedAccount = ecommerceNameMap[name].source_label
          targetAccountId = ecommerceNameMap[name].target_id
          matchedKw = name
          break
        }
      }
    }
    if (!matchedKw) {
      for (const kw of allTransKws) {
        if (line.includes(kw)) {
          type = 'transfer'
          matchedAccountId = transferKwMap[kw].source_id
          matchedAccount = transferKwMap[kw].source_label
          targetAccountId = transferKwMap[kw].target_id
          matchedKw = kw
          break
        }
      }
    }
    if (!matchedKw) {
      for (const kw of allIncKws) {
        if (line.includes(kw)) {
          type = 'income'
          matchedAccountId = incomeKwMap[kw].id
          matchedAccount = incomeKwMap[kw].label
          matchedKw = kw
          break
        }
      }
    }
    if (!matchedKw) {
      for (const kw of allExpKws) {
        if (line.includes(kw)) {
          type = 'expense'
          matchedAccountId = expenseKwMap[kw].id
          matchedAccount = expenseKwMap[kw].label
          matchedKw = kw
          break
        }
      }
    }

    // Fallback: 内置类型规则（覆盖最常见的"支出/收入/转账/提现"场景）
    // 优先级：特定组合 > 通用词。长表达式先匹配，避免短词"转账"/"到账"误吞
    if (!matchedKw) {
      // ── 第一优先级：容易误判的特定组合（必须在通用规则之前） ──
      // "微信转账给xxx" / "支付宝转给xxx" 是支出（付款给别人），不是内部转账
      if (/转账.*给|转.*给[^账]|转给/.test(line)) {
        type = 'expense'
      }
      // "退税到账" / "退税" 是收入，不是转账
      else if (/退税|税费返还/.test(line)) {
        type = 'income'
      }
      // "下单收款" / "客户付款" / "xxx回款" 是收入
      else if (/下单|收款|其他收入|营业收入|销售收入|回款/.test(line)) {
        type = 'income'
      }

      // ── 第二优先级：提现类（店铺/平台 → 银行卡，走专用 withdrawal 卡片） ──
      else if (/店铺提现|抖店提现|有赞提现|平台提现|淘宝提现|拼多多提现/.test(line)) {
        type = 'withdrawal'
      }
      // 通用提现（微信/支付宝/"提现"）仍按转账处理，保持旧行为
      else if (/微信提现|支付宝提现|提现到|提现/.test(line)) {
        type = 'transfer'
      }

      // ── 第三优先级：内部转账 ──
      else if (/到账$|到账-|公户收|银行.*转入|转入.*银行/.test(line)) {
        type = 'transfer'
      } else if (/^(转卡|转余利宝|转中信|转支付宝|转平安|任公户.*转|公户.*转)/.test(line)) {
        type = 'transfer'
      } else if (/转账(?!手续)|互转|划转|调拨|内部转/.test(line)) {
        type = 'transfer'
      }

      // 账户名匹配
      for (const name of accountNames) {
        if (line.startsWith(name)) {
          matchedAccountId = accountNameMap[name].id
          matchedAccount = accountNameMap[name].label
          matchedKw = name
          break
        }
      }
      if (!matchedAccountId) {
        for (const name of accountNames) {
          if (line.includes(name) && name.length >= 2) {
            matchedAccountId = accountNameMap[name].id
            matchedAccount = accountNameMap[name].label
            break
          }
        }
      }
    }

    // ── Step 2: 资产/台账类型识别 ──
    const typeMatch = matchTransactionType(line)
    if (typeMatch) {
      type = typeMatch.type
    }

    // ── Step 3: 提取金额（优先用 ￥ 格式金额，否则从描述提取） ──
    let amount = fmtAmount
    if (!amount) {
      // 万元
      const wan = line.match(/([\d.]+)\s*万/)
      if (wan && parseFloat(wan[1]) > 0) {
        amount = parseFloat(wan[1]) * 10000
      } else {
        // 匹配 XXXX元 或 XXXX.XX元（排除 XX日 的数字）
        // 先尝试带"元"的精确匹配
        const amtYuan = line.match(/(\d[\d,.]*)\s*元/)
        if (amtYuan) {
          amount = parseFloat(amtYuan[1].replace(/,/g, ''))
        } else {
          // 再尝试独立数字（排除 XX日、XX月、XX号、XX%、XX个 等）
          const nums = [...line.matchAll(/(?<!\d)(\d[\d,.]*\.?\d*)(?!\s*[日月号%个h])/g)]
          // 取最大的数字作为金额（通常金额是最大的数）
          let maxNum = 0
          for (const nm of nums) {
            const v = parseFloat(nm[1].replace(/,/g, ''))
            if (v > maxNum) maxNum = v
          }
          if (maxNum > 0) amount = maxNum
        }
      }
    }

    // ── Step 4: 提取日期 ──
    // 支持格式：XX月XX日、XX日、MM/DD
    let dayOfMonth = null
    let monthNum = null
    const dmFull = line.match(/(\d{1,2})月(\d{1,2})日?/)
    if (dmFull) {
      monthNum = parseInt(dmFull[1])
      dayOfMonth = parseInt(dmFull[2])
    } else {
      const dOnly = line.match(/(\d{1,2})日/)
      if (dOnly) {
        dayOfMonth = parseInt(dOnly[1])
      }
    }

    // ── Step 5: 提取备注（去掉已识别的部分） ──
    let note = line
    if (matchedKw) note = note.replace(matchedKw, '')
    // 去掉日期部分
    note = note.replace(/\d{1,2}月\d{1,2}日?/g, '')
    note = note.replace(/\d{1,2}日/g, '')
    // 去掉金额部分（带元的数字、纯大数字）
    note = note.replace(/\d[\d,.]*\s*元/g, '')
    // 去掉账户名
    for (const name of accountNames) note = note.replace(new RegExp(name, 'g'), '')
    note = note.replace(/\s+/g, ' ').trim()

    // ── Step 6: 类别匹配 + 收款方提取 ──
    const catResult = type === 'expense' ? matchCategory(line) : { category: '', confidence: 100, source: 'type' }
    const payee = extractPayee(line, matchedKw)

    const result = {
      _rawText: desc + (fmtAmount ? `\t￥${fmtAmount.toLocaleString()}` : ''),
      _type: type,
      _originalType: type,
      _typeChanged: false,
      _learnKeyword: '',
      _confidence: catResult.confidence,
      _matchSource: catResult.source,
      _uploading: false,
      _originalAccountId: matchedAccountId,
      _accountChanged: false,
      _learnAccountKeyword: '',
      account_id: matchedAccountId,
      account_label: matchedAccount || '未匹配',
      amount: amount || null,
      category: catResult.category,
      payee,
      note,
      receipt_url: '',
      _dayOfMonth: dayOfMonth,
      _monthNum: monthNum,
      expense_date: new Date().toISOString().slice(0, 10),
    }

    if (type === 'transfer') result.target_account_id = targetAccountId || ''
    if (type === 'withdrawal') {
      result.fee_amount = 0
      result.fee_remark = ''
      // 提现 account_id 必须是电商店铺；解析器若匹配到非电商账户，清掉让用户手选
      if (matchedAccountId) {
        const acc = accountStore.accounts.find(a => a.id === matchedAccountId)
        if (!acc || acc.category !== 'ecommerce') {
          result.account_id = ''
          result.account_label = '请选择店铺'
          result.target_account_id = ''
        } else {
          // 店铺已识别：用 targetAccountId（店铺配的默认提现账户）预选
          result.target_account_id = targetAccountId || acc.default_withdraw_account_id || ''
        }
      } else {
        result.target_account_id = ''
      }
    }
    if (type === 'fixed_asset') {
      result.asset_name = note
      result.asset_category = 'equipment'
      result.useful_life_years = 5
      result.residual_rate = 5
    }
    if (type === 'prepaid') result.supplier = note
    if (type === 'deferred_revenue') {
      result.customer_name = ''
      result.total_sessions = 10
      result.course_type = '1v1'
    }
    if (type === 'other_receivable') {
      result.receivable_type = /借/.test(line) ? 'loan' : 'deposit'
      result.counterparty = note
    }
    if (type === 'other_payable') {
      result.payable_type = /保证金/.test(line) ? 'guarantee' : 'deposit'
      result.counterparty = note
    }
    if (type === 'payable') result.supplier = note

    results.push(result)
  }

  return results
}

function handleParseExpenses() {
  parseError.value = ''
  if (!rawText.value.trim()) return
  try {
    const expenses = parseExpenseText(rawText.value)
    if (expenses.length === 0) {
      parseError.value = '未能解析出任何记录，请检查文本格式'
      parsedExpenses.value = []
      return
    }
    parsedExpenses.value = expenses.map(exp => {
      // 用提取到的日期 + 月份选择器计算完整日期（注意用本地时间，避免 UTC 偏移）
      if (exp._dayOfMonth) {
        const year = expenseMonth.value.getFullYear()
        const month = exp._monthNum
          ? exp._monthNum - 1
          : expenseMonth.value.getMonth()
        const day = exp._dayOfMonth
        // 不用 toISOString()（UTC），手动拼本地日期字符串
        exp.expense_date = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      } else {
        const now = new Date()
        exp.expense_date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
      }
      return exp
    })
  } catch (e) {
    console.error('解析失败:', e)
    parseError.value = '解析出错: ' + (e.message || '未知错误')
    parsedExpenses.value = []
  }
}

// ── 智能提交：根据类型写入不同表 ──
async function submitOneTransaction(exp) {
  const amount = Number(exp.amount)
  const date = exp.expense_date || new Date().toISOString().slice(0, 10)
  const accountId = exp.account_id || null
  const note = exp.note || ''
  console.log('[智能记账] submitOneTransaction 开始, type:', exp._type, 'amount:', amount, 'accountId:', accountId)

  switch (exp._type) {
    case 'expense': {
      console.log('[智能记账] 调用 store.createExpense...')
      await store.createExpense({
        category: exp.category || 'other',
        amount,
        payee: exp.payee || note || '未填写',
        account_id: accountId,
        note,
        expense_date: date,
        receipt_url: exp.receipt_url || null,
      })
      console.log('[智能记账] store.createExpense 完成')
      break
    }
    case 'income': {
      console.log('[智能记账] 写入 other_income...')
      const { error: incErr } = await supabase.from('other_income').insert({
        amount,
        category: '其他收入',
        description: exp.payee || note || '未填写',
        account_id: accountId,
      })
      if (incErr) throw new Error('收入写入失败: ' + incErr.message)
      console.log('[智能记账] other_income 写入完成')
      break
    }
    case 'transfer': {
      console.log('[智能记账] 写入 account_transfers...')
      const { error: trErr } = await supabase.from('account_transfers').insert({
        from_account_id: accountId,
        to_account_id: exp.target_account_id || null,
        amount,
        transfer_date: date,
        note,
      })
      if (trErr) throw new Error('转账写入失败: ' + trErr.message)
      console.log('[智能记账] account_transfers 写入完成')
      break
    }
    case 'withdrawal': {
      console.log('[智能记账] 执行店铺提现...')
      if (!accountId) throw new Error('请选择提现店铺')
      if (!exp.target_account_id) throw new Error('请选择到账账户')
      const storeAcc = accountStore.accounts.find(a => a.id === accountId)
      const toAcc = accountStore.accounts.find(a => a.id === exp.target_account_id)
      if (!storeAcc || storeAcc.category !== 'ecommerce') {
        throw new Error('所选店铺不是电商账户')
      }
      const wdRes = await performStoreWithdrawal({
        storeId: accountId,
        storeName: storeAcc.short_name || storeAcc.code || '',
        toAccountId: exp.target_account_id,
        toAccountName: toAcc ? (toAcc.short_name || toAcc.code || '') : '',
        amount,
        feeAmount: Number(exp.fee_amount) || 0,
        feeRemark: exp.fee_remark || '',
        remark: note,
      })
      // 首次提现已自动写默认到账账户 → 同步到本地 Pinia 避免下次还要重选
      if (wdRes?.defaultTargetSaved) {
        const idx = accountStore.accounts.findIndex(a => a.id === accountId)
        if (idx >= 0) accountStore.accounts[idx].default_withdraw_account_id = exp.target_account_id
      }
      console.log('[智能记账] 店铺提现完成')
      break
    }
    case 'fixed_asset': {
      const usefulMonths = (exp.useful_life_years || 5) * 12
      const residualRate = exp.residual_rate || 5
      const monthlyDep = (amount * (1 - residualRate / 100)) / usefulMonths
      console.log('[智能记账] 写入 assets...')
      const { error: assetErr } = await supabase.from('assets').insert({
        name: exp.asset_name || note || '未命名资产',
        category: exp.asset_category || 'equipment',
        purchase_price: amount,
        purchase_date: date,
        useful_life_months: usefulMonths,
        residual_rate: residualRate,
        monthly_depreciation: Math.round(monthlyDep * 100) / 100,
        accumulated_depreciation: 0,
        current_value: amount,
        status: ASSET_STATUS.IN_USE,
      })
      if (assetErr) throw new Error('资产写入失败: ' + assetErr.message)
      console.log('[智能记账] assets 写入完成，写入支出记录...')
      await store.createExpense({
        category: 'equipment',
        amount,
        payee: exp.asset_name || '固定资产',
        account_id: accountId,
        note: `购入固定资产: ${exp.asset_name || ''}`,
        expense_date: date,
      })
      console.log('[智能记账] 固定资产全部完成')
      break
    }
    case 'prepaid': {
      console.log('[智能记账] 写入 prepaid_accounts...')
      const { error: preErr } = await supabase.from('prepaid_accounts').insert({
        supplier_name: exp.supplier || note || '未填写',
        amount,
        settled_amount: 0,
        remaining_amount: amount,
        paid_date: date,
        purpose: note || '预付货款',
        status: 'pending',
        note,
      })
      if (preErr) throw new Error('预付写入失败: ' + preErr.message)
      console.log('[智能记账] prepaid 写入完成，写入支出记录...')
      await store.createExpense({
        category: '预付账款',
        amount,
        payee: exp.supplier || '预付款',
        account_id: accountId,
        note: `预付账款: ${exp.supplier || ''}`,
        expense_date: date,
      })
      console.log('[智能记账] 预付全部完成')
      break
    }
    case 'deferred_revenue': {
      console.log('[智能记账] 写入 deferred_revenue...')
      const { error: defErr } = await supabase.from('deferred_revenue').insert({
        customer_name: exp.customer_name || '未填写',
        total_amount: amount,
        remaining_amount: amount,
        total_sessions: exp.total_sessions || 10,
        consumed_sessions: 0,
        remaining_sessions: exp.total_sessions || 10,
        received_date: date,
        product_name: exp.course_type === 'group' ? '小班课' : exp.course_type === 'online' ? '线上课' : '线下1v1',
        status: 'active',
        note,
      })
      if (defErr) throw new Error('预收写入失败: ' + defErr.message)
      console.log('[智能记账] deferred_revenue 写入完成')
      break
    }
    case 'other_receivable': {
      console.log('[智能记账] 写入 other_receivables...')
      const { error: recErr } = await supabase.from('other_receivables').insert({
        receivable_type: exp.receivable_type || 'deposit',
        counterparty: exp.counterparty || note || '未填写',
        amount,
        recovered_amount: 0,
        remaining_amount: amount,
        occurred_date: date,
        status: 'pending',
        note,
      })
      if (recErr) throw new Error('应收写入失败: ' + recErr.message)
      console.log('[智能记账] other_receivables 写入完成，写入支出记录...')
      await store.createExpense({
        category: '押金/保证金',
        amount,
        payee: exp.counterparty || '押金',
        account_id: accountId,
        note: `${exp.receivable_type === 'loan' ? '借出' : '押金'}: ${exp.counterparty || ''}`,
        expense_date: date,
      })
      console.log('[智能记账] 应收全部完成')
      break
    }
    case 'other_payable': {
      console.log('[智能记账] 写入 other_payables...')
      const { error: opErr } = await supabase.from('other_payables').insert({
        payable_type: exp.payable_type || 'deposit',
        counterparty: exp.counterparty || note || '未填写',
        amount,
        returned_amount: 0,
        remaining_amount: amount,
        occurred_date: date,
        status: 'pending',
        note,
      })
      if (opErr) throw new Error('应付写入失败: ' + opErr.message)
      console.log('[智能记账] other_payables 写入完成')
      break
    }
    case 'payable': {
      console.log('[智能记账] 写入 payable_accounts...')
      const { error: paErr } = await supabase.from('payable_accounts').insert({
        supplier_name: exp.supplier || note || '未填写',
        amount,
        paid_amount: 0,
        remaining_amount: amount,
        due_date: exp.due_date || null,
        status: 'pending',
        note,
      })
      if (paErr) throw new Error('应付账款写入失败: ' + paErr.message)
      console.log('[智能记账] payable_accounts 写入完成')
      break
    }
    case 'salary': {
      console.log('[智能记账] 写入 salaries...')
      const { data: { session: salSession } } = await supabase.auth.getSession()
      const { error: salErr } = await supabase.from('salaries').insert({
        employee_name: exp.payee || note || '未填写',
        base_salary: amount,
        actual_amount: amount,
        pay_month: date.slice(0, 7),
        pay_date: date,
        status: 'paid',
        account_id: accountId,
        note,
        created_by: salSession?.user?.id,
      })
      if (salErr) throw new Error('工资写入失败: ' + salErr.message)
      console.log('[智能记账] salaries 写入完成，写入支出记录...')
      await store.createExpense({
        category: '工资',
        amount,
        payee: exp.payee || '工资发放',
        account_id: accountId,
        note: `工资: ${exp.payee || ''}`,
        expense_date: date,
      })
      console.log('[智能记账] 工资全部完成')
      break
    }
    case 'dividend': {
      console.log('[智能记账] 写入 dividends...')
      const { error: divErr } = await supabase.from('dividends').insert({
        shareholder_name: exp.payee || note || '未填写',
        amount,
        pay_date: date,
        account_id: accountId,
        status: 'paid',
        note,
      })
      if (divErr) throw new Error('分红写入失败: ' + divErr.message)
      console.log('[智能记账] dividends 写入完成，写入支出记录...')
      await store.createExpense({
        category: '股东分红',
        amount,
        payee: exp.payee || '股东分红',
        account_id: accountId,
        note: `分红: ${exp.payee || ''}`,
        expense_date: date,
      })
      console.log('[智能记账] 分红全部完成')
      break
    }
    default: {
      console.log('[智能记账] 默认支出处理...')
      await store.createExpense({
        category: exp.category || 'other',
        amount,
        payee: exp.payee || note || '未填写',
        account_id: accountId,
        note,
        expense_date: date,
      })
      console.log('[智能记账] 默认支出完成')
    }
  }
  console.log('[智能记账] submitOneTransaction 结束')
}

// TYPE_LABELS 已在关键词管理区定义

// 超时保护：防止网络请求挂起导致按钮一直转
function withTimeout(promise, ms = 20000) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(`操作超时(${ms/1000}s)，请检查网络后重试`)), ms))
  ])
}

async function submitParsedExpense(idx) {
  const exp = parsedExpenses.value[idx]
  if (!exp || !exp.amount) {
    toast('请填写金额', 'warning')
    return
  }
  // 行级锁：已经提交中就拦掉，防止双击造成重复入账（提现场景尤其致命）
  if (exp._submitting) {
    console.warn('[智能记账] 该条已在提交中，忽略重复点击')
    return
  }
  exp._submitting = true
  submittingParsed.value = true
  try {
    console.log('[智能记账] 单条提交, type:', exp._type, 'amount:', exp.amount)
    await withTimeout(submitOneTransaction(exp))
    parsedExpenses.value.splice(idx, 1)
    toast(`${TYPE_LABELS[exp._type] || '记录'}已创建`, 'success')
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    console.error('[智能记账] 单条提交失败:', e?.message || e)
    toast('创建失败：' + (e.message || ''), 'error')
    exp._submitting = false  // 失败才解锁，成功已经被 splice 掉
  } finally {
    submittingParsed.value = false
  }
}

async function submitAllParsedExpenses() {
  const valid = parsedExpenses.value.filter(e => e.amount)
  if (valid.length === 0) {
    toast('没有可提交的记录（请确保每条都有金额）', 'warning')
    return
  }
  if (!confirm(`确认批量提交 ${valid.length} 条记录？`)) return
  submittingParsed.value = true
  let successCount = 0
  let failCount = 0
  try {
    for (const exp of valid) {
      try {
        console.log(`[智能记账] 提交第 ${successCount + failCount + 1}/${valid.length} 条，类型: ${exp._type}，金额: ${exp.amount}`)
        await withTimeout(submitOneTransaction(exp))
        successCount++
        console.log(`[智能记账] ✅ 成功`)
      } catch (e) {
        failCount++
        console.error('[智能记账] ❌ 提交失败:', e?.message || e)
      }
    }
    parsedExpenses.value = []
    toast(`成功提交 ${successCount} 条${failCount > 0 ? `，失败 ${failCount} 条` : ''}`, successCount > 0 ? 'success' : 'error')
    await loadPage(pagination.value.page)
    await fetchStats()
  } catch (e) {
    console.error('[智能记账] 批量提交异常:', e)
    toast('提交过程出错：' + (e.message || '未知错误'), 'error')
  } finally {
    submittingParsed.value = false
  }
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
      .is('deleted_at', null)
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

// 电商店铺（仅 category='ecommerce'，店铺提现卡片的"提现店铺"候选）
const ecommerceAccounts = computed(() =>
  activeAccounts.value.filter(a => a.category === 'ecommerce')
)

// 非电商账户（店铺提现卡片的"到账账户"候选）
const nonEcommerceAccounts = computed(() =>
  activeAccounts.value.filter(a => a.category !== 'ecommerce')
)

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
      .is('deleted_at', null)
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
  _uploading: false,
})

// ── 凭证上传（Supabase Storage） ──
async function handleReceiptUpload(event, target) {
  const file = event.target.files?.[0]
  if (!file) return
  // 限制大小 10MB
  if (file.size > 10 * 1024 * 1024) {
    toast('文件不能超过 10MB', 'warning')
    event.target.value = ''
    return
  }
  target._uploading = true
  try {
    const ext = file.name.split('.').pop() || 'jpg'
    const fileName = `receipts/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`

    // 先尝试用当前 session 上传（需 RLS 策略）
    let uploadData = null
    let uploadError = null
    const result = await supabase.storage.from('expense-receipts').upload(fileName, file, {
      cacheControl: '3600',
      upsert: false,
    })
    uploadData = result.data
    uploadError = result.error

    // 如果 RLS 拒绝了，用 fetch + service role key 直接上传（内部系统可信场景）
    if (uploadError && (uploadError.message?.includes('row-level security') || uploadError.statusCode === '403' || uploadError.statusCode === 403)) {
      console.warn('[凭证上传] RLS 拦截，使用 service role 上传...')
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
      const serviceKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY
      if (!serviceKey) {
        throw new Error('凭证上传需要配置 VITE_SUPABASE_SERVICE_KEY 环境变量（或在 Supabase 控制台为 expense-receipts 桶添加 INSERT 策略）')
      }
      const resp = await fetch(`${supabaseUrl}/storage/v1/object/expense-receipts/${fileName}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${serviceKey}`,
          'Content-Type': file.type || 'application/octet-stream',
          'x-upsert': 'false',
        },
        body: file,
      })
      if (!resp.ok) {
        const errBody = await resp.text()
        throw new Error(`上传失败 (${resp.status}): ${errBody}`)
      }
      const respData = await resp.json()
      uploadData = { path: respData.Key || fileName }
    } else if (uploadError) {
      throw uploadError
    }

    // 获取公开 URL
    const { data: urlData } = supabase.storage.from('expense-receipts').getPublicUrl(uploadData.path)
    target.receipt_url = urlData.publicUrl
    toast('凭证上传成功', 'success')
  } catch (e) {
    console.error('凭证上传失败:', e)
    toast('上传失败：' + (e.message || '未知错误'), 'error')
  } finally {
    target._uploading = false
    event.target.value = ''
  }
}

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
    } catch (e) { console.warn("[silent catch]", e?.message || e) }

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
    } catch (e) { console.warn("[silent catch]", e?.message || e) }
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
      try { balResult = await useAccountStore().updateBalance(exp.account_id, Number(exp.amount)) } catch (e) { console.error('[Expenses] 已付款支出回滚账户余额失败 — 数据可能不一致', e); toast('账户余额回滚失败,请手动核对', 'error') }
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
      } catch (e) { console.warn("[silent catch]", e?.message || e) }
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
    // 同步更新 DB 类别名索引（供智能匹配第③层使用）
    dbCategoryNames.value = (data || []).filter(c => c.status === 'active').map(c => c.name)
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
      .is('deleted_at', null)
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
