<template>
  <div>
    <div class="flex items-center gap-3 mb-6">
      <button @click="$router.back()" class="text-gray-500 hover:text-gray-700 transition cursor-pointer">
        ← 返回
      </button>
      <h1 class="text-xl font-bold text-gray-800"><Icon name="building" class="inline w-4 h-4 -mt-0.5 mr-1" /> 账户详情</h1>
    </div>

    <!-- Account Info -->
    <div v-if="account" class="bg-white rounded-xl border border-gray-100 p-6 mb-6">
      <div class="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <div>
          <div class="text-xs text-gray-500 mb-1">账户标识</div>
          <div class="font-semibold text-gray-800">{{ account.code }}</div>
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-1">收款平台</div>
          <div class="text-gray-700">{{ platformLabel(account.platform) }}</div>
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-1">余额</div>
          <div class="text-lg font-bold text-green-600">{{ formatMoney(account.balance) }}</div>
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-1">状态</div>
          <span :class="account.status === 'active' ? 'text-green-600 bg-green-50' : 'text-gray-500 bg-gray-100'" class="px-2 py-0.5 rounded text-xs font-medium">
            {{ account.status === 'active' ? '正常' : '已冻结' }}
          </span>
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-1">负责人</div>
          <div class="text-gray-700">{{ account.owner_name || '—' }}</div>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-100 p-4 mb-4 flex gap-3 items-center flex-wrap">
      <input v-model="dateFrom" type="date" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
      <span class="text-gray-300">~</span>
      <input v-model="dateTo" type="date" class="px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-blue-500">
      <button @click="loadRecords" :disabled="loading" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm hover:bg-gray-200 transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">{{ loading ? '加载中…' : '筛选' }}</button>
      <span class="text-sm text-gray-500 ml-auto">共 {{ records.length }} 条记录</span>
    </div>

    <!-- Records Table -->
    <div class="bg-white rounded-xl border border-gray-100 overflow-hidden">
      <div v-if="loading" class="p-12 text-center text-gray-500 text-sm">加载中…</div>
      <table v-else class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50 text-gray-600">
            <th class="px-4 py-3 text-left font-medium">时间</th>
            <th class="px-4 py-3 text-center font-medium">类型</th>
            <th class="px-4 py-3 text-right font-medium">金额</th>
            <th class="px-4 py-3 text-left font-medium">关联信息</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in records" :key="r.id" class="border-t border-gray-50 hover:bg-gray-50/60">
            <td class="px-4 py-3 text-gray-500 whitespace-nowrap">{{ formatDate(r.created_at) }}</td>
            <td class="px-4 py-3 text-center">
              <span :class="r.typeClass" class="px-2 py-0.5 rounded text-xs font-medium">{{ r.typeLabel }}</span>
            </td>
            <td class="px-4 py-3 text-right font-medium whitespace-nowrap" :class="r.amount >= 0 ? 'text-green-600' : 'text-red-600'">
              {{ r.amount >= 0 ? '+' : '' }}{{ formatMoney(r.amount) }}
            </td>
            <td class="px-4 py-3 text-gray-500 text-xs">{{ r.detail }}</td>
          </tr>
          <tr v-if="records.length === 0 && !loading">
            <td colspan="4" class="px-4 py-12 text-center text-gray-500">暂无记录</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { formatMoney, toast, formatDate, PLATFORM_LABELS } from '../lib/utils'
import { loadAccountLedgerRecords } from '../lib/accountFlows'
import Icon from '../components/icons/Icons.vue'

const route = useRoute()
const accountId = route.params.id
const loading = ref(true)
const account = ref(null)
const records = ref([])
const dateFrom = ref('')
const dateTo = ref('')

// PLATFORM_LABELS 已从 utils.js 统一导入
function platformLabel(p) { return PLATFORM_LABELS[p] || p || '' }

onMounted(() => {
  loadAccount()
  loadRecords()
})

async function loadAccount() {
  const { data, error } = await supabase
    .from('accounts')
    .select('*, profiles!owner_id(display_name, name)')
    .eq('id', accountId)
    .eq('status', 'active')
    .single()
  if (error || !data) {
    toast('账户不存在', 'error')
    return
  }
  account.value = {
    ...data,
    owner_name: data.profiles?.display_name || data.profiles?.name || '',
  }
}

async function loadRecords() {
  loading.value = true
  try {
    records.value = await loadAccountLedgerRecords({
      accountId,
      dateFrom: dateFrom.value,
      dateTo: dateTo.value,
    })
  } catch {
    toast('流水加载失败，请重试', 'error')
  } finally {
    loading.value = false
  }
}
</script>
