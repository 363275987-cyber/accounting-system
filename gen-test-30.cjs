// 生成30条电商测试订单 + 售后数据的Excel
const XLSX = require('xlsx');

const wb = XLSX.utils.book_new();
const skus = ['DAB002','DAD003','DAD005','DAD011','TA013','TA163','TA170','TA175','TB001','DAA074'];

function randDate(dayOffset) {
  const d = new Date(2026, 3, 1 + dayOffset); // 4月1日起
  const h = String(8 + Math.floor(Math.random()*12)).padStart(2,'0');
  const m = String(Math.floor(Math.random()*60)).padStart(2,'0');
  const s = String(Math.floor(Math.random()*60)).padStart(2,'0');
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${h}:${m}:${s}`;
}

// ============ 抖音销售订单（10条） ============
// 列映射：F(5)子订单编号  D(3)店铺  K(10)商家编码  L(11)数量  M(12)金额  W(22)状态  C(2)支付时间
const douyinHeader = ['序号','商品明细','支付完成时间','店铺','父订单编号','子订单编号','商家订单编号','售后状态','发货方式','物流单号','商家编码','商品数量','商品金额','售后备注','收货人','联系电话','收货地址','省份','城市','区县','订单备注','修改时间','订单状态'];
const douyinData = [douyinHeader];
const douyinStores = ['抖店-靓仔甄选台球店','抖店-王孟南台球教学店','抖店-好事情台球','抖店-台球one号店'];
const douyinStatuses = ['已完成','已完成','已完成','待发货','已发货'];
const douyinOrderNos = []; // 记录订单号，用于售后

for (let i = 0; i < 10; i++) {
  const dateStr = randDate(i % 8);
  const store = douyinStores[i % douyinStores.length];
  const sku = skus[i % skus.length];
  const amounts = [198, 368, 580, 1280, 2980, 88, 456, 1680, 3200, 760];
  const amount = amounts[i];
  const qty = i < 7 ? 1 : 2;
  const status = douyinStatuses[i % douyinStatuses.length];
  const extNo = `DY2026040${(i%8)+1}${String(i).padStart(3,'0')}`;
  douyinOrderNos.push(extNo);
  const row = new Array(23).fill('');
  row[0] = i + 1;
  row[2] = dateStr;
  row[3] = store;
  row[4] = `P${extNo}`;
  row[5] = extNo;
  row[10] = sku;
  row[11] = qty;
  row[12] = amount;
  row[14] = ['王小明','李大强','赵美丽','陈志远','周小芳','吴天昊','孙建国','黄雪梅','马超','郑大海'][i];
  row[15] = `138${String(10000000 + i*1111111).slice(0,8)}`;
  row[22] = status;
  douyinData.push(row);
}
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(douyinData), '抖音销售订单');

// ============ 快手销售订单（10条） ============
// 列映射：E(4)订单号  D(3)店铺  AG(32)SKU  L(11)实付款  K(10)状态  C(2)时间
const ksHeader = new Array(34).fill('');
ksHeader[0]='序号'; ksHeader[2]='订单时间'; ksHeader[3]='店铺'; ksHeader[4]='订单编号';
ksHeader[5]='商品名称'; ksHeader[10]='订单状态'; ksHeader[11]='实付款'; ksHeader[32]='SKU编码';
const ksData = [ksHeader];
const ksOrderNos = [];

for (let i = 0; i < 10; i++) {
  const dateStr = randDate(i % 8);
  const sku = skus[(i + 3) % skus.length];
  const amounts = [520, 168, 2680, 99, 1580, 380, 4200, 56, 890, 1200];
  const amount = amounts[i];
  const extNo = `KS2026040${(i%8)+1}${String(i).padStart(3,'0')}`;
  ksOrderNos.push(extNo);
  const row = new Array(34).fill('');
  row[0] = i + 1;
  row[2] = dateStr;
  row[3] = '快手-王孟南台球教学';
  row[4] = extNo;
  row[10] = '交易成功';
  row[11] = amount;
  row[32] = sku;
  ksData.push(row);
}
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(ksData), '快手销售订单');

// ============ 视频号销售订单（10条） ============
// 列映射：E(4)订单号  D(3)店铺  AV(47)SKU  V(21)实付金额  J(9)状态  F(5)下单时间
const sphHeader = new Array(48).fill('');
sphHeader[0]='序号'; sphHeader[3]='店铺'; sphHeader[4]='订单号'; sphHeader[5]='下单时间';
sphHeader[9]='订单状态'; sphHeader[21]='订单实际支付金额'; sphHeader[47]='SKU编码';
const sphData = [sphHeader];
const sphStores = ['视频号-靓仔台球','视频号-王孟南台球教学'];
const sphOrderNos = [];

for (let i = 0; i < 10; i++) {
  const dateStr = randDate(i % 8);
  const store = sphStores[i % sphStores.length];
  const sku = skus[(i + 5) % skus.length];
  const amounts = [680, 2200, 158, 3680, 420, 1280, 5200, 320, 980, 1860];
  const amount = amounts[i];
  const extNo = `SPH2026040${(i%8)+1}${String(i).padStart(3,'0')}`;
  sphOrderNos.push(extNo);
  const row = new Array(48).fill('');
  row[0] = i + 1;
  row[3] = store;
  row[4] = extNo;
  row[5] = dateStr;
  row[9] = '待发货';
  row[21] = amount;
  row[47] = sku;
  sphData.push(row);
}
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(sphData), '视频号销售订单');

// ============ 抖音售后订单（3条） ============
// 列映射：A(0)店铺 B(1)售后单号 C(2)订单号 L(12)退商品金额 Q(16)售后状态
const dyAfterHeader = new Array(17).fill('');
dyAfterHeader[0]='店铺'; dyAfterHeader[1]='售后单号'; dyAfterHeader[2]='订单号';
dyAfterHeader[12]='退商品金额'; dyAfterHeader[16]='售后状态';
const dyAfterData = [dyAfterHeader];
// 用前面抖音的订单号
const dyRefunds = [
  { store: '抖店-靓仔甄选台球店', refundNo: 'DYREF001', orderNo: douyinOrderNos[0], amount: 198, status: '退款成功' },
  { store: '抖店-好事情台球', refundNo: 'DYREF002', orderNo: douyinOrderNos[2], amount: 580, status: '同意退款，退款成功' },
];
dyRefunds.forEach(r => {
  const row = new Array(17).fill('');
  row[0] = r.store;
  row[1] = r.refundNo;
  row[2] = r.orderNo;
  row[12] = r.amount;
  row[16] = r.status;
  dyAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(dyAfterData), '抖音售后订单');

// ============ 快手售后订单（2条） ============
// 列映射：A(0)店铺 B(1)售后单号 C(2)订单编号 O(15)退款金额 P(16)售后状态
const ksAfterHeader = new Array(17).fill('');
ksAfterHeader[0]='店铺'; ksAfterHeader[1]='售后单号'; ksAfterHeader[2]='订单编号';
ksAfterHeader[15]='退款金额'; ksAfterHeader[16]='售后状态';
const ksAfterData = [ksAfterHeader];
const ksRefunds = [
  { store: '快手-王孟南台球教学', refundNo: 'KSREF001', orderNo: ksOrderNos[1], amount: 168, status: '售后成功' },
];
ksRefunds.forEach(r => {
  const row = new Array(17).fill('');
  row[0] = r.store;
  row[1] = r.refundNo;
  row[2] = r.orderNo;
  row[15] = r.amount;
  row[16] = r.status;
  ksAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(ksAfterData), '快手售后订单');

// ============ 视频号售后订单（2条） ============
// 列映射：A(0)店铺 B(1)售后单号 J(9)订单编号 W(22)退款金额 X(23)售后状态
const sphAfterHeader = new Array(24).fill('');
sphAfterHeader[0]='店铺'; sphAfterHeader[1]='售后单号'; sphAfterHeader[9]='订单编号';
sphAfterHeader[22]='退款金额'; sphAfterHeader[23]='售后状态';
const sphAfterData = [sphAfterHeader];
const sphRefunds = [
  { store: '视频号-靓仔台球', refundNo: 'SPHREF001', orderNo: sphOrderNos[0], amount: 680, status: '退款成功' },
  { store: '视频号-王孟南台球教学', refundNo: 'SPHREF002', orderNo: sphOrderNos[3], amount: 3680, status: '退款成功' },
];
sphRefunds.forEach(r => {
  const row = new Array(24).fill('');
  row[0] = r.store;
  row[1] = r.refundNo;
  row[9] = r.orderNo;
  row[22] = r.amount;
  row[23] = r.status;
  sphAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(sphAfterData), '视频号售后订单');

// ============ 输出 ============
const outPath = '/Users/wangmengnan/Desktop/电商测试订单30条.xlsx';
XLSX.writeFile(wb, outPath);
console.log('✅ 生成成功: ' + outPath);
console.log(`抖音销售: ${douyinData.length - 1} 条`);
console.log(`快手销售: ${ksData.length - 1} 条`);
console.log(`视频号销售: ${sphData.length - 1} 条`);
console.log(`抖音售后: ${dyAfterData.length - 1} 条`);
console.log(`快手售后: ${ksAfterData.length - 1} 条`);
console.log(`视频号售后: ${sphAfterData.length - 1} 条`);
console.log(`销售合计: ${douyinData.length + ksData.length + sphData.length - 3} 条`);
console.log(`售后合计: ${dyAfterData.length + ksAfterData.length + sphAfterData.length - 3} 条`);
