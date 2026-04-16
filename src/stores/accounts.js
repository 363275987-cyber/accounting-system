import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useAccountStore = defineStore('accounts', {
  state: () => ({
    accounts: [],
    loading: false,
    _forceRefresh: false,
  }),
  actions: {
    async fetchAccounts() {
      // 数据缓存：已有数据且非强制刷新时跳过
      if (this.accounts.length > 0 && !this._forceRefresh) return
      this._forceRefresh = false
      this.loading = true
      try {
        const { data, error } = await withTimeout(
          supabase
            .from('accounts')
            .select('*')
            .neq('status', 'deleted')
            .order('ip_code')
            .order('sequence'),
          10000,
          '加载账户列表'
        )
        if (error) throw error
        this.accounts = data || []
      } catch (e) {
        console.error('Failed to fetch accounts:', e)
      } finally {
        this.loading = false
      }
    },

    async createAccount(payload) {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .insert(payload)
          .select()
          .single(),
        10000,
        '创建账户'
      )
      if (error) throw error
      this.accounts.push(data)
      return data
    },

    async updateAccount(id, updates) {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .update(updates)
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新账户'
      )
      if (error) throw error
      const idx = this.accounts.findIndex(a => a.id === id)
      if (idx >= 0) this.accounts[idx] = data
      return data
    },

    async updateSequence(id, newSequence) {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .update({ sequence: newSequence })
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新账户顺序'
      )
      if (error) throw error
      const idx = this.accounts.findIndex(a => a.id === id)
      if (idx >= 0) this.accounts[idx] = data
      // 重新排序
      this.accounts.sort((a, b) => (a.sequence || 0) - (b.sequence || 0))
      return data
    },

    async swapSequence(id1, id2) {
      const acc1 = this.accounts.find(a => a.id === id1)
      const acc2 = this.accounts.find(a => a.id === id2)
      if (!acc1 || !acc2) return
      const seq1 = acc1.sequence || 0
      const seq2 = acc2.sequence || 0
      try {
        const { error: e1 } = await withTimeout(
          supabase.from('accounts').update({ sequence: -999 }).eq('id', id1),
          10000,
          '交换账户顺序-1'
        )
        if (e1) throw e1
        const { error: e2 } = await withTimeout(
          supabase.from('accounts').update({ sequence: seq1 }).eq('id', id2),
          10000,
          '交换账户顺序-2'
        )
        if (e2) throw e2
        const { error: e3 } = await withTimeout(
          supabase.from('accounts').update({ sequence: seq2 }).eq('id', id1),
          10000,
          '交换账户顺序-3'
        )
        if (e3) throw e3
        acc1.sequence = seq2
        acc2.sequence = seq1
        this.accounts.sort((a, b) => (a.sequence || 0) - (b.sequence || 0))
      } catch (e) {
        // 排序失败，重新加载确保数据一致
        this._forceRefresh = true
        await this.fetchAccounts()
        throw e
      }
    },

    async deleteAccount(id) {
      // 检查所有可能引用该账户的表，任何一张有数据都不允许删除
      const relatedTables = [
        { table: 'orders',   label: '订单',   column: 'account_id' },
        { table: 'expenses', label: '支出',   column: 'account_id' },
        { table: 'refunds',  label: '退款',   column: 'account_id' },
      ]
      for (const { table, label, column } of relatedTables) {
        const { count, error } = await withTimeout(
          supabase
            .from(table)
            .select('*', { count: 'exact', head: true })
            .eq(column, id)
            .is('deleted_at', null),
          10000,
          `检查${label}关联`
        )
        // 表不存在时 Supabase 会返回错误，忽略即可（有些环境没开启相关模块）
        if (error) continue
        if (count && count > 0) {
          throw new Error(`该账户下有 ${count} 笔${label}，无法删除。请先处理关联数据。`)
        }
      }
      // transfers 表两边都可能引用
      const { count: trCount, error: trErr } = await withTimeout(
        supabase
          .from('account_transfers')
          .select('*', { count: 'exact', head: true })
          .is('deleted_at', null)
          .or(`from_account_id.eq.${id},to_account_id.eq.${id}`),
        10000,
        '检查转账关联'
      )
      if (!trErr && trCount && trCount > 0) {
        throw new Error(`该账户下有 ${trCount} 笔转账，无法删除。请先处理关联数据。`)
      }

      const { error } = await withTimeout(
        supabase.from('accounts').delete().eq('id', id),
        10000,
        '删除账户'
      )
      if (error) {
        if (error.message?.includes('foreign key')) {
          throw new Error('该账户有关联数据，无法删除')
        }
        throw error
      }
      this.accounts = this.accounts.filter(a => a.id !== id)
    },

    // 获取活跃账户列表（用于下拉选择）
    getActiveAccounts() {
      return this.accounts.filter(a => a.status === 'active')
    },

    // 更新账户余额（原子操作）
    // amountDelta > 0 增加，< 0 减少
    async updateBalance(accountId, amountDelta, reason = '订单余额变动', refType = 'order', refId = null) {
      const { data, error } = await withTimeout(
        supabase.rpc('increment_balance', {
          p_account_id: accountId,
          p_delta: amountDelta,
          p_reason: reason,
          p_ref_type: refType,
          p_ref_id: refId,
        }),
        10000,
        '更新账户余额'
      )
      if (error) throw error
      // data 现在是 {old_balance, new_balance}
      const newBal = data?.new_balance ?? (typeof data === 'number' ? data : null)
      if (newBal == null) {
        // RPC 没返回新余额，直接从库里拉一次兜底，避免本地缓存错位
        await this.refreshBalance(accountId)
      } else {
        const idx = this.accounts.findIndex(a => a.id === accountId)
        if (idx >= 0) this.accounts[idx].balance = Number(newBal)
      }
      return data
    },

    // 从 Supabase 重新加载余额（同步真实数据）
    async refreshBalance(accountId) {
      const { data, error } = await withTimeout(
        supabase
          .from('accounts')
          .select('balance')
          .eq('id', accountId)
          .single(),
        10000,
        '刷新账户余额'
      )
      if (error) throw error
      const idx = this.accounts.findIndex(a => a.id === accountId)
      if (idx >= 0) this.accounts[idx].balance = data.balance
      return data.balance
    },

    // 按 IP 分组
    getGroupedByIP() {
      const groups = {}
      for (const acc of this.getActiveAccounts()) {
        if (!groups[acc.ip_code]) groups[acc.ip_code] = []
        groups[acc.ip_code].push(acc)
      }
      return groups
    },
  },
})
