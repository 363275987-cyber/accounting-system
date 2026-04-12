<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-2xl max-h-[85vh] flex flex-col mx-4">
      <!-- Header -->
      <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
        <div>
          <h3 class="text-lg font-semibold text-gray-800">🎁 选择赠品</h3>
          <p class="text-xs text-gray-500 mt-0.5">为主产品「{{ mainProductName }}」配置赠品</p>
        </div>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer leading-none">&times;</button>
      </div>

      <div class="flex flex-1 overflow-hidden">
        <!-- 左侧：产品库搜索 -->
        <div class="flex-1 border-r border-gray-100 flex flex-col min-w-0">
          <div class="p-3 border-b border-gray-50">
            <input
              v-model="searchKeyword"
              placeholder="搜索赠品（皮头、手套、巧克粉、杆盒...）"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-purple-500"
              autofocus
            />
            <div class="flex gap-1 mt-2 flex-wrap">
              <button
                @click="toggleCategory('')"
                class="px-2 py-0.5 text-xs rounded-full border transition cursor-pointer"
                :class="!activeCategory ? 'bg-purple-100 text-purple-700 border-purple-300' : 'bg-gray-50 text-gray-500 border-gray-200 hover:bg-gray-100'"
              >
                全部
              </button>
              <button
                v-for="cat in giftCategories"
                :key="cat.key"
                @click="toggleCategory(cat.key)"
                class="px-2 py-0.5 text-xs rounded-full border transition cursor-pointer"
                :class="activeCategory === cat.key ? 'bg-purple-100 text-purple-700 border-purple-300' : 'bg-gray-50 text-gray-500 border-gray-200 hover:bg-gray-100'"
              >
                {{ cat.label }}
              </button>
            </div>
          </div>
          <div class="flex-1 overflow-y-auto p-2 space-y-1">
            <div
              v-for="p in filteredProducts"
              :key="p.id"
              @click="addGift(p)"
              class="flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer text-sm transition"
              :class="isAlreadySelected(p.id) ? 'bg-gray-100 text-gray-500 cursor-not-allowed' : 'hover:bg-purple-50'"
            >
              <div class="min-w-0">
                <div class="font-medium truncate">{{ p.name }}</div>
                <div class="text-xs text-gray-500">
                  {{ giftCategoryLabel(p.category) }}
                  <span v-if="p.brand"> · {{ p.brand }}</span>
                  <span v-if="Number(p.cost_price) > 0"> · 成本 ¥{{ Number(p.cost_price).toFixed(2) }}</span>
                </div>
              </div>
              <span v-if="!isAlreadySelected(p.id)" class="text-purple-500 text-lg leading-none flex-shrink-0">+</span>
              <span v-else class="text-gray-300 text-xs flex-shrink-0">已选</span>
            </div>
            <div v-if="filteredProducts.length === 0" class="text-center py-8 text-gray-500 text-sm">
              {{ searching ? '搜索中...' : '没有找到匹配的产品' }}
            </div>
          </div>
        </div>

        <!-- 右侧：已选赠品 -->
        <div class="w-64 flex flex-col flex-shrink-0">
          <div class="p-3 border-b border-gray-50">
            <div class="text-sm font-medium text-gray-700">已选赠品 ({{ selectedGifts.length }})</div>
          </div>
          <div class="flex-1 overflow-y-auto p-2 space-y-2">
            <div
              v-for="(gift, idx) in selectedGifts"
              :key="gift.product_id"
              class="bg-purple-50 rounded-lg p-3"
            >
              <div class="flex items-start justify-between">
                <div class="min-w-0 flex-1">
                  <div class="text-sm font-medium text-gray-800 truncate">{{ gift.name }}</div>
                  <div class="text-xs text-gray-500">成本 ¥{{ Number(gift.cost_price || 0).toFixed(2) }} / 个</div>
                </div>
                <button @click="removeGift(idx)" class="text-gray-500 hover:text-red-500 cursor-pointer text-sm ml-1">&times;</button>
              </div>
              <div class="flex items-center justify-between mt-2">
                <div class="flex items-center gap-1">
                  <button @click="changeQty(idx, -1)" class="w-6 h-6 flex items-center justify-center rounded border border-gray-200 text-gray-500 hover:bg-white cursor-pointer text-sm">−</button>
                  <span class="w-8 text-center text-sm font-medium">{{ gift.quantity }}</span>
                  <button @click="changeQty(idx, 1)" class="w-6 h-6 flex items-center justify-center rounded border border-gray-200 text-gray-500 hover:bg-white cursor-pointer text-sm">+</button>
                </div>
                <span class="text-xs text-gray-500">小计 ¥{{ (Number(gift.cost_price || 0) * gift.quantity).toFixed(2) }}</span>
              </div>
            </div>
            <div v-if="selectedGifts.length === 0" class="text-center py-8 text-gray-300 text-sm">
              从左侧添加赠品
            </div>
          </div>

          <!-- 底部汇总 -->
          <div class="p-3 border-t border-gray-100 bg-gray-50 rounded-b-xl">
            <div class="flex justify-between text-xs text-gray-500 mb-1">
              <span>赠品总成本</span>
              <span>¥{{ giftTotalCost }}</span>
            </div>
            <!-- 首次配置无限制；编辑时限制增量 -->
            <div v-if="hasExistingBundle && mainCostPrice > 0" class="flex justify-between text-xs mb-1" :class="isOverLimit ? 'text-red-500 font-medium' : 'text-gray-500'">
              <span>新增成本上限 (主产品成本×{{ (giftLimitPercent / 100).toFixed(1) }}%)</span>
              <span>¥{{ maxIncrement }}</span>
            </div>
            <div v-if="hasExistingBundle" class="flex justify-between text-xs text-gray-500 mb-1">
              <span>原有赠品成本</span>
              <span>¥{{ originalGiftsCostDisplay }}</span>
            </div>
            <div v-if="hasExistingBundle" class="flex justify-between text-xs mb-1" :class="incrementCost > maxIncrementNum ? 'text-red-500 font-medium' : 'text-gray-500'">
              <span>本次新增成本</span>
              <span>¥{{ incrementCostDisplay }}</span>
            </div>
            <div v-if="isOverLimit" class="text-xs text-red-500 mt-1 bg-red-50 rounded px-2 py-1">
              ⚠️ 新增赠品成本超限 ¥{{ overBy.toFixed(2) }}，请联系经理审批
            </div>
            <div v-if="!hasExistingBundle && mainCostPrice > 0" class="text-xs text-green-600 mt-1">
              ✦ 首次配置赠品，无成本限制
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between px-5 py-4 border-t border-gray-100">
        <label v-if="hasExistingBundle" class="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
          <input type="checkbox" v-model="saveAsDefault" class="rounded border-gray-300" />
          保存为默认套装
        </label>
        <div v-else></div>
        <div class="flex gap-2">
          <button @click="$emit('close')" class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer">取消</button>
          <button
            @click="confirm"
            :disabled="selectedGifts.length === 0 || isOverLimit"
            class="px-4 py-2 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
          >
            确认
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'

const props = defineProps({
  mainProductId: { type: String, required: true },
  mainProductName: { type: String, default: '' },
  mainCostPrice: { type: Number, default: 0 },
  existingGifts: { type: Array, default: () => [] },
  editingExisting: { type: Boolean, default: false },
  giftLimitPercent: { type: Number, default: 10 },
})

const emit = defineEmits(['confirm', 'close'])

const searchKeyword = ref('')
const activeCategory = ref('')
const selectedGifts = ref([])
const allProducts = ref([])
const searching = ref(false)
const saveAsDefault = ref(false)
const originalGiftsCost = ref(0) // 原有赠品总成本

const giftCategories = [
  { key: 'tip', label: '皮头' },
  { key: 'glove', label: '手套' },
  { key: 'chalk', label: '巧克粉' },
  { key: 'case', label: '杆盒/杆桶' },
  { key: 'bag', label: '杆包' },
  { key: 'towel', label: '毛巾' },
  { key: 'maintenance', label: '保养套装' },
  { key: 'extension', label: '加长把' },
  { key: 'glue', label: '胶水' },
  { key: 'rest', label: '架杆' },
  { key: 'shaft', label: '前支' },
  { key: 'jump_break', label: '冲杆/跳杆' },
]

const categoryLabels = {
  tip: '皮头', glove: '手套', chalk: '巧克粉', case: '杆盒/杆桶',
  bag: '杆包', towel: '毛巾', maintenance: '保养套装', extension: '加长把',
  glue: '胶水', rest: '架杆', shaft: '前支', jump_break: '冲杆/跳杆',
  cue: '球杆', ball: '球', table: '球桌', course: '课程',
  book: '书籍', accessory: '配件', consumable: '耗材', service: '服务',
}

function giftCategoryLabel(cat) {
  return categoryLabels[cat] || cat || '其他'
}

// 是否已有套装（有已有赠品 = 编辑模式）
const hasExistingBundle = computed(() => props.existingGifts.length > 0)

onMounted(async () => {
  if (props.existingGifts.length > 0) {
    selectedGifts.value = props.existingGifts.map(g => ({
      product_id: g.product_id,
      name: g.product_name || g.name,
      cost_price: g.cost_price || g.gift_cost || 0,
      retail_price: g.retail_price || g.gift_price || 0,
      quantity: g.quantity,
    }))
    originalGiftsCost.value = selectedGifts.value.reduce((sum, g) => sum + g.cost_price * g.quantity, 0)
  }
  await loadProducts()
})

async function loadProducts() {
  searching.value = true
  try {
    const { data, error } = await supabase
      .from('products')
      .select('id, name, category, brand, cost_price, retail_price, unit, status')
      .eq('status', 'active')
      .neq('category', 'cue')
      .order('category')
      .order('name')
    if (error) throw error
    allProducts.value = data || []
  } catch (e) {
    console.error('加载产品失败:', e)
  } finally {
    searching.value = false
  }
}

function toggleCategory(cat) {
  activeCategory.value = activeCategory.value === cat ? '' : cat
}

const filteredProducts = computed(() => {
  let list = allProducts.value
  if (activeCategory.value) {
    list = list.filter(p => p.category === activeCategory.value)
  }
  if (searchKeyword.value) {
    const kw = searchKeyword.value.toLowerCase()
    list = list.filter(p =>
      (p.name && p.name.toLowerCase().includes(kw)) ||
      (p.brand && p.brand.toLowerCase().includes(kw))
    )
  }
  return list
})

function isAlreadySelected(productId) {
  return selectedGifts.value.some(g => g.product_id === productId)
}

function addGift(product) {
  if (isAlreadySelected(product.id)) return
  selectedGifts.value.push({
    product_id: product.id,
    name: product.name,
    cost_price: Number(product.cost_price) || 0,
    retail_price: Number(product.retail_price) || 0,
    quantity: 1,
  })
}

function removeGift(idx) {
  selectedGifts.value.splice(idx, 1)
}

function changeQty(idx, delta) {
  const newQty = selectedGifts.value[idx].quantity + delta
  if (newQty >= 1 && newQty <= 99) {
    selectedGifts.value[idx].quantity = newQty
  }
}

const giftTotalCost = computed(() => {
  return selectedGifts.value.reduce((sum, g) => sum + g.cost_price * g.quantity, 0).toFixed(2)
})

const originalGiftsCostDisplay = computed(() => originalGiftsCost.value.toFixed(2))

// 本次新增成本 = 当前总成本 - 原有成本（可能为负数，表示减少了赠品）
const incrementCost = computed(() => {
  return Number(giftTotalCost.value) - originalGiftsCost.value
})

const incrementCostDisplay = computed(() => incrementCost.value.toFixed(2))

// 新增上限 = 主产品成本 × 百分比
const maxIncrementNum = computed(() => {
  return props.mainCostPrice * props.giftLimitPercent / 100
})

const maxIncrement = computed(() => {
  return maxIncrementNum.value.toFixed(2)
})

// 超限判断：首次配置不限制；编辑时只限制增量（增量 > 0 时才检查）
const isOverLimit = computed(() => {
  if (!hasExistingBundle.value) return false // 首次配置，无限制
  if (props.mainCostPrice <= 0) return false // 没有成本价，不限制
  if (incrementCost.value <= 0) return false // 减少了赠品，不限制
  return incrementCost.value > maxIncrementNum.value
})

const overBy = computed(() => {
  if (!isOverLimit.value) return 0
  return incrementCost.value - maxIncrementNum.value
})

function confirm() {
  emit('confirm', {
    gifts: selectedGifts.value.map(g => ({
      product_id: g.product_id,
      product_name: g.name,
      cost_price: g.cost_price,
      retail_price: g.retail_price,
      quantity: g.quantity,
    })),
    saveAsDefault: hasExistingBundle.value ? saveAsDefault.value : true,
  })
}
</script>
