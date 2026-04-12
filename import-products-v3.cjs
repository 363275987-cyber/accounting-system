/**
 * 产品完整导入脚本 v3 — 通过 SQL 直接导入（绕过 RLS）
 *
 * 生成 SQL 文件，然后通过 `npx supabase db query --linked` 执行
 */

const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const XLSX_PATH = '/Users/wangmengnan/Downloads/产品库-最新xiao.xlsx';
const SQL_DIR = '/tmp/product_import_sql';

// ===================== Category mapping =====================

const CATEGORY_MAP = {
  '球杆': 'cue',
  '包装': 'accessory',
  '配件': 'accessory',
  '球桌': 'other',
  '课程配套': 'other',
  '邮费': 'other',
};

function mapCategory(cat) {
  return CATEGORY_MAP[cat] || 'other';
}

function esc(s) {
  if (s == null) return 'NULL';
  return "'" + String(s).replace(/'/g, "''") + "'";
}

function escJson(obj) {
  if (!obj) return 'NULL';
  return "'" + JSON.stringify(obj).replace(/'/g, "''") + "'::jsonb";
}

// ===================== DISPIMG helpers =====================

const MAPPING_PATH = '/tmp/dispimg_mapping.json';
const EXTRACT_DIR = '/tmp/xlsx_extract';
let dispImgMap = {};
if (fs.existsSync(MAPPING_PATH)) {
  dispImgMap = JSON.parse(fs.readFileSync(MAPPING_PATH, 'utf8'));
}

function extractDispImgId(val) {
  if (!val || typeof val !== 'string') return null;
  const match = val.match(/DISPIMG\("(ID_[A-F0-9]+)"/);
  return match ? match[1] : null;
}

function getCellDispImg(ws, row, col) {
  const cell = ws[XLSX.utils.encode_cell({ r: row, c: col })];
  if (!cell) return null;
  if (cell.f) return extractDispImgId(cell.f);
  if (typeof cell.v === 'string') return extractDispImgId(cell.v);
  return null;
}

// ===================== Parse Excel =====================

function parseLatestPriceList(wb) {
  const ws = wb.Sheets['最新价格表'];
  const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
  const items = [];
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    if (!row || !row[0]) continue;
    const code = String(row[0]).trim();
    const name = String(row[2] || '').trim();
    if (!name) continue;
    const categoryRaw = String(row[3] || '').trim();
    const brand = String(row[4] || '').trim();
    const costPrice = Number(row[6]) || 0;
    const retailPrice = Number(row[7]) || 0;
    const minPrice = Number(row[8]) || 0;
    const note = String(row[9] || '').trim();
    items.push({ sku_code: code, name, category_raw: categoryRaw, category: mapCategory(categoryRaw), brand: brand || '其他', cost_price: costPrice, retail_price: retailPrice, min_price: minPrice, note });
  }
  return items;
}

function parsePearleyImages(wb) {
  // Return: name → img_id mapping for all 皮尔力 items with images
  const imgMap = [];

  // 皮尔力球杆
  const ws1 = wb.Sheets['皮尔力球杆'];
  if (ws1) {
    const data = XLSX.utils.sheet_to_json(ws1, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row || !row[1] || typeof row[1] !== 'string') continue;
      if (/^\d+元$/.test(String(row[1]).trim())) continue;
      const imgId = getCellDispImg(ws1, i, 9);
      if (imgId) imgMap.push({ name: row[1].trim(), img_id: imgId });
    }
  }
  // 皮尔力小头杆
  const ws2 = wb.Sheets['皮尔力小头杆'];
  if (ws2) {
    const data = XLSX.utils.sheet_to_json(ws2, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row || !row[1] || typeof row[1] !== 'string') continue;
      if (/^\d+元$/.test(String(row[1]).trim())) continue;
      const imgId = getCellDispImg(ws2, i, 7);
      if (imgId) imgMap.push({ name: row[1].trim(), img_id: imgId });
    }
  }
  // 皮尔力杆桶及杆包
  const ws3 = wb.Sheets['皮尔力杆桶及杆包'];
  if (ws3) {
    const data = XLSX.utils.sheet_to_json(ws3, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row || !row[1] || typeof row[1] !== 'string') continue;
      if (/^\d+元$/.test(String(row[1]).trim())) continue;
      const imgId = getCellDispImg(ws3, i, 8);
      if (imgId) imgMap.push({ name: row[1].trim(), img_id: imgId });
    }
  }
  // 皮尔力配件
  const ws4 = wb.Sheets['皮尔力配件'];
  if (ws4) {
    const data = XLSX.utils.sheet_to_json(ws4, { header: 1 });
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      if (!row || !row[0] || typeof row[0] !== 'string') continue;
      if (/^\d+元/.test(String(row[0]).trim())) continue;
      const imgId = getCellDispImg(ws4, i, 7);
      if (imgId) imgMap.push({ name: row[0].trim(), img_id: imgId });
    }
  }
  return imgMap;
}

function parseBundleCosts(wb) {
  const ws = wb.Sheets['套装成本'];
  if (!ws) return [];
  const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
  const bundles = [];
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    if (!row || !row[1]) continue;
    bundles.push({
      code: String(row[1]).trim(),
      name: String(row[2] || '').trim(),
      brand: String(row[0] || '').trim(),
      original_cost: Number(row[3]) || 0,
      price_diff: Number(row[4]) || 0,
      total_cost: Number(row[5]) || 0,
      note: String(row[6] || '').trim(),
    });
  }
  return bundles;
}

function parseBundleBOM(wb) {
  const ws = wb.Sheets['套装数量'];
  if (!ws) return {};
  const data = XLSX.utils.sheet_to_json(ws, { header: 1 });
  const bom = {};
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    if (!row || !row[0]) continue;
    const bundleCode = String(row[0]).trim();
    const itemCode = row[2] ? String(row[2]).trim() : null;
    const itemName = row[3] ? String(row[3]).trim() : null;
    const qty = row[13] != null ? Number(row[13]) : (row[4] != null ? Number(row[4]) : 1);
    if (!bom[bundleCode]) bom[bundleCode] = [];
    if (itemCode && qty > 0) {
      bom[bundleCode].push({ sku_code: itemCode, name: itemName, quantity: Math.round(qty) || 1 });
    }
  }
  return bom;
}

// ===================== Image URL builder =====================

function getImageUrl(imgId) {
  if (!imgId || !dispImgMap[imgId]) return null;
  const imgFile = dispImgMap[imgId];
  const localPath = path.join(EXTRACT_DIR, 'xl', imgFile);
  if (!fs.existsSync(localPath)) return null;
  const storagePath = `imports/${imgFile.replace('media/', '')}`;
  return `https://cmswoyiuoeqzeassubvw.supabase.co/storage/v1/object/public/products/${storagePath}`;
}

// ===================== Main =====================

function main() {
  console.log('=== 产品完整导入 v3 (SQL) ===\n');

  const wb = XLSX.readFile(XLSX_PATH);

  // Parse
  const priceList = parseLatestPriceList(wb);
  console.log(`最新价格表: ${priceList.length} 条`);

  const pearleyImages = parsePearleyImages(wb);
  console.log(`皮尔力图片: ${pearleyImages.length} 条`);

  const bundleCosts = parseBundleCosts(wb);
  console.log(`套装成本: ${bundleCosts.length} 条`);

  const bundleBOM = parseBundleBOM(wb);
  const bomCount = Object.values(bundleBOM).filter(v => v.length > 0).length;
  console.log(`套装BOM: ${bomCount} 个有明细`);

  // Build image lookup: match pearley name → price list sku_code
  const nameToImage = {};
  for (const item of pearleyImages) {
    const imgUrl = getImageUrl(item.img_id);
    if (!imgUrl) continue;

    // Try exact match
    for (const p of priceList) {
      const pName = p.name;
      const iName = item.name;
      // Normalize for matching
      const pNorm = pName.replace(/\s+/g, '').replace(/-/g, '').toLowerCase();
      const iNorm = iName.replace(/\s+/g, '').replace(/-/g, '').toLowerCase();
      if (pNorm === iNorm || pNorm.includes(iNorm) || iNorm.includes(pNorm)) {
        nameToImage[p.sku_code] = imgUrl;
        break;
      }
    }
  }
  console.log(`图片匹配成功: ${Object.keys(nameToImage).length} 个`);

  // Generate SQL
  if (!fs.existsSync(SQL_DIR)) fs.mkdirSync(SQL_DIR, { recursive: true });

  // === SQL Part 1: Insert single products ===
  let sql1 = '-- Single products\n';
  for (const p of priceList) {
    const imageUrl = nameToImage[p.sku_code] || null;
    const unit = p.category === 'cue' ? '根' : '个';
    const specs = { category_raw: p.category_raw };
    if (p.note) specs.note = p.note;
    if (p.min_price) specs.min_price = p.min_price;

    sql1 += `INSERT INTO products (name, spu_code, category, brand, cost_price, retail_price, unit, product_type, status, image, specs) VALUES (${esc(p.name)}, ${esc(p.sku_code)}, ${esc(p.category)}, ${esc(p.brand)}, ${p.cost_price}, ${p.retail_price}, ${esc(unit)}, 'single', 'active', ${esc(imageUrl)}, ${escJson(specs)});\n`;
  }
  fs.writeFileSync(path.join(SQL_DIR, '01_products.sql'), sql1);
  console.log(`\n生成 01_products.sql (${priceList.length} 条)`);

  // === SQL Part 2: Create SKUs for each product ===
  let sql2 = '-- Product SKUs\n';
  for (const p of priceList) {
    sql2 += `INSERT INTO product_skus (product_id, sku_code, specs, cost_price, retail_price, stock, status) SELECT id, ${esc(p.sku_code)}, ${esc(p.category_raw)}, ${p.cost_price}, ${p.retail_price}, 0, 'active' FROM products WHERE spu_code = ${esc(p.sku_code)} AND product_type = 'single' LIMIT 1;\n`;
  }
  fs.writeFileSync(path.join(SQL_DIR, '02_skus.sql'), sql2);
  console.log(`生成 02_skus.sql (${priceList.length} 条)`);

  // === SQL Part 3: Insert bundle products ===
  let sql3 = '-- Bundle products\n';
  for (const b of bundleCosts) {
    const specs = {};
    if (b.note) specs.note = b.note;
    if (b.price_diff) specs.price_diff = b.price_diff;
    specs.original_cost = b.original_cost;

    sql3 += `INSERT INTO products (name, spu_code, category, brand, cost_price, retail_price, unit, product_type, status, specs) VALUES (${esc(b.name)}, ${esc(b.code)}, 'cue', ${esc(b.brand || '其他')}, ${b.total_cost}, 0, '套', 'bundle', 'active', ${escJson(specs)}) ON CONFLICT (spu_code) DO UPDATE SET product_type = 'bundle', cost_price = EXCLUDED.cost_price, specs = EXCLUDED.specs, unit = '套';\n`;
  }
  fs.writeFileSync(path.join(SQL_DIR, '03_bundles.sql'), sql3);
  console.log(`生成 03_bundles.sql (${bundleCosts.length} 条)`);

  // === SQL Part 4: Insert bundle BOM items ===
  let sql4 = '-- Bundle BOM items\n';
  let bomTotal = 0;
  for (const [bundleCode, items] of Object.entries(bundleBOM)) {
    if (!items.length) continue;
    for (let idx = 0; idx < items.length; idx++) {
      const item = items[idx];
      // bundle_id comes from products where spu_code = bundleCode
      // sku_id comes from product_skus where sku_code = item.sku_code
      sql4 += `INSERT INTO bundle_items (bundle_id, sku_id, quantity, sort_order) SELECT bp.id, ps.id, ${item.quantity}, ${idx} FROM products bp, product_skus ps WHERE bp.spu_code = ${esc(bundleCode)} AND bp.product_type = 'bundle' AND ps.sku_code = ${esc(item.sku_code)} LIMIT 1;\n`;
      bomTotal++;
    }
  }
  fs.writeFileSync(path.join(SQL_DIR, '04_bom.sql'), sql4);
  console.log(`生成 04_bom.sql (${bomTotal} 条)`);

  console.log(`\nSQL 文件生成完毕，共 ${priceList.length + bundleCosts.length} 产品 + ${priceList.length} SKU + ${bomTotal} BOM`);
  console.log(`位置: ${SQL_DIR}/`);

  // Execute SQL files
  console.log('\n=== 开始执行 SQL ===');
  const files = ['01_products.sql', '02_skus.sql', '03_bundles.sql', '04_bom.sql'];
  for (const f of files) {
    const filePath = path.join(SQL_DIR, f);
    console.log(`\n执行 ${f}...`);
    try {
      const result = execSync(`npx supabase db query --linked < "${filePath}"`, {
        encoding: 'utf8',
        timeout: 120000,
        cwd: process.cwd(),
      });
      // Count success
      const content = fs.readFileSync(filePath, 'utf8');
      const insertCount = (content.match(/INSERT INTO/g) || []).length;
      console.log(`  ✓ ${insertCount} 条 INSERT 语句执行完成`);
    } catch (e) {
      console.log(`  ✕ 执行失败: ${e.message.substring(0, 200)}`);
      // Try to show the specific error
      if (e.stderr) console.log(`  stderr: ${e.stderr.substring(0, 300)}`);
    }
  }

  console.log('\n=== 导入完成 ===');
}

main();
