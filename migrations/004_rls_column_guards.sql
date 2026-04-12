-- ============================================================================
-- 004_rls_column_guards.sql
-- 修复 RLS 的列级权限漏洞
--
-- 背景：
--   现有策略 "Finance update orders" 允许 creator_id = auth.uid()，
--   意味着销售创建订单后，可以通过直接调用 REST API 修改任意字段，
--   包括 status（把 pending 改成 completed）。前端的
--   `if (!['admin','finance']) delete updates.status` 是可被绕过的。
--
--   PG 的 RLS 是行级不是列级，无法直接"允许更新某些列"。
--   所以这里用 BEFORE UPDATE 触发器来做列级守卫。
--
-- 审阅提示：
--   1. 在 Supabase 控制台 SQL Editor 里逐段执行
--   2. 执行前请备份或先在 staging 环境试跑
--   3. 如果你们的角色名和这里不一致，调整 role IN (...) 列表
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. orders 表：非 finance/admin 不得修改 status 字段
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION guard_orders_update()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
BEGIN
  -- 仅在 status 真的发生变化时才校验，减少不必要开销
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
    IF v_role NOT IN ('finance', 'admin') THEN
      RAISE EXCEPTION '权限不足：仅 finance/admin 可修改订单状态 (当前角色: %)', COALESCE(v_role, 'unknown')
        USING ERRCODE = '42501';  -- insufficient_privilege
    END IF;
  END IF;

  -- 金额字段同理：非 finance/admin 不能改已提交订单的金额
  IF NEW.amount IS DISTINCT FROM OLD.amount THEN
    SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
    IF v_role NOT IN ('finance', 'admin') THEN
      RAISE EXCEPTION '权限不足：仅 finance/admin 可修改订单金额'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_guard_orders_update ON orders;
CREATE TRIGGER trg_guard_orders_update
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION guard_orders_update();

-- ----------------------------------------------------------------------------
-- 2. expenses 表：状态流转校验
--    - pending → approved/rejected 只能由 finance/admin/manager 做
--    - approved → paid 同上
--    - 其它流转一律禁止（防止 sales 自己把状态从 rejected 改回 pending）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION guard_expenses_update()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
    IF v_role NOT IN ('finance', 'admin', 'manager') THEN
      RAISE EXCEPTION '权限不足：仅 finance/admin/manager 可修改支出状态'
        USING ERRCODE = '42501';
    END IF;

    -- 状态流转白名单
    IF NOT (
      (OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected', 'paid'))
      OR (OLD.status = 'approved' AND NEW.status = 'paid')
      OR (OLD.status = 'rejected' AND NEW.status = 'pending')  -- 允许重新提交
    ) THEN
      RAISE EXCEPTION '非法的状态流转：% → %', OLD.status, NEW.status
        USING ERRCODE = '22023';
    END IF;
  END IF;

  -- 金额字段一旦 approved 以上就不能再改
  IF NEW.amount IS DISTINCT FROM OLD.amount AND OLD.status IN ('approved', 'paid') THEN
    RAISE EXCEPTION '已审批/已付款的支出金额不可修改'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_guard_expenses_update ON expenses;
CREATE TRIGGER trg_guard_expenses_update
  BEFORE UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION guard_expenses_update();

-- ----------------------------------------------------------------------------
-- 3. accounts 表：余额字段只允许 RPC 里写（防止绕过 increment_balance）
--    思路：BEFORE UPDATE 里检查 balance 是否变化；如果变化但调用方不是
--    SECURITY DEFINER 上下文（即没经过 increment_balance），就拒绝。
--
--    Supabase 里判断"是否从 RPC 里来"不太容易，折中方案：直接限制
--    只有 finance/admin 能通过普通 UPDATE 改 balance；其他人要改余额
--    必须走 RPC（RPC 用 SECURITY DEFINER，可以绕过 RLS）。
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION guard_accounts_update()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
BEGIN
  IF NEW.balance IS DISTINCT FROM OLD.balance THEN
    SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
    IF v_role NOT IN ('finance', 'admin') THEN
      RAISE EXCEPTION '权限不足：账户余额只能通过 RPC 修改'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_guard_accounts_update ON accounts;
CREATE TRIGGER trg_guard_accounts_update
  BEFORE UPDATE ON accounts
  FOR EACH ROW
  EXECUTE FUNCTION guard_accounts_update();

-- ============================================================================
-- 完成后验证：
--
-- 1. 用一个 sales 账号登录，尝试 PATCH /rest/v1/orders?id=xxx
--    body: {"status":"completed"}
--    期望：返回 42501 权限错误
--
-- 2. 用 finance 账号做同样操作 → 期望成功
--
-- 3. 用 sales 账号直接 UPDATE accounts SET balance = 99999
--    期望：返回权限错误
-- ============================================================================
