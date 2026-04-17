import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'
import { logOperation, getAccountBalance, formatMoneyStr } from '../utils/operationLogger'
import { dayEnd } from '../utils/dateRange'

export const useOrderStore = defineStore('orders', {
  state: () => ({
    orders: [],
    loading: false,
    _fetchPromise: null,
    pagination: { total: 0, page: 1, pageSize: 20 },
  }),

  actions: {
    async fetchOrders({ keyword, searchField, category, dateFrom, dateTo, status, page = 1, pageSize = 20, platformTab } = {}) {
      // 防重复请求：如果上一次请求还在进行中，直接返回
      if (this.loading && this._fetchPromise) return this._fetchPromise
      this.loading = true
      this._fetchPromise = this._doFetchOrders({ keyword, searchField, category, dateFrom, dateTo, status, page, pageSize, platformTab })
      try {
        await this._fetchPromise
      } finally {
        this._fetchPromise = null
      }
    },

    async _doFetchOrders({ keyword, searchField, category, dateFrom, dateTo, status, page, pageSize, platformTab }) {
      try {
        const keywordParams = { searchField }
        let query = supabase
          .from('orders')
          .select('*', { count: 'estimated' })   // 估算行数,翻页时不全表扫
          .is('deleted_at', null)
          .order('created_at', { ascending: false })
          .range((page - 1) * pageSize, page * pageSize - 1)

        if (keyword) {
          // 按指定字段搜索
          const field = keywordParams.searchField
          if (field && field !== 'account_name') {
            // 指定字段搜索（不走账户查询，速度快）
            if (field === 'account_code' || field === 'customer_name' || field === 'product_name' || field === 'order_no' || field === 'note' || field === 'service_number_code') {
              query = query.ilike(field, `%${keyword}%`)
            }
          } else if (field === 'account_name' || !field) {
            // 账户名搜索：先查账户
            const { data: matchedAccounts } = await withTimeout(
              supabase
                .from('accounts')
                .select('id')
                .or(`short_name.ilike.%${keyword}%,code.ilike.%${keyword}%`)
                .limit(50),
              10000,
              '搜索订单关联账户'
            )
            const accIds = (matchedAccounts || []).map(a => a.id)
            if (!field && accIds.length === 0) {
              // "全部字段"模式下账户没匹配到，退回到多字段 ilike
              query = query.or(`customer_name.ilike.%${keyword}%,product_name.ilike.%${keyword}%,account_code.ilike.%${keyword}%,order_no.ilike.%${keyword}%,note.ilike.%${keyword}%`)
            } else {
              let orParts = `customer_name.ilike.%${keyword}%,product_name.ilike.%${keyword}%,account_code.ilike.%${keyword}%,order_no.ilike.%${keyword}%,note.ilike.%${keyword}%`
              if (accIds.length > 0) {
                orParts += `,account_id.in.(${accIds.join(',')})`
              }
              query = query.or(orParts)
            }
          }
        }
        if (category) query = query.eq('product_category', category)
        if (status) query = query.eq('status', status)
        if (dateFrom) query = query.gte('created_at', dateFrom)
        if (dateTo) query = query.lte('created_at', dayEnd(dateTo))
        // 订单页只显示私域订单，始终排除电商订单
        query = query.is('platform_type', null)

        const { data, error, count } = await withTimeout(query, 10000, '加载订单列表')
        if (error) throw error
        this.orders = data || []
        this.pagination = { total: count || 0, page, pageSize }
      } catch (e) {
        console.error('Failed to fetch orders:', e?.message || e?.details || JSON.stringify(e))
      } finally {
        this.loading = false
      }
    },

    async createOrder(payload) {
      // 一次性获取 session，避免多次异步请求
      const { data: { session } } = await supabase.auth.getSession()
      const userId = session?.user?.id

      // 自动填充 sales_id：通过 account_id 查当前活跃分配
      let salesId = payload.sales_id
      if (!salesId && payload.account_id) {
        const { data: ca } = await withTimeout(
          supabase
            .from('channel_assignments')
            .select('sales_id')
            .eq('account_id', payload.account_id)
            .eq('status', 'active')
            .maybeSingle(),
          10000,
          '查询渠道分配'
        )
        if (ca) salesId = ca.sales_id
      }
      // Fallback: 如果还是没有 sales_id，用当前用户
      if (!salesId) salesId = userId

      const { data, error } = await withTimeout(
        supabase
          .from('orders')
          .insert({
            ...payload,
            sales_id: salesId,
            creator_id: userId,
          })
          .select()
          .single(),
        10000,
        '创建订单'
      )
      if (error) throw error
      this.orders.unshift(data)

      // 自动更新对应账户余额（仅 completed 状态才加余额）
      let balBefore = null
      let balAfter = null
      const orderStatus = payload.status || data.status || 'completed'
      if (payload.account_id && payload.amount && orderStatus === 'completed') {
        const { useAccountStore } = await import('./accounts')
        const accStore = useAccountStore()
        const acc = accStore.accounts.find(a => a.id === payload.account_id)
        balBefore = acc?.balance ?? null
        // ⚠️ 电商店铺 balance_method='manual' 时，订单不再累加店铺余额
        // (店铺真实余额由财务通过"入账"入口手工维护，订单只作运营数据)
        const skipBalance = acc?.category === 'ecommerce' && acc?.balance_method === 'manual'
        if (!skipBalance) {
          try {
            await accStore.updateBalance(payload.account_id, Number(payload.amount))
            balAfter = accStore.accounts.find(a => a.id === payload.account_id)?.balance ?? null
          } catch (e) {
            console.error('余额更新失败，订单已创建但余额未更新:', e)
          }
        } else {
          balAfter = balBefore  // 未动余额
        }
      }

      // 操作日志
      try {
        const accName = await getAccountBalance(payload.account_id).then(r => r?.name || null)
        const balText = balBefore != null && balAfter != null
          ? `，余额 ${Number(balBefore).toFixed(2)} ${Number(balAfter) > Number(balBefore) ? '+' : '-'} ${Math.abs(Number(balAfter) - Number(balBefore)).toFixed(2)} → ${Number(balAfter).toFixed(2)}`
          : ''
        logOperation({
          action: 'create_order',
          module: '订单',
          description: `新建订单 ${data.order_no || ''}，金额 ${formatMoneyStr(payload.amount)}${accName ? `，账户：${accName}` : ''}${balText}${payload.customer_name ? `，客户：${payload.customer_name}` : ''}`,
          detail: { order_id: data.id, order_no: data.order_no, amount: payload.amount, customer_name: payload.customer_name, account_id: payload.account_id, balance_before: balBefore, balance_after: balAfter },
          amount: payload.amount,
          accountId: payload.account_id,
          accountName: accName,
        })
      } catch (e) { console.warn('操作日志写入失败:', e) }

      return data
    },

    async updateOrder(id, updates) {
      // 安全检查：非 admin/finance 不能修改 status
      // ⚠️ 注意：这只是前端的一道提示性拦截，真正的权限控制必须放在 Supabase RLS 策略里，
      // 否则任何人都可以直接调用 REST 接口绕过。
      if (updates.status !== undefined) {
        const { data: sessionData } = await supabase.auth.getSession()
        const userId = sessionData?.session?.user?.id
        if (!userId) {
          throw new Error('未登录，无法修改订单')
        }
        const { data: profile, error: profileErr } = await withTimeout(
          supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single(),
          10000,
          '查询用户角色(订单)'
        )
        if (profileErr || !profile || !['admin', 'finance'].includes(profile.role)) {
          delete updates.status
        }
      }

      // 记录变更前的快照（用于后续余额调整）
      const oldOrder = this.orders.find(o => o.id === id)
      const needCancelRefund = oldOrder && updates.status === 'cancelled' && oldOrder.status !== 'cancelled'
        && oldOrder.account_id && oldOrder.amount && Number(oldOrder.amount) > 0
      // 订单从 pending 变成 completed 时，增加余额
      const needCompleteAdd = oldOrder && updates.status === 'completed' && oldOrder.status !== 'completed'
        && oldOrder.status !== 'partially_refunded'
        && oldOrder.account_id && oldOrder.amount && Number(oldOrder.amount) > 0
      const amountDelta = (updates.amount !== undefined && oldOrder && Number(updates.amount) !== Number(oldOrder.amount))
        ? Number(updates.amount) - Number(oldOrder.amount || 0)
        : 0
      const needAmountAdjust = amountDelta !== 0 && oldOrder && oldOrder.account_id

      // ⚠️ 先更新数据库，成功后再调整余额（防止余额变了但DB没变）
      const { data, error } = await withTimeout(
        supabase
          .from('orders')
          .update(updates)
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新订单'
      )
      if (error) throw error
      const idx = this.orders.findIndex(o => o.id === id)
      if (idx >= 0) this.orders[idx] = data

      // DB 更新成功后，再处理余额变动
      const { useAccountStore } = await import('./accounts')
      const accStore = useAccountStore()
      // ⚠️ 电商店铺 manual 模式跳过所有余额变动(订单只作运营数据)
      const _acc = oldOrder ? accStore.accounts.find(a => a.id === oldOrder.account_id) : null
      const skipBalance = _acc?.category === 'ecommerce' && _acc?.balance_method === 'manual'

      // 取消订单：退回余额
      if (needCancelRefund && !skipBalance) {
        try {
          const balBefore = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          await accStore.updateBalance(oldOrder.account_id, -Number(oldOrder.amount))
          const balAfter = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          try {
            const accInfo = await getAccountBalance(oldOrder.account_id)
            const accName = accInfo?.name || ''
            const balText = balBefore != null && balAfter != null
              ? `，余额 ${Number(balBefore).toFixed(2)} - ${Math.abs(Number(balBefore) - Number(balAfter)).toFixed(2)} → ${Number(balAfter).toFixed(2)}`
              : ''
            logOperation({
              action: 'cancel_order',
              module: '订单',
              description: `取消订单 ${oldOrder.order_no || ''}，退回金额 ${formatMoneyStr(oldOrder.amount)}，客户：${oldOrder.customer_name || ''}，账户：${accName}${balText}`,
              detail: { order_id: id, order_no: oldOrder.order_no, amount: oldOrder.amount, customer_name: oldOrder.customer_name, account_id: oldOrder.account_id, account_name: accName, balance_before: balBefore, balance_after: balAfter },
              amount: oldOrder.amount,
              accountId: oldOrder.account_id,
              accountName: accName,
              balanceBefore: balBefore,
              balanceAfter: balAfter,
            })
          } catch (e) { console.warn('操作日志写入失败:', e) }
        } catch (e) {
          console.error('❌ 取消订单余额回退失败（订单已取消但余额未退），需手动处理！订单:', oldOrder.order_no, '账户:', oldOrder.account_id, '金额:', oldOrder.amount, e)
        }
      }

      // 订单状态变更为 completed：增加余额
      if (needCompleteAdd && !skipBalance) {
        try {
          const balBefore = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          await accStore.updateBalance(oldOrder.account_id, Number(oldOrder.amount))
          const balAfter = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          try {
            const accInfo = await getAccountBalance(oldOrder.account_id)
            const accName = accInfo?.name || ''
            const balText = balBefore != null && balAfter != null
              ? `，余额 ${Number(balBefore).toFixed(2)} + ${Math.abs(Number(balAfter) - Number(balBefore)).toFixed(2)} → ${Number(balAfter).toFixed(2)}`
              : ''
            logOperation({
              action: 'complete_order',
              module: '订单',
              description: `订单确认完成 ${oldOrder.order_no || ''}，增加余额 ${formatMoneyStr(oldOrder.amount)}，客户：${oldOrder.customer_name || ''}，账户：${accName}${balText}`,
              detail: { order_id: id, order_no: oldOrder.order_no, amount: oldOrder.amount, customer_name: oldOrder.customer_name, account_id: oldOrder.account_id, account_name: accName, balance_before: balBefore, balance_after: balAfter },
              amount: oldOrder.amount,
              accountId: oldOrder.account_id,
              accountName: accName,
              balanceBefore: balBefore,
              balanceAfter: balAfter,
            })
          } catch (e) { console.warn('操作日志写入失败:', e) }
        } catch (e) {
          console.error('❌ 订单完成余额增加失败，需手动处理！订单:', oldOrder.order_no, '账户:', oldOrder.account_id, '金额:', oldOrder.amount, e)
        }
      }

      // 修改金额：调整余额差额
      if (needAmountAdjust && !skipBalance) {
        try {
          const balBefore = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          await accStore.updateBalance(oldOrder.account_id, amountDelta)
          const balAfter = accStore.accounts.find(a => a.id === oldOrder.account_id)?.balance ?? null
          try {
            const accInfo = await getAccountBalance(oldOrder.account_id)
            const accName = accInfo?.name || ''
            const dir = amountDelta > 0 ? '+' : '-'
            const balText = balBefore != null && balAfter != null
              ? `，余额 ${Number(balBefore).toFixed(2)} ${dir} ${Math.abs(amountDelta).toFixed(2)} → ${Number(balAfter).toFixed(2)}`
              : ''
            logOperation({
              action: 'update_order_amount',
              module: '订单',
              description: `修改订单 ${oldOrder.order_no || ''} 金额 ${formatMoneyStr(oldOrder.amount)} → ${formatMoneyStr(updates.amount)}，客户：${oldOrder.customer_name || ''}，账户：${accName}${balText}`,
              detail: { order_id: id, order_no: oldOrder.order_no, old_amount: oldOrder.amount, new_amount: updates.amount, delta: amountDelta, customer_name: oldOrder.customer_name, account_id: oldOrder.account_id, account_name: accName, balance_before: balBefore, balance_after: balAfter },
              amount: Math.abs(amountDelta),
              accountId: oldOrder.account_id,
              accountName: accName,
              balanceBefore: balBefore,
              balanceAfter: balAfter,
            })
          } catch (e) { console.warn('操作日志写入失败:', e) }
        } catch (e) {
          console.error('❌ 订单金额变更余额调整失败（订单已改但余额未调），需手动处理！订单:', oldOrder.order_no, '差额:', amountDelta, e)
        }
      }

      return data
    },

    async deleteOrder(idOrOrder) {
      const order = typeof idOrOrder === 'object' ? idOrOrder : null
      const id = typeof idOrOrder === 'string' ? idOrOrder : order.id

      // 记录删除前的账户余额
      let balBefore = null
      let accName = ''
      if (order?.account_id) {
        try {
          const { getAccountBalance } = await import('../utils/operationLogger')
          const accInfo = await getAccountBalance(order.account_id)
          balBefore = accInfo?.balance
          accName = accInfo?.name || ''
        } catch (e) { console.warn("[silent catch]", e?.message || e) }
      }

      // 通过 RPC 软删除（RPC 内部已处理余额扣回）
      const { error: delError } = await withTimeout(
        supabase.rpc('delete_order', { p_id: id }),
        10000,
        '删除订单'
      )
      if (delError) throw delError

      // 刷新账户余额
      if (order?.account_id) {
        try {
          const { useAccountStore } = await import('./accounts')
          useAccountStore().refreshBalance(order.account_id)
        } catch (e) { console.warn("[silent catch]", e?.message || e) }
      }

      // 记录删除后的账户余额并写操作日志
      if (order) {
        try {
          const { logOperation, getAccountBalance } = await import('../utils/operationLogger')
          let balAfter = null
          if (order.account_id) {
            const accInfo = await getAccountBalance(order.account_id)
            balAfter = accInfo?.balance
            if (!accName) accName = accInfo?.name || ''
          }
          const balText = balBefore != null && balAfter != null
            ? `，余额 ${Number(balBefore).toFixed(2)} → ${Number(balAfter).toFixed(2)}`
            : ''
          await logOperation({
            action: 'delete_order',
            module: '订单',
            description: `删除订单 ${order.order_no || ''}，扣回金额 ¥${Number(order.amount || 0).toFixed(2)}，客户：${order.customer_name || ''}，账户：${accName}${balText}`,
            detail: { order_id: id, order_no: order.order_no, amount: order.amount, customer_name: order.customer_name, account_id: order.account_id, account_name: accName, balance_before: balBefore, balance_after: balAfter },
            amount: order.amount,
            accountId: order.account_id,
            accountName: accName,
            balanceBefore: balBefore,
            balanceAfter: balAfter,
          })
        } catch (e) { console.warn('操作日志写入失败:', e) }
      }

      this.orders = this.orders.filter(o => o.id !== id)
    },
  },
})
