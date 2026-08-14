create or replace function private.mark_task_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('appstroy.force_permanent_task_delete', true) = 'on' then
    if not public.is_admin() then
      raise exception 'Недостаточно прав для окончательного удаления задачи';
    end if;
    perform set_config('appstroy.deleting_task_id', old.id::text, true);
    perform set_config(
      'appstroy.deleting_task_company_id',
      old.company_id::text,
      true
    );
    return old;
  end if;

  if old.is_draft then
    perform set_config('appstroy.deleting_task_id', old.id::text, true);
    perform set_config(
      'appstroy.deleting_task_company_id',
      old.company_id::text,
      true
    );
    perform set_config('appstroy.suppress_draft_task_id', old.id::text, true);
    return old;
  end if;

  if old.deleted_at is not null then return null; end if;
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

revoke all on function private.mark_task_delete()
  from public, anon, authenticated;

create or replace function public.bulk_restore_archived_employees(
  p_employee_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if not public.is_admin() then
    raise exception 'Недостаточно прав для восстановления сотрудников';
  end if;
  if p_employee_ids is null or cardinality(p_employee_ids) = 0 then return 0; end if;
  if cardinality(p_employee_ids) > 500 then
    raise exception 'За один раз можно восстановить не более 500 сотрудников';
  end if;
  if cardinality(p_employee_ids) <>
      (select count(distinct id) from unnest(p_employee_ids) ids(id)) then
    raise exception 'В списке сотрудников есть повторы';
  end if;
  if cardinality(p_employee_ids) <> (
    select count(*)
    from public.employees employee
    where employee.company_id = v_company_id
      and employee.id = any(p_employee_ids)
      and employee.archived_at is not null
  ) then
    raise exception 'Один из сотрудников не найден или уже восстановлен';
  end if;

  update public.employees employee
  set is_active = true,
      archived_at = null,
      updated_at = now()
  where employee.company_id = v_company_id
    and employee.id = any(p_employee_ids);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.bulk_restore_archived_employees(uuid[])
  from public, anon;
grant execute on function public.bulk_restore_archived_employees(uuid[])
  to authenticated;

create or replace function public.bulk_restore_archived_objects(p_names text[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_count integer := 0;
begin
  if not public.is_admin() then
    raise exception 'Недостаточно прав для восстановления объектов';
  end if;
  if p_names is null or cardinality(p_names) = 0 then return 0; end if;
  if cardinality(p_names) > 100 then
    raise exception 'За один раз можно восстановить не более 100 объектов';
  end if;
  if cardinality(p_names) <> (
    select count(distinct lower(btrim(name)))
    from unnest(p_names) requested(name)
    where btrim(coalesce(name, '')) <> ''
  ) then
    raise exception 'Список объектов содержит пустые или повторяющиеся названия';
  end if;
  if cardinality(p_names) <> (
    select count(*)
    from public.objects object_row
    join (
      select distinct lower(btrim(name)) as normalized_name
      from unnest(p_names) requested(name)
    ) requested
      on requested.normalized_name = lower(btrim(object_row.name))
    where object_row.company_id = public.current_user_company_id()
      and not object_row.is_active
  ) then
    raise exception 'Один из объектов не найден или уже восстановлен';
  end if;

  foreach v_name in array p_names loop
    perform public.restore_object(v_name);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.bulk_restore_archived_objects(text[])
  from public, anon;
grant execute on function public.bulk_restore_archived_objects(text[])
  to authenticated;

create or replace function public.permanently_delete_archived_employees(
  p_employee_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee_id uuid;
  v_manifest jsonb;
  v_employee_document_paths jsonb := '[]'::jsonb;
  v_payment_receipt_paths jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'Удаление доступно только администратору';
  end if;
  if p_employee_ids is null or cardinality(p_employee_ids) = 0 then
    return jsonb_build_object(
      'employee_document_paths', '[]'::jsonb,
      'payment_receipt_paths', '[]'::jsonb,
      'task_photo_paths', '[]'::jsonb
    );
  end if;
  if cardinality(p_employee_ids) > 100 then
    raise exception 'За один раз можно удалить не более 100 сотрудников';
  end if;
  if cardinality(p_employee_ids) <>
      (select count(distinct id) from unnest(p_employee_ids) ids(id)) then
    raise exception 'В списке сотрудников есть повторы';
  end if;

  foreach v_employee_id in array p_employee_ids loop
    v_manifest := public.permanently_delete_employee(v_employee_id);
    v_employee_document_paths := v_employee_document_paths ||
      coalesce(v_manifest -> 'employee_document_paths', '[]'::jsonb);
    v_payment_receipt_paths := v_payment_receipt_paths ||
      coalesce(v_manifest -> 'payment_receipt_paths', '[]'::jsonb);
  end loop;

  return jsonb_build_object(
    'employee_document_paths', v_employee_document_paths,
    'payment_receipt_paths', v_payment_receipt_paths,
    'task_photo_paths', '[]'::jsonb
  );
end;
$$;

revoke all on function public.permanently_delete_archived_employees(uuid[])
  from public, anon;
grant execute on function public.permanently_delete_archived_employees(uuid[])
  to authenticated;

create or replace function public.permanently_delete_archived_objects(
  p_names text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_requested_name text;
  v_object_id uuid;
  v_name text;
  v_manifest jsonb;
  v_employee_document_paths jsonb := '[]'::jsonb;
  v_payment_receipt_paths jsonb := '[]'::jsonb;
  v_task_photo_paths jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'Удаление доступно только администратору';
  end if;
  if p_names is null or cardinality(p_names) = 0 then
    return jsonb_build_object(
      'employee_document_paths', '[]'::jsonb,
      'payment_receipt_paths', '[]'::jsonb,
      'task_photo_paths', '[]'::jsonb
    );
  end if;
  if cardinality(p_names) > 50 then
    raise exception 'За один раз можно удалить не более 50 объектов';
  end if;
  if cardinality(p_names) <> (
    select count(distinct lower(btrim(name)))
    from unnest(p_names) requested(name)
    where btrim(coalesce(name, '')) <> ''
  ) then
    raise exception 'Список объектов содержит пустые или повторяющиеся названия';
  end if;

  foreach v_requested_name in array p_names loop
    v_manifest := public.archived_object_delete_manifest(v_requested_name);
    select object_row.id, object_row.name
    into v_object_id, v_name
    from public.objects object_row
    where object_row.company_id = v_company_id
      and lower(btrim(object_row.name)) = lower(btrim(v_requested_name))
      and not object_row.is_active;
    if not found then raise exception 'Архивный объект не найден'; end if;

    if exists (
      select 1 from public.project_milestones milestone
      where milestone.company_id = v_company_id
        and milestone.object_id = v_object_id
    ) then
      raise exception 'Нельзя удалить объект: к нему привязаны контрольные точки';
    end if;
    if exists (
      select 1 from public.recruitment_applications application
      where application.company_id = v_company_id
        and application.object_id = v_object_id
    ) then
      raise exception 'Нельзя удалить объект: к нему привязаны кандидаты';
    end if;
    if exists (
      select 1 from public.procurement_requests request_row
      where request_row.company_id = v_company_id
        and request_row.object_id = v_object_id
    ) then
      raise exception 'Нельзя удалить объект: к нему привязаны заявки снабжения';
    end if;

    v_employee_document_paths := v_employee_document_paths ||
      coalesce(v_manifest -> 'employee_document_paths', '[]'::jsonb);
    v_payment_receipt_paths := v_payment_receipt_paths ||
      coalesce(v_manifest -> 'payment_receipt_paths', '[]'::jsonb);
    v_task_photo_paths := v_task_photo_paths ||
      coalesce(v_manifest -> 'task_photo_paths', '[]'::jsonb);

    update public.user_profiles profile
    set object_name = null,
        updated_at = now()
    where profile.active_company_id = v_company_id
      and lower(btrim(profile.object_name)) = lower(btrim(v_name));
    delete from public.app_notification_clears item
    where item.company_id = v_company_id
      and lower(btrim(item.object_name)) = lower(btrim(v_name));
    delete from public.app_notifications item
    where item.company_id = v_company_id
      and lower(btrim(item.object_name)) = lower(btrim(v_name));
    perform set_config('appstroy.force_permanent_task_delete', 'on', true);
    delete from public.tasks task
    where task.company_id = v_company_id
      and task.object_id = v_object_id;
    perform set_config('appstroy.force_permanent_task_delete', 'off', true);
    delete from public.attendance attendance
    where attendance.company_id = v_company_id
      and attendance.object_id = v_object_id;
    delete from public.employees employee
    where employee.company_id = v_company_id
      and employee.object_id = v_object_id;
    delete from public.objects object_row
    where object_row.company_id = v_company_id
      and object_row.id = v_object_id;
    if not found then raise exception 'Объект не найден'; end if;
  end loop;

  return jsonb_build_object(
    'employee_document_paths', v_employee_document_paths,
    'payment_receipt_paths', v_payment_receipt_paths,
    'task_photo_paths', v_task_photo_paths
  );
end;
$$;

revoke all on function public.permanently_delete_archived_objects(text[])
  from public, anon;
grant execute on function public.permanently_delete_archived_objects(text[])
  to authenticated;
