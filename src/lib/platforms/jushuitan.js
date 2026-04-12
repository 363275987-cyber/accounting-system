import { BasePlatform } from './base.js';

/**
 * 聚水潭 ERP API 对接
 * 文档: https://open.jushuitan.com/
 *
 * 聚水潭是ERP系统，主要用于订单管理和发货。
 * 授权流程：
 * 1. 在聚水潭开放平台注册开发者账号
 * 2. 创建应用获取 app_key + app_secret
 * 3. 通过 OAuth 获取授权 token
 * 4. 调用业务接口（基于 HTTPS + 签名）
 */
export class JushuitanPlatform extends BasePlatform {
  constructor(credentials) {
    super(credentials);
  }

  get apiBase() {
    return this.credentials.extra_config?.api_base || 'https://openapi.jushuitan.com';
  }

  /**
   * 聚水潭 API 签名生成
   * 签名规则: MD5(app_key + app_secret + timestamp)
   */
  _generateSign(timestamp) {
    const { app_id, app_secret } = this.credentials;
    const str = `${app_id}${app_secret}${timestamp}`;
    // TODO: 实际需要引入 MD5 库
    // 简单的签名占位
    return str;
  }

  /**
   * 获取订单列表
   * 接口: POST /open/orders/query
   */
  async fetchOrders({ startTime, endTime, page = 1, pageSize = 20 }) {
    if (!this.credentials.access_token) {
      console.warn('[JushuitanPlatform] No access_token, returning mock empty');
      return { orders: [], hasMore: false };
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const sign = this._generateSign(timestamp);

    // TODO: 实现实际API调用
    // const resp = await fetch(`${this.apiBase}/open/orders/query`, {
    //   method: 'POST',
    //   headers: {
    //     'Content-Type': 'application/json',
    //     'Authorization': `Bearer ${this.credentials.access_token}`,
    //   },
    //   body: JSON.stringify({
    //     app_key: this.credentials.app_id,
    //     timestamp,
    //     sign,
    //     page_index: page,
    //     page_size: pageSize,
    //     date_b: startTime,
    //     date_e: endTime,
    //   }),
    // });

    console.log('[JushuitanPlatform] fetchOrders called (framework mode, no actual API call)');
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
    console.log('[JushuitanPlatform] refreshToken called (framework mode)');
    return { success: false, message: '框架模式，未实现实际刷新' };
  }

  /**
   * 测试连接
   */
  async testConnection() {
    if (!this.credentials.app_id || !this.credentials.app_secret) {
      return { success: false, message: '请先填写 App ID 和 App Secret' };
    }

    console.log('[JushuitanPlatform] testConnection (framework mode)');
    return { success: true, message: '连接成功（框架模式）' };
  }

  /**
   * 转换聚水潭订单数据为统一格式
   */
  _transformOrder(item) {
    return {
      external_order_id: item.oi_id || item.so_id,
      shop_name: this.credentials.shop_name || item.shop_name,
      order_status: this._mapStatus(item.order_status || item.status),
      customer_name: item.receiver_name,
      customer_phone: item.receiver_mobile,
      customer_address: [item.receiver_state, item.receiver_city, item.receiver_district, item.receiver_address].filter(Boolean).join(' '),
      product_name: (item.items || []).map(p => p.name).join(', '),
      product_image: (item.items || [])[0]?.img || null,
      sku_info: (item.items || []).map(p => p.sku_name || p.properties_value).join(', '),
      amount: item.amount || item.payment || 0,
      freight: item.post_fee || item.freight || 0,
      payment_method: item.payment_method || null,
      order_time: item.created || null,
      pay_time: item.pay_date || null,
      remark: item.remark || item.buyer_remark || null,
    };
  }

  _mapStatus(status) {
    const map = {
      10: 'pending',
      20: 'paid',
      30: 'shipped',
      50: 'completed',
      60: 'cancelled',
      70: 'refunded',
    };
    return map[status] || 'pending';
  }
}
