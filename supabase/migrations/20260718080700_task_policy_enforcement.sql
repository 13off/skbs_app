create or replace function private.validate_task_photo_requirements()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_policy jsonb;
  v_before_count integer;
  v_after_count integer;
begin
  v_policy := public.get_effective_task_policy(new.object_name);
  new.photo_requirements_enforced := coalesce((v_policy ->> 'require_before_photo')::boolean, true);

  if tg_op = 'INSERT' then
    if new.created_by_user_id is null then
      new.created_by_user_id := auth.uid();
    end if;
    if not public.task_can_create_for_user(new.task_date, new.object_name) then
      raise exception 'Создание задачи на эту дату запрещено настройками объекта';
    end if;
    if not new.is_draft then
      raise exception 'Новая задача должна быть создана через безопасный черновик';
    end if;
    return new;
  end if;

  if not public.is_admin() then
    if not public.task_can_edit_for_user(old.id) then
      raise exception 'Редактирование задачи закрыто настройками объекта';
    end if;
    if new.object_name is distinct from old.object_name then
      raise exception 'Прораб не может переносить задачу между объектами';
    end if;
    if new.task_date is distinct from old.task_date
       and not coalesce((v_policy ->> 'foreman_can_edit_date')::boolean, true) then
      raise exception 'Изменение даты задачи запрещено настройками объекта';
    end if;
    if (new.axes is distinct from old.axes or new.work is distinct from old.work)
       and not coalesce((v_policy ->> 'foreman_can_edit_axes_work')::boolean, true) then
      raise exception 'Изменение осей и вида работ запрещено настройками объекта';
    end if;
    if new.status is distinct from old.status
       and not coalesce((v_policy ->> 'foreman_can_edit_status')::boolean, true) then
      raise exception 'Изменение статуса запрещено настройками объекта';
    end if;
  end if;

  if old.is_draft and not new.is_draft
     and coalesce((v_policy ->> 'require_before_photo')::boolean, true) then
    select count(*) into v_before_count
    from public.task_photos photo
    where photo.task_id = new.id and photo.photo_stage = 'before';
    if v_before_count < coalesce((v_policy ->> 'min_before_photos')::integer, 1) then
      raise exception 'Добавьте необходимое количество фото «До»: %',
        coalesce((v_policy ->> 'min_before_photos')::integer, 1);
    end if;
  end if;

  if new.status = 'Выполнено'
     and old.status is distinct from new.status
     and coalesce((v_policy ->> 'require_after_photo_on_complete')::boolean, true) then
    select count(*) into v_after_count
    from public.task_photos photo
    where photo.task_id = new.id and photo.photo_stage = 'after';
    if v_after_count < coalesce((v_policy ->> 'min_after_photos')::integer, 1) then
      raise exception 'Добавьте необходимое количество фото «После»: %',
        coalesce((v_policy ->> 'min_after_photos')::integer, 1);
    end if;
  end if;

  if new.status <> 'Выполнено'
     and not (old.is_draft and not new.is_draft)
     and new.task_date <= public.current_operational_date()
     and coalesce((v_policy ->> 'require_not_done_comment')::boolean, true)
     and btrim(coalesce(new.not_done_comment, '')) = '' then
    raise exception 'Укажите причину, почему задача не выполнена';
  end if;

  return new;
end;
$$;

drop trigger if exists tasks_validate_photo_requirements on public.tasks;
create trigger tasks_validate_photo_requirements
before insert or update on public.tasks
for each row execute function private.validate_task_photo_requirements();

-- Task RLS now delegates to the object policy functions.
drop policy if exists tasks_insert_company_object on public.tasks;
create policy tasks_insert_company_object
on public.tasks for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and is_draft
  and created_by_user_id = (select auth.uid())
  and public.task_can_create_for_user(task_date, object_name)
);

drop policy if exists tasks_update_company_object on public.tasks;
create policy tasks_update_company_object
on public.tasks for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_can_edit_for_user(id)
)
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
);

drop policy if exists tasks_delete_company_admin on public.tasks;
create policy tasks_delete_company_admin
on public.tasks for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_can_delete_for_user(id)
);

drop policy if exists task_assignees_insert_company_task on public.task_assignees;
create policy task_assignees_insert_company_task
on public.task_assignees for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.task_can_edit_assignees_for_user(task_id)
  and exists (
    select 1
    from public.tasks task
    join public.employees employee
      on employee.id = task_assignees.employee_id
     and employee.company_id = task.company_id
     and lower(btrim(employee.object_name)) = lower(btrim(task.object_name))
    where task.id = task_assignees.task_id
      and task.company_id = task_assignees.company_id
  )
);

drop policy if exists task_assignees_delete_company_task on public.task_assignees;
create policy task_assignees_delete_company_task
on public.task_assignees for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_can_edit_assignees_for_user(task_id)
);

drop policy if exists task_photos_insert_company_task on public.task_photos;
create policy task_photos_insert_company_task
on public.task_photos for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.task_can_add_photo_for_user(task_id)
);

drop policy if exists task_photos_delete_company_task on public.task_photos;
create policy task_photos_delete_company_task
on public.task_photos for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_photo_can_delete_for_user(id)
);

-- Storage path uses task id as the first folder segment.
drop policy if exists task_photos_storage_insert_company_task on storage.objects;
create policy task_photos_storage_insert_company_task
on storage.objects for insert to authenticated
with check (
  bucket_id = 'task-photos'
  and exists (
    select 1 from public.tasks task
    where task.company_id = public.current_user_company_id()
      and task.id::text = (storage.foldername(name))[1]
      and public.task_can_add_photo_for_user(task.id)
  )
);

drop policy if exists task_photos_storage_delete_company_task on storage.objects;
create policy task_photos_storage_delete_company_task
on storage.objects for delete to authenticated
using (
  bucket_id = 'task-photos'
  and exists (
    select 1
    from public.tasks task
    where task.company_id = public.current_user_company_id()
      and task.id::text = (storage.foldername(name))[1]
      and public.task_can_edit_for_user(task.id)
  )
);

revoke all on function public.is_developer() from public, anon;
revoke all on function public.get_effective_task_policy(text) from public, anon;
revoke all on function public.get_developer_task_policy_center() from public, anon;
revoke all on function public.save_task_policy_setting(uuid, jsonb) from public, anon;
revoke all on function public.reset_task_policy_override(uuid) from public, anon;
revoke all on function public.task_policy_bool(text, text, boolean) from public, anon;
revoke all on function public.task_policy_int(text, text, integer) from public, anon;
revoke all on function public.task_can_create_for_user(date, text) from public, anon;
revoke all on function public.task_can_edit_for_user(uuid) from public, anon;
revoke all on function public.task_can_edit_assignees_for_user(uuid) from public, anon;
revoke all on function public.task_can_add_photo_for_user(uuid) from public, anon;
revoke all on function public.task_photo_can_delete_for_user(uuid) from public, anon;
revoke all on function public.task_can_delete_for_user(uuid) from public, anon;

grant execute on function public.is_developer() to authenticated, service_role;
grant execute on function public.get_effective_task_policy(text) to authenticated, service_role;
grant execute on function public.get_developer_task_policy_center() to authenticated, service_role;
grant execute on function public.save_task_policy_setting(uuid, jsonb) to authenticated, service_role;
grant execute on function public.reset_task_policy_override(uuid) to authenticated, service_role;
grant execute on function public.task_policy_bool(text, text, boolean) to authenticated, service_role;
grant execute on function public.task_policy_int(text, text, integer) to authenticated, service_role;
grant execute on function public.task_can_create_for_user(date, text) to authenticated, service_role;
grant execute on function public.task_can_edit_for_user(uuid) to authenticated, service_role;
grant execute on function public.task_can_edit_assignees_for_user(uuid) to authenticated, service_role;
grant execute on function public.task_can_add_photo_for_user(uuid) to authenticated, service_role;
grant execute on function public.task_photo_can_delete_for_user(uuid) to authenticated, service_role;
grant execute on function public.task_can_delete_for_user(uuid) to authenticated, service_role;
