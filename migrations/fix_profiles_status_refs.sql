-- Fix: profiles 表没有 status 列；并且 SECURITY DEFINER 触发器在 auth schema
-- 上下文中执行时，未限定的 `profiles` 解析失败 (relation "profiles" does not exist)。
-- 该补丁同时修：
--   1) UserManagement「+添加员工」调用 admin_create_user 失败 (column "status" does not exist)
--   2) Supabase Auth Admin API 创建用户 → on_auth_user_created 触发器 → handle_new_user
--      报 "relation profiles does not exist"，因为 search_path 缺 public
--   3) acct_handle_new_user 同样缺 search_path，且引用 status 列
--
-- 已在 2026-04-15 通过 Supabase Management API 执行过；保留此文件作为审计/回滚参考。

-- 1) 主触发器：onAuthUserCreated → handle_new_user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'sales')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 2) 备用触发器函数（acct_on_auth_user_created）
CREATE OR REPLACE FUNCTION public.acct_handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.id) THEN
    INSERT INTO public.profiles (id, name, role, email)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
      COALESCE(NEW.raw_user_meta_data->>'role', 'sales'),
      NEW.email
    );
  END IF;
  RETURN NEW;
END;
$$;

-- 3) admin_create_user RPC：去掉 status 字段；仅写 profiles 行
--    （真实的 auth.users 创建由前端通过 Auth Admin API 调用）
DROP FUNCTION IF EXISTS public.admin_create_user(text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_create_user(
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
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := gen_random_uuid();

  INSERT INTO public.profiles (id, name, role, department, phone, email)
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
