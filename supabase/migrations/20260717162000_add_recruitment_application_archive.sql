alter table public.recruitment_applications
  add column if not exists archived_at timestamptz;

create index if not exists recruitment_applications_company_archive_idx
  on public.recruitment_applications (company_id, archived_at, created_at desc);

insert into public.role_permissions (role_code, permission_code)
values
  ('owner', 'recruitment.applications.delete'),
  ('admin', 'recruitment.applications.delete'),
  ('hr', 'recruitment.applications.delete')
on conflict (role_code, permission_code) do nothing;

drop policy if exists recruitment_applications_delete
  on public.recruitment_applications;
create policy recruitment_applications_delete
  on public.recruitment_applications
  for delete
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.delete')
  );
