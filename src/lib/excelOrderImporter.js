/**
 * Excel批量导入订单解析器
 * 支持三种格式自动识别：
 * 1. 聚水潭导出（单sheet，72列）
 * 2. 抖店后台导出（多sheet，取销售订单明细sheets）
 * 3. 通用模板格式（降级）
 */

// 状态映射
const STATUS_MAP = {
  '已发货': 'completed',
  '已完成': 'completed',
  '已签收': 'completed',
  '确认收货': 'completed',
  '已取消': 'cancelled',
  '售后中': 'pending',
  '退款中': 'pending',
  '待发货': 'pending',
  '部分发货': 'completed',
  '交易关闭': 'cancelled',
  '订单关闭': 'cancelled',
}

// 店铺名 → 平台映射
const STORE_PLATFORM_MAP = {
  '快手': 'kuaishou',
  '抖店': 'douyin',
  '抖音': 'douyin',
  '视频号': 'weixin_video',
  '淘宝': 'taobao',
  '天猫': 'taobao',
  '京东': 'jd',
  '拼多多': 'pdd',
  '小红书': 'xiaohongshu',
  '有赞': 'youzan',
  '微信': 'wechat',
}

// 店铺名前缀 → 客服号前缀映射
const STORE_SERVICE_MAP = {
  '南': '南',
  '辉': '辉',
}

// ============ 通用工具函数 ============

function parsePlatform(storeName) {
  if (!storeName) return 'other'
  for (const [prefix, platform] of Object.entries(STORE_PLATFORM_MAP)) {
    if (storeName.includes(prefix)) return platform
  }
  return 'other'
}

function parseServicePrefix(storeName) {
  if (!storeName) return ''
  for (const [keyword, prefix] of Object.entries(STORE_SERVICE_MAP)) {
    if (storeName.includes(keyword)) return prefix
  }
  return ''
}

/**
 * 过滤无效收货人
 * - 用户ID格式（如 "209:JpDgjr..."）
 * - 纯乱码脱敏名（如 "昂**"）
 * - 过短的名字（1个字且含*）
 */
function filterCustomerName(name) {
  if (!name) return ''
  const trimmed = name.trim()
  // 用户ID特征
  if (/^\d{1,5}[:：]/.test(trimmed) || /^[A-Za-z0-9]{10,}$/.test(trimmed)) {
    return ''
  }
  // 脱敏名：只有1-2个汉字+星号（如"昂**"、"张*"）
  if (/^[\u4e00-\u9fff]{1,2}\*+$/.test(trimmed)) {
    return ''
  }
  // 去掉控制字符
  return trimmed.replace(/[\x00-\x1F]/g, '')
}

function parseStatus(statusRaw) {
  if (!statusRaw) return 'completed'
  return STATUS_MAP[statusRaw.trim()] || 'completed'
}

function parseDate(dateVal) {
  if (!dateVal) return null
  if (typeof dateVal === 'number') {
    const d = new Date((dateVal - 25569) * 86400 * 1000)
    return isNaN(d.getTime()) ? null : d.toISOString()
  }
  const str = String(dateVal).trim()
  const d = new Date(str)
  if (!isNaN(d.getTime())) return d.toISOString()
  const match = str.match(/(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})/)
  if (match) return new Date(match[1], match[2] - 1, match[3]).toISOString()
  return null
}

/**
 * 解析Excel文件，返回workbook和sheet列表
 */
async function parseExcelWorkbook(file) {
  if (typeof XLSX === 'undefined') {
    throw new Error('SheetJS 未加载，请刷新页面重试')
  }
  const ext = file.name.split('.').pop().toLowerCase()
  if (!['xlsx', 'xls'].includes(ext)) {
    throw new Error('仅支持 .xlsx 和 .xls 格式')
  }
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result)
        const workbook = XLSX.read(data, { type: 'array', cellDates: true })
        resolve(workbook)
      } catch (err) {
        reject(new Error('解析Excel失败: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('读取文件失败'))
    reader.readAsArrayBuffer(file)
  })
}

/**
 * 将sheet转为 { headers: string[], rows: Object[] }
 */
function sheetToRows(workbook, sheetName) {
  const sheet = workbook.Sheets[sheetName]
  if (!sheet) return null
  const jsonData = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '', raw: false })
  if (jsonData.length < 2) return null
  const headers = jsonData[0].map(h => String(h).trim())
  const rows = jsonData.slice(1)
    .filter(row => row.some(cell => cell !== '' && cell !== null && cell !== undefined))
    .map(row => {
      const obj = {}
      headers.forEach((h, idx) => {
        obj[h] = row[idx] !== undefined && row[idx] !== null ? row[idx] : ''
      })
      return obj
    })
  return { headers, rows }
}

// ============ 格式识别 ============

/**
 * 识别Excel格式类型
 * @param {string[]} sheetNames
 * @param {string[]} firstHeaders - 第一个sheet的表头
 * @returns {'jst' | 'doudian' | 'generic'}
 */
export function detectExcelFormat(sheetNames, firstHeaders) {
  // 抖店后台：sheet名包含"销售订单明细"
  const hasSalesSheet = sheetNames.some(n => n.includes('销售订单明细'))
  if (hasSalesSheet) return 'doudian'

  // 聚水潭：sheet名包含"原始数据"或表头有聚水潭特征列
  if (sheetNames.some(n => n.includes('原始数据'))) return 'jst'
  const jstIndicators = ['线上订单号', '内部订单号', '产品分类', '成本价']
  const matchCount = firstHeaders.filter(h => jstIndicators.some(ind => h.includes(ind))).length
  if (matchCount >= 2) return 'jst'

  return 'generic'
}

/**
 * 获取格式描述文本
 */
export function getFormatLabel(format) {
  const labels = { jst: '聚水潭格式', doudian: '抖店后台格式', generic: '通用模板格式' }
  return labels[format] || '未知格式'
}

// ============ 聚水潭格式 ============

const JST_COLUMN_ALIASES = {
  external_order_no: ['线上订单号', '平台订单号', '订单编号'],
  internal_order_no: ['内部订单号', '系统订单号'],
  store_name: ['店铺', '店铺名称', '来源店铺'],
  status_raw: ['订单状态', '状态'],
  order_date: ['订单日期', '下单日期', '下单时间', '交易创建时间'],
  payment_date: ['付款日期', '付款时间'],
  product_name: ['名称', '商品名称', '货品名称', '商品', '产品名称'],
  brand: ['品牌'],
  product_category: ['产品分类', '商品分类', '类目'],
  unit_cost: ['成本价', '成本', '采购价', '货品成本'],
  amount: ['销售金额', '实付金额', '应付金额', '买家实付'],
  quantity: ['销售数量', '数量', '购买数量'],
  customer_name: ['收货人', '收件人', '买家昵称', '客户名称'],
  customer_phone: ['收货手机', '手机号', '联系电话'],
  province: ['省', '省份'],
  city: ['市', '城市'],
  district: ['区县', '区', '县'],
  express_company: ['快递公司', '物流公司'],
  express_no: ['快递单号', '物流单号'],
  total_amount: ['订单金额', '订单总金额', '总金额'],
  service_charge: ['平台服务费', '平台手续费', '技术服务费', '服务费'],
}

/**
 * 自动匹配聚水潭列名
 */
export function autoMatchJstColumns(headers) {
  const mapping = {}
  const usedHeaders = new Set()
  for (const [field, aliases] of Object.entries(JST_COLUMN_ALIASES)) {
    // 精确匹配
    let idx = headers.findIndex(h => aliases.some(alias => h.trim() === alias))
    // 模糊匹配（排除已使用的列）
    if (idx < 0) {
      idx = headers.findIndex((h) => {
        if (usedHeaders.has(h)) return false
        const lower = h.toLowerCase().trim()
        return aliases.some(alias => lower === alias.toLowerCase() || lower.includes(alias.toLowerCase()))
      })
    }
    if (idx >= 0) {
      mapping[field] = headers[idx]
      usedHeaders.add(headers[idx])
    }
  }
  return mapping
}

/**
 * 将聚水潭Excel行解析为订单对象
 */
export function mapJstRowsToOrders(excelRows, columnMap) {
  const orders = []
  let skipped = 0
  const seenOrderNos = new Set()

  for (let i = 0; i < excelRows.length; i++) {
    const row = excelRows[i]
    const rowIdx = i + 2

    const val = (field) => {
      const h = columnMap[field]
      if (!h) return ''
      const v = row[h]
      return (v !== undefined && v !== null) ? String(v).trim() : ''
    }
    const numVal = (field) => {
      const h = columnMap[field]
      if (!h) return 0
      const v = row[h]
      if (v === undefined || v === null || v === '') return 0
      if (typeof v === 'number') return v
      const n = parseFloat(String(v).replace(/[,，\s]/g, ''))
      return isNaN(n) ? 0 : n
    }

    const externalOrderNo = val('external_order_no')
    const storeName = val('store_name')
    const statusRaw = val('status_raw')
    const productName = val('product_name')
    const amount = numVal('amount')
    const quantity = (() => { const q = numVal('quantity'); return q > 0 ? Math.floor(q) : 1 })()
    const customerName = filterCustomerName(val('customer_name'))
    const customerPhone = val('customer_phone')

    // 跳过金额为0的行
    if (!amount) { skipped++; continue }

    // 跳过已取消的订单
    const status = parseStatus(statusRaw)
    if (status === 'cancelled') { skipped++; continue }

    // 重复订单号检测
    if (externalOrderNo && seenOrderNos.has(externalOrderNo)) { skipped++; continue }
    if (externalOrderNo) seenOrderNos.add(externalOrderNo)

    orders.push({
      _rowIdx: rowIdx,
      _selected: true,
      external_order_no: externalOrderNo,
      internal_order_no: val('internal_order_no'),
      store_name: storeName,
      platform: parsePlatform(storeName),
      status: parseStatus(statusRaw),
      status_raw: statusRaw,
      order_date: val('order_date'),
      payment_date: val('payment_date'),
      product_name: productName,
      brand: val('brand'),
      product_category: val('product_category'),
      unit_cost: numVal('unit_cost'),
      amount: amount,
      quantity: quantity,
      customer_name: customerName,
      customer_phone: customerPhone,
      province: val('province'),
      city: val('city'),
      district: val('district'),
      customer_address: '',
      express_company: val('express_company'),
      express_no: val('express_no'),
      total_amount: numVal('total_amount'),
      service_charge: numVal('service_charge'),
      service_prefix: parseServicePrefix(storeName),
    })
  }

  return { orders, skipped }
}

// ============ 抖店后台格式 ============

/**
 * 根据sheet名判断是否为抖店后台导出格式
 */
export function isDoudianFormatBySheets(sheetNames) {
  return sheetNames.some(name =>
    name.includes('销售订单明细') && !name.includes('售后')
  )
}

/**
 * 读取Excel获取所有sheet名（不解析全部数据，速度快）
 */
export async function getSheetNames(file) {
  const workbook = await parseExcelWorkbook(file)
  return workbook.SheetNames
}

const DOUDIAN_COLUMN_ALIASES = {
  external_order_no: ['订单号', '平台订单号', '外部订单号'],
  store_name: ['店铺'],
  status_raw: ['订单状态', '状态'],
  order_date: ['订单下单时间_1', '订单下单时间', '下单时间', '交易创建时间', '下单日期'],
  payment_date: ['付款时间', '订单付款时间'],
  product_name: ['商品名称', '名称', '货品名称', '商品', '产品名称'],
  brand: ['品牌'],
  product_category: ['商品分类', '产品分类', '类目', '三级类目'],
  unit_cost: ['成本价', '成本'],
  unit_price: ['商品实际价格(单件)', '商品单价', '单价'],
  amount: ['订单实际收款金额', '实际收款金额', '订单实付金额', '买家实付', '实付金额', '销售金额'],
  quantity: ['商品数量', '数量', '购买数量', '销售数量'],
  customer_name: ['收件人姓名', '收货人', '收件人', '客户名称'],
  customer_phone: ['收件人手机', '收货手机', '手机号', '联系电话'],
  customer_address: ['收件人地址', '收货地址', '详细地址'],
  province: ['省'],
  city: ['市'],
  district: ['区'],
  express_company: ['快递公司', '物流公司'],
  express_no: ['快递单号', '物流单号'],
  total_amount: ['订单金额', '订单总金额', '总金额'],
  // 抖店特有
  daihuo_account: ['带货账号昵称', '带货账号'],
  payment_method: ['支付方式', '付款方式'],
  service_charge: ['平台服务费', '平台手续费', '技术服务费', '服务费', '商家实收服务费'],
}

/**
 * 自动匹配抖店后台列名
 */
export function autoMatchDoudianColumns(headers) {
  const mapping = {}
  const usedHeaders = new Set()
  // 先精确匹配，再includes匹配
  for (const [field, aliases] of Object.entries(DOUDIAN_COLUMN_ALIASES)) {
    // 精确匹配
    let idx = headers.findIndex(h => {
      const t = h.trim()
      return aliases.some(alias => t === alias)
    })
    // 模糊匹配
    if (idx < 0) {
      idx = headers.findIndex((h, i) => {
        if (usedHeaders.has(h)) return false
        const t = h.toLowerCase().trim()
        return aliases.some(alias => t === alias.toLowerCase() || t.includes(alias.toLowerCase()))
      })
    }
    if (idx >= 0) {
      mapping[field] = headers[idx]
      usedHeaders.add(headers[idx])
    }
  }
  return mapping
}

/**
 * 获取抖店后台中需要读取的销售订单sheets
 * 规则：sheet名包含"销售订单明细"，排除包含"售后"的sheet
 */
function getDoudianSalesSheets(sheetNames) {
  return sheetNames.filter(name =>
    name.includes('销售订单明细') && !name.includes('售后')
  )
}

/**
 * 解析抖店后台Excel
 * 读取多个销售订单明细sheet，合并数据
 * @param {File} file
 * @returns {Promise<{ headers: string[], rows: Object[], sheetCount: number }>}
 */
export async function parseDoudianExcel(file) {
  const workbook = await parseExcelWorkbook(file)
  const salesSheets = getDoudianSalesSheets(workbook.SheetNames)

  if (salesSheets.length === 0) {
    throw new Error('未找到销售订单明细sheet，请确认文件格式')
  }

  let allRows = []
  let headers = null

  for (const sheetName of salesSheets) {
    const result = sheetToRows(workbook, sheetName)
    if (!result) continue
    if (!headers) headers = result.headers
    allRows = allRows.concat(result.rows)
  }

  if (!headers || allRows.length === 0) {
    throw new Error('销售订单明细sheet中没有数据')
  }

  return { headers, rows: allRows, sheetCount: salesSheets.length }
}

/**
 * 将抖店后台Excel行解析为订单对象
 */
export function mapDoudianRowsToOrders(excelRows, columnMap) {
  const orders = []
  let skipped = 0
  const seenOrderNos = new Set()

  for (let i = 0; i < excelRows.length; i++) {
    const row = excelRows[i]
    const rowIdx = i + 2

    const val = (field) => {
      const h = columnMap[field]
      if (!h) return ''
      const v = row[h]
      return (v !== undefined && v !== null) ? String(v).trim() : ''
    }
    const numVal = (field) => {
      const h = columnMap[field]
      if (!h) return 0
      const v = row[h]
      if (v === undefined || v === null || v === '') return 0
      if (typeof v === 'number') return v
      const n = parseFloat(String(v).replace(/[,，\s]/g, ''))
      return isNaN(n) ? 0 : n
    }

    const externalOrderNo = val('external_order_no')
    const storeName = val('store_name')
    const statusRaw = val('status_raw')
    const productName = val('product_name')
    const amount = numVal('amount')
    const quantity = (() => { const q = numVal('quantity'); return q > 0 ? Math.floor(q) : 1 })()
    const customerName = filterCustomerName(val('customer_name'))
    const customerPhone = val('customer_phone')

    // 拼接地址：省+市+区+详细地址
    const addrParts = [val('province'), val('city'), val('district'), val('customer_address')].filter(Boolean)
    const customerAddress = addrParts.join('')

    // 跳过金额为0或负数的行
    if (!amount || amount < 0) { skipped++; continue }

    // 跳过已取消的订单
    const status = parseStatus(statusRaw)
    if (status === 'cancelled') { skipped++; continue }

    // 重复订单号检测
    if (externalOrderNo && seenOrderNos.has(externalOrderNo)) { skipped++; continue }
    if (externalOrderNo) seenOrderNos.add(externalOrderNo)

    orders.push({
      _rowIdx: rowIdx,
      _selected: true,
      external_order_no: externalOrderNo,
      internal_order_no: '',
      store_name: storeName,
      platform: parsePlatform(storeName),
      status: parseStatus(statusRaw),
      status_raw: statusRaw,
      order_date: val('order_date'),
      payment_date: val('payment_date'),
      product_name: productName,
      brand: val('brand'),
      product_category: val('product_category'),
      unit_cost: numVal('unit_cost'),
      unit_price: numVal('unit_price'),
      amount: amount,
      quantity: quantity,
      customer_name: customerName,
      customer_phone: customerPhone,
      province: val('province'),
      city: val('city'),
      district: val('district'),
      customer_address: customerAddress,
      express_company: val('express_company'),
      express_no: val('express_no'),
      total_amount: numVal('total_amount'),
      service_charge: numVal('service_charge'),
      service_prefix: parseServicePrefix(storeName),
      daihuo_account: val('daihuo_account'),
      payment_method: val('payment_method'),
    })
  }

  return { orders, skipped }
}

// ============ 兼容旧接口（通用模板格式） ============

/**
 * @deprecated 用 parseExcelWorkbook + detectExcelFormat 代替
 */
export async function parseJstExcel(file) {
  const workbook = await parseExcelWorkbook(file)
  const firstSheet = workbook.SheetNames[0]
  const result = sheetToRows(workbook, firstSheet)
  if (!result) throw new Error('Excel文件为空或只有表头')
  return { headers: result.headers, rows: result.rows, _sheetNames: workbook.SheetNames }
}

/**
 * @deprecated 用 detectExcelFormat 代替
 */
export function isJstFormat(headers) {
  const jstIndicators = ['线上订单号', '内部订单号', '产品分类', '成本价']
  return headers.filter(h => jstIndicators.some(ind => h.includes(ind))).length >= 2
}

// ============ 产品匹配 ============

/**
 * 在产品库中模糊匹配产品
 * 三级匹配：精确 → 包含 → 关键词
 */
export function matchProduct(productName, products) {
  if (!productName || !products || products.length === 0) return null

  // 精确匹配
  let match = products.find(p => p.name === productName)
  if (match) return match

  // 包含匹配
  match = products.find(p => productName.includes(p.name) || p.name.includes(productName))
  if (match) return match

  // 关键词匹配：取产品名的主要部分
  const keywords = productName.replace(/[（(].+?[）)]/g, '').replace(/[\d\-\/\s]+/g, '').trim()
  if (keywords.length >= 2) {
    match = products.find(p => {
      const pKeywords = p.name.replace(/[（(].+?[）)]/g, '').replace(/[\d\-\/\s]+/g, '').trim()
      return pKeywords.includes(keywords) || keywords.includes(pKeywords)
    })
    if (match) return match
  }

  return null
}

/**
 * 通过 SKU 编码精确匹配（用于导入 Excel，聚水潭模式）
 */
export async function matchBySkuCode(skuCode, rpcFn) {
  if (!skuCode || !rpcFn) return null
  try {
    const { data, error } = await rpcFn("match_product_by_sku_code", { p_sku_code: String(skuCode).trim() })
    if (error || !data || !data.sku_id) return null
    return data
  } catch (e) {
    return null
  }
}
