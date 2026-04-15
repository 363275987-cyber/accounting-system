import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useShareholderLoanStore = defineStore('shareholderLoans', {
  state: () => ({
    loans: [],
    loanDetail: null,
    repayments: [],
    loading: false,
    pagination: { total: 0, page: 1, pageSize: 20 },
  }),

  actions: {
    // 获取垫资列表（使用汇总视图）
    async fetchLoans({ page = 1, pageSize = 20 } = {}) {
      this.loading = true
      try {
        const { data, error, count } = await withTimeout(
          supabase
            .from('shareholder_loan_summary')
            .select('*', { count: 'exact' })
            .range((page - 1) * pageSize, page * pageSize - 1),
          10000,
          '加载垫资列表'
        )

        if (error) throw error
        this.loans = data || []
        this.pagination = { total: count || 0, page, pageSize }
      } catch (e) {
        console.error('Failed to fetch loans:', e)
        throw e
      } finally {
        this.loading = false
      }
    },

    // 获取单条垫资详情
    async fetchLoanDetail(id) {
      const { data, error } = await withTimeout(
        supabase
          .from('shareholder_loan_summary')
          .select('*')
          .eq('id', id)
          .single(),
        10000,
        '加载垫资详情'
      )
      if (error) throw error
      this.loanDetail = data
      return data
    },

    // 创建垫资
    async createLoan(payload) {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user?.id) throw new Error('未登录，无法创建垫资')
      const { data, error } = await withTimeout(
        supabase
          .from('shareholder_loans')
          .insert({
            ...payload,
            created_by: session.user.id,
          })
          .select()
          .single(),
        10000,
        '创建垫资'
      )
      if (error) throw error
      return data
    },

    // 更新垫资
    async updateLoan(id, updates) {
      const { data, error } = await withTimeout(
        supabase
          .from('shareholder_loans')
          .update({ ...updates, updated_at: new Date().toISOString() })
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新垫资'
      )
      if (error) throw error
      return data
    },

    // 获取还款记录
    async fetchRepayments(loanId) {
      const { data, error } = await withTimeout(
        supabase
          .from('loan_repayments')
          .select('*')
          .eq('loan_id', loanId)
          .order('repayment_date', { ascending: false }),
        10000,
        '加载还款记录'
      )
      if (error) throw error
      this.repayments = data || []
      return data
    },

    // 创建还款记录
    async createRepayment(payload) {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user?.id) throw new Error('未登录，无法创建还款')
      const { data, error } = await withTimeout(
        supabase
          .from('loan_repayments')
          .insert({
            ...payload,
            created_by: session.user.id,
          })
          .select()
          .single(),
        10000,
        '创建还款记录'
      )
      if (error) throw error
      return data
    },

    // 删除还款记录
    async deleteRepayment(id) {
      const { error } = await withTimeout(
        supabase
          .from('loan_repayments')
          .delete()
          .eq('id', id),
        10000,
        '删除还款记录'
      )
      if (error) throw error
    },

    // 计算利息
    async calculateInterest(loanId, asOfDate = null) {
      const { data, error } = await withTimeout(
        supabase.rpc('calculate_loan_interest', {
          p_loan_id: loanId,
          p_as_of_date: asOfDate || new Date().toISOString().split('T')[0],
        }),
        10000,
        '计算利息'
      )
      if (error) throw error
      return Number(data) || 0
    },
  },
})
