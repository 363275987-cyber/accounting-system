// ============================================================
// 财务指标统一计算模块
// ============================================================
//
// 修复 BUG-4：财务报表同一指标多处算法不一致
//
// 历史问题：Reports.vue 里 Overview / Income / Equity 三个 tab 各自
// 独立计算"净利润"，公式不同，用户切 tab 看到不同数字。
//
// 本模块提供两套口径，所有报表必须 import 这里的函数，禁止再写本地副本：
//
// 1. computeIncomeStatement(supabase, startISO, endISO)
//    完整账面口径：revenue - cost - 五大费用 - 退款
//    用于：利润表、权益变动表的净利润、未来的所有"账面净利润"
//
// 2. computeOverviewProfit(supabase, startISO, endISO)
//    现金口径：totalIncome - totalExpense（不扣成本/退款）
//    用于：Dashboard 概览卡片、Reports Overview tab 的日历视图
//    UI 上必须明确标注「未扣成本/退款」避免和账面净利润混淆
//
// 任何新报表/新卡片如果要算"净利润"，请先想清楚是哪种口径，
// 然后调用对应函数；不要在组件里重新写一遍 reduce。
// ============================================================

// ── 工具函数 ──
export function num(v) {
  return parseFloat(v) || 0
}

// 取订单实收金额（优先 payment_amount，兜底 amount）
export function orderAmt(o) {
  return num(o.payment_amount) || num(o.amount)
}

// ── 费用类目分组规则 ──
//
// 把数据库里 expenses.category 的英文 key 映射到 6 大报表分组：
// cogs(营业成本) / labor(人工) / operating(经营) / financial(财务) /
// admin(管理) / investing(投资) / other(其他)
export const REPORT_GROUP = {
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

// 中文类别名 → 英文 key 反查（覆盖 expense_categories 表所有可能值）
export const CHINESE_TO_KEY = {
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

// 标准化类别：中文名转英文 key，英文 key 原样返回
export function normalizeCategory(cat) {
  if (!cat) return 'other'
  if (/^[a-z_]+$/.test(cat)) return cat
  return CHINESE_TO_KEY[cat] || 'other'
}

// ── 数据加载器（供 Reports.vue 各 tab 复用，集中维护避免漂移） ──

// 其他收入查询（容错：表不存在则返回空数组）
export async function loadOtherIncome(supabase, startISO, endISO) {
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

// 把 ISO 日期转换为 YYYY-MM 字符串（用于按 pay_month 字段过滤）
function isoToYearMonth(iso) {
  return (iso || '').slice(0, 7)
}

// 员工工资数据 — 权责发生制（按 pay_month 过滤）
// 用于利润表计提：当月损益要计入"应发工资"，与实际发薪日期无关
export async function loadSalariesAccrual(supabase, startISO, endISO) {
  try {
    const startMonth = isoToYearMonth(startISO)
    const endMonth = isoToYearMonth(endISO)
    const { data, error } = await supabase
      .from('salaries')
      .select('actual_amount, employee_name, pay_month, pay_date')
      .is('deleted_at', null)
      .gte('pay_month', startMonth)
      .lte('pay_month', endMonth)
    if (error) { console.warn('salaries(accrual) query error:', error.message); return [] }
    return data || []
  } catch (e) {
    console.warn('salaries(accrual) fallback to empty:', e.message)
    return []
  }
}

// 员工工资数据 — 收付实现制（按 pay_date 过滤）
// 用于现金口径报表：以"实际发薪日"作为现金流出时点；未发放的工资(pay_date 为 null)不计入
export async function loadSalariesCash(supabase, startISO, endISO) {
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
    if (error) { console.warn('salaries(cash) query error:', error.message); return [] }
    return data || []
  } catch (e) {
    console.warn('salaries(cash) fallback to empty:', e.message)
    return []
  }
}

// 兼容老调用名 — 默认走现金口径(保持原行为安全)
// 新代码请直接调 loadSalariesAccrual / loadSalariesCash
export async function loadSalaries(supabase, startISO, endISO) {
  return loadSalariesCash(supabase, startISO, endISO)
}

// 转账手续费汇总
export async function loadTransferFees(supabase, startISO, endISO) {
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

// 电商提现数据（带店铺名）
export async function loadWithdrawals(supabase, startISO, endISO) {
  try {
    const { data, error } = await supabase
      .from('withdrawals')
      .select('amount, actual_arrival, created_at, account_id')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO)
    if (error) throw error
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

// ============================================================
// 核心计算 1：完整账面口径利润表
// ============================================================
//
// 用于：利润表 tab、权益变动表 tab、任何"账面净利润"指标
//
// 返回结构与原 Reports.vue incomeData 一致（除 withdrawalDetail 由调用方拼装）
//
// 公式：
//   revenue = privateRevenue + ecommerceRevenue + otherIncome
//   cost = privateCost + max(0, ecommerceFees) + livestreamCost
//   grossProfit = revenue - cost
//   netProfit = grossProfit - laborCost - operatingCost - adminCost - financialCost - refunds
//
// 其中：
//   - laborCost = expenses.labor + salaries 表
//   - financialCost = expenses.financial + 转账手续费
//   - 退款 = 私域退款 + 电商退款
export async function computeIncomeStatement(supabase, startISO, endISO) {
  // 1. 私域订单收入
  const { data: privateOrders, error: ordErr } = await supabase
    .from('orders')
    .select('id, amount, payment_amount')
    .in('status', ['completed', 'partially_refunded'])
    .is('deleted_at', null)
    .is('platform_type', null)
    .gte('created_at', startISO)
    .lte('created_at', endISO)
  if (ordErr) throw ordErr

  const privateRevenue = (privateOrders || []).reduce((s, o) => s + orderAmt(o), 0)
  const orderIds = (privateOrders || []).map(o => o.id)

  // 2. 私域产品成本
  let privateCost = 0
  if (orderIds.length > 0) {
    const { data: items, error: itemErr } = await supabase
      .from('order_items')
      .select('unit_cost, quantity, order_id')
      .in('order_id', orderIds)
    if (itemErr) console.error('order_items error:', itemErr)
    else privateCost = (items || []).reduce((s, i) => s + num(i.unit_cost) * num(i.quantity), 0)
  }

  // 3. 电商提现
  const withdrawals = await loadWithdrawals(supabase, startISO, endISO)
  const ecommerceRevenue = withdrawals.reduce((s, w) => s + num(w.actual_arrival), 0)
  const ecommerceTotalAmount = withdrawals.reduce((s, w) => s + num(w.amount), 0)
  const ecommerceFees = ecommerceTotalAmount - ecommerceRevenue

  // 4. 其他收入
  const otherIncomeRows = await loadOtherIncome(supabase, startISO, endISO)
  const otherIncome = otherIncomeRows.reduce((s, oi) => s + num(oi.amount), 0)

  // 4.5 员工工资 — 利润表用权责发生制：按 pay_month 计提，与实际发薪日无关
  const salaryData = await loadSalariesAccrual(supabase, startISO, endISO)
  const totalSalary = salaryData.reduce((s, r) => s + num(r.actual_amount), 0)

  // 4.6 转账手续费
  const transferFees = await loadTransferFees(supabase, startISO, endISO)

  // 总收入
  const revenue = privateRevenue + ecommerceRevenue + otherIncome

  // 5. 费用按分类
  const { data: expenseRows, error: expErr } = await supabase
    .from('expenses')
    .select('amount, category')
    .eq('status', 'paid')
    .is('deleted_at', null)
    .gte('created_at', startISO)
    .lte('created_at', endISO)
  if (expErr) throw expErr

  const groupedExpenses = { cogs: {}, labor: {}, operating: {}, financial: {}, admin: {}, investing: {}, other: {} }
  const groupTotals = { cogs: 0, labor: 0, operating: 0, financial: 0, admin: 0, investing: 0, other: 0 }
  for (const e of (expenseRows || [])) {
    const cat = normalizeCategory(e.category)
    const group = REPORT_GROUP[cat] || 'operating'
    const amt = num(e.amount)
    groupedExpenses[group][cat] = (groupedExpenses[group][cat] || 0) + amt
    groupTotals[group] = (groupTotals[group] || 0) + amt
  }

  function groupDetail(group) {
    return Object.entries(groupedExpenses[group] || {})
      .map(([category, amount]) => ({ category, amount }))
      .sort((a, b) => b.amount - a.amount)
  }

  const livestreamCost = groupTotals.cogs
  const cost = privateCost + Math.max(0, ecommerceFees) + livestreamCost
  const grossProfit = revenue - cost

  // 人工成本 = expenses.labor + salaries 表
  const laborCost = groupTotals.labor + totalSalary
  const laborDetail = groupDetail('labor')
  if (totalSalary > 0) {
    laborDetail.unshift({ category: '_salary_system', amount: totalSalary })
  }
  const operatingCost = groupTotals.operating
  const operatingDetail = groupDetail('operating')
  const adminCost = groupTotals.admin
  const adminDetail = groupDetail('admin')
  // 财务费用 = expenses.financial + 转账手续费
  const financialCost = groupTotals.financial + transferFees
  const financialDetail = groupDetail('financial')
  if (transferFees > 0) {
    financialDetail.push({ category: '_transfer_fee', amount: transferFees })
  }

  // 6. 退款（私域 + 电商分开）
  const { data: refundRows, error: refErr } = await supabase
    .from('refunds')
    .select('refund_amount, order_id')
    .eq('status', 'completed')
    .is('deleted_at', null)
    .gte('created_at', startISO)
    .lte('created_at', endISO)
  if (refErr) throw refErr

  const refundOrderIds = (refundRows || []).map(r => r.order_id).filter(Boolean)
  const ecommerceOrderIdSet = new Set()
  if (refundOrderIds.length > 0) {
    const { data: refundOrders } = await supabase
      .from('orders')
      .select('id, platform_type')
      .is('deleted_at', null)
      .in('id', refundOrderIds)
    for (const ro of (refundOrders || [])) {
      if (ro.platform_type) ecommerceOrderIdSet.add(ro.id)
    }
  }

  let privateRefunds = 0
  let ecommerceRefunds = 0
  for (const r of (refundRows || [])) {
    const amt = num(r.refund_amount)
    if (ecommerceOrderIdSet.has(r.order_id)) ecommerceRefunds += amt
    else privateRefunds += amt
  }
  const refunds = privateRefunds + ecommerceRefunds

  const netProfit = grossProfit - laborCost - operatingCost - adminCost - financialCost - refunds

  // privateProfit / ecommerceProfit 用于 Equity tab 的"私域净利润 / 电商净利润"细分
  const privateProfit = privateRevenue - privateCost - privateRefunds
  const ecommerceProfit = ecommerceRevenue - ecommerceRefunds // 电商提现已扣除手续费

  return {
    // 收入
    revenue, privateRevenue, ecommerceRevenue, otherIncome,
    // 成本
    cost, privateCost, ecommerceFees: Math.max(0, ecommerceFees), livestreamCost,
    // 毛利
    grossProfit,
    // 费用分类
    laborCost, laborDetail,
    operatingCost, operatingDetail,
    adminCost, adminDetail,
    financialCost, financialDetail,
    // 退款
    refunds, privateRefunds, ecommerceRefunds,
    // 净利润
    netProfit,
    // 分渠道净利润（Equity tab 用）
    privateProfit, ecommerceProfit,
    // 原始 withdrawals 数据（让调用方按需拼 withdrawalDetail）
    withdrawals,
  }
}

// ============================================================
// 核心计算 2：现金口径概览
// ============================================================
//
// 用于：Dashboard 概览卡片、Reports Overview tab 的日历视图
//
// 公式：
//   totalIncome = privateRevenue + ecommerceRevenue + otherIncome
//   totalExpense = expenses(paid) + salaries + transferFees
//   profit = totalIncome - totalExpense
//
// ⚠️ 这是"现金口径"——不扣商品成本、不扣退款。
// UI 上必须明确标注「未扣成本/退款」，避免和 computeIncomeStatement
// 返回的"账面净利润"混淆。
//
// 注意：和 Dashboard.vue 旧逻辑的差异：
//   - 旧 Dashboard 用 status IN ('approved','paid')，本函数统一为 paid
//   - 旧 Dashboard 不含 salaries/transferFees，本函数含
//   两个口径合并后，Dashboard 卡片和 Reports Overview tab 数字会一致
export async function computeOverviewProfit(supabase, startISO, endISO) {
  const [ordRes, expRes] = await Promise.all([
    supabase
      .from('orders')
      .select('amount, payment_amount')
      .in('status', ['completed', 'partially_refunded'])
      .is('deleted_at', null)
      .is('platform_type', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
    supabase
      .from('expenses')
      .select('amount')
      .eq('status', 'paid')
      .is('deleted_at', null)
      .gte('created_at', startISO)
      .lte('created_at', endISO),
  ])

  if (ordRes.error) throw ordRes.error
  if (expRes.error) throw expRes.error

  const privateIncome = (ordRes.data || []).reduce((s, o) => s + orderAmt(o), 0)

  const withdrawals = await loadWithdrawals(supabase, startISO, endISO)
  const ecommerceIncome = withdrawals.reduce((s, w) => s + num(w.actual_arrival), 0)

  const otherIncomeRows = await loadOtherIncome(supabase, startISO, endISO)
  const otherIncome = otherIncomeRows.reduce((s, oi) => s + num(oi.amount), 0)

  // 现金口径：按实际发薪日(pay_date)统计，未发放的工资不计入
  const salaryRows = await loadSalariesCash(supabase, startISO, endISO)
  const salaryExpense = salaryRows.reduce((s, r) => s + num(r.actual_amount), 0)

  const transferFees = await loadTransferFees(supabase, startISO, endISO)

  const expenseSum = (expRes.data || []).reduce((s, e) => s + num(e.amount), 0)

  const totalIncome = privateIncome + ecommerceIncome + otherIncome
  const totalExpense = expenseSum + salaryExpense + transferFees
  const profit = totalIncome - totalExpense

  return {
    totalIncome,
    privateIncome,
    ecommerceIncome,
    otherIncome,
    totalExpense,
    expenseSum,
    salaryExpense,
    transferFees,
    profit,
  }
}
