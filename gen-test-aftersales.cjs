// 生成10条售后数据，对应之前30条电商订单的订单号
const XLSX = require('xlsx');
const wb = XLSX.utils.book_new();

// 之前生成的订单号（与gen-test-30.cjs一致）
const douyinOrderNos = [];
const ksOrderNos = [];
const sphOrderNos = [];
for (let i = 0; i < 10; i++) {
  douyinOrderNos.push(`DY2026040${(i%8)+1}${String(i).padStart(3,'0')}`);
  ksOrderNos.push(`KS2026040${(i%8)+1}${String(i).padStart(3,'0')}`);
  sphOrderNos.push(`SPH2026040${(i%8)+1}${String(i).padStart(3,'0')}`);
}

// ============ 抖音售后订单（4条） ============
// A(0)店铺 B(1)售后单号 C(2)订单号 L(12)退商品金额 Q(16)售后状态
const dyAfterHeader = new Array(17).fill('');
dyAfterHeader[0]='店铺'; dyAfterHeader[1]='售后单号'; dyAfterHeader[2]='订单号';
dyAfterHeader[12]='退商品金额'; dyAfterHeader[16]='售后状态';
const dyAfterData = [dyAfterHeader];

const dyRefunds = [
  { store: '抖店-靓仔甄选台球店', refundNo: 'DYREF20260406001', orderNo: douyinOrderNos[0], amount: 198, status: '退款成功' },
  { store: '抖店-好事情台球',     refundNo: 'DYREF20260407002', orderNo: douyinOrderNos[2], amount: 580, status: '同意退款，退款成功' },
  { store: '抖店-台球one号店',    refundNo: 'DYREF20260408003', orderNo: douyinOrderNos[3], amount: 1280, status: '退款成功' },
  { store: '抖店-王孟南台球教学店', refundNo: 'DYREF20260409004', orderNo: douyinOrderNos[7], amount: 1680, status: '退款成功' },
];
dyRefunds.forEach(r => {
  const row = new Array(17).fill('');
  row[0] = r.store; row[1] = r.refundNo; row[2] = r.orderNo;
  row[12] = r.amount; row[16] = r.status;
  dyAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(dyAfterData), '抖音售后订单');

// ============ 快手售后订单（3条） ============
// A(0)店铺 B(1)售后单号 C(2)订单编号 O(15)退款金额 P(16)售后状态
const ksAfterHeader = new Array(17).fill('');
ksAfterHeader[0]='店铺'; ksAfterHeader[1]='售后单号'; ksAfterHeader[2]='订单编号';
ksAfterHeader[15]='退款金额'; ksAfterHeader[16]='售后状态';
const ksAfterData = [ksAfterHeader];

const ksRefunds = [
  { store: '快手-王孟南台球教学', refundNo: 'KSREF20260406001', orderNo: ksOrderNos[1], amount: 168, status: '售后成功' },
  { store: '快手-王孟南台球教学', refundNo: 'KSREF20260407002', orderNo: ksOrderNos[4], amount: 1580, status: '售后成功' },
  { store: '快手-王孟南台球教学', refundNo: 'KSREF20260408003', orderNo: ksOrderNos[6], amount: 4200, status: '售后成功' },
];
ksRefunds.forEach(r => {
  const row = new Array(17).fill('');
  row[0] = r.store; row[1] = r.refundNo; row[2] = r.orderNo;
  row[15] = r.amount; row[16] = r.status;
  ksAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(ksAfterData), '快手售后订单');

// ============ 视频号售后订单（3条） ============
// A(0)店铺 B(1)售后单号 J(9)订单编号 W(22)退款金额 X(23)售后状态
const sphAfterHeader = new Array(24).fill('');
sphAfterHeader[0]='店铺'; sphAfterHeader[1]='售后单号'; sphAfterHeader[9]='订单编号';
sphAfterHeader[22]='退款金额'; sphAfterHeader[23]='售后状态';
const sphAfterData = [sphAfterHeader];

const sphRefunds = [
  { store: '视频号-靓仔台球',     refundNo: 'SPHREF20260406001', orderNo: sphOrderNos[0], amount: 680, status: '退款成功' },
  { store: '视频号-王孟南台球教学', refundNo: 'SPHREF20260407002', orderNo: sphOrderNos[3], amount: 3680, status: '退款成功' },
  { store: '视频号-靓仔台球',     refundNo: 'SPHREF20260409003', orderNo: sphOrderNos[8], amount: 980, status: '退款成功' },
];
sphRefunds.forEach(r => {
  const row = new Array(24).fill('');
  row[0] = r.store; row[1] = r.refundNo; row[9] = r.orderNo;
  row[22] = r.amount; row[23] = r.status;
  sphAfterData.push(row);
});
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(sphAfterData), '视频号售后订单');

// ============ 输出 ============
const outPath = '/Users/wangmengnan/Desktop/电商售后订单10条.xlsx';
XLSX.writeFile(wb, outPath);
console.log('✅ 生成成功: ' + outPath);
console.log(`抖音售后: ${dyAfterData.length - 1} 条`);
console.log(`快手售后: ${ksAfterData.length - 1} 条`);
console.log(`视频号售后: ${sphAfterData.length - 1} 条`);
console.log(`售后合计: ${dyAfterData.length + ksAfterData.length + sphAfterData.length - 3} 条`);
