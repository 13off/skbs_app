-- AppСтрой Документооборот v3.
-- Неразрушающее расширение: существующие document_templates,
-- document_template_versions, recruitment_* и employees переиспользуются.

insert into public.permission_catalog
  (permission_code, category, title, description, supports_object_scope, sort_order)
values
  ('documents.workflow.view', 'Документооборот', 'Просмотр документооборота',
   'Открывать процессы оформления, файлы и статусы.', false, 530),
  ('documents.workflow.manage', 'Документооборот', 'Подключение инструмента',
   'Включать и отключать инструмент и менять настройки компании.', false, 540),
  ('documents.onboarding.create', 'Документооборот', 'Создание оформлений',
   'Создавать процесс оформления кандидата или сотрудника.', false, 550),
  ('documents.onboarding.edit', 'Документооборот', 'Ведение оформлений',
   'Заполнять этапы, условия и загружать документы.', false, 560),
  ('documents.onboarding.verify', 'Документооборот', 'Проверка документов',
   'Принимать или отклонять файлы и подтверждать юридически значимые этапы.', false, 570),
  ('documents.packages.manage', 'Документооборот', 'Пакеты документов',
   'Создавать и изменять наборы утверждённых шаблонов.', false, 580),
  ('documents.audit.view', 'Документооборот', 'История документооборота',
   'Просматривать журнал действий и версии файлов.', false, 590)
on conflict (permission_code) do update
set category = excluded.category,
    title = excluded.title,
    description = excluded.description,
    supports_object_scope = excluded.supports_object_scope,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.role_permissions (role_code, permission_code)
select role_code, permission_code
from (
  values
    ('owner', 'documents.workflow.view'),
    ('owner', 'documents.workflow.manage'),
    ('owner', 'documents.onboarding.create'),
    ('owner', 'documents.onboarding.edit'),
    ('owner', 'documents.onboarding.verify'),
    ('owner', 'documents.packages.manage'),
    ('owner', 'documents.audit.view'),
    ('admin', 'documents.workflow.view'),
    ('admin', 'documents.workflow.manage'),
    ('admin', 'documents.onboarding.create'),
    ('admin', 'documents.onboarding.edit'),
    ('admin', 'documents.onboarding.verify'),
    ('admin', 'documents.packages.manage'),
    ('admin', 'documents.audit.view'),
    ('developer', 'documents.workflow.view'),
    ('developer', 'documents.workflow.manage'),
    ('developer', 'documents.onboarding.create'),
    ('developer', 'documents.onboarding.edit'),
    ('developer', 'documents.onboarding.verify'),
    ('developer', 'documents.packages.manage'),
    ('developer', 'documents.audit.view'),
    ('hr', 'documents.workflow.view'),
    ('hr', 'documents.onboarding.create'),
    ('hr', 'documents.onboarding.edit'),
    ('hr', 'documents.onboarding.verify'),
    ('hr', 'documents.audit.view'),
    ('lawyer', 'documents.workflow.view'),
    ('lawyer', 'documents.onboarding.verify'),
    ('lawyer', 'documents.packages.manage'),
    ('lawyer', 'documents.audit.view'),
    ('lawyer', 'documents.templates.edit')
) as defaults(role_code, permission_code)
on conflict (role_code, permission_code) do nothing;

create table if not exists public.document_tool_installations (
  company_id uuid primary key references public.companies(id) on delete cascade,
  is_enabled boolean not null default false,
  settings jsonb not null default '{}'::jsonb,
  enabled_at timestamptz,
  enabled_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_tool_settings_object check (jsonb_typeof(settings) = 'object')
);

create table if not exists public.document_packages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  code text not null,
  title text not null,
  description text not null default '',
  onboarding_type text not null default 'custom',
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_packages_code_nonempty check (btrim(code) <> ''),
  constraint document_packages_title_nonempty check (btrim(title) <> ''),
  constraint document_packages_type_check check (
    onboarding_type in ('employment', 'gph', 'transfer', 'termination', 'custom')
  ),
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
  constraint document_package_templates_order_check check (sort_order >= 0),
  unique (package_id, template_id)
);

create table if not exists public.employee_onboardings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  recruitment_application_id uuid references public.recruitment_applications(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  package_id uuid references public.document_packages(id) on delete set null,
  status text not null default 'draft',
  current_step text not null default 'source_files',
  onboarding_type text not null default 'custom',
  object_id uuid references public.objects(id) on delete set null,
  assigned_user_id uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  conditions jsonb not null default '{}'::jsonb,
  recognized_data jsonb not null default '{}'::jsonb,
  verification_data jsonb not null default '{}'::jsonb,
  completion_snapshot jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint employee_onboardings_status_check check (
    status in ('draft', 'in_progress', 'blocked', 'completed', 'cancelled')
  ),
  constraint employee_onboardings_step_check check (
    current_step in (
      'source_files', 'source_completeness', 'recognition', 'hr_verification',
      'employee_card', 'package_and_conditions', 'generation', 'printing',
      'signing', 'signed_documents', 'final_scans', 'archive_verification',
      'completion'
    )
  ),
  constraint employee_onboardings_type_check check (
    onboarding_type in ('employment', 'gph', 'transfer', 'termination', 'custom')
  ),
  constraint employee_onboardings_json_check check (
    jsonb_typeof(conditions) = 'object'
    and jsonb_typeof(recognized_data) = 'object'
    and jsonb_typeof(verification_data) = 'object'
    and jsonb_typeof(completion_snapshot) = 'object'
  )
);

create table if not exists public.employee_onboarding_steps (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid not null references public.employee_onboardings(id) on delete cascade,
  step_code text not null,
  status text not null default 'pending',
  assigned_user_id uuid references auth.users(id) on delete set null,
  is_required boolean not null default true,
  due_at timestamptz,
  payload jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint employee_onboarding_steps_code_check check (
    step_code in (
      'source_files', 'source_completeness', 'recognition', 'hr_verification',
      'employee_card', 'package_and_conditions', 'generation', 'printing',
      'signing', 'signed_documents', 'final_scans', 'archive_verification',
      'completion'
    )
  ),
  constraint employee_onboarding_steps_status_check check (
    status in ('pending', 'in_progress', 'completed', 'blocked', 'skipped')
  ),
  constraint employee_onboarding_steps_payload_check check (jsonb_typeof(payload) = 'object'),
  unique (onboarding_id, step_code)
);

create table if not exists public.employee_document_files (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid references public.employee_onboardings(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  recruitment_document_id uuid references public.recruitment_documents(id) on delete set null,
  recruitment_onboarding_form_id uuid references public.recruitment_onboarding_forms(id) on delete set null,
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
  uploaded_by uuid references auth.users(id) on delete set null default auth.uid(),
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  constraint employee_document_files_kind_check check (
    file_kind in ('source', 'generated', 'signed', 'final_scan', 'archive')
  ),
  constraint employee_document_files_verification_check check (
    verification_status in ('pending', 'accepted', 'rejected')
  ),
  constraint employee_document_files_quality_check check (
    quality_status in (
      'not_checked', 'accepted', 'manual_review', 'blurred',
      'cropped', 'dark', 'unreadable', 'rejected'
    )
  ),
  constraint employee_document_files_size_check check (file_size is null or file_size >= 0),
  constraint employee_document_files_version_check check (version_no > 0),
  constraint employee_document_files_metadata_check check (jsonb_typeof(metadata) = 'object'),
  constraint employee_document_files_path_nonempty check (
    btrim(storage_bucket) <> '' and btrim(storage_path) <> ''
  ),
  unique (company_id, storage_bucket, storage_path)
);

create table if not exists public.document_audit_log (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  onboarding_id uuid references public.employee_onboardings(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  actor_user_id uuid references auth.users(id) on delete set null default auth.uid(),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint document_audit_entity_nonempty check (
    btrim(entity_type) <> '' and btrim(entity_id) <> '' and btrim(action) <> ''
  ),
  constraint document_audit_details_check check (jsonb_typeof(details) = 'object')
);

create index if not exists document_packages_company_idx
  on public.document_packages(company_id, is_active, title);
create index if not exists document_package_templates_package_idx
  on public.document_package_templates(package_id, sort_order);
create index if not exists document_package_templates_template_idx
  on public.document_package_templates(template_id);
create index if not exists employee_onboardings_company_status_idx
  on public.employee_onboardings(company_id, status, updated_at desc);
create index if not exists employee_onboardings_employee_idx
  on public.employee_onboardings(employee_id, updated_at desc)
  where employee_id is not null;
create index if not exists employee_onboardings_recruitment_idx
  on public.employee_onboardings(recruitment_application_id, updated_at desc)
  where recruitment_application_id is not null;
create index if not exists employee_onboardings_object_idx
  on public.employee_onboardings(object_id, updated_at desc)
  where object_id is not null;
create index if not exists employee_onboardings_package_idx
  on public.employee_onboardings(package_id)
  where package_id is not null;
create index if not exists employee_onboardings_assigned_idx
  on public.employee_onboardings(assigned_user_id, status, due_at)
  where assigned_user_id is not null;
create index if not exists employee_onboarding_steps_process_idx
  on public.employee_onboarding_steps(onboarding_id, status);
create index if not exists employee_onboarding_steps_assigned_idx
  on public.employee_onboarding_steps(assigned_user_id, status, due_at)
  where assigned_user_id is not null;
create index if not exists employee_document_files_process_idx
  on public.employee_document_files(onboarding_id, file_kind, document_type, created_at desc);
create index if not exists employee_document_files_employee_idx
  on public.employee_document_files(employee_id, created_at desc)
  where employee_id is not null;
create index if not exists employee_document_files_template_idx
  on public.employee_document_files(template_version_id)
  where template_version_id is not null;
create unique index if not exists employee_document_files_recruitment_unique
  on public.employee_document_files(onboarding_id, recruitment_document_id)
  where recruitment_document_id is not null;
create unique index if not exists employee_document_files_form_unique
  on public.employee_document_files(onboarding_id, recruitment_onboarding_form_id)
  where recruitment_onboarding_form_id is not null;
create index if not exists document_audit_log_process_idx
  on public.document_audit_log(onboarding_id, created_at desc);
create index if not exists document_audit_log_company_idx
  on public.document_audit_log(company_id, created_at desc);

alter table public.document_tool_installations enable row level security;
alter table public.document_packages enable row level security;
alter table public.document_package_templates enable row level security;
alter table public.employee_onboardings enable row level security;
alter table public.employee_onboarding_steps enable row level security;
alter table public.employee_document_files enable row level security;
alter table public.document_audit_log enable row level security;

drop policy if exists document_tool_installations_company_access on public.document_tool_installations;
drop policy if exists document_packages_company_access on public.document_packages;
drop policy if exists document_package_templates_company_access on public.document_package_templates;
drop policy if exists employee_onboardings_company_access on public.employee_onboardings;
drop policy if exists employee_onboarding_steps_company_access on public.employee_onboarding_steps;
drop policy if exists employee_document_files_company_access on public.employee_document_files;
drop policy if exists document_audit_log_company_access on public.document_audit_log;

create policy document_tool_installations_select
on public.document_tool_installations for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.workflow.view')
    or public.current_user_has_permission('documents.workflow.manage')
  )
);

create policy document_tool_installations_insert
on public.document_tool_installations for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.manage')
);

create policy document_tool_installations_update
on public.document_tool_installations for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.manage')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.manage')
);

create policy document_packages_select
on public.document_packages for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.view')
);

create policy document_packages_insert
on public.document_packages for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
);

create policy document_packages_update
on public.document_packages for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
);

create policy document_package_templates_select
on public.document_package_templates for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.view')
);

create policy document_package_templates_insert
on public.document_package_templates for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
);

create policy document_package_templates_update
on public.document_package_templates for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
);

create policy document_package_templates_delete
on public.document_package_templates for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.packages.manage')
);

create policy employee_onboardings_select
on public.employee_onboardings for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.view')
);

create policy employee_onboardings_insert
on public.employee_onboardings for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.onboarding.create')
);

create policy employee_onboardings_update
on public.employee_onboardings for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

create policy employee_onboarding_steps_select
on public.employee_onboarding_steps for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.view')
);

create policy employee_onboarding_steps_update
on public.employee_onboarding_steps for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

create policy employee_document_files_select
on public.employee_document_files for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.workflow.view')
);

create policy employee_document_files_insert
on public.employee_document_files for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.onboarding.edit')
);

create policy employee_document_files_update
on public.employee_document_files for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

create policy document_audit_log_select
on public.document_audit_log for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('documents.audit.view')
);

revoke all on public.document_tool_installations from anon;
revoke all on public.document_packages from anon;
revoke all on public.document_package_templates from anon;
revoke all on public.employee_onboardings from anon;
revoke all on public.employee_onboarding_steps from anon;
revoke all on public.employee_document_files from anon;
revoke all on public.document_audit_log from anon;

grant select, insert, update on public.document_tool_installations to authenticated;
grant select, insert, update on public.document_packages to authenticated;
grant select, insert, update, delete on public.document_package_templates to authenticated;
grant select, insert, update on public.employee_onboardings to authenticated;
grant select, update on public.employee_onboarding_steps to authenticated;
grant select, insert, update on public.employee_document_files to authenticated;
grant select on public.document_audit_log to authenticated;
grant usage, select on sequence public.document_audit_log_id_seq to authenticated;

comment on table public.document_tool_installations is
  'Feature gate and company settings for AppСтрой Документооборот.';
comment on table public.employee_onboardings is
  'Full employee document onboarding lifecycle, linked to recruitment, employee and template sources.';
comment on table public.employee_document_files is
  'Versioned source, generated, signed and final scan references. Existing recruitment files may be linked without copying.';
comment on table public.document_audit_log is
  'Append-only document workflow audit. Writes are performed only by checked RPC functions.';
