create table if not exists public.document_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null,
  title text not null,
  category text not null default 'other',
  description text not null default '',
  status text not null default 'review'
    check (status in ('active', 'review', 'archived')),
  current_version_id uuid,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists document_templates_global_code_key
  on public.document_templates (code)
  where company_id is null;

create unique index if not exists document_templates_company_code_key
  on public.document_templates (company_id, code)
  where company_id is not null;

create index if not exists document_templates_company_status_idx
  on public.document_templates (company_id, status, category, title);

create table if not exists public.document_template_versions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.document_templates(id) on delete cascade,
  company_id uuid references public.companies(id) on delete cascade,
  version_no integer not null check (version_no > 0),
  file_name text not null,
  mime_type text not null,
  source_kind text not null check (source_kind in ('asset', 'storage', 'external')),
  asset_path text,
  storage_path text,
  external_url text,
  field_schema jsonb not null default '{}'::jsonb,
  notes text not null default '',
  is_approved boolean not null default false,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (template_id, version_no),
  check (
    (source_kind = 'asset' and asset_path is not null and storage_path is null and external_url is null)
    or
    (source_kind = 'storage' and storage_path is not null and asset_path is null and external_url is null)
    or
    (source_kind = 'external' and external_url is not null and asset_path is null and storage_path is null)
  )
);

create index if not exists document_template_versions_company_template_idx
  on public.document_template_versions (company_id, template_id, version_no desc);

alter table public.document_templates
  drop constraint if exists document_templates_current_version_id_fkey;

alter table public.document_templates
  add constraint document_templates_current_version_id_fkey
  foreign key (current_version_id)
  references public.document_template_versions(id)
  on delete set null
  deferrable initially deferred;

alter table public.document_templates enable row level security;
alter table public.document_template_versions enable row level security;

revoke all on table public.document_templates from anon;
revoke all on table public.document_template_versions from anon;
grant select, insert, update on table public.document_templates to authenticated;
grant select, insert, update on table public.document_template_versions to authenticated;

create policy document_templates_select
on public.document_templates
for select
to authenticated
using (
  company_id is null
  or (select public.is_company_member(company_id))
);

create policy document_templates_insert
on public.document_templates
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

create policy document_templates_update
on public.document_templates
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
)
with check (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

create policy document_template_versions_select
on public.document_template_versions
for select
to authenticated
using (
  company_id is null
  or (select public.is_company_member(company_id))
);

create policy document_template_versions_insert
on public.document_template_versions
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
  and exists (
    select 1
    from public.document_templates template
    where template.id = template_id
      and template.company_id = company_id
  )
);

create policy document_template_versions_update
on public.document_template_versions
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
)
with check (
  company_id = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'document-templates',
  'document-templates',
  false,
  15728640,
  array[
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.oasis.opendocument.text'
  ]::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy document_templates_storage_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'document-templates'
  and (select public.is_company_member(((storage.foldername(name))[1])::uuid))
);

create policy document_templates_storage_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'document-templates'
  and ((storage.foldername(name))[1])::uuid = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

create policy document_templates_storage_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'document-templates'
  and ((storage.foldername(name))[1])::uuid = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
)
with check (
  bucket_id = 'document-templates'
  and ((storage.foldername(name))[1])::uuid = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

create policy document_templates_storage_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'document-templates'
  and ((storage.foldername(name))[1])::uuid = (select public.current_user_company_id())
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

with template_seed(id, code, title, category, description, status) as (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'employment_application', 'Заявление на работу', 'hr', 'Официальный пустой бланк ООО «СКБС» из рабочего Google Drive.', 'active'),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'salary_transfer_application', 'Заявление о перечислении зарплаты', 'hr', 'Официальный пустой бланк ООО «СКБС» из рабочего Google Drive.', 'active'),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'personal_data_consent', 'Согласие на обработку персональных данных', 'hr', 'Требуется загрузить и утвердить форму ООО «СКБС». Чужие формы не используются.', 'review'),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'employment_contract', 'Трудовой договор', 'hr', 'Требуется загрузить и утвердить действующую форму ООО «СКБС». Типовой чужой договор не используется.', 'review')
)
insert into public.document_templates (
  id, company_id, code, title, category, description, status, created_by
)
select id, null, code, title, category, description, status, null
from template_seed
on conflict (id) do update set
  title = excluded.title,
  category = excluded.category,
  description = excluded.description,
  status = excluded.status,
  updated_at = now();

insert into public.document_template_versions (
  id, template_id, company_id, version_no, file_name, mime_type,
  source_kind, external_url, field_schema, notes, is_approved, created_by
)
values
  (
    '20000000-0000-4000-8000-000000000001'::uuid,
    '10000000-0000-4000-8000-000000000001'::uuid,
    null,
    1,
    'Заявление_на_работу.docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'external',
    'https://drive.google.com/file/d/1QGZrmV2aaHA4oBA6QElv2w8aPAU6N59a/view',
    '{}'::jsonb,
    'Подключён оригинал из рабочего Drive. Форму не менять.',
    true,
    null
  ),
  (
    '20000000-0000-4000-8000-000000000002'::uuid,
    '10000000-0000-4000-8000-000000000002'::uuid,
    null,
    1,
    'Заявление_о_перечислении_ЗП.docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'external',
    'https://drive.google.com/file/d/1KJYAaHyv3dmipPnuSL_NDT5_z_K8dYN3/view',
    '{}'::jsonb,
    'Подключён оригинал из рабочего Drive. Форму не менять.',
    true,
    null
  )
on conflict (id) do update set
  file_name = excluded.file_name,
  mime_type = excluded.mime_type,
  source_kind = excluded.source_kind,
  external_url = excluded.external_url,
  notes = excluded.notes,
  is_approved = excluded.is_approved;

update public.document_templates
set current_version_id = case code
  when 'employment_application' then '20000000-0000-4000-8000-000000000001'::uuid
  when 'salary_transfer_application' then '20000000-0000-4000-8000-000000000002'::uuid
  else current_version_id
end,
updated_at = now()
where company_id is null
  and code in ('employment_application', 'salary_transfer_application');

comment on table public.document_templates is
  'Company-scoped and connected document template catalogue.';
comment on table public.document_template_versions is
  'Immutable source-file versions for document templates.';
