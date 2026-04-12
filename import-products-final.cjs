const { createClient } = require('@supabase/supabase-js');
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const CRED_PATH = '/Users/wangmengnan/.openclaw-autoclaw/workspace/.supabase-credentials.json';
const APP_DIR = '/Users/wangmengnan/.openclaw-autoclaw/workspace/accounting-app';
const MEDIA_DIR = '/Users/wangmengnan/.openclaw-autoclaw/media/inbound';

// Find the xlsx file
const xlsxFile = fs.readdirSync(MEDIA_DIR).find(f => f.endsWith('.xlsx'));
const filePath = path.join(MEDIA_DIR, xlsxFile);

const creds = JSON.parse(fs.readFileSync(CRED_PATH, 'utf8'));
const sb = createClient(creds.url, creds.service_role_key);
const wb = XLSX.readFile(filePath);

const CAT = {'球杆':'cue','配件':'accessory','包装':'accessory','球桌':'table','':'accessory'};
const EM = {cue:'🎱',accessory:'🔧',table:'🎱'};

async function main() {
  console.log('Starting import from:', filePath);
  
  const rows = XLSX.utils.sheet_to_json(wb.Sheets['最新价格表'], {defval: ''});
  let pC = 0, sC = 0, bC = 0, biC = 0;
  const map = {};

  // Step 1: Import single products
  for (const r of rows) {
    const code = (r['商品编码'] || '').trim();
    const name = (r['商品名称'] || '').trim();
    const cat = CAT[r['项目']] || 'accessory';
    const brand = (r['品牌'] || '').trim();
    const cost = parseFloat(r['成本价']) || 0;
    const retail = parseFloat(r['零售价']) || 0;
    if (!code || !name) continue;

    // Remove code prefix from name
    const escCode = code.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const clean = name.replace(new RegExp('^' + escCode + '[\\s-]*'), '').trim() || name;

    const { data: p, error } = await sb.from('products').insert({
      name: clean,
      category: cat,
      brand: brand || null,
      product_type: 'single',
      cost_price: cost,
      retail_price: retail || null,
      image: EM[cat] || '📦',
      unit: cat === 'cue' ? '根' : '个',
      status: 'active',
    }).select('id').single();

    if (error) {
      console.error('ERR product: ' + clean + ' (' + code + '): ' + error.message.substring(0, 80));
      continue;
    }
    map[code] = p.id;
    pC++;

    const { error: sErr } = await sb.from('product_skus').insert({
      product_id: p.id,
      sku_code: code,
      specs: [],
      cost_price: cost,
      retail_price: retail || 0,
      stock: 0,
      reserved: 0,
      platform_bindings: [],
      status: 'active',
    });
    if (!sErr) sC++;
  }

  console.log('Step 1 done: ' + pC + ' products, ' + sC + ' SKUs');

  // Step 2: Import bundles
  const bundles = XLSX.utils.sheet_to_json(wb.Sheets['套装成本'], {defval: ''});
  for (const r of bundles) {
    const code = (r['套装编码'] || '').trim();
    const name = (r['套装'] || '').trim();
    const brand = (r['品牌'] || '').trim();
    const cost = parseFloat(r['合计成本']) || 0;
    if (!code || !name) continue;

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
    map[code] = p.id;
    bC++;

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
    if (!sErr) sC++;
  }

  console.log('Step 2 done: ' + bC + ' bundles');

  // Step 3: Import bundle items
  const qtyRaw = XLSX.utils.sheet_to_json(wb.Sheets['套装数量'], {header: 1, defval: ''});
  const seen = new Set();
  for (let i = 2; i < qtyRaw.length; i++) {
    const r = qtyRaw[i];
    const bCode = String(r[0] || '').trim();
    const sCode = String(r[2] || '').trim();
    const qty = parseInt(r[4]) || 1;
    if (!bCode || !sCode || qty < 1) continue;
    const k = bCode + '|' + sCode;
    if (seen.has(k)) continue;
    seen.add(k);

    const bId = map[bCode];
    if (!bId) continue;

    const { data: sku } = await sb.from('product_skus').select('id').eq('sku_code', sCode).single();
    if (!sku) continue;

    try {
      await sb.from('bundle_items').insert({
        bundle_id: bId,
        sku_id: sku.id,
        quantity: qty,
        sort_order: biC,
      });
      biC++;
    } catch (e) { /* duplicate, skip */ }
  }

  console.log('Step 3 done: ' + biC + ' bundle items');
  console.log('');
  console.log('=== TOTAL ===');
  console.log('Products: ' + pC);
  console.log('Bundles: ' + bC);
  console.log('SKUs: ' + sC);
  console.log('Bundle items: ' + biC);
}

main().catch(e => console.error('FATAL:', e.message));
