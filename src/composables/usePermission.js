import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

const role = ref('')
const loaded = ref(false)

export function usePermission() {
  async function loadRole() {
    if (loaded.value) return
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) { role.value = 'guest'; loaded.value = true; return }
      const { data } = await supabase.from('profiles').select('role').eq('id', session.user.id).single()
      role.value = data?.role || 'guest'
    } catch { role.value = 'guest' }
    loaded.value = true
  }

  const isAdmin = computed(() => role.value === 'admin')
  const isFinance = computed(() => ['admin', 'finance'].includes(role.value))
  const isWarehouse = computed(() => ['admin', 'finance', 'warehouse'].includes(role.value))
  const canEdit = computed(() => ['admin', 'finance'].includes(role.value))
  const canDelete = computed(() => role.value === 'admin')
  const canSeeCost = computed(() => role.value === 'admin')

  return { role, isAdmin, isFinance, isWarehouse, canEdit, canDelete, canSeeCost, loadRole, loaded }
}
