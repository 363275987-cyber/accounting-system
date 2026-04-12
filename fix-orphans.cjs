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

async function main() {
  // Get existing SKU product_ids
  const { data: existingSkus } = await sb.from('product_skus').select('product_id');
  const hasSkuSet = new Set(existingSkus.map(s => s.product_id));

  // Get single products without SKUs
  const { data: orphans } = await sb.from('products').select('id, name, cost_price, retail_price').eq('product_type', 'single');
  const needSku = orphans.filter(p => !hasSkuSet.has(p.id));
  console.log('Orphan products (no SKU):', needSku.length);

  if (needSku.length === 0) { console.log('All good!'); return; }

  // Build reverse lookup: product name -> sku_code from Excel
  const rows = XLSX.utils.sheet_to_json(wb.Sheets['最新价格表'], {defval: ''});
  const nameToCode = {};
  for (const r of rows) {
    const code = (r['商品编码'] || '').trim();
    const name = (r['商品名称'] || '').trim();
    if (!code || !name) continue;
    const escCode = code.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const clean = name.replace(new RegExp('^' + escCode + '[\\s-]*'), '').trim() || name;
    nameToCode[clean] = code;
    nameToCode[name] = code; // also map full name
  }

  // Also check bundle products
  const { data: bundleOrphans } = await sb.from('products').select('id, name, cost_price').eq('product_type', 'bundle');
  const bundleNeedSku = bundleOrphans.filter(p => !hasSkuSet.has(p.id));
  console.log('Orphan bundles (no SKU):', bundleNeedSku.length);

  // For bundles, try to find TA code from 套装成本
  const bundleRows = XLSX.utils.sheet_to_json(wb.Sheets['套装成本'], {defval: ''});
  for (const r of bundleRows) {
    const code = (r['套装编码'] || '').trim();
    const name = (r['套装'] || '').trim();
    nameToCode[name] = code;
  }

  // Generate SKUs for orphans
  const batch = [];
  for (const p of [...needSku, ...bundleNeedSku]) {
    const code = nameToCode[p.name] || null;
    batch.push({
      product_id: p.id,
      sku_code: code || 'GEN-' + p.id.substring(0, 8),
      specs: [],
      cost_price: p.cost_price || 0,
      retail_price: p.retail_price || 0,
      stock: 0,
      reserved: 0,
      platform_bindings: [],
      status: 'active',
    });
  }

  // Insert in chunks
  for (let i = 0; i < batch.length; i += 100) {
    const chunk = batch.slice(i, i + 100);
    const { error } = await sb.from('product_skus').insert(chunk);
    if (error) console.log('Chunk error:', error.message.substring(0, 100));
    else console.log('Inserted', Math.min(i + 100, batch.length), '/', batch.length);
  }

  console.log('DONE. Fixed', batch.length, 'orphan products');
}

main().catch(e => console.error('FATAL:', e.message));
