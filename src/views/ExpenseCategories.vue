<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-bold text-gray-800">🏷️ 支出类别管理</h1>
        <p class="text-sm text-gray-500 mt-1">管理支出分类，新增、编辑或停用类别</p>
      </div>
      <button @click="showCreateForm = !showCreateForm"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer">
        {{ showCreateForm ? '收起' : '+ 新增类别' }}
      </button>
    </div>

    <!-- 新增类别表单 -->
    <div v-if="showCreateForm" class="bg-white rounded-xl border border-gray-100 p-5 mb-4">
      <h2 class="font-semibold text-gray-800 mb-4">新增支出类别</h2>
      <form @submit.prevent="handleCreate" class="flex gap-3 items-end">
        <div class="flex-1">
          <label class="block text-sm font-medium text-gray-700 mb-1">类别名称 <span class="text-red-400">*</span></label>
          <input v-model="newName" placeholder="请输入类别名称" required maxlength="50"
            class="w-full px-3 py-2.5 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <button type="submit" :disabled="creating"
          class="bg-blue-600 text-white px-6 py-2.5 rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50 cursor-pointer whitespace-nowrap">
          {{ creating ? '创建中...' : '确认添加' }}
        </button>
      </form>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-3 gap-4 mb-4">
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">类别总数</div>
        <div class="text-2xl font-bold text-blue-600">{{ categories.length }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">启用</div>
        <div class="text-2xl font-bold text-green-600">{{ activeCount }}</div>
      </div>
      <div class="bg-white rounded-xl border border-gray-100 p-5">
        <div class="text-sm text-gray-500 mb-1">停用</div>
        <div class="text-2xl font-bold text-gray-500">{{ inactiveCount }}</div>
      </div>
    </div>

    <!-- 搜索 -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="searchKeyword" placeholder="搜索类别名称"
        class="px-3 py-2 border border-gray-200 rounded-lg text-sm w-60 outline-none focus:ring-2 focus:ring-blue-500" />
      <select v-model="statusFilter" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none cursor-pointer">
        <option value="">全部状态</option>
        <option value="active">启用</option>
        <option value="inactive">停用</option>
      </select>
      <span class="text-sm text-gray-500 ml-auto">共 {{ filteredList.length }} 条</span>
    </div>

    <!-- 列表 -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <Skeleton v-if="loading" type="table" :rows="5" :columns="4" />
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">类别名称</th>
            <th class="px-4 py-3 text-left font-medium">状态</th>
            <th class="px-4 py-3 text-left font-medium">创建时间</th>
            <th class="px-4 py-3 text-left font-medium">更新时间</th>
            <th class="px-4 py-3 text-center font-medium">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in filteredList" :key="item.id" class="border-t border-gray-50 hover:bg-gray-50">
            <!-- 名称列：编辑模式 -->
            <td class="px-4 py-3" v-if="editingId === item.id">
              <div class="flex items-center gap-2">
                <input v-model="editName" @keyup.enter="saveEdit(item)" @keyup.escape="cancelEdit"
                  class="px-2 py-1.5 border border-blue-300 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500 w-40"
                  ref="editInput" />
                <button @click="saveEdit(item)" class="text-green-600 hover:text-green-800 text-xs cursor-pointer">保存</button>
                <button @click="cancelEdit" class="text-gray-500 hover:text-gray-600 text-xs cursor-pointer">取消</button>
              </div>
            </td>
            <!-- 名称列：普通模式 -->
            <td class="px-4 py-3 text-gray-800 font-medium" v-else>{{ item.name }}</td>
            <!-- 状态 -->
            <td class="px-4 py-3">
              <span :class="item.status === 'active'
                ? 'text-green-600 bg-green-50 px-2 py-0.5 rounded text-xs'
                : 'text-gray-500 bg-gray-100 px-2 py-0.5 rounded text-xs'">
                {{ item.status === 'active' ? '启用' : '停用' }}
              </span>
            </td>
            <!-- 创建时间 -->
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatDate(item.created_at) }}</td>
            <!-- 更新时间 -->
            <td class="px-4 py-3 text-gray-500 text-xs whitespace-nowrap">{{ formatDate(item.updated_at) }}</td>
            <!-- 操作 -->
            <td class="px-4 py-3 text-center whitespace-nowrap" v-if="editingId !== item.id">
              <button @click="startEdit(item)"
                class="text-blue-600 hover:text-blue-800 text-xs cursor-pointer mr-3">编辑</button>
              <button v-if="item.status === 'active'" @click="toggleStatus(item)"
                class="text-orange-600 hover:text-orange-800 text-xs cursor-pointer mr-3">停用</button>
              <button v-else @click="toggleStatus(item)"
                class="text-green-600 hover:text-green-800 text-xs cursor-pointer mr-3">启用</button>
              <button @click="handleDelete(item)"
                class="text-red-500 hover:text-red-700 text-xs cursor-pointer">删除</button>
            </td>
          </tr>
          <tr v-if="!loading && filteredList.length === 0">
            <td colspan="5" class="px-4 py-8 text-center text-gray-500">
              {{ searchKeyword || statusFilter ? '没有匹配的类别' : '暂无支出类别数据' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { formatDate, toast } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'

const loading = ref(false)
const creating = ref(false)
const showCreateForm = ref(false)
const categories = ref([])
const searchKeyword = ref('')
const statusFilter = ref('')

// 新增类别
const newName = ref('')

// 编辑
const editingId = ref(null)
const editName = ref('')
const editInput = ref(null)

// 统计
const activeCount = computed(() => categories.value.filter(c => c.status === 'active').length)
const inactiveCount = computed(() => categories.value.filter(c => c.status === 'inactive').length)

// 过滤
const filteredList = computed(() => {
  let list = categories.value
  if (searchKeyword.value) {
    const kw = searchKeyword.value.toLowerCase()
    list = list.filter(c => c.name.toLowerCase().includes(kw))
  }
  if (statusFilter.value) {
    list = list.filter(c => c.status === statusFilter.value)
  }
  return list
})

// 加载数据
async function loadData() {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .select('*')
      .order('created_at', { ascending: true })
    if (error) throw error
    categories.value = data || []
  } catch (e) {
    console.error('加载支出类别失败:', e)
    toast('加载支出类别失败：' + (e?.message || e?.code || '未知错误'), 'error')
  } finally {
    loading.value = false
  }
}

// 新增类别
async function handleCreate() {
  const name = newName.value.trim()
  if (!name) return
  creating.value = true
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .insert({ name })
      .select()
      .single()
    if (error) {
      if (error.code === '23505') {
        toast('该类别名称已存在', 'warning')
      } else {
        throw error
      }
      return
    }
    categories.value.push(data)
    newName.value = ''
    toast('类别已添加', 'success')
  } catch (e) {
    toast('添加失败：' + (e.message || ''), 'error')
  } finally {
    creating.value = false
  }
}

// 编辑
async function startEdit(item) {
  editingId.value = item.id
  editName.value = item.name
  await nextTick()
  if (editInput.value) {
    const input = Array.isArray(editInput.value) ? editInput.value[0] : editInput.value
    if (input) input.focus()
  }
}

function cancelEdit() {
  editingId.value = null
  editName.value = ''
}

async function saveEdit(item) {
  const name = editName.value.trim()
  if (!name) {
    toast('类别名称不能为空', 'warning')
    return
  }
  if (name === item.name) {
    cancelEdit()
    return
  }
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .update({ name })
      .eq('id', item.id)
      .select()
      .single()
    if (error) {
      if (error.code === '23505') {
        toast('该类别名称已存在', 'warning')
      } else {
        throw error
      }
      return
    }
    item.name = data.name
    item.updated_at = data.updated_at
    cancelEdit()
    toast('类别已更新', 'success')
  } catch (e) {
    toast('更新失败：' + (e.message || ''), 'error')
  }
}

// 切换状态
async function toggleStatus(item) {
  const newStatus = item.status === 'active' ? 'inactive' : 'active'
  const action = newStatus === 'inactive' ? '停用' : '启用'
  if (!confirm(`确认要${action}「${item.name}」吗？`)) return
  try {
    const { data, error } = await supabase
      .from('expense_categories')
      .update({ status: newStatus })
      .eq('id', item.id)
      .select()
      .single()
    if (error) throw error
    item.status = data.status
    item.updated_at = data.updated_at
    toast(`已${action}`, 'success')
  } catch (e) {
    toast('操作失败', 'error')
  }
}

// 删除
async function handleDelete(item) {
  // 检查是否有支出记录引用该类别
  try {
    const { count, error: countError } = await supabase
      .from('expenses')
      .select('id', { count: 'exact', head: true })
      .is('deleted_at', null)
      .eq('category', item.name)
    if (countError) throw countError

    if (count > 0) {
      toast(`该类别下有 ${count} 条支出记录，无法删除。请先停用该类别。`, 'warning')
      return
    }
  } catch (e) {
    toast('检查失败，请稍后重试', 'error')
    return
  }

  if (!confirm(`确认要删除「${item.name}」吗？此操作不可恢复。`)) return

  try {
    const { error } = await supabase
      .from('expense_categories')
      .delete()
      .eq('id', item.id)
    if (error) throw error
    categories.value = categories.value.filter(c => c.id !== item.id)
    toast('类别已删除', 'success')
  } catch (e) {
    toast('删除失败：' + (e.message || ''), 'error')
  }
}

onMounted(loadData)
</script>
