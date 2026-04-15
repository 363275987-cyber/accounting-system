import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useSalesGroupStore = defineStore('salesGroup', {
  state: () => ({
    groups: [],
    members: [],        // current group members
    groupPerformance: [], // group performance data
    loading: false,
  }),
  actions: {
    // 获取所有分组
    async fetchGroups() {
      this.loading = true
      try {
        const { data, error } = await withTimeout(
          supabase
            .from('sales_groups')
            .select('*')
            .order('created_at', { ascending: false }),
          10000,
          '加载销售组列表'
        )
        if (error) throw error
        this.groups = data || []
      } catch (e) {
        console.error('Failed to fetch groups:', e)
        throw e
      } finally {
        this.loading = false
      }
    },

    // 创建分组 - 使用 RPC 绕过 RLS
    async createGroup({ name, leader_id }) {
      const { data, error } = await withTimeout(
        supabase.rpc('create_sales_group', { p_name: name, p_leader_id: leader_id || null }),
        10000,
        '创建销售组'
      )
      if (error) throw error

      await this.fetchGroups()
      return data
    },

    // 更新分组
    async updateGroup(id, updates) {
      const { error } = await withTimeout(
        supabase
          .from('sales_groups')
          .update({ ...updates, updated_at: new Date().toISOString() })
          .eq('id', id),
        10000,
        '更新销售组'
      )
      if (error) throw error
      await this.fetchGroups()
    },

    // 删除分组
    async deleteGroup(id) {
      // 先删除成员
      const { error: memberErr } = await withTimeout(
        supabase.from('sales_group_members').delete().eq('group_id', id),
        10000,
        '删除销售组成员'
      )
      if (memberErr) throw memberErr
      const { error } = await withTimeout(
        supabase.from('sales_groups').delete().eq('id', id),
        10000,
        '删除销售组'
      )
      if (error) throw error
      await this.fetchGroups()
    },

    // 获取分组下的成员（带 profile 信息）
    async fetchMembers(groupId) {
      const { data, error } = await withTimeout(
        supabase
          .from('sales_group_members')
          .select(`
            *,
            profile:profiles(id, name, role, phone)
          `)
          .eq('group_id', groupId)
          .order('role', { ascending: false }), // leader first
        10000,
        '加载销售组成员'
      )
      if (error) throw error
      this.members = data || []
      return this.members
    },

    // 添加成员
    async addMember(groupId, userId, role = 'member') {
      const { error } = await withTimeout(
        supabase
          .from('sales_group_members')
          .insert({ group_id: groupId, user_id: userId, role }),
        10000,
        '添加销售组成员'
      )
      if (error) throw error
      await this.fetchMembers(groupId)
    },

    // 移除成员
    async removeMember(groupId, userId) {
      const { error } = await withTimeout(
        supabase
          .from('sales_group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId),
        10000,
        '移除销售组成员'
      )
      if (error) throw error
      await this.fetchMembers(groupId)
    },

    // 设置组长（更新分组 leader_id + 成员角色）
    async setLeader(groupId, userId) {
      // 从数据库获取当前 leader，避免用过期缓存
      const { data: freshGroup } = await withTimeout(
        supabase.from('sales_groups').select('leader_id').eq('id', groupId).single(),
        10000,
        '查询销售组组长'
      )
      if (freshGroup?.leader_id) {
        const { error: e1 } = await withTimeout(
          supabase
            .from('sales_group_members')
            .update({ role: 'member' })
            .eq('group_id', groupId)
            .eq('user_id', freshGroup.leader_id),
          10000,
          '降级旧组长'
        )
        if (e1) throw e1
      }

      const { error: e2 } = await withTimeout(
        supabase
          .from('sales_group_members')
          .update({ role: 'leader' })
          .eq('group_id', groupId)
          .eq('user_id', userId),
        10000,
        '升级新组长'
      )
      if (e2) throw e2

      const { error: e3 } = await withTimeout(
        supabase
          .from('sales_groups')
          .update({ leader_id: userId, updated_at: new Date().toISOString() })
          .eq('id', groupId),
        10000,
        '更新销售组组长字段'
      )
      if (e3) throw e3

      await this.fetchGroups()
      await this.fetchMembers(groupId)
    },

    // 获取用户所在的销售组
    async getUserGroup(userId) {
      const { data, error } = await withTimeout(
        supabase.rpc('get_user_sales_group', { p_user_id: userId }),
        10000,
        '查询用户销售组'
      )
      if (error) throw error
      return data || []
    },

    // 获取组内业绩
    async fetchGroupPerformance(groupId, month) {
      const { data, error } = await withTimeout(
        supabase
          .from('v_group_performance')
          .select('*')
          .eq('group_id', groupId)
          .like('month', `${month}%`),
        10000,
        '加载销售组业绩'
      )
      if (error) throw error
      this.groupPerformance = data || []
      return this.groupPerformance
    },

    // 获取组员列表（用于添加成员选择）
    // profiles 表无 status 列（BUG-12 同因），仅按角色筛
    async getAvailableUsers() {
      const { data, error } = await withTimeout(
        supabase
          .from('profiles')
          .select('id, name, role')
          .order('name'),
        10000,
        '加载可用用户列表'
      )
      if (error) throw error
      return data || []
    },
  },
})
