-- ============================================
-- Coaching System Tables
-- ============================================

-- 1. Coaches (教练)
CREATE TABLE IF NOT EXISTS public.coaches (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  phone text,
  specialties jsonb DEFAULT '[]'::jsonb,
  hourly_rate numeric(10,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  bio text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.coaches ENABLE ROW LEVEL SECURITY;

-- coach_role: coaches table has no user_id, so we use a mapping approach
-- admin/finance full access
CREATE POLICY "coaches_select" ON public.coaches
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'coach')
  );
CREATE POLICY "coaches_insert" ON public.coaches
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "coaches_update" ON public.coaches
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "coaches_delete" ON public.coaches
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- 2. Students (学员)
CREATE TABLE IF NOT EXISTS public.students (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  phone text,
  level text DEFAULT 'beginner' CHECK (level IN ('beginner', 'intermediate', 'advanced')),
  note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

CREATE POLICY "students_select" ON public.students
  FOR SELECT USING (true);
CREATE POLICY "students_insert" ON public.students
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "students_update" ON public.students
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "students_delete" ON public.students
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- 3. Courses (课程类型)
CREATE TABLE IF NOT EXISTS public.courses (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  duration_hours numeric(10,2) NOT NULL DEFAULT 0,
  price numeric(10,2) NOT NULL DEFAULT 0,
  coach_id uuid REFERENCES public.coaches(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "courses_select" ON public.courses
  FOR SELECT USING (true);
CREATE POLICY "courses_insert" ON public.courses
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "courses_update" ON public.courses
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "courses_delete" ON public.courses
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- 4. Coaching Sessions (上课记录)
CREATE TABLE IF NOT EXISTS public.coaching_sessions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  coach_id uuid NOT NULL REFERENCES public.coaches(id) ON DELETE CASCADE,
  course_id uuid REFERENCES public.courses(id) ON DELETE SET NULL,
  session_date date NOT NULL,
  duration_hours numeric(10,2) NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'cancelled')),
  note text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.coaching_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sessions_select" ON public.coaching_sessions
  FOR SELECT USING (true);
CREATE POLICY "sessions_insert" ON public.coaching_sessions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "sessions_update" ON public.coaching_sessions
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "sessions_delete" ON public.coaching_sessions
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- 5. Coaching Payments (教练课收款)
CREATE TABLE IF NOT EXISTS public.coaching_payments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.coaching_sessions(id) ON DELETE SET NULL,
  amount numeric(12,2) NOT NULL,
  payment_method text,
  account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'refunded')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.coaching_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select" ON public.coaching_payments
  FOR SELECT USING (true);
CREATE POLICY "payments_insert" ON public.coaching_payments
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "payments_update" ON public.coaching_payments
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );
CREATE POLICY "payments_delete" ON public.coaching_payments
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'finance', 'manager'))
  );

-- ============================================
-- Updated_at triggers
-- ============================================
DROP TRIGGER IF EXISTS coaches_updated_at ON public.coaches;
CREATE TRIGGER coaches_updated_at
  BEFORE UPDATE ON public.coaches
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS students_updated_at ON public.students;
CREATE TRIGGER students_updated_at
  BEFORE UPDATE ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_coaches_status ON public.coaches(status);
CREATE INDEX IF NOT EXISTS idx_students_level ON public.students(level);
CREATE INDEX IF NOT EXISTS idx_courses_status ON public.courses(status);
CREATE INDEX IF NOT EXISTS idx_coaching_sessions_date ON public.coaching_sessions(session_date);
CREATE INDEX IF NOT EXISTS idx_coaching_sessions_student ON public.coaching_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_coaching_sessions_coach ON public.coaching_sessions(coach_id);
CREATE INDEX IF NOT EXISTS idx_coaching_payments_session ON public.coaching_payments(session_id);
CREATE INDEX IF NOT EXISTS idx_coaching_payments_student ON public.coaching_payments(student_id);

-- ============================================
-- Seed data
-- ============================================

-- 老王教练
INSERT INTO public.coaches (name, phone, specialties, hourly_rate, bio)
VALUES ('王孟南', NULL, '["开球","走位","发力","防守"]'::jsonb, 500.00, '台球教练，擅长斯诺克和中式八球')
ON CONFLICT DO NOTHING;

-- 预设课程（关联到老王）
INSERT INTO public.courses (name, duration_hours, price, coach_id, status)
SELECT '一对一私教', 1.00, 500.00, c.id, 'active'
FROM public.coaches c
WHERE c.name = '王孟南'
  AND NOT EXISTS (SELECT 1 FROM public.courses WHERE name = '一对一私教');

INSERT INTO public.courses (name, duration_hours, price, coach_id, status)
SELECT '三天两夜集训', 24.00, 6800.00, c.id, 'active'
FROM public.coaches c
WHERE c.name = '王孟南'
  AND NOT EXISTS (SELECT 1 FROM public.courses WHERE name = '三天两夜集训');

INSERT INTO public.courses (name, duration_hours, price, coach_id, status)
SELECT '线上录播课', 10.00, 299.00, c.id, 'active'
FROM public.coaches c
WHERE c.name = '王孟南'
  AND NOT EXISTS (SELECT 1 FROM public.courses WHERE name = '线上录播课');
