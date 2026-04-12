// 模拟电商导入的payload，通过supabase REST API直接测试
// 这就是 importEcommerceOrders 会发送的完整payload

const https = require('https');
const http = require('http');

// 从 .env 读取supabase配置
const fs = require('fs');
const envContent = fs.readFileSync(__dirname + '/.env', 'utf8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const m = line.match(/^(VITE_\w+)\s*=\s*(.+)$/);
  if (m) envVars[m[1]] = m[2].trim();
});

const SUPABASE_URL = envVars.VITE_SUPABASE_URL;
const SUPABASE_KEY = envVars.VITE_SUPABASE_ANON_KEY;

console.log('Supabase URL:', SUPABASE_URL);

// 模拟 importEcommerceOrders 构建的 payload（和真实导入代码一模一样）
const testPayload = {
  order_no: 'TEST_IMPORT_SIM_001',
  customer_name: '电商客户',
  customer_phone: '',
  customer_address: '',
  product_name: '',
  product_category: 'other',
  amount: 198,
  status: 'completed',
  order_source: 'cs_service',
  external_order_no: 'TEST_IMPORT_SIM_001',
  platform_type: 'douyin',
  platform_store: '抖店-靓仔甄选台球店',
  account_code: '抖店-靓仔甄选台球店',
  sku_code: 'DAB002',
  payment_amount: 198,
  order_time: '2026-04-01T02:00:00.000Z',
  account_id: 'dcdae01d-69e0-4a54-9aba-e550234dce7a',
  // NOTE: 导入代码没有设置 quantity, payment_method, creator_id, sales_id
};

console.log('\n=== Test Payload ===');
console.log(JSON.stringify(testPayload, null, 2));

// 发送请求
const url = new URL(SUPABASE_URL + '/rest/v1/orders');
const postData = JSON.stringify(testPayload);

const options = {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_KEY,
    'Authorization': 'Bearer ' + SUPABASE_KEY,
    'Prefer': 'return=representation',
  },
};

const req = https.request(url, options, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    console.log('\n=== Response ===');
    console.log('Status:', res.statusCode);
    try {
      const parsed = JSON.parse(body);
      console.log(JSON.stringify(parsed, null, 2));
    } catch(e) {
      console.log(body);
    }

    // 如果成功，清理测试数据
    if (res.statusCode === 201) {
      console.log('\n✅ INSERT 成功! 现在清理...');
      const delUrl = new URL(SUPABASE_URL + '/rest/v1/orders?external_order_no=eq.TEST_IMPORT_SIM_001');
      const delReq = https.request(delUrl, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_KEY,
          'Authorization': 'Bearer ' + SUPABASE_KEY,
        },
      }, (delRes) => {
        let delBody = '';
        delRes.on('data', c => delBody += c);
        delRes.on('end', () => console.log('Cleanup status:', delRes.statusCode));
      });
      delReq.write(JSON.stringify({ deleted_at: new Date().toISOString() }));
      delReq.end();
    }
  });
});

req.write(postData);
req.end();
