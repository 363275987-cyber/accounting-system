// Web Worker: 在后台线程解析电商订单 Excel，避免主线程卡死。
// 主线程通过 excelWorkerClient.parseEcommerceExcelOffMain 调用它。

import * as XLSX from 'xlsx'
import { parseEcommerceExcel } from './ecommerceOrderImporter'

// ecommerceOrderImporter 内部用 XLSX.utils.sheet_to_json，但没显式 import，
// 历史上靠 xlsx UMD 注册到全局来工作。worker 里手动挂一下，保持兼容。
globalThis.XLSX = XLSX

self.onmessage = async (e) => {
  const { arrayBuffer, options } = e.data || {}
  try {
    self.postMessage({ phase: 'reading' })
    const workbook = XLSX.read(new Uint8Array(arrayBuffer), { type: 'array' })

    self.postMessage({ phase: 'parsing', sheets: workbook.SheetNames.length })
    const result = parseEcommerceExcel(workbook, options || {})

    self.postMessage({ phase: 'done', result })
  } catch (err) {
    self.postMessage({ phase: 'error', message: err?.message || String(err) })
  }
}
