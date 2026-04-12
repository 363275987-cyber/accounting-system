const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const c = JSON.parse(fs.readFileSync('/Users/wangmengnan/.openclaw-autoclaw/workspace/.supabase-credentials.json','utf8'));
const sb = createClient(c.url, c.service_role_key);

async function main() {
  // Find products without SKUs
  const { data: allP } = await sb.from('products').select('id, name, product_type, cost_price, retail_price');
  const { data: allS } = await sb.from('product_skus').select('id, product_id, sku_code');
  const skuPids = new Set(allS.map(s => s.product_id));
  const orphans = allP.filter(p => !skuPids.has(p.id));
  
  console.log('Orphans:', orphans.length);
  
  // Generate unique SKU codes using a counter per prefix
  let counter = 1;
  for (const p of orphans) {
    const prefix = p.product_type === 'bundle' ? 'TB' : 'SP';
    const skuCode = prefix + '-' + String(counter).padStart(4, '0');
    counter++;
    
    try {
      await sb.from('product_skus').insert({
        product_id: p.id,
        sku_code: skuCode,
        specs: [],
        cost_price: p.cost_price || 0,
        retail_price: p.retail_price || 0,
        stock: 0,
        reserved: 0,
        platform_bindings: [],
        status: 'active',
      });
    } catch (e) {
      console.log('ERR:', p.name, e.message.substring(0, 60));
    }
  }
  
  // Final count
  const { count: sc } = await sb.from('product_skus').select('*', {count:'exact',head:true});
  console.log('Final SKU count:', sc);
}

main().catch(e => console.error('FATAL:', e.message));
