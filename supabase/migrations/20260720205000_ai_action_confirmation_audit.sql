create table if not exists public.ai_action_audit (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  action_id text not null,
  action_type text not null,
  object_name text,
  proposal jsonb not null default '{}'::jsonb,
  status text not null default 'proposed'
    check (status in ('proposed', 'confirmed', 'cancelled', 'completed', 'failed')),
  target_entity_type text,
  target_entity_id text,
  error_text text,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (company_id, user_id, action_id)
);

create index if not exists ai_action_audit_company_created_idx
  on public.ai_action_audit (company_id, created_at desc);

create index if not exists ai_action_audit_user_created_idx
  on public.ai_action_audit (user_id, created_at desc);

create index if not exists ai_action_audit_company_status_idx
  on public.ai_action_audit (company_id, status, created_at desc);

alter table public.ai_action_audit enable row level security;

revoke all on table public.ai_action_audit from anon;
grant select, insert, update on table public.ai_action_audit to authenticated;

create policy ai_action_audit_select
on public.ai_action_audit
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_company_admin(company_id))
);

create policy ai_action_audit_insert
on public.ai_action_audit
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_company_member(company_id))
  and status = 'proposed'
);

create policy ai_action_audit_update_own
on public.ai_action_audit
for update
to authenticated
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_company_member(company_id))
)
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_company_member(company_id))
);

comment on table public.ai_action_audit is
  'Audit trail for AI-proposed actions that require explicit human confirmation.';
comment on column public.ai_action_audit.proposal is
  'Exact non-secret action proposal shown to the user before confirmation.';
