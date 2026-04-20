/**
 * 电商订单 Excel 导入器
 * 支持抖音、快手、视频号的销售订单和售后订单导入
 */

import { PLATFORM_LABELS } from './utils'

// ============ 平台识别 ============

/**
 * 根据 sheet 名称识别平台类型
 */
export function identifyPlatform(sheetName) {
  if (!sheetName) return null
  const name = sheetName.trim()
  if (name.includes('抖音') || name.includes('抖店')) return 'douyin'
  if (name.includes('快手')) return 'kuaishou'
  if (name.includes('视频号')) return 'shipinhao'
  return null
}

/**
 * 判断 sheet 是否为售后订单
 */
export function isAfterSalesSheet(sheetName) {
  if (!sheetName) return false
  return sheetName.includes('售后')
}

/**
 * 判断 sheet 是否为销售订单
 */
export function isSalesOrderSheet(sheetName) {
  if (!sheetName) return false
  return sheetName.includes('销售订单')
}

/**
 * 获取销售订单相关的 sheets（排除售后）
 */
export function getSalesSheets(sheetNames) {
  return sheetNames.filter(name =>
    !isAfterSalesSheet(name) && (
      isSalesOrderSheet(name) ||
      identifyPlatform(name) !== null
    )
  )
}

/**
 * 获取售后订单相关的 sheets
 */
export function getAfterSalesSheets(sheetNames) {
  return sheetNames.filter(name => isAfterSalesSheet(name))
}

// ============ 销售订单解析 ============

/**
 * 解析抖音销售订单
 * 列映射：
 * - F (index 5): 子订单编号 → external_order_no
 * - D (index 3): 店铺 → platform_store
 * - K (index 10): 商家编码 → sku_code
 * - L (index 11): 商品数量 → quantity
 * - M (index 12): 商品金额 → payment_amount
 * - W (index 22): 订单状态 → status
 * - C (index 2): 支付完成时间 → order_time
 */
function parseDouyinSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(22)
  // 跳过"已关闭"和"同意退款，退款成功"
  if (status === '已关闭' || status === '同意退款，退款成功') return null

  const paymentAmount = getNum(12)
  if (paymentAmount <= 0) return null

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'sales',
    platform_type: 'douyin',
    external_order_no: get(5),  // F列 - 子订单编号
    platform_store: get(3),     // D列 - 店铺
    sku_code: get(10),          // K列 - 商家编码
    quantity: getNum(11),       // L列 - 商品数量
    payment_amount: paymentAmount, // M列 - 商品金额
    status: status,
    order_time: get(2),         // C列 - 支付完成时间
    _rawRow: row,
  }
}

/**
 * 解析快手销售订单
 * 列映射：
 * - E (index 4): 订单号 → external_order_no
 * - D (index 3): 店铺 → platform_store
 * - AF (index 32): SKU编码 → sku_code
 * - L (index 11): 实付款 → payment_amount
 * - K (index 10): 订单状态 → status
 * - C (index 2) 或 I (index 8): 支付完成时间 → order_time
 */
function parseKuaishouSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(10)
  // 跳过"交易关闭"
  if (status === '交易关闭') return null

  const paymentAmount = getNum(11)
  if (paymentAmount <= 0) return null

  // 支付完成时间：优先列C，空的话取列I
  const orderTime = get(2) || get(8)

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'sales',
    platform_type: 'kuaishou',
    external_order_no: get(4),   // E列 - 订单号
    platform_store: get(3),      // D列 - 店铺
    sku_code: get(32),           // AF列 - SKU编码
    quantity: getNum(11),        // L列 - 实付款 (也作为数量占位)
    payment_amount: paymentAmount,
    status: status,
    order_time: orderTime,
    _rawRow: row,
  }
}

/**
 * 解析视频号销售订单
 * 列映射：
 * - E (index 4): 订单号 → external_order_no
 * - D (index 3): 店铺 → platform_store
 * - AV (index 47): SKU编码(自定义) → sku_code
 * - V (index 21): 订单实际支付金额 → payment_amount
 * - J (index 9): 订单状态 → status
 * - F (index 5): 订单下单时间 → order_time
 */
function parseShipinhaoSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(9)
  // 跳过"已取消"
  if (status === '已取消') return null

  const paymentAmount = getNum(21)
  if (paymentAmount <= 0) return null

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'sales',
    platform_type: 'shipinhao',
    external_order_no: get(4),    // E列 - 订单号
    platform_store: get(3),       // D列 - 店铺
    sku_code: get(47),            // AV列 - SKU编码(自定义)
    quantity: 1,                  // 视频号无单独数量列
    payment_amount: paymentAmount,
    status: status,
    order_time: get(5),           // F列 - 订单下单时间
    _rawRow: row,
  }
}

// ============ 售后订单解析 ============

/**
 * 解析抖音售后订单
 * 列映射：
 * - B (index 1): 售后单号 → refund_no
 * - C (index 2): 订单号 → external_order_no（用于匹配）
 * - A (index 0): 店铺 → platform_store
 * - L (index 12): 退商品金额 → refund_amount
 * - Q (index 16): 售后状态 → status
 */
function parseDouyinAfterSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(16)
  // 只处理"退款成功"或"同意退款，退款成功"
  if (status !== '退款成功' && status !== '同意退款，退款成功') return null

  const refundAmount = getNum(12)
  if (refundAmount <= 0) return null

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'aftersales',
    platform_type: 'douyin',
    refund_no: get(1),           // B列 - 售后单号
    external_order_no: get(2),   // C列 - 订单号
    platform_store: get(0),      // A列 - 店铺
    refund_amount: refundAmount, // L列 - 退商品金额
    status: status,
    _rawRow: row,
  }
}

/**
 * 解析快手售后订单
 * 列映射：
 * - B (index 1): 售后单号 → refund_no
 * - C (index 2): 订单编号 → external_order_no
 * - A (index 0): 店铺 → platform_store
 * - O (index 15): 退款金额 → refund_amount
 * - P (index 16): 售后状态 → status
 */
function parseKuaishouAfterSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(16)
  // 只处理"售后成功"
  if (status !== '售后成功') return null

  const refundAmount = getNum(15)
  if (refundAmount <= 0) return null

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'aftersales',
    platform_type: 'kuaishou',
    refund_no: get(1),           // B列 - 售后单号
    external_order_no: get(2),   // C列 - 订单编号
    platform_store: get(0),      // A列 - 店铺
    refund_amount: refundAmount, // O列 - 退款金额
    status: status,
    _rawRow: row,
  }
}

/**
 * 解析视频号售后订单
 * 列映射：
 * - B (index 1): 售后单号 → refund_no
 * - J (index 9): 订单编号 → external_order_no
 * - A (index 0): 店铺 → platform_store
 * - W (index 22): 退款金额 → refund_amount
 * - X (index 23): 售后状态 → status
 */
function parseShipinhaoAfterSalesRow(row, rowIdx) {
  const get = (idx) => String(row[idx] ?? '').trim()
  const getNum = (idx) => {
    const v = get(idx)
    if (!v) return 0
    const n = parseFloat(v.replace(/[,，\s]/g, ''))
    return isNaN(n) ? 0 : n
  }

  const status = get(23)
  // 只处理"退款成功"
  if (status !== '退款成功') return null

  const refundAmount = getNum(22)
  if (refundAmount <= 0) return null

  return {
    _rowIdx: rowIdx,
    _selected: true,
    _type: 'aftersales',
    platform_type: 'shipinhao',
    refund_no: get(1),           // B列 - 售后单号
    external_order_no: get(9),   // J列 - 订单编号
    platform_store: get(0),      // A列 - 店铺
    refund_amount: refundAmount, // W列 - 退款金额
    status: status,
    _rawRow: row,
  }
}

// ============ 主解析入口 ============

/**
 * 解析 Excel workbook，返回销售订单和售后订单
 * @param {Object} workbook - XLSX workbook
 * @param {Object} options - { autoDetect: boolean, forcePlatform: string|null }
 * @returns {{ salesOrders: Array, afterSalesOrders: Array, skipped: number, errors: string[] }}
 */
export function parseEcommerceExcel(workbook, options = {}) {
  const { autoDetect = true, forcePlatform = null } = options
  const sheetNames = workbook.SheetNames

  const salesOrders = []
  const afterSalesOrders = []
  let skipped = 0
  const errors = []
  const seenExternalNos = new Set()
  const seenRefundNos = new Set()

  // 处理每个 sheet
  for (const sheetName of sheetNames) {
    const sheet = workbook.Sheets[sheetName]
    if (!sheet) continue

    const jsonData = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' })
    if (jsonData.length < 2) continue

    // 跳过表头行
    const rows = jsonData.slice(1).filter(row =>
      row.some(cell => cell !== '' && cell !== null && cell !== undefined)
    )

    // 确定平台
    let platform = null
    if (forcePlatform) {
      platform = forcePlatform
    } else if (autoDetect) {
      platform = identifyPlatform(sheetName)
    }

    if (!platform) {
      errors.push(`Sheet "${sheetName}" 无法识别平台，已跳过`)
      continue
    }

    const isAfterSales = isAfterSalesSheet(sheetName)

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      const rowIdx = i + 2 // +2: +1 for 0-index, +1 for header

      try {
        if (isAfterSales) {
          // 售后订单
          let parsed = null
          if (platform === 'douyin') parsed = parseDouyinAfterSalesRow(row, rowIdx)
          else if (platform === 'kuaishou') parsed = parseKuaishouAfterSalesRow(row, rowIdx)
          else if (platform === 'shipinhao') parsed = parseShipinhaoAfterSalesRow(row, rowIdx)

          if (!parsed) { skipped++; continue }

          // 售后去重
          if (parsed.refund_no && seenRefundNos.has(parsed.refund_no)) {
            skipped++
            continue
          }
          if (parsed.refund_no) seenRefundNos.add(parsed.refund_no)

          afterSalesOrders.push(parsed)
        } else {
          // 销售订单
          let parsed = null
          if (platform === 'douyin') parsed = parseDouyinSalesRow(row, rowIdx)
          else if (platform === 'kuaishou') parsed = parseKuaishouSalesRow(row, rowIdx)
          else if (platform === 'shipinhao') parsed = parseShipinhaoSalesRow(row, rowIdx)

          if (!parsed) { skipped++; continue }

          // 销售去重
          if (parsed.external_order_no) {
            const dedupKey = `${parsed.platform_type}:${parsed.external_order_no}`
            if (seenExternalNos.has(dedupKey)) {
              skipped++
              continue
            }
            seenExternalNos.add(dedupKey)
          }

          salesOrders.push(parsed)
        }
      } catch (e) {
        errors.push(`Sheet "${sheetName}" 第 ${rowIdx} 行解析错误: ${e.message}`)
        skipped++
      }
    }
  }

  return { salesOrders, afterSalesOrders, skipped, errors }
}

// ============ 数据库操作 ============

/**
 * 执行电商订单导入（销售+售后）
 *
 * 优化策略（方案 A+B）：
 * 1. 客户端对冲：先用售后订单号匹配销售订单号，在内存中对冲，只把"没被退的有效订单"写入数据库
 * 2. 批量插入：每 100 条一批 insert，减少网络往返
 * 3. 账户预加载：一次性加载所有电商账户，不逐条查询
 * 4. 余额延迟更新：全部导入完后，按账户一次性算总额更新余额
 *
 * @param {Object} params
 * @param {Array} params.salesOrders - 销售订单列表
 * @param {Array} params.afterSalesOrders - 售后订单列表
 * @param {Function} params.supabase - supabase client
 * @param {Function} params.onProgress - 进度回调
 * @returns {{ success, duplicate, skippedRefunded, failures, netSalesAmount, totalRefundAmount }}
 */
// 让出主线程一瞬间，避免长时间同步阻塞导致浏览器"无响应"
const yieldToMainThread = () => new Promise(r => setTimeout(r, 0))

export async function importEcommerceOrders({ salesOrders, afterSalesOrders, supabase: sb, onProgress }) {
  const result = { success: 0, duplicate: 0, skippedRefunded: 0, failures: [], netSalesAmount: 0, totalRefundAmount: 0 }
  const BATCH = 100

  onProgress?.({ type: 'prepare', current: 0, total: 1, message: '准备中：对冲退款...' })

  // ========== 第一步：客户端对冲（内存中完成） ==========

  // 构建售后索引（支持精确匹配和前缀匹配）
  // 抖音：销售用子订单号(DY20260401000_001)，售后用父订单号(DY20260401000)
  // 快手/视频号：两者通常一致
  const afterSalesExact = new Map()   // platform:orderNo -> { totalRefund, records[] }
  const afterSalesPrefix = new Map()  // platform:parentOrderNo -> { totalRefund, records[] }

  for (const refund of afterSalesOrders) {
    const exactKey = `${refund.platform_type}:${refund.external_order_no}`
    if (!afterSalesExact.has(exactKey)) {
      afterSalesExact.set(exactKey, { totalRefund: 0, records: [], matched: false })
    }
    const entry = afterSalesExact.get(exactKey)
    entry.totalRefund += Number(refund.refund_amount || 0)
    entry.records.push(refund)

    // 同时建前缀索引（售后的 external_order_no 作为前缀来匹配销售的子订单号）
    const prefixKey = `${refund.platform_type}:${refund.external_order_no}`
    if (!afterSalesPrefix.has(prefixKey)) {
      afterSalesPrefix.set(prefixKey, afterSalesExact.get(exactKey))
    }
  }

  // 对冲：把被全额退款的销售订单过滤掉，只保留有效订单
  const effectiveOrders = [] // 没被退/部分退 -> 要导入
  const fullyRefundedOrders = [] // 被全额退 -> 不导入，但记录退款金额

  let _loopCounter = 0
  for (const order of salesOrders) {
    // 每 500 条让一次主线程，防止长文件 parse+match 冻结页面
    if (++_loopCounter % 500 === 0) {
      onProgress?.({ type: 'prepare', current: _loopCounter, total: salesOrders.length,
        message: `对冲匹配中 ${_loopCounter}/${salesOrders.length}...` })
      await yieldToMainThread()
    }
    const exactKey = `${order.platform_type}:${order.external_order_no}`

    // 先精确匹配
    let refundInfo = afterSalesExact.get(exactKey)

    // 再前缀匹配：销售子订单号(DY20260401000_001)的前缀是售后父订单号(DY20260401000)
    if (!refundInfo) {
      for (const [prefixKey, info] of afterSalesPrefix) {
        const [platform, parentNo] = [prefixKey.split(':')[0], prefixKey.substring(prefixKey.indexOf(':') + 1)]
        if (order.platform_type === platform && order.external_order_no && order.external_order_no.startsWith(parentNo)) {
          refundInfo = info
          break
        }
      }
    }

    if (!refundInfo) {
      // 没有售后，直接导入
      effectiveOrders.push({ ...order, _refundAmount: 0 })
    } else {
      refundInfo.matched = true
      const orderAmt = Number(order.payment_amount || 0)
      if (refundInfo.totalRefund >= orderAmt) {
        // 全额退款，跳过导入
        fullyRefundedOrders.push(order)
        result.skippedRefunded++
        result.totalRefundAmount += orderAmt
      } else {
        // 部分退款，仍导入（记录退款金额用于标记）
        effectiveOrders.push({ ...order, _refundAmount: refundInfo.totalRefund })
        result.totalRefundAmount += refundInfo.totalRefund
      }
    }
  }

  // 剩余未匹配的售后（售后表有但销售表没有对应订单）
  const unmatchedRefunds = []
  for (const [key, info] of afterSalesExact) {
    if (!info.matched) {
      unmatchedRefunds.push(...info.records)
      result.totalRefundAmount += info.totalRefund
    }
  }

  // 计算净销售额
  result.netSalesAmount = effectiveOrders.reduce((s, o) => s + Number(o.payment_amount || 0) - Number(o._refundAmount || 0), 0)

  onProgress?.({ type: 'prepare', current: 1, total: 1,
    message: `对冲完成：${salesOrders.length} 笔销售 - ${fullyRefundedOrders.length} 笔全退 = ${effectiveOrders.length} 笔有效订单` })

  // ========== 第二步：预加载去重数据 + 账户数据 ==========

  // 2a. 预加载已有的 external_order_no（去重）
  const existingExternalNos = new Set()
  if (effectiveOrders.length > 0) {
    try {
      const uniqueNos = [...new Set(effectiveOrders.map(o => o.external_order_no).filter(Boolean))]
      for (let i = 0; i < uniqueNos.length; i += 500) {
        const chunk = uniqueNos.slice(i, i + 500)
        const { data: existing } = await sb
          .from('orders')
          .select('external_order_no, platform_type')
          .in('external_order_no', chunk)
          .is('deleted_at', null)
        for (const row of (existing || [])) {
          if (row.external_order_no && row.platform_type) {
            existingExternalNos.add(`${row.platform_type}:${row.external_order_no}`)
          }
        }
      }
    } catch (e) {
      console.warn('去重查询失败:', e)
    }
  }

  // 2b. 预加载所有电商账户（避免逐条查询）
  const accountCache = new Map() // storeName -> { id, short_name }
  try {
    const { data: allAccounts } = await sb
      .from('accounts')
      .select('id, short_name, platform, ecommerce_platform')
      .eq('status', 'active')
      .limit(500)
    for (const acc of (allAccounts || [])) {
      if (acc.short_name) accountCache.set(acc.short_name, acc)
    }
  } catch (e) {
    console.warn('账户预加载失败:', e)
  }

  // 快速查找账户（先从缓存找，找不到再创建）
  // Promise 级缓存：防止并发场景下同一个 storeName 被重复创建
  const pendingCreate = new Map() // storeName -> Promise<accountId|null>
  async function getAccountId(platformType, storeName) {
    if (!storeName) return null
    // 缓存命中
    for (const [name, acc] of accountCache) {
      if (name.includes(storeName) || storeName.includes(name)) return acc.id
    }
    // 按平台匹配
    for (const [name, acc] of accountCache) {
      if (acc.ecommerce_platform === platformType || acc.platform === platformType) return acc.id
    }
    // 正在创建中，等待既有的 promise
    if (pendingCreate.has(storeName)) return pendingCreate.get(storeName)
    // 缓存未命中，调用原函数创建（注册 promise 防并发）
    const p = (async () => {
      const created = await findOrCreateEcommerceAccount(sb, platformType, storeName)
      if (created) accountCache.set(created.short_name || storeName, created)
      return created?.id || null
    })()
    pendingCreate.set(storeName, p)
    try { return await p } finally { pendingCreate.delete(storeName) }
  }

  // ========== 第三步：批量导入有效订单 ==========

  // 按账户累计余额变动（最后一次性更新）
  const balanceDeltas = new Map() // accountId -> delta

  // 过滤掉已存在的订单
  const toInsert = []
  for (const order of effectiveOrders) {
    if (order.external_order_no) {
      const dedupKey = `${order.platform_type}:${order.external_order_no}`
      if (existingExternalNos.has(dedupKey)) {
        result.duplicate++
        continue
      }
    }
    toInsert.push(order)
  }

  // 预构建所有 payload（accountId 查询走缓存，为避免并发重复触发 create 加 promise 缓存）
  const payloads = []
  for (let idx = 0; idx < toInsert.length; idx++) {
    const order = toInsert[idx]
    const accountId = await getAccountId(order.platform_type, order.platform_store)
    const orderTime = parseOrderTime(order.order_time)
    const netAmount = Number(order.payment_amount || 0) - Number(order._refundAmount || 0)

    const payload = {
      order_no: order.external_order_no || `EC-${Date.now()}-${idx}`,
      customer_name: '电商客户',
      customer_phone: '',
      customer_address: '',
      product_name: '',
      product_category: 'other',
      amount: order.payment_amount,
      status: order._refundAmount > 0 ? 'partially_refunded' : 'completed',
      order_source: 'cs_service',
      external_order_no: order.external_order_no,
      platform_type: order.platform_type,
      platform_store: order.platform_store,
      account_code: order.platform_store || '',
      sku_code: order.sku_code || null,
      payment_amount: order.payment_amount,
      order_time: orderTime,
      quantity: order.quantity || 1,
      // 把 created_at 直接设成实际支付时间(解析自 Excel)
      // 这样前端所有按 created_at 的统计/筛选/排序会自动按"真实下单日"来算
      // 如果解析失败(orderTime=null),留空走默认 NOW()
      ...(orderTime ? { created_at: orderTime } : {}),
    }
    if (accountId) {
      payload.account_id = accountId
      balanceDeltas.set(accountId, (balanceDeltas.get(accountId) || 0) + netAmount)
    }
    payloads.push(payload)
    if (idx % 300 === 299) await yieldToMainThread()  // 让主线程换气
  }

  // 并发批量写入 (concurrency=4)，去掉"失败降级为逐条"的灾难路径
  const SALES_CONC = 4
  const batchCount = Math.ceil(payloads.length / BATCH)
  let _batchDone = 0
  const runSalesBatch = async (batchIdx) => {
    const start = batchIdx * BATCH
    const chunk = payloads.slice(start, start + BATCH)
    try {
      const { data: inserted, error } = await sb
        .from('orders')
        .insert(chunk)
        .select('id')
      if (error) {
        // 因为前面已经 dedup 过，这里走到通常是并发或约束异常
        if (error.code === '23505') result.duplicate += chunk.length
        else result.failures.push({ message: `批量插入失败(批${batchIdx + 1}): ${error.message}` })
      } else {
        result.success += (inserted || chunk).length
      }
    } catch (e) {
      result.failures.push({ message: `批量插入异常(批${batchIdx + 1}): ${e.message}` })
    } finally {
      _batchDone++
      onProgress?.({ type: 'sales', current: _batchDone * BATCH, total: payloads.length,
        message: `导入有效订单 ${_batchDone}/${batchCount} 批` })
    }
  }
  for (let k = 0; k < batchCount; k += SALES_CONC) {
    const group = []
    for (let g = k; g < Math.min(k + SALES_CONC, batchCount); g++) group.push(runSalesBatch(g))
    await Promise.all(group)
    await yieldToMainThread()
  }

  // ========== 第四步：处理未匹配的售后（批量化） ==========
  if (unmatchedRefunds.length > 0) {
    onProgress?.({ type: 'aftersales', current: 0, total: unmatchedRefunds.length,
      message: `处理 ${unmatchedRefunds.length} 条未匹配售后...` })

    // 4a. 预加载已有退款号（去重）
    const existingRefundNos = new Set()
    try {
      const uniqueRefundNos = [...new Set(unmatchedRefunds.map(r => r.refund_no).filter(Boolean))]
      for (let i = 0; i < uniqueRefundNos.length; i += 500) {
        const chunk = uniqueRefundNos.slice(i, i + 500)
        const { data: existing } = await sb
          .from('refunds')
          .select('refund_no')
          .in('refund_no', chunk)
          .is('deleted_at', null)
        for (const row of (existing || [])) {
          if (row.refund_no) existingRefundNos.add(row.refund_no)
        }
      }
    } catch (e) { console.warn("[silent catch]", e?.message || e) }

    // 4b. 过滤掉已存在的退款号
    const toProcess = []
    for (const r of unmatchedRefunds) {
      if (r.refund_no && existingRefundNos.has(r.refund_no)) {
        result.duplicate++
        continue
      }
      toProcess.push(r)
    }

    // 4c. 批量精确匹配（按平台分组，in 查询）
    const matchedMap = new Map() // `${platform}:${extOrdNo}` -> orderRow
    const byPlatform = new Map()
    for (const r of toProcess) {
      if (!r.external_order_no) continue
      if (!byPlatform.has(r.platform_type)) byPlatform.set(r.platform_type, [])
      byPlatform.get(r.platform_type).push(r.external_order_no)
    }
    for (const [platform, nos] of byPlatform) {
      const unique = [...new Set(nos)]
      for (let i = 0; i < unique.length; i += 500) {
        const chunk = unique.slice(i, i + 500)
        try {
          const { data: matches } = await sb.from('orders')
            .select('id, external_order_no, account_id, payment_amount, platform_type')
            .eq('platform_type', platform)
            .in('external_order_no', chunk)
            .is('deleted_at', null)
          for (const o of (matches || [])) {
            matchedMap.set(`${o.platform_type}:${o.external_order_no}`, o)
          }
        } catch (e) { console.warn('售后精确匹配失败:', e) }
      }
      await yieldToMainThread()
    }

    // 4d. 分类：精确命中 / 需 fuzzy / 需占位
    const matchedRefunds = []     // { refund, orderRow }
    const needFuzzy = []
    for (const r of toProcess) {
      const o = matchedMap.get(`${r.platform_type}:${r.external_order_no}`)
      if (o) matchedRefunds.push({ refund: r, orderRow: o })
      else needFuzzy.push(r)
    }

    // 4e. 并发 fuzzy 匹配（concurrency=6）
    const stillUnmatched = []
    const FUZZY_CONC = 6
    let _fz = 0
    const runFuzzy = async (r) => {
      if (!r.external_order_no) { stillUnmatched.push(r); return }
      try {
        const { data } = await sb.from('orders')
          .select('id, account_id, payment_amount, external_order_no, platform_type')
          .is('deleted_at', null)
          .like('external_order_no', `${r.external_order_no}%`)
          .eq('platform_type', r.platform_type)
          .limit(1).maybeSingle()
        if (data) matchedRefunds.push({ refund: r, orderRow: data })
        else stillUnmatched.push(r)
      } catch (e) {
        stillUnmatched.push(r)
      } finally {
        _fz++
        if (_fz % 10 === 0) onProgress?.({ type: 'aftersales', current: _fz, total: needFuzzy.length,
          message: `售后模糊匹配 ${_fz}/${needFuzzy.length}` })
      }
    }
    for (let k = 0; k < needFuzzy.length; k += FUZZY_CONC) {
      await Promise.all(needFuzzy.slice(k, k + FUZZY_CONC).map(runFuzzy))
      if (k % (FUZZY_CONC * 5) === 0) await yieldToMainThread()
    }

    // 4f. 批量创建占位订单（一次 insert 全部）
    if (stillUnmatched.length > 0) {
      onProgress?.({ type: 'aftersales', current: 0, total: stillUnmatched.length, message: `创建 ${stillUnmatched.length} 个占位订单...` })
      const phPayloads = []
      for (let idx = 0; idx < stillUnmatched.length; idx++) {
        const r = stillUnmatched[idx]
        const accountId = await getAccountId(r.platform_type, r.platform_store)
        phPayloads.push({
          order_no: `REFUND-${r.refund_no || `${Date.now()}-${idx}`}`,
          customer_name: '售后退款（无原始订单）',
          customer_phone: '', customer_address: '', product_name: '',
          product_category: 'other',
          amount: r.refund_amount,
          status: 'refunded',
          order_source: 'cs_service',
          external_order_no: r.external_order_no || '',
          platform_type: r.platform_type,
          platform_store: r.platform_store || '',
          account_code: r.platform_store || '',
          payment_amount: r.refund_amount,
          ...(accountId ? { account_id: accountId } : {}),
        })
      }
      // 分批并发插入（concurrency=4，每批 100）
      const PH_BATCH = 100, PH_CONC = 4
      const phBatches = Math.ceil(phPayloads.length / PH_BATCH)
      const runPh = async (bi) => {
        const start = bi * PH_BATCH
        const chunk = phPayloads.slice(start, start + PH_BATCH)
        const refs = stillUnmatched.slice(start, start + PH_BATCH)
        try {
          const { data: placeholders, error } = await sb.from('orders').insert(chunk).select('id, account_id')
          if (error) {
            result.failures.push({ message: `批量占位订单失败: ${error.message}` })
            return
          }
          for (let i = 0; i < refs.length; i++) {
            const ph = placeholders?.[i]
            if (ph) matchedRefunds.push({ refund: refs[i], orderRow: { id: ph.id, account_id: ph.account_id } })
          }
        } catch (e) {
          result.failures.push({ message: `批量占位订单异常: ${e.message}` })
        }
      }
      for (let k = 0; k < phBatches; k += PH_CONC) {
        const group = []
        for (let g = k; g < Math.min(k + PH_CONC, phBatches); g++) group.push(runPh(g))
        await Promise.all(group)
        await yieldToMainThread()
      }
    }

    // 4g. 批量插入 refunds 记录（concurrency=4，每批 100）
    if (matchedRefunds.length > 0) {
      onProgress?.({ type: 'aftersales', current: 0, total: matchedRefunds.length, message: `批量写入 ${matchedRefunds.length} 条退款...` })
      const REF_BATCH = 100, REF_CONC = 4
      const refBatchCount = Math.ceil(matchedRefunds.length / REF_BATCH)
      let _rdone = 0
      const runRef = async (bi) => {
        const start = bi * REF_BATCH
        const chunk = matchedRefunds.slice(start, start + REF_BATCH)
        const payloads = chunk.map(({ refund, orderRow }) => ({
          order_id: orderRow.id,
          refund_no: refund.refund_no,
          refund_amount: refund.refund_amount,
          reason: `${refund.platform_type} 售后退款`,
          status: 'completed',
          refund_from_account_id: orderRow.account_id || null,
        }))
        try {
          const { error } = await sb.from('refunds').insert(payloads)
          if (error) {
            if (error.code === '23505') result.duplicate += payloads.length
            else result.failures.push({ message: `批量退款插入失败: ${error.message}` })
          } else {
            result.success += payloads.length
            for (const { refund, orderRow } of chunk) {
              if (orderRow.account_id && refund.refund_amount > 0) {
                balanceDeltas.set(orderRow.account_id,
                  (balanceDeltas.get(orderRow.account_id) || 0) - Number(refund.refund_amount))
              }
            }
          }
        } catch (e) {
          result.failures.push({ message: `批量退款插入异常: ${e.message}` })
        } finally {
          _rdone++
          onProgress?.({ type: 'aftersales', current: _rdone * REF_BATCH, total: matchedRefunds.length,
            message: `批量写入退款 ${_rdone}/${refBatchCount}` })
        }
      }
      for (let k = 0; k < refBatchCount; k += REF_CONC) {
        const group = []
        for (let g = k; g < Math.min(k + REF_CONC, refBatchCount); g++) group.push(runRef(g))
        await Promise.all(group)
        await yieldToMainThread()
      }

      // 4h. 批量更新订单状态为 refunded（in 批量）
      const orderIds = [...new Set(matchedRefunds.map(m => m.orderRow.id))]
      for (let i = 0; i < orderIds.length; i += 500) {
        const chunk = orderIds.slice(i, i + 500)
        try {
          await sb.from('orders').update({ status: 'refunded' }).in('id', chunk)
        } catch (e) { console.warn('批量更新订单状态失败:', e) }
      }
    }
  }

  // ========== 第五步：一次性更新所有账户余额（并发 4） ==========
  onProgress?.({ type: 'balance', current: 0, total: balanceDeltas.size, message: '更新账户余额...' })

  const BAL_CONC = 4
  const balEntries = [...balanceDeltas].filter(([, d]) => d !== 0)
  // 批量预拉余额（一次 in 查询），再并发更新
  const balIds = balEntries.map(([id]) => id)
  const accRowMap = new Map()
  for (let i = 0; i < balIds.length; i += 200) {
    const chunk = balIds.slice(i, i + 200)
    try {
      const { data: accs } = await sb.from('accounts')
        .select('id, balance, category, balance_method')
        .in('id', chunk)
      for (const a of (accs || [])) accRowMap.set(a.id, a)
    } catch (e) { console.warn('余额预拉取失败:', e) }
  }

  let _balDone = 0
  const runBal = async ([accountId, delta]) => {
    try {
      const acc = accRowMap.get(accountId)
      // ⚠️ 电商店铺 balance_method='manual' 不自动累加余额(和 orders.js 的行为保持一致)
      if (acc && !(acc.category === 'ecommerce' && acc.balance_method === 'manual')) {
        await sb.from('accounts')
          .update({ balance: Number(acc.balance) + delta })
          .eq('id', accountId)
      }
    } catch (e) {
      console.warn('余额更新失败:', accountId, e)
    } finally {
      _balDone++
      if (_balDone % 5 === 0) {
        onProgress?.({ type: 'balance', current: _balDone, total: balEntries.length, message: `更新账户余额 ${_balDone}/${balEntries.length}` })
      }
    }
  }
  for (let k = 0; k < balEntries.length; k += BAL_CONC) {
    const group = balEntries.slice(k, k + BAL_CONC).map(runBal)
    await Promise.all(group)
  }

  onProgress?.({ type: 'done', current: 1, total: 1,
    message: `导入完成：${result.success} 成功，${result.skippedRefunded} 笔全额退款已对冲跳过` })

  return result
}

// ============ 辅助函数 ============

/**
 * 查找或创建电商账户
 */
async function findOrCreateEcommerceAccount(sb, platformType, storeName) {
  if (!storeName) return null

  // 先尝试精确匹配
  const { data: existing } = await sb
    .from('accounts')
    .select('id, short_name, platform')
    .eq('status', 'active')
    .limit(500)

  if (existing) {
    // 精确匹配店铺名
    const exactMatch = existing.find(a =>
      (a.short_name || '').includes(storeName)
    )
    if (exactMatch) return exactMatch

    // 匹配同平台账户
    const platformMatch = existing.find(a => a.platform === platformType)
    if (platformMatch) return platformMatch
  }

  // 自动创建新账户
  try {
    const { data: newAccount, error } = await sb
      .from('accounts')
      .insert({
        short_name: storeName,
        code: storeName,
        platform: platformType,
        ecommerce_platform: platformType,
        settlement_days: platformType === 'kuaishou' ? 7 : 15,
        balance: 0,
        opening_balance: 0,
        status: 'active',
      })
      .select()
      .single()

    if (error) throw error
    return newAccount || null
  } catch (e) {
    console.warn('自动创建账户失败:', storeName, e)
    return null
  }
}

/**
 * 解析各种时间格式
 */
function parseOrderTime(dateStr) {
  if (!dateStr) return null
  if (typeof dateStr === 'number') {
    // Excel serial date
    const d = new Date((dateStr - 25569) * 86400 * 1000)
    return isNaN(d.getTime()) ? null : d.toISOString()
  }
  const str = String(dateStr).trim()
  const d = new Date(str)
  if (!isNaN(d.getTime())) return d.toISOString()
  // 尝试常见格式: 2026-01-01 12:00:00, 2026/1/1 12:00
  const match = str.match(/(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?/)
  if (match) {
    const [, y, m, d2, h, min, s] = match
    const isoStr = `${y}-${m.padStart(2, '0')}-${d2.padStart(2, '0')}T${(h || '00').padStart(2, '0')}:${(min || '00').padStart(2, '0')}:${(s || '00').padStart(2, '0')}+08:00`
    const parsed = new Date(isoStr)
    if (!isNaN(parsed.getTime())) return parsed.toISOString()
  }
  return null
}

/**
 * 平台中文名 —— 使用 utils.js 统一的 PLATFORM_LABELS
 */
export function platformTypeName(type) {
  return PLATFORM_LABELS[type] || type || ''
}
