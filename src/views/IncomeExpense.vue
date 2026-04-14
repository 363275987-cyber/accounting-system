<template>
  <div>
    <!-- Tab Bar -->
    <div class="flex gap-1 bg-gray-100 rounded-xl p-1 mb-4">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        @click="activeTab = tab.key"
        class="flex-1 px-3 py-2 rounded-lg text-sm font-medium transition cursor-pointer whitespace-nowrap"
        :class="activeTab === tab.key
          ? 'bg-white text-gray-800 shadow-sm'
          : 'text-gray-500 hover:text-gray-700'"
      >
        {{ tab.icon }} {{ tab.label }}
      </button>
    </div>

    <!-- Tab Content -->
    <KeepAlive>
      <Expenses v-if="activeTab === 'expenses'" />
      <OtherIncome v-else-if="activeTab === 'income'" />
      <SalaryManagement v-else-if="activeTab === 'salary'" />
    </KeepAlive>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import Expenses from './Expenses.vue'
import OtherIncome from './OtherIncome.vue'
import SalaryManagement from './SalaryManagement.vue'

const tabs = [
  { key: 'expenses', label: '支出记录', icon: '💸' },
  { key: 'income', label: '其他收入', icon: '💰' },
  { key: 'salary', label: '工资发放', icon: '👥' },
]

const activeTab = ref('expenses')
</script>
