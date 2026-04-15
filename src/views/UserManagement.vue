<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">👥 用户管理</h1>
      <button v-if="canCreate" @click="openCreateModal" 
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer">
        + 添加员工
      </button>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="search" placeholder="搜索姓名/邮箱/手机"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500"
        @input="debouncedSearch">
      <select v-model="filters.role" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
        <option value="">全部角色</option>
        <option v-for="(label, key) in allRoles" :key="key" :value="key">{{ label }}</option>
      </select>
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredUsers.length }} 人</span>
    </div>

    <!-- Users Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <Skeleton v-if="loading" type="table" :rows="6" :columns="7" />
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">姓名</th>
            <th class="px-4 py-3 text-left font-medium">角色</th>
            <th class="px-4 py-3 text-left font-medium">部门</th>
            <th class="px-4 py-3 text-left font-medium">IP</th>
            <th class="px-4 py-3 text-left font-medium">手机</th>
            <th class="px-4 py-3 text-center font-medium">状态</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in filteredUsers" :key="u.id" class="border-t border-gray-50 hover:bg-gray-50/60 transition">
            <td class="px-4 py-3 font-medium text-gray-800">{{ u.name }}</td>
            <td class="px-4 py-3">
              <span class="text-xs px-2 py-0.5 rounded-full font-medium"
                :class="roleClass(u.role)">
                {{ roleLabel(u.role) }}
              </span>
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ u.department || '—' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ u.ip_code || '—' }}</td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ u.phone || '—' }}</td>
            <td class="px-4 py-3 text-center">
              <span class="text-green-600 bg-green-50 px-2 py-0.5 rounded-full text-xs font-medium">在职</span>
            </td>
            <td class="px-4 py-3 text-center whitespace-nowrap" v-if="canManage">
              <span class="text-gray-400 text-xs">—</span>
            </td>
          </tr>
          <tr v-if="filteredUsers.length === 0">
            <td colspan="7" class="px-4 py-12 text-center text-gray-500">暂无用户数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Note about creation -->
    <div v-if="canCreate" class="mt-4 bg-yellow-50 border border-yellow-200 rounded-xl p-4 text-sm text-yellow-800">
      <p class="font-medium mb-1">📌 添加员工说明</p>
      <p>填写邮箱和姓名后，系统会创建账号并设置默认密码 <code class="bg-yellow-100 px-1 rounded">Test123456</code>。
      新员工首次登录后请自行修改密码。如遇问题，可在 Supabase 后台手动创建。</p>
    </div>

    <!-- Create User Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black/30 flex items-center justify-center z-50" @click.self="showCreateModal = false">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 max-h-[85vh] flex flex-col overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between shrink-0">
          <h2 class="font-bold text-gray-800">➕ 添加员工</h2>
          <button @click="showCreateModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">&times;</button>
        </div>
        <form @submit.prevent="handleCreate" class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">姓名 <span class="text-red-400">*</span></label>
            <input v-model="form.name" placeholder="员工姓名" required
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">邮箱 <span class="text-red-400">*</span></label>
            <input v-model="form.email" type="email" placeholder="employee@company.com" required
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
            <p class="text-xs text-gray-500 mt-1">新员工会收到邮件邀请，点击链接设置密码</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">角色</label>
            <select v-model="form.role" 
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="sales">销售员</option>
              <option value="cs">客服（电商）</option>
              <option value="finance">财务</option>
              <option value="manager">经理</option>
              <option value="hr">人事</option>
              <option value="coach">教练</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">部门</label>
            <select v-model="form.department" 
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer">
              <option value="">请选择</option>
              <option value="IP部">IP部</option>
              <option value="销售部">销售部</option>
              <option value="客服部">客服部</option>
              <option value="财务部">财务部</option>
              <option value="管理部">管理部</option>
              <option value="剪辑部">剪辑部</option>
              <option value="引流部">引流部</option>
              <option value="设计部">设计部</option>
              <option value="仓储部">仓储部</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">手机号</label>
            <input v-model="form.phone" placeholder="选填" type="tel"
              class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showCreateModal = false"
              class="flex-1 py-2.5 border border-gray-200 rounded-lg text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">取消</button>
            <button type="submit" :disabled="submitting"
              class="flex-1 py-2.5 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer">
              {{ submitting ? '创建中...' : '创建账号' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { toast, debounce } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'

const auth = useAuthStore()
const loading = ref(true)
const submitting = ref(false)
const search = ref('')
const users = ref([])
const showCreateModal = ref(false)

const filters = reactive({ role: '' })

const allRoles = {
  sales: '销售员',
  cs: '客服（电商）',
  finance: '财务',
  manager: '经理',
  admin: '管理员',
  hr: '人事',
  coach: '教练',
}

const roleClassMap = {
  sales: 'bg-blue-50 text-blue-700',
  cs: 'bg-gray-100 text-gray-600',
  finance: 'bg-green-50 text-green-700',
  manager: 'bg-purple-50 text-purple-700',
  admin: 'bg-red-50 text-red-700',
  hr: 'bg-teal-50 text-teal-700',
  coach: 'bg-indigo-50 text-indigo-700',
}

const canCreate = computed(() => auth.isAdmin || auth.isFinance || auth.isHR)
const canManage = computed(() => auth.isAdmin || auth.isFinance)

const filteredUsers = computed(() => {
  return users.value.filter(u => {
    if (filters.role && u.role !== filters.role) return false
    if (search.value) {
      const kw = search.value.toLowerCase()
      return [u.name, u.phone].some(f => f?.toLowerCase().includes(kw))
    }
    return true
  })
})

const debouncedSearch = debounce(() => {}, 300)

const form = reactive({
  name: '',
  email: '',
  role: 'sales',
  department: '',
  phone: '',
})

function roleLabel(role) {
  return allRoles[role] || role
}

function roleClass(role) {
  return roleClassMap[role] || 'bg-gray-50 text-gray-600'
}

function openCreateModal() {
  form.name = ''
  form.email = ''
  form.role = 'sales'
  form.department = ''
  form.phone = ''
  showCreateModal.value = true
}

async function loadUsers() {
  loading.value = true
  try {
    // profiles 表无 status 列，不再查询 status
    const { data, error } = await supabase
      .from('profiles')
      .select('id, name, role, phone, email, department, created_at')
      .order('created_at', { ascending: false })
    if (error) throw error
    // 过滤掉台球训练的学生（只显示公司相关角色）
    const companyRoles = ['sales', 'cs', 'finance', 'manager', 'admin', 'hr', 'coach']
    users.value = (data || []).filter(u => companyRoles.includes(u.role))
  } catch (e) {
    console.error('加载用户失败:', e)
    toast('加载用户列表失败：' + (e.message || ''), 'error')
  } finally {
    loading.value = false
  }
}

async function handleCreate() {
  if (!form.name || !form.email) return
  submitting.value = true
  try {
    // 使用 RPC 在服务端创建用户（避免 signUp 替换当前 session）
    const { data: rpcData, error: rpcError } = await supabase.rpc('admin_create_user', {
      p_email: form.email,
      p_password: 'Test123456',
      p_name: form.name,
      p_role: form.role,
      p_department: form.department || null,
      p_phone: form.phone || null,
    })

    if (rpcError || !rpcData?.success) {
      const msg = rpcData?.error || rpcError?.message || '未知错误'
      if (msg.includes('already') || msg.includes('exists') || msg.includes('registered')) {
        toast('该邮箱已注册', 'error')
      } else {
        toast('创建失败：' + msg, 'error')
      }
      return
    }

    toast(`员工 ${form.name} 创建成功（密码：Test123456）`, 'success')
    showCreateModal.value = false

    // 刷新用户列表
    loadUsers()
  } catch (e) {
    console.error(e)
    toast('创建失败: ' + (e.message || ''), 'error')
  } finally {
    submitting.value = false
  }
}

// profiles 表无 status 列，停用/启用功能暂不支持
async function toggleStatus(_user, _newStatus) {
  toast('暂不支持启用/停用：profiles 表无 status 列', 'info')
}

onMounted(loadUsers)
</script>
