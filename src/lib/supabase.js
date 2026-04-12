import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    '[Supabase] 缺少环境变量 VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY。\n' +
    '请在项目根目录创建 .env 文件（可参考 .env.example），填入你的 Supabase 项目配置后重新启动 dev server。'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
