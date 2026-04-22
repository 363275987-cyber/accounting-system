-- ═══════════════════════════════════════════════════════════════
-- 对齐电商日统计视图口径
-- 目标：
-- 1) 统一 sales_amount 使用 payment_amount 优先、amount 兜底
-- 2) 统一 refund_amount 只统计 completed 退款
-- 3) 补出 effective_count，减少页面端自行拼装
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS settlement_days INT DEFAULT 15;

CREATE OR REPLACE VIEW public.v_ecommerce_daily AS
WITH refund_totals AS (
  SELECT
    order_id,
    COALESCE(SUM(refund_amount), 0)::numeric AS refund_amount
  FROM refunds
  WHERE deleted_at IS NULL
    AND status = 'completed'
  GROUP BY order_id
)
SELECT
  a.id AS account_id,
  a.short_name AS store_name,
  a.platform,
  a.ecommerce_platform,
  a.settlement_days,
  DATE(COALESCE(o.order_time, o.created_at)) AS order_date,
  COUNT(o.id) FILTER (WHERE o.status IN ('completed', 'partially_refunded'))::int AS order_count,
  COUNT(o.id) FILTER (
    WHERE o.status IN ('completed', 'partially_refunded')
      AND COALESCE(rt.refund_amount, 0) < COALESCE(o.payment_amount, o.amount, 0)
  )::int AS effective_count,
  COALESCE(SUM(COALESCE(o.payment_amount, o.amount, 0)) FILTER (
    WHERE o.status IN ('completed', 'partially_refunded')
  ), 0)::numeric AS sales_amount,
  COALESCE(SUM(COALESCE(rt.refund_amount, 0)) FILTER (
    WHERE o.status IN ('completed', 'partially_refunded')
  ), 0)::numeric AS refund_amount,
  COALESCE(
    SUM(COALESCE(o.payment_amount, o.amount, 0)) FILTER (
      WHERE o.status IN ('completed', 'partially_refunded')
    ) -
    SUM(COALESCE(rt.refund_amount, 0)) FILTER (
      WHERE o.status IN ('completed', 'partially_refunded')
    ),
    0
  )::numeric AS net_income
FROM accounts a
LEFT JOIN orders o
  ON o.account_id = a.id
  AND o.deleted_at IS NULL
  AND o.platform_type IS NOT NULL
LEFT JOIN refund_totals rt
  ON rt.order_id = o.id
WHERE a.ecommerce_platform IS NOT NULL
  AND a.status = 'active'
GROUP BY
  a.id,
  a.short_name,
  a.platform,
  a.ecommerce_platform,
  a.settlement_days,
  DATE(COALESCE(o.order_time, o.created_at));
