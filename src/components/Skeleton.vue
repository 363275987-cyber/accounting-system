<template>
  <div class="animate-pulse">
    <!-- Table Skeleton -->
    <template v-if="type === 'table'">
      <div class="w-full">
        <!-- Header row -->
        <div class="flex gap-2 px-4 py-3 bg-gray-50 rounded-t-xl">
          <div v-for="i in columns" :key="'h'+i"
            class="h-4 bg-gray-200 rounded flex-1"
            :class="i === columns ? 'max-w-[60px]' : ''"
            :style="{ width: columnWidths[i-1] || 'auto' }">
          </div>
        </div>
        <!-- Data rows -->
        <div v-for="r in rows" :key="'r'+r"
          class="flex gap-2 px-4 py-3 border-t border-gray-100">
          <div v-for="i in columns" :key="'c'+i"
            class="h-4 bg-gray-100 rounded flex-1"
            :style="{ width: columnWidths[i-1] || 'auto' }">
          </div>
        </div>
      </div>
    </template>

    <!-- Stats Skeleton -->
    <template v-else-if="type === 'stats'">
      <div class="grid gap-4" :class="statsGridClass">
        <div v-for="i in count" :key="'s'+i"
          class="bg-white rounded-xl border border-gray-100 p-5">
          <div class="h-4 w-24 bg-gray-200 rounded mb-3"></div>
          <div class="h-8 w-32 bg-gray-100 rounded"></div>
        </div>
      </div>
    </template>

    <!-- Card Skeleton -->
    <template v-else-if="type === 'card'">
      <div class="grid gap-4" :class="cardGridClass">
        <div v-for="i in count" :key="'card'+i"
          class="bg-white rounded-xl border border-gray-100 p-4">
          <div class="h-5 w-2/3 bg-gray-200 rounded mb-3"></div>
          <div class="h-4 w-full bg-gray-100 rounded mb-2"></div>
          <div class="h-4 w-4/5 bg-gray-100 rounded"></div>
        </div>
      </div>
    </template>

    <!-- Form Skeleton -->
    <template v-else-if="type === 'form'">
      <div class="space-y-4">
        <div v-for="i in fields" :key="'f'+i">
          <div class="h-3 w-20 bg-gray-200 rounded mb-2"></div>
          <div class="h-10 w-full bg-gray-100 rounded-lg"></div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
const props = defineProps({
  type: { type: String, default: 'table' },
  rows: { type: Number, default: 5 },
  columns: { type: Number, default: 5 },
  count: { type: Number, default: 4 },
  fields: { type: Number, default: 4 },
  columnWidths: { type: Array, default: () => [] },
  statsGridClass: { type: String, default: 'grid-cols-2 lg:grid-cols-4' },
  cardGridClass: { type: String, default: 'grid-cols-1 md:grid-cols-3' },
})
</script>
