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

/**
 * 给任意 Promise（包括 Supabase PostgREST 查询构造器）包一层超时保护。
 *
 * 背景: 如果某个查询命中了不存在的视图/表或者走到被墙的链路，supabase-js
 * 的请求会一直 pending，导致队列被毒化，之后所有页面都卡死，只能硬刷新。
 *
 * 用法:
 *   const { data, error } = await withTimeout(
 *     supabase.from('accounts').select('*'),
 *     10000,
 *     '加载账户'
 *   )
 *
 * @param {PromiseLike<any>} promise - Supabase 查询 thenable 或普通 Promise
 * @param {number} ms - 超时毫秒数，默认 10 秒
 * @param {string} label - 出错时的标签，便于排查
 * @returns {Promise<any>}
 */
export function withTimeout(promise, ms = 10000, label = 'Supabase 请求') {
  return Promise.race([
    promise,
    new Promise((_, rej) => setTimeout(() => rej(new Error(`${label} 超时`)), ms))
  ])
}
