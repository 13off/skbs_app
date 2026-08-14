-- AppСтрой: единая логика посещаемости для отчётов, напоминаний и «Дел».
--
-- Правила:
-- 1. Если по объекту за день нет ни одной строки табеля — это НЕ отсутствие
--    сотрудников. Это «табель не заполнен».
-- 2. Если по объекту есть хотя бы одна строка табеля, сотрудник без положительной
--    смены за этот день считается отсутствовавшим.
-- 3. В 12:00 МСК руководителю приходит одно агрегированное напоминание по
--    объектам, где табель вообще не заполнен.
-- 4. На следующий день в 08:00 МСК руководителю создаётся одно дело
--    «Взять объяснительные» со списком отсутствовавших сотрудников.
-- 5. Старое автоматическое дело «Закрыть пропуски в табеле» из отчётов больше
--    не создаётся, чтобы не дублировать новую семантику.

create or replace function private.manager_attendance_snapshot(
  p_company_id uuid,
  p_object_id uuid,
  p_work_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
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
  -- Поле missing оставлено как совместимый алиас для текущего клиента.
  -- Теперь оно означает именно отсутствие, а не «пустую ячейку».
  'missing', coalesce(absent_payload.absent_count, 0),
  'absent_items', coalesce(absent_payload.items, '[]'::jsonb),
  'unfilled_objects', coalesce(unfilled_payload.unfilled_count, 0),
  'unfilled_items', coalesce(unfilled_payload.items, '[]'::jsonb)
)
from attendance_summary, absent_payload, unfilled_payload;
$$;

create or replace function private.manager_report_people_v2(
  p_company_id uuid,
  p_object_id uuid,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
with employee_rows as (
  select e.*
  from public.employees e
  where e.company_id = p_company_id
    and (p_object_id is null or e.object_id = p_object_id)
), added_people as (
  select count(distinct e.person_id)::integer as count
  from employee_rows e
  where e.created_at::date = p_report_date
    and not exists (
      select 1
      from employee_rows older
      where older.person_id = e.person_id
        and older.created_at < e.created_at
    )
), departed_people as (
  select count(distinct e.person_id)::integer as count
  from employee_rows e
  where coalesce(
      e.archived_at::date,
      case when not e.is_active then e.updated_at::date end
    ) = p_report_date
    and (
      p_object_id is not null
      or not exists (
        select 1
        from public.employees active_row
        where active_row.company_id = e.company_id
          and active_row.person_id = e.person_id
          and active_row.is_active = true
          and active_row.archived_at is null
      )
    )
), snapshots as (
  select
    private.manager_attendance_snapshot(
      p_company_id,
      p_object_id,
      p_report_date
    ) as today,
    private.manager_attendance_snapshot(
      p_company_id,
      p_object_id,
      p_report_date - 1
    ) as yesterday
)
select jsonb_build_object(
  'employees', jsonb_build_object(
    'active', coalesce((snapshots.today ->> 'active')::integer, 0),
    'added', added_people.count,
    'archived', departed_people.count,
    'historical_estimate', p_report_date < current_date
  ),
  'attendance', jsonb_build_object(
    'active', coalesce((snapshots.today ->> 'active')::integer, 0),
    'marked', coalesce((snapshots.today ->> 'marked')::integer, 0),
    'missing', coalesce((snapshots.today ->> 'absent')::integer, 0),
    'absent', coalesce((snapshots.today ->> 'absent')::integer, 0),
    'shifts', coalesce((snapshots.today ->> 'shifts')::numeric, 0),
    'unfilled_objects', coalesce((snapshots.today ->> 'unfilled_objects')::integer, 0),
    'historical_estimate', p_report_date < current_date
  ),
  'trend', jsonb_build_object(
    'attendance_missing_yesterday',
      coalesce((snapshots.yesterday ->> 'absent')::integer, 0),
    'attendance_absent_yesterday',
      coalesce((snapshots.yesterday ->> 'absent')::integer, 0)
  ),
  -- Старый ключ оставляем для совместимости, но внутри теперь отсутствовавшие.
  'missing_items', coalesce(snapshots.today -> 'absent_items', '[]'::jsonb),
  'absent_items', coalesce(snapshots.today -> 'absent_items', '[]'::jsonb),
  'unfilled_items', coalesce(snapshots.today -> 'unfilled_items', '[]'::jsonb)
)
from added_people, departed_people, snapshots;
$$;

-- Старое отчётное дело «Закрыть пропуски в табеле» больше не нужно.
-- Все остальные типы отчётных дел продолжают работать без изменений.
create or replace function private.sync_manager_report_todo_issue(
  p_company_id uuid,
  p_report_date date,
  p_due_at timestamptz,
  p_issue_code text,
  p_title text,
  p_body text,
  p_count integer,
  p_priority text default 'normal',
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_existing_id uuid;
  v_source_key text;
  v_metadata jsonb;
begin
  if p_company_id is null
    or p_report_date is null
    or nullif(btrim(coalesce(p_issue_code, '')), '') is null
  then
    return;
  end if;

  if p_issue_code = 'attendance_missing' then
    p_count := 0;
  end if;

  v_metadata := coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'issue_code', p_issue_code,
    'report_date', p_report_date,
    'count', greatest(coalesce(p_count, 0), 0),
    'source', 'manager_reports_center',
    'scope', 'company'
  );

  select todo.id
    into v_existing_id
  from public.manager_todos todo
  where todo.company_id = p_company_id
    and todo.source_type = 'manager_report'
    and todo.status = 'open'
    and todo.metadata ->> 'issue_code' = p_issue_code
  order by todo.created_at desc
  limit 1
  for update;

  if greatest(coalesce(p_count, 0), 0) = 0 then
    if v_existing_id is not null then
      update public.manager_todos
      set status = 'done',
          completed_by = null,
          completed_at = now(),
          metadata = metadata || jsonb_build_object(
            'auto_resolved', true,
            'resolved_at', now(),
            'last_report_date', p_report_date
          ),
          updated_at = now()
      where id = v_existing_id;
    end if;
    return;
  end if;

  if v_existing_id is not null then
    update public.manager_todos
    set title = left(btrim(coalesce(p_title, '')), 300),
        body = left(btrim(coalesce(p_body, '')), 4000),
        source_date = p_report_date,
        due_at = p_due_at,
        reminder_at = p_due_at,
        priority = case
          when p_priority in ('low', 'normal', 'high', 'critical') then p_priority
          else 'normal'
        end,
        metadata = v_metadata || jsonb_build_object('auto_resolved', false),
        updated_at = now()
    where id = v_existing_id;
    return;
  end if;

  v_source_key := 'report:' || p_issue_code || ':' || p_report_date::text;

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
  ) values (
    p_company_id,
    left(btrim(coalesce(p_title, '')), 300),
    left(btrim(coalesce(p_body, '')), 4000),
    'open',
    p_due_at,
    p_due_at,
    case
      when p_priority in ('low', 'normal', 'high', 'critical') then p_priority
      else 'normal'
    end,
    'manager_report',
    v_source_key,
    p_report_date,
    v_metadata || jsonb_build_object('auto_resolved', false),
    null,
    'admin',
    null
  )
  on conflict (company_id, source_type, source_key)
    where source_key is not null
  do nothing;
end;
$$;

create or replace function private.populate_manager_absence_todos()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_yesterday date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := (
    (now() at time zone 'Europe/Moscow')::date + time '08:00'
  ) at time zone 'Europe/Moscow';
  v_company record;
  v_snapshot jsonb;
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
    v_absent_count := coalesce((v_snapshot ->> 'absent')::integer, 0);

    if v_absent_count = 0 then
      update public.manager_todos todo
      set status = 'cancelled',
          updated_at = now()
      where todo.company_id = v_company.id
        and todo.source_type = 'attendance_no_show'
        and todo.source_date = v_yesterday
        and todo.status = 'open';
      continue;
    end if;

    select string_agg(item ->> 'title', ', ' order by item ->> 'title')
      into v_employee_names
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
    ) item;

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
    ) values (
      v_company.id,
      'Взять объяснительные',
      format(
        'За %s отсутствовали: %s. Взять объяснительную у каждого сотрудника.',
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
        'employees', coalesce(v_snapshot -> 'absent_items', '[]'::jsonb),
        'source', 'attendance_snapshot'
      ),
      null,
      'admin',
      null
    )
    on conflict (company_id, source_type, source_key)
      where source_key is not null
    do update
    set body = excluded.body,
        metadata = excluded.metadata,
        due_at = excluded.due_at,
        reminder_at = excluded.reminder_at,
        updated_at = now()
    where public.manager_todos.status = 'open';
  end loop;
end;
$$;

create or replace function private.populate_manager_timesheet_unfilled_reminders()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := (
    (now() at time zone 'Europe/Moscow')::date + time '12:00'
  ) at time zone 'Europe/Moscow';
  v_company record;
  v_snapshot jsonb;
  v_unfilled_count integer;
  v_object_names text;
  v_reminder_key text;
begin
  -- Создаём запись за 5 минут до 12:00, чтобы существующий обработчик
  -- scheduled_reminders успел доставить её ровно к 12:00. Если функция впервые
  -- запустилась позже, просроченное напоминание будет отправлено ближайшим циклом.
  if v_now_local < v_today + time '11:55' then
    return;
  end if;

  for v_company in
    select company.id
    from public.companies company
    where company.status = 'active'
  loop
    v_reminder_key :=
      'admin-timesheet-unfilled:' || v_company.id::text || ':' || v_today::text;

    v_snapshot := private.manager_attendance_snapshot(
      v_company.id,
      null,
      v_today
    );
    v_unfilled_count := coalesce(
      (v_snapshot ->> 'unfilled_objects')::integer,
      0
    );

    if v_unfilled_count = 0 then
      update public.scheduled_reminders reminder
      set status = 'cancelled'
      where reminder.company_id = v_company.id
        and reminder.reminder_key = v_reminder_key
        and reminder.status = 'pending';
      continue;
    end if;

    select string_agg(item ->> 'title', ', ' order by item ->> 'title')
      into v_object_names
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'unfilled_items', '[]'::jsonb)
    ) item;

    insert into public.scheduled_reminders(
      company_id,
      reminder_key,
      entity_type,
      entity_id,
      reminder_type,
      due_at,
      recipient_role,
      title,
      body,
      object_name,
      priority
    ) values (
      v_company.id,
      v_reminder_key,
      'admin_reminder',
      v_company.id,
      'manager_timesheet_unfilled',
      v_due_at,
      'admin',
      'Не заполнен табель',
      format(
        'К 12:00 табель не заполнен по объектам: %s.',
        coalesce(v_object_names, 'не указаны')
      ),
      '',
      'high'
    )
    on conflict (company_id, reminder_key)
    do update
    set due_at = excluded.due_at,
        title = excluded.title,
        body = excluded.body,
        priority = excluded.priority
    where public.scheduled_reminders.status = 'pending';
  end loop;
end;
$$;

create or replace function private.populate_role_operational_reminders()
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  perform private.populate_foreman_configured_reminders();
  perform private.populate_backoffice_configured_reminders();
  perform private.populate_developer_custom_reminders();
  perform private.populate_manager_timesheet_unfilled_reminders();
  perform private.populate_manager_absence_todos();
  perform private.populate_manager_report_todos();
end;
$$;

-- Сразу закрываем старые открытые дела, которые просили «закрыть пропуски».
update public.manager_todos
set status = 'done',
    completed_by = null,
    completed_at = now(),
    metadata = metadata || jsonb_build_object(
      'auto_resolved', true,
      'resolved_reason', 'attendance_semantics_changed',
      'resolved_at', now()
    ),
    updated_at = now()
where source_type = 'manager_report'
  and status = 'open'
  and metadata ->> 'issue_code' = 'attendance_missing';

revoke all on function private.manager_attendance_snapshot(uuid, uuid, date)
  from public, anon, authenticated;
revoke all on function private.populate_manager_absence_todos()
  from public, anon, authenticated;
revoke all on function private.populate_manager_timesheet_unfilled_reminders()
  from public, anon, authenticated;
