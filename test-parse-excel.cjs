// 测试解析生成的Excel文件，模拟 parseEcommerceExcel 的逻辑
const XLSX = require('xlsx');

const filePath = '/Users/wangmengnan/Desktop/电商测试订单30条.xlsx';
console.log('读取文件:', filePath);

const workbook = XLSX.readFile(filePath);
console.log('Sheet 名称:', workbook.SheetNames);

for (const sheetName of workbook.SheetNames) {
  const sheet = workbook.Sheets[sheetName];
  const jsonData = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });

  console.log(`\n=== ${sheetName} ===`);
  console.log(`总行数: ${jsonData.length}`);

  if (jsonData.length < 2) {
    console.log('❌ 行数不足，跳过');
    continue;
  }

  // 检查平台识别
  const isDouyin = sheetName.includes('抖音') || sheetName.includes('抖店');
  const isKuaishou = sheetName.includes('快手');
  const isShipinhao = sheetName.includes('视频号');
  const isAfterSales = sheetName.includes('售后');
  console.log(`平台: ${isDouyin ? '抖音' : isKuaishou ? '快手' : isShipinhao ? '视频号' : '未识别'}`);
  console.log(`类型: ${isAfterSales ? '售后' : '销售'}`);

  // 显示表头（第一行）
  const header = jsonData[0];
  console.log(`表头列数: ${header.length}`);

  // 检查前2条数据行
  const dataRows = jsonData.slice(1).filter(row =>
    row.some(cell => cell !== '' && cell !== null && cell !== undefined)
  );
  console.log(`有效数据行: ${dataRows.length}`);

  if (dataRows.length > 0) {
    const row = dataRows[0];
    console.log(`\n第一行数据（共 ${row.length} 列）:`);

    if (isDouyin && !isAfterSales) {
      // 抖音销售: F(5)订单号 D(3)店铺 K(10)SKU L(11)数量 M(12)金额 W(22)状态 C(2)时间
      console.log(`  C[2] 支付时间: "${row[2]}"`);
      console.log(`  D[3] 店铺: "${row[3]}"`);
      console.log(`  F[5] 子订单编号: "${row[5]}"`);
      console.log(`  K[10] 商家编码: "${row[10]}"`);
      console.log(`  L[11] 数量: "${row[11]}"`);
      console.log(`  M[12] 金额: "${row[12]}"`);
      console.log(`  W[22] 状态: "${row[22]}"`);

      // 检查关键字段
      const amount = parseFloat(String(row[12]).replace(/[,，\s]/g, ''));
      const orderNo = String(row[5] ?? '').trim();
      console.log(`  → 解析金额: ${amount} (${isNaN(amount) || amount <= 0 ? '❌无效' : '✅有效'})`);
      console.log(`  → 解析订单号: "${orderNo}" (${orderNo ? '✅有效' : '❌空'})`);
    }

    if (isKuaishou && !isAfterSales) {
      // 快手: E(4)订单号 D(3)店铺 AG(32)SKU L(11)实付款 K(10)状态 C(2)时间
      console.log(`  C[2] 时间: "${row[2]}"`);
      console.log(`  D[3] 店铺: "${row[3]}"`);
      console.log(`  E[4] 订单号: "${row[4]}"`);
      console.log(`  K[10] 状态: "${row[10]}"`);
      console.log(`  L[11] 实付款: "${row[11]}"`);
      console.log(`  AG[32] SKU: "${row[32]}"`);

      const amount = parseFloat(String(row[11]).replace(/[,，\s]/g, ''));
      console.log(`  → 解析金额: ${amount} (${isNaN(amount) || amount <= 0 ? '❌无效' : '✅有效'})`);
    }

    if (isShipinhao && !isAfterSales) {
      // 视频号: E(4)订单号 D(3)店铺 AV(47)SKU V(21)金额 J(9)状态 F(5)时间
      console.log(`  D[3] 店铺: "${row[3]}"`);
      console.log(`  E[4] 订单号: "${row[4]}"`);
      console.log(`  F[5] 时间: "${row[5]}"`);
      console.log(`  J[9] 状态: "${row[9]}"`);
      console.log(`  V[21] 金额: "${row[21]}"`);
      console.log(`  AV[47] SKU: "${row[47]}"`);

      const amount = parseFloat(String(row[21]).replace(/[,，\s]/g, ''));
      console.log(`  → 解析金额: ${amount} (${isNaN(amount) || amount <= 0 ? '❌无效' : '✅有效'})`);
    }

    if (isAfterSales) {
      if (isDouyin) {
        console.log(`  A[0] 店铺: "${row[0]}"`);
        console.log(`  B[1] 售后单号: "${row[1]}"`);
        console.log(`  C[2] 订单号: "${row[2]}"`);
        console.log(`  L[12] 退款金额: "${row[12]}"`);
        console.log(`  Q[16] 状态: "${row[16]}"`);
      }
      if (isKuaishou) {
        console.log(`  A[0] 店铺: "${row[0]}"`);
        console.log(`  B[1] 售后单号: "${row[1]}"`);
        console.log(`  C[2] 订单号: "${row[2]}"`);
        console.log(`  O[15] 退款金额: "${row[15]}"`);
        console.log(`  P[16] 状态: "${row[16]}"`);
      }
      if (isShipinhao) {
        console.log(`  A[0] 店铺: "${row[0]}"`);
        console.log(`  B[1] 售后单号: "${row[1]}"`);
        console.log(`  J[9] 订单号: "${row[9]}"`);
        console.log(`  W[22] 退款金额: "${row[22]}"`);
        console.log(`  X[23] 状态: "${row[23]}"`);
      }
    }
  }
}
