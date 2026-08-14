-- AppСтрой: лёгкие дела руководителя + автоматическое дело по подтверждённым невыходам.
-- Автоматическое дело создаётся только по attendance.status = 'no_show',
-- а не по отсутствующей отметке табеля.

create table if not exists public.manager_todos (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  title text not null,
  body text not null default '',
  status text not null default 'open'
    check (status in ('open', 'done', 'cancelled')),
  due_at timestamptz,
  reminder_at timestamptz,
  priority text not null default 'normal'
    check (priority in ('normal', 'high', 'critical')),
  source_type text not null default 'manual',
  source_key text,
  source_date date,
  metadata jsonb not null default '{}'::jsonb,
  recipient_user_id uuid references auth.users(id) on delete set null,
  target_role text not null default 'admin',
  created_by uuid references auth.users(id) on delete set null,
  completed_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists manager_todos_source_key_uidx
  on public.manager_todos(company_id, source_type, source_key)
  where source_key is not null;

create index if not exists manager_todos_open_idx
  on public.manager_todos(company_id, status, created_at desc);

create index if not exists manager_todos_due_idx
  on public.manager_todos(company_id, reminder_at)
  where status = 'open' and reminder_at is not null;

alter table public.manager_todos enable row level security;

create or replace function private.sync_manager_todo_reminder()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $$
declare
  v_key text := 'manager-todo:' || new.id::text;
begin
  if new.status = 'open' and new.reminder_at is not null then
    insert into public.scheduled_reminders(
      company_id,
      reminder_key,
      entity_type,
      entity_id,
      reminder_type,
      due_at,
      recipient_user_id,
      recipient_role,
      status,
      title,
      body,
      object_name,
      priority,
      in_app_enabled,
      push_enabled
    ) values (
      new.company_id,
      v_key,
      'manager_todo',
      new.id,
      'manager_todo_due',
      new.reminder_at,
      new.recipient_user_id,
      new.target_role,
      'pending',
      new.title,
      new.body,
      '',
      new.priority,
      true,
      true
    )
    on conflict (company_id, reminder_key) do update
    set due_at = excluded.due_at,
        recipient_user_id = excluded.recipient_user_id,
        recipient_role = excluded.recipient_role,
        status = case
          when public.scheduled_reminders.status = 'sent'
               and public.scheduled_reminders.due_at = excluded.due_at
            then 'sent'
          else 'pending'
        end,
        title = excluded.title,
        body = excluded.body,
        priority = excluded.priority,
        notification_id = case
          when public.scheduled_reminders.status = 'sent'
               and public.scheduled_reminders.due_at = excluded.due_at
            then public.scheduled_reminders.notification_id
          else null
        end,
        sent_at = case
          when public.scheduled_reminders.status = 'sent'
               and public.scheduled_reminders.due_at = excluded.due_at
            then public.scheduled_reminders.sent_at
          else null
        end;
  else
    update public.scheduled_reminders
    set status = case when status = 'sent' then status else 'cancelled' end
    where company_id = new.company_id
      and reminder_key = v_key;
  end if;

  return new;
end;
$$;

drop trigger if exists manager_todos_sync_reminder on public.manager_todos;
create trigger manager_todos_sync_reminder
after insert or update of title, body, status, reminder_at, priority,
  recipient_user_id, target_role
on public.manager_todos
for each row execute function private.sync_manager_todo_reminder();

create or replace function public.get_my_manager_todos(
  p_include_done boolean default false,
  p_limit integer default 80
)
returns table(
  id uuid,
  title text,
  body text,
  status text,
  due_at timestamptz,
  reminder_at timestamptz,
  priority text,
  source_type text,
  source_date date,
  metadata jsonb,
  created_at timestamptz,
  completed_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Дела доступны только руководителю';
  end if;

  return query
  select
    todo.id,
    todo.title,
    todo.body,
    todo.status,
    todo.due_at,
    todo.reminder_at,
    todo.priority,
    todo.source_type,
    todo.source_date,
    todo.metadata,
    todo.created_at,
    todo.completed_at
  from public.manager_todos todo
  where todo.company_id = v_company_id
    and todo.status <> 'cancelled'
    and (coalesce(p_include_done, false) or todo.status = 'open')
  order by
    case when todo.status = 'open' then 0 else 1 end,
    coalesce(todo.reminder_at, todo.due_at, todo.created_at),
    todo.created_at desc
  limit least(greatest(coalesce(p_limit, 80), 1), 200);
end;
$$;

create or replace function public.create_manager_todo(
  p_title text,
  p_body text default '',
  p_reminder_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Дела доступны только руководителю';
  end if;
  if char_length(v_title) not between 1 and 300 then
    raise exception 'Введите название дела';
  end if;

  insert into public.manager_todos(
    company_id, title, body, due_at, reminder_at, priority,
    source_type, recipient_user_id, target_role, created_by
  ) values (
    v_company_id,
    v_title,
    left(btrim(coalesce(p_body, '')), 4000),
    p_reminder_at,
    p_reminder_at,
    'normal',
    'manual',
    auth.uid(),
    'admin',
    auth.uid()
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.set_manager_todo_done(
  p_todo_id uuid,
  p_done boolean default true
)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Дела доступны только руководителю';
  end if;

  update public.manager_todos
  set status = case when coalesce(p_done, true) then 'done' else 'open' end,
      completed_by = case when coalesce(p_done, true) then auth.uid() else null end,
      completed_at = case when coalesce(p_done, true) then now() else null end,
      updated_at = now()
  where id = p_todo_id
    and company_id = v_company_id
    and status <> 'cancelled';

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

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
        jsonb_build_object('employee_id', employee_id, 'name', employee_name)
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
      'За %s отсутствовали: %s',
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
      'employees', grouped.employees
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

create or replace function private.populate_role_operational_reminders()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  perform private.populate_foreman_configured_reminders();
  perform private.populate_backoffice_configured_reminders();
  perform private.populate_developer_custom_reminders();
  perform private.populate_manager_absence_todos();
end;
$$;

revoke all on public.manager_todos from anon, authenticated;
revoke all on function public.get_my_manager_todos(boolean, integer) from public;
revoke all on function public.create_manager_todo(text, text, timestamptz) from public;
revoke all on function public.set_manager_todo_done(uuid, boolean) from public;

grant execute on function public.get_my_manager_todos(boolean, integer) to authenticated;
grant execute on function public.create_manager_todo(text, text, timestamptz) to authenticated;
grant execute on function public.set_manager_todo_done(uuid, boolean) to authenticated;
