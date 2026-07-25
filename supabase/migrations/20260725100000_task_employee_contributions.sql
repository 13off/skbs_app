create table if not exists public.task_employee_contributions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  contribution_percent integer not null check (contribution_percent between 0 and 100),
  recorded_by uuid references auth.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  unique (task_id, employee_id)
);

create index if not exists task_employee_contributions_employee_date_idx
  on public.task_employee_contributions(employee_id, recorded_at desc);
create index if not exists task_employee_contributions_object_task_idx
  on public.task_employee_contributions(object_id, task_id);
create index if not exists task_employee_contributions_company_idx
  on public.task_employee_contributions(company_id);

alter table public.task_employee_contributions enable row level security;

revoke all on table public.task_employee_contributions from public, anon, authenticated;

drop function if exists public.get_task_contributions(uuid);
create function public.get_task_contributions(p_task_id uuid)
returns table (
  employee_id uuid,
  contribution_percent integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $body$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_task_company_id uuid;
  v_object_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  select task_row.company_id, task_row.object_id
    into v_task_company_id, v_object_id
    from public.tasks task_row
   where task_row.id = p_task_id
     and task_row.deleted_at is null;

  if v_task_company_id is null or v_task_company_id <> v_company_id then
    raise exception 'task is not available' using errcode = '42501';
  end if;
  if not public.current_user_has_object_scope(v_object_id)
     or not public.current_user_has_object_permission('tasks.view', v_object_id) then
    raise exception 'task is not available' using errcode = '42501';
  end if;

  return query
  select contribution.employee_id, contribution.contribution_percent
    from public.task_employee_contributions contribution
   where contribution.task_id = p_task_id
   order by contribution.recorded_at, contribution.employee_id;
end;
$body$;

revoke all on function public.get_task_contributions(uuid) from public, anon;
grant execute on function public.get_task_contributions(uuid) to authenticated;

drop function if exists public.save_task_contributions(uuid, jsonb);
create function public.save_task_contributions(
  p_task_id uuid,
  p_contributions jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $body$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_task_company_id uuid;
  v_object_id uuid;
  v_status text;
  v_assignee_count integer;
  v_json_count integer;
  v_distinct_count integer;
  v_total integer;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_contributions) <> 'array' then
    raise exception 'contributions must be an array';
  end if;

  v_company_id := public.current_user_company_id();
  select task_row.company_id, task_row.object_id, task_row.status
    into v_task_company_id, v_object_id, v_status
    from public.tasks task_row
   where task_row.id = p_task_id
     and task_row.deleted_at is null
   for update;

  if v_task_company_id is null or v_task_company_id <> v_company_id then
    raise exception 'task is not available' using errcode = '42501';
  end if;
  if not public.current_user_has_object_scope(v_object_id)
     or not public.current_user_has_object_permission('tasks.edit', v_object_id) then
    raise exception 'task edit is not allowed' using errcode = '42501';
  end if;
  if v_status <> 'Выполнено' then
    raise exception 'contributions are saved only for completed tasks';
  end if;

  select count(*) into v_assignee_count
    from public.task_assignees assignee
   where assignee.task_id = p_task_id;
  if v_assignee_count = 0 then
    raise exception 'completed task has no participants';
  end if;

  v_json_count := jsonb_array_length(p_contributions);
  select count(distinct (item ->> 'employee_id')::uuid),
         coalesce(sum((item ->> 'percent')::integer), 0)
    into v_distinct_count, v_total
    from jsonb_array_elements(p_contributions) item;

  if v_json_count <> v_assignee_count or v_distinct_count <> v_assignee_count then
    raise exception 'contributions must contain every participant exactly once';
  end if;
  if v_total <> 100 then
    raise exception 'contribution total must equal 100';
  end if;
  if exists (
    select 1
      from jsonb_array_elements(p_contributions) item
     where (item ->> 'percent')::integer not between 0 and 100
  ) then
    raise exception 'contribution percent is outside 0..100';
  end if;
  if exists (
    select 1
      from jsonb_array_elements(p_contributions) item
     where not exists (
       select 1
         from public.task_assignees assignee
        where assignee.task_id = p_task_id
          and assignee.employee_id = (item ->> 'employee_id')::uuid
     )
  ) then
    raise exception 'contribution contains a non-participant';
  end if;
  if exists (
    select 1
      from public.task_assignees assignee
     where assignee.task_id = p_task_id
       and not exists (
         select 1
           from jsonb_array_elements(p_contributions) item
          where (item ->> 'employee_id')::uuid = assignee.employee_id
       )
  ) then
    raise exception 'a task participant is missing';
  end if;

  delete from public.task_employee_contributions
   where task_id = p_task_id;

  insert into public.task_employee_contributions (
    company_id,
    object_id,
    task_id,
    employee_id,
    contribution_percent,
    recorded_by,
    recorded_at
  )
  select v_company_id,
         v_object_id,
         p_task_id,
         (item ->> 'employee_id')::uuid,
         (item ->> 'percent')::integer,
         v_user_id,
         now()
    from jsonb_array_elements(p_contributions) item;
end;
$body$;

revoke all on function public.save_task_contributions(uuid, jsonb) from public, anon;
grant execute on function public.save_task_contributions(uuid, jsonb) to authenticated;

drop function if exists public.clear_task_contributions(uuid);
create function public.clear_task_contributions(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $body$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_task_company_id uuid;
  v_object_id uuid;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  select task_row.company_id, task_row.object_id
    into v_task_company_id, v_object_id
    from public.tasks task_row
   where task_row.id = p_task_id
     and task_row.deleted_at is null;

  if v_task_company_id is null or v_task_company_id <> v_company_id then
    raise exception 'task is not available' using errcode = '42501';
  end if;
  if not public.current_user_has_object_scope(v_object_id)
     or not public.current_user_has_object_permission('tasks.edit', v_object_id) then
    raise exception 'task edit is not allowed' using errcode = '42501';
  end if;

  delete from public.task_employee_contributions
   where task_id = p_task_id;
end;
$body$;

revoke all on function public.clear_task_contributions(uuid) from public, anon;
grant execute on function public.clear_task_contributions(uuid) to authenticated;

drop function if exists public.get_employee_contribution_summary(uuid, date, date);
create function public.get_employee_contribution_summary(
  p_employee_id uuid,
  p_date_from date default null,
  p_date_to date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $body$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_employee_company_id uuid;
  v_object_id uuid;
  v_task_count integer := 0;
  v_total_percent integer := 0;
  v_average_percent numeric := 0;
  v_object_task_count integer := 0;
  v_history jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_date_from is not null and p_date_to is not null and p_date_from > p_date_to then
    raise exception 'invalid contribution date range';
  end if;

  v_company_id := public.current_user_company_id();
  select employee.company_id, employee.object_id
    into v_employee_company_id, v_object_id
    from public.employees employee
   where employee.id = p_employee_id;

  if v_employee_company_id is null or v_employee_company_id <> v_company_id then
    raise exception 'employee is not available' using errcode = '42501';
  end if;
  if not public.current_user_has_object_scope(v_object_id)
     or not public.current_user_has_object_permission('employees.view', v_object_id) then
    raise exception 'employee is not available' using errcode = '42501';
  end if;

  select count(*),
         coalesce(sum(contribution.contribution_percent), 0),
         coalesce(round(avg(contribution.contribution_percent)::numeric, 1), 0),
         coalesce(
           jsonb_agg(
             jsonb_build_object(
               'task_id', task_row.id,
               'task_date', task_row.task_date,
               'object_name', task_row.object_name,
               'axes', task_row.axes,
               'work', task_row.work,
               'percent', contribution.contribution_percent,
               'recorded_at', contribution.recorded_at
             )
             order by task_row.task_date desc, contribution.recorded_at desc
           ),
           '[]'::jsonb
         )
    into v_task_count, v_total_percent, v_average_percent, v_history
    from public.task_employee_contributions contribution
    join public.tasks task_row on task_row.id = contribution.task_id
   where contribution.employee_id = p_employee_id
     and contribution.company_id = v_company_id
     and contribution.object_id = v_object_id
     and task_row.status = 'Выполнено'
     and task_row.deleted_at is null
     and (p_date_from is null or task_row.task_date >= p_date_from)
     and (p_date_to is null or task_row.task_date <= p_date_to);

  select count(distinct contribution.task_id)
    into v_object_task_count
    from public.task_employee_contributions contribution
    join public.tasks task_row on task_row.id = contribution.task_id
   where contribution.company_id = v_company_id
     and contribution.object_id = v_object_id
     and task_row.status = 'Выполнено'
     and task_row.deleted_at is null
     and (p_date_from is null or task_row.task_date >= p_date_from)
     and (p_date_to is null or task_row.task_date <= p_date_to);

  return jsonb_build_object(
    'task_count', v_task_count,
    'total_percent', v_total_percent,
    'equivalent_tasks', round(v_total_percent::numeric / 100, 2),
    'average_percent', v_average_percent,
    'object_task_count', v_object_task_count,
    'object_share_percent', case
      when v_object_task_count = 0 then 0
      else round(v_total_percent::numeric / v_object_task_count, 1)
    end,
    'history', v_history
  );
end;
$body$;

revoke all on function public.get_employee_contribution_summary(uuid, date, date)
  from public, anon;
grant execute on function public.get_employee_contribution_summary(uuid, date, date)
  to authenticated;

comment on table public.task_employee_contributions is
  'Доли личного вклада назначенных участников в результат завершённой задачи; сумма по задаче всегда 100%.';
