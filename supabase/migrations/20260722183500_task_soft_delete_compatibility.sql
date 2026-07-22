create or replace function private.mark_task_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.is_draft then
    perform set_config('appstroy.deleting_task_id', old.id::text, true);
    perform set_config('appstroy.deleting_task_company_id', old.company_id::text, true);
    perform set_config('appstroy.suppress_draft_task_id', old.id::text, true);
    return old;
  end if;

  if old.deleted_at is not null then
    return null;
  end if;

  if not public.task_can_delete_for_user(old.id) then
    raise exception 'Недостаточно прав для удаления задачи';
  end if;

  update public.tasks
  set deleted_at = now(),
      deleted_by = auth.uid(),
      delete_reason = '',
      restored_at = null,
      restored_by = null,
      updated_at = now()
  where id = old.id;

  return null;
end;
$$;

revoke all on function private.mark_task_delete() from public, anon, authenticated;

drop policy if exists tasks_delete_own_draft_only on public.tasks;
drop policy if exists tasks_delete_company_admin on public.tasks;
create policy tasks_delete_company_admin
on public.tasks
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and (
    (
      is_draft
      and (
        (select public.is_admin())
        or created_by_user_id = (select auth.uid())
      )
    )
    or (
      not is_draft
      and public.task_can_delete_for_user(id)
    )
  )
);
