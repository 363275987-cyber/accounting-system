<template>
  <div>
    <!-- Summary Cards -->
    <div class="grid grid-cols-2 gap-3 md:gap-4 mb-4 md:mb-6">
      <div class="bg-white rounded-xl border border-gray-100 p-4 md:p-5">
        <div class="text-sm text-gray-500 mb-1">本月其他收入总额</div>
        <div class="text-2xl font-bold text-green-600">{{ formatMoney(stats.monthTotal) }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-4 md:p-5">
        <div class="text-sm text-gray-500 mb-1">本月笔数</div>
        <div class="text-2xl font-bold text-green-600">{{ stats.monthCount }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-3 md:p-4 mb-4">
      <div class="flex gap-2 md:gap-3 items-center flex-wrap">
        <div class="relative flex items-center">
          <input
            v-model="filters.search"
            placeholder="搜索描述"
            class="px-3 py-2 pr-9 border border-gray-200 rounded-lg text-sm w-full md:w-52 outline-none focus:ring-2 focus:ring-blue-500"
            @keyup.enter="loadPage(1)"
          />
          <button @click="loadPage(1)" class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-600 cursor-pointer" title="搜索">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
          </button>
        </div>
        <select
          v-model="filters.category"
          class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0 cursor-pointer"
          @change="loadPage(1)"
        >
          <option value="">全部类别</option>
          <option v-for="(label, key) in OTHER_INCOME_CATEGORIES" :key="key" :value="key">{{ label }}</option>
        </select>
        <input
          v-model="filters.dateFrom"
          type="date"
          class="px-2 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0"
          @change="loadPage(1)"
        >
        <input
          v-model="filters.dateTo"
          type="date"
          class="px-2 py-2 border border-gray-200 rounded-lg text-sm outline-none flex-shrink-0"
          @change="loadPage(1)"
        >
        <button
          v-if="hasActiveFilters"
          @click="resetFilters"
          class="text-sm text-blue-600 hover:text-blue-700 cursor-pointer flex-shrink-0 whitespace-nowrap"
        >
          清除
        </button>
      </div>
      <div class="text-sm text-gray-500 mt-2 text-right">{{ pagination.total }} 条</div>
    </div>

    <!-- Action Bar -->
    <div class="flex justify-end mb-4">
      <button
        @click="openCreateModal"
        class="bg-blue-600 text-white px-3 md:px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer whitespace-nowrap"
      >
        + 新建
      </button>
    </div>

    <!-- Desktop Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden hidden md:block">
      <!-- Loading skeleton -->
      <div v-if="loading && records.length === 0" class="p-6 space-y-3">
        <div v-for="i in 5" :key="i" class="h-10 bg-gray-100 rounded animate-pulse"></div>
      </div>

      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">时间</th>
            <th class="px-4 py-3 text-left font-medium">类别</th>
            <th class="px-4 py-3 text-right font-medium">金额</th>
            <th class="px-4 py-3 text-left font-medium">描述</th>
            <th class="px-4 py-3 text-left font-medium">收款账户</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="record in records"
            :key="record.id"
            class="border-t border-gray-50 hover:bg-gray-50/70 transition cursor-pointer"
            @click="openEditModal(record)"
          >
            <td class="px-4 py-3 text-gray-500 whitespace-nowrap">
              {{ formatDate(record.created_at) }}
            </td>
            <td class="px-4 py-3">
              <span class="bg-green-50 text-green-700 px-2 py-0.5 rounded text-xs font-medium">
                {{ OTHER_INCOME_CATEGORIES[record.category] || record.category }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <span class="font-medium text-green-600">{{ formatMoney(record.amount) }}</span>
            </td>
            <td class="px-4 py-3 text-gray-800">
              <div class="line-clamp-1">{{ record.description || '--' }}</div>
            </td>
            <td class="px-4 py-3 text-gray-600 text-sm">
              {{ getAccountName(record.account_id) }}
            </td>
            <td class="px-4 py-3 text-center whitespace-nowrap" @click.stop>
              <button
                @click="openEditModal(record)"
                class="text-blue-600 hover:text-blue-700 text-xs font-medium mr-2 cursor-pointer"
              >
                编辑
              </button>
              <button
                @click="handleDelete(record)"
                class="text-red-400 hover:text-red-600 text-xs px-2 py-1 rounded hover:bg-red-50 transition cursor-pointer"
              >
                删除
              </button>
            </td>
          </tr>

          <!-- Empty State -->
          <tr v-if="records.length === 0 && !loading">
            <td colspan="6" class="px-4 py-12 text-center">
              <div class="text-4xl mb-3">📭</div>
              <div class="text-gray-500">暂无其他收入记录</div>
              <div class="text-xs text-gray-300 mt-1">点击右上角新建收入</div>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination (desktop) -->
      <div
        v-if="pagination.total > pagination.pageSize"
        class="border-t border-gray-100 px-4 py-3 flex items-center justify-between"
      >
        <span class="text-xs text-gray-500">
          第 {{ (pagination.page - 1) * pagination.pageSize + 1 }}-{{ Math.min(pagination.page * pagination.pageSize, pagination.total) }} 条
        </span>
        <div class="flex gap-1">
          <button
            @click="loadPage(pagination.page - 1)"
            :disabled="pagination.page <= 1"
            class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
          >
            上一页
          </button>
          <template v-for="p in visiblePages" :key="p">
            <button
              v-if="p !== '...'"
              @click="loadPage(p)"
              :class="[
                'px-3 py-1.5 text-xs rounded-lg cursor-pointer',
                p === pagination.page
                  ? 'bg-blue-600 text-white'
                  : 'border border-gray-200 hover:bg-gray-50'
              ]"
            >
              {{ p }}
            </button>
            <span v-else class="px-1 text-gray-500 text-xs">...</span>
          </template>
          <button
            @click="loadPage(pagination.page + 1)"
            :disabled="pagination.page >= totalPages"
            class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
          >
            下一页
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile Card List -->
    <div class="md:hidden space-y-2">
      <div v-if="loading && records.length === 0" class="space-y-2">
        <div v-for="i in 5" :key="i" class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="h-4 w-24 bg-gray-100 rounded animate-pulse mb-2"></div>
          <div class="h-6 w-32 bg-gray-100 rounded animate-pulse"></div>
        </div>
      </div>
      <div
        v-for="record in records"
        :key="'m-' + record.id"
        class="bg-white rounded-xl border border-gray-100 p-3 shadow-sm"
        @click="openEditModal(record)"
      >
        <div class="flex items-center justify-between mb-2">
          <span class="bg-green-50 text-green-700 px-2 py-0.5 rounded text-xs font-medium">
            {{ OTHER_INCOME_CATEGORIES[record.category] || record.category }}
          </span>
          <span class="font-semibold text-green-600 text-sm">{{ formatMoney(record.amount) }}</span>
        </div>
        <div class="flex items-center justify-between mb-1">
          <span class="text-xs text-gray-500 line-clamp-1 flex-1 mr-2">{{ record.description || '--' }}</span>
          <span class="text-xs text-gray-400 flex-shrink-0">{{ getAccountName(record.account_id) }}</span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-xs text-gray-500">{{ formatDate(record.created_at) }}</span>
          <div class="flex items-center gap-2" @click.stop>
            <button @click="openEditModal(record)" class="text-blue-600 text-xs px-2 py-1 rounded hover:bg-blue-50 cursor-pointer">编辑</button>
            <button @click="handleDelete(record)" class="text-red-400 text-xs px-2 py-1 rounded hover:bg-red-50 cursor-pointer">删除</button>
          </div>
        </div>
      </div>
      <div v-if="records.length === 0 && !loading" class="bg-white rounded-xl border border-gray-100 p-8 text-center text-gray-500">
        <div class="text-4xl mb-3">📭</div>
        <div>暂无其他收入记录</div>
      </div>

      <!-- Mobile Pagination -->
      <div v-if="pagination.total > pagination.pageSize" class="flex items-center justify-center gap-2 pt-2">
        <button
          @click="loadPage(pagination.page - 1)"
          :disabled="pagination.page <= 1"
          class="px-3 py-2 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
        >上一页</button>
        <span class="text-xs text-gray-500">{{ pagination.page }} / {{ totalPages }}</span>
        <button
          @click="loadPage(pagination.page + 1)"
          :disabled="pagination.page >= totalPages"
          class="px-3 py-2 text-xs rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
        >下一页</button>
      </div>
    </div>

    <!-- Create / Edit Modal -->
    <div
      v-if="showModal"
      class="fixed inset-0 bg-black/30 flex items-center justify-center z-50"
      @click.self="showModal = false"
    >
      <div class="bg-white rounded-none md:rounded-2xl shadow-2xl w-full md:max-w-lg md:mx-4 overflow-hidden flex flex-col">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
          <h2 class="font-bold text-gray-800">{{ editingId ? '编辑其他收入' : '新建其他收入' }}</h2>
          <button @click="showModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleSubmit" class="p-6 space-y-4">
          <!-- Category -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">收入类别 <span class="text-red-500">*</span></label>
            <select
              v-model="form.category"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
              required
            >
              <option value="" disabled>选择类别</option>
              <option v-for="(label, key) in OTHER_INCOME_CATEGORIES" :key="key" :value="key">{{ label }}</option>
            </select>
          </div>

          <!-- Amount -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">金额 <span class="text-red-500">*</span></label>
            <input
              v-model.number="form.amount"
              type="number"
              step="0.01"
              min="0.01"
              placeholder="输入金额"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>

          <!-- Description -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">描述</label>
            <textarea
              v-model="form.description"
              rows="3"
              placeholder="备注说明"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"
            ></textarea>
          </div>

          <!-- Account -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">收款账户</label>
            <SearchableSelect
              v-model="form.account_id"
              :options="activeAccounts"
              label-key="code"
              value-key="id"
              placeholder="选择收款账户"
              search-placeholder="搜索账户..."
            />
          </div>

          <!-- Date -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">日期</label>
            <input
              v-model="form.date"
              type="date"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <!-- Submit -->
          <div class="flex justify-end gap-3 pt-2">
            <button
              type="button"
              @click="showModal = false"
              class="px-4 py-2 border border-gray-200 text-gray-600 rounded-lg text-sm hover:bg-gray-50 cursor-pointer"
            >
              取消
            </button>
            <button
              type="submit"
              :disabled="submitting"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ submitting ? '提交中...' : (editingId ? '保存' : '创建') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAccountStore } from '../stores/accounts'
import { useAuthStore } from '../stores/auth'
import SearchableSelect from '../components/SearchableSelect.vue'
import { formatMoney, formatDate, OTHER_INCOME_CATEGORIES, toast } from '../lib/utils'

const accountStore = useAccountStore()
const authStore = useAuthStore()

function getAccountName(id) {
  if (!id) return '--'
  const acc = accountStore.accounts.find(a => a.id === id)
  return acc ? (acc.short_name || acc.code || acc.name) : '--'
}

const activeAccounts = computed(() => {
  return accountStore.accounts
    .filter(a => a.status === 'active')
    .map(a => ({
      ...a,
      code: `${a.short_name || a.code}（¥${Number(a.balance || 0).toFixed(2)}）`,
    }))
})

// --- State ---
const loading = ref(false)
const records = ref([])
const pagination = reactive({
  page: 1,
  pageSize: 20,
  total: 0,
})

// --- Stats ---
const stats = reactive({
  monthTotal: 0,
  monthCount: 0,
})

const now = new Date()
const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

async function fetchStats() {
  try {
    const { data } = await supabase
      .from('other_income')
      .select('amount')
      .is('deleted_at', null)
      .gte('created_at', monthStart)
    if (data) {
      stats.monthTotal = data.reduce((s, r) => s + (Number(r.amount) || 0), 0)
      stats.monthCount = data.length
    }
  } catch (e) {
    console.error('Failed to fetch stats:', e)
  }
}

// --- Filters ---
const filters = reactive({
  search: '',
  category: '',
  dateFrom: '',
  dateTo: '',
})

const hasActiveFilters = computed(() => {
  return filters.search || filters.category || filters.dateFrom || filters.dateTo
})

function resetFilters() {
  filters.search = ''
  filters.category = ''
  filters.dateFrom = ''
  filters.dateTo = ''
  loadPage(1)
}

// --- Pagination ---
const totalPages = computed(() => {
  return Math.ceil(pagination.total / pagination.pageSize) || 1
})

const visiblePages = computed(() => {
  const total = totalPages.value
  const current = pagination.page
  const pages = []
  if (total <= 7) {
    for (let i = 1; i <= total; i++) pages.push(i)
  } else {
    pages.push(1)
    if (current > 3) pages.push('...')
    const start = Math.max(2, current - 1)
    const end = Math.min(total - 1, current + 1)
    for (let i = start; i <= end; i++) pages.push(i)
    if (current < total - 2) pages.push('...')
    pages.push(total)
  }
  return pages
})

// --- Load Data ---
async function loadPage(page = 1) {
  loading.value = true
  try {
    const from = (page - 1) * pagination.pageSize
    const to = from + pagination.pageSize - 1

    let query = supabase
      .from('other_income')
      .select('*', { count: 'exact' })
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .range(from, to)

    if (filters.category) {
      query = query.eq('category', filters.category)
    }
    if (filters.dateFrom) {
      query = query.gte('created_at', filters.dateFrom)
    }
    if (filters.dateTo) {
      const end = new Date(filters.dateTo)
      end.setDate(end.getDate() + 1)
      query = query.lt('created_at', end.toISOString().slice(0, 10))
    }
    if (filters.search) {
      const safe = filters.search.replace(/[,%().*]/g, '')
      if (safe) {
        query = query.ilike('description', `%${safe}%`)
      }
    }

    const { data, count, error } = await query
    if (error) throw error

    records.value = data || []
    pagination.total = count || 0
    pagination.page = page
  } catch (e) {
    console.error('Failed to load other income:', e)
    toast('加载失败：' + (e.message || ''), 'error')
  } finally {
    loading.value = false
  }
}

// --- Modal ---
const showModal = ref(false)
const editingId = ref(null)
const submitting = ref(false)

const form = reactive({
  category: '',
  amount: null,
  description: '',
  account_id: '',
  date: new Date().toISOString().slice(0, 10),
})

function openCreateModal() {
  editingId.value = null
  form.category = ''
  form.amount = null
  form.description = ''
  form.account_id = ''
  form.date = new Date().toISOString().slice(0, 10)
  showModal.value = true
}

function openEditModal(record) {
  editingId.value = record.id
  form.category = record.category || ''
  form.amount = record.amount
  form.description = record.description || ''
  form.account_id = record.account_id || ''
  form.date = record.created_at ? new Date(record.created_at).toISOString().slice(0, 10) : new Date().toISOString().slice(0, 10)
  showModal.value = true
}

async function handleSubmit() {
  if (!form.category || !form.amount) {
    toast('请填写类别和金额', 'warning')
    return
  }
  submitting.value = true
  try {
    const payload = {
      category: form.category,
      amount: Number(form.amount),
      description: form.description || null,
      account_id: form.account_id || null,
      created_at: form.date ? new Date(form.date).toISOString() : new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    if (editingId.value) {
      // Update
      const { error } = await supabase
        .from('other_income')
        .update(payload)
        .eq('id', editingId.value)
      if (error) throw error
      toast('更新成功', 'success')
    } else {
      // Create
      payload.recorded_by = authStore.profile?.id || null
      const { error } = await supabase
        .from('other_income')
        .insert(payload)
      if (error) throw error
      toast('创建成功', 'success')
    }

    showModal.value = false
    await loadPage(pagination.page)
    await fetchStats()
  } catch (e) {
    console.error('Submit failed:', e)
    toast('操作失败：' + (e.message || ''), 'error')
  } finally {
    submitting.value = false
  }
}

// --- Delete (soft) ---
async function handleDelete(record) {
  if (!confirm('确认删除这条收入记录？')) return
  try {
    const { error } = await supabase
      .from('other_income')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', record.id)
    if (error) throw error
    toast('已删除', 'success')
    await loadPage(pagination.page)
    await fetchStats()
  } catch (e) {
    console.error('Delete failed:', e)
    toast('删除失败：' + (e.message || ''), 'error')
  }
}

// --- Init ---
onMounted(async () => {
  if (accountStore.accounts.length === 0) {
    await accountStore.fetchAccounts()
  }
  await Promise.all([loadPage(1), fetchStats()])
})
</script>
