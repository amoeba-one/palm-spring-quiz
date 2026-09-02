-- Palm Spring quiz library: run once in the Supabase SQL editor.
-- Change the password on the app_secret line before running.

create extension if not exists pgcrypto;

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  rounds jsonb not null default '[]'::jsonb,
  jokers boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.quizzes enable row level security;
drop policy if exists "public read" on public.quizzes;
create policy "public read" on public.quizzes for select to anon, authenticated using (true);
grant select on public.quizzes to anon, authenticated;

create table if not exists public.app_secret (
  id int primary key default 1 check (id = 1),
  password text not null
);
alter table public.app_secret enable row level security;
revoke all on public.app_secret from anon, authenticated;
insert into public.app_secret (id, password) values (1, 'CHANGE-ME' -- set your family password here)
  on conflict (id) do update set password = excluded.password;

create or replace function public.check_pw(pw text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from app_secret where password = pw) then
    raise exception 'invalid password' using errcode = '28000';
  end if;
end $$;

create or replace function public.save_quiz(pw text, quiz jsonb) returns public.quizzes
language plpgsql security definer set search_path = public as $$
declare
  qid uuid := nullif(quiz->>'id','')::uuid;
  row public.quizzes;
begin
  perform check_pw(pw);
  if qid is not null and exists (select 1 from quizzes where id = qid) then
    update quizzes set title = quiz->>'title', rounds = coalesce(quiz->'rounds','[]'::jsonb), jokers = coalesce((quiz->>'jokers')::boolean,true), updated_at = now()
      where id = qid returning * into row;
  else
    insert into quizzes (id, title, rounds, jokers) values (coalesce(qid, gen_random_uuid()), quiz->>'title', coalesce(quiz->'rounds','[]'::jsonb), coalesce((quiz->>'jokers')::boolean,true))
      returning * into row;
  end if;
  return row;
end $$;

create or replace function public.delete_quiz(pw text, qid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform check_pw(pw);
  delete from quizzes where id = qid;
end $$;

revoke all on function public.check_pw(text) from public, anon, authenticated;
grant execute on function public.save_quiz(text, jsonb) to anon, authenticated;
grant execute on function public.delete_quiz(text, uuid) to anon, authenticated;
