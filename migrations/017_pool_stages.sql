-- 台球直播:比赛阶段(一晚打多个阶段,开始新阶段自动比分清零,打点带阶段号)
alter table pool_score add column if not exists stage int not null default 0;
alter table pool_score add column if not exists stage_active boolean not null default false;
alter table pool_marks add column if not exists stage int default 0;

create table if not exists pool_stage_events (
  id bigint generated always as identity primary key,
  ts text not null,
  stage int not null,
  action text not null   -- start / end
);
alter table pool_stage_events enable row level security;
drop policy if exists pool_stage_events_all on pool_stage_events;
create policy pool_stage_events_all on pool_stage_events for all using (true) with check (true);

create or replace function pool_stage_ctl(p_action text, p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  if p_action = 'start' then
    update pool_score set stage = stage + 1, stage_active = true, a = 0, b = 0
      where id = 1 returning * into r;
    insert into pool_score_events (ts, a, b) values (p_ts, 0, 0);
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'start');
  else
    update pool_score set stage_active = false where id = 1 returning * into r;
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
  end if;
  return r;
end $$;

-- v2: 开始时手动选阶段号(可跳过某阶段),不再自动+1
create or replace function pool_stage_ctl(p_action text, p_ts text, p_stage int default null)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  if p_action = 'start' then
    update pool_score set stage = coalesce(p_stage, stage + 1), stage_active = true, a = 0, b = 0
      where id = 1 returning * into r;
    insert into pool_score_events (ts, a, b) values (p_ts, 0, 0);
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'start');
  else
    update pool_score set stage_active = false where id = 1 returning * into r;
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
  end if;
  return r;
end $$;

-- v3: 四个阶段比分连续累计,开始新阶段不清零(清零只走手动按钮)
create or replace function pool_stage_ctl(p_action text, p_ts text, p_stage int default null)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  if p_action = 'start' then
    update pool_score set stage = coalesce(p_stage, stage + 1), stage_active = true
      where id = 1 returning * into r;
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'start');
  else
    update pool_score set stage_active = false where id = 1 returning * into r;
    insert into pool_stage_events (ts, stage, action) values (p_ts, r.stage, 'end');
  end if;
  return r;
end $$;
