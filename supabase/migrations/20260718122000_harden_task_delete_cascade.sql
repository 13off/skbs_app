create or replace function private.mark_task_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform set_config('appstroy.deleting_task_id', old.id::text, true);
  if old.is_draft then
    perform set_config('appstroy.suppress_draft_task_id', old.id::text, true);
  end if;
  return old;
end;
$$;

revoke all on function private.mark_task_delete() from public, anon, authenticated;
grant execute on function private.mark_task_delete() to service_role;

drop trigger if exists tasks_mark_draft_delete on public.tasks;
drop trigger if exists tasks_mark_delete on public.tasks;
create trigger tasks_mark_delete
before delete on public.tasks
for each row execute function private.mark_task_delete();

create or replace function private.prevent_required_task_photo_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_task public.tasks%rowtype;
  v_deleting_task_id text := coalesce(
    current_setting('appstroy.deleting_task_id', true),
    ''
  );
begin
  if v_deleting_task_id = old.task_id::text then
    return old;
  end if;

  select * into v_task from public.tasks where id = old.task_id;
  if not found or not v_task.photo_requirements_enforced then
    return old;
  end if;

  if old.photo_stage = 'before'
     and not v_task.is_draft
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = old.task_id
         and p.photo_stage = 'before'
         and p.id <> old.id
     ) then
    raise exception 'Нельзя удалить последнее обязательное фото «До»';
  end if;

  if old.photo_stage = 'after'
     and v_task.status = 'Выполнено'
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = old.task_id
         and p.photo_stage = 'after'
         and p.id <> old.id
     ) then
    raise exception 'Нельзя удалить последнее обязательное фото «После» у выполненной задачи';
  end if;

  return old;
end;
$$;

revoke all on function private.prevent_required_task_photo_delete() from public, anon, authenticated;
grant execute on function private.prevent_required_task_photo_delete() to service_role;

create or replace function private.filter_draft_task_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_deleting_task_id text := coalesce(
    current_setting('appstroy.deleting_task_id', true),
    ''
  );
begin
  if v_deleting_task_id <> ''
     and new.entity_type in ('task_assignees','task_photos')
     and position(v_deleting_task_id in coalesce(new.body, '')) > 0 then
    return null;
  end if;

  if new.entity_type = 'tasks'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1 from public.tasks t
       where t.id = new.entity_id::uuid and t.is_draft
     ) then
    return null;
  end if;

  if new.entity_type = 'task_photos'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1
       from public.task_photos p
       join public.tasks t on t.id = p.task_id
       where p.id = new.entity_id::uuid
         and t.is_draft
     ) then
    return null;
  end if;

  return new;
end;
$$;

revoke all on function private.filter_draft_task_notifications() from public, anon, authenticated;
grant execute on function private.filter_draft_task_notifications() to service_role;

drop function if exists private.mark_draft_task_delete();
