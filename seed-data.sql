-- 台球账目系统 - 测试数据种子文件
-- 在 Supabase SQL Editor 中执行（在 supabase-schema.sql 之后）
-- 包含：用户、账户、渠道分配、订单、支出、平台收入、销售目标

-- ============================
-- 1. 测试用户
-- ============================
-- 方式1（推荐）：在 Supabase Dashboard → Authentication → Users 手动创建以下用户
-- 然后执行下面的 profiles UPDATE 语句
--
-- 方式2：使用 SQL 直接创建（需要 service_role 权限，SQL Editor 自动有）
-- 密码统一设为：Test123456
--
-- 如果方式2执行失败（instance_id 唯一约束冲突），请改用方式1

-- 尝试直接创建用户（如果已存在会报错，忽略即可）
DO $$ BEGIN
  -- 管理员：老王
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'laowang@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "王孟南", "role": "admin"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'laowang@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'renkaizhi@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "任凯智", "role": "admin"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'renkaizhi@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'finance@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "张财务", "role": "finance"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'finance@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'yuan@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "袁经理", "role": "manager"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'yuan@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'dang@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "党副总", "role": "manager"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'dang@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'sales01@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "李小明", "role": "sales"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'sales01@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'sales02@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "王大力", "role": "sales"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'sales02@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'sales03@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "赵小花", "role": "sales"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'sales03@test.com already exists: %', SQLERRM;
END $$;

DO $$ BEGIN
  INSERT INTO auth.users (
    instance_id, id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, aud, role, confirmation_token, inviter_id
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(), 'cs01@test.com',
    crypt('Test123456', gen_salt('bf')),
    NOW(),
    '{"name": "孙客服", "role": "cs"}',
    'authenticated', 'authenticated', '', '00000000-0000-0000-0000-000000000000'
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'cs01@test.com already exists: %', SQLERRM;
END $$;

-- 确保 pgcrypto 扩展已启用（Supabase 默认有，但以防万一）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 确保所有用户都有 profile（触发器会自动创建，这里做 UPSERT 保底）
INSERT INTO profiles (id, name, role, status) VALUES
  ((SELECT id FROM auth.users WHERE email = 'laowang@test.com'), '王孟南', 'admin', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'renkaizhi@test.com'), '任凯智', 'admin', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'finance@test.com'), '张财务', 'finance', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'yuan@test.com'), '袁经理', 'manager', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'dang@test.com'), '党副总', 'manager', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'sales01@test.com'), '李小明', 'sales', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'sales02@test.com'), '王大力', 'sales', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'sales03@test.com'), '赵小花', 'sales', 'active'),
  ((SELECT id FROM auth.users WHERE email = 'cs01@test.com'), '孙客服', 'cs', 'active')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, role = EXCLUDED.role;

-- 补充 profile 详细信息
UPDATE profiles SET department = 'IP部', ip_code = '楠', phone = '13800001111' WHERE name = '王孟南';
UPDATE profiles SET department = '管理部', phone = '13800002222' WHERE name = '任凯智';
UPDATE profiles SET department = '财务部', phone = '13800003333' WHERE name = '张财务';
UPDATE profiles SET department = '管理部', phone = '13800004444' WHERE name = '袁经理';
UPDATE profiles SET department = '管理部', phone = '13800005555' WHERE name = '党副总';
UPDATE profiles SET department = '销售部', phone = '13800006666' WHERE name = '李小明';
UPDATE profiles SET department = '销售部', phone = '13800007777' WHERE name = '王大力';
UPDATE profiles SET department = '销售部', phone = '13800008888' WHERE name = '赵小花';
UPDATE profiles SET department = '客服部', phone = '13800009999' WHERE name = '孙客服';

-- ============================
-- 2. 收款账户
-- ============================
INSERT INTO accounts (code, ip_code, sequence, platform, balance, status) VALUES
  ('楠一微信', '楠', 1, 'wechat', 45230.50, 'active'),
  ('楠二微信', '楠', 2, 'wechat', 28100.00, 'active'),
  ('楠三微信', '楠', 3, 'wechat', 15680.30, 'active'),
  ('楠四微信', '楠', 4, 'wechat', 8950.00, 'active'),
  ('楠五微信', '楠', 5, 'wechat', 32100.00, 'active'),
  ('楠支付宝', '楠', 1, 'alipay', 18760.00, 'active'),
  ('楠银行卡工商', '楠', 1, 'bank', 156800.00, 'active'),
  ('楠银行卡建设', '楠', 2, 'bank', 89200.00, 'active'),
  ('楠银行卡招商', '楠', 3, 'bank', 67500.00, 'active'),
  ('楠抖音', '楠', 1, 'douyin', 234000.00, 'active'),
  ('楠快手', '楠', 1, 'kuaishou', 45600.00, 'active'),
  ('楠淘宝', '楠', 1, 'taobao', 31200.00, 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO accounts (code, ip_code, sequence, platform, balance, status) VALUES
  ('凯一微信', '凯', 1, 'wechat', 32000.00, 'active'),
  ('凯二微信', '凯', 2, 'wechat', 15800.00, 'active'),
  ('凯支付宝', '凯', 1, 'alipay', 22300.00, 'active'),
  ('凯银行卡', '凯', 1, 'bank', 98000.00, 'active')
ON CONFLICT (code) DO NOTHING;

-- ============================
-- 3. 渠道分配
-- ============================
INSERT INTO channel_assignments (account_id, sales_id, assigned_by, assigned_at, status) VALUES
  ((SELECT id FROM accounts WHERE code = '楠一微信'), (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-01', 'active'),
  ((SELECT id FROM accounts WHERE code = '楠二微信'), (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-01', 'active'),
  ((SELECT id FROM accounts WHERE code = '楠三微信'), (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-15', 'active'),
  ((SELECT id FROM accounts WHERE code = '楠四微信'), (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-10', 'active'),
  ((SELECT id FROM accounts WHERE code = '楠五微信'), (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-10', 'active'),
  ((SELECT id FROM accounts WHERE code = '凯一微信'), (SELECT id FROM profiles WHERE name = '赵小花'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-20', 'active'),
  ((SELECT id FROM accounts WHERE code = '凯二微信'), (SELECT id FROM profiles WHERE name = '赵小花'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-03-20', 'active')
ON CONFLICT DO NOTHING;

-- 历史分配（已释放）
INSERT INTO channel_assignments (account_id, sales_id, assigned_by, assigned_at, released_at, status, note) VALUES
  ((SELECT id FROM accounts WHERE code = '楠一微信'), (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '袁经理'), '2026-02-01', '2026-03-01', 'released', '定期轮换')
ON CONFLICT DO NOTHING;

-- ============================
-- 4. 订单
-- ============================
INSERT INTO orders (order_no, account_id, account_code, creator_id, sales_id, customer_name, customer_phone, customer_address, product_category, product_name, amount, status, created_at) VALUES
  ('ORD-20260327-001', (SELECT id FROM accounts WHERE code = '楠一微信'), '楠一微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '陈先生', '13912345678', '广东省深圳市龙华区民治街道', 'cue', '先锋 Breaks 球杆单', 3500.00, 'completed', '2026-03-27 10:00:00'),

  ('ORD-20260327-002', (SELECT id FROM accounts WHERE code = '楠二微信'), '楠二微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '张女士', '13823456789', '北京市朝阳区建国路', 'cue', 'LP 球杆单', 5800.00, 'completed', '2026-03-27 09:30:00'),

  ('ORD-20260326-001', (SELECT id FROM accounts WHERE code = '楠一微信'), '楠一微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '王同学', '13634567890', '上海市浦东新区', 'accessory', '皮头 防滑粉 配件套装', 280.00, 'completed', '2026-03-26 16:00:00'),

  ('ORD-20260326-002', (SELECT id FROM accounts WHERE code = '楠支付宝'), '楠支付宝',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '刘女士', '13545678901', '浙江省杭州市西湖区', 'recording_course', '台球进阶录播课', 2980.00, 'completed', '2026-03-26 14:20:00'),

  ('ORD-20260325-001', (SELECT id FROM accounts WHERE code = '楠四微信'), '楠四微信',
    (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '王大力'),
    '李先生', '13756789012', '四川省成都市武侯区', 'cue', '达芬奇 球杆', 8900.00, 'completed', '2026-03-25 11:00:00'),

  ('ORD-20260325-002', (SELECT id FROM accounts WHERE code = '楠五微信'), '楠五微信',
    (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '王大力'),
    '周同学', '13367890123', '湖北省武汉市洪山区', 'cue', '入门级球杆套装', 1500.00, 'completed', '2026-03-25 10:30:00'),

  ('ORD-20260324-001', (SELECT id FROM accounts WHERE code = '楠一微信'), '楠一微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '赵先生', '13478901234', '江苏省南京市鼓楼区', 'accessory', '巧粉 10盒装', 150.00, 'completed', '2026-03-24 15:00:00'),

  ('ORD-20260324-002', (SELECT id FROM accounts WHERE code = '凯一微信'), '凯一微信',
    (SELECT id FROM profiles WHERE name = '赵小花'), (SELECT id FROM profiles WHERE name = '赵小花'),
    '吴先生', '13189012345', '山东省青岛市市南区', 'cue', '皮尔力 球杆', 4200.00, 'completed', '2026-03-24 13:00:00'),

  ('ORD-20260323-001', (SELECT id FROM accounts WHERE code = '楠二微信'), '楠二微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '孙女士', '13090123456', '福建省厦门市思明区', 'cue', '美洲豹 球杆单', 6800.00, 'completed', '2026-03-23 16:30:00'),

  ('ORD-20260322-001', (SELECT id FROM accounts WHERE code = '楠三微信'), '楠三微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '黄先生', '13901234567', '广东省广州市天河区', 'offline_camp', '线下三天两夜课程', 9800.00, 'completed', '2026-03-22 09:00:00'),

  ('ORD-20260322-002', (SELECT id FROM accounts WHERE code = '楠四微信'), '楠四微信',
    (SELECT id FROM profiles WHERE name = '王大力'), (SELECT id FROM profiles WHERE name = '王大力'),
    '钱同学', '13812345670', '湖南省长沙市岳麓区', 'cue', '美洲豹 Break 球杆', 7200.00, 'completed', '2026-03-22 14:00:00'),

  ('ORD-20260321-001', (SELECT id FROM accounts WHERE code = '楠一微信'), '楠一微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '郑女士', '13723456780', '重庆市渝中区', 'recording_course', '零基础入门录播课', 1980.00, 'completed', '2026-03-21 11:00:00'),

  ('ORD-20260320-001', (SELECT id FROM accounts WHERE code = '凯二微信'), '凯二微信',
    (SELECT id FROM profiles WHERE name = '赵小花'), (SELECT id FROM profiles WHERE name = '赵小花'),
    '冯先生', '13634567890', '陕西省西安市雁塔区', 'cue', '入门球杆+配件套装', 2200.00, 'completed', '2026-03-20 15:00:00'),

  ('ORD-20260320-002', (SELECT id FROM accounts WHERE code = '楠支付宝'), '楠支付宝',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '何先生', '13545678901', '辽宁省大连市中山区', 'cue', '威利球杆 红木', 12500.00, 'completed', '2026-03-20 10:00:00'),

  -- 待确认订单
  ('ORD-20260327-003', (SELECT id FROM accounts WHERE code = '楠三微信'), '楠三微信',
    (SELECT id FROM profiles WHERE name = '李小明'), (SELECT id FROM profiles WHERE name = '李小明'),
    '马女士', '13256789012', '云南省昆明市盘龙区', 'cue', 'Powder Breaks 球杆', 4800.00, 'pending', '2026-03-27 15:00:00');

-- ============================
-- 5. 支出
-- ============================
INSERT INTO expenses (category, amount, payee, account_id, status, note, created_by, created_at) VALUES
  ('rent', 15000.00, '深圳XX物业公司', (SELECT id FROM accounts WHERE code = '楠银行卡工商'), 'paid',
    '3月办公室房租', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-01'),

  ('salary', 85000.00, '员工工资-3月', (SELECT id FROM accounts WHERE code = '楠银行卡建设'), 'paid',
    '3月全体员工工资', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-05'),

  ('daily', 3200.00, '京东办公用品', (SELECT id FROM accounts WHERE code = '楠支付宝'), 'paid',
    '打印纸、墨盒、文件夹', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-08'),

  ('marketing', 5000.00, '抖音投放', (SELECT id FROM accounts WHERE code = '楠银行卡招商'), 'paid',
    '3月直播推广费', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-10'),

  ('shipping', 1800.00, '顺丰快递', (SELECT id FROM accounts WHERE code = '楠支付宝'), 'paid',
    '球杆发货运费', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-15'),

  ('equipment', 3500.00, '苹果官方', (SELECT id FROM accounts WHERE code = '楠银行卡工商'), 'paid',
    'iPhone 16 手机1台', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-18'),

  -- 待审批（>2000，需要admin审批）
  ('equipment', 28000.00, '聚水潭ERP年费', (SELECT id FROM accounts WHERE code = '楠银行卡工商'), 'pending',
    'ERP系统续费一年', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-25'),

  ('marketing', 15000.00, '快手投放', (SELECT id FROM accounts WHERE code = '楠银行卡招商'), 'pending',
    '4月快手推广预算', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-26'),

  -- 已批准待付款
  ('rent', 15000.00, '深圳XX物业公司', (SELECT id FROM accounts WHERE code = '楠银行卡工商'), 'approved',
    '4月办公室房租', (SELECT id FROM profiles WHERE name = '张财务'), '2026-03-27');

-- 给已审批的设置审批信息
UPDATE expenses SET 
  approver_id = (SELECT id FROM profiles WHERE name = '王孟南'),
  approved_at = '2026-03-27 09:00:00'
WHERE payee = '深圳XX物业公司' AND status = 'approved';

-- ============================
-- 6. 平台收入
-- ============================
INSERT INTO platform_revenues (platform, period, total_revenue, settled_amount, pending_amount, fee_rate, fee_amount, recorded_by) VALUES
  ('douyin', '2026-03', 234000.00, 186000.00, 48000.00, 5.0, 11700.00, (SELECT id FROM profiles WHERE name = '张财务')),
  ('kuaishou', '2026-03', 45600.00, 32000.00, 13600.00, 5.0, 2280.00, (SELECT id FROM profiles WHERE name = '张财务')),
  ('taobao', '2026-03', 31200.00, 28000.00, 3200.00, 3.0, 936.00, (SELECT id FROM profiles WHERE name = '张财务'))
ON CONFLICT (platform, period) DO NOTHING;

INSERT INTO platform_revenues (platform, period, total_revenue, settled_amount, pending_amount, fee_rate, fee_amount, recorded_by) VALUES
  ('douyin', '2026-02', 198000.00, 195000.00, 3000.00, 5.0, 9900.00, (SELECT id FROM profiles WHERE name = '张财务')),
  ('kuaishou', '2026-02', 38000.00, 37500.00, 500.00, 5.0, 1900.00, (SELECT id FROM profiles WHERE name = '张财务'))
ON CONFLICT (platform, period) DO NOTHING;

-- ============================
-- 7. 销售目标
-- ============================
INSERT INTO sales_targets (user_id, period_type, period_value, target_amount, target_orders, actual_amount, actual_orders, status) VALUES
  ((SELECT id FROM profiles WHERE name = '李小明'), 'monthly', '2026-03', 80000.00, 20, 38260.00, 8, 'in_progress'),
  ((SELECT id FROM profiles WHERE name = '王大力'), 'monthly', '2026-03', 60000.00, 15, 17600.00, 3, 'in_progress'),
  ((SELECT id FROM profiles WHERE name = '赵小花'), 'monthly', '2026-03', 40000.00, 10, 6400.00, 2, 'in_progress')
ON CONFLICT (user_id, period_type, period_value) DO NOTHING;
