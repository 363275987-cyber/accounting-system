import { DouyinPlatform } from './douyin.js';
import { KuaishouPlatform } from './kuaishou.js';
import { WechatVideoPlatform } from './wechat-video.js';
import { JushuitanPlatform } from './jushuitan.js';

/**
 * 平台配置常量
 */
export const PLATFORM_CONFIG = {
  douyin: {
    key: 'douyin',
    name: '抖店',
    icon: '🎵',
    color: 'from-gray-800 to-gray-900',
    bgColor: 'bg-gray-900',
    lightBg: 'bg-gray-50',
    borderColor: 'border-gray-200',
    apiDoc: 'https://op.jinritemai.com/',
    description: '抖音电商开放平台',
    requiredFields: ['app_id', 'app_secret'],
    optionalFields: ['shop_id'],
  },
  kuaishou: {
    key: 'kuaishou',
    name: '快手',
    icon: '📹',
    color: 'from-orange-500 to-orange-600',
    bgColor: 'bg-orange-500',
    lightBg: 'bg-orange-50',
    borderColor: 'border-orange-200',
    apiDoc: 'https://open.kuaishou.com/',
    description: '快手电商开放平台',
    requiredFields: ['app_id', 'app_secret'],
    optionalFields: ['shop_id'],
  },
  wechat_video: {
    key: 'wechat_video',
    name: '视频号',
    icon: '💬',
    color: 'from-green-500 to-green-600',
    bgColor: 'bg-green-500',
    lightBg: 'bg-green-50',
    borderColor: 'border-green-200',
    apiDoc: 'https://open.weixin.qq.com/',
    description: '微信视频号/小程序店铺',
    requiredFields: ['app_id', 'app_secret'],
    optionalFields: [],
  },
  jushuitan: {
    key: 'jushuitan',
    name: '聚水潭',
    icon: '🌊',
    color: 'from-blue-500 to-blue-600',
    bgColor: 'bg-blue-500',
    lightBg: 'bg-blue-50',
    borderColor: 'border-blue-200',
    apiDoc: 'https://open.jushuitan.com/',
    description: '聚水潭 ERP 系统',
    requiredFields: ['app_id', 'app_secret'],
    optionalFields: ['shop_id'],
  },
};

/**
 * 获取所有平台的 key 列表
 */
export const PLATFORM_KEYS = Object.keys(PLATFORM_CONFIG);

/**
 * 根据凭证创建对应的平台实例
 * @param {object} credentials - 凭证记录
 * @returns {BasePlatform}
 */
export function createPlatform(credentials) {
  switch (credentials.platform) {
    case 'douyin':
      return new DouyinPlatform(credentials);
    case 'kuaishou':
      return new KuaishouPlatform(credentials);
    case 'wechat_video':
      return new WechatVideoPlatform(credentials);
    case 'jushuitan':
      return new JushuitanPlatform(credentials);
    default:
      throw new Error(`Unknown platform: ${credentials.platform}`);
  }
}
