<template>
  <div>
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800"><Icon name="package" class="inline w-4 h-4 -mt-0.5 mr-1" /> 仓库管理</h1>
      <button
        @click="openModal()"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition cursor-pointer"
      ><Icon name="plus" class="inline w-4 h-4 -mt-0.5 mr-1" /> 新建仓库
      </button>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="bg-white rounded-xl border border-gray-100 p-12 text-center text-gray-500 text-sm">
      加载中...
    </div>

    <!-- Warehouse Table -->
    <div v-else class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-100 bg-gray-50/50">
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">仓库名称</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">编码</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">类型</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">平台</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">地址</th>
            <th class="text-left px-4 py-3 text-xs font-medium text-gray-500">状态</th>
            <th class="text-right px-4 py-3 text-xs font-medium text-gray-500">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="store.warehouses.length === 0">
            <td colspan="7" class="px-4 py-12 text-center text-gray-500">
              暂无仓库数据
            </td>
          </tr>
          <tr
            v-for="wh in store.warehouses"
            :key="wh.id"
            class="border-b border-gray-50 hover:bg-gray-50/50 transition"
          >
            <td class="px-4 py-3 font-medium text-gray-800">{{ wh.name }}</td>
            <td class="px-4 py-3 text-gray-500 font-mono text-xs">{{ wh.code }}</td>
            <td class="px-4 py-3">
              <span
                class="inline-block px-2 py-0.5 rounded-full text-xs font-medium"
                :class="typeClass(wh.type)"
              >
                {{ TYPE_LABELS[wh.type] || wh.type }}
              </span>
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs">
              {{ wh.platform ? PLATFORM_LABELS[wh.platform] : '--' }}
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs max-w-[200px] truncate">{{ wh.address || '--' }}</td>
            <td class="px-4 py-3">
              <span
                class="inline-block px-2 py-0.5 rounded-full text-xs font-medium"
                :class="wh.is_active ? 'bg-green-50 text-green-600' : 'bg-gray-100 text-gray-500'"
              >
                {{ wh.is_active ? '启用' : '停用' }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <button
                @click="openModal(wh)"
                class="text-blue-500 hover:text-blue-700 text-xs mr-3 cursor-pointer"
              >
                编辑
              </button>
              <button
                @click="toggleStatus(wh)"
                class="text-xs cursor-pointer mr-3"
                :class="wh.is_active ? 'text-orange-500 hover:text-orange-700' : 'text-green-500 hover:text-green-700'"
              >
                {{ wh.is_active ? '停用' : '启用' }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/40" @click="showModal = false"></div>
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">
          {{ editingId ? '编辑仓库' : '新建仓库' }}
        </h2>

        <div class="space-y-4">
          <!-- 名称 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">仓库名称 <span class="text-red-400">*</span></label>
            <input
              v-model="form.name"
              placeholder="如：主仓库"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <!-- 编码 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">仓库编码 <span class="text-red-400">*</span></label>
            <input
              v-model="form.code"
              placeholder="如：WH001"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <!-- 类型 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">仓库类型 <span class="text-red-400">*</span></label>
            <select
              v-model="form.type"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择</option>
              <option value="physical">实体仓</option>
              <option value="virtual">☁️ 虚拟仓</option>
              <option value="platform">📱 平台仓</option>
            </select>
          </div>

          <!-- 平台（平台仓时显示） -->
          <div v-if="form.type === 'platform'">
            <label class="block text-sm text-gray-500 mb-1">平台 <span class="text-red-400">*</span></label>
            <select
              v-model="form.platform"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">请选择</option>
              <option v-for="(label, key) in PLATFORM_LABELS" :key="key" :value="key">
                {{ PLATFORM_ICONS[key] || '' }} {{ label }}
              </option>
            </select>
          </div>

          <!-- 地址 -->
          <div>
            <label class="block text-sm text-gray-500 mb-1">地址</label>
            <input
              v-model="form.address"
              placeholder="仓库地址（选填）"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>
        </div>

        <!-- Actions -->
        <div class="flex justify-end gap-3 mt-6">
          <button
            @click="showModal = false"
            class="px-4 py-2 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition"
          >
            取消
          </button>
          <button
            @click="saveWarehouse"
            :disabled="saving"
            class="px-4 py-2 text-sm text-white bg-blue-600 rounded-lg hover:bg-blue-700 cursor-pointer transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ saving ? '保存中...' : '保存' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { usePermission } from '../composables/usePermission'
import Icon from '../components/icons/Icons.vue'

const { canDelete, loadRole } = usePermission()
import { useInventoryStore } from '../stores/inventory'
import { PLATFORM_LABELS } from '../lib/utils'

const store = useInventoryStore()

const TYPE_LABELS = {
  physical: '实体仓',
  virtual: '虚拟仓',
  platform: '平台仓',
}

// PLATFORM_LABELS 已从 utils.js 统一导入

const PLATFORM_ICONS = {
  douyin: '🎵',
  kuaishou: '⚡',
  weixin_video: '💬',
  taobao: '🛒',
  jd: '🐶',
  pdd: '🔴',
}

const showModal = ref(false)
const editingId = ref(null)
const saving = ref(false)

const defaultForm = { name: '', code: '', type: '', platform: '', address: '' }
const form = reactive({ ...defaultForm })

function typeClass(type) {
  const map = {
    physical: 'bg-blue-50 text-blue-600',
    virtual: 'bg-purple-50 text-purple-600',
    platform: 'bg-orange-50 text-orange-600',
  }
  return map[type] || 'bg-gray-100 text-gray-500'
}

function openModal(warehouse = null) {
  if (warehouse) {
    editingId.value = warehouse.id
    Object.assign(form, {
      name: warehouse.name || '',
      code: warehouse.code || '',
      type: warehouse.type || '',
      platform: warehouse.platform || '',
      address: warehouse.address || '',
    })
  } else {
    editingId.value = null
    Object.assign(form, { ...defaultForm })
  }
  showModal.value = true
}

async function saveWarehouse() {
  if (!form.name || !form.code || !form.type) {
    alert('请填写必填字段：名称、编码、类型')
    return
  }
  if (form.type === 'platform' && !form.platform) {
    alert('平台仓请选择所属平台')
    return
  }

  saving.value = true
  try {
    const payload = {
      name: form.name,
      code: form.code,
      type: form.type,
      platform: form.type === 'platform' ? form.platform : null,
      address: form.address || null,
      is_active: true,
    }

    if (editingId.value) {
      await store.updateWarehouse(editingId.value, payload)
      alert('仓库已更新')
    } else {
      await store.createWarehouse(payload)
      alert('仓库已创建')
    }
    showModal.value = false
  } catch (e) {
    alert('操作失败：' + (e.message || '未知错误'))
  } finally {
    saving.value = false
  }
}

async function toggleStatus(warehouse) {
  const action = warehouse.is_active ? '停用' : '启用'
  if (!confirm(`确认${action}仓库「${warehouse.name}」？`)) return

  try {
    await store.updateWarehouse(warehouse.id, { is_active: !warehouse.is_active })
    alert(`仓库已${action}`)
  } catch (e) {
    alert('操作失败：' + (e.message || '未知错误'))
  }
}

onMounted(() => {
  store.fetchWarehouses()
})
</script>
