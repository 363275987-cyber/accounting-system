// 飞书每日经营摘要推送
// 触发方式：
//   1) pg_cron + net.http_post 定时调用(见 migrations/010)
//   2) 手动触发用于测试:
//      curl -X POST "https://<project-ref>.supabase.co/functions/v1/daily-briefing?kind=morning" \
//        -H "Authorization: Bearer <service_role_or_anon>"
//
// 必需环境变量(Supabase → Settings → Edge Functions → Secrets):
//   FEISHU_WEBHOOK_URL   飞书自定义群机器人 webhook
//   FEISHU_SECRET        飞书机器人签名密钥(强烈建议)
//   SUPABASE_URL         Supabase 项目地址(自动注入)
//   SUPABASE_SERVICE_ROLE_KEY  数据库服务密钥(自动注入)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4'

const FEISHU_WEBHOOK = Deno.env.get('FEISHU_WEBHOOK_URL') ?? ''
const FEISHU_SECRET = Deno.env.get('FEISHU_SECRET') ?? ''
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const APP_URL = Deno.env.get('APP_URL') ?? 'https://363275987-cyber.github.io/accounting-system/#/boss'

const supabase = createClient(SUPABASE_URL, SERVICE_KEY)

// 飞书签名算法(HMAC-SHA256 + base64)
async function feishuSign(timestamp: number, secret: string): Promise<string> {
  const stringToSign = `${timestamp}\n${secret}`
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(stringToSign),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  // HMAC of empty string(飞书的做法)
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(''))
  return btoa(String.fromCharCode(...new Uint8Array(sig)))
}

function fmtMoney(n: number): string {
  const v = Number(n || 0)
  const sign = v < 0 ? '-' : ''
  return `${sign}¥${Math.abs(v).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

function pad(n: number): string { return String(n).padStart(2, '0') }

// 把 Date 转成 北京时间 ISO
function tzIso(d: Date, end = false): string {
  const s = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  return new Date(`${s}T${end ? '23:59:59' : '00:00:00'}+08:00`).toISOString()
}

// 决定摘要区间。morning = 昨天整日;  evening = 今天至此刻
function resolveRange(kind: 'morning' | 'evening'): { from: string; to: string; label: string } {
  const now = new Date()
  if (kind === 'morning') {
    const y = new Date(now); y.setDate(y.getDate() - 1)
    const label = `${y.getMonth() + 1}月${y.getDate()}日`
    return { from: tzIso(y), to: tzIso(y, true), label: `${label} 昨日经营` }
  }
  const label = `${now.getMonth() + 1}月${now.getDate()}日`
  return { from: tzIso(now), to: tzIso(now, true), label: `${label} 今日实时` }
}

type Summary = {
  income_total: number
  expense_total: number
  refund_total: number
  dividend_total: number
  orders_count: number
}

async function fetchAll(from: string, to: string) {
  const [summaryRes, topStoresRes, driftRes] = await Promise.all([
    supabase.rpc('get_boss_summary', { p_from: from, p_to: to }),
    supabase.rpc('get_top_stores', { p_from: from, p_to: to, p_limit: 3 }),
    supabase.rpc('check_balance_drift'),
  ])
  if (summaryRes.error) throw summaryRes.error
  if (topStoresRes.error) throw topStoresRes.error
  // drift 错可忽略
  return {
    summary: (summaryRes.data ?? {}) as Summary,
    topStores: topStoresRes.data ?? [],
    drift: driftRes.data ?? [],
  }
}

function profitOf(s: Summary): number {
  return Number(s.income_total || 0) - Number(s.expense_total || 0) - Number(s.refund_total || 0) - Number(s.dividend_total || 0)
}

// 组装飞书互动卡片
function buildCard(kind: 'morning' | 'evening', data: Awaited<ReturnType<typeof fetchAll>>, rangeLabel: string) {
  const { summary, topStores, drift } = data
  const profit = profitOf(summary)
  const driftCount = drift.length

  const headerTitle = kind === 'morning' ? '📊 昨日经营摘要' : '📊 今日实时摘要'
  const themeColor = profit >= 0 ? 'green' : 'red'

  const storeLines = topStores.length > 0
    ? topStores.map((s: any, i: number) => {
        const medal = ['🥇', '🥈', '🥉'][i] || '🏅'
        return `${medal} **${s.short_name}**  ${fmtMoney(Number(s.sales))}  _(${s.orders_count} 笔)_`
      }).join('\n')
    : '_暂无店铺销售_'

  const driftBlock = driftCount > 0
    ? `\n\n⚠️ **${driftCount} 个账户余额对不齐**，请查看余额对账页`
    : `\n\n✅ 所有账户对齐，数据健康`

  return {
    msg_type: 'interactive',
    card: {
      config: { wide_screen_mode: true },
      header: {
        title: { tag: 'plain_text', content: headerTitle },
        subtitle: { tag: 'plain_text', content: rangeLabel },
        template: themeColor,
      },
      elements: [
        {
          tag: 'div',
          fields: [
            { is_short: false, text: { tag: 'lark_md', content: `**💰 净利润**\n<font color='${profit >= 0 ? 'green' : 'red'}'>${profit >= 0 ? '+' : ''}${fmtMoney(profit)}</font>` } },
          ],
        },
        {
          tag: 'div',
          fields: [
            { is_short: true, text: { tag: 'lark_md', content: `**📈 收入**\n<font color='green'>+${fmtMoney(summary.income_total)}</font>\n_${summary.orders_count} 笔订单_` } },
            { is_short: true, text: { tag: 'lark_md', content: `**📉 支出**\n<font color='red'>-${fmtMoney(summary.expense_total)}</font>\n_退款 ${fmtMoney(summary.refund_total)}_` } },
          ],
        },
        { tag: 'hr' },
        {
          tag: 'div',
          text: { tag: 'lark_md', content: `**🏆 店铺销售 Top 3**\n${storeLines}${driftBlock}` },
        },
        { tag: 'hr' },
        {
          tag: 'action',
          actions: [
            {
              tag: 'button',
              text: { tag: 'plain_text', content: '📱 打开完整看板' },
              type: 'primary',
              url: APP_URL,
            },
          ],
        },
      ],
    },
  }
}

async function postToFeishu(payload: Record<string, unknown>) {
  if (!FEISHU_WEBHOOK) throw new Error('FEISHU_WEBHOOK_URL 未配置')
  const body: Record<string, unknown> = { ...payload }
  if (FEISHU_SECRET) {
    const timestamp = Math.floor(Date.now() / 1000)
    body.timestamp = String(timestamp)
    body.sign = await feishuSign(timestamp, FEISHU_SECRET)
  }
  const res = await fetch(FEISHU_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await res.text()
  if (!res.ok) throw new Error(`Feishu webhook failed: ${res.status} ${text}`)
  return text
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url)
    const kind = (url.searchParams.get('kind') || 'morning') as 'morning' | 'evening'
    const { from, to, label } = resolveRange(kind)
    const data = await fetchAll(from, to)
    const card = buildCard(kind, data, label)
    const result = await postToFeishu(card)
    return new Response(JSON.stringify({ ok: true, kind, label, feishu_response: result }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('[daily-briefing] fatal:', e)
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    })
  }
})
