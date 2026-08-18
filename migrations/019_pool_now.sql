-- 服务器授时:打点页启动时对表,消除各手机时钟不准导致的打点偏移
create or replace function pool_now() returns text language sql stable as $$
  select to_char(now() at time zone 'Asia/Shanghai', 'YYYY-MM-DD"T"HH24:MI:SS')
$$;
