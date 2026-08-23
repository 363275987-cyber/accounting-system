-- 打点归属选手(高光/搞笑等可选谁的;清台自动写入)
alter table pool_marks add column if not exists player text not null default '';
