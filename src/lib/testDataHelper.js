/**
 * 随机测试数据生成工具
 * 用于快速填充测试数据，所有数据带 note='测试数据' 标记
 */

export const SURNAMES = ['张', '李', '王', '赵', '刘', '陈', '杨', '黄', '周', '吴', '徐', '孙', '马', '胡', '朱', '高', '林', '何', '郭', '罗']
export const GIVEN_NAMES = ['伟', '芳', '娜', '强', '磊', '洋', '勇', '艳', '杰', '军', '明', '超', '秀英', '丽', '志强', '小红', '小美', '建华', '国强', '海涛']
export const CITIES = ['北京市', '上海市', '广州市', '深圳市', '杭州市', '成都市', '武汉市', '南京市', '重庆市', '西安市', '长沙市', '苏州市']
export const DISTRICTS = ['朝阳区', '海淀区', '浦东新区', '天河区', '南山区', '武侯区', '江汉区', '鼓楼区']
export const ADDRESSES = ['中山路88号', '建设大道123号', '人民路56号', '解放路200号', '光谷大道78号', '天府三街99号']
export const PAYEES = ['顺丰速运', '德邦物流', '中通快递', '圆通速递', '韵达快递', '极兔速递', '京东物流', '跨越速运', '万邦物流', '安能物流', '百世快递', '申通快递']
export const REFUND_REASONS = ['客户退货', '质量问题', '发错货', '客户取消', '尺寸不合适', '颜色不符', '七天无理由', '协商退款', '少件漏发', '商品损坏']

export const PRODUCT_CATEGORIES_LIST = ['cue', 'accessory', 'recording_course', 'offline_camp', 'other']
export const PRODUCT_NAMES_BY_CATEGORY = {
  '球杆': ['LK皮尔力·破冰者', 'DBA黑金刚', '来力·逐梦者', '荆龙·霸王枪', '国熙·大师级', '皮尔力·明一', 'DBA·疾风', '来力·锋芒', '荆龙·幻影', '皮尔力·赤兔'],
  '皮头': ['蓝钻皮头', '毒药皮头', '犀牛皮头', '茗芯皮头', '魔术师皮头', '黑科技皮头', '猛禽皮头', '虎牌皮头'],
  '巧克粉': ['大师巧粉', '猛禽巧粉', '皮尔力巧粉', '蓝宝石巧粉', '绿水鬼巧粉', '黑玛瑙巧粉'],
  '杆盒': ['铝合金杆盒', '碳纤维杆盒', '皮质杆盒', '实木杆盒', '折叠杆盒', '双节杆盒'],
  '手套': ['台球手套L', '台球手套M', '台球手套S', '防滑手套', '透气手套', '专业比赛手套'],
  '配件': ['球杆接口', '加长把', '皮头胶水', '皮头修磨器', '球杆油', '防滑粉', '擦粉布'],
  '球台': ['台球桌9尺', '台球桌8尺', '台球桌7尺', '折叠球台', '中式八球台'],
  '保养套装': ['球杆保养套装', '皮头更换套装', '球台清洁套装', '全套工具套装', '新手入门套装'],
}

export function randomPick(arr) {
  return arr[Math.floor(Math.random() * arr.length)]
}

export function randomPhone() {
  return '1' + randomPick(['3', '5', '7', '8', '9']) + String(Math.floor(Math.random() * 1e9)).padStart(9, '0')
}

export function randomName() {
  return randomPick(SURNAMES) + randomPick(GIVEN_NAMES)
}

export function randomAddress() {
  return randomPick(CITIES) + randomPick(DISTRICTS) + randomPick(ADDRESSES)
}

export function randomAmount(min, max) {
  // Generate amounts that look realistic (often round numbers)
  const patterns = [1, 10, 50, 100, 500]
  const multiplier = randomPick(patterns)
  return Math.round((min + Math.random() * (max - min)) / multiplier) * multiplier || min
}

export function randomDate(daysAgo = 30) {
  const now = new Date()
  const past = new Date(now.getTime() - Math.random() * daysAgo * 86400000)
  return past.toISOString().split('T')[0]
}

export function todayDate() {
  return new Date().toISOString().split('T')[0]
}
