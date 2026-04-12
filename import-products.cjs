// 导入脚本：从Excel导入产品到 Supabase (SPU + SKU)
const { createClient } = require('@supabase/supabase-js');
const XLSX = require('xlsx');
const fs = require('fs');

// Supabase 配置
const creds = JSON.parse(fs.readFileSync('/Users/wangmengnan/.openclaw-autoclaw/workspace/.supabase-credentials.json', 'utf8'));
const supabase = createClient(creds.url, creds.service_role_key);

const filePath = '/Users/wangmengnan/.openclaw-autoclaw/media/inbound/å_å_¾ç_ç_å_å_æ_æ_äº_å_é_å_ä_æ_¼å_æ_è_ä_æ_¼æ_ç_è_-æ_æ_xiao---dc4373ba-cec1-46ab-8682-34ed4e34c3ce.xlsx';
const wb = XLSX.readFile(filePath);

// 分类映射
const CATEGORY_MAP = {
  '球杆': 'cue',
  '配件': 'accessory',
  '包装': 'packaging',
  '球桌': 'table',
};

// emoji 映射
const CATEGORY_EMOJI = {
  'cue': '🎱',
  'accessory': '🔧',
  'packaging': '📦',
  'table': '🎱',
};

async function main() {
  console.log('=== 开始导入 ===');

  // 1. 从「最新价格表」导入所有产品
  const priceSheet = wb.Sheets['最新价格表'];
  const priceData = XLSX.utils.sheet_to_json(priceSheet, { defval: '' });

  let productCount = 0;
  let skuCount = 0;
  const productIds = {}; // sku_code → product_id mapping

  for (const row of priceData) {
    const code = (row['商品编码'] || '').trim();
    const name = (row['商品名称'] || '').trim();
    const category = CATEGORY_MAP[row['项目']] || 'accessory';
    const brand = (row['品牌'] || '').trim();
    const costPrice = parseFloat(row['成本价']) || 0;
    const retailPrice = parseFloat(row['零售价']) || 0;
    const wechatPrice = parseFloat(row['微信最低价']) || 0;

    if (!code || !name) continue;

    // 提取纯名称（去掉编码前缀）
    const cleanName = name.replace(code, '').replace(/^[\s\-_]+/, '').trim() || name;

    // 创建产品(SPU)
    const { data: product, error: pErr } = await supabase
      .from('products')
      .insert({
        name: cleanName,
        category,
        brand: brand || null,
        product_type: 'single',
        cost_price: costPrice,
        retail_price: retailPrice || null,
        image: CATEGORY_EMOJI[category] || '📦',
        unit: category === 'cue' ? '根' : '个',
        status: 'active',
      })
      .select('id')
      .single();

    if (pErr) {
      console.error(`产品创建失败: ${cleanName} (${code}) - ${pErr.message}`);
      continue;
    }

    productCount++;
    productIds[code] = product.id;

    // 创建SKU
    const { error: sErr } = await supabase
      .from('product_skus')
      .insert({
        product_id: product.id,
        sku_code: code,
        specs: [],
        cost_price: costPrice,
        retail_price: retailPrice || 0,
        stock: 0,
        reserved: 0,
        platform_bindings: [],
        status: 'active',
      });

    if (sErr) {
      console.error(`SKU创建失败: ${code} - ${sErr.message}`);
    } else {
      skuCount++;
    }
  }

  // 2. 从「套装成本」导入套装产品
  const bundleSheet = wb.Sheets['套装成本'];
  const bundleData = XLSX.utils.sheet_to_json(bundleSheet, { defval: '' });

  let bundleCount = 0;
  for (const row of bundleData) {
    const code = (row['套装编码'] || '').trim();
    const name = (row['套装'] || '').trim();
    const brand = (row['品牌'] || '').trim();
    const totalCost = parseFloat(row['合计成本']) || 0;

    if (!code || !name) continue;

    // 创建套装产品
    const { data: product, error: pErr } = await supabase
      .from('products')
      .insert({
        name,
        brand: brand || null,
        product_type: 'bundle',
        category: 'cue', // 套装主要是球杆
        cost_price: totalCost,
        retail_price: null,
        image: '📦',
        unit: '个',
        status: 'active',
      })
      .select('id')
      .single();

    if (pErr) {
      console.error(`套装创建失败: ${name} (${code}) - ${pErr.message}`);
      continue;
    }

    productIds[code] = product.id;
    bundleCount++;

    // 创建套装的默认SKU
    await supabase.from('product_skus').insert({
      product_id: product.id,
      sku_code: code,
      specs: [],
      cost_price: totalCost,
      retail_price: 0,
      stock: 0,
      reserved: 0,
      platform_bindings: [],
      status: 'active',
    });
    skuCount++;
  }

  // 3. 从「套装数量」导入套装子商品
  const bundleQtyRaw = XLSX.utils.sheet_to_json(wb.Sheets['套装数量'], { header: 1, defval: '' });
  // 数据格式: [套装编码, 套装名, 子SKU编码, 子商品名, 数量, ...]
  let bundleItemCount = 0;
  for (let i = 2; i < bundleQtyRaw.length; i++) {
    const r = bundleQtyRaw[i];
    const bundleCode = String(r[0] || '').trim();
    const subSkuCode = String(r[2] || '').trim();
    const qty = parseInt(r[4]) || 1;

    if (!bundleCode || !subSkuCode || qty < 1) continue;

    const bundleProductId = productIds[bundleCode];
    // 找子SKU的id
    const subSkuProductId = productIds[subSkuCode];

    if (!bundleProductId) continue;

    // 需要找到 product_skus 的 id
    // 子SKU可能本身没有单独的产品，而是在套装价格表中
    // 先查 product_skus
    const { data: subSku } = await supabase
      .from('product_skus')
      .select('id, product_id')
      .eq('sku_code', subSkuCode)
      .single();

    if (!subSku) continue;

    // 检查是否已存在
    const { data: existing } = await supabase
      .from('bundle_items')
      .select('id')
      .eq('bundle_id', bundleProductId)
      .eq('sku_id', subSku.id)
      .single();

    if (existing) continue; // 已存在就跳过

    const { error: biErr } = await supabase
      .from('bundle_items')
      .insert({
        bundle_id: bundleProductId,
        sku_id: subSku.id,
        quantity: qty,
        sort_order: bundleItemCount,
      });

    if (!biErr) bundleItemCount++;
  }

  console.log(`\n=== 导入完成 ===`);
  console.log(`产品(SPU): ${productCount} 个`);
  console.log(`套装: ${bundleCount} 个`);
  console.log(`SKU: ${skuCount} 个`);
  console.log(`套装明细: ${bundleItemCount} 条`);
}

main().catch(e => console.error('导入失败:', e));
