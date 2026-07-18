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
  v_report_date date := coalesce(p_report_date, current_date);
  v_object_name text := '';
  v_objects jsonb := '[]'::jsonb;
  v_dispatcher_runs jsonb := '[]'::jsonb;
  v_tasks_total integer := 0;
  v_tasks_done integer := 0;
  v_tasks_problem integer := 0;
  v_tasks_yesterday_total integer := 0;
  v_tasks_yesterday_done integer := 0;
  v_tasks_week_total integer := 0;
  v_tasks_week_done integer := 0;
  v_active_employees integer := 0;
  v_added_employees integer := 0;
  v_archived_employees integer := 0;
  v_attendance_marked integer := 0;
  v_attendance_missing integer := 0;
  v_attendance_yesterday_missing integer := 0;
  v_total_shifts numeric := 0;
  v_payments_month_count integer := 0;
  v_payments_month_amount numeric := 0;
  v_payments_day_count integer := 0;
  v_payments_missing_receipts integer := 0;
  v_recruitment_active integer := 0;
  v_recruitment_new integer := 0;
  v_recruitment_messages integer := 0;
  v_legal_open integer := 0;
  v_legal_overdue integer := 0;
  v_legal_high integer := 0;
  v_documents_expiring integer := 0;
  v_milestones_open integer := 0;
  v_milestones_overdue integer := 0;
  v_milestones_upcoming integer := 0;
  v_critical integer := 0;
  v_pending_tasks jsonb := '[]'::jsonb;
  v_missing_attendance_items jsonb := '[]'::jsonb;
  v_missing_receipt_items jsonb := '[]'::jsonb;
  v_legal_items jsonb := '[]'::jsonb;
  v_milestone_items jsonb := '[]'::jsonb;
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
    if not found then
      raise exception 'Объект не найден или отключён';
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', o.id, 'name', o.name, 'address', coalesce(o.address, ''))
      order by o.name
    ),
    '[]'::jsonb
  ) into v_objects
  from public.objects o
  where o.company_id = v_company_id and o.is_active = true;

  select count(*)::integer,
         count(*) filter (where lower(coalesce(t.status, '')) in ('выполнено','готово','completed','done'))::integer,
         count(*) filter (where btrim(coalesce(t.not_done_comment, '')) <> '')::integer
  into v_tasks_total, v_tasks_done, v_tasks_problem
  from public.tasks t
  where t.company_id = v_company_id
    and t.task_date = v_report_date
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or lower(btrim(coalesce(t.object_name, ''))) = lower(btrim(v_object_name)));

  select count(*)::integer,
         count(*) filter (where lower(coalesce(t.status, '')) in ('выполнено','готово','completed','done'))::integer
  into v_tasks_yesterday_total, v_tasks_yesterday_done
  from public.tasks t
  where t.company_id = v_company_id
    and t.task_date = v_report_date - 1
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or lower(btrim(coalesce(t.object_name, ''))) = lower(btrim(v_object_name)));

  select count(*)::integer,
         count(*) filter (where lower(coalesce(t.status, '')) in ('выполнено','готово','completed','done'))::integer
  into v_tasks_week_total, v_tasks_week_done
  from public.tasks t
  where t.company_id = v_company_id
    and t.task_date between v_report_date - 6 and v_report_date
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or lower(btrim(coalesce(t.object_name, ''))) = lower(btrim(v_object_name)));

  select count(*)::integer,
         count(*) filter (where e.created_at::date = v_report_date)::integer,
         count(*) filter (where e.archived_at::date = v_report_date)::integer
  into v_active_employees, v_added_employees, v_archived_employees
  from public.employees e
  where e.company_id = v_company_id
    and e.is_active = true
    and e.archived_at is null
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)));

  select count(distinct a.employee_id)::integer, coalesce(sum(a.shifts), 0)
  into v_attendance_marked, v_total_shifts
  from public.attendance a
  where a.company_id = v_company_id
    and a.work_date = v_report_date
    and (p_object_id is null or lower(btrim(coalesce(a.object_name, ''))) = lower(btrim(v_object_name)));

  select count(*)::integer into v_attendance_missing
  from public.employees e
  where e.company_id = v_company_id
    and e.is_active = true and e.archived_at is null
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)))
    and not exists (
      select 1 from public.attendance a
      where a.company_id = e.company_id and a.employee_id = e.id and a.work_date = v_report_date
    );

  select count(*)::integer into v_attendance_yesterday_missing
  from public.employees e
  where e.company_id = v_company_id
    and e.is_active = true and e.archived_at is null
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)))
    and not exists (
      select 1 from public.attendance a
      where a.company_id = e.company_id and a.employee_id = e.id and a.work_date = v_report_date - 1
    );

  select count(*)::integer,
         coalesce(sum(p.amount), 0),
         count(*) filter (where p.payment_date = v_report_date)::integer,
         count(*) filter (where not exists (
           select 1 from public.payment_receipts receipt
           where receipt.company_id = p.company_id and receipt.payment_id = p.id
         ))::integer
  into v_payments_month_count, v_payments_month_amount, v_payments_day_count, v_payments_missing_receipts
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = v_company_id
    and p.period_year = extract(year from v_report_date)::integer
    and p.period_month = extract(month from v_report_date)::integer
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)));

  select count(*) filter (
           where a.archived_at is null
             and lower(coalesce(a.status, '')) not in ('принят','отказ','отклонён','архив','hired','rejected','reserve')
         )::integer,
         count(*) filter (where a.archived_at is null and a.created_at::date = v_report_date)::integer
  into v_recruitment_active, v_recruitment_new
  from public.recruitment_applications a
  where a.company_id = v_company_id
    and (p_object_id is null or a.object_id = p_object_id);

  select count(*)::integer into v_recruitment_messages
  from public.recruitment_messages m
  join public.recruitment_applications a on a.id = m.application_id and a.company_id = m.company_id
  where m.company_id = v_company_id
    and m.direction = 'incoming'
    and m.created_at::date = v_report_date
    and (p_object_id is null or a.object_id = p_object_id);

  select count(*) filter (
           where m.resolved_at is null
             and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
         )::integer,
         count(*) filter (
           where m.resolved_at is null and m.due_at < v_report_date::timestamp
             and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
         )::integer,
         count(*) filter (
           where m.resolved_at is null
             and lower(coalesce(m.risk_level, '')) in ('высокий','критический','high','critical')
         )::integer
  into v_legal_open, v_legal_overdue, v_legal_high
  from public.legal_matters m
  where m.company_id = v_company_id
    and (p_object_id is null or m.object_id = p_object_id);

  select count(*)::integer into v_documents_expiring
  from public.legal_documents d
  where d.company_id = v_company_id
    and d.archived_at is null
    and d.expires_on between v_report_date and v_report_date + 7
    and (p_object_id is null or d.object_id = p_object_id);

  select count(*) filter (
           where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
         )::integer,
         count(*) filter (
           where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
             and m.target_date < v_report_date
         )::integer,
         count(*) filter (
           where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
             and m.target_date between v_report_date and v_report_date + 7
         )::integer
  into v_milestones_open, v_milestones_overdue, v_milestones_upcoming
  from public.project_milestones m
  where m.company_id = v_company_id
    and (p_object_id is null or lower(btrim(coalesce(m.object_name, ''))) = lower(btrim(v_object_name)));

  v_critical := v_tasks_problem + v_attendance_missing + v_payments_missing_receipts
    + v_legal_overdue + v_legal_high + v_milestones_overdue;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id, 'title', coalesce(nullif(btrim(t.work), ''), 'Задача'),
    'subtitle', concat_ws(' · ', nullif(btrim(coalesce(t.axes, '')), ''), nullif(btrim(coalesce(t.status, '')), '')),
    'note', btrim(coalesce(t.not_done_comment, ''))
  ) order by t.work, t.id), '[]'::jsonb)
  into v_pending_tasks
  from public.tasks t
  where t.company_id = v_company_id and t.task_date = v_report_date and not coalesce(t.is_draft, false)
    and lower(coalesce(t.status, '')) not in ('выполнено','готово','completed','done')
    and (p_object_id is null or lower(btrim(coalesce(t.object_name, ''))) = lower(btrim(v_object_name)));

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id, 'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', btrim(coalesce(e.position, '')), 'note', 'Нет отметки в табеле'
  ) order by e.fio, e.id), '[]'::jsonb)
  into v_missing_attendance_items
  from public.employees e
  where e.company_id = v_company_id and e.is_active = true and e.archived_at is null
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)))
    and not exists (
      select 1 from public.attendance a
      where a.company_id = e.company_id and a.employee_id = e.id and a.work_date = v_report_date
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00')) || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(' · ', nullif(btrim(coalesce(p.payment_type, '')), ''), nullif(btrim(coalesce(p.comment, '')), ''))
  ) order by p.payment_date desc, e.fio), '[]'::jsonb)
  into v_missing_receipt_items
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = v_company_id
    and p.period_year = extract(year from v_report_date)::integer
    and p.period_month = extract(month from v_report_date)::integer
    and (p_object_id is null or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(v_object_name)))
    and not exists (
      select 1 from public.payment_receipts receipt
      where receipt.company_id = p.company_id and receipt.payment_id = p.id
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id, 'title', coalesce(nullif(btrim(m.title), ''), 'Юридический вопрос'),
    'subtitle', concat_ws(' · ', nullif(btrim(coalesce(m.risk_level, '')), ''), nullif(btrim(coalesce(m.status, '')), '')),
    'note', btrim(coalesce(m.required_actions, m.description, ''))
  ) order by m.due_at, m.title), '[]'::jsonb)
  into v_legal_items
  from public.legal_matters m
  where m.company_id = v_company_id and m.resolved_at is null
    and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
    and (m.due_at < v_report_date::timestamp or lower(coalesce(m.risk_level, '')) in ('высокий','критический','high','critical'))
    and (p_object_id is null or m.object_id = p_object_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id, 'title', coalesce(nullif(btrim(m.title), ''), 'Этап'),
    'subtitle', concat_ws(' · ', nullif(btrim(coalesce(m.location, '')), ''), 'срок ' || to_char(m.target_date, 'DD.MM.YYYY')),
    'note', btrim(coalesce(m.notes, ''))
  ) order by m.target_date, m.title), '[]'::jsonb)
  into v_milestone_items
  from public.project_milestones m
  where m.company_id = v_company_id
    and lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
    and m.target_date <= v_report_date + 7
    and (p_object_id is null or lower(btrim(coalesce(m.object_name, ''))) = lower(btrim(v_object_name)));

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc), '[]'::jsonb)
  into v_dispatcher_runs
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
    'report_date', v_report_date,
    'selected_object', case when p_object_id is null then null else jsonb_build_object('id', p_object_id, 'name', v_object_name) end,
    'objects', v_objects,
    'metrics', jsonb_build_object(
      'critical_count', v_critical,
      'tasks', jsonb_build_object('total', v_tasks_total, 'done', v_tasks_done, 'pending', v_tasks_total-v_tasks_done, 'problem', v_tasks_problem),
      'attendance', jsonb_build_object('active', v_active_employees, 'marked', v_attendance_marked, 'missing', v_attendance_missing, 'shifts', v_total_shifts),
      'employees', jsonb_build_object('active', v_active_employees, 'added', v_added_employees, 'archived', v_archived_employees),
      'payments', jsonb_build_object('month_count', v_payments_month_count, 'month_amount', v_payments_month_amount, 'day_count', v_payments_day_count, 'missing_receipts', v_payments_missing_receipts),
      'recruitment', jsonb_build_object('active', v_recruitment_active, 'new', v_recruitment_new, 'incoming_messages', v_recruitment_messages),
      'legal', jsonb_build_object('open', v_legal_open, 'overdue', v_legal_overdue, 'high_risk', v_legal_high, 'expiring_documents', v_documents_expiring),
      'milestones', jsonb_build_object('open', v_milestones_open, 'overdue', v_milestones_overdue, 'upcoming', v_milestones_upcoming)
    ),
    'trend', jsonb_build_object(
      'tasks_done_rate', case when v_tasks_total=0 then 0 else round(v_tasks_done::numeric*100/v_tasks_total,1) end,
      'tasks_yesterday_done_rate', case when v_tasks_yesterday_total=0 then 0 else round(v_tasks_yesterday_done::numeric*100/v_tasks_yesterday_total,1) end,
      'tasks_week_done_rate', case when v_tasks_week_total=0 then 0 else round(v_tasks_week_done::numeric*100/v_tasks_week_total,1) end,
      'attendance_missing_yesterday', v_attendance_yesterday_missing
    ),
    'details', jsonb_build_object(
      'pending_tasks', v_pending_tasks,
      'missing_attendance', v_missing_attendance_items,
      'missing_receipts', v_missing_receipt_items,
      'legal_attention', v_legal_items,
      'milestones_attention', v_milestone_items
    ),
    'dispatcher_runs', v_dispatcher_runs,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.get_manager_reports_center(uuid,date) from public, anon;
grant execute on function public.get_manager_reports_center(uuid,date) to authenticated;
