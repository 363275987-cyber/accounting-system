-- 记分模式:duo双人 / target追分(目标分+让分起步) / trio三人 / quad四人
alter table pool_score add column if not exists mode text not null default 'duo';
alter table pool_score add column if not exists target int not null default 0;
alter table pool_score add column if not exists c int not null default 0;
alter table pool_score add column if not exists d int not null default 0;
alter table pool_score add column if not exists name_c text not null default '选手C';
alter table pool_score add column if not exists name_d text not null default '选手D';
alter table pool_score_events add column if not exists c int not null default 0;
alter table pool_score_events add column if not exists d int not null default 0;

create or replace function pool_bump_score(p_side text, p_delta int, p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  update pool_score set
    a = case when p_side = 'a' then greatest(0, a + p_delta) else a end,
    b = case when p_side = 'b' then greatest(0, b + p_delta) else b end,
    c = case when p_side = 'c' then greatest(0, c + p_delta) else c end,
    d = case when p_side = 'd' then greatest(0, d + p_delta) else d end
  where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b, c, d) values (p_ts, r.a, r.b, r.c, r.d);
  return r;
end $$;

create or replace function pool_reset_score(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  update pool_score set a = 0, b = 0, c = 0, d = 0 where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b, c, d) values (p_ts, 0, 0, 0, 0);
  return r;
end $$;

create or replace function pool_match_end(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  select * into r from pool_score where id = 1;
  if r.stage_active then
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
  end if;
  insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'match_end');
  update pool_score set a = 0, b = 0, c = 0, d = 0, stage = 0, stage_active = false
    where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b, c, d) values (p_ts, 0, 0, 0, 0);
  return r;
end $$;

create or replace function pool_fresh_check(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score; last_ts text;
begin
  select * into r from pool_score where id = 1;
  if r.a = 0 and r.b = 0 and r.c = 0 and r.d = 0 and r.stage = 0 and not r.stage_active then
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
    update pool_score set a = 0, b = 0, c = 0, d = 0, stage = 0, stage_active = false
      where id = 1 returning * into r;
    insert into pool_score_events (ts, a, b, c, d) values (p_ts, 0, 0, 0, 0);
  end if;
  return r;
end $$;
