-- A newly created task is inserted as a draft and returned to the client before
-- assignees and photos are attached. The creator must be able to read that own
-- draft, otherwise PostgREST's INSERT ... RETURNING is rejected by RLS and the
-- entire task creation transaction appears to fail with HTTP 403.

drop policy if exists tasks_select_company_object on public.tasks;

create policy tasks_select_company_object
on public.tasks
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and (
    public.task_is_allowed_for_user(id)
    or (
      is_draft
      and created_by_user_id = (select auth.uid())
    )
  )
);
