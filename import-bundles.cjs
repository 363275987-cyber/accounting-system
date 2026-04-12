const { createClient } = require('@supabase/supabase-js');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const CRED_PATH = '/Users/wangmengnan/.openclaw-autoclaw/workspace/.supabase-credentials.json';
const MEDIA_DIR = '/Users/wangmengnan/.openclaw-autoclaw/media/inbound';
const xlsxFile = fs.readdirSync(MEDIA_DIR).find(f => f.endsWith('.xlsx'));
const filePath = path.join(MEDIA_DIR, xlsxFile);

const creds = JSON.parse(fs.readFileSync(CRED_PATH, 'utf8'));
const sb = createClient(creds.url, creds.service_role_key);
const wb = XLSX.readFile(filePath);

// Build sku_code -> product_skus.id mapping
async function buildSkuMap() {
  const { data } = await sb.from('product_skus').select('id, sku_code, product_id');
  const byCode = {};
  data.forEach(r => { byCode[r.sku_code] = r; });
  return byCode;
}

async function main() {
  const skuMap = await buildSkuMap();
  console.log('Existing SKUs:', Object.keys(skuMap).length);

  // Step 1: Insert missing SKUs for products that were created without SKUs
  const { data: products } = await sb.from('products').select('id, name, product_type, cost_price, retail_price');
  let newSku = 0;
  for (const p of products) {
    // Check if this product already has a SKU
    const hasSku = Object.values(skuMap).some(s => s.product_id === p.id);
    if (hasSku) continue;

    // Generate sku_code from name or use existing pattern
    const { data: existingSkus } = await sb.from('product_skus').select('sku_code').eq('product_id', p.id);
    if (existingSkus && existingSkus.length > 0) continue;

    // For single products, try to find the code from the Excel
    // Skip - we'll handle this separately
  }

  // Step 2: Import bundles from 套装成本
  const bundles = XLSX.utils.sheet_to_json(wb.Sheets['套装成本'], {defval: ''});
  let bC = 0;
  for (const r of bundles) {
    const code = (r['套装编码'] || '').trim();
    const name = (r['套装'] || '').trim();
    const brand = (r['品牌'] || '').trim();
    const cost = parseFloat(r['合计成本']) || 0;
    if (!code || !name) continue;

    // Check if already exists as SKU
    if (skuMap[code]) { console.log('Skip existing bundle:', code, name); continue; }

    const { data: p, error } = await sb.from('products').insert({
      name,
      brand: brand || null,
      product_type: 'bundle',
      category: 'cue',
      cost_price: cost,
      retail_price: null,
      image: '📦',
      unit: '个',
      status: 'active',
    }).select('id').single();

    if (error) {
      console.error('ERR bundle: ' + name + ': ' + error.message.substring(0, 80));
      continue;
    }

    const { error: sErr } = await sb.from('product_skus').insert({
      product_id: p.id,
      sku_code: code,
      specs: [],
      cost_price: cost,
      retail_price: 0,
      stock: 0,
      reserved: 0,
      platform_bindings: [],
      status: 'active',
    });
    if (!sErr) {
      skuMap[code] = { product_id: p.id };
      bC++;
      console.log('Bundle added:', code, name);
    }
  }
  console.log('Bundles added:', bC);

  // Step 3: Import bundle items
  const qtyRaw = XLSX.utils.sheet_to_json(wb.Sheets['套装数量'], {header: 1, defval: ''});
  const seen = new Set();
  let biC = 0;

  // Rebuild skuMap with full data
  const freshMap = await buildSkuMap();
  // Also build sku_code -> product_id for bundle lookup
  const skuToProductId = {};
  for (const s of Object.values(freshMap)) {
    skuToProductId[s.sku_code] = s;
  }

  // Build product name -> product_id for bundle products (from products table)
  const { data: allProducts } = await sb.from('products').select('id, name').eq('product_type', 'bundle');
  const bundleProductMap = {};
  allProducts.forEach(p => { bundleProductMap[p.name] = p.id; });

  for (let i = 2; i < qtyRaw.length; i++) {
    const r = qtyRaw[i];
    const bCode = String(r[0] || '').trim();
    const sCode = String(r[2] || '').trim();
    const qty = parseInt(r[4]) || 1;
    if (!bCode || !sCode || qty < 1) continue;
    const k = bCode + '|' + sCode;
    if (seen.has(k)) continue;
    seen.add(k);

    // Find bundle product_id via sku_code
    const bSku = skuToProductId[bCode];
    if (!bSku) continue;

    // Find sub-item SKU
    const sSku = skuToProductId[sCode];
    if (!sSku) continue;

    try {
      await sb.from('bundle_items').insert({
        bundle_id: bSku.product_id,
        sku_id: sSku.id,
        quantity: qty,
        sort_order: biC,
      });
      biC++;
    } catch (e) { /* dup */ }
  }
  console.log('Bundle items added:', biC);

  // Step 4: Check for products without SKUs and try to fix
  const { data: orphanProducts } = await sb.from('products').select('id, name').eq('product_type', 'single');
  let fixed = 0;
  for (const p of orphanProducts) {
    const hasSku = Object.values(freshMap).some(s => s.product_id === p.id);
    if (!hasSku) {
      console.log('Orphan product (no SKU):', p.id, p.name);
    }
  }
  console.log('Orphan products:', orphanProducts.length - Object.keys(freshMap).length + bC);

  console.log('DONE');
}

main().catch(e => console.error('FATAL:', e.message));
