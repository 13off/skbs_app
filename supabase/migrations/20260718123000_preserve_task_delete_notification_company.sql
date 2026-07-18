create or replace function private.mark_task_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform set_config('appstroy.deleting_task_id', old.id::text, true);
  perform set_config('appstroy.deleting_task_company_id', old.company_id::text, true);
  if old.is_draft then
    perform set_config('appstroy.suppress_draft_task_id', old.id::text, true);
  end if;
  return old;
end;
$$;

revoke all on function private.mark_task_delete() from public, anon, authenticated;
grant execute on function private.mark_task_delete() to service_role;

create or replace function private.assign_deleted_task_notification_company()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_task_id text := coalesce(
    current_setting('appstroy.deleting_task_id', true),
    ''
  );
  v_company_id text := coalesce(
    current_setting('appstroy.deleting_task_company_id', true),
    ''
  );
begin
  if new.company_id is null
     and new.entity_type = 'tasks'
     and new.entity_id = v_task_id
     and v_company_id ~ '^[0-9a-fA-F-]{36}$' then
    new.company_id := v_company_id::uuid;
  end if;
  return new;
end;
$$;

revoke all on function private.assign_deleted_task_notification_company() from public, anon, authenticated;
grant execute on function private.assign_deleted_task_notification_company() to service_role;

drop trigger if exists app_notifications_00_deleted_task_company
on public.app_notifications;
create trigger app_notifications_00_deleted_task_company
before insert on public.app_notifications
for each row execute function private.assign_deleted_task_notification_company();
