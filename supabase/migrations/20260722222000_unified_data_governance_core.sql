alter table public.attendance
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id) on delete set null,
  add column if not exists delete_reason text not null default '',
  add column if not exists restored_at timestamptz,
  add column if not exists restored_by uuid references auth.users(id) on delete set null;

alter table public.payments
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id) on delete set null,
  add column if not exists delete_reason text not null default '',
  add column if not exists restored_at timestamptz,
  add column if not exists restored_by uuid references auth.users(id) on delete set null;

alter table public.project_milestones
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references auth.users(id) on delete set null,
  add column if not exists delete_reason text not null default '',
  add column if not exists restored_at timestamptz,
  add column if not exists restored_by uuid references auth.users(id) on delete set null;

create index if not exists attendance_company_deleted_idx
  on public.attendance(company_id, deleted_at, work_date desc);
create index if not exists attendance_deleted_by_idx
  on public.attendance(deleted_by);
create index if not exists attendance_restored_by_idx
  on public.attendance(restored_by);
create index if not exists payments_company_deleted_idx
  on public.payments(company_id, deleted_at, payment_date desc);
create index if not exists payments_deleted_by_idx
  on public.payments(deleted_by);
create index if not exists payments_restored_by_idx
  on public.payments(restored_by);
create index if not exists milestones_company_deleted_idx
  on public.project_milestones(company_id, deleted_at, target_date desc);
create index if not exists milestones_deleted_by_idx
  on public.project_milestones(deleted_by);
create index if not exists milestones_restored_by_idx
  on public.project_milestones(restored_by);
create index if not exists audit_log_company_created_idx
  on public.audit_log(company_id, created_at desc);
create index if not exists audit_log_entity_idx
  on public.audit_log(company_id, entity_type, entity_id);

create or replace function public.core_entity_audit_after_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_company_id uuid;
  v_entity_id text;
  v_semantic_action text;
  v_changed jsonb := '{}'::jsonb;
begin
  v_old := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  v_new := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  v_row := coalesce(v_new, v_old);

  v_company_id := nullif(v_row ->> 'company_id', '')::uuid;
  v_entity_id := coalesce(v_row ->> 'id', '');
  if v_company_id is null or v_entity_id = '' then
    return null;
  end if;

  if tg_op = 'INSERT' then
    v_semantic_action := 'created';
  elsif tg_op = 'DELETE' then
    v_semantic_action := 'deleted';
  else
    if coalesce(v_old ->> 'deleted_at', '') = ''
       and coalesce(v_new ->> 'deleted_at', '') <> '' then
      v_semantic_action := 'archived';
    elsif coalesce(v_old ->> 'deleted_at', '') <> ''
       and coalesce(v_new ->> 'deleted_at', '') = '' then
      v_semantic_action := 'restored';
    elsif tg_table_name = 'employees'
       and coalesce((v_old ->> 'is_active')::boolean, true)
       and not coalesce((v_new ->> 'is_active')::boolean, true) then
      v_semantic_action := 'archived';
    elsif tg_table_name = 'employees'
       and not coalesce((v_old ->> 'is_active')::boolean, true)
       and coalesce((v_new ->> 'is_active')::boolean, true) then
      v_semantic_action := 'restored';
    elsif tg_table_name = 'objects'
       and coalesce((v_old ->> 'is_active')::boolean, true)
       and not coalesce((v_new ->> 'is_active')::boolean, true) then
      v_semantic_action := 'archived';
    elsif tg_table_name = 'objects'
       and not coalesce((v_old ->> 'is_active')::boolean, true)
       and coalesce((v_new ->> 'is_active')::boolean, true) then
      v_semantic_action := 'restored';
    else
      v_semantic_action := 'updated';
    end if;

    select coalesce(jsonb_object_agg(key, true), '{}'::jsonb)
      into v_changed
      from jsonb_object_keys(
        coalesce(v_old, '{}'::jsonb) || coalesce(v_new, '{}'::jsonb)
      ) as keys(key)
     where (v_old -> keys.key) is distinct from (v_new -> keys.key);
  end if;

  v_changed := v_changed || jsonb_build_object(
    '_semantic_action', v_semantic_action
  );

  insert into public.audit_log(
    company_id,
    entity_type,
    entity_id,
    action,
    actor_user_id,
    changed_fields,
    before_data,
    after_data
  ) values (
    v_company_id,
    tg_table_name,
    v_entity_id,
    tg_op,
    auth.uid(),
    v_changed,
    v_old,
    v_new
  );

  return null;
end;
$$;

revoke all on function public.core_entity_audit_after_change()
  from public, anon, authenticated;

drop trigger if exists employees_core_audit on public.employees;
create trigger employees_core_audit
after insert or update or delete on public.employees
for each row execute function public.core_entity_audit_after_change();

drop trigger if exists attendance_core_audit on public.attendance;
create trigger attendance_core_audit
after insert or update or delete on public.attendance
for each row execute function public.core_entity_audit_after_change();

drop trigger if exists payments_core_audit on public.payments;
create trigger payments_core_audit
after insert or update or delete on public.payments
for each row execute function public.core_entity_audit_after_change();

drop trigger if exists objects_core_audit on public.objects;
create trigger objects_core_audit
after insert or update or delete on public.objects
for each row execute function public.core_entity_audit_after_change();

drop trigger if exists milestones_core_audit on public.project_milestones;
create trigger milestones_core_audit
after insert or update or delete on public.project_milestones
for each row execute function public.core_entity_audit_after_change();

drop trigger if exists document_templates_core_audit on public.document_templates;
create trigger document_templates_core_audit
after insert or update or delete on public.document_templates
for each row execute function public.core_entity_audit_after_change();
