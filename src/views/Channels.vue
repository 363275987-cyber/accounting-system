<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-800">📱 客服号分配</h1>
        <p class="text-sm text-gray-500 mt-1">把微信客服号（及其对应的支付宝账户）分配给销售员</p>
      </div>
      <button @click="showAssignModal = true" 
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer">
        + 新建分配
      </button>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="filters.keyword" placeholder="搜索客服号或销售名" 
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500">
      <select v-model="filters.status" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部状态</option>
        <option value="active">活跃</option>
        <option value="released">已释放</option>
      </select>
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredAssignments.length }} 条</span>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-4 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">已分配客服号</div>
        <div class="text-2xl font-bold text-blue-600">{{ activeCount }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">销售员人数</div>
        <div class="text-2xl font-bold text-green-600">{{ salesCount }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">未分配账户</div>
        <div class="text-2xl font-bold text-orange-500">{{ unassignedCount }}</div>
      </div>
    </div>

    <!-- Assignments Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <div v-if="loading" class="p-12 text-center text-gray-500">加载中...</div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">客服号</th>
            <th class="px-4 py-3 text-left font-medium">平台</th>
            <th class="px-4 py-3 text-left font-medium">分配销售</th>
            <th class="px-4 py-3 text-left font-medium">分配时间</th>
            <th class="px-4 py-3 text-left font-medium">释放时间</th>
            <th class="px-4 py-3 text-center font-medium">状态</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in paginatedItems" :key="item.id" class="border-t border-gray-50 hover:bg-gray-50">
            <td class="px-4 py-3">
              <span class="bg-blue-50 text-blue-700 px-2 py-0.5 rounded text-xs font-medium">{{ item.account_code }}</span>
            </td>
            <td class="px-4 py-3 text-gray-500">
              <span>{{ PLATFORM_LABELS[item.platform] || item.platform }}</span>
            </td>
            <td class="px-4 py-3 text-gray-800">{{ item.sales_name || '—' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatDate(item.assigned_at) }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ item.released_at ? formatDate(item.released_at) : '—' }}</td>
            <td class="px-4 py-3 text-center">
              <span :class="item.status === 'active' 
                ? 'text-green-600 bg-green-50 px-2 py-0.5 rounded text-xs' 
                : 'text-gray-500 bg-gray-50 px-2 py-0.5 rounded text-xs'">
                {{ item.status === 'active' ? '活跃' : '已释放' }}
              </span>
            </td>
            <td class="px-4 py-3 text-center">
              <button v-if="item.status === 'active'" @click="releaseAssignment(item)" 
                class="text-orange-600 hover:text-orange-800 text-xs cursor-pointer mr-2">释放</button>
            </td>
          </tr>
          <tr v-if="filteredAssignments.length === 0">
            <td colspan="7" class="px-4 py-8 text-center text-gray-500">暂无分配数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="flex items-center justify-between mt-4 text-sm text-gray-500">
      <span>第 {{ currentPage }} / {{ totalPages }} 页</span>
      <div class="flex gap-2">
        <button @click="currentPage--" :disabled="currentPage <= 1" class="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-40 cursor-pointer">上一页</button>
        <button @click="currentPage++" :disabled="currentPage >= totalPages" class="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-40 cursor-pointer">下一页</button>
      </div>
    </div>

    <!-- Assign Modal -->
    <div v-if="showAssignModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showAssignModal = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 max-h-[85vh] flex flex-col overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 class="font-bold text-gray-800">新建客服号分配</h2>
          <button @click="showAssignModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleAssign" class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">选择客服号（微信/支付宝）</label>
            <select v-model="assignForm.account_id" required
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="">请选择账户</option>
              <optgroup label="微信">
                <option v-for="acc in wechatAccounts" :key="acc.id" :value="acc.id">{{ acc.code }}</option>
              </optgroup>
              <optgroup label="支付宝">
                <option v-for="acc in alipayAccounts" :key="acc.id" :value="acc.id">{{ acc.code }}</option>
              </optgroup>
              <optgroup label="银行卡">
                <option v-for="acc in bankAccounts" :key="acc.id" :value="acc.id">{{ acc.code }}</option>
              </optgroup>
              <optgroup v-for="(accs, ip) in accountsByIP" :key="ip" :label="'  ' + ip">
                <option v-for="acc in accs.filter(a => !['wechat','alipay','bank'].includes(a.platform))" :key="acc.id" :value="acc.id">{{ acc.code }}</option>
              </optgroup>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">分配给销售员</label>
            <select v-model="assignForm.sales_id" required
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="">请选择销售员</option>
              <option v-for="p in salesList" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
            <textarea v-model="assignForm.note" rows="2" placeholder="可选，如：该客服号当前由XX负责"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 resize-none"></textarea>
          </div>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showAssignModal = false" class="flex-1 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
            <button type="submit" :disabled="submitting" class="flex-1 py-2.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 cursor-pointer">
              {{ submitting ? '提交中...' : '确认分配' }}
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
import { useAuthStore } from '../stores/auth'
import { PLATFORM_LABELS, formatDate, toast } from '../lib/utils'

const auth = useAuthStore()
const loading = ref(false)
const submitting = ref(false)
const assignments = ref([])
const accounts = ref([])
const salesList = ref([])

const filters = reactive({ keyword: '', status: '' })
const currentPage = ref(1)
const pageSize = 20

const showAssignModal = ref(false)
const assignForm = ref({ account_id: '', sales_id: '', note: '' })

// 只展示 active 账户；accountsByIP 已按 status 过滤，这三组之前漏了 → 废弃账户会出现在分配下拉里
const wechatAccounts = computed(() => accounts.value.filter(a => a.platform === 'wechat' && a.status === 'active'))
const alipayAccounts = computed(() => accounts.value.filter(a => a.platform === 'alipay' && a.status === 'active'))
const bankAccounts = computed(() => accounts.value.filter(a => a.platform === 'bank' && a.status === 'active'))
const accountsByIP = computed(() => {
  const groups = {}
  for (const acc of accounts.value.filter(a => a.status === 'active' && !['wechat','alipay','bank'].includes(a.platform))) {
    if (!groups[acc.ip_code]) groups[acc.ip_code] = []
    groups[acc.ip_code].push(acc)
  }
  return groups
})

const activeCount = computed(() => assignments.value.filter(a => a.status === 'active').length)
const salesCount = computed(() => new Set(assignments.value.filter(a => a.status === 'active').map(a => a.sales_id)).size)
const unassignedCount = computed(() => {
  const assignedIds = new Set(assignments.value.filter(a => a.status === 'active').map(a => a.account_id))
  return accounts.value.filter(a => a.status === 'active' && !assignedIds.has(a.id)).length
})

const filteredAssignments = computed(() => {
  let list = assignments.value
  if (filters.keyword) {
    const kw = filters.keyword.toLowerCase()
    list = list.filter(a => (a.account_code || '').toLowerCase().includes(kw) || (a.sales_name || '').toLowerCase().includes(kw))
  }
  if (filters.status) list = list.filter(a => a.status === filters.status)
  return list
})

const totalPages = computed(() => Math.max(1, Math.ceil(filteredAssignments.value.length / pageSize)))
const paginatedItems = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return filteredAssignments.value.slice(start, start + pageSize)
})

async function loadData() {
  loading.value = true
  try {
    // profiles 表无 status 列（BUG-12 同因），仅按角色筛
    const [accRes, profRes, caRes] = await Promise.all([
      supabase.from('accounts').select('*').order('ip_code').order('sequence'),
      supabase.from('profiles').select('*').in('role', ['sales', 'cs']).order('name'),
      supabase.from('channel_assignments')
        .select('*, accounts!inner(code, ip_code, platform), profiles:sales_id(name)')
        .order('assigned_at', { ascending: false })
    ])
    accounts.value = accRes.data || []
    salesList.value = profRes.data || []
    assignments.value = (caRes.data || []).map(item => ({
      ...item,
      account_code: item.accounts?.code || '',
      platform: item.accounts?.platform || '',
      sales_name: item.profiles?.name || '',
    }))
  } catch (e) {
    console.error('[Channels] Failed to load data:', e)
    toast('渠道数据加载失败：' + (e?.message || e?.code || '未知错误'), 'error')
  } finally {
    loading.value = false
  }
}

onMounted(loadData)

async function handleAssign() {
  if (!assignForm.value.account_id || !assignForm.value.sales_id) return
  submitting.value = true
  try {
    // Release existing assignment for this account
    await supabase.from('channel_assignments')
      .update({ status: 'released', released_at: new Date().toISOString() })
      .eq('account_id', assignForm.value.account_id)
      .eq('status', 'active')

    // Create new assignment
    const { error } = await supabase.from('channel_assignments').insert({
      account_id: assignForm.value.account_id,
      sales_id: assignForm.value.sales_id,
      assigned_by: auth.profile?.id,
      note: assignForm.value.note || null,
    })
    if (error) throw error

    // Also update the account's sales_id for direct reference
    await supabase.from('accounts')
      .update({ sales_id: assignForm.value.sales_id })
      .eq('id', assignForm.value.account_id)

    showAssignModal.value = false
    assignForm.value = { account_id: '', sales_id: '', note: '' }
    await loadData()
    toast('客服号分配成功', 'success')
  } catch (e) {
    toast('分配失败：' + (e.message || '请重试'), 'error')
  } finally {
    submitting.value = false
  }
}

async function releaseAssignment(item) {
  try {
    const { error } = await supabase.from('channel_assignments')
      .update({ status: 'released', released_at: new Date().toISOString() })
      .eq('id', item.id)
    if (error) throw error
    // Also clear the account's sales_id
    if (item.account_id) {
      await supabase.from('accounts').update({ sales_id: null }).eq('id', item.account_id)
    }
    item.status = 'released'
    item.released_at = new Date().toISOString()
    toast('已释放', 'success')
  } catch (e) {
    toast('操作失败', 'error')
  }
}
</script>
