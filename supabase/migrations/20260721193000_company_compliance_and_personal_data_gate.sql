alter table public.recruitment_applications
  add column if not exists is_test_record boolean not null default false;

create table if not exists public.company_employer_profiles (
  company_id uuid primary key references public.companies(id) on delete cascade,
  legal_name text not null default '',
  short_name text not null default '',
  legal_address text not null default '',
  actual_address text not null default '',
  inn text not null default '',
  kpp text not null default '',
  ogrn text not null default '',
  bank_name text not null default '',
  bank_account text not null default '',
  bank_bik text not null default '',
  bank_corr_account text not null default '',
  representative_name text not null default '',
  representative_position text not null default '',
  representative_basis text not null default '',
  contract_city text not null default '',
  work_schedule text not null default '',
  salary_terms_template text not null default '',
  retention_policy text not null default '',
  legal_documents_approved boolean not null default false,
  approved_by_name text not null default '',
  approved_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.company_personal_data_gates (
  company_id uuid primary key references public.companies(id) on delete cascade,
  real_documents_enabled boolean not null default false,
  russian_storage_location_confirmed boolean not null default false,
  data_controller_details_approved boolean not null default false,
  personal_data_consent_approved boolean not null default false,
  retention_and_deletion_policy_approved boolean not null default false,
  download_audit_log_verified boolean not null default false,
  backup_and_restore_tested boolean not null default false,
  access_offboarding_tested boolean not null default false,
  incident_response_owner_assigned boolean not null default false,
  storage_region text not null default '',
  retention_days integer not null default 0 check (retention_days >= 0),
  deletion_policy text not null default '',
  incident_owner text not null default '',
  approved_by_name text not null default '',
  approved_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.company_personal_data_gate_audit (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  changed_by uuid references auth.users(id) on delete set null,
  old_state jsonb not null default '{}'::jsonb,
  new_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.personal_data_access_log (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  action text not null check (action = any (array[
    'generate'::text,
    'view'::text,
    'download'::text,
    'upload'::text,
    'replace'::text,
    'delete'::text
  ])),
  entity_type text not null,
  entity_id text not null,
  file_path text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists company_employer_profiles_updated_by_fk_idx
  on public.company_employer_profiles(updated_by);
create index if not exists company_personal_data_gates_updated_by_fk_idx
  on public.company_personal_data_gates(updated_by);
create index if not exists company_personal_data_gate_audit_company_created_idx
  on public.company_personal_data_gate_audit(company_id, created_at desc);
create index if not exists company_personal_data_gate_audit_changed_by_fk_idx
  on public.company_personal_data_gate_audit(changed_by);
create index if not exists personal_data_access_log_company_created_idx
  on public.personal_data_access_log(company_id, created_at desc);
create index if not exists personal_data_access_log_user_fk_idx
  on public.personal_data_access_log(user_id);

insert into public.role_permissions (role_code, permission_code)
values
  ('owner', 'personal_data.compliance.view'),
  ('admin', 'personal_data.compliance.view'),
  ('developer', 'personal_data.compliance.view'),
  ('hr', 'personal_data.compliance.view'),
  ('lawyer', 'personal_data.compliance.view'),
  ('owner', 'personal_data.compliance.edit'),
  ('admin', 'personal_data.compliance.edit'),
  ('developer', 'personal_data.compliance.edit'),
  ('lawyer', 'personal_data.compliance.edit'),
  ('owner', 'personal_data.audit.view'),
  ('admin', 'personal_data.audit.view'),
  ('developer', 'personal_data.audit.view'),
  ('lawyer', 'personal_data.audit.view')
on conflict (role_code, permission_code) do nothing;

grant select, insert, update on public.company_employer_profiles to authenticated;
grant select, insert, update on public.company_personal_data_gates to authenticated;
grant select on public.company_personal_data_gate_audit to authenticated;
grant select, insert on public.personal_data_access_log to authenticated;

alter table public.company_employer_profiles enable row level security;
alter table public.company_personal_data_gates enable row level security;
alter table public.company_personal_data_gate_audit enable row level security;
alter table public.personal_data_access_log enable row level security;

drop policy if exists company_employer_profiles_select on public.company_employer_profiles;
create policy company_employer_profiles_select
  on public.company_employer_profiles
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.view')
  );

drop policy if exists company_employer_profiles_insert on public.company_employer_profiles;
create policy company_employer_profiles_insert
  on public.company_employer_profiles
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
    and updated_by = (select auth.uid())
  );

drop policy if exists company_employer_profiles_update on public.company_employer_profiles;
create policy company_employer_profiles_update
  on public.company_employer_profiles
  for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
    and updated_by = (select auth.uid())
  );

drop policy if exists company_personal_data_gates_select on public.company_personal_data_gates;
create policy company_personal_data_gates_select
  on public.company_personal_data_gates
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.view')
  );

drop policy if exists company_personal_data_gates_insert on public.company_personal_data_gates;
create policy company_personal_data_gates_insert
  on public.company_personal_data_gates
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
    and updated_by = (select auth.uid())
  );

drop policy if exists company_personal_data_gates_update on public.company_personal_data_gates;
create policy company_personal_data_gates_update
  on public.company_personal_data_gates
  for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.compliance.edit')
    and updated_by = (select auth.uid())
  );

drop policy if exists company_personal_data_gate_audit_select on public.company_personal_data_gate_audit;
create policy company_personal_data_gate_audit_select
  on public.company_personal_data_gate_audit
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.audit.view')
  );

drop policy if exists personal_data_access_log_select on public.personal_data_access_log;
create policy personal_data_access_log_select
  on public.personal_data_access_log
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('personal_data.audit.view')
  );

drop policy if exists personal_data_access_log_insert on public.personal_data_access_log;
create policy personal_data_access_log_insert
  on public.personal_data_access_log
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and user_id = (select auth.uid())
    and public.current_user_has_permission('personal_data.compliance.view')
  );

create or replace function private.validate_company_personal_data_gate()
returns trigger
language plpgsql
set search_path = public, private
as $$
declare
  employer_approved boolean := false;
begin
  new.updated_at := now();
  new.updated_by := auth.uid();

  if new.real_documents_enabled then
    select coalesce(p.legal_documents_approved, false)
      into employer_approved
      from public.company_employer_profiles p
      where p.company_id = new.company_id;

    if not coalesce(employer_approved, false)
       or not new.russian_storage_location_confirmed
       or not new.data_controller_details_approved
       or not new.personal_data_consent_approved
       or not new.retention_and_deletion_policy_approved
       or not new.download_audit_log_verified
       or not new.backup_and_restore_tested
       or not new.access_offboarding_tested
       or not new.incident_response_owner_assigned
       or btrim(new.storage_region) = ''
       or new.retention_days <= 0
       or btrim(new.deletion_policy) = ''
       or btrim(new.incident_owner) = ''
       or btrim(new.approved_by_name) = ''
       or new.approved_at is null then
      raise exception 'Production gate cannot be enabled until every evidence item and employer approval is complete';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_company_personal_data_gate() from public;

drop trigger if exists validate_company_personal_data_gate_before_write
  on public.company_personal_data_gates;
create trigger validate_company_personal_data_gate_before_write
  before insert or update on public.company_personal_data_gates
  for each row execute function private.validate_company_personal_data_gate();

create or replace function private.audit_company_personal_data_gate()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  insert into public.company_personal_data_gate_audit(
    company_id,
    changed_by,
    old_state,
    new_state
  ) values (
    new.company_id,
    auth.uid(),
    case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end,
    to_jsonb(new)
  );
  return new;
end;
$$;

revoke all on function private.audit_company_personal_data_gate() from public;

drop trigger if exists audit_company_personal_data_gate_after_write
  on public.company_personal_data_gates;
create trigger audit_company_personal_data_gate_after_write
  after insert or update on public.company_personal_data_gates
  for each row execute function private.audit_company_personal_data_gate();
