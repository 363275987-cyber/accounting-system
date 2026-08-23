-- 收件箱:剪辑师/打点员在 切片工坊 或 打点页 里提交问题(截图+文字),南哥的 Mac 上取件
CREATE TABLE IF NOT EXISTS pool_feedback (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source TEXT NOT NULL,            -- 切片工坊 / 打点页
  who TEXT DEFAULT '',
  text TEXT DEFAULT '',
  context TEXT DEFAULT '',         -- 项目/日期/页面等自动附带的信息
  image TEXT DEFAULT '',           -- data:image/...;base64 (≤1.5MB)
  status TEXT NOT NULL DEFAULT 'new',   -- new / seen / done
  reply TEXT DEFAULT ''
);
ALTER TABLE pool_feedback ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pool_feedback_anon ON pool_feedback;
CREATE POLICY pool_feedback_anon ON pool_feedback FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS pool_feedback_status_idx ON pool_feedback(status, created_at);
NOTIFY pgrst, 'reload schema';
