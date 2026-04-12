-- ========== 插入30条电商测试订单 ==========
-- 抖音 10条
INSERT INTO orders (creator_id, account_id, account_code, customer_name, product_category, product_name, amount, status, order_source, payment_method, platform_type, platform_store, external_order_no, sku_code, quantity, payment_amount, created_at) VALUES
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','dcdae01d-69e0-4a54-9aba-e550234dce7a','EC-DY-HSQ','电商客户','other','',198,'completed','cs_service','wechat','douyin','抖店-靓仔甄选台球店','DY20260401000','DAB002',1,198,'2026-04-01 10:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','814b6650-0c15-4a1a-9f28-a2d2bff6c74c','EC-DY-ZZH','电商客户','other','',368,'completed','cs_service','wechat','douyin','抖店-王孟南台球教学店','DY20260402001','DAD003',1,368,'2026-04-02 11:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','dcdae01d-69e0-4a54-9aba-e550234dce7a','EC-DY-HSQ','电商客户','other','',580,'completed','cs_service','wechat','douyin','抖店-好事情台球','DY20260403002','DAD005',1,580,'2026-04-03 09:30:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','613de495-24fc-4879-9c10-eb57ba4f83b4','EC-DY-ONE','电商客户','other','',1280,'completed','cs_service','wechat','douyin','抖店-台球one号店','DY20260404003','DAD011',1,1280,'2026-04-04 14:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','dcdae01d-69e0-4a54-9aba-e550234dce7a','EC-DY-HSQ','电商客户','other','',2980,'completed','cs_service','wechat','douyin','抖店-靓仔甄选台球店','DY20260405004','TA013',1,2980,'2026-04-05 08:30:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','814b6650-0c15-4a1a-9f28-a2d2bff6c74c','EC-DY-ZZH','电商客户','other','',88,'completed','cs_service','wechat','douyin','抖店-王孟南台球教学店','DY20260406005','TA163',1,88,'2026-04-06 10:20:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','dcdae01d-69e0-4a54-9aba-e550234dce7a','EC-DY-HSQ','电商客户','other','',456,'completed','cs_service','wechat','douyin','抖店-好事情台球','DY20260407006','TA170',1,456,'2026-04-07 15:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','613de495-24fc-4879-9c10-eb57ba4f83b4','EC-DY-ONE','电商客户','other','',1680,'completed','cs_service','wechat','douyin','抖店-台球one号店','DY20260408007','TA175',2,1680,'2026-04-08 09:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','dcdae01d-69e0-4a54-9aba-e550234dce7a','EC-DY-HSQ','电商客户','other','',3200,'pending','cs_service','wechat','douyin','抖店-靓仔甄选台球店','DY20260401008','TB001',2,3200,'2026-04-01 16:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','814b6650-0c15-4a1a-9f28-a2d2bff6c74c','EC-DY-ZZH','电商客户','other','',760,'completed','cs_service','wechat','douyin','抖店-王孟南台球教学店','DY20260402009','DAA074',2,760,'2026-04-02 17:30:00+08');

-- 快手 10条
INSERT INTO orders (creator_id, account_id, account_code, customer_name, product_category, product_name, amount, status, order_source, payment_method, platform_type, platform_store, external_order_no, sku_code, quantity, payment_amount, created_at) VALUES
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',520,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260401000','DAD011',1,520,'2026-04-01 12:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',168,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260402001','TA013',1,168,'2026-04-02 13:45:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',2680,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260403002','TA163',1,2680,'2026-04-03 09:30:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',99,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260404003','TA170',1,99,'2026-04-04 15:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',1580,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260405004','TA175',1,1580,'2026-04-05 10:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',380,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260406005','TB001',1,380,'2026-04-06 08:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',4200,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260407006','DAA074',1,4200,'2026-04-07 11:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',56,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260408007','DAB002',1,56,'2026-04-08 16:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',890,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260401008','DAD003',1,890,'2026-04-01 19:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','f89bfe77-3184-4f8a-928a-5b8a21a95374','EC-KS-WMN','电商客户','other','',1200,'completed','cs_service','wechat','kuaishou','快手-王孟南台球教学','KS20260402009','DAD005',1,1200,'2026-04-02 20:00:00+08');

-- 视频号 10条
INSERT INTO orders (creator_id, account_id, account_code, customer_name, product_category, product_name, amount, status, order_source, payment_method, platform_type, platform_store, external_order_no, sku_code, quantity, payment_amount, created_at) VALUES
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',680,'completed','cs_service','wechat','shipinhao','视频号-靓仔台球','SPH20260401000','TA170',1,680,'2026-04-01 09:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',2200,'completed','cs_service','wechat','shipinhao','视频号-王孟南台球教学','SPH20260402001','TA175',1,2200,'2026-04-02 12:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','8e61cf60-b35e-4141-818f-52a81df75b05','EC-SPH-LZ','电商客户','other','',158,'completed','cs_service','wechat','shipinhao','视频号-靓仔台球','SPH20260403002','TB001',1,158,'2026-04-03 16:30:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',3680,'completed','cs_service','wechat','shipinhao','视频号-王孟南台球教学','SPH20260404003','DAA074',1,3680,'2026-04-04 11:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','8e61cf60-b35e-4141-818f-52a81df75b05','EC-SPH-LZ','电商客户','other','',420,'completed','cs_service','wechat','shipinhao','视频号-靓仔台球','SPH20260405004','DAB002',1,420,'2026-04-05 14:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',1280,'completed','cs_service','wechat','shipinhao','视频号-王孟南台球教学','SPH20260406005','DAD003',1,1280,'2026-04-06 10:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','8e61cf60-b35e-4141-818f-52a81df75b05','EC-SPH-LZ','电商客户','other','',5200,'completed','cs_service','wechat','shipinhao','视频号-靓仔台球','SPH20260407006','DAD005',1,5200,'2026-04-07 09:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',320,'pending','cs_service','wechat','shipinhao','视频号-王孟南台球教学','SPH20260408007','DAD011',1,320,'2026-04-08 15:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','8e61cf60-b35e-4141-818f-52a81df75b05','EC-SPH-LZ','电商客户','other','',980,'completed','cs_service','wechat','shipinhao','视频号-靓仔台球','SPH20260401008','TA013',1,980,'2026-04-01 18:00:00+08'),
('5f7e2488-5d6b-47eb-8a59-a6d43c8aa3f5','d56be961-42a7-40dc-986c-0c6f475d8470','EC-SPH-WMN','电商客户','other','',1860,'completed','cs_service','wechat','shipinhao','视频号-王孟南台球教学','SPH20260402009','TA163',1,1860,'2026-04-02 20:30:00+08');
