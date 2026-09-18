-- Allow the read-only executive role to see work-order plan/fact values.
-- Write policies remain restricted to admin/developer/foreman.

drop policy if exists work_plans_read on public.task_work_plans;
create policy work_plans_read
on public.task_work_plans
for select
to authenticated
using (
  public.task_is_allowed_for_user(task_id)
  and public.current_user_role() in ('admin', 'developer', 'foreman', 'executive')
);

drop policy if exists work_days_read on public.task_work_days;
create policy work_days_read
on public.task_work_days
for select
to authenticated
using (
  public.task_is_allowed_for_user(task_id)
  and public.current_user_role() in ('admin', 'developer', 'foreman', 'executive')
);
