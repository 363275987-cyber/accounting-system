<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-800">📱 客服号管理</h1>
        <p class="text-sm text-gray-500 mt-1">管理微信客服号，将手机和微信分配给销售员</p>
      </div>
      <div class="flex items-center gap-2">
        <button @click="showCreateForm = !showCreateForm"
          class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer">
          {{ showCreateForm ? '收起' : '+ 批量创建' }}
        </button>
        <button @click="triggerImport"
          class="bg-green-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-700 transition cursor-pointer"><Icon name="download" class="inline w-4 h-4 -mt-0.5 mr-1" /> Excel导入
        </button>
        <input ref="fileInput" type="file" accept=".xlsx,.xls,.csv" class="hidden" @change="handleImport" />
      </div>
    </div>

    <!-- 批量创建表单 -->
    <div v-if="showCreateForm" class="bg-white rounded-xl border border-gray-100 p-5 mb-4">
      <h2 class="font-semibold text-gray-800 mb-4">批量创建客服号</h2>
      <form @submit.prevent="handleBatchCreate" class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">编号前缀 <span class="text-red-400">*</span></label>
          <input v-model="createForm.prefix" placeholder="如：南" required
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">起始编号 <span class="text-red-400">*</span></label>
          <input v-model.number="createForm.start" type="number" placeholder="如：1" required min="1"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">数量 <span class="text-red-400">*</span></label>
          <input v-model.number="createForm.count" type="number" placeholder="如：100" required min="1" max="500"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">分配给销售员</label>
          <select v-model="createForm.sales_id"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
            <option value="">不分配</option>
            <option v-for="s in salesList" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div class="col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">备注</label>
          <input v-model="createForm.note" placeholder="可选备注"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div class="col-span-2">
          <button type="submit" :disabled="creating"
            class="bg-blue-600 text-white px-6 py-2.5 rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 cursor-pointer">
            {{ creating ? '创建中...' : '批量创建' }}
          </button>
        </div>
      </form>
    </div>

    <!-- Excel导入预览弹窗 -->
    <div v-if="showImportPreview" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showImportPreview = false">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[80vh] flex flex-col mx-4">
        <div class="flex items-center justify-between p-5 border-b border-gray-100">
          <div>
            <h2 class="font-semibold text-gray-800"><Icon name="download" class="inline w-4 h-4 -mt-0.5 mr-1" /> Excel导入预览</h2>
            <p class="text-xs text-gray-500 mt-1">已解析 {{ importData.length }} 条，可编辑后提交</p>
          </div>
          <button @click="showImportPreview = false" class="text-gray-500 hover:text-gray-600 text-lg cursor-pointer">✕</button>
        </div>
        <!-- 表格预览 -->
        <div class="flex-1 overflow-auto p-4">
          <table class="w-full text-xs">
            <thead class="sticky top-0">
              <tr class="bg-gray-50">
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">编号</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">微信昵称</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">实名</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">身份证</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">开户行</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">银行卡号</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">预留手机</th>
                <th class="px-2 py-2 text-left font-medium text-gray-500 border-b">备注</th>
                <th class="px-2 py-2 text-center font-medium text-red-500 border-b">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, idx) in importData" :key="idx" class="border-b border-gray-50 hover:bg-gray-50/50">
                <td><input v-model="row.code" class="w-16 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.wechat_name" class="w-20 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.verified_name" class="w-16 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.id_number" class="w-28 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.bank_name" class="w-20 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.bank_card_number" class="w-32 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.bank_phone" class="w-24 px-1 py-1 border rounded text-xs" /></td>
                <td><input v-model="row.note" class="w-20 px-1 py-1 border rounded text-xs" /></td>
                <td class="text-center"><button @click="importData.splice(idx, 1)" class="text-red-400 hover:text-red-600 cursor-pointer">✕</button></td>
              </tr>
            </tbody>
          </table>
          <p v-if="importData.length === 0" class="text-center text-gray-500 py-8">未解析到有效数据</p>
        </div>
        <div class="p-4 border-t border-gray-100 flex items-center justify-between">
          <span class="text-xs text-gray-500">只显示前100条，共解析 {{ importTotal }} 条</span>
          <div class="flex gap-2">
            <button @click="showImportPreview = false" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm cursor-pointer">取消</button>
            <button @click="submitImport" :disabled="importing"
              class="px-6 py-2 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 disabled:opacity-50 cursor-pointer">
              {{ importing ? '导入中...' : '✅ 确认导入' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-3 gap-4 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">客服号总数</div>
        <div class="text-2xl font-bold text-blue-600">{{ stats.total }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">活跃</div>
        <div class="text-2xl font-bold text-green-600">{{ stats.active }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">未分配</div>
        <div class="text-2xl font-bold text-orange-500">{{ stats.unassigned }}</div>
      </div>
    </div>

    <!-- 搜索 -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="searchKeyword" placeholder="搜索客服号或销售名"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500" />
      <select v-model="statusFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部状态</option>
        <option value="active">活跃</option>
        <option value="inactive">停用</option>
      </select>
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredList.length }} 条</span>
    </div>

    <!-- 列表 -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <Skeleton v-if="loading" type="table" :rows="6" :columns="4" />
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">编号</th>
            <th class="px-4 py-3 text-left font-medium">分配销售</th>
            <th class="px-4 py-3 text-left font-medium">状态</th>
            <th class="px-4 py-3 text-left font-medium">创建时间</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="item in paginatedItems" :key="item.id">
            <tr class="border-t border-gray-50 hover:bg-gray-50">
              <td class="px-4 py-3">
                <span class="bg-blue-50 text-blue-700 px-2 py-0.5 rounded text-xs font-medium">{{ item.code }}</span>
              </td>
              <td class="px-4 py-3 text-gray-800">{{ item.sales_name || '—' }}</td>
              <td class="px-4 py-3 text-center">
                <span :class="item.status === 'active'
                  ? 'text-green-600 bg-green-50 px-2 py-0.5 rounded text-xs'
                  : 'text-gray-500 bg-gray-100 px-2 py-0.5 rounded text-xs'">
                  {{ item.status === 'active' ? '活跃' : '停用' }}
                </span>
              </td>
              <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatDate(item.created_at) }}</td>
              <td class="px-4 py-3 text-center">
                <div class="flex items-center justify-center gap-3">
                  <button v-if="item.status === 'active'" @click="toggleStatus(item)"
                    class="text-orange-600 hover:text-orange-800 text-xs cursor-pointer">停用</button>
                  <button v-else @click="toggleStatus(item)"
                    class="text-green-600 hover:text-green-800 text-xs cursor-pointer">重新激活</button>
                  <button v-if="authStore.isFinance" @click="openEditModal(item)"
                    class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer">编辑</button>
                </div>
              </td>
            </tr>
            <!-- 实名认证信息（仅 finance/admin/manager 可见） -->
            <tr v-if="authStore.isFinance" class="border-t border-gray-50 bg-gray-50/50">
              <td colspan="5" class="px-4 py-2">
                <div class="flex flex-wrap gap-x-6 gap-y-1 text-xs text-gray-500">
                  <span>微信号：<span class="text-gray-700">{{ item.wechat_name || '—' }}</span></span>
                  <span>认证人：<span class="text-gray-700">{{ item.verified_name || '—' }}</span></span>
                  <span>身份证号：<span class="text-gray-700">{{ item.id_number || '—' }}</span></span>
                  <span>银行卡：<span class="text-gray-700">{{ item.bank_name || '—' }} {{ item.bank_card_number || '' }}</span></span>
                  <span>预留手机：<span class="text-gray-700">{{ item.bank_phone || '—' }}</span></span>
                </div>
              </td>
            </tr>
          </template>
          <tr v-if="!loading && filteredList.length === 0">
            <td colspan="5" class="px-4 py-8 text-center text-gray-500">暂无客服号数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- 分页 -->
    <div v-if="totalPages > 1" class="flex items-center justify-between mt-4 text-sm text-gray-500">
      <span>第 {{ currentPage }} / {{ totalPages }} 页</span>
      <div class="flex gap-2">
        <button @click="currentPage--" :disabled="currentPage <= 1" class="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-40 cursor-pointer">上一页</button>
        <button @click="currentPage++" :disabled="currentPage >= totalPages" class="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-40 cursor-pointer">下一页</button>
      </div>
    </div>

    <!-- 编辑实名认证信息弹窗 -->
    <div v-if="showEditModal" class="fixed inset-0 z-50 flex items-center justify-center">
      <!-- 遮罩 -->
      <div class="absolute inset-0 bg-black/40" @click="showEditModal = false"></div>
      <!-- 弹窗 -->
      <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-lg mx-4 p-6">
        <div class="flex items-center justify-between mb-5">
          <h2 class="text-lg font-bold text-gray-800">编辑实名认证信息 — {{ editingItem?.code }}</h2>
          <button @click="showEditModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="saveEditForm" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">微信号</label>
            <input v-model="editForm.wechat_name" placeholder="请输入微信号"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">认证人姓名</label>
            <input v-model="editForm.verified_name" placeholder="请输入认证人姓名"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">身份证号</label>
            <input v-model="editForm.id_number" placeholder="请输入身份证号"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">银行卡名称</label>
              <input v-model="editForm.bank_name" placeholder="如：工商银行"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">银行卡号</label>
              <input v-model="editForm.bank_card_number" placeholder="请输入银行卡号"
                class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">预留手机号</label>
            <input v-model="editForm.bank_phone" placeholder="请输入预留手机号"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div class="flex justify-end gap-3 pt-2">
            <button type="button" @click="showEditModal = false"
              class="px-4 py-2 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
            <button type="submit" :disabled="saving"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 cursor-pointer">
              {{ saving ? '保存中...' : '保存' }}
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
import { formatDate, formatMoney, toast, debounce } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'
import Icon from '../components/icons/Icons.vue'

const authStore = useAuthStore()
const loading = ref(false)
const creating = ref(false)
const saving = ref(false)
const showCreateForm = ref(false)
const serviceNumbers = ref([])
const salesList = ref([])
const fileInput = ref(null)

// Excel导入
const showImportPreview = ref(false)
const importing = ref(false)
const importData = ref([])
const importTotal = ref(0)

function triggerImport() {
  fileInput.value?.click()
}

// 列名映射（中英文都支持）
const COLUMN_MAP = {
  code: ['编号', '客服号', 'code', '序号'],
  wechat_name: ['微信昵称', '微信号', 'wechat_name', '昵称'],
  verified_name: ['实名', '真实姓名', 'verified_name', '姓名'],
  id_number: ['身份证', '身份证号', 'id_number', 'idcard'],
  bank_name: ['开户行', '银行名称', 'bank_name'],
  bank_card_number: ['银行卡号', 'bank_card', 'bank_card_number'],
  bank_phone: ['预留手机', '银行预留手机', 'bank_phone', '手机号'],
  note: ['备注', '说明', 'note'],
}

function normalizeColumnName(name) {
  const lower = (name || '').trim().toLowerCase().replace(/\s+/g, '')
  for (const [field, aliases] of Object.entries(COLUMN_MAP)) {
    for (const alias of aliases) {
      if (lower === alias.toLowerCase()) return field
    }
  }
  return null
}

async function handleImport(e) {
  const file = e.target.files?.[0]
  if (!file) return
  importing.value = true
  try {
    // 使用 SheetJS CDN
    if (!window.XLSX) {
      const script = document.createElement('script')
      script.src = 'https://cdn.sheetjs.com/xlsx-0.20.1/package/dist/xlsx.full.min.js'
      script.onload = () => parseFile(file)
      document.head.appendChild(script)
    } else {
      parseFile(file)
    }
  } catch (err) {
    toast('文件读取失败', 'error')
  } finally {
    importing.value = false
    e.target.value = ''
  }
}

async function parseFile(file) {
    const reader = new FileReader()
    reader.onload = (ev) => {
      try {
        const wb = XLSX.read(ev.target.result, { type: 'binary' })
        const ws = wb.Sheets[wb.SheetNames[0]]
        const rows = XLSX.utils.sheet_to_json(ws, { raw: false, defval: '' })
        const parsed = []
        for (const row of rows) {
          const obj = { code: '', wechat_name: '', verified_name: '', id_number: '', bank_name: '', bank_card_number: '', bank_phone: '', note: '' }
          for (const [key, val] of Object.entries(row)) {
            const field = normalizeColumnName(key)
            if (field && field !== 'note') obj[field] = String(val || '').trim()
            else if (!field) {
              // 未知列，放到备注里
              const existing = obj.note ? obj.note + ' | ' : ''
              obj.note = existing + `${key}: ${val}`
            }
          }
          // 至少有编号才算有效行
          if (obj.code) parsed.push(obj)
        }
        importTotal.value = parsed.length
        importData.value = parsed.slice(0, 100)
        showImportPreview.value = true
        if (parsed.length > 0) toast(`解析成功，共 ${parsed.length} 条`, 'success')
        else toast('未找到有效数据（请确保有"编号"列）', 'warning')
      } catch (err) {
        console.error('Excel解析失败:', err)
        toast('文件解析失败，请检查格式', 'error')
      }
    }
    reader.readAsBinaryString(file)
  }

  async function submitImport() {
    if (importData.value.length === 0) return
    importing.value = true
    try {
    let success = 0, failed = 0
    for (const row of importData.value) {
      if (!row.code) { failed++; continue }
      try {
        const { error } = await supabase.from('service_numbers').upsert({
          code: row.code,
          wechat_name: row.wechat_name || null,
          verified_name: row.verified_name || null,
          id_number: row.id_number || null,
          bank_name: row.bank_name || null,
          bank_card_number: row.bank_card_number || null,
          bank_phone: row.bank_phone || null,
          note: row.note || null,
          status: 'active',
        }, { onConflict: 'code' })
        if (error) {
          if (error.message.includes('duplicate')) {
            await supabase.from('service_numbers').update({
              wechat_name: row.wechat_name || null,
              verified_name: row.verified_name || null,
              id_number: row.id_number || null,
              bank_name: row.bank_name || null,
              bank_card_number: row.bank_card_number || null,
              bank_phone: row.bank_phone || null,
              note: row.note || null,
            }).eq('code', row.code)
            success++
          } else { failed++ }
        } else { success++ }
      } catch (e) { failed++ }
    }
    showImportPreview.value = false
    importData.value = []
    await loadServiceNumbers()
    toast(`导入完成：成功 ${success}，失败 ${failed}`, success > 0 ? 'success' : 'warning')
    } finally {
      importing.value = false
    }
  }

// 批量创建表单
const createForm = reactive({ prefix: '南', start: 1, count: 100, sales_id: '', note: '' })

// 搜索和过滤
const searchKeyword = ref('')
const statusFilter = ref('')
const currentPage = ref(1)
const pageSize = 20

// 编辑弹窗
const showEditModal = ref(false)
const editingItem = ref(null)
const editForm = reactive({
  wechat_name: '',
  verified_name: '',
  id_number: '',
  bank_name: '',
  bank_card_number: '',
  bank_phone: '',
})

// 统计
const stats = computed(() => ({
  total: serviceNumbers.value.length,
  active: serviceNumbers.value.filter(s => s.status === 'active').length,
  unassigned: serviceNumbers.value.filter(s => !s.sales_id && s.status === 'active').length,
}))

// 过滤列表
const filteredList = computed(() => {
  let list = serviceNumbers.value
  if (searchKeyword.value) {
    const kw = searchKeyword.value.toLowerCase()
    list = list.filter(s => (s.code || '').toLowerCase().includes(kw) || (s.sales_name || '').toLowerCase().includes(kw))
  }
  if (statusFilter.value) list = list.filter(s => s.status === statusFilter.value)
  return list
})

// 分页
const totalPages = computed(() => Math.max(1, Math.ceil(filteredList.value.length / pageSize)))
const paginatedItems = computed(() => {
  const start = (currentPage.value - 1) * pageSize
  return filteredList.value.slice(start, start + pageSize)
})

// 从客服号 code 提取前缀和序号
function parseCode(code) {
  // code 格式: "南1", "北23" 等 — 前缀是第一个字符，序号是后面的数字
  const match = code.match(/^(\D+)(\d+)$/)
  if (match) return { prefix: match[1], sequence: parseInt(match[2]) }
  return { prefix: '', sequence: null }
}

// 加载数据
async function loadData() {
  loading.value = true
  try {
    // profiles 表无 status 列（BUG-12 同因），仅按角色筛
    const [snRes, salesRes] = await Promise.all([
      supabase.from('service_numbers').select('*').order('code'),
      supabase.from('profiles').select('*').in('role', ['sales', 'cs', 'manager']).order('name'),
    ])
    serviceNumbers.value = snRes.data || []
    salesList.value = salesRes.data || []
  } catch (e) {
    console.error('加载客服号失败:', e)
    toast('加载客服号失败：' + (e?.message || e?.code || '未知错误'), 'error')
  } finally {
    loading.value = false
  }
}

// 批量创建
async function handleBatchCreate() {
  const { prefix, start, count, sales_id, note } = createForm
  if (!prefix || !start || !count) return

  const endNum = start + count - 1
  const msg = `将创建 ${prefix}${start}~${prefix}${endNum} 共 ${count} 个客服号（同时自动创建对应的微信收款账户），确认？`
  if (!confirm(msg)) return

  creating.value = true
  try {
    // ⚠️ 参数名必须与 DB 函数签名完全一致：prefix/start/count/sales_id/note
    // (BUG-13 历史记录称改成 p_ 前缀，但实测云端函数仍是无前缀版本)
    const { data, error } = await supabase.rpc('batch_create_service_numbers', {
      prefix,
      start,
      count,
      sales_id: sales_id || null,
      note: note || null,
    })
    if (error) throw error
    toast(`成功创建 ${count} 个客服号及对应的微信收款账户`, 'success')
    showCreateForm.value = false
    createForm.prefix = '南'
    createForm.start = 1
    createForm.count = 100
    createForm.sales_id = ''
    createForm.note = ''
    await loadData()
  } catch (e) {
    toast('创建失败：' + (e.message || ''), 'error')
  } finally {
    creating.value = false
  }
}

// 切换状态（含余额检查）
async function toggleStatus(item) {
  const newStatus = item.status === 'active' ? 'inactive' : 'active'
  const action = newStatus === 'inactive' ? '停用' : '重新激活'

  // 停用时检查关联微信账户余额
  if (newStatus === 'inactive') {
    try {
      const { prefix, sequence } = parseCode(item.code)
      if (prefix && sequence !== null) {
        const { data: accounts, error } = await supabase
          .from('accounts')
          .select('balance')
          .eq('ip_code', prefix)
          .eq('sequence', sequence)
          .eq('platform', 'wechat')
        if (!error && accounts && accounts.length > 0) {
          const totalBalance = accounts.reduce((sum, a) => sum + (parseFloat(a.balance) || 0), 0)
          if (totalBalance > 0) {
            toast(`该客服号关联的微信账户还有余额 ${formatMoney(totalBalance)}，请先处理余额后再停用`, 'warning', 5000)
            return
          }
        }
      }
    } catch (e) {
      console.error('余额检查失败:', e)
      // 检查失败时仍然允许操作，避免阻断
    }
  }

  if (!confirm(`确认要${action} ${item.code} 吗？`)) return
  try {
    const { error } = await supabase
      .from('service_numbers')
      .update({ status: newStatus })
      .eq('id', item.id)
    if (error) throw error
    item.status = newStatus
    toast(`已${action}`, 'success')
  } catch (e) {
    toast('操作失败', 'error')
  }
}

// 打开编辑弹窗
function openEditModal(item) {
  editingItem.value = item
  editForm.wechat_name = item.wechat_name || ''
  editForm.verified_name = item.verified_name || ''
  editForm.id_number = item.id_number || ''
  editForm.bank_name = item.bank_name || ''
  editForm.bank_card_number = item.bank_card_number || ''
  editForm.bank_phone = item.bank_phone || ''
  showEditModal.value = true
}

// 保存编辑
async function saveEditForm() {
  if (!editingItem.value) return
  saving.value = true
  try {
    const { error } = await supabase
      .from('service_numbers')
      .update({
        wechat_name: editForm.wechat_name || null,
        verified_name: editForm.verified_name || null,
        id_number: editForm.id_number || null,
        bank_name: editForm.bank_name || null,
        bank_card_number: editForm.bank_card_number || null,
        bank_phone: editForm.bank_phone || null,
      })
      .eq('id', editingItem.value.id)
    if (error) throw error

    // 更新本地数据
    const item = serviceNumbers.value.find(s => s.id === editingItem.value.id)
    if (item) {
      item.wechat_name = editForm.wechat_name || null
      item.verified_name = editForm.verified_name || null
      item.id_number = editForm.id_number || null
      item.bank_name = editForm.bank_name || null
      item.bank_card_number = editForm.bank_card_number || null
      item.bank_phone = editForm.bank_phone || null
    }

    showEditModal.value = false
    toast('保存成功', 'success')
  } catch (e) {
    toast('保存失败：' + (e.message || ''), 'error')
  } finally {
    saving.value = false
  }
}

onMounted(loadData)
</script>
