create or replace function private.populate_manager_absence_todos()
returns void
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $function$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_yesterday date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := ((now() at time zone 'Europe/Moscow')::date + time '08:00') at time zone 'Europe/Moscow';
  v_company record;
  v_snapshot jsonb;
  v_active_absent_items jsonb;
  v_absent_count integer;
  v_employee_names text;
begin
  if v_now_local < v_today + time '08:00' then
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

    select coalesce(
      jsonb_agg(item order by coalesce(item ->> 'title', '')),
      '[]'::jsonb
    )
    into v_active_absent_items
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
    ) item
    join public.employees employee
      on employee.id = nullif(btrim(item ->> 'employee_id'), '')::uuid
     and employee.company_id = v_company.id
    where coalesce(employee.is_active, false) = true
      and employee.archived_at is null;

    v_absent_count := jsonb_array_length(v_active_absent_items);
    v_snapshot := jsonb_set(
      v_snapshot,
      '{absent_items}',
      v_active_absent_items,
      true
    );
    v_snapshot := jsonb_set(
      v_snapshot,
      '{absent}',
      to_jsonb(v_absent_count),
      true
    );

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
        from jsonb_array_elements(v_active_absent_items) item
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
    from jsonb_array_elements(v_active_absent_items) item
    where nullif(btrim(item ->> 'employee_id'), '') is not null
    on conflict(company_id, employee_id, absence_date)
    do update set
      amount = 10000,
      status = case
        when public.absence_fines.status = 'confirmed' then 'confirmed'
        else 'pending'
      end,
      cancelled_at = case
        when public.absence_fines.status = 'confirmed'
          then public.absence_fines.cancelled_at
        else null
      end,
      updated_at = now();

    if v_absent_count = 0 then
      update public.manager_todos todo
      set status = 'cancelled', updated_at = now()
      where todo.company_id = v_company.id
        and todo.source_type = 'attendance_no_show'
        and todo.source_date = v_yesterday
        and todo.status = 'open';
      continue;
    end if;

    select string_agg(
      item ->> 'title',
      ', '
      order by item ->> 'title'
    )
    into v_employee_names
    from jsonb_array_elements(v_active_absent_items) item;

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
        'За %s отсутствовали: %s. Взять объяснительную и подписать акт о нарушении у каждого сотрудника.',
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
        'absent_count', v_absent_count,
        'employees', v_active_absent_items,
        'pending_fine_amount', 10000,
        'fine_requires_explanation', true,
        'fine_requires_signed_act', true,
        'source', 'attendance_snapshot'
      ),
      null,
      'admin',
      null
    )
    on conflict(company_id, source_type, source_key)
      where source_key is not null
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

-- Pending penalties are actionable work too: once an employee is no longer
-- active, do not keep asking managers to collect documents for that penalty.
update public.absence_fines fine
set
  status = 'cancelled',
  cancelled_at = coalesce(fine.cancelled_at, now()),
  updated_at = now()
from public.employees employee
where employee.id = fine.employee_id
  and employee.company_id = fine.company_id
  and fine.status = 'pending'
  and (
    coalesce(employee.is_active, false) = false
    or employee.archived_at is not null
  );

-- Reconcile already-open explanation tasks, including dates older than
-- yesterday. Historical attendance remains untouched; only current action
-- items are filtered to employees who still work for the company.
do $reconcile_open_absence_todos$
declare
  v_todo record;
  v_active_items jsonb;
  v_active_count integer;
  v_active_names text;
begin
  for v_todo in
    select todo.id, todo.company_id, todo.source_date, todo.metadata
    from public.manager_todos todo
    where todo.source_type = 'attendance_no_show'
      and todo.status = 'open'
  loop
    select
      coalesce(
        jsonb_agg(item order by coalesce(item ->> 'title', '')),
        '[]'::jsonb
      ),
      string_agg(
        item ->> 'title',
        ', '
        order by item ->> 'title'
      )
    into v_active_items, v_active_names
    from jsonb_array_elements(
      coalesce(v_todo.metadata -> 'employees', '[]'::jsonb)
    ) item
    join public.employees employee
      on employee.id = nullif(btrim(item ->> 'employee_id'), '')::uuid
     and employee.company_id = v_todo.company_id
    where coalesce(employee.is_active, false) = true
      and employee.archived_at is null;

    v_active_count := jsonb_array_length(v_active_items);

    if v_active_count = 0 then
      update public.manager_todos todo
      set
        status = 'cancelled',
        metadata = jsonb_set(
          jsonb_set(todo.metadata, '{employees}', '[]'::jsonb, true),
          '{absent_count}',
          '0'::jsonb,
          true
        ),
        updated_at = now()
      where todo.id = v_todo.id;
    else
      update public.manager_todos todo
      set
        body = format(
          'За %s отсутствовали: %s. Взять объяснительную и подписать акт о нарушении у каждого сотрудника.',
          to_char(v_todo.source_date, 'DD.MM.YYYY'),
          v_active_names
        ),
        metadata = jsonb_set(
          jsonb_set(todo.metadata, '{employees}', v_active_items, true),
          '{absent_count}',
          to_jsonb(v_active_count),
          true
        ),
        updated_at = now()
      where todo.id = v_todo.id;
    end if;
  end loop;
end;
$reconcile_open_absence_todos$;
