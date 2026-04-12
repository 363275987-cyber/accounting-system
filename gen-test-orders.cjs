// 生成测试电商Excel（抖音销售 + 快手销售 + 视频号销售）
const XLSX = require('xlsx');

const wb = XLSX.utils.book_new();

// ============ 抖音销售订单（sheet名需含"抖"或"抖店"） ============
// 列: A(0)序号 B(1)xxx C(2)支付完成时间 D(3)店铺 E(4)xxx F(5)子订单编号 G-K(6-9)xxx
//      K(10)商家编码 L(11)商品数量 M(12)商品金额 N-V(13-21)xxx W(22)订单状态
const douyinSales = [
  ['序号','商品明细','支付完成时间','店铺','父订单编号','子订单编号','商家订单编号','售后状态','发货方式','物流单号','商家编码','商品数量','商品金额','售后备注','收货人','联系电话','收货地址','省份','城市','区县','订单备注','修改时间','订单状态'],
];
const douyinStores = ['抖店-靓仔甄选台球店','抖店-王孟南台球教学店','抖店-台球four号店','抖店-好事情台球'];
const skus = ['DAB002','DAD003','DAD005','DAD011','TA013','TA163','TA170','TA175','TB001','DAA074'];
const statuses = ['已完成','已完成','已完成','已完成','待发货','已发货'];
let orderIdx = 1;
for (let day = 0; day < 7; day++) {
  const date = new Date(2026, 2, 26 + day); // 3/26 ~ 4/1
  const dateStr = `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')} ${String(8 + Math.floor(Math.random()*12)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}`;
  const count = 3 + Math.floor(Math.random() * 5);
  for (let i = 0; i < count; i++) {
    const store = douyinStores[Math.floor(Math.random() * douyinStores.length)];
    const sku = skus[Math.floor(Math.random() * skus.length)];
    const amount = (100 + Math.floor(Math.random() * 900));
    const qty = 1 + Math.floor(Math.random() * 3);
    const status = statuses[Math.floor(Math.random() * statuses.length)];
    const extNo = `DD${dateStr.replace(/[-: ]/g,'')}${String(i).padStart(3,'0')}`;
    douyinSales.push([orderIdx++, '', dateStr, store, `P${extNo}`, extNo, '', '', '快递', '', sku, qty, amount, '', '张三', '13800138000', '广东省深圳市龙华区xxx', '广东', '深圳', '龙华', '', '', status]);
  }
}
const wsDouyin = XLSX.utils.aoa_to_sheet(douyinSales);
XLSX.utils.book_append_sheet(wb, wsDouyin, '抖音销售订单');

// ============ 快手销售订单 ============
// 列: A(0)序号 B(1)xxx C(2)时间 D(3)店铺 E(4)订单号 F-I(5-8)xxx
//      J(9)订单状态 K(10)订单状态(另一个) L(11)实付款 ... AF(32)SKU编码
const kuaishouSales = [
  ['序号','','订单时间','店铺','订单编号','商品名称','','','订单状态','订单状态2','实付款','','','','','','','','','','','','','','','','','','','','','','','SKU编码'],
];
const ksStores = ['快手-王孟南台球教学'];
for (let day = 0; day < 7; day++) {
  const date = new Date(2026, 2, 26 + day);
  const dateStr = `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')} ${String(10 + Math.floor(Math.random()*10)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}`;
  const count = 2 + Math.floor(Math.random() * 4);
  for (let i = 0; i < count; i++) {
    const store = ksStores[0];
    const sku = skus[Math.floor(Math.random() * skus.length)];
    const amount = 80 + Math.floor(Math.random() * 600);
    const status = '交易成功';
    const extNo = `KS${dateStr.replace(/[-: ]/g,'')}${String(i).padStart(3,'0')}`;
    const row = new Array(33).fill('');
    row[0] = orderIdx++;
    row[2] = dateStr;
    row[3] = store;
    row[4] = extNo;
    row[8] = status;
    row[10] = status;
    row[11] = amount;
    row[32] = sku;
    kuaishouSales.push(row);
  }
}
const wsKuaishou = XLSX.utils.aoa_to_sheet(kuaishouSales);
XLSX.utils.book_append_sheet(wb, wsKuaishou, '快手销售订单');

// ============ 视频号销售订单 ============
// 列: A(0)序号 B(1)xxx C(2)xxx D(3)店铺 E(4)订单号 F(5)下单时间 G-I(6-8)xxx
//      J(9)订单状态 K-V(10-21)xxx V(21)订单实际支付金额 ... AV(47)SKU编码
const sphSales = [
  ['序号','','','店铺','订单号','下单时间','','','订单状态','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','','SKU编码','订单实际支付金额'],
];
const sphStores = ['视频号-靓仔台球','视频号-王孟南台球教学'];
for (let day = 0; day < 7; day++) {
  const date = new Date(2026, 2, 26 + day);
  const dateStr = `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')} ${String(9 + Math.floor(Math.random()*12)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}:${String(Math.floor(Math.random()*60)).padStart(2,'0')}`;
  const count = 2 + Math.floor(Math.random() * 5);
  for (let i = 0; i < count; i++) {
    const store = sphStores[Math.floor(Math.random() * sphStores.length)];
    const sku = skus[Math.floor(Math.random() * skus.length)];
    const amount = 50 + Math.floor(Math.random() * 800);
    const status = '待发货';
    const extNo = `SPH${dateStr.replace(/[-: ]/g,'')}${String(i).padStart(3,'0')}`;
    const row = new Array(49).fill('');
    row[0] = orderIdx++;
    row[3] = store;
    row[4] = extNo;
    row[5] = dateStr;
    row[9] = status;
    row[21] = amount;
    row[47] = sku;
    sphSales.push(row);
  }
}
const wsSph = XLSX.utils.aoa_to_sheet(sphSales);
XLSX.utils.book_append_sheet(wb, wsSph, '视频号销售订单');

const outPath = '/Users/wangmengnan/.openclaw-autoclaw/workspace/accounting-app/test-ecommerce-orders.xlsx';
XLSX.writeFile(wb, outPath);
console.log('✅ 生成成功: ' + outPath);
console.log(`抖音: ${douyinSales.length - 1} 条`);
console.log(`快手: ${kuaishouSales.length - 1} 条`);
console.log(`视频号: ${sphSales.length - 1} 条`);
console.log(`总计: ${douyinSales.length + kuaishouSales.length + sphSales.length - 3} 条`);
