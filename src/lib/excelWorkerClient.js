// 主线程调用 Excel 解析 Web Worker 的封装。
// 优点：解析期间不卡 UI，可以实时报进度。
//
// 用法:
//   const { salesOrders, afterSalesOrders, skipped, errors } =
//     await parseEcommerceExcelOffMain(file, options, onProgress)
//
// onProgress({ phase, sheets? }) 事件：
//   phase: 'reading'  | 'parsing' | 'done' | 'error'

export async function parseEcommerceExcelOffMain(file, options = {}, onProgress) {
  const arrayBuffer = await file.arrayBuffer()

  return new Promise((resolve, reject) => {
    const worker = new Worker(
      new URL('./excelParseWorker.js', import.meta.url),
      { type: 'module' }
    )

    const cleanup = () => {
      try { worker.terminate() } catch {}
    }

    worker.onmessage = (e) => {
      const { phase, result, message, sheets } = e.data || {}
      if (phase === 'done') {
        cleanup()
        resolve(result)
      } else if (phase === 'error') {
        cleanup()
        reject(new Error(message || 'Worker 解析失败'))
      } else if (onProgress) {
        onProgress({ phase, sheets })
      }
    }

    worker.onerror = (e) => {
      cleanup()
      reject(new Error(e?.message || 'Worker 运行异常'))
    }

    // 用 transferable 传 arrayBuffer，避免结构化克隆开销（对大文件明显）
    worker.postMessage({ arrayBuffer, options }, [arrayBuffer])
  })
}
