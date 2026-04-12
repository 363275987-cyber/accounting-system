const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');
const https = require('https');

const SUPABASE_URL = 'https://cmswoyiuoeqzeassubvw.supabase.co';
const SUPABASE_KEY = 'sb_publishable_kyhsOoWxO8YEBczAIJsUxQ_9KUmxFV2';

const XLSX_PATH = '/Users/wangmengnan/Downloads/产品库-最新xiao.xlsx';
const EXTRACT_DIR = '/tmp/xlsx_extract';
const MAPPING_PATH = '/tmp/dispimg_mapping.json';

// Load DISPIMG mapping
const dispImgMap = JSON.parse(fs.readFileSync(MAPPING_PATH, 'utf8'));

// Supabase REST helper
function supabaseRequest(method, endpoint, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint, SUPABASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      path: url.pathname + url.search,
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, data }); }
      });
    });
    req.on('error', reject);
    if (body) req.end(JSON.stringify(body));
    else req.end();
  });
}

// Upload image to Supabase Storage
function uploadImage(localPath, storagePath) {
  return new Promise((resolve, reject) => {
    const fileData = fs.readFileSync(localPath);
    const url = new URL(`/storage/v1/object/products/${storagePath}`, SUPABASE_URL);
    const options = {
      method: 'POST',
      hostname: url.hostname,
      path: url.pathname,
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'image/png',
        'Content-Length': fileData.length,
        'x-upsert': 'true',
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, data }));
    });
    req.on('error', reject);
    req.end(fileData);
  });
}

function getPublicUrl(storagePath) {
  return `${SUPABASE_URL}/storage/v1/object/public/products/${storagePath}`;
}

// Extract DISPIMG ID from formula
function extractDispImgId(val) {
  if (!val || typeof val !== 'string') return null;
  const match = val.match(/DISPIMG\("(ID_[A-F0-9]+)"/);
  return match ? match[1] : null;
}

// Get cell formula or value
function getCellDispImg(ws, row, col) {
  const cell = ws[XLSX.utils.encode_cell({ r: row, c: col })];
  if (!cell) return null;
  if (cell.f) return extractDispImgId(cell.f);
  if (typeof cell.v === 'string') return extractDispImgId(cell.v);
  return null;
}

// Parse all 4 product sheets
function parseProducts() {
  const wb = XLSX.readFile(XLSX_PATH);
  const products = [];

  // --- Sheet 1: 皮尔力球杆 ---
  {
    const ws = wb.Sheets['皮尔力球杆'];
    const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
    let series = '';
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row) continue;
      if (row[0]) series = String(row[0]).trim();
      const name = row[1];
      if (!name || typeof name !== 'string' || /^\d+元$/.test(name.trim())) continue;

      products.push({
        name: name.trim(),
        brand: '皮尔力',
        category: '球杆',
        series,
        cost_price: Number(row[2]) || 0,
        retail_price: Number(row[3]) || 0,
        bundle_desc: String(row[4] || ''),
        note: String(row[6] || ''),
        img_id: getCellDispImg(ws, i, 9), // col J
      });
    }
  }

  // --- Sheet 2: 皮尔力小头杆 ---
  {
    const ws = wb.Sheets['皮尔力小头杆'];
    const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
    let series = '';
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row) continue;
      if (row[0]) series = String(row[0]).trim();
      const name = row[1];
      if (!name || typeof name !== 'string' || /^\d+元$/.test(name.trim())) continue;

      products.push({
        name: name.trim(),
        brand: '皮尔力',
        category: '小头杆',
        series,
        cost_price: Number(row[2]) || 0,
        retail_price: Number(row[3]) || 0,
        bundle_desc: String(row[4] || ''),
        note: '',
        img_id: getCellDispImg(ws, i, 7), // col H
      });
    }
  }

  // --- Sheet 3: 皮尔力杆桶及杆包 ---
  {
    const ws = wb.Sheets['皮尔力杆桶及杆包'];
    const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
    let series = '';
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row) continue;
      if (row[0]) series = String(row[0]).trim();
      const name = row[1];
      if (!name || typeof name !== 'string' || /^\d+元$/.test(name.trim())) continue;

      products.push({
        name: name.trim(),
        brand: '皮尔力',
        category: series || '杆桶杆包',
        series,
        cost_price: Number(row[2]) || 0,
        retail_price: Number(row[3]) || 0,
        bundle_desc: String(row[4] || ''),
        note: String(row[5] || ''),
        img_id: getCellDispImg(ws, i, 8), // col I
      });
    }
  }

  // --- Sheet 4: 皮尔力配件 ---
  {
    const ws = wb.Sheets['皮尔力配件'];
    const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row) continue;
      const name = row[0];
      if (!name || typeof name !== 'string' || /^\d+元$/.test(name.trim())) continue;

      products.push({
        name: name.trim(),
        brand: '皮尔力',
        category: '配件',
        series: '',
        cost_price: Number(row[2]) || 0,
        retail_price: Number(row[3]) || 0,
        bundle_desc: '',
        note: String(row[4] || ''),
        img_id: getCellDispImg(ws, i, 7), // col H
      });
    }
  }

  // --- Sheet 5: 配件 (第三方品牌) ---
  {
    const ws = wb.Sheets['配件'];
    const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row) continue;
      const code = row[0];
      const name = row[1];
      if (!name || typeof name !== 'string') continue;
      const brand = String(row[3] || '').trim();
      const costPrice = Number(row[7]) || 0;
      const retailPrice = Number(row[8]) || 0;
      if (!costPrice && !retailPrice) continue;

      products.push({
        name: name.trim(),
        brand: brand || '其他',
        category: '配件',
        series: String(row[2] || ''),
        cost_price: costPrice,
        retail_price: retailPrice,
        bundle_desc: '',
        note: '',
        img_id: null, // 配件表无图
        spu_code: String(code || ''),
      });
    }
  }

  return products;
}

async function main() {
  console.log('=== 产品导入工具 v2 ===\n');

  const products = parseProducts();
  console.log(`解析到 ${products.length} 个产品\n`);

  // Deduplicate by name
  const seen = new Set();
  const unique = [];
  for (const p of products) {
    const key = `${p.brand}|${p.name}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(p);
  }
  console.log(`去重后 ${unique.length} 个产品\n`);

  let uploaded = 0, imgFailed = 0, inserted = 0, insertFailed = 0;

  for (let i = 0; i < unique.length; i++) {
    const p = unique[i];
    let imageUrl = null;

    // Upload image
    if (p.img_id && dispImgMap[p.img_id]) {
      const imgFile = dispImgMap[p.img_id];
      const localPath = path.join(EXTRACT_DIR, 'xl', imgFile);
      if (fs.existsSync(localPath)) {
        const storagePath = `imports/${imgFile.replace('media/', '')}`;
        try {
          const res = await uploadImage(localPath, storagePath);
          if (res.status === 200) {
            imageUrl = getPublicUrl(storagePath);
            uploaded++;
          } else {
            imgFailed++;
          }
        } catch {
          imgFailed++;
        }
      }
    }

    // Insert product
    const payload = {
      name: p.name,
      brand: p.brand,
      category: p.category,
      cost_price: p.cost_price,
      retail_price: p.retail_price,
      image: imageUrl,
      status: 'active',
      unit: p.category === '球杆' || p.category === '小头杆' ? '根' : '个',
      product_type: 'single',
      specs: { series: p.series, bundle: p.bundle_desc, note: p.note },
    };
    if (p.spu_code) payload.spu_code = p.spu_code;

    const res = await supabaseRequest('POST', '/rest/v1/products', payload);
    if (res.status >= 200 && res.status < 300) {
      inserted++;
    } else {
      insertFailed++;
      if (insertFailed <= 5) console.log(`\n  ✕ 插入失败 ${p.name}: ${JSON.stringify(res.data)}`);
    }
    process.stdout.write(`\r[${i+1}/${unique.length}] 已导入 ${inserted} | 图片 ${uploaded} | 失败 ${insertFailed}`);
  }

  console.log(`\n\n=== 导入完成 ===`);
  console.log(`产品: ${inserted} 成功 / ${insertFailed} 失败`);
  console.log(`图片: ${uploaded} 上传成功 / ${imgFailed} 失败`);
}

main().catch(console.error);
