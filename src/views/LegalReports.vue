<template>
  <div class="bg-white rounded-xl border border-gray-100 p-12 text-center">
    <div class="text-4xl mb-4">📋</div>
    <h2 class="text-lg font-bold text-gray-800 mb-2">法定财务报表已合并</h2>
    <p class="text-gray-500 mb-6">所有财务报表（利润表、资产负债表、现金流量表、权益变动表）已统一整合至「财务报表」页面。</p>
    <router-link to="/reports"
      class="inline-block px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">
      前往财务报表 →
    </router-link>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()

onMounted(() => {
  // Auto-redirect after a brief moment
  setTimeout(() => {
    router.replace({ name: 'Reports' })
  }, 3000)
})
</script>
