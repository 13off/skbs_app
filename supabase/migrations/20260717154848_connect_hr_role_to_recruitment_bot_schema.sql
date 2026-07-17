alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
  add constraint user_profiles_role_check
  check (role = any (array['admin'::text, 'foreman'::text, 'lawyer'::text, 'accountant'::text, 'hr'::text]));

alter table public.company_memberships
  drop constraint if exists company_memberships_role_check;
alter table public.company_memberships
  add constraint company_memberships_role_check
  check (role = any (array['owner'::text, 'admin'::text, 'foreman'::text, 'lawyer'::text, 'accountant'::text, 'hr'::text]));

alter table public.role_permissions
  drop constraint if exists role_permissions_role_check;
alter table public.role_permissions
  add constraint role_permissions_role_check
  check (role_code = any (array['owner'::text, 'admin'::text, 'foreman'::text, 'lawyer'::text, 'accountant'::text, 'hr'::text]));

alter table public.company_invitations
  drop constraint if exists company_invitations_role_check;
alter table public.company_invitations
  add constraint company_invitations_role_check
  check (role = any (array['admin'::text, 'foreman'::text, 'lawyer'::text, 'accountant'::text, 'hr'::text]));

insert into public.role_permissions (role_code, permission_code)
select role_code, permission_code
from (values
  ('owner', 'recruitment.applications.view'),
  ('owner', 'recruitment.applications.edit'),
  ('owner', 'recruitment.documents.view'),
  ('owner', 'recruitment.documents.edit'),
  ('owner', 'recruitment.vacancies.view'),
  ('owner', 'recruitment.vacancies.edit'),
  ('admin', 'recruitment.applications.view'),
  ('admin', 'recruitment.applications.edit'),
  ('admin', 'recruitment.documents.view'),
  ('admin', 'recruitment.documents.edit'),
  ('admin', 'recruitment.vacancies.view'),
  ('admin', 'recruitment.vacancies.edit'),
  ('hr', 'recruitment.applications.view'),
  ('hr', 'recruitment.applications.edit'),
  ('hr', 'recruitment.documents.view'),
  ('hr', 'recruitment.documents.edit'),
  ('hr', 'recruitment.vacancies.view'),
  ('hr', 'recruitment.vacancies.edit')
) as permissions(role_code, permission_code)
on conflict (role_code, permission_code) do nothing;

alter table public.recruitment_applications
  drop constraint if exists recruitment_applications_source_check;
alter table public.recruitment_applications
  add constraint recruitment_applications_source_check
  check (source = any (array['manual'::text, 'telegram'::text, 'max'::text]));
alter table public.recruitment_applications
  add column if not exists hr_comment text not null default '';

revoke all on table public.recruitment_applications from anon;
revoke all on table public.recruitment_documents from anon;
revoke all on table public.recruitment_status_history from anon;
revoke all on table public.recruitment_vacancies from anon;
grant select, insert, update, delete on table public.recruitment_applications to authenticated;
grant select, insert, update, delete on table public.recruitment_documents to authenticated;
grant select, insert on table public.recruitment_status_history to authenticated;
grant select, insert, update, delete on table public.recruitment_vacancies to authenticated;
grant usage, select on sequence public.recruitment_status_history_id_seq to authenticated;

alter table public.recruitment_applications enable row level security;
alter table public.recruitment_documents enable row level security;
alter table public.recruitment_status_history enable row level security;
alter table public.recruitment_vacancies enable row level security;

drop policy if exists recruitment_applications_manage_admin on public.recruitment_applications;
drop policy if exists recruitment_applications_select_admin on public.recruitment_applications;
create policy recruitment_applications_select
  on public.recruitment_applications for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_applications_insert
  on public.recruitment_applications for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_applications_update
  on public.recruitment_applications for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_applications_delete
  on public.recruitment_applications for delete to authenticated
  using ((select public.is_company_admin(company_id)));

drop policy if exists recruitment_documents_manage_admin on public.recruitment_documents;
drop policy if exists recruitment_documents_select_admin on public.recruitment_documents;
create policy recruitment_documents_select
  on public.recruitment_documents for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.view')
  );
create policy recruitment_documents_insert
  on public.recruitment_documents for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  );
create policy recruitment_documents_update
  on public.recruitment_documents for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  );
create policy recruitment_documents_delete
  on public.recruitment_documents for delete to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.documents.edit')
  );

drop policy if exists recruitment_status_history_manage_admin on public.recruitment_status_history;
drop policy if exists recruitment_status_history_select_admin on public.recruitment_status_history;
create policy recruitment_status_history_select
  on public.recruitment_status_history for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_status_history_insert
  on public.recruitment_status_history for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
    and (created_by is null or created_by = (select auth.uid()))
  );

drop policy if exists recruitment_vacancies_manage_admin on public.recruitment_vacancies;
drop policy if exists recruitment_vacancies_select_company on public.recruitment_vacancies;
create policy recruitment_vacancies_select
  on public.recruitment_vacancies for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.vacancies.view')
  );
create policy recruitment_vacancies_insert
  on public.recruitment_vacancies for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.vacancies.edit')
  );
create policy recruitment_vacancies_update
  on public.recruitment_vacancies for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.vacancies.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.vacancies.edit')
  );
create policy recruitment_vacancies_delete
  on public.recruitment_vacancies for delete to authenticated
  using ((select public.is_company_admin(company_id)));

drop trigger if exists recruitment_applications_touch_updated_at on public.recruitment_applications;
create trigger recruitment_applications_touch_updated_at
  before update on public.recruitment_applications
  for each row execute function public.touch_updated_at();

drop trigger if exists recruitment_vacancies_touch_updated_at on public.recruitment_vacancies;
create trigger recruitment_vacancies_touch_updated_at
  before update on public.recruitment_vacancies
  for each row execute function public.touch_updated_at();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_applications;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_applications
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_documents;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_documents
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_status_history;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_status_history
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_vacancies;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_vacancies
  for each row execute function private.broadcast_app_data_change();
