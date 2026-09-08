create or replace function private.populate_manager_absence_todos()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_yesterday date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := ((now() at time zone 'Europe/Moscow')::date + time '10:00') at time zone 'Europe/Moscow';
  v_company record;
  v_snapshot jsonb;
  v_explanation_items jsonb;
  v_fine_items jsonb;
  v_explanation_count integer;
  v_fine_count integer;
  v_employee_names text;
begin
  if v_now_local < v_today + time '10:00' then
    return;
  end if;

  for v_company in
    select company.id
    from public.companies company
    where company.status = 'active'
  loop
    v_snapshot := private.manager_attendance_snapshot(
      v_company.id,
      null,
      v_yesterday
    );

    -- Explanations are required for sickness and no-show. A planned day off
    -- must never appear in the manager's explanation todo.
    select coalesce(
      jsonb_agg(item order by coalesce(item ->> 'title', '')),
      '[]'::jsonb
    )
    into v_explanation_items
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
    ) item
    join public.employees employee
      on employee.id = nullif(btrim(item ->> 'employee_id'), '')::uuid
     and employee.company_id = v_company.id
    where coalesce(employee.is_active, false) = true
      and employee.archived_at is null
      and not exists (
        select 1
        from public.attendance attendance_row
        where attendance_row.company_id = v_company.id
          and attendance_row.employee_id = employee.id
          and attendance_row.work_date = v_yesterday
          and attendance_row.deleted_at is null
          and coalesce(attendance_row.shifts, 0) = 0
          and lower(btrim(coalesce(attendance_row.absence_reason, ''))) = 'day_off'
      );

    -- Keep fines stricter than explanation collection: sickness needs an
    -- explanation, but it must not be converted into a no-show fine.
    select coalesce(
      jsonb_agg(item order by coalesce(item ->> 'title', '')),
      '[]'::jsonb
    )
    into v_fine_items
    from jsonb_array_elements(v_explanation_items) item
    where not exists (
      select 1
      from public.attendance attendance_row
      where attendance_row.company_id = v_company.id
        and attendance_row.employee_id = nullif(btrim(item ->> 'employee_id'), '')::uuid
        and attendance_row.work_date = v_yesterday
        and attendance_row.deleted_at is null
        and coalesce(attendance_row.shifts, 0) = 0
        and lower(btrim(coalesce(attendance_row.absence_reason, ''))) = 'sick'
    );

    v_explanation_count := jsonb_array_length(v_explanation_items);
    v_fine_count := jsonb_array_length(v_fine_items);
    v_snapshot := jsonb_set(v_snapshot, '{absent_items}', v_explanation_items, true);
    v_snapshot := jsonb_set(v_snapshot, '{absent}', to_jsonb(v_explanation_count), true);

    update public.absence_fines fine
    set
      status = 'cancelled',
      cancelled_at = coalesce(fine.cancelled_at, now()),
      updated_at = now()
    where fine.company_id = v_company.id
      and fine.absence_date = v_yesterday
      and fine.status = 'pending'
      and not exists (
        select 1
        from jsonb_array_elements(v_fine_items) item
        where nullif(btrim(item ->> 'employee_id'), '')::uuid = fine.employee_id
      );

    insert into public.absence_fines(
      company_id,
      employee_id,
      absence_date,
      amount,
      status,
      updated_at
    )
    select
      v_company.id,
      nullif(btrim(item ->> 'employee_id'), '')::uuid,
      v_yesterday,
      10000,
      'pending',
      now()
    from jsonb_array_elements(v_fine_items) item
    where nullif(btrim(item ->> 'employee_id'), '') is not null
    on conflict(company_id, employee_id, absence_date)
    do update set
      amount = 10000,
      status = case
        when public.absence_fines.status = 'confirmed' then 'confirmed'
        else 'pending'
      end,
      cancelled_at = case
        when public.absence_fines.status = 'confirmed' then public.absence_fines.cancelled_at
        else null
      end,
      updated_at = now();

    if v_explanation_count = 0 then
      update public.manager_todos todo
      set status = 'cancelled', updated_at = now()
      where todo.company_id = v_company.id
        and todo.source_type = 'attendance_no_show'
        and todo.source_date = v_yesterday
        and todo.status = 'open';
      continue;
    end if;

    select string_agg(item ->> 'title', ', ' order by item ->> 'title')
    into v_employee_names
    from jsonb_array_elements(v_explanation_items) item;

    insert into public.manager_todos(
      company_id,
      title,
      body,
      status,
      due_at,
      reminder_at,
      priority,
      source_type,
      source_key,
      source_date,
      metadata,
      recipient_user_id,
      target_role,
      created_by
    )
    values(
      v_company.id,
      'Взять объяснительные',
      format(
        'За %s отсутствовали: %s. Взять объяснительную у каждого сотрудника. Для прогулов оформить акт о нарушении.',
        to_char(v_yesterday, 'DD.MM.YYYY'),
        coalesce(v_employee_names, 'сотрудники')
      ),
      'open',
      v_due_at,
      v_due_at,
      'high',
      'attendance_no_show',
      'attendance-no-show:' || v_yesterday::text,
      v_yesterday,
      jsonb_build_object(
        'absence_date', v_yesterday,
        'absent_count', v_explanation_count,
        'employees', v_explanation_items,
        'pending_fine_amount', 10000,
        'pending_fine_count', v_fine_count,
        'fine_employees', v_fine_items,
        'fine_requires_explanation', v_fine_count > 0,
        'fine_requires_signed_act', v_fine_count > 0,
        'source', 'attendance_snapshot'
      ),
      null,
      'admin',
      null
    )
    on conflict(company_id, source_type, source_key) where source_key is not null
    do update set
      body = excluded.body,
      metadata = excluded.metadata,
      due_at = excluded.due_at,
      reminder_at = excluded.reminder_at,
      updated_at = now()
    where public.manager_todos.status = 'open';
  end loop;
end;
$function$;
