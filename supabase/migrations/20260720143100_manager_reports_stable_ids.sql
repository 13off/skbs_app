create or replace function private.manager_report_tasks_v2(
  p_company_id uuid,
  p_object_id uuid,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with today as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done,
    count(*) filter (
      where btrim(coalesce(t.not_done_comment, '')) <> ''
    )::integer as problem
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), yesterday as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date - 1
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), week_data as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date between p_report_date - 6 and p_report_date
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), pending as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'title', coalesce(nullif(btrim(t.work), ''), 'Задача'),
    'subtitle', concat_ws(
      ' · ',
      nullif(btrim(coalesce(t.axes, '')), ''),
      nullif(btrim(coalesce(t.status, '')), '')
    ),
    'note', btrim(coalesce(t.not_done_comment, ''))
  ) order by t.work, t.id), '[]'::jsonb) as items
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date
    and not coalesce(t.is_draft, false)
    and lower(coalesce(t.status, '')) not in
      ('выполнено','готово','completed','done')
    and (p_object_id is null or t.object_id = p_object_id)
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'total', today.total,
    'done', today.done,
    'pending', today.total - today.done,
    'problem', today.problem
  ),
  'trend', jsonb_build_object(
    'done_rate', case
      when today.total = 0 then 0
      else round(today.done::numeric * 100 / today.total, 1)
    end,
    'yesterday_done_rate', case
      when yesterday.total = 0 then 0
      else round(yesterday.done::numeric * 100 / yesterday.total, 1)
    end,
    'week_done_rate', case
      when week_data.total = 0 then 0
      else round(week_data.done::numeric * 100 / week_data.total, 1)
    end
  ),
  'pending_items', pending.items
)
from today, yesterday, week_data, pending;
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
set search_path = public, pg_temp
as $$
with employee_rows as (
  select e.*
  from public.employees e
  where e.company_id = p_company_id
    and (p_object_id is null or e.object_id = p_object_id)
), today_candidates as (
  select
    e.*,
    exists (
      select 1
      from public.attendance fact
      where fact.company_id = e.company_id
        and fact.employee_id = e.id
        and fact.work_date = p_report_date
        and (p_object_id is null or fact.object_id = p_object_id)
    ) as has_attendance
  from employee_rows e
  where (
    p_report_date >= current_date
    and e.is_active = true
    and e.archived_at is null
  ) or (
    p_report_date < current_date
    and (
      exists (
        select 1
        from public.attendance fact
        where fact.company_id = e.company_id
          and fact.employee_id = e.id
          and fact.work_date = p_report_date
          and (p_object_id is null or fact.object_id = p_object_id)
      )
      or (
        e.created_at::date <= p_report_date
        and (
          e.is_active = true
          or coalesce(e.archived_at::date, e.updated_at::date) > p_report_date
        )
      )
    )
  )
), effective_today as (
  select distinct on (e.person_id) e.*
  from today_candidates e
  order by
    e.person_id,
    e.has_attendance desc,
    e.created_at desc,
    e.id
), yesterday_candidates as (
  select
    e.*,
    exists (
      select 1
      from public.attendance fact
      where fact.company_id = e.company_id
        and fact.employee_id = e.id
        and fact.work_date = p_report_date - 1
        and (p_object_id is null or fact.object_id = p_object_id)
    ) as has_attendance
  from employee_rows e
  where exists (
    select 1
    from public.attendance fact
    where fact.company_id = e.company_id
      and fact.employee_id = e.id
      and fact.work_date = p_report_date - 1
      and (p_object_id is null or fact.object_id = p_object_id)
  ) or (
    e.created_at::date <= p_report_date - 1
    and (
      e.is_active = true
      or coalesce(e.archived_at::date, e.updated_at::date) > p_report_date - 1
    )
  )
), effective_yesterday as (
  select distinct on (e.person_id) e.*
  from yesterday_candidates e
  order by
    e.person_id,
    e.has_attendance desc,
    e.created_at desc,
    e.id
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
), attendance as (
  select
    count(distinct e.person_id)::integer as marked,
    coalesce(sum(a.shifts), 0) as shifts
  from public.attendance a
  join public.employees e
    on e.id = a.employee_id
   and e.company_id = a.company_id
  where a.company_id = p_company_id
    and a.work_date = p_report_date
    and (p_object_id is null or a.object_id = p_object_id)
), missing_today as (
  select
    count(*)::integer as count,
    coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id,
      'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
      'subtitle', btrim(coalesce(e.position, '')),
      'note', 'Нет отметки в табеле'
    ) order by e.fio, e.id), '[]'::jsonb) as items
  from effective_today e
  where p_report_date <= current_date
    and not exists (
      select 1
      from public.attendance a
      join public.employees attendance_employee
        on attendance_employee.id = a.employee_id
       and attendance_employee.company_id = a.company_id
      where a.company_id = e.company_id
        and attendance_employee.person_id = e.person_id
        and a.work_date = p_report_date
        and (p_object_id is null or a.object_id = p_object_id)
    )
), missing_yesterday as (
  select count(*)::integer as count
  from effective_yesterday e
  where p_report_date - 1 <= current_date
    and not exists (
      select 1
      from public.attendance a
      join public.employees attendance_employee
        on attendance_employee.id = a.employee_id
       and attendance_employee.company_id = a.company_id
      where a.company_id = e.company_id
        and attendance_employee.person_id = e.person_id
        and a.work_date = p_report_date - 1
        and (p_object_id is null or a.object_id = p_object_id)
    )
)
select jsonb_build_object(
  'employees', jsonb_build_object(
    'active', (select count(*) from effective_today),
    'added', added_people.count,
    'archived', departed_people.count,
    'historical_estimate', p_report_date < current_date
  ),
  'attendance', jsonb_build_object(
    'active', (select count(*) from effective_today),
    'marked', attendance.marked,
    'missing', missing_today.count,
    'shifts', attendance.shifts,
    'historical_estimate', p_report_date < current_date
  ),
  'trend', jsonb_build_object(
    'attendance_missing_yesterday', missing_yesterday.count
  ),
  'missing_items', missing_today.items
)
from added_people, departed_people, attendance, missing_today, missing_yesterday;
$$;

create or replace function private.manager_report_finance_v2(
  p_company_id uuid,
  p_object_id uuid,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with payments as (
  select
    count(*)::integer as month_count,
    coalesce(sum(p.amount), 0) as month_amount,
    count(*) filter (
      where p.payment_date = p_report_date
    )::integer as day_count,
    count(*) filter (
      where p.payment_date = p_report_date
        and not exists (
          select 1
          from public.payment_receipts receipt
          where receipt.company_id = p.company_id
            and receipt.payment_id = p.id
        )
    )::integer as day_missing_receipts,
    count(*) filter (
      where not exists (
        select 1
        from public.payment_receipts receipt
        where receipt.company_id = p.company_id
          and receipt.payment_id = p.id
      )
    )::integer as month_missing_receipts
  from public.payments p
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (p_object_id is null or p.object_id = p_object_id)
), missing as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00'))
      || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(
      ' · ',
      nullif(btrim(coalesce(p.payment_type, '')), ''),
      nullif(btrim(coalesce(p.comment, '')), '')
    )
  ) order by p.payment_date desc, e.fio), '[]'::jsonb) as items
  from public.payments p
  join public.employees e
    on e.id = p.employee_id
   and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and p.payment_date = p_report_date
    and (p_object_id is null or p.object_id = p_object_id)
    and not exists (
      select 1
      from public.payment_receipts receipt
      where receipt.company_id = p.company_id
        and receipt.payment_id = p.id
    )
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'month_count', payments.month_count,
    'month_amount', payments.month_amount,
    'day_count', payments.day_count,
    'missing_receipts', payments.day_missing_receipts,
    'missing_receipts_day', payments.day_missing_receipts,
    'missing_receipts_month', payments.month_missing_receipts
  ),
  'missing_items', missing.items
)
from payments, missing;
$$;

create or replace function private.manager_report_milestones_v2(
  p_company_id uuid,
  p_object_id uuid,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with metrics as (
  select
    count(*) filter (
      where lower(coalesce(m.status, '')) not in
        ('выполнено','закрыто','completed','closed')
    )::integer as open_count,
    count(*) filter (
      where lower(coalesce(m.status, '')) not in
        ('выполнено','закрыто','completed','closed')
        and m.target_date < p_report_date
    )::integer as overdue,
    count(*) filter (
      where lower(coalesce(m.status, '')) not in
        ('выполнено','закрыто','completed','closed')
        and m.target_date between p_report_date and p_report_date + 7
    )::integer as upcoming
  from public.project_milestones m
  where m.company_id = p_company_id
    and (p_object_id is null or m.object_id = p_object_id)
), attention as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'title', coalesce(nullif(btrim(m.title), ''), 'Этап'),
    'subtitle', concat_ws(
      ' · ',
      nullif(btrim(coalesce(m.location, '')), ''),
      'срок ' || to_char(m.target_date, 'DD.MM.YYYY')
    ),
    'note', btrim(coalesce(m.notes, ''))
  ) order by m.target_date, m.title), '[]'::jsonb) as items
  from public.project_milestones m
  where m.company_id = p_company_id
    and lower(coalesce(m.status, '')) not in
      ('выполнено','закрыто','completed','closed')
    and m.target_date <= p_report_date + 7
    and (p_object_id is null or m.object_id = p_object_id)
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'open', metrics.open_count,
    'overdue', metrics.overdue,
    'upcoming', metrics.upcoming
  ),
  'attention_items', attention.items
)
from metrics, attention;
$$;

revoke all on function private.manager_report_tasks_v2(uuid,uuid,date)
  from public, anon, authenticated;
revoke all on function private.manager_report_people_v2(uuid,uuid,date)
  from public, anon, authenticated;
revoke all on function private.manager_report_finance_v2(uuid,uuid,date)
  from public, anon, authenticated;
revoke all on function private.manager_report_milestones_v2(uuid,uuid,date)
  from public, anon, authenticated;

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
  v_attention integer := 0;
begin
  if auth.uid() is null
    or v_company_id is null
    or not public.is_admin()
  then
    raise exception 'Недостаточно прав для отчётов руководителя';
  end if;

  if p_object_id is not null then
    select o.name
      into v_object_name
    from public.objects o
    where o.id = p_object_id
      and o.company_id = v_company_id
      and o.is_active = true;

    if not found then
      raise exception 'Объект не найден или отключён';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'name', o.name,
    'address', coalesce(o.address, '')
  ) order by o.name), '[]'::jsonb)
  into v_objects
  from public.objects o
  where o.company_id = v_company_id
    and o.is_active = true;

  v_tasks := private.manager_report_tasks_v2(
    v_company_id, p_object_id, v_date
  );
  v_people := private.manager_report_people_v2(
    v_company_id, p_object_id, v_date
  );
  v_finance := private.manager_report_finance_v2(
    v_company_id, p_object_id, v_date
  );
  v_recruitment := private.manager_report_recruitment(
    v_company_id, p_object_id, v_date
  );
  v_legal := private.manager_report_legal(
    v_company_id, p_object_id, v_date
  );
  v_milestones := private.manager_report_milestones_v2(
    v_company_id, p_object_id, v_date
  );

  v_critical :=
    coalesce((v_tasks #>> '{metrics,problem}')::integer, 0)
    + coalesce((v_people #>> '{attendance,missing}')::integer, 0)
    + coalesce((v_finance #>> '{metrics,missing_receipts_day}')::integer, 0)
    + coalesce((v_legal #>> '{metrics,overdue}')::integer, 0)
    + coalesce((v_legal #>> '{metrics,high_risk}')::integer, 0)
    + coalesce((v_milestones #>> '{metrics,overdue}')::integer, 0);

  v_attention :=
    greatest(
      coalesce((v_tasks #>> '{metrics,pending}')::integer, 0)
        - coalesce((v_tasks #>> '{metrics,problem}')::integer, 0),
      0
    )
    + greatest(
      coalesce((v_finance #>> '{metrics,missing_receipts_month}')::integer, 0)
        - coalesce((v_finance #>> '{metrics,missing_receipts_day}')::integer, 0),
      0
    )
    + coalesce((v_legal #>> '{metrics,expiring_documents}')::integer, 0)
    + coalesce((v_milestones #>> '{metrics,upcoming}')::integer, 0);

  select coalesce(
    jsonb_agg(to_jsonb(r) order by r.created_at desc),
    '[]'::jsonb
  )
  into v_runs
  from (
    select
      id,
      object_id,
      object_name,
      summary_date,
      status,
      title,
      body,
      payload,
      ai_used,
      error_text,
      sent_at,
      attempts,
      created_at
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
      else jsonb_build_object(
        'id', p_object_id,
        'name', v_object_name
      )
    end,
    'objects', v_objects,
    'metrics', jsonb_build_object(
      'critical_count', v_critical,
      'attention_count', v_attention,
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
      'tasks_yesterday_done_rate',
        v_tasks #> '{trend,yesterday_done_rate}',
      'tasks_week_done_rate', v_tasks #> '{trend,week_done_rate}',
      'attendance_missing_yesterday',
        v_people #> '{trend,attendance_missing_yesterday}'
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

revoke all on function public.get_manager_reports_center(uuid,date)
  from public, anon;
grant execute on function public.get_manager_reports_center(uuid,date)
  to authenticated;
