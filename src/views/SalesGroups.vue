<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-xl font-bold text-gray-800">👥 销售分组管理</h1>
      <button @click="showCreateModal = true"
        class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
        + 创建分组
      </button>
    </div>

    <!-- Loading -->
    <Skeleton v-if="store.loading" type="card" :count="3" card-grid-class="grid-cols-1" />

    <template v-else>
      <!-- Group List -->
      <div class="space-y-4">
        <div v-for="group in store.groups" :key="group.id"
          class="bg-white rounded-xl border border-gray-100 overflow-hidden">
          <!-- Group Header -->
          <div class="px-5 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <span class="text-lg">🏷️</span>
              <div>
                <div class="font-semibold text-gray-800">{{ group.name }}</div>
                <div class="text-xs text-gray-500 mt-0.5">
                  创建于 {{ formatDate(group.created_at) }}
                </div>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs px-2.5 py-1 rounded-full"
                :class="group.status === 'active' ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500'">
                {{ group.status === 'active' ? '启用' : '停用' }}
              </span>
              <button @click="toggleStatus(group)"
                class="text-xs px-2 py-1 rounded hover:bg-gray-100 text-gray-500 cursor-pointer">
                {{ group.status === 'active' ? '停用' : '启用' }}
              </button>
              <button @click="openEditGroup(group)"
                class="text-xs px-2 py-1 rounded hover:bg-blue-50 text-blue-600 cursor-pointer">
                编辑
              </button>
              <button @click="confirmDelete(group)"
                class="text-xs px-2 py-1 rounded hover:bg-red-50 text-red-500 cursor-pointer">
                删除
              </button>
            </div>
          </div>

          <!-- Group Leader & Members -->
          <div class="px-5 pb-4">
            <div class="flex items-center gap-2 mb-3">
              <span class="text-sm text-gray-500">组长：</span>
              <span class="text-sm font-medium text-blue-700">{{ getLeaderName(group) || '未设置' }}</span>
              <span class="text-sm text-gray-300 mx-1">|</span>
              <span class="text-sm text-gray-500">组员：{{ getMemberCount(group) }} 人</span>
            </div>

            <!-- Action Buttons -->
            <div class="flex gap-2">
              <button @click="openMembers(group.id)"
                class="text-xs px-3 py-1.5 bg-gray-50 text-gray-600 rounded-lg hover:bg-gray-100 cursor-pointer">
                👥 查看组员
              </button>
              <button @click="openAddMember(group.id)"
                class="text-xs px-3 py-1.5 bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 cursor-pointer">
                + 添加组员
              </button>
              <button @click="openGroupPerformance(group.id)"
                class="text-xs px-3 py-1.5 bg-green-50 text-green-600 rounded-lg hover:bg-green-100 cursor-pointer">
                📊 组内业绩
              </button>
              <button @click="openSetTarget(group.id)"
                class="text-xs px-3 py-1.5 bg-orange-50 text-orange-600 rounded-lg hover:bg-orange-100 cursor-pointer">
                🎯 设定目标
              </button>
            </div>
          </div>
        </div>

        <div v-if="store.groups.length === 0" class="bg-white rounded-xl border border-gray-100 p-12 text-center">
          <div class="text-3xl mb-3">📋</div>
          <div class="text-gray-500 text-sm mb-4">暂无销售分组</div>
          <button @click="showCreateModal = true"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
            + 创建第一个分组
          </button>
        </div>
      </div>
    </template>

    <!-- Create/Edit Group Modal -->
    <div v-if="showCreateModal || showEditModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6">
        <h3 class="text-lg font-bold text-gray-800 mb-4">
          {{ showEditModal ? '编辑分组' : '创建分组' }}
        </h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">分组名称</label>
            <input v-model="groupForm.name" type="text" placeholder="例如：华南销售一组"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showCreateModal = false; showEditModal = false; editingGroup = null"
            class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg cursor-pointer">取消</button>
          <button @click="saveGroup" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">
            {{ showEditModal ? '保存' : '创建' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Members List Modal -->
    <div v-if="showMembersModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg p-6 max-h-[80vh] overflow-auto">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">👥 组员列表</h3>
          <button @click="showMembersModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <Skeleton v-if="membersLoading" type="card" :count="4" card-grid-class="grid-cols-1" />
        <div v-else class="space-y-2">
          <div v-for="m in store.members" :key="m.id"
            class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center text-sm font-medium">
                {{ (m.profile?.name || '?')[0] }}
              </div>
              <div>
                <div class="text-sm font-medium text-gray-800">{{ m.profile?.name || '未知' }}</div>
                <div class="text-xs text-gray-500">{{ m.profile?.phone || '' }} · {{ roleLabel(m.profile?.role) }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-xs px-2 py-0.5 rounded-full"
                :class="m.role === 'leader' ? 'bg-yellow-50 text-yellow-700' : 'bg-gray-50 text-gray-500'">
                {{ m.role === 'leader' ? '👑 组长' : '组员' }}
              </span>
              <button v-if="m.role !== 'leader'" @click="makeLeader(m)"
                class="text-xs px-2 py-1 text-blue-600 hover:bg-blue-50 rounded cursor-pointer">
                设为组长
              </button>
              <button @click="removeMemberConfirm(m)" class="text-xs px-2 py-1 text-red-500 hover:bg-red-50 rounded cursor-pointer">
                移除
              </button>
            </div>
          </div>
          <div v-if="store.members.length === 0" class="text-center py-6 text-gray-500 text-sm">暂无组员</div>
        </div>
      </div>
    </div>

    <!-- Add Member Modal -->
    <div v-if="showAddMemberModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 max-h-[80vh] overflow-auto">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">➕ 添加组员</h3>
          <button @click="showAddMemberModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <Skeleton v-if="usersLoading" type="card" :count="4" card-grid-class="grid-cols-1" />
        <div v-else class="space-y-1">
          <div v-for="u in availableUsers" :key="u.id"
            class="flex items-center justify-between p-3 rounded-lg hover:bg-gray-50">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center text-sm font-medium">
                {{ (u.name || '?')[0] }}
              </div>
              <div>
                <div class="text-sm font-medium text-gray-800">{{ u.name }}</div>
                <div class="text-xs text-gray-500">{{ roleLabel(u.role) }}</div>
              </div>
            </div>
            <button v-if="!isInGroup(u.id)" @click="addMember(u.id)"
              class="text-xs px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 cursor-pointer">
              添加
            </button>
            <span v-else class="text-xs text-gray-500">已加入</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Group Performance Modal -->
    <div v-if="showPerformanceModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl p-6 max-h-[85vh] overflow-auto">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">📊 组内业绩</h3>
          <button @click="showPerformanceModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>

        <!-- Month Selector -->
        <div class="mb-4">
          <input v-model="perfMonth" type="month"
            @change="loadGroupPerformance"
            class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
        </div>

        <Skeleton v-if="perfLoading" type="stats" :count="3" stats-grid-class="grid-cols-3" />
        <template v-else>
          <!-- Summary -->
          <div class="grid grid-cols-3 gap-4 mb-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-xs text-gray-500 mb-1">组总金额</div>
              <div class="text-xl font-bold text-green-600">{{ formatMoney(perfTotal.amount) }}</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-xs text-gray-500 mb-1">总订单数</div>
              <div class="text-xl font-bold text-blue-600">{{ perfTotal.orders }}</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-xs text-gray-500 mb-1">平均客单价</div>
              <div class="text-xl font-bold text-purple-600">{{ formatMoney(perfTotal.avg) }}</div>
            </div>
          </div>

          <!-- Table -->
          <table class="w-full text-sm">
            <thead>
              <tr class="bg-gray-50 text-gray-600">
                <th class="px-3 py-2 text-left font-medium">姓名</th>
                <th class="px-3 py-2 text-right font-medium">订单数</th>
                <th class="px-3 py-2 text-right font-medium">总金额</th>
                <th class="px-3 py-2 text-right font-medium">客单价</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in store.groupPerformance" :key="p.user_id" class="border-t border-gray-50">
                <td class="px-3 py-2 font-medium">{{ p.user_name }}</td>
                <td class="px-3 py-2 text-right">{{ p.total_orders }}</td>
                <td class="px-3 py-2 text-right text-green-600 font-semibold">{{ formatMoney(p.total_amount) }}</td>
                <td class="px-3 py-2 text-right text-gray-600">{{ formatMoney(p.avg_order_amount) }}</td>
              </tr>
              <tr v-if="store.groupPerformance.length === 0">
                <td colspan="4" class="px-3 py-6 text-center text-gray-500">暂无业绩数据</td>
              </tr>
            </tbody>
          </table>
        </template>
      </div>
    </div>

    <!-- Set Target Modal -->
    <div v-if="showTargetModal" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 max-h-[80vh] overflow-auto">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">🎯 设定销售目标</h3>
          <button @click="showTargetModal = false" class="text-gray-500 hover:text-gray-600 text-xl cursor-pointer">✕</button>
        </div>
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-600 mb-1">目标类型</label>
            <select v-model="targetForm.period_type" class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              <option value="monthly">月度目标</option>
              <option value="quarterly">季度目标</option>
            </select>
          </div>
          <div v-if="targetForm.period_type === 'monthly'">
            <label class="block text-sm text-gray-600 mb-1">月份</label>
            <input v-model="targetForm.period_value" type="month"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div v-else>
            <label class="block text-sm text-gray-600 mb-1">季度</label>
            <select v-model="targetForm.period_value"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              <option value="2026-Q1">2026 Q1</option>
              <option value="2026-Q2">2026 Q2</option>
              <option value="2026-Q3">2026 Q3</option>
              <option value="2026-Q4">2026 Q4</option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">组员</label>
            <select v-model="targetForm.user_id"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
              <option value="">请选择组员</option>
              <option v-for="m in store.members" :key="m.id" :value="m.user_id">
                {{ m.profile?.name || '未知' }} {{ m.role === 'leader' ? '(组长)' : '' }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">目标金额（元）</label>
            <input v-model.number="targetForm.target_amount" type="number" min="0" placeholder="0"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
          <div>
            <label class="block text-sm text-gray-600 mb-1">备注</label>
            <input v-model="targetForm.note" type="text" placeholder="可选"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button @click="showTargetModal = false" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg cursor-pointer">取消</button>
          <button @click="saveTarget" class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700 cursor-pointer">保存目标</button>
        </div>
      </div>
    </div>

    <!-- Confirm Delete Modal -->
    <div v-if="showDeleteConfirm" class="fixed inset-0 bg-black/40 z-50 flex items-center justify-center">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6">
        <h3 class="text-lg font-bold text-gray-800 mb-2">⚠️ 确认删除</h3>
        <p class="text-sm text-gray-600 mb-4">确定要删除分组「{{ deletingGroup?.name }}」吗？此操作不可恢复。</p>
        <div class="flex justify-end gap-2">
          <button @click="showDeleteConfirm = false" class="px-4 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg cursor-pointer">取消</button>
          <button @click="deleteGroup" class="px-4 py-2 bg-red-600 text-white rounded-lg text-sm hover:bg-red-700 cursor-pointer">删除</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useSalesGroupStore } from '../stores/salesGroup'
import { formatMoney, toast } from '../lib/utils'
import Skeleton from '../components/Skeleton.vue'

const store = useSalesGroupStore()

// Modals
const showCreateModal = ref(false)
const showEditModal = ref(false)
const showMembersModal = ref(false)
const showAddMemberModal = ref(false)
const showPerformanceModal = ref(false)
const showTargetModal = ref(false)
const showDeleteConfirm = ref(false)

// Forms
const groupForm = reactive({ name: '' })
const targetForm = reactive({ period_type: 'monthly', period_value: '', user_id: '', target_amount: 0, note: '' })
const editingGroup = ref(null)
const deletingGroup = ref(null)

// State
const membersLoading = ref(false)
const usersLoading = ref(false)
const perfLoading = ref(false)
const perfMonth = ref('')
const availableUsers = ref([])
const currentGroupId = ref(null)

const roleLabels = {
  sales: '销售', cs: '客服', finance: '财务', manager: '经理', admin: '管理员', hr: '人事', coach: '教练',
}

function roleLabel(role) { return roleLabels[role] || role }
function formatDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleDateString('zh-CN')
}

function getLeaderName(group) {
  const member = store.members.find(m => m.user_id === group.leader_id && m.group_id === group.id)
  if (member) return member.profile?.name
  return ''
}

function getMemberCount(group) {
  return store.members.filter(m => m.group_id === group.id).length || 0
}

function isInGroup(userId) {
  return store.members.some(m => m.user_id === userId && m.group_id === currentGroupId.value)
}

async function saveGroup() {
  if (!groupForm.name.trim()) {
    toast('请输入分组名称', 'warning')
    return
  }
  try {
    if (showEditModal.value && editingGroup.value) {
      await store.updateGroup(editingGroup.value.id, { name: groupForm.name.trim() })
      toast('分组已更新', 'success')
    } else {
      await store.createGroup({ name: groupForm.name.trim() })
      toast('分组已创建', 'success')
    }
    showCreateModal.value = false
    showEditModal.value = false
    editingGroup.value = null
    groupForm.name = ''
  } catch (e) {
    toast('操作失败: ' + (e.message || '未知错误'), 'error')
  }
}

function openEditGroup(group) {
  editingGroup.value = group
  groupForm.name = group.name
  showEditModal.value = true
}

async function toggleStatus(group) {
  const newStatus = group.status === 'active' ? 'inactive' : 'active'
  try {
    await store.updateGroup(group.id, { status: newStatus })
    toast(newStatus === 'active' ? '已启用' : '已停用', 'success')
  } catch (e) {
    toast('操作失败', 'error')
  }
}

function confirmDelete(group) {
  deletingGroup.value = group
  showDeleteConfirm.value = true
}

async function deleteGroup() {
  try {
    await store.deleteGroup(deletingGroup.value.id)
    toast('分组已删除', 'success')
    showDeleteConfirm.value = false
    deletingGroup.value = null
  } catch (e) {
    toast('删除失败: ' + (e.message || '未知错误'), 'error')
  }
}

async function openMembers(groupId) {
  currentGroupId.value = groupId
  membersLoading.value = true
  showMembersModal.value = true
  try {
    await store.fetchMembers(groupId)
  } catch (e) {
    toast('加载组员失败', 'error')
  } finally {
    membersLoading.value = false
  }
}

async function openAddMember(groupId) {
  currentGroupId.value = groupId
  usersLoading.value = true
  showAddMemberModal.value = true
  try {
    await store.fetchMembers(groupId)
    availableUsers.value = await store.getAvailableUsers()
  } catch (e) {
    toast('加载用户列表失败', 'error')
  } finally {
    usersLoading.value = false
  }
}

async function addMember(userId) {
  try {
    await store.addMember(currentGroupId.value, userId)
    toast('已添加组员', 'success')
  } catch (e) {
    toast('添加失败: ' + (e.message || '未知错误'), 'error')
  }
}

async function removeMemberConfirm(member) {
  if (!confirm(`确定要移除「${member.profile?.name}」吗？`)) return
  try {
    await store.removeMember(currentGroupId.value, member.user_id)
    toast('已移除组员', 'success')
  } catch (e) {
    toast('移除失败', 'error')
  }
}

async function makeLeader(member) {
  if (!confirm(`确定要将「${member.profile?.name}」设为组长吗？`)) return
  try {
    await store.setLeader(currentGroupId.value, member.user_id)
    toast('组长已更新', 'success')
  } catch (e) {
    toast('设置失败', 'error')
  }
}

async function openGroupPerformance(groupId) {
  currentGroupId.value = groupId
  const now = new Date()
  perfMonth.value = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  perfLoading.value = true
  showPerformanceModal.value = true
  try {
    await loadGroupPerformance()
  } finally {
    perfLoading.value = false
  }
}

async function loadGroupPerformance() {
  try {
    await store.fetchGroupPerformance(currentGroupId.value, perfMonth.value)
  } catch (e) {
    toast('加载业绩失败', 'error')
  }
}

const perfTotal = computed(() => {
  const data = store.groupPerformance
  if (!data.length) return { amount: 0, orders: 0, avg: 0 }
  const amount = data.reduce((s, r) => s + Number(r.total_amount), 0)
  const orders = data.reduce((s, r) => s + Number(r.total_orders), 0)
  return { amount, orders, avg: orders > 0 ? amount / orders : 0 }
})

async function openSetTarget(groupId) {
  currentGroupId.value = groupId
  membersLoading.value = true
  showTargetModal.value = true
  const now = new Date()
  targetForm.period_value = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
  targetForm.user_id = ''
  targetForm.target_amount = 0
  targetForm.note = ''
  try {
    await store.fetchMembers(groupId)
  } catch (e) {
    toast('加载组员失败', 'error')
  } finally {
    membersLoading.value = false
  }
}

async function saveTarget() {
  if (!targetForm.user_id) {
    toast('请选择组员', 'warning')
    return
  }
  if (!targetForm.target_amount || targetForm.target_amount <= 0) {
    toast('请输入目标金额', 'warning')
    return
  }
  try {
    // Upsert target
    const { error } = await supabase
      .from('sales_targets')
      .upsert({
        user_id: targetForm.user_id,
        period_type: targetForm.period_type,
        period_value: targetForm.period_value,
        target_amount: targetForm.target_amount,
        group_id: currentGroupId.value,
        status: 'in_progress',
      }, { onConflict: 'user_id,period_type,period_value' })

    if (error) throw error
    toast('目标已设定', 'success')
    showTargetModal.value = false
  } catch (e) {
    toast('保存失败: ' + (e.message || '未知错误'), 'error')
  }
}

onMounted(() => {
  store.fetchGroups()
})
</script>
