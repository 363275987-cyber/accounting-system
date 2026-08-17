-- 台球直播打点上云(pool_ 前缀,与账目业务完全隔离)
-- 手机打点页(GitHub Pages /dadian/)直连这些表;Mac 端切片系统定时同步回本地。

create table if not exists pool_marks (
  id bigint generated always as identity primary key,
  session_date text not null,          -- 营业日(凌晨6点前算前一天)
  ts text not null,                    -- 打点时刻,本地时间 ISO
  category text not null,
  note text default '',
  marker text default '',
  score text default '',
  deleted boolean default false,
  created_at timestamptz default now()
);
create index if not exists pool_marks_date_idx on pool_marks (session_date);

create table if not exists pool_chips (
  id bigint generated always as identity primary key,
  label text unique not null
);

create table if not exists pool_score (
  id int primary key,
  a int not null default 0,
  b int not null default 0,
  name_a text not null default '南哥',
  name_b text not null default '对手'
);

create table if not exists pool_score_events (
  id bigint generated always as identity primary key,
  ts text not null,
  a int not null,
  b int not null
);

insert into pool_score (id) values (1) on conflict do nothing;
insert into pool_chips (label) values
  ('翻袋'),('清台'),('斯诺克'),('接管'),('翻盘'),('绝杀'),
  ('整活'),('口误'),('破防'),('名场面'),('赛点'),('逆转'),('关键局')
on conflict do nothing;

-- 打点属半公开数据,开放匿名读写(页面另有口令挡路人)
alter table pool_marks enable row level security;
alter table pool_chips enable row level security;
alter table pool_score enable row level security;
alter table pool_score_events enable row level security;
drop policy if exists pool_marks_all on pool_marks;
create policy pool_marks_all on pool_marks for all using (true) with check (true);
drop policy if exists pool_chips_all on pool_chips;
create policy pool_chips_all on pool_chips for all using (true) with check (true);
drop policy if exists pool_score_all on pool_score;
create policy pool_score_all on pool_score for all using (true) with check (true);
drop policy if exists pool_score_events_all on pool_score_events;
create policy pool_score_events_all on pool_score_events for all using (true) with check (true);

-- 原子记分(多人同时点不丢数)
create or replace function pool_bump_score(p_side text, p_delta int, p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  update pool_score set
    a = case when p_side = 'a' then greatest(0, a + p_delta) else a end,
    b = case when p_side = 'b' then greatest(0, b + p_delta) else b end
  where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b) values (p_ts, r.a, r.b);
  return r;
end $$;

create or replace function pool_reset_score(p_ts text)
returns pool_score language plpgsql security definer as $$
declare r pool_score;
begin
  update pool_score set a = 0, b = 0 where id = 1 returning * into r;
  insert into pool_score_events (ts, a, b) values (p_ts, 0, 0);
  return r;
end $$;
