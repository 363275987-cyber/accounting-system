// 台球账目系统 - 创建用户 Edge Function
// 部署到 Supabase: supabase functions deploy create-user
// 调用方式: supabase.functions.invoke('create-user', { body: {...} })

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
)

Deno.serve(async (req) => {
  try {
    const { email, password, name, role, department, phone } = await req.json()
    
    if (!email || !password || !name) {
      return new Response(JSON.stringify({ error: '缺少必填字段：email, password, name' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }
    
    const validRoles = ['sales', 'cs', 'finance', 'manager', 'admin', 'hr', 'coach']
    if (role && !validRoles.includes(role)) {
      return new Response(JSON.stringify({ error: `无效角色：${role}` }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { data: user, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { 
        name, 
        role: role || 'sales',
        department: department || null,
        phone: phone || null,
      },
    })

    if (error) {
      if (error.message?.includes('already registered')) {
        return new Response(JSON.stringify({ error: '该邮箱已注册' }), {
          status: 409,
          headers: { 'Content-Type': 'application/json' },
        })
      }
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true, user: { id: user.id, email: user.email } }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
