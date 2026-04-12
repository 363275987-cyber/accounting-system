import { BasePlatform } from './base.js';

/**
 * 抖店开放平台 API 对接
 * 文档: https://op.jinritemai.com/docs/guide-doc/new/69/76
 *
 * 授权流程：
 * 1. 商家在抖店开放平台创建应用，获取 app_key + app_secret
 * 2. 通过 OAuth 获取 access_token（需要店铺授权）
 * 3. 使用 access_token 调用业务接口
 */
export class DouyinPlatform extends BasePlatform {
  constructor(credentials) {
    super(credentials);
  }

  get apiBase() {
    return 'https://openapi-fxg.jinritemai.com';
  }

  get methodPrefix() {
    return '/order';
  }

  /**
   * 获取订单列表
   * @param {object} params
   * @param {string} params.startTime - 开始时间 (ISO string)
   * @param {string} params.endTime - 结束时间 (ISO string)
   * @param {number} params.page - 页码 (默认1)
   * @param {number} params.pageSize - 每页数量 (默认20)
   * @returns {Promise<{orders: Array, hasMore: boolean}>}
   */
  async fetchOrders({ startTime, endTime, page = 1, pageSize = 20 }) {
    if (!this.credentials.access_token) {
      console.warn('[DouyinPlatform] No access_token, returning mock empty');
      return { orders: [], hasMore: false };
    }

    // TODO: 实现实际API调用
    // 接口: POST {apiBase}/order/list
    // Headers: access-token: {access_token}
    // Body: { start_time, end_time, page, size }
    //
    // const resp = await fetch(`${this.apiBase}/order/list`, {
    //   method: 'POST',
    //   headers: {
    //     'Content-Type': 'application/json',
    //     'access-token': this.credentials.access_token,
    //   },
    //   body: JSON.stringify({
    //     start_time: startTime,
    //     end_time: endTime,
    //     page,
    //     size: pageSize,
    //   }),
    // });
    // const data = await resp.json();
    // // 转换为统一格式
    // return {
    //   orders: (data.data?.list || []).map(item => this._transformOrder(item)),
    //   hasMore: data.data?.has_more || false,
    // };

    console.log('[DouyinPlatform] fetchOrders called (framework mode, no actual API call)');
    return { orders: [], hasMore: false };
  }

  /**
   * 刷新 access_token
   * 接口: POST /oauth/token/refresh
   */
  async refreshToken() {
    if (!this.credentials.refresh_token) {
      return { success: false, message: '没有 refresh_token' };
    }

    // TODO: 实现实际API调用
    // const resp = await fetch(`${this.apiBase}/oauth/token/refresh`, {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({
    //     app_key: this.credentials.app_id,
    //     app_secret: this.credentials.app_secret,
    //     refresh_token: this.credentials.refresh_token,
    //     grant_type: 'refresh_token',
    //   }),
    // });

    console.log('[DouyinPlatform] refreshToken called (framework mode)');
    return { success: false, message: '框架模式，未实现实际刷新' };
  }

  /**
   * 测试连接 — 验证 app_id 和 app_secret 是否有效
   */
  async testConnection() {
    if (!this.credentials.app_id || !this.credentials.app_secret) {
      return { success: false, message: '请先填写 App ID 和 App Secret' };
    }

    // 框架模式：mock 成功
    // TODO: 接入实际API后替换为真实验证
    console.log('[DouyinPlatform] testConnection (framework mode)');
    return { success: true, message: '连接成功（框架模式）' };
  }

  /**
   * 将抖店API返回的订单数据转换为统一格式
   */
  _transformOrder(item) {
    return {
      external_order_id: item.order_id,
      shop_name: item.shop_name,
      order_status: this._mapStatus(item.order_status),
      customer_name: item.receiver_name,
      customer_phone: item.receiver_phone,
      customer_address: [item.receiver_province, item.receiver_city, item.receiver_district, item.receiver_address].filter(Boolean).join(' '),
      product_name: (item.product_list || []).map(p => p.product_name).join(', '),
      product_image: (item.product_list || [])[0]?.product_img_url || null,
      sku_info: (item.product_list || []).map(p => p.sku_name).join(', '),
      amount: item.pay_amount || item.order_amount || 0,
      freight: item.post_fee || 0,
      payment_method: item.pay_type_desc || null,
      order_time: item.create_time ? new Date(Number(item.create_time) * 1000).toISOString() : null,
      pay_time: item.pay_time ? new Date(Number(item.pay_time) * 1000).toISOString() : null,
      remark: item.buyer_remark || null,
    };
  }

  _mapStatus(status) {
    const map = {
      0: 'pending',    // 待支付
      2: 'paid',       // 已支付待发货
      3: 'shipped',    // 已发货
      4: 'completed',  // 已完成
      5: 'cancelled',  // 已取消
      7: 'refunded',   // 退款中/已退款
    };
    return map[status] || 'pending';
  }
}
