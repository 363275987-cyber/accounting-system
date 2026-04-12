/**
 * 订单文本解析器
 * 将粘贴的订单文本解析为结构化字段
 */

// 已知品牌列表（XX单 格式中的品牌）
const KNOWN_BRANDS = ['国熙', 'DBA', '美兹', '先锋', '奥秘', '美洲豹', '隋然', 'LUFER']

// 订单类型 → 产品分类映射
const ORDER_TYPE_TO_CATEGORY = {
  '球杆单': 'cue',
  '实物单': 'accessory',
  '教学单': 'recording_course',
  '线下课单': 'offline_camp',
  '录播课单': 'recording_course',
  '配件单': 'accessory',
}

// 收款平台 → 付款方式映射
const PLATFORM_TO_PAYMENT = {
  '有赞': 'wechat',
  '微信': 'wechat',
  '淘宝': 'taobao',
  '抖音': 'douyin',
  '快手': 'kuaishou',
  '支付宝': 'alipay',
  '银行卡': 'bank_transfer',
  '现金': 'cash',
}

// 地区标签关键词（不会映射到订单类型）
const REGION_KEYWORDS = ['深圳', '广州', '东莞', '惠州', '珠海', '佛山', '中山', '江门', '肇庆', '上海', '北京', '成都', '武汉', '杭州', '南京', '苏州', '长沙', '郑州', '重庆', '西安', '厦门', '福州', '昆明', '贵阳', '南昌', '合肥', '济南', '青岛', '大连', '沈阳', '哈尔滨', '长春', '太原', '石家庄', '天津', '兰州', '西宁', '银川', '呼和浩特', '乌鲁木齐', '拉萨', '海口', '三亚', '南宁', '宁波', '温州', '无锡', '常州', '徐州', '烟台', '威海', '洛阳', '汕头', '湛江']

/**
 * 解析产品明细字符串，统计产品数量
 * @param {string} productsStr - 用 + 分隔的产品字符串，如 "球杆*1+皮头*2"
 * @returns {Array<{name: string, qty: number}>}
 */
function parseProducts(productsStr) {
  if (!productsStr) return []
  
  const items = productsStr.split(/\+/).map(s => s.trim()).filter(Boolean)
  const result = []
  
  for (const item of items) {
    const match = item.match(/^(.+?)\*(\d+)$/)
    if (match) {
      result.push({ name: match[1].trim(), qty: parseInt(match[2], 10) })
    } else {
      result.push({ name: item.trim(), qty: 1 })
    }
  }
  
  // 合并同名产品
  const merged = {}
  for (const item of result) {
    if (merged[item.name]) {
      merged[item.name] += item.qty
    } else {
      merged[item.name] = item.qty
    }
  }
  
  return Object.entries(merged).map(([name, qty]) => ({ name, qty }))
}

/**
 * 从 "XX单" 标签中分类为品牌、地区、订单类型
 * @param {string[]} tags - 如 ['国熙单', '深圳单', '球杆单', '实物单']
 * @returns {{ brands: string[], regions: string[], types: string[], category: string|null }}
 */
function classifyTags(tags) {
  const brands = []
  const regions = []
  const types = []
  let category = null
  const categoryPriority = { cue: 3, offline_camp: 2, recording_course: 2, accessory: 1 }
  
  for (const tag of tags) {
    const name = tag.replace(/单$/, '')
    
    if (name && ORDER_TYPE_TO_CATEGORY[tag]) {
      types.push(tag)
      const cat = ORDER_TYPE_TO_CATEGORY[tag]
      // Prefer higher priority category (e.g., cue > accessory)
      if (!category || (categoryPriority[cat] || 0) > (categoryPriority[category] || 0)) {
        category = cat
      }
    } else if (KNOWN_BRANDS.includes(name)) {
      brands.push(tag)
    } else if (name && REGION_KEYWORDS.some(k => name.includes(k))) {
      regions.push(tag)
    } else {
      // 未知标签，归为通用标签
      types.push(tag)
    }
  }
  
  return { brands, regions, types, category }
}

/**
 * 从订单文本中提取收货地址
 * 地址特征：连续汉字+数字，包含省市县区镇乡村街道路号栋楼室等关键词
 * @param {string} text - 原始订单文本
 * @param {Object} result - 已解析的部分结果（包含customer_name, customer_phone, products等）
 * @returns {string}
 */
function extractAddress(text, result) {
  // 地址关键词正则：至少包含一个地址后缀
  const ADDR_SUFFIX = '(?:省|市|区|县|镇|乡|村|街道|路|大道|街|号|栋|幢|楼|层|室|院|小区|花园|公寓|家园|城|苑|府|庭|广场|商店|超市|医院|学校|大厦|中心|商务|科技|工业|开发区|园区|特区|新城|新区|社区|组团|组团|里|弄|巷|坊|座|单元|梯|幢|居|寓|舍|坊)'
  const ADDR_PATTERN = new RegExp(
    '[\\u4e00-\\u9fff\\dA-Za-z()（）\\-·]+' + ADDR_SUFFIX + '[\\u4e00-\\u9fff\\dA-Za-z()（）\\-·]*',
    'g'
  )
  
  // 先清理掉已知的非地址部分
  let cleanText = text
  // 去掉序号
  cleanText = cleanText.replace(/^\d+\.\s+/, '')
  // 去掉标签
  cleanText = cleanText.replace(/【[^】]+】/g, '')
  // 去掉客服号+平台（如"南165太泰有赞"）
  cleanText = cleanText.replace(/(南|北)\d+[\u4e00-\u9fff]*(有赞|微信|淘宝|抖音|快手|支付宝|小红书|拼多多|京东|现金)/, '')
  // 去掉日期
  cleanText = cleanText.replace(/\d{1,2}日/g, '')
  // 去掉金额
  cleanText = cleanText.replace(/[￥¥]?\d+(?:,\d{3})*(?:\.\d+)?\s*元/, '')
  // 去掉产品明细（含*或+的部分）
  cleanText = cleanText.replace(/[\u4e00-\u9fffA-Za-z0-9]+[*+][\u4e00-\u9fffA-Za-z0-9*+\s]*/g, '')
  // 去掉XX单标签
  cleanText = cleanText.replace(/[\u4e00-\u9fffA-Za-z]+单/g, '')
  
  // 匹配所有可能的地址
  const matches = cleanText.match(ADDR_PATTERN)
  if (!matches || matches.length === 0) return ''
  
  // 过滤：地址长度至少3个字符，且不能是纯人名
  let addresses = matches.filter(m => {
    const trimmed = m.trim()
    // 太短的不是地址
    if (trimmed.length < 3) return false
    // 排除已知的人名（就是customer_name本身）
    if (trimmed === result.customer_name) return false
    // 排除纯中文2-4字的（可能是人名）
    if (/^[\u4e00-\u9fff]{2,4}$/.test(trimmed)) return false
    return true
  })
  
  if (addresses.length === 0) return ''
  
  // 如果有多个匹配，取最长的（通常地址越长越完整）
  addresses.sort((a, b) => b.length - a.length)
  
  // 清理地址：去掉首尾空白和多余标点
  let addr = addresses[0].trim()
  // 去掉开头的姓名部分
  if (result.customer_name && addr.startsWith(result.customer_name)) {
    addr = addr.substring(result.customer_name.length).trim()
  }
  // 去掉开头或结尾的电话号码
  if (result.customer_phone) {
    addr = addr.replace(new RegExp(result.customer_phone.replace(/[\s-]/g, '[\\s-]?'), 'g'), '').trim()
  }
  
  return addr
}

/**
 * 解析单条订单文本
 * @param {string} text - 单条订单文本
 * @returns {Object} 解析后的订单字段
 */
function parseSingleOrder(text) {
  const result = {
    _rawText: text,
    sequence: '',
    service_number: '',
    platform: '',
    platform_raw: '',
    date_raw: '',
    brands: [],
    regions: [],
    order_types: [],
    product_category: '',
    amount: null,
    products_raw: '',
    products: [],
    customer_address: '',
    customer_name: '',
    customer_phone: '',
    order_no: '',
    tags: [],      // 其他未分类标签（如 大坤单、黄埔军团）
    note: '',
  }
  
  // 提取订单号
  const orderNoMatch = text.match(/【订单号：([^\】]+)】/)
  if (orderNoMatch) {
    result.order_no = orderNoMatch[1]
    // 去除订单号部分，方便后续解析
    text = text.replace(/【订单号：[^\】]+】/, '')
  }
  
  // 提取【标签】（如【大坤单】【黄埔军团】【前端单】）
  const tagRegex = /【([^】]+)】/g
  let tagMatch
  while ((tagMatch = tagRegex.exec(text)) !== null) {
    result.tags.push(tagMatch[1])
  }
  text = text.replace(/【[^】]+】/g, '')
  
  // 提取序号 (如 "2." 或 "5.")
  // 提取序号 (如 "1. " 或 "2. " 开头，必须是数字+点+空格+中文，避免误匹配小数如"1.2元"
  const seqMatch = text.match(/^(\d+)\.\s+[\u4e00-\u9fff]/)
  if (seqMatch) {
    result.sequence = String(seqMatch[1])
  }
  
  // 提取客服号(南/北+数字)和平台
  // 客服号只取"南/北+数字"，后面的人名+平台分开处理
  const serviceMatch = text.match(/(南|北)(\d+)([\u4e00-\u9fff]*?)(有赞|微信|淘宝|抖音|快手|支付宝|小红书|拼多多|京东|现金)/)
  if (serviceMatch) {
    result.service_number = serviceMatch[1] + serviceMatch[2]
    result.service_number_name = serviceMatch[3] // 人名部分（如"太泰"）
    result.platform_raw = serviceMatch[4]
    result.platform = PLATFORM_TO_PAYMENT[serviceMatch[4]] || 'other'
    // 收款账户关键词 = 人名+平台（如"太泰有赞"）
    result.account_keyword = (serviceMatch[3] + serviceMatch[4])
  } else {
    // 宽松匹配：只有南/北+数字+中文字符
    const looseServiceMatch = text.match(/(南|北)(\d+)([\u4e00-\u9fff]+)/)
    if (looseServiceMatch) {
      result.service_number = looseServiceMatch[1] + looseServiceMatch[2]
      result.service_number_name = looseServiceMatch[3]
      result.account_keyword = looseServiceMatch[3]
    }
  }
  
  // 提取日期 (如 "07日")
  const dateMatch = text.match(/(\d{1,2})日/)
  if (dateMatch) {
    result.date_raw = dateMatch[1] + '日'
  }
  
  // 提取金额 (如 "1980元")，支持￥/¥符号
  const amountMatch = text.match(/[￥¥]?(\d+(?:,\d{3})*(?:\.\d+)?)\s*元/)
  if (amountMatch) {
    result.amount = parseFloat(amountMatch[1].replace(/,/g, ''))
  }

  // ========== 提取电话号码 ==========
  // 支持格式：11位手机、带空格/横杠的11位、400开头、区号+座机
  let phoneMatch = null
  // 11位手机号（可能带空格或横杠分隔）
  phoneMatch = text.match(/1[3-9]\d[\s-]?\d{4}[\s-]?\d{4}/)
  if (!phoneMatch) {
    // 400电话
    phoneMatch = text.match(/400[ -]?\d{3}[ -]?\d{4}/)
  }
  if (!phoneMatch) {
    // 座机（区号-号码）
    phoneMatch = text.match(/0\d{2,3}[- ]?\d{7,8}/)
  }
  if (phoneMatch) {
    result.customer_phone = phoneMatch[0].replace(/[\s-]/g, '')
  }

  // ========== 提取客户姓名 ==========
  // 策略1：手机号前面紧邻的中文名（2-4个汉字，可能有空格）
  if (phoneMatch) {
    const beforePhone = text.substring(0, phoneMatch.index)
    // 紧邻手机号前面，可能有空格
    const nameBefore = beforePhone.match(/([\u4e00-\u9fff]{2,4})\s*$/)
    if (nameBefore) {
      result.customer_name = nameBefore[1]
    } else {
      // 策略2：手机号后面紧跟的中文名
      const afterPhone = text.substring(phoneMatch.index + phoneMatch[0].length)
      const nameAfter = afterPhone.match(/^\s*([\u4e00-\u9fff]{2,4})/)
      if (nameAfter) {
        result.customer_name = nameAfter[1]
      }
    }
  }
  // 策略3：如果没找到姓名但找到了电话，尝试从"姓名 电话"模式匹配
  if (!result.customer_name && phoneMatch) {
    const phoneIdx = phoneMatch.index
    const beforePart = text.substring(Math.max(0, phoneIdx - 10), phoneIdx)
    const nameInContext = beforePart.match(/([\u4e00-\u9fff]{2,4})\s*$/)
    if (nameInContext) {
      result.customer_name = nameInContext[1]
    }
  }
  
  // 提取所有 "XX单" 标签
  const singleTags = text.match(/[\u4e00-\u9fffA-Za-z]+单/g) || []
  const classified = classifyTags(singleTags)
  result.brands = classified.brands
  result.regions = classified.regions
  result.order_types = classified.types
  result.product_category = classified.category || ''
  
  // 提取产品明细: 金额之后、地址开始之前的连续产品信息
  // 产品特征：包含 *数字 或 + 分隔
  let productsRaw = ''
  if (amountMatch) {
    const afterAmount = text.substring(amountMatch.index + amountMatch[0].length)
    
    // 地址特征：包含省/市/区/县/镇/乡/村/街道/路/道/号/栋/楼/室/院/小区/花园/公寓/苑/府/城
    const addrStart = afterAmount.search(/[\u4e00-\u9fff]{2,}(?:省|市|区|县|镇|乡|村|街道|路|大道|号|栋|楼|室|院|小区|商店|超市|医院|学校|广场|花园|公寓|家园|城|苑|府|庭)/)
    const namePhoneStart = phoneMatch ? afterAmount.indexOf(result.customer_name) : -1
    
    let endIdx = afterAmount.length
    if (addrStart >= 0) endIdx = Math.min(endIdx, addrStart)
    if (namePhoneStart >= 0) endIdx = Math.min(endIdx, namePhoneStart)
    
    // 只取包含 + 或 * 的部分作为产品明细
    const candidate = afterAmount.substring(0, endIdx).trim()
    if (candidate.includes('+') || candidate.includes('*')) {
      productsRaw = candidate
    }
  }
  
  result.products_raw = productsRaw
  result.products = parseProducts(productsRaw)
  
  // ========== 提取收货地址 ==========
  // 地址特征：连续汉字中包含省/市/区/县/镇/乡/村/街道/路/道/号/栋/楼/室等
  // 策略：在整个文本中搜索地址模式
  result.customer_address = extractAddress(text, result)
  
  // 组装产品名称字段
  if (result.products.length > 0) {
    result.product_name = result.products
      .map(p => p.qty > 1 ? `${p.name}*${p.qty}` : p.name)
      .join(' + ')
  } else {
    result.product_name = ''
  }
  
  return result
}

/**
 * 解析订单文本（支持多条）
 * 按序号（数字+点）分隔多条订单
 * @param {string} text - 粘贴的原始文本
 * @returns {Array<Object>} 解析后的订单数组
 */
export function parseOrderText(text) {
  if (!text || !text.trim()) return []
  
  // 按换行分割：每行一条订单
  const lines = text.trim().split('\n').map(l => l.trim()).filter(l => l.length > 5)
  
  return lines.map(line => parseSingleOrder(line))
}

/**
 * 将解析结果转为表单字段
 * @param {Object} parsed - parseSingleOrder 的结果
 * @returns {Object} 可直接赋给表单的字段
 */
export function parsedToForm(parsed) {
  return {
    service_number: parsed.service_number || '',
    payment_method: parsed.platform || 'wechat',
    customer_name: parsed.customer_name || '',
    customer_phone: parsed.customer_phone || '',
    customer_address: parsed.customer_address || '',
    product_category: parsed.product_category || '',
    product_name: parsed.product_name || '',
    amount: parsed.amount || null,
    note: [
      parsed.brands.join('、'),
      parsed.regions.join('、'),
      parsed.order_types.join('、'),
      parsed.tags.length > 0 ? parsed.tags.join('、') : '',
      parsed.order_no ? `订单号：${parsed.order_no}` : '',
    ].filter(Boolean).join(' | '),
  }
}
