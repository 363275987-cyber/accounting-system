// 共享工具函数

/**
 * 格式化金额
 */
export function formatMoney(amount, showSign = false) {
  if (amount == null) return '¥0'
  const formatted = Math.abs(amount).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  const prefix = showSign && amount > 0 ? '+' : ''
  const sign = amount < 0 ? '-' : ''
  return `${prefix}${sign}¥${formatted}`
}

/**
 * 格式化日期
 */
export function formatDate(dateStr, format = 'short') {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  if (format === 'short') {
    return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
  if (format === 'date') {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }
  if (format === 'full') {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }
  return d.toLocaleString('zh-CN')
}

/**
 * 产品分类映射
 */
export const PRODUCT_CATEGORIES = {
  cue: '球杆',
  accessory: '配件',
  recording_course: '录播课',
  offline_camp: '线下课',
  other: '其他',
}

export const PLATFORM_LABELS = {
  wechat: '微信',
  alipay: '支付宝',
  bank: '银行卡',
  taobao: '淘宝',
  douyin: '抖音',
  kuaishou: '快手',
  weixin_video: '视频号',
  shipinhao: '视频号',
  wechat_video: '视频号',
  jd: '京东',
  pdd: '拼多多',
  xiaohongshu: '小红书',
  youzan: '有赞',
  weidian: '微店',
  jushuitan: '聚水潭',
  cash: '现金',
  other: '其他',
}

export const PLATFORM_CATEGORIES = {
  wechat: { category: 'wechat', label: '微信（绑定客服号）' },
  alipay: { category: 'shared', label: '支付宝（共享）' },
  bank: { category: 'shared', label: '银行卡（共享）' },
  taobao: { category: 'ecommerce', label: '电商（淘宝）' },
  douyin: { category: 'ecommerce', label: '电商（抖音）' },
  kuaishou: { category: 'ecommerce', label: '电商（快手）' },
  weixin_video: { category: 'ecommerce', label: '电商（视频号）' },
  shipinhao: { category: 'ecommerce', label: '电商（视频号）' },
  jd: { category: 'ecommerce', label: '电商（京东）' },
  cash: { category: 'other', label: '现金' },
  other: { category: 'other', label: '其他' },
}

export const ECOMMERCE_PLATFORMS = {
  taobao: '淘宝',
  jd: '京东',
  douyin: '抖音',
  kuaishou: '快手',
  weixin_video: '视频号',
  shipinhao: '视频号',
}

export const EXPENSE_CATEGORIES = {
  salary: '工资',
  rent: '房租',
  equipment: '设备',
  marketing: '营销',
  tax: '税费',
  daily: '日常',
  shipping: '物流',
  platform_fee: '平台费',
  refund: '退款',
  other: '其他',
}

export const ORDER_STATUS = {
  pending: { label: '待确认', class: 'text-orange-600 bg-orange-50' },
  completed: { label: '已完成', class: 'text-green-600 bg-green-50' },
  cancelled: { label: '已取消', class: 'text-gray-500 bg-gray-50' },
  refunded: { label: '已全退款', class: 'text-red-500 bg-red-50' },
  partially_refunded: { label: '部分退款', class: 'text-amber-600 bg-amber-50' },
}

export const ORDER_SOURCE = {
  sales_guided: '销售引导',
  organic: '有机流量',
  cs_service: '客服处理',
  shared: '平分单',
}

export const REFUND_STATUS = {
  pending: { label: '待处理', class: 'text-orange-600 bg-orange-50' },
  processing: { label: '退款中', class: 'text-blue-600 bg-blue-50' },
  completed: { label: '已退款', class: 'text-green-600 bg-green-50' },
  failed: { label: '退款失败', class: 'text-red-500 bg-red-50' },
}

export const COMMISSION_STATUS = {
  pending: { label: '待确认', class: 'text-orange-600 bg-orange-50' },
  confirmed: { label: '已确认', class: 'text-blue-600 bg-blue-50' },
  paid: { label: '已发放', class: 'text-green-600 bg-green-50' },
}

export const COMMISSION_SOURCE = {
  order: '订单提成',
  live: '直播提成',
}

export const EXPENSE_STATUS = {
  pending: { label: '待审批', class: 'text-orange-600 bg-orange-50' },
  approved: { label: '已批准', class: 'text-blue-600 bg-blue-50' },
  paid: { label: '已付款', class: 'text-green-600 bg-green-50' },
  rejected: { label: '已驳回', class: 'text-red-500 bg-red-50' },
}

/**
 * 产品库分类
 */
export const PRODUCT_ITEM_CATEGORIES = {
  cue: '球杆',
  tip: '皮头',
  chalk: '巧克',
  shaft: '前支',
  extension: '加长把',
  jump_break: '冲跳杆',
  case: '杆盒',
  bag: '杆包',
  glove: '手套',
  towel: '毛巾',
  glue: '胶水',
  maintenance: '保养',
  rest: '架杆',
  ball: '球',
  table: '球桌/台尼',
  book: '书籍/画册',
  course: '课程',
  service: '服务费',
  accessory: '配件',
  consumable: '耗材',
  other: '其他',
}

export const PRODUCT_BRANDS = ['皮尔力', '来力', 'DBA', '国熙', '荆龙', '其他']

/**
 * Toast 通知系统 — 委托给 useToast composable（Vue 响应式）
 */
import { useToast as _useToast } from '../composables/useToast'
const _toast = _useToast()

export function toast(message, type = 'info', duration = 3000) {
  _toast.toast(message, type, duration)
}

/**
 * 防抖
 */
export function debounce(fn, delay = 300) {
  let timer
  return (...args) => {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), delay)
  }
}
