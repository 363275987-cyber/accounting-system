const SUPABASE_URL = 'https://cmswoyiuoeqzeassubvw.supabase.co'
const MANAGEMENT_TOKEN = 'sbp_a256e53dbedbe3c3b40186afd90eb227ffcb76b7'
const fs = require('fs')

const sql = fs.readFileSync('migrations/002_ecommerce_stores.sql', 'utf-8')

// 分割语句
const statements = sql
  .split(';')
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.match(/^--/m) || s.includes('CREATE') || s.includes('ALTER') || s.includes('INSERT') || s.includes('UPDATE') || s.includes('DROP'))

async function runQuery(query) {
  const res = await fetch('https://api.supabase.com/v1/projects/cmswoyiuoeqzeassubvw/database/query', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${MANAGEMENT_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ query })
  })
  const data = await res.json()
  return data
}

async function main() {
  // 按逻辑分组执行
  const groups = sql.split(/\n-- \d+\./).filter(Boolean)

  for (let i = 0; i < groups.length; i++) {
    const group = groups[i].trim()
    if (!group) continue
    // 分每条语句
    const stmts = group.split(';').map(s => s.trim()).filter(s => s.length > 10)
    for (const stmt of stmts) {
      if (stmt.length < 10) continue
      try {
        const result = await runQuery(stmt)
        if (result.error) {
          console.log(`❌ ERROR: ${result.error}`)
        } else {
          console.log(`✅ OK (${stmt.substring(0, 60)}...)`)
        }
      } catch (e) {
        console.log(`❌ FAIL: ${e.message}`)
      }
    }
  }
  console.log('\n完成!')
}

main()
