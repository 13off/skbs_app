alter table public.recruitment_applications
  add column if not exists employee_id uuid references public.employees(id) on delete set null;

create index if not exists recruitment_applications_employee_idx
  on public.recruitment_applications (company_id, employee_id)
  where employee_id is not null;

create table if not exists public.recruitment_onboarding_forms (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null references public.recruitment_applications(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  form_code text not null check (form_code = any (array[
    'employment_application'::text,
    'salary_transfer_application'::text,
    'personal_data_consent'::text,
    'employment_contract'::text
  ])),
  status text not null default 'not_generated' check (status = any (array[
    'not_generated'::text,
    'ready_to_print'::text,
    'printed'::text,
    'signed'::text
  ])),
  missing_fields text[] not null default '{}',
  generated_at timestamptz,
  printed_at timestamptz,
  signed_at timestamptz,
  storage_bucket text not null default 'recruitment-documents',
  storage_path text not null default '',
  original_name text not null default '',
  mime_type text not null default '',
  size_bytes bigint,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, application_id, form_code),
  constraint recruitment_onboarding_signed_file_check check (
    status <> 'signed'
    or (storage_path <> '' and original_name <> '' and signed_at is not null)
  )
);

create index if not exists recruitment_onboarding_forms_application_idx
  on public.recruitment_onboarding_forms (application_id, form_code);
create index if not exists recruitment_onboarding_forms_employee_idx
  on public.recruitment_onboarding_forms (employee_id, form_code)
  where employee_id is not null;
create index if not exists recruitment_onboarding_forms_status_idx
  on public.recruitment_onboarding_forms (company_id, status, updated_at desc);

alter table public.recruitment_onboarding_forms enable row level security;
revoke all on table public.recruitment_onboarding_forms from anon;
grant select, insert, update, delete on table public.recruitment_onboarding_forms to authenticated;

create policy recruitment_onboarding_forms_select
  on public.recruitment_onboarding_forms
  for select
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.view')
  );

create policy recruitment_onboarding_forms_insert
  on public.recruitment_onboarding_forms
  for insert
  to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
    and exists (
      select 1
      from public.recruitment_applications application
      where application.id = application_id
        and application.company_id = company_id
    )
    and (
      employee_id is null
      or exists (
        select 1
        from public.employees employee
        where employee.id = employee_id
          and employee.company_id = company_id
      )
    )
  );

create policy recruitment_onboarding_forms_update
  on public.recruitment_onboarding_forms
  for update
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
    and exists (
      select 1
      from public.recruitment_applications application
      where application.id = application_id
        and application.company_id = company_id
    )
    and (
      employee_id is null
      or exists (
        select 1
        from public.employees employee
        where employee.id = employee_id
          and employee.company_id = company_id
      )
    )
  );

create policy recruitment_onboarding_forms_delete
  on public.recruitment_onboarding_forms
  for delete
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  );

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
]
where id = 'recruitment-documents';

drop policy if exists recruitment_documents_storage_insert on storage.objects;
create policy recruitment_documents_storage_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'recruitment-documents'
    and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
    and public.current_user_has_permission('recruitment.documents.edit')
  );

drop policy if exists recruitment_documents_storage_update on storage.objects;
create policy recruitment_documents_storage_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'recruitment-documents'
    and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
    and public.current_user_has_permission('recruitment.documents.edit')
  )
  with check (
    bucket_id = 'recruitment-documents'
    and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
    and public.current_user_has_permission('recruitment.documents.edit')
  );

drop policy if exists recruitment_documents_storage_delete on storage.objects;
create policy recruitment_documents_storage_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'recruitment-documents'
    and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
    and public.current_user_has_permission('recruitment.documents.edit')
  );

drop trigger if exists app_data_broadcast_after_change on public.recruitment_onboarding_forms;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_onboarding_forms
  for each row execute function private.broadcast_app_data_change();
