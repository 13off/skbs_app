-- All document-related capabilities are unavailable while the company tool is disabled.
-- The installation row itself stays accessible so an owner/admin can enable it again.

create or replace function public.document_tool_is_enabled(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when p_company_id is null then false
    when auth.role() = 'service_role' then exists (
      select 1
      from public.document_tool_installations installation
      where installation.company_id = p_company_id
        and installation.is_enabled
    )
    else public.is_company_member(p_company_id) and exists (
      select 1
      from public.document_tool_installations installation
      where installation.company_id = p_company_id
        and installation.is_enabled
    )
  end;
$$;

revoke all on function public.document_tool_is_enabled(uuid) from public, anon;
grant execute on function public.document_tool_is_enabled(uuid) to authenticated;

create or replace function public.require_document_tool_enabled()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_company_id uuid;
begin
  -- Migrations and trusted service jobs are not blocked by a customer feature flag.
  if auth.uid() is null or auth.role() = 'service_role' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    target_company_id := old.company_id;
  else
    target_company_id := new.company_id;
  end if;

  if not public.document_tool_is_enabled(target_company_id) then
    raise exception using
      errcode = 'P0001',
      message = 'Подключите AppСтрой Трудоустройство';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.require_document_tool_enabled() from public, anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'employee_private_data',
    'document_templates',
    'document_template_versions',
    'document_packages',
    'document_package_templates',
    'employee_onboardings',
    'employee_onboarding_steps',
    'employee_document_files'
  ]
  loop
    execute format(
      'drop trigger if exists require_document_tool_enabled on public.%I',
      table_name
    );
    execute format(
      'create trigger require_document_tool_enabled before insert or update or delete on public.%I for each row execute function public.require_document_tool_enabled()',
      table_name
    );
  end loop;
end $$;

-- Legacy employee private data.
drop policy if exists employee_private_data_select_company_admin on public.employee_private_data;
create policy employee_private_data_select_company_admin
on public.employee_private_data for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.document_tool_is_enabled(company_id)
);

drop policy if exists employee_private_data_insert_company_admin on public.employee_private_data;
create policy employee_private_data_insert_company_admin
on public.employee_private_data for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.document_tool_is_enabled(company_id)
  and exists (
    select 1 from public.employees employee
    where employee.id = employee_private_data.employee_id
      and employee.company_id = employee_private_data.company_id
  )
);

drop policy if exists employee_private_data_update_company_admin on public.employee_private_data;
create policy employee_private_data_update_company_admin
on public.employee_private_data for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.document_tool_is_enabled(company_id)
)
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.document_tool_is_enabled(company_id)
);

drop policy if exists employee_private_data_delete_company_admin on public.employee_private_data;
create policy employee_private_data_delete_company_admin
on public.employee_private_data for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.document_tool_is_enabled(company_id)
);

-- Templates and immutable template versions.
drop policy if exists document_templates_select on public.document_templates;
create policy document_templates_select
on public.document_templates for select to authenticated
using (
  public.document_tool_is_enabled((select public.current_user_company_id()))
  and (
    company_id is null
    or (
      company_id = (select public.current_user_company_id())
      and public.current_user_has_permission('documents.templates.view')
    )
  )
);

drop policy if exists document_templates_insert on public.document_templates;
create policy document_templates_insert
on public.document_templates for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
);

drop policy if exists document_templates_update on public.document_templates;
create policy document_templates_update
on public.document_templates for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
);

drop policy if exists document_template_versions_select on public.document_template_versions;
create policy document_template_versions_select
on public.document_template_versions for select to authenticated
using (
  public.document_tool_is_enabled((select public.current_user_company_id()))
  and (
    company_id is null
    or (
      company_id = (select public.current_user_company_id())
      and public.current_user_has_permission('documents.templates.view')
    )
  )
);

drop policy if exists document_template_versions_insert on public.document_template_versions;
create policy document_template_versions_insert
on public.document_template_versions for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
  and exists (
    select 1 from public.document_templates template
    where template.id = document_template_versions.template_id
      and template.company_id = document_template_versions.company_id
  )
);

drop policy if exists document_template_versions_update on public.document_template_versions;
create policy document_template_versions_update
on public.document_template_versions for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.templates.edit')
);

-- Packages.
drop policy if exists document_packages_select on public.document_packages;
create policy document_packages_select
on public.document_packages for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists document_packages_insert on public.document_packages;
create policy document_packages_insert
on public.document_packages for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
);

drop policy if exists document_packages_update on public.document_packages;
create policy document_packages_update
on public.document_packages for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
);

drop policy if exists document_package_templates_select on public.document_package_templates;
create policy document_package_templates_select
on public.document_package_templates for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists document_package_templates_insert on public.document_package_templates;
create policy document_package_templates_insert
on public.document_package_templates for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
);

drop policy if exists document_package_templates_update on public.document_package_templates;
create policy document_package_templates_update
on public.document_package_templates for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
);

drop policy if exists document_package_templates_delete on public.document_package_templates;
create policy document_package_templates_delete
on public.document_package_templates for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.packages.manage')
);

-- Employee onboarding workflow.
drop policy if exists employee_onboardings_select on public.employee_onboardings;
create policy employee_onboardings_select
on public.employee_onboardings for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists employee_onboardings_insert on public.employee_onboardings;
create policy employee_onboardings_insert
on public.employee_onboardings for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.onboarding.create')
);

drop policy if exists employee_onboardings_update on public.employee_onboardings;
create policy employee_onboardings_update
on public.employee_onboardings for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

drop policy if exists employee_onboarding_steps_select on public.employee_onboarding_steps;
create policy employee_onboarding_steps_select
on public.employee_onboarding_steps for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists employee_onboarding_steps_update on public.employee_onboarding_steps;
create policy employee_onboarding_steps_update
on public.employee_onboarding_steps for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

drop policy if exists employee_document_files_select on public.employee_document_files;
create policy employee_document_files_select
on public.employee_document_files for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists employee_document_files_insert on public.employee_document_files;
create policy employee_document_files_insert
on public.employee_document_files for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.onboarding.edit')
);

drop policy if exists employee_document_files_update on public.employee_document_files;
create policy employee_document_files_update
on public.employee_document_files for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
  )
);

drop policy if exists document_audit_log_select on public.document_audit_log;
create policy document_audit_log_select
on public.document_audit_log for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.document_tool_is_enabled(company_id)
  and public.current_user_has_permission('documents.audit.view')
);

-- Storage: new workflow paths use company_id as the first folder.
drop policy if exists document_workflow_files_select on storage.objects;
create policy document_workflow_files_select
on storage.objects for select to authenticated
using (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] =
      (select public.current_user_company_id())::text
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and public.current_user_has_permission('documents.workflow.view')
);

drop policy if exists document_workflow_files_insert on storage.objects;
create policy document_workflow_files_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] =
      (select public.current_user_company_id())::text
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and public.current_user_has_permission('documents.onboarding.edit')
);

drop policy if exists document_workflow_files_delete on storage.objects;
create policy document_workflow_files_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] =
      (select public.current_user_company_id())::text
  and owner_id = (select auth.uid()::text)
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and public.current_user_has_permission('documents.onboarding.edit')
);

-- Legacy employee folders use employee_id as the first folder.
drop policy if exists employee_documents_select_company_admin on storage.objects;
create policy employee_documents_select_company_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1 from public.employees employee
    where employee.company_id = (select public.current_user_company_id())
      and employee.id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists employee_documents_insert_company_admin on storage.objects;
create policy employee_documents_insert_company_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1 from public.employees employee
    where employee.company_id = (select public.current_user_company_id())
      and employee.id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists employee_documents_update_company_admin on storage.objects;
create policy employee_documents_update_company_admin
on storage.objects for update to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1 from public.employees employee
    where employee.company_id = (select public.current_user_company_id())
      and employee.id::text = (storage.foldername(name))[1]
  )
)
with check (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1 from public.employees employee
    where employee.company_id = (select public.current_user_company_id())
      and employee.id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists employee_documents_delete_company_admin on storage.objects;
create policy employee_documents_delete_company_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1 from public.employees employee
    where employee.company_id = (select public.current_user_company_id())
      and employee.id::text = (storage.foldername(name))[1]
  )
);

-- Template binary files are also part of the installed tool.
drop policy if exists document_templates_storage_select on storage.objects;
create policy document_templates_storage_select
on storage.objects for select to authenticated
using (
  bucket_id = 'document-templates'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and case
    when coalesce((storage.foldername(name))[1], '') ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then public.is_company_member(((storage.foldername(name))[1])::uuid)
    else false
  end
);

drop policy if exists document_templates_storage_insert on storage.objects;
create policy document_templates_storage_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'document-templates'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and case
    when coalesce((storage.foldername(name))[1], '') ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid =
      (select public.current_user_company_id())
    else false
  end
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

drop policy if exists document_templates_storage_update on storage.objects;
create policy document_templates_storage_update
on storage.objects for update to authenticated
using (
  bucket_id = 'document-templates'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and case
    when coalesce((storage.foldername(name))[1], '') ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid =
      (select public.current_user_company_id())
    else false
  end
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
)
with check (
  bucket_id = 'document-templates'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and case
    when coalesce((storage.foldername(name))[1], '') ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid =
      (select public.current_user_company_id())
    else false
  end
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

drop policy if exists document_templates_storage_delete on storage.objects;
create policy document_templates_storage_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'document-templates'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and case
    when coalesce((storage.foldername(name))[1], '') ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then ((storage.foldername(name))[1])::uuid =
      (select public.current_user_company_id())
    else false
  end
  and (select public.current_user_role()) in ('admin', 'developer', 'hr')
);

-- Keep the blocker RPC callable, but prevent SECURITY DEFINER reads while disabled.
do $$
begin
  if to_regprocedure('public.document_onboarding_blockers_unguarded(uuid)') is null then
    alter function public.document_onboarding_blockers(uuid)
      rename to document_onboarding_blockers_unguarded;
  end if;
end $$;

create or replace function public.document_onboarding_blockers(p_onboarding_id uuid)
returns table(code text, message text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.document_tool_is_enabled(public.current_user_company_id()) then
    raise exception 'Подключите AppСтрой Трудоустройство';
  end if;

  return query
  select blocker.code, blocker.message
  from public.document_onboarding_blockers_unguarded(p_onboarding_id) blocker;
end;
$$;

revoke all on function public.document_onboarding_blockers_unguarded(uuid)
from public, anon, authenticated;
revoke all on function public.document_onboarding_blockers(uuid)
from public, anon;
grant execute on function public.document_onboarding_blockers(uuid)
to authenticated;
