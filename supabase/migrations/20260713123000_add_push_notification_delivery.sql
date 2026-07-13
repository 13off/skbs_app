-- Push-уведомления работают поверх существующего внутреннего колокольчика.
-- Клиент может управлять только собственным устройством через SECURITY DEFINER RPC.

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  token text not null,
  device_id text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_device_tokens_token_not_blank check (btrim(token) <> ''),
  constraint push_device_tokens_device_not_blank check (btrim(device_id) <> '')
);

create unique index if not exists push_device_tokens_token_key
  on public.push_device_tokens (token);
create unique index if not exists push_device_tokens_user_device_key
  on public.push_device_tokens (user_id, device_id);
create index if not exists push_device_tokens_user_company_idx
  on public.push_device_tokens (user_id, company_id);
create index if not exists push_device_tokens_company_enabled_idx
  on public.push_device_tokens (company_id, enabled, user_id)
  where enabled = true;

alter table public.push_device_tokens enable row level security;

drop policy if exists "users read own push devices" on public.push_device_tokens;
create policy "users read own push devices"
  on public.push_device_tokens
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.company_memberships membership
      where membership.company_id = push_device_tokens.company_id
        and membership.user_id = (select auth.uid())
        and membership.is_active = true
    )
  );

revoke all on table public.push_device_tokens from anon, authenticated;
grant select on table public.push_device_tokens to authenticated;
grant all on table public.push_device_tokens to service_role;

create or replace function public.register_current_push_device(
  p_token text,
  p_device_id text,
  p_platform text,
  p_enabled boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := (select auth.uid());
  current_company_id uuid := public.current_user_company_id();
  inserted_id uuid;
begin
  if current_user_id is null then
    raise exception 'Требуется авторизация';
  end if;
  if current_company_id is null then
    raise exception 'Не выбрана активная компания';
  end if;
  if btrim(coalesce(p_token, '')) = '' or btrim(coalesce(p_device_id, '')) = '' then
    raise exception 'Токен и идентификатор устройства обязательны';
  end if;
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'Недопустимая платформа';
  end if;
  if not exists (
    select 1
    from public.company_memberships membership
    where membership.company_id = current_company_id
      and membership.user_id = current_user_id
      and membership.is_active = true
  ) then
    raise exception 'Нет доступа к активной компании';
  end if;

  -- Один физический браузер/телефон принадлежит только текущей сессии и компании.
  delete from public.push_device_tokens
  where token = btrim(p_token)
     or (user_id = current_user_id and device_id = btrim(p_device_id));

  insert into public.push_device_tokens (
    user_id,
    company_id,
    token,
    device_id,
    platform,
    enabled,
    last_seen_at,
    updated_at
  ) values (
    current_user_id,
    current_company_id,
    btrim(p_token),
    btrim(p_device_id),
    p_platform,
    coalesce(p_enabled, true),
    now(),
    now()
  )
  returning id into inserted_id;

  return inserted_id;
end;
$$;

create or replace function public.set_current_push_device_enabled(
  p_device_id text,
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;

  update public.push_device_tokens
  set enabled = coalesce(p_enabled, false),
      last_seen_at = now(),
      updated_at = now()
  where user_id = (select auth.uid())
    and device_id = btrim(coalesce(p_device_id, ''));
end;
$$;

create or replace function public.unregister_current_push_device(
  p_device_id text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;

  delete from public.push_device_tokens
  where user_id = (select auth.uid())
    and device_id = btrim(coalesce(p_device_id, ''));
end;
$$;

revoke all on function public.register_current_push_device(text, text, text, boolean) from public, anon;
revoke all on function public.set_current_push_device_enabled(text, boolean) from public, anon;
revoke all on function public.unregister_current_push_device(text) from public, anon;
grant execute on function public.register_current_push_device(text, text, text, boolean) to authenticated;
grant execute on function public.set_current_push_device_enabled(text, boolean) to authenticated;
grant execute on function public.unregister_current_push_device(text) to authenticated;

create table if not exists public.push_notification_deliveries (
  notification_id uuid primary key references public.app_notifications(id) on delete cascade,
  status text not null check (
    status in ('processing', 'sent', 'partial', 'no_recipients', 'failed')
  ),
  attempted_at timestamptz not null default now(),
  completed_at timestamptz,
  sent_count integer not null default 0 check (sent_count >= 0),
  failure_count integer not null default 0 check (failure_count >= 0),
  details jsonb not null default '{}'::jsonb
);

create index if not exists push_notification_deliveries_status_idx
  on public.push_notification_deliveries (status, attempted_at desc);

alter table public.push_notification_deliveries enable row level security;
revoke all on table public.push_notification_deliveries from anon, authenticated;
grant all on table public.push_notification_deliveries to service_role;

comment on table public.push_device_tokens is
  'FCM tokens scoped to one authenticated user and company. Direct writes are blocked; use RPC.';
comment on table public.push_notification_deliveries is
  'Server-only idempotency and delivery result for pushes created from app_notifications.';
