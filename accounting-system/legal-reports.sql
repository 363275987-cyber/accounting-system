-- ============================================================
-- 法定财务报表 RPC 函数（四表一注）
-- 创建时间: 2026-03-29
-- 公司: 台球公司（任凯智60% / 王孟南40%）
-- ============================================================

-- 1. 资产负债表
CREATE OR REPLACE FUNCTION balance_sheet_report(p_as_of date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cash numeric := 0;
  v_receivables numeric := 0;
  v_total_assets numeric := 0;
  v_payables numeric := 0;
  v_shareholder_loans numeric := 0;
  v_total_liabilities numeric := 0;
  v_retained_earnings numeric := 0;
  v_total_equity numeric := 0;
  v_cash_detail jsonb := '[]'::jsonb;
  v_receivables_detail jsonb := '[]'::jsonb;
  v_payables_detail jsonb := '[]'::jsonb;
  v_loans_detail jsonb := '[]'::jsonb;
BEGIN
  -- 资产：现金（各活跃账户余额合计）
  SELECT jsonb_agg(jsonb_build_object(
    'account_name', COALESCE(a.account_name, a.code),
    'platform', a.platform,
    'balance', a.balance
  )) INTO v_cash_detail
  FROM accounts a
  WHERE a.status = 'active';

  SELECT COALESCE(SUM(balance), 0) INTO v_cash
  FROM accounts
  WHERE status = 'active';

  -- 资产：应收账款（pending订单amount，排除已删除）
  SELECT COALESCE(SUM(amount), 0), jsonb_agg(jsonb_build_object(
    'order_no', o.order_no,
    'customer_name', o.customer_name,
    'amount', o.amount,
    'created_at', o.created_at
  )) INTO v_receivables, v_receivables_detail
  FROM orders o
  WHERE o.status = 'pending' AND o.deleted_at IS NULL;

  v_total_assets := v_cash + v_receivables;

  -- 负债：应付账款（pending + approved支出，排除已删除）
  SELECT COALESCE(SUM(amount), 0), jsonb_agg(jsonb_build_object(
    'category', e.category,
    'payee', e.payee,
    'amount', e.amount,
    'status', e.status,
    'created_at', e.created_at
  )) INTO v_payables, v_payables_detail
  FROM expenses e
  WHERE e.status IN ('pending', 'approved') AND e.deleted_at IS NULL;

  -- 负债：股东垫资（未还本金）
  SELECT COALESCE(SUM(s.remaining_principal), 0), jsonb_agg(jsonb_build_object(
    'shareholder_name', s.shareholder_name,
    'loan_amount', s.loan_amount,
    'repaid_principal', s.repaid_principal,
    'remaining_principal', s.remaining_principal,
    'annual_interest_rate', s.annual_interest_rate
  )) INTO v_shareholder_loans, v_loans_detail
  FROM shareholder_loan_summary s
  WHERE s.status = 'active';

  v_total_liabilities := v_payables + v_shareholder_loans;

  -- 所有者权益：利润累计 = completed订单amount - paid支出amount
  SELECT COALESCE(SUM(o.amount), 0) INTO v_retained_earnings
  FROM orders o
  WHERE o.status = 'completed' AND o.deleted_at IS NULL;

  SELECT v_retained_earnings - COALESCE(SUM(e.amount), 0) INTO v_retained_earnings
  FROM expenses e
  WHERE e.status = 'paid' AND e.deleted_at IS NULL;

  -- 扣除已完成的退款
  SELECT v_retained_earnings - COALESCE(SUM(r.refund_amount), 0) INTO v_retained_earnings
  FROM refunds r
  WHERE r.status = 'completed' AND r.deleted_at IS NULL;

  v_total_equity := v_retained_earnings;

  RETURN json_build_object(
    'as_of', p_as_of,
    'assets', json_build_object(
      'cash', v_cash,
      'cash_detail', v_cash_detail,
      'receivables', v_receivables,
      'receivables_detail', v_receivables_detail,
      'total', v_total_assets
    ),
    'liabilities', json_build_object(
      'payables', v_payables,
      'payables_detail', v_payables_detail,
      'shareholder_loans', v_shareholder_loans,
      'loans_detail', v_loans_detail,
      'total', v_total_liabilities
    ),
    'equity', json_build_object(
      'retained_earnings', v_retained_earnings,
      'total', v_total_equity
    ),
    'check', json_build_object(
      'assets', v_total_assets,
      'liabilities_plus_equity', v_total_liabilities + v_total_equity,
      'balanced', (v_total_assets = v_total_liabilities + v_total_equity)
    )
  );
END;
$$;

-- 2. 利润表
CREATE OR REPLACE FUNCTION income_statement_report(p_start date, p_end date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_revenue numeric := 0;
  v_cost numeric := 0;
  v_gross_profit numeric := 0;
  v_expenses_total numeric := 0;
  v_refunds_total numeric := 0;
  v_net_profit numeric := 0;
  v_revenue_detail jsonb := '[]'::jsonb;
  v_expenses_detail jsonb := '[]'::jsonb;
  v_refunds_detail jsonb := '[]'::jsonb;
BEGIN
  -- 营业收入：期间内completed订单amount合计
  SELECT COALESCE(SUM(amount), 0), jsonb_agg(jsonb_build_object(
    'order_no', o.order_no,
    'customer_name', o.customer_name,
    'product_category', o.product_category,
    'amount', o.amount,
    'completed_at', o.updated_at
  )) INTO v_revenue, v_revenue_detail
  FROM orders o
  WHERE o.status = 'completed'
    AND o.deleted_at IS NULL
    AND o.updated_at >= p_start
    AND o.updated_at < (p_end + interval '1 day');

  -- 营业成本：期间内order_items的成本合计（unit_cost * quantity）
  SELECT COALESCE(SUM(oi.unit_cost * oi.quantity), 0) INTO v_cost
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.status = 'completed'
    AND o.deleted_at IS NULL
    AND o.updated_at >= p_start
    AND o.updated_at < (p_end + interval '1 day');

  v_gross_profit := v_revenue - v_cost;

  -- 营业费用：期间内paid支出合计（按category分组）
  SELECT COALESCE(SUM(sub.cat_total), 0) INTO v_expenses_total
  FROM (
    SELECT e.category, SUM(e.amount) AS cat_total
    FROM expenses e
    WHERE e.status = 'paid'
      AND e.deleted_at IS NULL
      AND e.paid_at >= p_start
      AND e.paid_at < (p_end + interval '1 day')
    GROUP BY e.category
    ORDER BY cat_total DESC
  ) sub;

  SELECT jsonb_agg(jsonb_build_object(
    'category', sub.category,
    'amount', sub.cat_total
  )) INTO v_expenses_detail
  FROM (
    SELECT e.category, SUM(e.amount) AS cat_total
    FROM expenses e
    WHERE e.status = 'paid'
      AND e.deleted_at IS NULL
      AND e.paid_at >= p_start
      AND e.paid_at < (p_end + interval '1 day')
    GROUP BY e.category
    ORDER BY cat_total DESC
  ) sub;

  -- 退款金额
  SELECT COALESCE(SUM(r.refund_amount), 0), jsonb_agg(jsonb_build_object(
    'refund_no', r.refund_no,
    'order_id', r.order_id,
    'refund_amount', r.refund_amount,
    'completed_at', r.completed_at
  )) INTO v_refunds_total, v_refunds_detail
  FROM refunds r
  WHERE r.status = 'completed'
    AND r.deleted_at IS NULL
    AND r.completed_at >= p_start
    AND r.completed_at < (p_end + interval '1 day');

  v_net_profit := v_gross_profit - v_expenses_total - v_refunds_total;

  RETURN json_build_object(
    'period_start', p_start,
    'period_end', p_end,
    'revenue', v_revenue,
    'revenue_detail', v_revenue_detail,
    'cost', v_cost,
    'gross_profit', v_gross_profit,
    'expenses', v_expenses_total,
    'expenses_detail', v_expenses_detail,
    'refunds', v_refunds_total,
    'refunds_detail', v_refunds_detail,
    'net_profit', v_net_profit
  );
END;
$$;

-- 3. 现金流量表
CREATE OR REPLACE FUNCTION cash_flow_report_formal(p_start date, p_end date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_cash_in numeric := 0;
  v_expense_cash_out numeric := 0;
  v_refund_cash_out numeric := 0;
  v_operating_net numeric := 0;
  v_invest_cash_in numeric := 0;
  v_invest_cash_out numeric := 0;
  v_investing_net numeric := 0;
  v_loan_new numeric := 0;
  v_loan_repay numeric := 0;
  v_financing_net numeric := 0;
  v_net_change numeric := 0;
  v_operating_detail jsonb := '[]'::jsonb;
  v_investing_detail jsonb := '[]'::jsonb;
  v_financing_detail jsonb := '[]'::jsonb;
BEGIN
  -- 经营活动
  -- 订单收款：completed订单
  SELECT COALESCE(SUM(amount), 0) INTO v_order_cash_in
  FROM orders o
  WHERE o.status = 'completed'
    AND o.deleted_at IS NULL
    AND o.updated_at >= p_start
    AND o.updated_at < (p_end + interval '1 day');

  -- 支出付款：paid支出
  SELECT COALESCE(SUM(amount), 0) INTO v_expense_cash_out
  FROM expenses e
  WHERE e.status = 'paid'
    AND e.deleted_at IS NULL
    AND e.paid_at >= p_start
    AND e.paid_at < (p_end + interval '1 day');

  -- 退款
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_refund_cash_out
  FROM refunds r
  WHERE r.status = 'completed'
    AND r.deleted_at IS NULL
    AND r.completed_at >= p_start
    AND r.completed_at < (p_end + interval '1 day');

  v_operating_net := v_order_cash_in - v_expense_cash_out - v_refund_cash_out;

  v_operating_detail := jsonb_build_array(
    jsonb_build_object('item', '订单收款', 'amount', v_order_cash_in),
    jsonb_build_object('item', '支出付款', 'amount', -v_expense_cash_out),
    jsonb_build_object('item', '退款支出', 'amount', -v_refund_cash_out)
  );

  -- 投资活动：设备采购（支出中category含'设备'或'采购'）
  SELECT COALESCE(SUM(amount), 0) INTO v_invest_cash_out
  FROM expenses e
  WHERE e.status = 'paid'
    AND e.deleted_at IS NULL
    AND e.paid_at >= p_start
    AND e.paid_at < (p_end + interval '1 day')
    AND (e.category ILIKE '%设备%' OR e.category ILIKE '%采购%' OR e.category ILIKE '%固定资产%');

  v_investing_net := -v_invest_cash_out;

  v_investing_detail := jsonb_build_array(
    jsonb_build_object('item', '设备/固定资产采购', 'amount', -v_invest_cash_out)
  );

  -- 筹资活动：股东垫资新增、还款
  -- 新增垫资（期间内新建的shareholder_loans）
  SELECT COALESCE(SUM(loan_amount), 0) INTO v_loan_new
  FROM shareholder_loans sl
  WHERE sl.status = 'active'
    AND sl.created_at >= p_start
    AND sl.created_at < (p_end + interval '1 day');

  -- 垫资还款（期间内的loan_repayments）
  SELECT COALESCE(SUM(principal_amount), 0) INTO v_loan_repay
  FROM loan_repayments lr
  WHERE lr.repayment_date >= p_start
    AND lr.repayment_date < (p_end + interval '1 day');

  v_financing_net := v_loan_new - v_loan_repay;

  v_financing_detail := jsonb_build_array(
    jsonb_build_object('item', '股东垫资新增', 'amount', v_loan_new),
    jsonb_build_object('item', '股东垫资还款', 'amount', -v_loan_repay)
  );

  v_net_change := v_operating_net + v_investing_net + v_financing_net;

  RETURN json_build_object(
    'period_start', p_start,
    'period_end', p_end,
    'operating', json_build_object(
      'cash_in_orders', v_order_cash_in,
      'cash_out_expenses', v_expense_cash_out,
      'cash_out_refunds', v_refund_cash_out,
      'net', v_operating_net,
      'detail', v_operating_detail
    ),
    'investing', json_build_object(
      'equipment_purchase', v_invest_cash_out,
      'net', v_investing_net,
      'detail', v_investing_detail
    ),
    'financing', json_build_object(
      'loan_new', v_loan_new,
      'loan_repay', v_loan_repay,
      'net', v_financing_net,
      'detail', v_financing_detail
    ),
    'net_change', v_net_change
  );
END;
$$;

-- 4. 所有者权益变动表
CREATE OR REPLACE FUNCTION equity_statement_report(p_start date, p_end date)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_beginning_equity numeric := 0;
  v_period_profit numeric := 0;
  v_period_refunds numeric := 0;
  v_net_income numeric := 0;
  v_loan_changes numeric := 0;
  v_ending_equity numeric := 0;
  v_renzhaizhi_share numeric := 0;
  v_wangmengnan_share numeric := 0;
  v_loan_detail jsonb := '[]'::jsonb;
BEGIN
  -- 期初所有者权益：截至p_start之前的利润累计
  -- completed订单 - paid支出 - completed退款（截至期初）
  SELECT COALESCE(SUM(o.amount), 0) INTO v_beginning_equity
  FROM orders o
  WHERE o.status = 'completed'
    AND o.deleted_at IS NULL
    AND o.updated_at < p_start;

  SELECT v_beginning_equity - COALESCE(SUM(e.amount), 0) INTO v_beginning_equity
  FROM expenses e
  WHERE e.status = 'paid'
    AND e.deleted_at IS NULL
    AND e.paid_at < p_start;

  SELECT v_beginning_equity - COALESCE(SUM(r.refund_amount), 0) INTO v_beginning_equity
  FROM refunds r
  WHERE r.status = 'completed'
    AND r.deleted_at IS NULL
    AND r.completed_at < p_start;

  -- 本期净利润
  SELECT COALESCE(SUM(o.amount), 0) INTO v_period_profit
  FROM orders o
  WHERE o.status = 'completed'
    AND o.deleted_at IS NULL
    AND o.updated_at >= p_start
    AND o.updated_at < (p_end + interval '1 day');

  SELECT v_period_profit - COALESCE(SUM(e.amount), 0) INTO v_period_profit
  FROM expenses e
  WHERE e.status = 'paid'
    AND e.deleted_at IS NULL
    AND e.paid_at >= p_start
    AND e.paid_at < (p_end + interval '1 day');

  -- 扣除本期退款
  SELECT COALESCE(SUM(refund_amount), 0) INTO v_period_refunds
  FROM refunds r
  WHERE r.status = 'completed'
    AND r.deleted_at IS NULL
    AND r.completed_at >= p_start
    AND r.completed_at < (p_end + interval '1 day');

  v_net_income := v_period_profit - v_period_refunds;

  -- 本期垫资变动（新增垫资 - 还款本金）
  SELECT COALESCE(SUM(loan_amount), 0) INTO v_loan_changes
  FROM shareholder_loans sl
  WHERE sl.status = 'active'
    AND sl.created_at >= p_start
    AND sl.created_at < (p_end + interval '1 day');

  SELECT v_loan_changes - COALESCE(SUM(lr.principal_amount), 0) INTO v_loan_changes
  FROM loan_repayments lr
  WHERE lr.repayment_date >= p_start
    AND lr.repayment_date < (p_end + interval '1 day');

  -- 垫资明细
  SELECT jsonb_agg(jsonb_build_object(
    'shareholder_name', sl.shareholder_name,
    'loan_amount', sl.loan_amount,
    'created_at', sl.created_at
  )) INTO v_loan_detail
  FROM shareholder_loans sl
  WHERE sl.status = 'active'
    AND sl.created_at >= p_start
    AND sl.created_at < (p_end + interval '1 day');

  -- 期末权益 = 期初 + 本期净利润 + 本期垫资净变动
  v_ending_equity := v_beginning_equity + v_net_income + v_loan_changes;

  -- 按股东比例分配（任凯智60%，王孟南40%）
  v_renzhaizhi_share := v_ending_equity * 0.6;
  v_wangmengnan_share := v_ending_equity * 0.4;

  RETURN json_build_object(
    'period_start', p_start,
    'period_end', p_end,
    'beginning_equity', v_beginning_equity,
    'net_income', v_net_income,
    'loan_changes', v_loan_changes,
    'loan_detail', v_loan_detail,
    'ending_equity', v_ending_equity,
    'shareholders', json_build_array(
      json_build_object('name', '任凯智', 'share', '60%', 'equity', v_renzhaizhi_share),
      json_build_object('name', '王孟南', 'share', '40%', 'equity', v_wangmengnan_share)
    )
  );
END;
$$;
