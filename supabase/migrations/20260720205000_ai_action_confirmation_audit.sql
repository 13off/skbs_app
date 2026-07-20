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
revoke update, delete on table public.ai_action_audit from authenticated;
grant select, insert on table public.ai_action_audit to authenticated;

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
  and target_entity_type is null
  and target_entity_id is null
  and error_text is null
  and confirmed_at is null
  and completed_at is null
);

create or replace function public.transition_ai_action_audit(
  p_audit_id uuid,
  p_status text,
  p_target_entity_type text default null,
  p_target_entity_id text default null,
  p_error_text text default null
)
returns public.ai_action_audit
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.ai_action_audit;
  v_now timestamptz := now();
begin
  if p_status not in ('confirmed', 'cancelled', 'completed', 'failed') then
    raise exception 'Недопустимый статус аудита';
  end if;

  select *
  into v_row
  from public.ai_action_audit
  where id = p_audit_id
    and user_id = auth.uid()
    and company_id = public.current_user_company_id()
    and public.is_company_member(company_id)
  for update;

  if not found then
    raise exception 'Запись аудита не найдена или недоступна';
  end if;

  if not (
    (v_row.status = 'proposed' and p_status in ('confirmed', 'cancelled', 'failed'))
    or (v_row.status = 'confirmed' and p_status in ('completed', 'cancelled', 'failed'))
  ) then
    raise exception 'Недопустимый переход статуса: % -> %', v_row.status, p_status;
  end if;

  update public.ai_action_audit
  set status = p_status,
      confirmed_at = case
        when p_status = 'confirmed' then v_now
        else confirmed_at
      end,
      completed_at = case
        when p_status in ('completed', 'failed') then v_now
        else completed_at
      end,
      target_entity_type = case
        when p_status = 'completed' then nullif(trim(p_target_entity_type), '')
        else target_entity_type
      end,
      target_entity_id = case
        when p_status = 'completed' then nullif(trim(p_target_entity_id), '')
        else target_entity_id
      end,
      error_text = case
        when p_status = 'failed' then left(nullif(trim(p_error_text), ''), 1000)
        else error_text
      end,
      updated_at = v_now
  where id = p_audit_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.transition_ai_action_audit(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.transition_ai_action_audit(uuid, text, text, text, text)
  to authenticated;

comment on table public.ai_action_audit is
  'Audit trail for AI-proposed actions that require explicit human confirmation.';
comment on column public.ai_action_audit.proposal is
  'Immutable non-secret action proposal shown to the user before confirmation.';
comment on function public.transition_ai_action_audit(uuid, text, text, text, text) is
  'Performs owner-only validated state transitions without allowing proposal mutation.';
