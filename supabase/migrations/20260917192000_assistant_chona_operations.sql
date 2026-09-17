create schema if not exists private;

create table if not exists private.assistant_chona_operations (
  request_id uuid primary key,
  operation text not null check (operation in ('create_tasks', 'upsert_attendance')),
  payload jsonb not null,
  result jsonb,
  created_at timestamptz not null default now()
);

revoke all on table private.assistant_chona_operations from public, anon, authenticated;

comment on table private.assistant_chona_operations is
  'Idempotency log for the restricted ChatGPT service channel used for Chona tasks and attendance.';

create or replace function private.assistant_chona_create_tasks(
  p_request_id uuid,
  p_task_date date,
  p_tasks jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
declare
  v_actor_id uuid;
  v_actor_name text;
  v_company_id uuid;
  v_object_id uuid;
  v_object_name text;
  v_payload jsonb;
  v_existing_operation text;
  v_existing_payload jsonb;
  v_existing_result jsonb;
  v_inserted integer;
  v_item jsonb;
  v_task_id uuid;
  v_axes text;
  v_work text;
  v_assignees jsonb;
  v_fio text;
  v_employee_ids uuid[];
  v_employee_id uuid;
  v_without_volume boolean;
  v_planned_quantity numeric;
  v_unit text;
  v_tasks_result jsonb := '[]'::jsonb;
begin
  if p_request_id is null then
    raise exception 'request_id is required';
  end if;
  if p_task_date is null then
    raise exception 'task_date is required';
  end if;
  if p_tasks is null or jsonb_typeof(p_tasks) <> 'array' then
    raise exception 'tasks must be a JSON array';
  end if;
  if jsonb_array_length(p_tasks) < 1 or jsonb_array_length(p_tasks) > 50 then
    raise exception 'tasks array must contain from 1 to 50 items';
  end if;

  begin
    select
      up.id,
      coalesce(nullif(btrim(up.full_name), ''), 'Одинцев Илья Александрович'),
      membership.company_id,
      obj.id,
      obj.name
    into strict
      v_actor_id,
      v_actor_name,
      v_company_id,
      v_object_id,
      v_object_name
    from public.user_profiles up
    join public.company_memberships membership
      on membership.user_id = up.id
     and membership.is_active = true
     and membership.role = 'owner'
    join public.objects obj
      on obj.company_id = membership.company_id
     and obj.is_active = true
     and lower(btrim(obj.name)) = lower('Чона')
    where lower(btrim(up.full_name)) = lower('Одинцев Илья Александрович');
  exception
    when no_data_found then
      raise exception 'Chona owner context was not found';
    when too_many_rows then
      raise exception 'Chona owner context is ambiguous';
  end;

  perform set_config('request.jwt.claim.sub', v_actor_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_actor_id::text, 'role', 'authenticated')::text,
    true
  );

  v_payload := jsonb_build_object(
    'task_date', p_task_date,
    'tasks', p_tasks
  );

  insert into private.assistant_chona_operations(request_id, operation, payload)
  values (p_request_id, 'create_tasks', v_payload)
  on conflict (request_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select operation, payload, result
      into v_existing_operation, v_existing_payload, v_existing_result
    from private.assistant_chona_operations
    where request_id = p_request_id;

    if v_existing_operation is distinct from 'create_tasks'
       or v_existing_payload is distinct from v_payload then
      raise exception 'request_id was already used with another operation or payload';
    end if;
    if v_existing_result is null then
      raise exception 'request_id is already being processed';
    end if;
    return v_existing_result;
  end if;

  for v_item in
    select value from jsonb_array_elements(p_tasks)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'each task must be a JSON object';
    end if;

    v_axes := btrim(coalesce(v_item ->> 'axes', ''));
    v_work := btrim(coalesce(v_item ->> 'work', ''));
    if v_axes = '' or v_work = '' then
      raise exception 'each task must contain axes and work';
    end if;
    if char_length(v_axes) > 1000 or char_length(v_work) > 4000 then
      raise exception 'axes or work exceeds the allowed length';
    end if;

    v_assignees := coalesce(v_item -> 'assignee_fios', '[]'::jsonb);
    if jsonb_typeof(v_assignees) <> 'array' then
      raise exception 'assignee_fios must be a JSON array';
    end if;
    if jsonb_array_length(v_assignees) > 100 then
      raise exception 'too many assignees';
    end if;

    begin
      v_without_volume := coalesce((v_item ->> 'without_volume')::boolean, false);
    exception when invalid_text_representation then
      raise exception 'without_volume must be boolean';
    end;

    v_unit := btrim(coalesce(v_item ->> 'unit', ''));
    begin
      v_planned_quantity := case
        when v_item ? 'planned_quantity' and v_item ->> 'planned_quantity' is not null
          then (v_item ->> 'planned_quantity')::numeric
        else null
      end;
    exception when invalid_text_representation then
      raise exception 'planned_quantity must be numeric';
    end;

    if v_without_volume then
      if v_planned_quantity is not null or v_unit <> '' then
        raise exception 'without-volume task cannot contain quantity or unit';
      end if;
    else
      if v_planned_quantity is null or v_unit = '' then
        raise exception 'task with volume must contain planned_quantity and unit';
      end if;
      if v_planned_quantity < 0 then
        raise exception 'planned_quantity cannot be negative';
      end if;
      if char_length(v_unit) > 40 then
        raise exception 'unit exceeds the allowed length';
      end if;
    end if;

    insert into public.tasks(
      company_id,
      task_date,
      object_name,
      object_id,
      axes,
      work,
      status,
      not_done_comment,
      created_by,
      created_by_user_id,
      is_draft,
      photo_requirements_enforced
    ) values (
      v_company_id,
      p_task_date,
      v_object_name,
      v_object_id,
      v_axes,
      v_work,
      'Запланировано',
      '',
      v_actor_name,
      v_actor_id,
      true,
      false
    )
    returning id into v_task_id;

    for v_fio in
      select btrim(value)
      from jsonb_array_elements_text(v_assignees)
    loop
      if v_fio = '' then
        raise exception 'assignee fio cannot be empty';
      end if;

      select array_agg(employee.id)
        into v_employee_ids
      from public.employees employee
      where employee.company_id = v_company_id
        and employee.object_id = v_object_id
        and employee.is_active = true
        and employee.archived_at is null
        and lower(btrim(employee.fio)) = lower(v_fio);

      if coalesce(cardinality(v_employee_ids), 0) <> 1 then
        raise exception 'active Chona employee not found uniquely: %', v_fio;
      end if;
      v_employee_id := v_employee_ids[1];

      insert into public.task_assignees(company_id, task_id, employee_id)
      values (v_company_id, v_task_id, v_employee_id)
      on conflict (task_id, employee_id) do nothing;
    end loop;

    insert into public.task_work_plans(task_id, planned_quantity, unit, without_volume)
    values (
      v_task_id,
      case when v_without_volume then null else v_planned_quantity end,
      case when v_without_volume then '' else v_unit end,
      v_without_volume
    );

    update public.tasks
    set is_draft = false,
        updated_at = now()
    where id = v_task_id;

    v_tasks_result := v_tasks_result || jsonb_build_array(
      jsonb_build_object(
        'id', v_task_id,
        'task_date', p_task_date,
        'object_name', v_object_name,
        'axes', v_axes,
        'work', v_work,
        'assignee_fios', v_assignees,
        'planned_quantity', case when v_without_volume then null else v_planned_quantity end,
        'unit', case when v_without_volume then '' else v_unit end,
        'without_volume', v_without_volume
      )
    );
  end loop;

  v_existing_result := jsonb_build_object('ok', true, 'tasks', v_tasks_result);
  update private.assistant_chona_operations
  set result = v_existing_result
  where request_id = p_request_id;

  return v_existing_result;
end;
$$;

create or replace function private.assistant_chona_upsert_attendance(
  p_request_id uuid,
  p_work_date date,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = private, public, pg_temp
as $$
declare
  v_actor_id uuid;
  v_actor_name text;
  v_company_id uuid;
  v_object_id uuid;
  v_object_name text;
  v_payload jsonb;
  v_existing_operation text;
  v_existing_payload jsonb;
  v_existing_result jsonb;
  v_inserted integer;
  v_item jsonb;
  v_fio text;
  v_employee_ids uuid[];
  v_employee_id uuid;
  v_status text;
  v_shifts numeric;
  v_hours numeric;
  v_comment text;
  v_absence_reason text;
  v_attendance_id uuid;
  v_entries_result jsonb := '[]'::jsonb;
begin
  if p_request_id is null then
    raise exception 'request_id is required';
  end if;
  if p_work_date is null then
    raise exception 'work_date is required';
  end if;
  if p_entries is null or jsonb_typeof(p_entries) <> 'array' then
    raise exception 'entries must be a JSON array';
  end if;
  if jsonb_array_length(p_entries) < 1 or jsonb_array_length(p_entries) > 150 then
    raise exception 'entries array must contain from 1 to 150 items';
  end if;

  begin
    select
      up.id,
      coalesce(nullif(btrim(up.full_name), ''), 'Одинцев Илья Александрович'),
      membership.company_id,
      obj.id,
      obj.name
    into strict
      v_actor_id,
      v_actor_name,
      v_company_id,
      v_object_id,
      v_object_name
    from public.user_profiles up
    join public.company_memberships membership
      on membership.user_id = up.id
     and membership.is_active = true
     and membership.role = 'owner'
    join public.objects obj
      on obj.company_id = membership.company_id
     and obj.is_active = true
     and lower(btrim(obj.name)) = lower('Чона')
    where lower(btrim(up.full_name)) = lower('Одинцев Илья Александрович');
  exception
    when no_data_found then
      raise exception 'Chona owner context was not found';
    when too_many_rows then
      raise exception 'Chona owner context is ambiguous';
  end;

  perform set_config('request.jwt.claim.sub', v_actor_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_actor_id::text, 'role', 'authenticated')::text,
    true
  );

  v_payload := jsonb_build_object(
    'work_date', p_work_date,
    'entries', p_entries
  );

  insert into private.assistant_chona_operations(request_id, operation, payload)
  values (p_request_id, 'upsert_attendance', v_payload)
  on conflict (request_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select operation, payload, result
      into v_existing_operation, v_existing_payload, v_existing_result
    from private.assistant_chona_operations
    where request_id = p_request_id;

    if v_existing_operation is distinct from 'upsert_attendance'
       or v_existing_payload is distinct from v_payload then
      raise exception 'request_id was already used with another operation or payload';
    end if;
    if v_existing_result is null then
      raise exception 'request_id is already being processed';
    end if;
    return v_existing_result;
  end if;

  for v_item in
    select value from jsonb_array_elements(p_entries)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'each attendance entry must be a JSON object';
    end if;

    v_fio := btrim(coalesce(v_item ->> 'fio', ''));
    if v_fio = '' then
      raise exception 'attendance fio is required';
    end if;

    select array_agg(employee.id)
      into v_employee_ids
    from public.employees employee
    where employee.company_id = v_company_id
      and employee.object_id = v_object_id
      and lower(btrim(employee.fio)) = lower(v_fio);

    if coalesce(cardinality(v_employee_ids), 0) <> 1 then
      raise exception 'Chona employee not found uniquely: %', v_fio;
    end if;
    v_employee_id := v_employee_ids[1];

    v_status := lower(btrim(coalesce(v_item ->> 'status', 'worked')));
    if v_status not in ('worked', 'no_show') then
      raise exception 'unsupported attendance status for %: %', v_fio, v_status;
    end if;

    begin
      v_shifts := case
        when v_item ? 'shifts' and v_item ->> 'shifts' is not null
          then (v_item ->> 'shifts')::numeric
        when v_status = 'worked' then 1
        else 0
      end;
      v_hours := case
        when v_item ? 'hours' and v_item ->> 'hours' is not null
          then (v_item ->> 'hours')::numeric
        else 0
      end;
    exception when invalid_text_representation then
      raise exception 'shifts and hours must be numeric';
    end;

    if v_shifts < 0 or v_shifts > 2 then
      raise exception 'shifts must be between 0 and 2 for %', v_fio;
    end if;
    if v_hours < 0 or v_hours > 48 then
      raise exception 'hours must be between 0 and 48 for %', v_fio;
    end if;
    if v_status = 'worked' and v_shifts <= 0 then
      raise exception 'worked entry must have positive shifts for %', v_fio;
    end if;
    if v_status = 'no_show' and v_shifts <> 0 then
      raise exception 'no_show entry must have zero shifts for %', v_fio;
    end if;

    v_comment := btrim(coalesce(v_item ->> 'comment', ''));
    v_absence_reason := lower(btrim(coalesce(v_item ->> 'absence_reason', '')));
    if v_status = 'worked' then
      v_absence_reason := null;
    else
      if v_absence_reason = '' then
        v_absence_reason := 'no_show';
      end if;
      if v_absence_reason not in ('sick', 'day_off', 'no_show') then
        raise exception 'unsupported absence_reason for %: %', v_fio, v_absence_reason;
      end if;
    end if;

    insert into public.attendance(
      company_id,
      work_date,
      employee_id,
      object_name,
      object_id,
      status,
      shifts,
      hours,
      comment,
      marked_by,
      marked_by_user_id,
      absence_reason,
      deleted_at,
      deleted_by,
      delete_reason,
      restored_at,
      restored_by
    ) values (
      v_company_id,
      p_work_date,
      v_employee_id,
      v_object_name,
      v_object_id,
      v_status,
      v_shifts,
      v_hours,
      v_comment,
      v_actor_name,
      v_actor_id,
      v_absence_reason,
      null,
      null,
      '',
      null,
      null
    )
    on conflict (work_date, employee_id) do update
      set company_id = excluded.company_id,
          object_name = excluded.object_name,
          object_id = excluded.object_id,
          status = excluded.status,
          shifts = excluded.shifts,
          hours = excluded.hours,
          comment = excluded.comment,
          marked_by = excluded.marked_by,
          marked_by_user_id = excluded.marked_by_user_id,
          absence_reason = excluded.absence_reason,
          deleted_at = null,
          deleted_by = null,
          delete_reason = '',
          restored_at = case
            when public.attendance.deleted_at is not null then now()
            else public.attendance.restored_at
          end,
          restored_by = case
            when public.attendance.deleted_at is not null then v_actor_id
            else public.attendance.restored_by
          end,
          updated_at = now()
    returning id into v_attendance_id;

    v_entries_result := v_entries_result || jsonb_build_array(
      jsonb_build_object(
        'id', v_attendance_id,
        'work_date', p_work_date,
        'fio', v_fio,
        'status', v_status,
        'shifts', v_shifts,
        'hours', v_hours,
        'absence_reason', v_absence_reason
      )
    );
  end loop;

  v_existing_result := jsonb_build_object('ok', true, 'entries', v_entries_result);
  update private.assistant_chona_operations
  set result = v_existing_result
  where request_id = p_request_id;

  return v_existing_result;
end;
$$;

revoke all on function private.assistant_chona_create_tasks(uuid, date, jsonb)
  from public, anon, authenticated;
revoke all on function private.assistant_chona_upsert_attendance(uuid, date, jsonb)
  from public, anon, authenticated;

comment on function private.assistant_chona_create_tasks(uuid, date, jsonb) is
  'Restricted idempotent service function for ChatGPT to create Chona tasks through normal task triggers and audits.';
comment on function private.assistant_chona_upsert_attendance(uuid, date, jsonb) is
  'Restricted idempotent service function for ChatGPT to correct Chona attendance through normal attendance triggers and audits.';
