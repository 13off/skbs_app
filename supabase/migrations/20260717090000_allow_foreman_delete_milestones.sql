drop policy if exists project_milestones_delete_company_admin
on public.project_milestones;

drop policy if exists project_milestones_delete_company_object
on public.project_milestones;

create policy project_milestones_delete_company_object
on public.project_milestones
for delete
to authenticated
using (
  company_id = current_user_company_id()
  and (
    is_admin()
    or (is_foreman() and can_access_object(object_name))
  )
);
