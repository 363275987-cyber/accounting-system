-- ============================================================
-- SPU + SKU 数据库迁移
-- 聚水潭风格：SPU=产品概念，SKU=可售规格
-- ============================================================

-- 1. products 表加字段（SPU级别）
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_type text DEFAULT 'single'
  CHECK (product_type IN ('single', 'course', 'bundle', 'gift_bag'));
ALTER TABLE products ADD COLUMN IF NOT EXISTS spu_code text;

-- 2. 创建 product_skus 表（SKU级别）
CREATE TABLE IF NOT EXISTS product_skus (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku_code text,
  specs jsonb DEFAULT '[]'::jsonb,
  cost_price numeric DEFAULT 0,
  retail_price numeric DEFAULT 0,
  stock integer DEFAULT 0,
  reserved integer DEFAULT 0,
  platform_bindings jsonb DEFAULT '[]'::jsonb,
  barcode text,
  status text DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_product_skus_product_id ON product_skus(product_id);
CREATE INDEX IF NOT EXISTS idx_product_skus_sku_code ON product_skus(sku_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_skus_sku_code_unique ON product_skus(sku_code) WHERE sku_code IS NOT NULL AND sku_code != '';

-- 3. 创建 bundle_items 表（套装明细）
CREATE TABLE IF NOT EXISTS bundle_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  bundle_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sku_id uuid NOT NULL REFERENCES product_skus(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 1,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(bundle_id, sku_id)
);

CREATE INDEX IF NOT EXISTS idx_bundle_items_bundle_id ON bundle_items(bundle_id);
CREATE INDEX IF NOT EXISTS idx_bundle_items_sku_id ON bundle_items(sku_id);

-- 4. RLS
ALTER TABLE product_skus ENABLE ROW LEVEL SECURITY;
ALTER TABLE bundle_items ENABLE ROW LEVEL SECURITY;

-- 5. RLS policies (allow authenticated users full access)
CREATE POLICY "product_skus_authenticated_select" ON product_skus FOR SELECT TO authenticated USING (true);
CREATE POLICY "product_skus_authenticated_insert" ON product_skus FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "product_skus_authenticated_update" ON product_skus FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "product_skus_authenticated_delete" ON product_skus FOR DELETE TO authenticated USING (true);

CREATE POLICY "bundle_items_authenticated_select" ON bundle_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "bundle_items_authenticated_insert" ON bundle_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "bundle_items_authenticated_update" ON bundle_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "bundle_items_authenticated_delete" ON bundle_items FOR DELETE TO authenticated USING (true);

-- 6. 触发器：updated_at 自动更新
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_product_skus_updated_at ON product_skus;
CREATE TRIGGER trg_product_skus_updated_at
  BEFORE UPDATE ON product_skus
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. 视图：产品 + SKU 汇总视图
CREATE OR REPLACE VIEW v_product_skus AS
SELECT
  p.id as product_id,
  p.spu_code,
  p.name as product_name,
  p.category,
  p.sub_category,
  p.brand,
  p.product_type,
  p.image,
  p.status as product_status,
  s.id as sku_id,
  s.sku_code,
  s.specs,
  s.cost_price as sku_cost_price,
  s.retail_price as sku_retail_price,
  s.stock,
  s.reserved,
  (s.stock - s.reserved) as available_stock,
  s.platform_bindings,
  s.barcode,
  s.status as sku_status
FROM products p
LEFT JOIN product_skus s ON s.product_id = p.id AND s.status = 'active'
WHERE p.status = 'active'
ORDER BY p.name, s.sku_code;

-- 8. RPC：获取产品详情（含所有SKU）
CREATE OR REPLACE FUNCTION get_product_detail(p_product_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_product jsonb;
  v_skus jsonb;
  v_bundle jsonb;
BEGIN
  SELECT row_to_json(p.*) INTO v_product
  FROM products p WHERE p.id = p_product_id;

  SELECT jsonb_agg(row_to_json(s.*)) INTO v_skus
  FROM product_skus s WHERE s.product_id = p_product_id ORDER BY s.sku_code;

  IF v_product->>'product_type' IN ('bundle', 'gift_bag') THEN
    SELECT jsonb_agg(jsonb_build_object(
      'sku_id', bi.sku_id,
      'product_name', bp.name,
      'sku_code', bs.sku_code,
      'specs', bs.specs,
      'quantity', bi.quantity
    )) INTO v_bundle
    FROM bundle_items bi
    JOIN product_skus bs ON bs.id = bi.sku_id
    JOIN products bp ON bp.id = bs.product_id
    WHERE bi.bundle_id = p_product_id;
  END IF;

  RETURN jsonb_build_object(
    'product', v_product,
    'skus', COALESCE(v_skus, '[]'::jsonb),
    'bundle_items', COALESCE(v_bundle, '[]'::jsonb)
  );
END;
$$;

-- 9. RPC：SKU 库存操作
CREATE OR REPLACE FUNCTION adjust_sku_stock(
  p_sku_id uuid,
  p_quantity integer,
  p_change_type text,
  p_note text DEFAULT ''
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_sku product_skus;
  v_before integer;
  v_after integer;
BEGIN
  SELECT * INTO v_sku FROM product_skus WHERE id = p_sku_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SKU不存在');
  END IF;

  v_before := v_sku.stock;
  IF p_change_type IN ('in', 'return') THEN
    v_after := v_sku.stock + p_quantity;
  ELSIF p_change_type IN ('out', 'ship', 'sale') THEN
    IF v_sku.stock - v_sku.reserved < p_quantity THEN
      RETURN jsonb_build_object('success', false, 'error', '库存不足', 'available', v_sku.stock - v_sku.reserved);
    END IF;
    v_after := v_sku.stock - p_quantity;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', '无效操作类型');
  END IF;

  UPDATE product_skus SET stock = v_after WHERE id = p_sku_id;

  RETURN jsonb_build_object('success', true, 'sku_id', p_sku_id, 'before', v_before, 'after', v_after, 'change', p_quantity, 'type', p_change_type);
END;
$$;

-- 10. RPC：通过 SKU 编码匹配产品（用于 Excel 导入）
CREATE OR REPLACE FUNCTION match_product_by_sku_code(p_sku_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'sku_id', s.id,
    'sku_code', s.sku_code,
    'product_id', p.id,
    'product_name', p.name,
    'brand', p.brand,
    'category', p.category,
    'specs', s.specs,
    'cost_price', s.cost_price,
    'retail_price', s.retail_price
  ) INTO v_result
  FROM product_skus s
  JOIN products p ON p.id = s.product_id
  WHERE s.sku_code = p_sku_code AND s.status = 'active';

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;
