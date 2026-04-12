// 平台对接基础类
export class BasePlatform {
  constructor(credentials) {
    this.credentials = credentials;
    this.platform = credentials.platform;
  }

  // 子类必须实现的方法
  async fetchOrders(params) {
    throw new Error(`${this.platform}: fetchOrders not implemented`);
  }

  async refreshToken() {
    throw new Error(`${this.platform}: refreshToken not implemented`);
  }

  async testConnection() {
    throw new Error(`${this.platform}: testConnection not implemented`);
  }

  /**
   * 记录同步日志到 platform_sync_logs 表
   * @param {object} supabase - Supabase client
   * @param {string} action - 'fetch_orders' | 'sync_order' | 'refresh_token'
   * @param {string} status - 'success' | 'failed' | 'partial'
   * @param {number} records - 影响记录数
   * @param {string|null} error - 错误信息
   * @param {number} duration - 耗时(ms)
   */
  async logSync(supabase, action, status, records = 0, error = null, duration = 0) {
    try {
      await supabase.from('platform_sync_logs').insert({
        platform: this.platform,
        action,
        status,
        records_affected: records,
        error_message: error,
        duration_ms: duration,
      });
    } catch (e) {
      console.error('[BasePlatform] Failed to write sync log:', e);
    }
  }

  /**
   * 通用订单同步逻辑
   * 1. 调用 fetchOrders 获取外部订单
   * 2. 对比 platform_orders 表，upsert 新增/更新
   * 3. 返回同步结果
   */
  async syncOrders(supabase, params = {}) {
    const startTime = Date.now();
    try {
      const result = await this.fetchOrders(params);
      const orders = result.orders || [];

      if (orders.length === 0) {
        await this.logSync(supabase, 'fetch_orders', 'success', 0, null, Date.now() - startTime);
        return { synced: 0, total: 0, message: '没有新订单' };
      }

      // 构造 upsert 数据
      const rows = orders.map(order => ({
        platform: this.platform,
        external_order_id: order.external_order_id || order.order_id,
        shop_name: this.credentials.shop_name || order.shop_name,
        order_status: order.order_status || 'pending',
        customer_name: order.customer_name || null,
        customer_phone: order.customer_phone || null,
        customer_address: order.customer_address || null,
        product_name: order.product_name || null,
        product_image: order.product_image || null,
        sku_info: order.sku_info || null,
        amount: Number(order.amount) || 0,
        freight: Number(order.freight) || 0,
        payment_method: order.payment_method || null,
        order_time: order.order_time || null,
        pay_time: order.pay_time || null,
        remark: order.remark || null,
        sync_status: 'synced',
        raw_data: order,
      }));

      const { error } = await supabase
        .from('platform_orders')
        .upsert(rows, { onConflict: 'platform,external_order_id' });

      if (error) throw error;

      // 更新凭证的最后同步时间
      await supabase
        .from('platform_credentials')
        .update({ last_sync_at: new Date().toISOString(), last_error: null })
        .eq('platform', this.platform);

      await this.logSync(supabase, 'sync_order', 'success', rows.length, null, Date.now() - startTime);
      return { synced: rows.length, total: result.hasMore ? rows.length + '+' : rows.length, message: `同步完成，共 ${rows.length} 条订单` };
    } catch (e) {
      await this.logSync(supabase, 'sync_order', 'failed', 0, e.message, Date.now() - startTime);

      // 更新凭证的错误状态
      await supabase
        .from('platform_credentials')
        .update({ last_error: e.message, status: 'error' })
        .eq('platform', this.platform);

      return { synced: 0, total: 0, message: '同步失败: ' + e.message };
    }
  }
}
