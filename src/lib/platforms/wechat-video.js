import { BasePlatform } from './base.js';

/**
 * 微信视频号/小程序店铺 API 对接
 * 文档: https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/business-capabilities/order-shipping/order-list.html
 *
 * 授权流程：
 * 1. 在微信开放平台/小程序后台配置服务器域名
 * 2. 通过 component_access_token / authorizer_access_token 授权
 * 3. 调用小程序订单管理接口
 */
export class WechatVideoPlatform extends BasePlatform {
  constructor(credentials) {
    super(credentials);
  }

  get apiBase() {
    return 'https://api.weixin.qq.com';
  }

  /**
   * 获取订单列表
   * 接口: POST /wxa/sec/order/get_order_list
   */
  async fetchOrders({ startTime, endTime, page = 1, pageSize = 20 }) {
    if (!this.credentials.access_token) {
      console.warn('[WechatVideoPlatform] No access_token, returning mock empty');
      return { orders: [], hasMore: false };
    }

    // TODO: 实现实际API调用
    // 微信接口需要用 POST 并带 access_token
    // const url = `${this.apiBase}/wxa/sec/order/get_order_list?access_token=${this.credentials.access_token}`;
    // const resp = await fetch(url, {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({
    //     start_time: Math.floor(new Date(startTime).getTime() / 1000),
    //     end_time: Math.floor(new Date(endTime).getTime() / 1000),
    //     page,
    //     page_size: pageSize,
    //   }),
    // });

    console.log('[WechatVideoPlatform] fetchOrders called (framework mode, no actual API call)');
    return { orders: [], hasMore: false };
  }

  /**
   * 刷新 access_token
   * 微信的 access_token 有效期 2 小时，需要用 refresh_token 刷新
   */
  async refreshToken() {
    if (!this.credentials.app_id || !this.credentials.app_secret) {
      return { success: false, message: '缺少 App ID 或 App Secret' };
    }

    // 微信获取 access_token 接口
    // GET /cgi-bin/token?grant_type=client_credential&appid={appid}&secret={secret}
    // TODO: 实现实际调用
    console.log('[WechatVideoPlatform] refreshToken called (framework mode)');
    return { success: false, message: '框架模式，未实现实际刷新' };
  }

  /**
   * 测试连接 — 验证 AppID + AppSecret 是否能获取 access_token
   */
  async testConnection() {
    if (!this.credentials.app_id || !this.credentials.app_secret) {
      return { success: false, message: '请先填写 App ID 和 App Secret' };
    }

    console.log('[WechatVideoPlatform] testConnection (framework mode)');
    return { success: true, message: '连接成功（框架模式）' };
  }

  /**
   * 转换微信订单数据为统一格式
   */
  _transformOrder(item) {
    return {
      external_order_id: item.order_id || item.out_trade_no,
      shop_name: this.credentials.shop_name || item.brand_name,
      order_status: this._mapStatus(item.order_status),
      customer_name: item.shipping_name,
      customer_phone: item.shipping_tel_number,
      customer_address: [item.shipping_province, item.shipping_city, item.shipping_district, item.shipping_address].filter(Boolean).join(' '),
      product_name: (item.product_info || []).map(p => p.product_name).join(', '),
      product_image: (item.product_info || [])[0]?.thumb_url || null,
      sku_info: (item.product_info || []).map(p => p.sku_str).join(', '),
      amount: item.order_price || item.pay_amount || 0,
      freight: item.freight_fee || 0,
      payment_method: item.pay_method || null,
      order_time: item.create_time ? new Date(item.create_time * 1000).toISOString() : null,
      pay_time: item.pay_time ? new Date(item.pay_time * 1000).toISOString() : null,
      remark: item.buyer_remark || null,
    };
  }

  _mapStatus(status) {
    const map = {
      10: 'pending',
      20: 'paid',
      30: 'shipped',
      100: 'completed',
      200: 'cancelled',
      250: 'refunded',
    };
    return map[status] || 'pending';
  }
}
