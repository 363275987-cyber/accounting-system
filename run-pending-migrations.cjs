const fs = require('fs')
const path = require('path')

const SUPABASE_PROJECT_REF = 'cmswoyiuoeqzeassubvw'
const MANAGEMENT_TOKEN = process.env.SUPABASE_MGMT_TOKEN
const MIGRATIONS = [
  '010_align_boss_dashboard_cash_metrics.sql',
  '011_align_ecommerce_daily_view.sql',
  '012_transfer_transaction_rpcs.sql',
  '013_process_refund_rpc.sql',
  '014_store_withdrawal_transaction_rpcs.sql',
  '015_store_deposit_transaction_rpcs.sql',
]
const startFrom = process.argv[2] || MIGRATIONS[0]
const startIndex = MIGRATIONS.indexOf(startFrom)

if (!MANAGEMENT_TOKEN) {
  console.error('缺少 SUPABASE_MGMT_TOKEN，无法执行远程 migration。')
  process.exit(1)
}

if (startIndex < 0) {
  console.error(`未知起始 migration: ${startFrom}`)
  process.exit(1)
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function runQuery(sql, retries = 3) {
  let lastError = null

  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const res = await fetch(`https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/database/query`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${MANAGEMENT_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query: sql }),
      })

      const text = await res.text()
      let body = null
      try {
        body = JSON.parse(text)
      } catch {
        body = text
      }

      if (!res.ok) {
        const message = typeof body === 'string' ? body : body?.error || JSON.stringify(body)
        throw new Error(message)
      }

      if (body?.error) {
        throw new Error(body.error)
      }

      return body
    } catch (error) {
      lastError = error
      if (attempt < retries) {
        console.warn(`  第 ${attempt} 次失败：${error.message}，2 秒后重试...`)
        await sleep(2000)
      }
    }
  }

  throw lastError
}

async function main() {
  const pending = MIGRATIONS.slice(startIndex)
  console.log(`准备执行 ${pending.length} 个待落库 migration，起点 ${startFrom}...`)

  for (const file of pending) {
    const fullPath = path.join(__dirname, 'migrations', file)
    const sql = fs.readFileSync(fullPath, 'utf8')
    console.log(`\n▶ 执行 ${file}`)
    try {
      await runQuery(sql)
      console.log(`✓ ${file} 已完成`)
    } catch (error) {
      console.error(`✗ ${file} 执行失败`)
      console.error(error.message)
      process.exit(1)
    }
  }

  console.log('\n全部 pending migrations 已执行完成。')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
