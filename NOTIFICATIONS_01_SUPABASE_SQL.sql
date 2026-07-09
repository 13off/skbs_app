-- Таблица уведомлений AppСтрой
-- Выполнить в Supabase SQL Editor один раз.

create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  actor_email text not null default '',
  object_name text not null default '',
  entity_type text not null default '',
  entity_id text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists app_notifications_created_at_idx
  on public.app_notifications (created_at desc);

create index if not exists app_notifications_object_name_idx
  on public.app_notifications (object_name);

alter table public.app_notifications enable row level security;

drop policy if exists "app_notifications_select_authenticated" on public.app_notifications;
create policy "app_notifications_select_authenticated"
  on public.app_notifications
  for select
  to authenticated
  using (true);

drop policy if exists "app_notifications_insert_authenticated" on public.app_notifications;
create policy "app_notifications_insert_authenticated"
  on public.app_notifications
  for insert
  to authenticated
  with check (true);
