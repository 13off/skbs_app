drop policy if exists recruitment_applications_delete
  on public.recruitment_applications;
create policy recruitment_applications_delete
  on public.recruitment_applications
  for delete
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and archived_at is not null
    and public.current_user_has_permission('recruitment.applications.delete')
  );
