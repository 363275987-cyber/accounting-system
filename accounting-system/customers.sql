-- =====================================================
-- 客户管理系统 - 数据库初始化
-- 手机号自动归集方案
-- =====================================================

-- 1. 创建 customers 表
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text UNIQUE NOT NULL,
  name text,
  address text,
  source text,
  tags jsonb DEFAULT '[]'::jsonb,
  status text DEFAULT 'active',
  note text,
  total_orders int DEFAULT 0,
  total_amount numeric DEFAULT 0,
  first_order_at timestamptz,
  last_order_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. orders 表添加 customer_id 字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES customers(id) ON DELETE SET NULL;

-- 3. 创建 updated_at 触发器（customers表）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS customers_updated_at ON customers;
CREATE TRIGGER customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- RLS 策略
-- =====================================================
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- admin / finance: 全权限
CREATE POLICY "customers_admin_all" ON customers
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

-- sales / cs: SELECT 所有客户基本信息
CREATE POLICY "customers_sales_select" ON customers
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid())
  );

-- sales / cs: INSERT 仅允许
CREATE POLICY "customers_sales_insert" ON customers
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid())
  );

-- sales / cs: UPDATE 仅允许自己的
CREATE POLICY "customers_sales_update" ON customers
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'finance'))
  );

-- =====================================================
-- RPC 函数
-- =====================================================

-- 4. auto_link_customer() — 订单创建/更新时自动关联客户
CREATE OR REPLACE FUNCTION auto_link_customer(p_order_id uuid)
RETURNS uuid AS $$
DECLARE
  v_order RECORD;
  v_customer_id uuid;
  v_customer RECORD;
BEGIN
  -- 获取订单信息
  SELECT * INTO v_order FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  
  -- 没有手机号则跳过
  IF v_order.customer_phone IS NULL OR v_order.customer_phone = '' THEN
    UPDATE orders SET customer_id = NULL WHERE id = p_order_id;
    RETURN NULL;
  END IF;
  
  -- 按手机号查找客户（去除空格和短横线后匹配）
  SELECT * INTO v_customer FROM customers
    WHERE regexp_replace(phone, '[\s\-]', '', 'g') = regexp_replace(v_order.customer_phone, '[\s\-]', '', 'g');
  
  IF v_customer.id IS NOT NULL THEN
    -- 找到客户 → 更新信息
    v_customer_id := v_customer.id;
    UPDATE customers SET
      name = COALESCE(NULLIF(v_order.customer_name, ''), v_customer.name),
      address = COALESCE(NULLIF(v_order.customer_address, ''), v_customer.address),
      source = COALESCE(v_order.order_source, v_customer.source),
      last_order_at = GREATEST(COALESCE(v_customer.last_order_at, '1970-01-01'::timestamptz), v_order.created_at),
      updated_at = now()
    WHERE id = v_customer_id;
  ELSE
    -- 没找到 → 自动创建客户
    INSERT INTO customers (phone, name, address, source, first_order_at, last_order_at)
    VALUES (
      v_order.customer_phone,
      v_order.customer_name,
      v_order.customer_address,
      v_order.order_source,
      v_order.created_at,
      v_order.created_at
    )
    RETURNING id INTO v_customer_id;
  END IF;
  
  -- 更新订单的 customer_id
  UPDATE orders SET customer_id = v_customer_id WHERE id = p_order_id;
  
  RETURN v_customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. update_customer_stats() — 批量刷新客户统计
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS void AS $$
BEGIN
  UPDATE customers c SET
    total_orders = sub.cnt,
    total_amount = sub.total,
    first_order_at = sub.first_at,
    last_order_at = sub.last_at,
    updated_at = now()
  FROM (
    SELECT
      customer_id,
      COUNT(*) AS cnt,
      COALESCE(SUM(amount), 0) AS total,
      MIN(created_at) AS first_at,
      MAX(created_at) AS last_at
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
  ) sub
  WHERE c.id = sub.customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. get_customer_stats() — 返回客户列表+统计
CREATE OR REPLACE FUNCTION get_customer_stats(
  p_search text DEFAULT '',
  p_status text DEFAULT '',
  p_tag text DEFAULT '',
  p_limit int DEFAULT 100,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid, phone text, name text, address text, source text,
  tags jsonb, status text, note text,
  total_orders int, total_amount numeric,
  first_order_at timestamptz, last_order_at timestamptz,
  created_at timestamptz,
  -- 额外统计
  avg_amount numeric, recent_months int,
  top_products text[], refund_count int, refund_total numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id, c.phone, c.name, c.address, c.source,
    c.tags, c.status, c.note,
    COALESCE(c.total_orders, 0)::int,
    COALESCE(c.total_amount, 0)::numeric,
    c.first_order_at, c.last_order_at, c.created_at,
    CASE WHEN c.total_orders > 0 THEN ROUND(c.total_amount / c.total_orders, 2) ELSE 0 END::numeric,
    -- 最近N个月有订单
    (SELECT COUNT(DISTINCT date_trunc('month', o.created_at))
     FROM orders o WHERE o.customer_id = c.id AND o.deleted_at IS NULL
       AND o.created_at >= now() - interval '6 months')::int,
    -- Top产品
    (SELECT COALESCE(array_agg(sub.pn), ARRAY[]::text[]) FROM (SELECT product_name AS pn FROM orders o WHERE o.customer_id = c.id GROUP BY product_name ORDER BY COUNT(*) DESC LIMIT 3) sub)
     FROM (SELECT product_name, COUNT(*) count FROM orders o
           WHERE o.customer_id = c.id AND o.deleted_at IS NULL GROUP BY product_name ORDER BY count DESC LIMIT 3) sub)::text[],
    -- 退款统计
    COALESCE((SELECT COUNT(*)::int FROM refunds r
      JOIN orders o ON o.id = r.order_id WHERE o.customer_id = c.id AND r.deleted_at IS NULL), 0)::int,
    COALESCE((SELECT COALESCE(SUM(refund_amount), 0) FROM refunds r
      JOIN orders o ON o.id = r.order_id WHERE o.customer_id = c.id AND r.deleted_at IS NULL), 0)::numeric
  FROM customers c
  WHERE
    -- 搜索过滤
    (p_search = '' OR p_search IS NULL
     OR c.phone LIKE '%' || p_search || '%'
     OR c.name ILIKE '%' || p_search || '%')
    -- 状态过滤
    AND (p_status = '' OR p_status IS NULL OR c.status = p_status)
    -- 标签过滤
    AND (p_tag = '' OR p_tag IS NULL OR c.tags @> to_jsonb(p_tag::text))
  ORDER BY c.last_order_at DESC NULLS LAST, c.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. get_customer_detail() — 客户详情
CREATE OR REPLACE FUNCTION get_customer_detail(p_customer_id uuid)
RETURNS JSON AS $$
DECLARE
  v_customer customers%ROWTYPE;
  v_orders json;
  v_refunds json;
  v_trend json;
  v_result json;
BEGIN
  SELECT * INTO v_customer FROM customers WHERE id = p_customer_id;
  IF NOT FOUND THEN RETURN NULL::json; END IF;
  
  -- 所有订单
  SELECT json_agg(row_to_json(o)) INTO v_orders
  FROM (
    SELECT o.id, o.order_no, o.product_category, o.product_name, o.amount,
      o.status, o.order_source, o.note,
      o.created_at
    FROM orders o
    WHERE o.customer_id = p_customer_id
    ORDER BY o.created_at DESC
  ) o;
  
  -- 退款记录
  SELECT json_agg(row_to_json(r)) INTO v_refunds
  FROM (
    SELECT r.refund_no, r.refund_amount, r.reason, r.status, r.created_at,
      o.order_no, o.product_name
    FROM refunds r
    JOIN orders o ON o.id = r.order_id
    WHERE o.customer_id = p_customer_id
    ORDER BY r.created_at DESC
  ) r;
  
  -- 月度消费趋势（最近12个月）
  SELECT json_agg(row_to_json(m)) INTO v_trend
  FROM (
    SELECT
      to_char(m.month, 'YYYY-MM') AS month,
      COALESCE(m.total_amount, 0)::numeric AS amount,
      COALESCE(m.count, 0)::int AS orders
    FROM (
      SELECT
        date_trunc('month', created_at) AS month,
        SUM(amount) AS total_amount,
        COUNT(*) AS count
      FROM orders
      WHERE customer_id = p_customer_id
        AND created_at >= now() - interval '12 months'
      GROUP BY date_trunc('month', created_at)
    ) m
    ORDER BY m.month
  ) m;
  
  -- 组装结果
  SELECT json_build_object(
    'customer', row_to_json(v_customer),
    'orders', COALESCE(v_orders, '[]'::json),
    'refunds', COALESCE(v_refunds, '[]'::json),
    'trend', COALESCE(v_trend, '[]'::json),
    'avg_order_amount', CASE WHEN v_customer.total_orders > 0
      THEN ROUND(v_customer.total_amount / v_customer.total_orders, 2) ELSE 0 END
  ) INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. get_customer_summary() — 统计卡片数据
CREATE OR REPLACE FUNCTION get_customer_summary()
RETURNS JSON AS $$
DECLARE
  v_total int;
  v_new_this_month int;
  v_active_30d int;
  v_avg_amount numeric;
BEGIN
  SELECT COUNT(*) INTO v_total FROM customers WHERE status != 'blacklist';
  
  SELECT COUNT(*) INTO v_new_this_month FROM customers
    WHERE status != 'blacklist'
      AND created_at >= date_trunc('month', now());
  
  SELECT COUNT(*) INTO v_active_30d FROM customers
    WHERE status != 'blacklist'
      AND last_order_at >= now() - interval '30 days';
  
  SELECT CASE WHEN COUNT(*) > 0 THEN ROUND(AVG(total_amount), 2) ELSE 0 END INTO v_avg_amount
    FROM customers WHERE status != 'blacklist' AND total_orders > 0;
  
  RETURN json_build_object(
    'total_customers', v_total,
    'new_this_month', v_new_this_month,
    'active_30d', v_active_30d,
    'avg_amount', v_avg_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 初始化：从现有订单创建客户记录
-- =====================================================
INSERT INTO customers (phone, name, address, source, first_order_at, last_order_at)
SELECT DISTINCT ON (
  regexp_replace(customer_phone, '[\s\-]', '', 'g')
)
  customer_phone,
  -- 取最新的姓名
  (SELECT customer_name FROM orders o2
   WHERE regexp_replace(o2.customer_phone, '[\s\-]', '', 'g') = regexp_replace(o.customer_phone, '[\s\-]', '', 'g')
   AND o2.customer_phone IS NOT NULL AND o2.customer_phone != ''
   AND o2.deleted_at IS NULL
   ORDER BY o2.created_at DESC LIMIT 1),
  -- 取最新的地址
  (SELECT customer_address FROM orders o3
   WHERE regexp_replace(o3.customer_phone, '[\s\-]', '', 'g') = regexp_replace(o.customer_phone, '[\s\-]', '', 'g')
   AND o3.customer_phone IS NOT NULL AND o3.customer_phone != ''
   AND o3.deleted_at IS NULL
   ORDER BY o3.created_at DESC LIMIT 1),
  -- 取最新的来源
  (SELECT order_source FROM orders o4
   WHERE regexp_replace(o4.customer_phone, '[\s\-]', '', 'g') = regexp_replace(o.customer_phone, '[\s\-]', '', 'g')
   AND o4.customer_phone IS NOT NULL AND o4.customer_phone != ''
   AND o4.deleted_at IS NULL
   ORDER BY o4.created_at DESC LIMIT 1),
  -- 首次下单
  (SELECT MIN(created_at) FROM orders o5
   WHERE regexp_replace(o5.customer_phone, '[\s\-]', '', 'g') = regexp_replace(o.customer_phone, '[\s\-]', '', 'g')
   AND o5.customer_phone IS NOT NULL AND o5.customer_phone != ''
   AND o5.deleted_at IS NULL),
  -- 最近下单
  (SELECT MAX(created_at) FROM orders o6
   WHERE regexp_replace(o6.customer_phone, '[\s\-]', '', 'g') = regexp_replace(o.customer_phone, '[\s\-]', '', 'g')
   AND o6.customer_phone IS NOT NULL AND o6.customer_phone != ''
   AND o6.deleted_at IS NULL)
FROM orders o
WHERE o.customer_phone IS NOT NULL AND o.customer_phone != '' AND o.deleted_at IS NULL
ON CONFLICT (phone) DO NOTHING;

-- 关联订单到客户
UPDATE orders o SET customer_id = c.id
FROM customers c
WHERE regexp_replace(o.customer_phone, '[\s\-]', '', 'g') = regexp_replace(c.phone, '[\s\-]', '', 'g')
  AND o.customer_phone IS NOT NULL AND o.customer_phone != ''
  AND o.deleted_at IS NULL
  AND o.customer_id IS NULL;

-- 刷新客户统计
SELECT update_customer_stats();
