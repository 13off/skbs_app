drop function if exists public.get_manager_weekly_team_contribution(uuid);
create function public.get_manager_weekly_team_contribution(
  p_object_id uuid default null
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
  v_today date := public.current_operational_date();
  v_week_end date;
  v_week_start date;
  v_completed_tasks integer := 0;
  v_participants integer := 0;
  v_objects integer := 0;
  v_rows jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not public.is_admin() then
    raise exception 'manager report is not available' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    raise exception 'company is not selected' using errcode = '42501';
  end if;

  if p_object_id is not null and not exists (
    select 1
      from public.objects object_row
     where object_row.id = p_object_id
       and object_row.company_id = v_company_id
  ) then
    raise exception 'object is not available' using errcode = '42501';
  end if;

  -- Отчёт всегда показывает последнюю полностью завершённую неделю:
  -- понедельник — воскресенье. Поэтому цифры остаются неизменными до
  -- следующего понедельника и не превращаются в ещё один ежедневный экран.
  v_week_end := v_today - extract(isodow from v_today)::integer;
  v_week_start := v_week_end - 6;

  with scoped as (
    select contribution.object_id,
           contribution.task_id,
           contribution.employee_id,
           contribution.contribution_percent,
           employee.fio as employee_name,
           employee.position,
           object_row.name as object_name
      from public.task_employee_contributions contribution
      join public.tasks task_row
        on task_row.id = contribution.task_id
       and task_row.company_id = contribution.company_id
      join public.employees employee
        on employee.id = contribution.employee_id
       and employee.company_id = contribution.company_id
      join public.objects object_row
        on object_row.id = contribution.object_id
       and object_row.company_id = contribution.company_id
     where contribution.company_id = v_company_id
       and task_row.status = 'Выполнено'
       and task_row.deleted_at is null
       and task_row.task_date between v_week_start and v_week_end
       and (p_object_id is null or contribution.object_id = p_object_id)
  ),
  object_totals as (
    select scoped.object_id,
           count(distinct scoped.task_id)::integer as task_count
      from scoped
     group by scoped.object_id
  ),
  employee_totals as (
    select scoped.employee_id,
           scoped.employee_name,
           scoped.position,
           scoped.object_id,
           scoped.object_name,
           count(distinct scoped.task_id)::integer as task_count,
           coalesce(sum(scoped.contribution_percent), 0)::integer as total_percent,
           coalesce(round(avg(scoped.contribution_percent)::numeric, 1), 0) as average_percent
      from scoped
     group by scoped.employee_id,
              scoped.employee_name,
              scoped.position,
              scoped.object_id,
              scoped.object_name
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'employee_id', employee_totals.employee_id,
               'employee_name', employee_totals.employee_name,
               'position', employee_totals.position,
               'object_id', employee_totals.object_id,
               'object_name', employee_totals.object_name,
               'task_count', employee_totals.task_count,
               'total_percent', employee_totals.total_percent,
               'equivalent_tasks', round(employee_totals.total_percent::numeric / 100, 2),
               'average_percent', employee_totals.average_percent,
               'team_share_percent', case
                 when object_totals.task_count = 0 then 0
                 else round(employee_totals.total_percent::numeric / object_totals.task_count, 1)
               end
             )
             order by lower(employee_totals.object_name), lower(employee_totals.employee_name)
           ),
           '[]'::jsonb
         )
    into v_rows
    from employee_totals
    join object_totals on object_totals.object_id = employee_totals.object_id;

  select count(distinct contribution.task_id)::integer,
         count(distinct contribution.employee_id)::integer,
         count(distinct contribution.object_id)::integer
    into v_completed_tasks, v_participants, v_objects
    from public.task_employee_contributions contribution
    join public.tasks task_row
      on task_row.id = contribution.task_id
     and task_row.company_id = contribution.company_id
   where contribution.company_id = v_company_id
     and task_row.status = 'Выполнено'
     and task_row.deleted_at is null
     and task_row.task_date between v_week_start and v_week_end
     and (p_object_id is null or contribution.object_id = p_object_id);

  return jsonb_build_object(
    'week_start', v_week_start,
    'week_end', v_week_end,
    'completed_tasks', v_completed_tasks,
    'participants', v_participants,
    'objects_count', v_objects,
    'rows', v_rows
  );
end;
$body$;

revoke all on function public.get_manager_weekly_team_contribution(uuid)
  from public, anon;
grant execute on function public.get_manager_weekly_team_contribution(uuid)
  to authenticated;

comment on function public.get_manager_weekly_team_contribution(uuid) is
  'Недельная сводка личного вклада только для руководителя; показывает последнюю завершённую неделю без отдельной вкладки и без доступа прораба.';
