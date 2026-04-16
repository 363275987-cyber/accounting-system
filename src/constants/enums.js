/**
 * 枚举常量集中管理
 * ----------------
 * 这里的字符串必须和 Supabase 数据库 enum / 列里的真实值保持一致。
 * 任何前端判断都应当用这里的常量，而不是硬编码字符串。
 *
 * 新增枚举前请先用 Grep/数据库确认真值，不要凭想象写。
 */

/**
 * 固定资产状态 (public.assets.status)
 *
 * 真值依据:
 *   - BUG-2 已经确认 `in_use` 是在用资产的真值
 *   - src/views/Expenses.vue 智能记账写入 assets 时用的是 `'in_use'`
 *   - FixedAssets.vue 页面本地硬编码过 `'active'` / `'idle'` / `'disposed'`，
 *     与数据库不一致，是 BUG-2 / BUG-3 的根因
 *
 * 注意:
 *   - `ASSET_STATUS.IN_USE` = 'in_use' (在用，100% 确定)
 *   - `DISPOSED` / `IDLE` / `MAINTENANCE` 按旧代码和通用命名猜测，
 *     如果后续和数据库不一致请到这里统一调整
 */
export const ASSET_STATUS = {
  IN_USE: 'in_use',
  DISPOSED: 'disposed',
  MAINTENANCE: 'maintenance',
  IDLE: 'idle',
}

/**
 * 固定资产状态中文标签
 */
export const ASSET_STATUS_LABEL = {
  [ASSET_STATUS.IN_USE]: '在用',
  [ASSET_STATUS.IDLE]: '闲置',
  [ASSET_STATUS.MAINTENANCE]: '维修中',
  [ASSET_STATUS.DISPOSED]: '已处置',
}

/**
 * 无形资产状态 (public.intangible_assets.status)
 *
 * 业务语义不同于固定资产：
 *   - ACTIVE: 有效（如商标在有效期内）
 *   - EXPIRED: 已过期（仅适用于有 expiry_date 的资产）
 *   - DISPOSED: 已处置
 *
 * 数据库列是 text，无 enum 约束。当前真值依据 IntangibleAssets.vue 写入用 'active'。
 */
export const INTANGIBLE_ASSET_STATUS = {
  ACTIVE: 'active',
  EXPIRED: 'expired',
  DISPOSED: 'disposed',
}

export const INTANGIBLE_ASSET_STATUS_LABEL = {
  [INTANGIBLE_ASSET_STATUS.ACTIVE]: '有效',
  [INTANGIBLE_ASSET_STATUS.EXPIRED]: '已过期',
  [INTANGIBLE_ASSET_STATUS.DISPOSED]: '已处置',
}

/**
 * 账户状态 (public.accounts.status)
 *
 * 真值依据(2026-04-16 复核):
 *   - supabase/migrations/20260415_wave1_fixes.sql:248 — `WHERE status = 'active'`
 *   - Accounts.vue:1039 — toggleFreeze 切到 'frozen'
 * 'active'  → 正常使用
 * 'frozen'  → 已冻结(余额仍存在,只是不可流入流出)
 */
export const ACCOUNT_STATUS = {
  ACTIVE: 'active',
  FROZEN: 'frozen',
}

export const ACCOUNT_STATUS_LABEL = {
  [ACCOUNT_STATUS.ACTIVE]: '正常',
  [ACCOUNT_STATUS.FROZEN]: '已冻结',
}

/**
 * 通用启停状态(适用于 expense_categories / service_numbers / channels /
 * commission rules / sales_groups / coaches / products / deferred_revenue 等)
 *
 * 真值依据:多张表都用 'active' / 'inactive' 双值,DB 里这些列都是 text,
 * 已经和前端 60+ 处 `status === 'active'` 一致(2026-04-16 全站 grep + migration 复核)。
 *
 * ⚠️ 不要把这个常量套到 assets(用 'in_use')和 orders(用 'completed/paid/cancelled')上。
 */
export const GENERIC_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
}

export const GENERIC_STATUS_LABEL = {
  [GENERIC_STATUS.ACTIVE]: '启用',
  [GENERIC_STATUS.INACTIVE]: '停用',
}

/**
 * 订单状态(public.orders.status)
 * 真值依据:supabase/migrations/20260415_wave1_fixes.sql:173/267-299
 *   订单实际值:completed / partially_refunded / paid / cancelled / refunded
 */
export const ORDER_STATUS = {
  COMPLETED: 'completed',
  PAID: 'paid',
  PARTIALLY_REFUNDED: 'partially_refunded',
  REFUNDED: 'refunded',
  CANCELLED: 'cancelled',
  PENDING: 'pending',
}

export const ORDER_STATUS_LABEL = {
  [ORDER_STATUS.COMPLETED]: '已完成',
  [ORDER_STATUS.PAID]: '已付款',
  [ORDER_STATUS.PARTIALLY_REFUNDED]: '部分退款',
  [ORDER_STATUS.REFUNDED]: '已退款',
  [ORDER_STATUS.CANCELLED]: '已取消',
  [ORDER_STATUS.PENDING]: '待处理',
}
