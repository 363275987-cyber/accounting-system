-- 开新场自检:页面加载时调用;若比分/阶段是前一个营业日留下的(忘了收场),自动补收场并归零
create or replace function pool_fresh_check(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score; last_ts text;
begin
  select * into r from pool_score where id = 1;
  if r.a = 0 and r.b = 0 and r.stage = 0 and not r.stage_active then
    return r;
  end if;
  select max(ts) into last_ts from (
    select ts from pool_score_events union all select ts from pool_stage_events) t;
  if last_ts is null then return r; end if;
  if to_char(last_ts::timestamp - interval '6 hours', 'YYYY-MM-DD')
     < to_char(p_ts::timestamp - interval '6 hours', 'YYYY-MM-DD') then
    if r.stage_active then
      insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
    end if;
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'match_end');
    update pool_score set a = 0, b = 0, stage = 0, stage_active = false
      where id = 1 returning * into r;
    insert into pool_score_events (ts, a, b) values (p_ts, 0, 0);
  end if;
  return r;
end $$;
