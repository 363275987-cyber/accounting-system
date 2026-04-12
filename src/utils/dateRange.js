// 日期范围工具：把用户输入的 YYYY-MM-DD 转成带本地时区的 ISO 字符串，
// 避免直接拼 "T00:00:00" 被数据库按 UTC 解析导致差 8 小时。
//
// 用法：
//   query = query.gte('created_at', dayStart(dateFrom))
//   query = query.lte('created_at', dayEnd(dateTo))

function tzOffsetSuffix(date = new Date()) {
  const offsetMin = -date.getTimezoneOffset() // 本地相对 UTC 的分钟数，东八区为 +480
  const sign = offsetMin >= 0 ? '+' : '-'
  const abs = Math.abs(offsetMin)
  const hh = String(Math.floor(abs / 60)).padStart(2, '0')
  const mm = String(abs % 60).padStart(2, '0')
  return `${sign}${hh}:${mm}`
}

/**
 * 返回某日 00:00:00 本地时间的 ISO 字符串（含时区）
 * @param {string} ymd YYYY-MM-DD
 * @returns {string|null}
 */
export function dayStart(ymd) {
  if (!ymd) return null
  return `${ymd}T00:00:00${tzOffsetSuffix()}`
}

/**
 * 返回某日 23:59:59.999 本地时间的 ISO 字符串（含时区）
 * @param {string} ymd YYYY-MM-DD
 * @returns {string|null}
 */
export function dayEnd(ymd) {
  if (!ymd) return null
  return `${ymd}T23:59:59.999${tzOffsetSuffix()}`
}
