-- 整场比赛收场:结束当前阶段(如在进行)、记 match_end 事件、比分和阶段归零备明晚
create or replace function pool_match_end(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  select * into r from pool_score where id = 1;
  if r.stage_active then
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
  end if;
  insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'match_end');
  update pool_score set stage = 0, stage_active = false, a = 0, b = 0
    where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b) values (p_ts, 0, 0);
  return r;
end $$;
