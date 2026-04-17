// 懒加载 xlsx 模块——它 421KB,避免主 bundle 拖慢首屏
let _xlsx = null
export async function loadXLSX() {
  if (!_xlsx) {
    _xlsx = await import('xlsx')
  }
  return _xlsx
}
