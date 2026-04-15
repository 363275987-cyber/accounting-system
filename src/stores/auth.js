import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    profile: null,
    loading: true,
  }),
  actions: {
    async init() {
      try {
        const { data: { session } } = await supabase.auth.getSession()
        if (session?.user) {
          await this.fetchProfile(session.user.id)
        }
      } catch (e) {
        // token 失效时静默清除，跳转到登录页
        await supabase.auth.signOut().catch(() => {})
      }
      this.loading = false

      supabase.auth.onAuthStateChange(async (_event, session) => {
        if (session?.user) {
          await this.fetchProfile(session.user.id)
        } else {
          this.user = null
          this.profile = null
        }
      })
    },
    async fetchProfile(userId) {
      const { data, error } = await withTimeout(
        supabase.from('profiles').select('*').eq('id', userId).single(),
        10000,
        '加载用户资料'
      )
      if (error) {
        console.error('Failed to fetch profile:', error?.message || error?.code || JSON.stringify(error))
        this.user = null
        this.profile = null
        return
      }
      this.user = userId
      this.profile = data
    },
    async login(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      await this.fetchProfile(data.user.id)
    },
    async resetPassword(email) {
      // Supabase 发送重置密码邮件，链接回到登录页
      const redirectTo = window.location.origin + window.location.pathname + '#/login?reset=1'
      const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo })
      if (error) throw error
    },
    async updatePassword(newPassword) {
      const { error } = await supabase.auth.updateUser({ password: newPassword })
      if (error) throw error
    },
    async logout() {
      await supabase.auth.signOut()
      this.user = null
      this.profile = null
    },
  },
  getters: {
    isAdmin: (state) => state.profile?.role === 'admin',
    isFinance: (state) => ['admin', 'finance', 'manager'].includes(state.profile?.role),
    isSales: (state) => state.profile?.role === 'sales',
    isCS: (state) => state.profile?.role === 'cs',
    isHR: (state) => state.profile?.role === 'hr',
    isWarehouse: (state) => state.profile?.role === 'warehouse',
    canApprove: (state) => ['admin', 'finance'].includes(state.profile?.role),
    isLoggedIn: (state) => !!state.user,
  }
})
