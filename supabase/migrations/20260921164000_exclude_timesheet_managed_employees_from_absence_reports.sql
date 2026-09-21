CREATE OR REPLACE FUNCTION private.manager_attendance_snapshot(p_company_id uuid, p_object_id uuid, p_work_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
 SET "TimeZone" TO 'Europe/Moscow'
AS $function$
with employee_candidates as (
  select
    e.*,
    exists (
      select 1
      from public.attendance a
      where a.company_id = e.company_id
        and a.employee_id = e.id
        and a.work_date = p_work_date
        and a.deleted_at is null
        and (p_object_id is null or a.object_id = p_object_id)
    ) as has_attendance
  from public.employees e
  where e.company_id = p_company_id
    and coalesce(e.timesheet_excluded, false) = false
    and (p_object_id is null or e.object_id = p_object_id)
    and (
      (
        p_work_date >= current_date
        and e.is_active = true
        and e.archived_at is null
      )
      or (
        p_work_date < current_date
        and e.created_at::date <= p_work_date
        and (
          e.is_active = true
          or coalesce(e.archived_at::date, e.updated_at::date) > p_work_date
        )
      )
    )
), effective_employees as (
  select distinct on (e.person_id) e.*
  from employee_candidates e
  order by
    e.person_id,
    e.has_attendance desc,
    e.created_at desc,
    e.id
), object_state as (
  select
    o.id as object_id,
    o.name as object_name,
    count(*)::integer as expected_count,
    exists (
      select 1
      from public.attendance a
      where a.company_id = p_company_id
        and a.object_id = o.id
        and a.work_date = p_work_date
        and a.deleted_at is null
    ) as has_any_attendance
  from public.objects o
  join effective_employees e on e.object_id = o.id
  where o.company_id = p_company_id
    and o.is_active = true
    and (p_object_id is null or o.id = p_object_id)
  group by o.id, o.name
), attendance_summary as (
  select
    count(distinct attendance_employee.person_id)::integer as marked,
    coalesce(sum(coalesce(a.shifts, 0)), 0)::numeric as shifts
  from public.attendance a
  join public.employees attendance_employee
    on attendance_employee.id = a.employee_id
   and attendance_employee.company_id = a.company_id
  where a.company_id = p_company_id
    and coalesce(attendance_employee.timesheet_excluded, false) = false
    and a.work_date = p_work_date
    and a.deleted_at is null
    and (p_object_id is null or a.object_id = p_object_id)
), absent_people as (
  select
    e.id as employee_id,
    e.person_id,
    e.fio,
    e.position,
    e.object_id,
    state.object_name,
    exists (
      select 1
      from public.attendance no_show_row
      join public.employees no_show_employee
        on no_show_employee.id = no_show_row.employee_id
       and no_show_employee.company_id = no_show_row.company_id
      where no_show_row.company_id = e.company_id
        and no_show_employee.person_id = e.person_id
        and no_show_row.object_id = e.object_id
        and no_show_row.work_date = p_work_date
        and no_show_row.deleted_at is null
        and lower(btrim(coalesce(no_show_row.status, ''))) = 'no_show'
        and coalesce(no_show_row.shifts, 0) = 0
    ) as confirmed_no_show
  from effective_employees e
  join object_state state
    on state.object_id = e.object_id
   and state.has_any_attendance = true
  where not exists (
    select 1
    from public.attendance positive_row
    join public.employees positive_employee
      on positive_employee.id = positive_row.employee_id
     and positive_employee.company_id = positive_row.company_id
    where positive_row.company_id = e.company_id
      and positive_employee.person_id = e.person_id
      and positive_row.object_id = e.object_id
      and positive_row.work_date = p_work_date
      and positive_row.deleted_at is null
      and coalesce(positive_row.shifts, 0) > 0
  )
), absent_payload as (
  select
    count(*)::integer as absent_count,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', employee_id,
          'employee_id', employee_id,
          'person_id', person_id,
          'title', coalesce(nullif(btrim(fio), ''), 'Сотрудник'),
          'subtitle', btrim(coalesce(position, '')),
          'note', 'Отсутствовал · ' || coalesce(nullif(btrim(object_name), ''), 'Без объекта'),
          'object_id', object_id,
          'object_name', object_name,
          'confirmed_no_show', confirmed_no_show
        )
        order by fio, employee_id
      ),
      '[]'::jsonb
    ) as items
  from absent_people
), unfilled_payload as (
  select
    count(*)::integer as unfilled_count,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', object_id,
          'title', object_name,
          'subtitle', expected_count::text || ' сотрудников',
          'note', 'Табель не заполнен',
          'object_id', object_id,
          'object_name', object_name,
          'expected_count', expected_count
        )
        order by object_name, object_id
      ),
      '[]'::jsonb
    ) as items
  from object_state
  where has_any_attendance = false
)
select jsonb_build_object(
  'active', (select count(*)::integer from effective_employees),
  'marked', coalesce(attendance_summary.marked, 0),
  'shifts', coalesce(attendance_summary.shifts, 0),
  'absent', coalesce(absent_payload.absent_count, 0),
  'missing', coalesce(absent_payload.absent_count, 0),
  'absent_items', coalesce(absent_payload.items, '[]'::jsonb),
  'unfilled_objects', coalesce(unfilled_payload.unfilled_count, 0),
  'unfilled_items', coalesce(unfilled_payload.items, '[]'::jsonb)
)
from attendance_summary, absent_payload, unfilled_payload;
$function$;


CREATE OR REPLACE FUNCTION private.populate_manager_absence_todos()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
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
      and coalesce(employee.timesheet_excluded, false) = false
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



-- Keep the explicitly excluded employee out of all future timesheet reports.
update public.employees
set timesheet_excluded = true,
    updated_at = now()
where fio = 'Одинцев Илья Александрович'
  and object_name = 'Мурманск'
  and archived_at is null;

-- Remove timesheet-excluded employees from already-open explanation todos.
with affected as (
  select
    todo.id,
    todo.source_date,
    coalesce(
      (
        select jsonb_agg(item order by item ->> 'title')
        from jsonb_array_elements(
          coalesce(todo.metadata -> 'employees', '[]'::jsonb)
        ) item
        left join public.employees employee
          on employee.id =
             nullif(btrim(item ->> 'employee_id'), '')::uuid
        where coalesce(employee.timesheet_excluded, false) = false
      ),
      '[]'::jsonb
    ) as employees,
    coalesce(
      (
        select jsonb_agg(item order by item ->> 'title')
        from jsonb_array_elements(
          coalesce(todo.metadata -> 'fine_employees', '[]'::jsonb)
        ) item
        left join public.employees employee
          on employee.id =
             nullif(btrim(item ->> 'employee_id'), '')::uuid
        where coalesce(employee.timesheet_excluded, false) = false
      ),
      '[]'::jsonb
    ) as fine_employees
  from public.manager_todos todo
  where todo.status = 'open'
    and todo.source_type = 'attendance_no_show'
    and exists (
      select 1
      from jsonb_array_elements(
        coalesce(todo.metadata -> 'employees', '[]'::jsonb)
      ) item
      join public.employees employee
        on employee.id =
           nullif(btrim(item ->> 'employee_id'), '')::uuid
      where coalesce(employee.timesheet_excluded, false) = true
    )
),
recalculated as (
  select
    affected.*,
    jsonb_array_length(affected.employees) as employee_count,
    jsonb_array_length(affected.fine_employees) as fine_count,
    (
      select string_agg(
        item ->> 'title',
        ', '
        order by item ->> 'title'
      )
      from jsonb_array_elements(affected.employees) item
    ) as employee_names
  from affected
)
update public.manager_todos todo
set
  status = case
    when recalculated.employee_count = 0 then 'cancelled'
    else todo.status
  end,
  body = case
    when recalculated.employee_count = 0 then
      format(
        'За %s сотрудников для объяснительных нет.',
        to_char(recalculated.source_date, 'DD.MM.YYYY')
      )
    else
      format(
        'За %s отсутствовали: %s. Взять объяснительную у каждого сотрудника. Для прогулов оформить акт о нарушении.',
        to_char(recalculated.source_date, 'DD.MM.YYYY'),
        recalculated.employee_names
      )
  end,
  metadata =
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                coalesce(todo.metadata, '{}'::jsonb),
                '{employees}',
                recalculated.employees,
                true
              ),
              '{absent_count}',
              to_jsonb(recalculated.employee_count),
              true
            ),
            '{fine_employees}',
            recalculated.fine_employees,
            true
          ),
          '{pending_fine_count}',
          to_jsonb(recalculated.fine_count),
          true
        ),
        '{fine_requires_explanation}',
        to_jsonb(recalculated.fine_count > 0),
        true
      ),
      '{fine_requires_signed_act}',
      to_jsonb(recalculated.fine_count > 0),
      true
    ),
  updated_at = now()
from recalculated
where todo.id = recalculated.id;

-- Pending absence penalties created only from the timesheet automation must
-- not remain active for employees excluded from the timesheet.
update public.absence_fines fine
set
  status = 'cancelled',
  cancelled_at = coalesce(fine.cancelled_at, now()),
  updated_at = now()
where fine.status = 'pending'
  and exists (
    select 1
    from public.employees employee
    where employee.id = fine.employee_id
      and employee.company_id = fine.company_id
      and coalesce(employee.timesheet_excluded, false) = true
  );
