create or replace function public.get_manager_reports_center(
  p_object_id uuid default null,
  p_report_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_date date := coalesce(p_report_date, current_date);
  v_object_name text := '';
  v_objects jsonb := '[]'::jsonb;
  v_runs jsonb := '[]'::jsonb;
  v_tasks jsonb;
  v_people jsonb;
  v_finance jsonb;
  v_recruitment jsonb;
  v_legal jsonb;
  v_milestones jsonb;
  v_critical integer := 0;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для отчётов руководителя';
  end if;

  if p_object_id is not null then
    select o.name into v_object_name
    from public.objects o
    where o.id = p_object_id
      and o.company_id = v_company_id
      and o.is_active = true;
    if not found then raise exception 'Объект не найден или отключён'; end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'name', o.name,
    'address', coalesce(o.address, '')
  ) order by o.name), '[]'::jsonb)
  into v_objects
  from public.objects o
  where o.company_id = v_company_id and o.is_active = true;

  v_tasks := private.manager_report_tasks(v_company_id, v_object_name, v_date);
  v_people := private.manager_report_people(v_company_id, v_object_name, v_date);
  v_finance := private.manager_report_finance(v_company_id, v_object_name, v_date);
  v_recruitment := private.manager_report_recruitment(v_company_id, p_object_id, v_date);
  v_legal := private.manager_report_legal(v_company_id, p_object_id, v_date);
  v_milestones := private.manager_report_milestones(v_company_id, v_object_name, v_date);

  v_critical :=
    coalesce((v_tasks #>> '{metrics,problem}')::integer, 0) +
    coalesce((v_people #>> '{attendance,missing}')::integer, 0) +
    coalesce((v_finance #>> '{metrics,missing_receipts}')::integer, 0) +
    coalesce((v_legal #>> '{metrics,overdue}')::integer, 0) +
    coalesce((v_legal #>> '{metrics,high_risk}')::integer, 0) +
    coalesce((v_milestones #>> '{metrics,overdue}')::integer, 0);

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc), '[]'::jsonb)
  into v_runs
  from (
    select id, object_id, object_name, summary_date, status, title, body, payload,
           ai_used, error_text, sent_at, attempts, created_at
    from public.dispatcher_summary_runs
    where company_id = v_company_id
      and (p_object_id is null or object_id = p_object_id)
    order by created_at desc
    limit 40
  ) r;

  return jsonb_build_object(
    'report_date', v_date,
    'selected_object', case
      when p_object_id is null then null
      else jsonb_build_object('id', p_object_id, 'name', v_object_name)
    end,
    'objects', v_objects,
    'metrics', jsonb_build_object(
      'critical_count', v_critical,
      'tasks', v_tasks -> 'metrics',
      'attendance', v_people -> 'attendance',
      'employees', v_people -> 'employees',
      'payments', v_finance -> 'metrics',
      'recruitment', v_recruitment,
      'legal', v_legal -> 'metrics',
      'milestones', v_milestones -> 'metrics'
    ),
    'trend', jsonb_build_object(
      'tasks_done_rate', v_tasks #> '{trend,done_rate}',
      'tasks_yesterday_done_rate', v_tasks #> '{trend,yesterday_done_rate}',
      'tasks_week_done_rate', v_tasks #> '{trend,week_done_rate}',
      'attendance_missing_yesterday', v_people #> '{trend,attendance_missing_yesterday}'
    ),
    'details', jsonb_build_object(
      'pending_tasks', v_tasks -> 'pending_items',
      'missing_attendance', v_people -> 'missing_items',
      'missing_receipts', v_finance -> 'missing_items',
      'legal_attention', v_legal -> 'attention_items',
      'milestones_attention', v_milestones -> 'attention_items'
    ),
    'dispatcher_runs', v_runs,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.get_manager_reports_center(uuid,date) from public, anon;
grant execute on function public.get_manager_reports_center(uuid,date) to authenticated;
