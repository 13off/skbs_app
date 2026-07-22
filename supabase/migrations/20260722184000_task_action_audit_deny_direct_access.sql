drop policy if exists task_action_audit_no_direct_access
on public.task_action_audit;

create policy task_action_audit_no_direct_access
on public.task_action_audit
for all
to authenticated
using (false)
with check (false);
