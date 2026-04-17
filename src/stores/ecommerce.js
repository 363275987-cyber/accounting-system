import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useEcommerceStore = defineStore('ecommerce', {
  state: () => ({
    stores: [],           // 电商店铺列表
    dailyStats: [],       // 日统计数据
    withdrawals: [],      // 提现记录
    loading: false,
    selectedDate: new Date().toISOString().split('T')[0], // 默认今天
  }),

  getters: {
    // 按平台分组
    storesByPlatform: (state) => {
      const groups = {}
      state.stores.forEach(s => {
        const key = s.ecommerce_platform || 'other'
        if (!groups[key]) groups[key] = []
        groups[key].push(s)
      })
      return groups
    },

    // 当日统计
    todayStats(state) {
      const date = state.selectedDate
      const dayStats = state.dailyStats.filter(d => d.order_date === date)
      return {
        total_orders: dayStats.reduce((sum, d) => sum + Number(d.order_count || 0), 0),
        total_sales: dayStats.reduce((sum, d) => sum + Number(d.sales_amount || 0), 0),
        total_refund: dayStats.reduce((sum, d) => sum + Number(d.refund_amount || 0), 0),
        total_net: dayStats.reduce((sum, d) => sum + Number(d.net_income || 0), 0),
      }
    },

    // 总可提现金额（所有店铺）
    totalWithdrawable(state) {
      return state.stores.reduce((sum, s) => sum + Number(s.withdrawable_amount || 0), 0)
    },
  },

  actions: {
    // 加载电商店铺列表
    async loadStores() {
      this.loading = true
      try {
        const { data, error } = await withTimeout(
          supabase
            .from('accounts')
            .select('id, short_name, platform, ecommerce_platform, settlement_days, balance, withdrawal_account_id, status')
            .eq('status', 'active')
            .not('ecommerce_platform', 'is', null)
            .order('ecommerce_platform'),
          10000,
          '加载电商店铺'
        )

        if (error) throw error

        // 获取每个店铺的可提现金额
        const storesWithdrawable = []
        for (const store of (data || [])) {
          try {
            const { data: wd, error: wdErr } = await withTimeout(
              supabase.rpc('get_withdrawable_amount', { p_account_id: store.id }),
              10000,
              '查询可提现金额'
            )
            storesWithdrawable.push({
              ...store,
              withdrawable_amount: wdErr ? 0 : Number(wd || 0),
            })
          } catch {
            storesWithdrawable.push({ ...store, withdrawable_amount: 0 })
          }
        }
        this.stores = storesWithdrawable
      } catch (e) {
        console.error('加载电商店铺失败:', e)
      } finally {
        this.loading = false
      }
    },

    // 加载日统计数据
    async loadDailyStats(dateRange) {
      try {
        const [startDate, endDate] = dateRange || [this.selectedDate, this.selectedDate]
        const { data, error } = await withTimeout(
          supabase
            .from('v_ecommerce_daily')
            .select('*')
            .gte('order_date', startDate)
            .lte('order_date', endDate)
            .order('order_date', { ascending: false }),
          10000,
          '加载电商日统计'
        )

        if (error) throw error
        this.dailyStats = data || []
      } catch (e) {
        console.error('加载日统计失败:', e)
      }
    },

    // 加载提现记录
    async loadWithdrawals(accountId) {
      try {
        let query = supabase
          .from('withdrawals')
          .select('*, from_store:accounts!withdrawals_account_id_fkey(id, short_name, ecommerce_platform), to_account:accounts!withdrawals_to_account_id_fkey(id, short_name)')
          .is('deleted_at', null)
          .order('created_at', { ascending: false })
          .limit(100)

        if (accountId) {
          query = query.eq('account_id', accountId)
        }

        const { data, error } = await withTimeout(query, 10000, '加载提现记录')
        if (error) throw error
        this.withdrawals = data || []
      } catch (e) {
        console.error('加载提现记录失败:', e)
      }
    },

    // 执行提现
    async executeWithdrawal(accountId, toAccountId, amount, feeDetail, remark) {
      try {
        const { data, error } = await withTimeout(
          supabase.rpc('execute_withdrawal', {
            p_account_id: accountId,
            p_to_account_id: toAccountId,
            p_amount: amount,
            p_fee_detail: feeDetail,
            p_remark: remark,
          }),
          15000,
          '执行提现'
        )

        if (error) throw error
        return data
      } catch (e) {
        console.error('提现失败:', e)
        throw e
      }
    },

    // 新建电商店铺
    async createStore(storeData) {
      // platform CHECK 只允许: alipay / bank / douyin / kuaishou / weixin_video / youzan / other
      const mapPlatform = (ecom) => {
        switch (ecom) {
          case 'douyin':    return 'douyin'
          case 'kuaishou':  return 'kuaishou'
          case 'shipinhao': return 'weixin_video'
          case 'youzan':    return 'youzan'
          default:          return 'other'
        }
      }
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .insert({
            short_name: storeData.name,
            code: storeData.name,
            owner_code: (storeData.owner_code || '').trim() || '—',
            platform: mapPlatform(storeData.ecommerce_platform),
            ecommerce_platform: storeData.ecommerce_platform,
            category: 'ecommerce',
            settlement_days: storeData.settlement_days,
            balance: 0,
            opening_balance: 0,
            withdrawal_account_id: storeData.withdrawal_account_id || null,
            status: 'active',
            balance_method: 'manual',  // 新建电商店铺默认手工维护余额；订单导入只计入运营数据，不累加 balance
          })
          .select()
          .single(),
        10000,
        '创建电商店铺'
      )

      if (error) throw error
      return data
    },

    // 更新店铺绑定
    async updateStore(accountId, updates) {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .update(updates)
          .eq('id', accountId)
          .select()
          .single(),
        10000,
        '更新店铺绑定'
      )

      if (error) throw error
      return data
    },

    // 获取现金账户列表（用于绑定提现到账账户）
    async loadCashAccounts() {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .select('id, short_name, platform, balance')
          .is('ecommerce_platform', null)
          .eq('status', 'active')
          .order('short_name'),
        10000,
        '加载现金账户'
      )

      if (error) throw error
      return data || []
    },
  },
})
