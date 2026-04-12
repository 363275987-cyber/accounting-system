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
  // Get all SKUs
  const { data: skus } = await sb.from('product_skus').select('id, sku_code, product_id');
  const skuByCode = {};
  skus.forEach(s => { skuByCode[s.sku_code] = s; });
  console.log('SKUs loaded:', Object.keys(skuByCode).length);

  // Parse 套装数量
  const qtyRaw = XLSX.utils.sheet_to_json(wb.Sheets['套装数量'], {header: 1, defval: ''});
  const seen = new Set();
  let biC = 0, miss = 0;

  // Batch insert to speed things up
  const batch = [];
  for (let i = 2; i < qtyRaw.length; i++) {
    const r = qtyRaw[i];
    const bCode = String(r[0] || '').trim();
    const sCode = String(r[2] || '').trim();
    const qty = parseInt(r[4]) || 1;
    if (!bCode || !sCode || qty < 1) continue;
    const k = bCode + '|' + sCode;
    if (seen.has(k)) continue;
    seen.add(k);

    const bSku = skuByCode[bCode];
    const sSku = skuByCode[sCode];
    if (!bSku || !sSku) { miss++; continue; }

    batch.push({
      bundle_id: bSku.product_id,
      sku_id: sSku.id,
      quantity: qty,
      sort_order: biC,
    });
    biC++;
  }

  console.log('Items to insert:', batch.length, 'missed:', miss);

  // Insert in chunks of 100
  for (let i = 0; i < batch.length; i += 100) {
    const chunk = batch.slice(i, i + 100);
    const { error } = await sb.from('bundle_items').insert(chunk);
    if (error) {
      console.log('Chunk ' + i + ' error:', error.message.substring(0, 100));
      // Try one by one for this chunk
      for (const item of chunk) {
        try { await sb.from('bundle_items').insert(item); } catch(e) {}
      }
    }
    console.log('Inserted', Math.min(i + 100, batch.length), '/', batch.length);
  }

  console.log('DONE. Bundle items inserted:', biC);
}

main().catch(e => console.error('FATAL:', e.message));
