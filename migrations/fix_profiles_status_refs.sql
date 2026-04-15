-- Fix: profiles 表没有 status 列，但以下对象仍然引用它，导致：
--   1. UserManagement "添加员工" 调用 admin_create_user 失败（column "status" of relation "profiles" does not exist）
--   2. Supabase Auth Admin API 创建用户失败（acct_handle_new_user 触发器同样插入 status）
-- 该补丁把这两个函数里的 status 引用删掉。

-- 1) 修复 AFTER INSERT ON auth.users 的触发器函数
CREATE OR REPLACE FUNCTION acct_handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = NEW.id) THEN
    INSERT INTO profiles (id, name, role)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
      COALESCE(NEW.raw_user_meta_data->>'role', 'sales')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2) 修复 admin_create_user RPC，去掉 status 字段
CREATE OR REPLACE FUNCTION admin_create_user(
  p_email      TEXT,
  p_password   TEXT,
  p_name       TEXT,
  p_role       TEXT,
  p_department TEXT DEFAULT NULL,
  p_phone      TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- 生成一个 UUID 用于 profiles（Auth Admin 创建由前端另行调用）
  v_user_id := gen_random_uuid();

  -- 仅更新/插入 profiles 行；真正的 auth.users 记录由调用方通过 Auth Admin API 创建
  INSERT INTO profiles (id, name, role, department, phone, email)
  VALUES (v_user_id, p_name, p_role, p_department, p_phone, p_email)
  ON CONFLICT (id) DO UPDATE SET
    name       = EXCLUDED.name,
    role       = EXCLUDED.role,
    department = EXCLUDED.department,
    phone      = EXCLUDED.phone,
    email      = EXCLUDED.email;

  RETURN jsonb_build_object('success', true, 'user_id', v_user_id);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
