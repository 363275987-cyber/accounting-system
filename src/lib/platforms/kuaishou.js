import { BasePlatform } from './base.js';

/**
 * 快手开放平台 API 对接
 * 文档: https://open.kuaishou.com/
 *
 * 授权流程：
 * 1. 开发者在快手开放平台创建应用
 * 2. 通过 OAuth2.0 授权获取 access_token
 * 3. 调用业务接口
 */
export class KuaishouPlatform extends BasePlatform {
  constructor(credentials) {
    super(credentials);
  }

  get apiBase() {
    return 'https://open.kuaishou.com';
  }

  /**
   * 获取订单列表
   * 接口: POST /openapi/order/list
   */
  async fetchOrders({ startTime, endTime, page = 1, pageSize = 20 }) {
    if (!this.credentials.access_token) {
      console.warn('[KuaishouPlatform] No access_token, returning mock empty');
      return { orders: [], hasMore: false };
    }

    // TODO: 实现实际API调用
    // const resp = await fetch(`${this.apiBase}/openapi/order/list`, {
    //   method: 'POST',
    //   headers: {
    //     'Content-Type': 'application/json',
    //     'Authorization': `Bearer ${this.credentials.access_token}`,
    //     'access-token': this.credentials.access_token,
    //   },
    //   body: JSON.stringify({
    //     begin_time: startTime,
    //     end_time: endTime,
    //     page,
    //     page_size: pageSize,
    //   }),
    // });

    console.log('[KuaishouPlatform] fetchOrders called (framework mode, no actual API call)');
    return { orders: [], hasMore: false };
  }

  /**
   * 刷新 access_token
   */
  async refreshToken() {
    if (!this.credentials.refresh_token) {
      return { success: false, message: '没有 refresh_token' };
    }

    // TODO: 实现实际API调用
    console.log('[KuaishouPlatform] refreshToken called (framework mode)');
    return { success: false, message: '框架模式，未实现实际刷新' };
  }

  /**
   * 测试连接
   */
  async testConnection() {
    if (!this.credentials.app_id || !this.credentials.app_secret) {
      return { success: false, message: '请先填写 App ID 和 App Secret' };
    }

    console.log('[KuaishouPlatform] testConnection (framework mode)');
    return { success: true, message: '连接成功（框架模式）' };
  }

  /**
   * 转换快手订单数据为统一格式
   */
  _transformOrder(item) {
    return {
      external_order_id: item.order_id || item.order_sn,
      shop_name: this.credentials.shop_name || item.shop_name,
      order_status: this._mapStatus(item.order_status),
      customer_name: item.receiver_name,
      customer_phone: item.receiver_phone,
      customer_address: [item.receiver_state, item.receiver_city, item.receiver_district, item.receiver_address].filter(Boolean).join(' '),
      product_name: (item.item_list || []).map(p => p.item_name).join(', '),
      product_image: (item.item_list || [])[0]?.thumb_url || null,
      sku_info: (item.item_list || []).map(p => p.sku_name || p.spec_json).join(', '),
      amount: item.order_amount || item.pay_amount || 0,
      freight: item.freight_amount || 0,
      payment_method: item.pay_type || null,
      order_time: item.created_at || null,
      pay_time: item.pay_time || null,
      remark: item.buyer_remark || null,
    };
  }

  _mapStatus(status) {
    const map = {
      10: 'pending',
      20: 'paid',
      30: 'shipped',
      40: 'completed',
      50: 'cancelled',
      60: 'refunded',
    };
    return map[status] || 'pending';
  }
}
