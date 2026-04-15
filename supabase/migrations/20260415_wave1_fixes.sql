-- ============================================================
-- Wave 1 修复 · 2026-04-15 (v2 — 基于云端真实 schema 重写)
-- 包含：BUG-8 / BUG-14 / BUG-15 / BUG-16
-- 废弃：BUG-10（经实测 dividends.account_id 已存在，无需迁移）
--
-- 本文件设计为 **幂等**，可在 Supabase SQL Editor 多次执行。
-- 请在 Supabase 控制台 → SQL Editor 中整份粘贴执行。
--
-- ⚠️ 重要：本文件基于 2026-04-15 通过 exec_sql RPC 实测的
--    云端表结构编写，与 repo 内 003_full_schema.sql 不完全一致。
--    原因：历史上云端 schema 经历过多次删列/改列，迁移未全部回写。
--
-- 实测得到的关键事实：
--   · dividends                 已有 account_id 列（旧 BUG-10 误报，放弃）
--   · customers                 无 status / total_orders / first_order_at / last_order_at
--                                 真实列：order_count, first_order_date, last_order_date
--                                 phone 有普通索引但 **没有** unique 约束
--   · shareholder_loans         无 receive_account_id，无 account_id
--                                 有 repaid_principal / remaining_principal 直接列
--   · loan_repayments           **表完全不存在**，前端 store 会写入报错
--   · balance_snapshots         仅 7 列 (id/account_id/period/opening/closing/status/created_at)
--                                 无 total_income/total_expense/total_refund/transfer_in/out/
--                                    transfer_fee/admin_adjustment/settlement_date/updated_at
--   · settle_monthly_balances   已存在但引用多个不存在的列，运行即报错
--                                 并引用 refunds.completed_at（真实列为 paid_at）
--   · generate_monthly_snapshots 已存在，内部调用上面那个坏函数，故前端按钮报错
--   · sync_customers_from_orders 已存在但 INSERT 列表全部是旧列名，运行即报错
-- ============================================================



-- ============================================================
-- Part 1 · loan_repayments 表 （原本缺失，前端 store 代码假设它存在）
-- ------------------------------------------------------------
-- src/stores/shareholderLoans.js 的 fetchRepayments / createRepayment 会
-- .from('loan_repayments') 读写这张表。线上没有这张表，导致所有还款操作
-- 在 PostgREST 层就 404。必须先建表，BUG-8 的视图才有意义。
-- ============================================================

CREATE TABLE IF NOT EXISTS loan_repayments (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id           uuid        NOT NULL REFERENCES shareholder_loans(id) ON DELETE CASCADE,
  repayment_amount  numeric(14,2) NOT NULL DEFAULT 0,
  principal_amount  numeric(14,2) NOT NULL DEFAULT 0,
  interest_amount   numeric(14,2) NOT NULL DEFAULT 0,
  repayment_date    date        NOT NULL DEFAULT CURRENT_DATE,
  account_id        uuid        REFERENCES accounts(id),
  note              text,
  created_by        uuid,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW(),
  deleted_at        timestamptz
);

CREATE INDEX IF NOT EXISTS idx_loan_repayments_loan_id ON loan_repayments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_repayments_date    ON loan_repayments(repayment_date);

COMMENT ON TABLE loan_repayments IS
  '股东垫资还款明细。前端 store 写入此表，BUG-8 视图聚合此表';



-- ============================================================
-- Part 2 · BUG-16  shareholder_loans.receive_account_id 列
-- ------------------------------------------------------------
-- 前端 Wave 2-B 已添加"公司收款账户"必填字段，但列不存在 → insert 报错。
-- ============================================================

ALTER TABLE shareholder_loans
  ADD COLUMN IF NOT EXISTS receive_account_id uuid REFERENCES accounts(id);

COMMENT ON COLUMN shareholder_loans.receive_account_id IS
  '公司收款账户 —— 垫资场景必填（资金从股东流入公司该账户），BUG-16 修复';

CREATE INDEX IF NOT EXISTS idx_shareholder_loans_receive_account
  ON shareholder_loans(receive_account_id);



-- ============================================================
-- Part 3 · BUG-8  shareholder_loan_summary 视图
-- ------------------------------------------------------------
-- src/stores/shareholderLoans.js fetchLoans 走 .from('shareholder_loan_summary')。
-- 视图基于 shareholder_loans 原生的 repaid_principal / remaining_principal 列，
-- 再从 loan_repayments 聚合还款利息总额 + 最后还款日期。
-- sl.* 动态展开，自动带出 receive_account_id。
-- ============================================================

DROP VIEW IF EXISTS shareholder_loan_summary;

CREATE VIEW shareholder_loan_summary AS
SELECT
  sl.*,
  COALESCE(
    (SELECT SUM(lr.interest_amount)
       FROM loan_repayments lr
      WHERE lr.loan_id = sl.id AND lr.deleted_at IS NULL),
    0
  ) AS repaid_interest,
  COALESCE(
    (SELECT SUM(lr.repayment_amount)
       FROM loan_repayments lr
      WHERE lr.loan_id = sl.id AND lr.deleted_at IS NULL),
    0
  ) AS total_repaid,
  (SELECT MAX(lr.repayment_date)
     FROM loan_repayments lr
    WHERE lr.loan_id = sl.id AND lr.deleted_at IS NULL
  ) AS last_repayment_date
FROM shareholder_loans sl
WHERE sl.deleted_at IS NULL;

COMMENT ON VIEW shareholder_loan_summary IS
  '股东垫资汇总视图（BUG-8 修复）。repaid_principal / remaining_principal 直接来自表';



-- ============================================================
-- Part 4 · BUG-15  customers 唯一约束 + sync_customers_from_orders 重写
-- ------------------------------------------------------------
-- 4.1 建立 phone 部分唯一索引，供 ON CONFLICT 使用
-- 4.2 重写 sync_customers_from_orders 使用真实列名：
--       order_count / first_order_date / last_order_date
--       不再引用 status / total_orders / first_order_at / last_order_at
-- ============================================================

-- 4.1  唯一索引（仅活动客户）
CREATE UNIQUE INDEX IF NOT EXISTS uniq_customers_phone_active
  ON customers(phone)
  WHERE deleted_at IS NULL;

-- 4.2  重写同步函数
CREATE OR REPLACE FUNCTION sync_customers_from_orders()
RETURNS TABLE(synced_count integer)
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_count integer;
BEGIN
  INSERT INTO customers (
    id, phone, name, address,
    order_count, total_amount,
    first_order_date, last_order_date,
    created_at, updated_at
  )
  SELECT
    gen_random_uuid(),
    phone,
    name,
    address,
    order_count,
    total_amount,
    first_order_date,
    last_order_date,
    NOW(),
    NOW()
  FROM (
    SELECT
      TRIM(customer_phone) AS phone,
      (ARRAY_AGG(customer_name    ORDER BY created_at DESC)
         FILTER (WHERE customer_name    IS NOT NULL))[1] AS name,
      (ARRAY_AGG(customer_address ORDER BY created_at DESC)
         FILTER (WHERE customer_address IS NOT NULL))[1] AS address,
      COUNT(*)                             AS order_count,
      COALESCE(SUM(amount), 0)             AS total_amount,
      MIN(created_at)                      AS first_order_date,
      MAX(created_at)                      AS last_order_date
    FROM orders
    WHERE deleted_at IS NULL
      AND customer_phone IS NOT NULL
      AND TRIM(customer_phone) ~ '^[0-9]{11}$'
      AND status IN ('completed', 'partially_refunded', 'paid')
    GROUP BY TRIM(customer_phone)
  ) agg
  ON CONFLICT (phone) WHERE deleted_at IS NULL DO UPDATE SET
    name             = COALESCE(EXCLUDED.name,    customers.name),
    address          = COALESCE(EXCLUDED.address, customers.address),
    order_count      = EXCLUDED.order_count,
    total_amount     = EXCLUDED.total_amount,
    first_order_date = LEAST(customers.first_order_date, EXCLUDED.first_order_date),
    last_order_date  = GREATEST(customers.last_order_date, EXCLUDED.last_order_date),
    updated_at       = NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  synced_count := v_count;
  RETURN NEXT;
END;
$func$;

GRANT EXECUTE ON FUNCTION sync_customers_from_orders() TO authenticated;
GRANT EXECUTE ON FUNCTION sync_customers_from_orders() TO anon;

COMMENT ON FUNCTION sync_customers_from_orders() IS
  '从 orders 表聚合客户数据同步到 customers 表（BUG-15 修复）';



-- ============================================================
-- Part 5 · BUG-14  settle_monthly_balances 重写 + generate_monthly_snapshots
-- ------------------------------------------------------------
-- 原函数引用大量不存在的列：
--   balance_snapshots 只有 7 列 (id/account_id/period/opening/closing/status/created_at)
--   原函数却 INSERT/UPDATE 了 total_income, total_expense, total_refund,
--   transfer_in, transfer_out, transfer_fee, admin_adjustment, settlement_date, updated_at
--   refunds.completed_at 也不存在（真实列为 paid_at）
--
-- 重写方案：
--   · 保留最小字段（opening_balance, closing_balance, status）
--   · 内部仍然计算 income/expense/refund/transfer/fee，但只用于算 closing
--   · refunds.completed_at → paid_at
--   · 使用 ON CONFLICT (account_id, period) 合并
-- ============================================================

-- 先给 balance_snapshots 的 (account_id, period) 加唯一约束（用于 ON CONFLICT）
CREATE UNIQUE INDEX IF NOT EXISTS uniq_balance_snapshots_account_period
  ON balance_snapshots(account_id, period);

CREATE OR REPLACE FUNCTION settle_monthly_balances(settlement_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_period       text;
  v_start_date   date;
  v_end_date     date;
  v_prev_period  text;
  v_results      jsonb := '[]'::jsonb;
  v_acc_id       uuid;
  v_acc_code     text;
  v_prev_closing numeric(14,2);
  v_opening      numeric(14,2);
  v_income       numeric(14,2);
  v_expense      numeric(14,2);
  v_refund       numeric(14,2);
  v_transfer_in  numeric(14,2);
  v_transfer_out numeric(14,2);
  v_fee          numeric(14,2);
  v_closing      numeric(14,2);
BEGIN
  v_period     := to_char(settlement_date, 'YYYY-MM');
  v_start_date := (v_period || '-01')::date;
  v_end_date   := v_start_date + interval '1 month';
  v_prev_period := to_char(v_start_date - interval '1 month', 'YYYY-MM');

  FOR v_acc_id, v_acc_code IN
    SELECT id, code FROM accounts WHERE status = 'active' ORDER BY code
  LOOP
    -- 上月期末作为本月期初，没有则取账户初始余额
    SELECT closing_balance INTO v_prev_closing
      FROM balance_snapshots
     WHERE account_id = v_acc_id AND period = v_prev_period
     LIMIT 1;

    IF v_prev_closing IS NOT NULL THEN
      v_opening := v_prev_closing;
    ELSE
      SELECT COALESCE(opening_balance, 0) INTO v_opening
        FROM accounts WHERE id = v_acc_id;
    END IF;

    -- 收入（已完成订单）
    SELECT COALESCE(SUM(amount), 0) INTO v_income
      FROM orders
     WHERE account_id = v_acc_id
       AND status IN ('completed', 'partially_refunded')
       AND deleted_at IS NULL
       AND created_at >= v_start_date AND created_at < v_end_date;

    -- 支出（已支付费用）
    SELECT COALESCE(SUM(amount), 0) INTO v_expense
      FROM expenses
     WHERE account_id = v_acc_id
       AND status = 'paid'
       AND paid_at >= v_start_date AND paid_at < v_end_date;

    -- 退款（refunds.paid_at，不是 completed_at）
    SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund
      FROM refunds
     WHERE refund_from_account_id = v_acc_id
       AND status = 'completed'
       AND paid_at IS NOT NULL
       AND paid_at >= v_start_date AND paid_at < v_end_date;

    -- 转账流入
    SELECT COALESCE(SUM(amount), 0) INTO v_transfer_in
      FROM account_transfers
     WHERE to_account_id = v_acc_id
       AND status = 'completed'
       AND deleted_at IS NULL
       AND created_at >= v_start_date AND created_at < v_end_date;

    -- 转账流出 + 手续费
    SELECT COALESCE(SUM(amount), 0), COALESCE(SUM(fee), 0)
      INTO v_transfer_out, v_fee
      FROM account_transfers
     WHERE from_account_id = v_acc_id
       AND status = 'completed'
       AND deleted_at IS NULL
       AND created_at >= v_start_date AND created_at < v_end_date;

    v_closing := v_opening + v_income - v_expense - v_refund
                 + v_transfer_in - v_transfer_out - v_fee;

    -- UPSERT balance_snapshots（只写存在的列）
    INSERT INTO balance_snapshots (
      account_id, period, opening_balance, closing_balance, status, created_at
    ) VALUES (
      v_acc_id, v_period, v_opening, v_closing, 'draft', NOW()
    )
    ON CONFLICT (account_id, period) DO UPDATE SET
      opening_balance = EXCLUDED.opening_balance,
      closing_balance = EXCLUDED.closing_balance,
      status          = 'draft';

    v_results := v_results || jsonb_build_object(
      'account_id',      v_acc_id,
      'account_code',    v_acc_code,
      'opening_balance', v_opening,
      'income',          v_income,
      'expense',         v_expense,
      'refund',          v_refund,
      'transfer_in',     v_transfer_in,
      'transfer_out',    v_transfer_out,
      'fee',             v_fee,
      'closing_balance', v_closing
    );
  END LOOP;

  RETURN v_results;
END;
$func$;

-- 包装函数：对"当前自然月"生成所有账户快照
-- 旧函数返回 void，与新版 jsonb 不兼容，必须先 DROP
DROP FUNCTION IF EXISTS generate_monthly_snapshots();

CREATE OR REPLACE FUNCTION generate_monthly_snapshots()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_settlement_date date;
BEGIN
  v_settlement_date := (to_char(NOW(), 'YYYY-MM') || '-01')::date
                       + interval '1 month' - interval '1 day';
  RETURN settle_monthly_balances(v_settlement_date);
END;
$func$;

GRANT EXECUTE ON FUNCTION settle_monthly_balances(date)   TO authenticated, anon;
GRANT EXECUTE ON FUNCTION generate_monthly_snapshots()    TO authenticated, anon;

COMMENT ON FUNCTION settle_monthly_balances(date) IS
  '按指定日期所在月结算所有活跃账户余额（BUG-14 修复 · 针对真实 schema 重写）';
COMMENT ON FUNCTION generate_monthly_snapshots()  IS
  '一键生成本月所有账户余额快照（BUG-14 修复）';



-- ============================================================
-- 自检查询（执行完后可手动粘贴到 SQL Editor 验证）
-- ------------------------------------------------------------
-- -- Part 1 loan_repayments 表
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'loan_repayments' ORDER BY ordinal_position;
--
-- -- Part 2 shareholder_loans.receive_account_id
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'shareholder_loans' AND column_name = 'receive_account_id';
--
-- -- Part 3 视图
-- SELECT COUNT(*) FROM shareholder_loan_summary;
--
-- -- Part 4 同步函数
-- SELECT * FROM sync_customers_from_orders();   -- 应当返回 (synced_count)
-- SELECT COUNT(*) FROM customers;                -- 应当 > 0
--
-- -- Part 5 结算函数
-- SELECT generate_monthly_snapshots();           -- 应当返回 JSON 数组
-- SELECT * FROM balance_snapshots
--  ORDER BY created_at DESC LIMIT 5;
-- ============================================================
