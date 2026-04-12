import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { dayStart, dayEnd } from '../utils/dateRange'

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    warehouses: [],
    inventory: [],
    logs: [],
    loading: false,
    stats: { totalStock: 0, totalProducts: 0, totalWarehouses: 0, lowStockWarnings: 0 },
    pagination: { page: 1, pageSize: 20, total: 0 },
    logPagination: { page: 1, pageSize: 20, total: 0 },
  }),

  actions: {
    // ========== 仓库管理 ==========
    async fetchWarehouses() {
      this.loading = true
      try {
        const { data, error } = await supabase
          .from('warehouses')
          .select('*')
          .order('created_at', { ascending: false })
        if (error) throw error
        this.warehouses = data || []
      } catch (e) {
        console.error('Failed to fetch warehouses:', e)
        throw e
      } finally {
        this.loading = false
      }
    },

    async createWarehouse(payload) {
      const { data, error } = await supabase
        .from('warehouses')
        .insert(payload)
        .select()
        .single()
      if (error) throw error
      this.warehouses.unshift(data)
      return data
    },

    async updateWarehouse(id, updates) {
      const { data, error } = await supabase
        .from('warehouses')
        .update(updates)
        .eq('id', id)
        .select()
        .single()
      if (error) throw error
      const idx = this.warehouses.findIndex(w => w.id === id)
      if (idx >= 0) this.warehouses[idx] = data
      return data
    },

    // ========== 库存管理 ==========
    async fetchStats() {
      try {
        const { data, error } = await supabase.rpc('get_inventory_stats')
        if (error) throw error
        if (data) {
          this.stats = {
            totalStock: data.total_stock || 0,
            totalProducts: data.total_products || 0,
            totalWarehouses: data.total_warehouses || 0,
            lowStockWarnings: data.low_stock || 0,
          }
        }
      } catch (e) {
        console.error('Failed to fetch inventory stats:', e)
      }
    },

    async fetchInventory(params = {}) {
      this.loading = true
      try {
        let query = supabase
          .from('inventory_view')
          .select('*', { count: 'exact' })

        if (params.warehouseId) {
          query = query.eq('warehouse_id', params.warehouseId)
        }
        if (params.brand) {
          query = query.eq('brand', params.brand)
        }
        if (params.keyword) {
          const kw = params.keyword.replace(/[,%().*]/g, '')
          query = query.or(`product_name.ilike.%${kw}%,warehouse_name.ilike.%${kw}%,brand.ilike.%${kw}%`)
        }

        const page = params.page || 1
        const pageSize = params.pageSize || 20
        const from = (page - 1) * pageSize
        const to = from + pageSize - 1

        query = query.order('product_name').range(from, to)

        const { data, error, count } = await query
        if (error) throw error
        this.inventory = data || []
        this.pagination = { page, pageSize, total: count || 0 }
      } catch (e) {
        console.error('Failed to fetch inventory:', e)
        throw e
      } finally {
        this.loading = false
      }
    },

    async fetchLogs(params = {}) {
      this.loading = true
      try {
        let query = supabase
          .from('inventory_logs')
          .select('*, warehouse:warehouses(name), product:products(name)', { count: 'exact' })
          .order('created_at', { ascending: false })

        if (params.warehouseId) {
          query = query.eq('warehouse_id', params.warehouseId)
        }
        if (params.type) {
          query = query.eq('change_type', params.type)
        }
        if (params.keyword) {
          const kw = params.keyword.replace(/[,%().*]/g, '')
          query = query.or(`product.name.ilike.%${kw}%,note.ilike.%${kw}%`)
        }
        if (params.startDate) {
          query = query.gte('created_at', dayStart(params.startDate))
        }
        if (params.endDate) {
          query = query.lte('created_at', dayEnd(params.endDate))
        }

        const page = params.page || 1
        const pageSize = params.pageSize || 20
        const from = (page - 1) * pageSize
        const to = from + pageSize - 1

        query = query.range(from, to)

        const { data, error, count } = await query
        if (error) throw error
        this.logs = data || []
        this.logPagination = { page, pageSize, total: count || 0 }
      } catch (e) {
        console.error('Failed to fetch inventory logs:', e)
        throw e
      } finally {
        this.loading = false
      }
    },

    // ========== 库存操作 ==========
    async adjustStock(warehouseId, productId, quantity, type, note) {
      const { data, error } = await supabase.rpc('adjust_inventory', {
        p_warehouse_id: warehouseId,
        p_product_id: productId,
        p_quantity: quantity,
        p_change_type: type,
        p_note: note,
      })
      if (error) throw error
      return data
    },

    async transferStock(fromWarehouseId, toWarehouseId, productId, quantity, note) {
      const { data, error } = await supabase.rpc('transfer_stock', {
        p_from_wh: fromWarehouseId,
        p_to_wh: toWarehouseId,
        p_product_id: productId,
        p_quantity: quantity,
        p_note: note,
      })
      if (error) throw error
      return data
    },

    async shipDeduct(orderId) {
      const { data, error } = await supabase.rpc('ship_deduct_inventory', {
        p_order_id: orderId,
      })
      if (error) throw error
      return data
    },

    async returnAdd(refundId, productId, quantity) {
      const { data, error } = await supabase.rpc('return_add_inventory', {
        p_refund_id: refundId,
        p_product_id: productId,
        p_quantity: quantity,
      })
      if (error) throw error
      return data
    },
  },
})
