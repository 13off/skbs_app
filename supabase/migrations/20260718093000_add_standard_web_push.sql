create table if not exists public.web_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  device_id text not null check (btrim(device_id) <> ''),
  endpoint text not null unique check (endpoint ~ '^https://'),
  p256dh text not null check (btrim(p256dh) <> ''),
  auth text not null check (btrim(auth) <> ''),
  expiration_time bigint,
  user_agent text not null default '',
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, user_id, device_id)
);

comment on table public.web_push_subscriptions is
  'Standards-based Web Push subscriptions for installed AppСтрой web apps, including iPhone Home Screen apps.';

create index if not exists web_push_subscriptions_recipient_idx
  on public.web_push_subscriptions(company_id, user_id)
  where enabled = true;

alter table public.web_push_subscriptions enable row level security;
revoke all on table public.web_push_subscriptions from public, anon, authenticated;
grant all on table public.web_push_subscriptions to service_role;

create or replace function public.get_push_secret(p_name text)
returns text
language sql
stable
security definer
set search_path = public, vault, pg_temp
as $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = p_name
    and p_name in ('appstroy_web_push_vapid_private_key')
  order by created_at desc
  limit 1;
$$;

revoke all on function public.get_push_secret(text) from public, anon, authenticated;
grant execute on function public.get_push_secret(text) to service_role;

create or replace function private.cleanup_web_push_after_membership_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.web_push_subscriptions
  where company_id = old.company_id
    and user_id = old.user_id;
  return old;
end;
$$;

revoke all on function private.cleanup_web_push_after_membership_delete() from public, anon, authenticated;
grant execute on function private.cleanup_web_push_after_membership_delete() to service_role;

drop trigger if exists company_memberships_cleanup_web_push
  on public.company_memberships;
create trigger company_memberships_cleanup_web_push
after delete on public.company_memberships
for each row execute function private.cleanup_web_push_after_membership_delete();
