-- AppСтрой Документооборот v3: неразрушающий фундамент.
-- Существующие document_templates/document_template_versions переиспользуются.

create table if not exists public.document_tool_installations (
  company_id uuid primary key references public.companies(id) on delete cascade,
  is_enabled boolean not null default false,
  settings jsonb not null default '{}'::jsonb,
  enabled_at timestamptz,
  enabled_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_packages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  code text not null,
  title text not null,
  description text not null default '',
  onboarding_type text not null default 'custom',
  is_active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, code)
);

create table if not exists public.document_package_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  package_id uuid not null references public.document_packages(id) on delete cascade,
  template_id uuid not null references public.document_templates(id) on delete restrict,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  unique (package_id, template_id)
);

create table if not exists public.employee_onboardings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid,
  package_id uuid references public.document_packages(id) on delete set null,
  status text not null default 'draft',
  current_step text not null default 'source_files',
  onboarding_type text not null default 'custom',
  object_id uuid,
  assigned_user_id uuid,
  due_at timestamptz,
  conditions jsonb not null default '{}'::jsonb,
  completion_snapshot jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by uuid,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.employee_onboarding_steps (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid not null references public.employee_onboardings(id) on delete cascade,
  step_code text not null,
  status text not null default 'pending',
  assigned_user_id uuid,
  is_required boolean not null default true,
  due_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (onboarding_id, step_code)
);

create table if not exists public.employee_document_files (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid references public.employee_onboardings(id) on delete cascade,
  employee_id uuid,
  file_kind text not null,
  document_type text not null,
  storage_bucket text not null,
  storage_path text not null,
  original_file_name text not null,
  mime_type text not null default 'application/octet-stream',
  file_size bigint,
  version_no integer not null default 1,
  template_id uuid references public.document_templates(id) on delete set null,
  template_version_id uuid references public.document_template_versions(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  quality_status text not null default 'not_checked',
  verification_status text not null default 'pending',
  uploaded_by uuid,
  created_at timestamptz not null default now(),
  unique (company_id, storage_bucket, storage_path)
);

create table if not exists public.document_audit_log (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid references public.employee_onboardings(id) on delete set null,
  employee_id uuid,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  actor_user_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists document_packages_company_idx on public.document_packages(company_id, is_active);
create index if not exists document_package_templates_package_idx on public.document_package_templates(package_id, sort_order);
create index if not exists employee_onboardings_company_status_idx on public.employee_onboardings(company_id, status, updated_at desc);
create index if not exists employee_onboardings_employee_idx on public.employee_onboardings(employee_id, updated_at desc);
create index if not exists employee_onboarding_steps_process_idx on public.employee_onboarding_steps(onboarding_id, status);
create index if not exists employee_document_files_process_idx on public.employee_document_files(onboarding_id, file_kind, document_type);
create index if not exists employee_document_files_employee_idx on public.employee_document_files(employee_id, created_at desc);
create index if not exists document_audit_log_process_idx on public.document_audit_log(onboarding_id, created_at desc);

alter table public.document_tool_installations enable row level security;
alter table public.document_packages enable row level security;
alter table public.document_package_templates enable row level security;
alter table public.employee_onboardings enable row level security;
alter table public.employee_onboarding_steps enable row level security;
alter table public.employee_document_files enable row level security;
alter table public.document_audit_log enable row level security;

-- Используем существующую функцию членства компании, уже принятую в проекте.
-- Если её имя в актуальной схеме отличается, миграцию нужно адаптировать до применения.
do $$
begin
  if to_regprocedure('public.is_company_member(uuid)') is not null then
    execute $policy$
      create policy document_tool_installations_company_access
      on public.document_tool_installations
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy document_packages_company_access
      on public.document_packages
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy document_package_templates_company_access
      on public.document_package_templates
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy employee_onboardings_company_access
      on public.employee_onboardings
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy employee_onboarding_steps_company_access
      on public.employee_onboarding_steps
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy employee_document_files_company_access
      on public.employee_document_files
      for all to authenticated
      using (public.is_company_member(company_id))
      with check (public.is_company_member(company_id))
    $policy$;
    execute $policy$
      create policy document_audit_log_company_access
      on public.document_audit_log
      for select to authenticated
      using (public.is_company_member(company_id))
    $policy$;
  end if;
end $$;

revoke delete, truncate on public.document_audit_log from authenticated;
grant select, insert, update on public.document_tool_installations to authenticated;
grant select, insert, update on public.document_packages to authenticated;
grant select, insert, update, delete on public.document_package_templates to authenticated;
grant select, insert, update on public.employee_onboardings to authenticated;
grant select, insert, update on public.employee_onboarding_steps to authenticated;
grant select, insert, update on public.employee_document_files to authenticated;
grant select, insert on public.document_audit_log to authenticated;

comment on table public.document_tool_installations is 'Feature gate and company settings for AppСтрой Документооборот.';
comment on table public.employee_onboardings is 'Full employee document onboarding lifecycle; reuses existing employee and template sources.';
comment on table public.employee_document_files is 'Source, generated, signed and final scan files with immutable versions.';