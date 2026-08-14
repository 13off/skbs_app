-- AppСтрой: неустойка за подтверждённый невыход.
-- Для каждого attendance.status = 'no_show' фиксируем 10 000 ₽ и помечаем,
-- что финансовое последствие должно быть приложено к объяснительной.

create or replace function private.populate_manager_absence_todos()
returns void
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_yesterday date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := ((now() at time zone 'Europe/Moscow')::date + time '08:00')
    at time zone 'Europe/Moscow';
  v_penalty_amount integer := 10000;
begin
  if v_now_local < v_today + time '08:00' then
    return;
  end if;

  -- Если подтверждённый невыход исправили до следующего прохода,
  -- открытое системное дело скрываем. Уже выполненные дела не трогаем.
  update public.manager_todos todo
  set status = 'cancelled',
      updated_at = now()
  where todo.source_type = 'attendance_no_show'
    and todo.source_date = v_yesterday
    and todo.status = 'open'
    and not exists (
      select 1
      from public.attendance attendance_row
      where attendance_row.company_id = todo.company_id
        and attendance_row.work_date = v_yesterday
        and attendance_row.deleted_at is null
        and lower(btrim(coalesce(attendance_row.status, ''))) = 'no_show'
        and coalesce(attendance_row.shifts, 0) = 0
        and not exists (
          select 1
          from public.attendance positive_row
          where positive_row.company_id = attendance_row.company_id
            and positive_row.employee_id = attendance_row.employee_id
            and positive_row.work_date = attendance_row.work_date
            and positive_row.deleted_at is null
            and coalesce(positive_row.shifts, 0) > 0
        )
    );

  with absent as (
    select distinct
      attendance_row.company_id,
      employee.id as employee_id,
      coalesce(nullif(btrim(employee.fio), ''), 'Сотрудник') as employee_name
    from public.attendance attendance_row
    join public.employees employee
      on employee.id = attendance_row.employee_id
     and employee.company_id = attendance_row.company_id
    join public.companies company
      on company.id = attendance_row.company_id
     and company.status = 'active'
    where attendance_row.work_date = v_yesterday
      and attendance_row.deleted_at is null
      and lower(btrim(coalesce(attendance_row.status, ''))) = 'no_show'
      and coalesce(attendance_row.shifts, 0) = 0
      and not exists (
        select 1
        from public.attendance positive_row
        where positive_row.company_id = attendance_row.company_id
          and positive_row.employee_id = attendance_row.employee_id
          and positive_row.work_date = attendance_row.work_date
          and positive_row.deleted_at is null
          and coalesce(positive_row.shifts, 0) > 0
      )
  ), grouped as (
    select
      company_id,
      count(*)::integer as absent_count,
      string_agg(employee_name, ', ' order by employee_name) as employee_names,
      jsonb_agg(
        jsonb_build_object(
          'employee_id', employee_id,
          'name', employee_name,
          'financial_consequence', 'contract_penalty',
          'penalty_amount', v_penalty_amount,
          'currency', 'RUB',
          'attach_to_explanation', true
        )
        order by employee_name
      ) as employees
    from absent
    group by company_id
  )
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
  select
    grouped.company_id,
    'Взять объяснительные',
    format(
      'За %s отсутствовали: %s. Неустойка: 10 000 ₽ за каждого подтверждённого невыхода. Прикрепить к объяснительной.',
      to_char(v_yesterday, 'DD.MM.YYYY'),
      grouped.employee_names
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
      'absent_count', grouped.absent_count,
      'employees', grouped.employees,
      'financial_consequence', 'contract_penalty',
      'penalty_amount_per_employee', v_penalty_amount,
      'currency', 'RUB',
      'attach_to_explanation', true
    ),
    null,
    'admin',
    null
  from grouped
  on conflict (company_id, source_type, source_key)
    where source_key is not null
  do update
  set body = excluded.body,
      metadata = excluded.metadata,
      due_at = excluded.due_at,
      reminder_at = excluded.reminder_at,
      updated_at = now()
  where public.manager_todos.status = 'open';
end;
$$;

-- Сразу обновляем уже созданные открытые дела по невыходам,
-- чтобы 10 000 ₽ появились без ожидания следующего автоматического прохода.
update public.manager_todos todo
set body = case
      when position('Неустойка:' in todo.body) > 0 then todo.body
      else rtrim(todo.body, '. ') || '. Неустойка: 10 000 ₽ за каждого подтверждённого невыхода. Прикрепить к объяснительной.'
    end,
    metadata = todo.metadata || jsonb_build_object(
      'financial_consequence', 'contract_penalty',
      'penalty_amount_per_employee', 10000,
      'currency', 'RUB',
      'attach_to_explanation', true,
      'employees', coalesce((
        select jsonb_agg(
          case
            when jsonb_typeof(employee_item) = 'object' then
              employee_item || jsonb_build_object(
                'financial_consequence', 'contract_penalty',
                'penalty_amount', 10000,
                'currency', 'RUB',
                'attach_to_explanation', true
              )
            else employee_item
          end
        )
        from jsonb_array_elements(coalesce(todo.metadata->'employees', '[]'::jsonb)) employee_item
      ), '[]'::jsonb)
    ),
    updated_at = now()
where todo.source_type = 'attendance_no_show'
  and todo.status = 'open';
