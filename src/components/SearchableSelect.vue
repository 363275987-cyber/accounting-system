<template>
  <div class="relative" ref="wrapperRef">
    <div
      class="w-full px-3 py-2.5 border rounded-lg text-sm outline-none cursor-pointer flex items-center justify-between"
      :class="showDropdown ? 'ring-2 ring-blue-500 border-blue-500' : 'border-gray-200'"
      @click="toggleDropdown"
    >
      <span :class="modelValue ? 'text-gray-800' : 'text-gray-500'">
        {{ displayText || placeholder }}
      </span>
      <span class="text-gray-500 text-xs ml-2">{{ filteredOptions.length }} 项</span>
    </div>

    <!-- Dropdown -->
    <div v-if="showDropdown"
      class="absolute z-50 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-64 overflow-hidden"
      :style="dropUp ? 'bottom:100%; margin-bottom:4px' : 'margin-top:4px'"
    >      <!-- Search -->
      <div class="p-2 border-b border-gray-100">
        <input
          ref="searchRef"
          v-model="searchText"
          type="text"
          :placeholder="searchPlaceholder || '搜索...'"
          class="w-full px-2.5 py-1.5 border border-gray-200 rounded text-sm outline-none focus:ring-1 focus:ring-blue-500"
          @keydown.down.prevent="moveDown"
          @keydown.up.prevent="moveUp"
          @keydown.enter.prevent="selectHighlighted"
          @keydown.esc.prevent="closeDropdown"
        />
      </div>
      <!-- Options -->
      <div class="overflow-y-auto max-h-48">
        <div v-if="pinnedOptions.length > 0 && !searchText" class="border-b border-gray-100">
          <div class="px-2 py-1 text-xs text-gray-500">常用</div>
          <div
            v-for="(opt, i) in pinnedOptions"
            :key="'pin-' + i"
            class="px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 flex items-center gap-2"
            :class="{ 'bg-blue-50': highlightedIndex === i }"
            @click="selectOption(opt)"
            @mouseenter="highlightedIndex = i"
          >
            <span class="text-xs text-yellow-500">⭐</span>
            {{ getLabel(opt) }}
          </div>
        </div>
        <div
          v-for="(opt, i) in regularOptions"
          :key="'opt-' + (pinnedOptions.length + i)"
          class="px-3 py-2 text-sm cursor-pointer hover:bg-blue-50 transition"
          :class="{
            'bg-blue-50': highlightedIndex === pinnedOptions.length + i,
            'text-blue-700 font-medium': getOptionValue(opt) === modelValue,
            'text-gray-800': getOptionValue(opt) !== modelValue
          }"
          @click="selectOption(opt)"
          @mouseenter="highlightedIndex = pinnedOptions.length + i"
        >
          {{ getLabel(opt) }}
        </div>
        <div v-if="filteredOptions.length === 0" class="px-3 py-6 text-center text-gray-500 text-sm">
          无匹配结果
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'

const props = defineProps({
  modelValue: [String, Number],
  options: { type: Array, default: () => [] },
  labelKey: { type: String, default: 'label' },
  valueKey: { type: String, default: 'value' },
  placeholder: { type: String, default: '请选择' },
  searchPlaceholder: { type: String, default: '' },
  pinnedValues: { type: Array, default: () => [] },
  minOptionsForSearch: { type: Number, default: 15 },
  dropUp: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])

const wrapperRef = ref(null)
const searchRef = ref(null)
const showDropdown = ref(false)
const searchText = ref('')
const highlightedIndex = ref(-1)

const filteredOptions = computed(() => {
  if (!searchText.value) return props.options
  const kw = searchText.value.toLowerCase()
  return props.options.filter(opt => getLabel(opt).toLowerCase().includes(kw))
})

const pinnedOptions = computed(() => {
  if (searchText.value) return []
  return props.options.filter(opt => props.pinnedValues.includes(getOptionValue(opt)))
})

const regularOptions = computed(() => {
  const pinnedIds = new Set(pinnedOptions.value.map(getOptionValue))
  return filteredOptions.value.filter(opt => !pinnedIds.has(getOptionValue(opt)))
})

const displayText = computed(() => {
  if (!props.modelValue) return ''
  const opt = props.options.find(o => getOptionValue(o) === props.modelValue)
  return opt ? getLabel(opt) : ''
})

const needsSearch = computed(() => props.options.length >= props.minOptionsForSearch)

function getLabel(opt) {
  return typeof opt === 'object' ? opt[props.labelKey] : opt
}

function getOptionValue(opt) {
  return typeof opt === 'object' ? opt[props.valueKey] : opt
}

function selectOption(opt) {
  emit('update:modelValue', getOptionValue(opt))
  closeDropdown()
}

function selectHighlighted() {
  const all = [...pinnedOptions.value, ...regularOptions.value]
  if (highlightedIndex.value >= 0 && highlightedIndex.value < all.length) {
    selectOption(all[highlightedIndex.value])
  }
}

function moveDown() {
  const max = pinnedOptions.value.length + regularOptions.value.length - 1
  highlightedIndex.value = Math.min(highlightedIndex.value + 1, max)
}

function moveUp() {
  highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0)
}

function toggleDropdown() {
  showDropdown.value = !showDropdown.value
  if (showDropdown.value) {
    searchText.value = ''
    highlightedIndex.value = -1
    nextTick(() => searchRef.value?.focus())
  }
}

function closeDropdown() {
  showDropdown.value = false
  searchText.value = ''
  highlightedIndex.value = -1
}

function handleClickOutside(e) {
  if (wrapperRef.value && !wrapperRef.value.contains(e.target)) {
    closeDropdown()
  }
}

onMounted(() => document.addEventListener('click', handleClickOutside))
onBeforeUnmount(() => document.removeEventListener('click', handleClickOutside))
</script>
