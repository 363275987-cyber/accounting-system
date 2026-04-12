/**
 * Excel批量导入订单 - 工具函数
 * 依赖：全局 XLSX 对象（SheetJS CDN）
 */

// 系统字段定义
export const IMPORT_FIELDS = [
  { key: 'customer_name', label: '客户姓名', required: true },
  { key: 'customer_phone', label: '客户电话', required: false },
  { key: 'customer_address', label: '收货地址', required: false },
  { key: 'amount', label: '订单金额', required: true },
  { key: 'product_name', label: '产品名称', required: true },
  { key: 'quantity', label: '数量', required: false },
  { key: 'service_number', label: '客服号', required: false },
  { key: 'payment_method', label: '收款方式', required: false },
  { key: 'note', label: '备注', required: false },
]

// 收款方式映射
const PAYMENT_METHOD_MAP = {
  '微信': 'wechat',
  '微信收款': 'wechat',
  '支付宝': 'alipay',
  '银行卡': 'bank_transfer',
  '银行卡转账': 'bank_transfer',
  '淘宝': 'taobao',
  '抖音': 'douyin',
  '抖音小店': 'douyin',
  '现金': 'cash',
  '其他': 'other',
}

/**
 * 解析Excel文件
 * @param {File} file
 * @returns {Promise<{ headers: string[], rows: any[][] }>}
 */
export async function parseExcelFile(file) {
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
        const workbook = XLSX.read(data, { type: 'array' })
        const sheetName = workbook.SheetNames[0]
        const sheet = workbook.Sheets[sheetName]
        const jsonData = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' })

        if (jsonData.length < 2) {
          reject(new Error('Excel文件为空或只有表头'))
          return
        }

        const headers = jsonData[0].map(h => String(h).trim())
        const rows = jsonData.slice(1).filter(row => {
          // 跳过完全空的行
          return row.some(cell => cell !== '' && cell !== null && cell !== undefined)
        })

        resolve({ headers, rows })
      } catch (err) {
        reject(new Error('解析Excel失败: ' + err.message))
      }
    }
    reader.onerror = () => reject(new Error('读取文件失败'))
    reader.readAsArrayBuffer(file)
  })
}

/**
 * 自动匹配Excel列名到系统字段
 * @param {string[]} excelHeaders
 * @returns {Object} { fieldKey: excelHeaderIndex }
 */
export function autoMatchColumns(excelHeaders) {
  const mapping = {}
  const fieldAliases = {
    customer_name: ['客户姓名', '姓名', '客户名称', '联系人', '客户'],
    customer_phone: ['客户电话', '电话', '手机号', '手机', '联系电话', '联系方式'],
    customer_address: ['收货地址', '地址', '送货地址', '详细地址', '收件地址'],
    amount: ['订单金额', '金额', '总价', '总金额', '订单总价', '应付金额'],
    product_name: ['产品名称', '产品', '商品名称', '商品', '产品名', '商品名', '货物名称'],
    quantity: ['数量', '购买数量', '商品数量', '订购数量'],
    service_number: ['客服号', '客服编号', '服务号'],
    payment_method: ['收款方式', '付款方式', '支付方式', '收款渠道'],
    note: ['备注', '说明', '订单备注', '备注信息'],
  }

  for (const field of IMPORT_FIELDS) {
    const aliases = fieldAliases[field.key] || [field.label]
    const idx = excelHeaders.findIndex(h => {
      const lower = h.toLowerCase().trim()
      return aliases.some(alias => lower === alias.toLowerCase())
    })
    if (idx >= 0) {
      mapping[field.key] = idx
    }
  }

  return mapping
}

/**
 * 生成下载用的Excel模板
 */
export function downloadTemplate() {
  if (typeof XLSX === 'undefined') {
    throw new Error('SheetJS 未加载')
  }

  const headers = IMPORT_FIELDS.map(f => f.label)
  const wsData = [headers, ['张三', '13800138000', '北京市朝阳区xxx', '299.00', '黑八球杆', '1', '001', '微信收款', '加急发货']]

  const ws = XLSX.utils.aoa_to_sheet(wsData)

  // 设置列宽
  ws['!cols'] = [
    { wch: 12 }, { wch: 16 }, { wch: 30 }, { wch: 12 },
    { wch: 16 }, { wch: 8 }, { wch: 10 }, { wch: 12 }, { wch: 20 },
  ]

  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, '订单模板')
  XLSX.writeFile(wb, '订单导入模板.xlsx')
}

/**
 * 根据列映射和数据行，转换为订单对象
 * @param {Object} columnMapping - { fieldKey: headerIndex }
 * @param {any[][]} rows - Excel数据行
 * @param {number} startRow - 起始行号（用于错误提示）
 * @returns {{ orders: Object[], errors: { row: number, message: string }[] }}
 */
export function mapRowsToOrders(columnMapping, rows, startRow = 1) {
  const orders = []
  const errors = []
  const seenPhones = new Set() // 用于检测重复

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i]
    const rowNumber = startRow + i
    const order = {}

    for (const field of IMPORT_FIELDS) {
      const colIdx = columnMapping[field.key]
      if (colIdx !== undefined && colIdx !== null && colIdx >= 0) {
        let val = row[colIdx]
        if (val !== null && val !== undefined) {
          val = String(val).trim()
        } else {
          val = ''
        }

        // 特殊处理
        if (field.key === 'amount') {
          // 清理金额：去除逗号、空格
          val = val.replace(/[,，\s]/g, '')
          const num = parseFloat(val)
          if (isNaN(num) || num < 0) {
            if (field.required) {
              errors.push({ row: rowNumber, message: `金额 "${val}" 不是有效的数字` })
              break
            }
            order[field.key] = 0
          } else {
            order[field.key] = num
          }
        } else if (field.key === 'quantity') {
          const num = parseInt(val) || 1
          order[field.key] = Math.max(1, num)
        } else if (field.key === 'payment_method') {
          order[field.key] = PAYMENT_METHOD_MAP[val] || ''
        } else {
          order[field.key] = val
        }
      }
    }

    if (errors.length > 0 && errors[errors.length - 1].row === rowNumber) {
      // 该行已有错误，跳过后续验证
      continue
    }

    // 验证必填字段
    const missing = []
    for (const field of IMPORT_FIELDS) {
      if (field.required && !order[field.key]) {
        missing.push(field.label)
      }
    }
    if (missing.length > 0) {
      errors.push({ row: rowNumber, message: `缺少必填字段: ${missing.join('、')}` })
      continue
    }

    // 跳过空行（客户姓名和金额都为空）
    if (!order.customer_name && !order.amount) {
      continue
    }

    // 重复检测（基于客户电话+金额）
    const dupKey = `${order.customer_phone}_${order.amount}_${order.product_name}`
    if (order.customer_phone && seenPhones.has(dupKey)) {
      errors.push({ row: rowNumber, message: `与前面订单重复（同电话+金额+产品）` })
      continue
    }
    seenPhones.add(dupKey)

    // 默认值
    if (!order.quantity) order.quantity = 1
    if (!order.payment_method) order.payment_method = 'wechat'
    if (!order.status) order.status = 'completed'
    if (!order.order_source) order.order_source = 'sales_guided'

    orders.push(order)
  }

  return { orders, errors }
}
