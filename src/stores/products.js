import { defineStore } from 'pinia'
import { supabase, withTimeout } from '../lib/supabase'

export const useProductStore = defineStore('products', {
  state: () => ({
    products: [],
    loading: false,
    pagination: { total: 0, page: 1, pageSize: 50 },
    // SKU 缓存：productId → skus[]
    skusMap: {},
    // 套装明细缓存：bundleId → items[]
    bundleItemsMap: {},
  }),

  actions: {
    // ========== SPU 产品管理 ==========

    async fetchProducts({ keyword, category, brand, status, product_type, page = 1, pageSize = 50 } = {}) {
      this.loading = true
      try {
        let query = supabase
          .from('products')
          .select('*', { count: 'exact' })
          .order('created_at', { ascending: false })
          .range((page - 1) * pageSize, page * pageSize - 1)

        if (keyword) {
          query = query.or(`name.ilike.%${keyword}%,brand.ilike.%${keyword}%,spu_code.ilike.%${keyword}%`)
        }
        if (category) query = query.eq('category', category)
        if (brand) query = query.eq('brand', brand)
        if (status) query = query.eq('status', status)
        if (product_type) query = query.eq('product_type', product_type)

        const { data, error, count } = await withTimeout(query, 10000, '加载商品列表')
        if (error) throw error
        this.products = data || []
        this.pagination = { total: count || 0, page, pageSize }
      } catch (e) {
        console.error('Failed to fetch products:', e)
      } finally {
        this.loading = false
      }
    },

    async createProduct(payload) {
      const { data, error } = await withTimeout(
        supabase
          .from('products')
          .insert(payload)
          .select()
          .single(),
        10000,
        '创建商品'
      )
      if (error) throw error
      this.products.unshift(data)
      return data
    },

    async updateProduct(id, updates) {
      const { data, error } = await withTimeout(
        supabase
          .from('products')
          .update(updates)
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新商品'
      )
      if (error) throw error
      const idx = this.products.findIndex(p => p.id === id)
      if (idx >= 0) this.products[idx] = data
      return data
    },

    async deleteProduct(id) {
      const { error } = await withTimeout(
        supabase.from('products').delete().eq('id', id),
        10000,
        '删除商品'
      )
      if (error) throw error
      this.products = this.products.filter(p => p.id !== id)
      // 清理缓存
      delete this.skusMap[id]
      delete this.bundleItemsMap[id]
    },

    async searchProducts(keyword) {
      if (!keyword || keyword.length < 1) return []
      // 先在 products 表搜索
      const { data: pData, error: pErr } = await withTimeout(
        supabase
          .from('products')
          .select('id, name, category, brand, cost_price, retail_price, unit, status, product_type')
          .eq('status', 'active')
          .or(`name.ilike.%${keyword}%,brand.ilike.%${keyword}%,spu_code.ilike.%${keyword}%`)
          .limit(20),
        10000,
        '搜索商品'
      )
      if (pErr) throw pErr

      // 再通过 SKU 编码搜索关联的产品（去重）
      const { data: sData, error: sErr } = await withTimeout(
        supabase
          .from('product_skus')
          .select('product_id, sku_code')
          .ilike('sku_code', `%${keyword}%`)
          .limit(10),
        10000,
        '搜索 SKU 编码'
      )
      if (!sErr && sData && sData.length > 0) {
        const productIds = [...new Set(sData.map(s => s.product_id))]
        const existingIds = new Set((pData || []).map(p => p.id))
        const newIds = productIds.filter(id => !existingIds.has(id))
        if (newIds.length > 0) {
          const { data: extra } = await withTimeout(
            supabase
              .from('products')
              .select('id, name, category, brand, cost_price, retail_price, unit, status, product_type')
              .eq('status', 'active')
              .in('id', newIds),
            10000,
            '加载 SKU 关联商品'
          )
          if (extra) pData.push(...extra)
        }
      }

      return pData || []
    },

    // ========== SKU 管理 ==========

    /** 获取产品的所有 SKU */
    async fetchSkus(productId) {
      const { data, error } = await withTimeout(
        supabase
          .from('product_skus')
          .select('*')
          .eq('product_id', productId)
          .eq('status', 'active')
          .order('sku_code'),
        10000,
        '加载 SKU 列表'
      )
      if (error) throw error
      this.skusMap[productId] = data || []
      return data || []
    },

    /** 创建 SKU */
    async createSku(payload) {
      const { data, error } = await withTimeout(
        supabase
          .from('product_skus')
          .insert(payload)
          .select()
          .single(),
        10000,
        '创建 SKU'
      )
      if (error) throw error
      // 更新缓存
      if (this.skusMap[payload.product_id]) {
        this.skusMap[payload.product_id].push(data)
      }
      return data
    },

    /** 更新 SKU */
    async updateSku(id, updates) {
      const { data, error } = await withTimeout(
        supabase
          .from('product_skus')
          .update(updates)
          .eq('id', id)
          .select()
          .single(),
        10000,
        '更新 SKU'
      )
      if (error) throw error
      // 更新缓存
      for (const pid in this.skusMap) {
        const idx = this.skusMap[pid].findIndex(s => s.id === id)
        if (idx >= 0) {
          this.skusMap[pid][idx] = data
          break
        }
      }
      return data
    },

    /** 删除 SKU */
    async deleteSku(id) {
      const { error } = await withTimeout(
        supabase.from('product_skus').delete().eq('id', id),
        10000,
        '删除 SKU'
      )
      if (error) throw error
      // 清理缓存
      for (const pid in this.skusMap) {
        this.skusMap[pid] = this.skusMap[pid].filter(s => s.id !== id)
      }
    },

    // ========== 套装明细（bundle_items） ==========

    /** 获取套装包含的子商品详情 */
    async fetchBundleItems(bundleId) {
      const { data, error } = await withTimeout(
        supabase
          .from('bundle_items')
          .select(`
            id, quantity, sort_order, sku_id,
            product_skus:sku_id(
              id, sku_code, specs, cost_price, retail_price, stock,
              products:product_id(id, name, image, brand, unit)
            )
          `)
          .eq('bundle_id', bundleId)
          .order('sort_order'),
        10000,
        '加载套装明细'
      )
      if (error) throw error
      this.bundleItemsMap[bundleId] = data || []
      return data || []
    },

    /** 保存套装明细（先删后插） */
    async saveBundleItems(bundleId, items) {
      // items: [{ sku_id, quantity, sort_order }]
      // 删除旧的
      const { error: delErr } = await withTimeout(
        supabase.from('bundle_items').delete().eq('bundle_id', bundleId),
        10000,
        '删除旧套装明细'
      )
      if (delErr) throw delErr

      if (!items || items.length === 0) {
        this.bundleItemsMap[bundleId] = []
        return []
      }

      // 插入新的
      const rows = items.map((item, i) => ({
        bundle_id: bundleId,
        sku_id: item.sku_id,
        quantity: item.quantity || 1,
        sort_order: item.sort_order ?? i,
      }))
      const { data, error } = await withTimeout(
        supabase
          .from('bundle_items')
          .insert(rows)
          .select(`
            id, quantity, sort_order, sku_id,
            product_skus:sku_id(
              id, sku_code, specs, cost_price, retail_price, stock,
              products:product_id(id, name, image, brand, unit)
            )
          `),
        10000,
        '保存套装明细'
      )
      if (error) throw error
      this.bundleItemsMap[bundleId] = data || []
      return data || []
    },

    // ========== 套装赠品系统（已有，保留不动） ==========

    /** 获取产品的套装（含赠品详情） */
    async getProductBundle(productId) {
      const { data, error } = await withTimeout(
        supabase
          .from('product_bundle_items')
          .select(`
            id, quantity, sort_order,
            product_id,
            products:product_id(id, name, category, brand, cost_price, retail_price, unit)
          `)
          .eq('bundle_id', productId)
          .order('sort_order'),
        10000,
        '加载商品套装'
      )
      if (error) throw error
      return data || []
    },

    /** 通过 RPC 获取完整套装（bundle + gifts） */
    async fetchBundleForProduct(productId) {
      const { data, error } = await withTimeout(
        supabase.rpc('get_product_bundle', { p_product_id: productId }),
        10000,
        '加载完整套装'
      )
      if (error) throw error
      return data
    },

    /** 保存套装：创建或更新 */
    async saveBundle(mainProductId, gifts, bundleName = null, createdBy = null) {
      if (!gifts || gifts.length === 0) return

      const { data: bundle, error: bErr } = await withTimeout(
        supabase
          .from('product_bundles')
          .upsert(
            { main_product_id: mainProductId, name: bundleName, created_by: createdBy },
            { onConflict: 'main_product_id' }
          )
          .select()
          .single(),
        10000,
        '保存套装头'
      )
      if (bErr) throw bErr

      const bundleId = bundle.id
      const { error: delErr2 } = await withTimeout(
        supabase.from('product_bundle_items').delete().eq('bundle_id', bundleId),
        10000,
        '清空旧套装赠品'
      )
      if (delErr2) throw delErr2

      const items = gifts.map((g, i) => ({
        bundle_id: bundleId,
        product_id: g.product_id,
        quantity: g.quantity || 1,
        sort_order: i,
      }))
      const { error: iErr } = await withTimeout(
        supabase.from('product_bundle_items').insert(items),
        10000,
        '写入套装赠品'
      )
      if (iErr) throw iErr

      return bundle
    },

    /** 删除套装 */
    async deleteBundle(mainProductId) {
      const { error } = await withTimeout(
        supabase
          .from('product_bundles')
          .delete()
          .eq('main_product_id', mainProductId),
        10000,
        '删除套装'
      )
      if (error) throw error
    },

    /** 赠品价值校验 */
    validateGiftValue(mainCostPrice, gifts, limitMultiplier = 3) {
      const giftTotalCost = gifts.reduce((sum, g) => sum + (Number(g.cost_price) || 0) * (g.quantity || 1), 0)
      const maxAllowed = Number(mainCostPrice) * limitMultiplier
      return {
        giftTotalCost,
        maxAllowed,
        isWithinLimit: giftTotalCost <= maxAllowed || maxAllowed === 0,
        overBy: maxAllowed > 0 ? Math.max(0, giftTotalCost - maxAllowed) : 0,
      }
    },

    // ========== 导入相关 ==========

    /** 通过 SKU 编码精确匹配（用于导入 Excel） */
    async matchBySkuCode(skuCode) {
      if (!skuCode) return null
      const { data, error } = await withTimeout(
        supabase.rpc('match_product_by_sku_code', {
          p_sku_code: skuCode,
        }),
        10000,
        '按 SKU 匹配商品'
      )
      if (error || !data || !data.sku_id) return null
      return data
    },

    // ========== SPU 编码自动生成 ==========

    /** 生成下一个 SPU 编码，如 SP-001 */
    async generateSpuCode() {
      const { data, error } = await withTimeout(
        supabase
          .from('products')
          .select('spu_code')
          .not('spu_code', 'is', null)
          .ilike('spu_code', 'SP-%')
          .order('spu_code', { ascending: false })
          .limit(1),
        10000,
        '生成 SPU 编码'
      )

      if (error || !data || data.length === 0) return 'SP-001'

      // 提取最大数字
      const maxCode = data[0].spu_code
      const match = maxCode.match(/SP-(\d+)/)
      const nextNum = match ? parseInt(match[1]) + 1 : 1
      return `SP-${String(nextNum).padStart(3, '0')}`
    },
  },
})
