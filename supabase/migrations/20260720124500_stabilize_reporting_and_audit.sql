alter table public.attendance
  add column if not exists marked_by_user_id uuid references auth.users(id) on delete set null;

create index if not exists attendance_marked_by_user_id_idx
  on public.attendance(marked_by_user_id)
  where marked_by_user_id is not null;

create or replace function public.attendance_set_actor()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor text;
begin
  if v_user_id is null then
    return new;
  end if;

  select nullif(btrim(up.full_name), '')
    into v_actor
  from public.user_profiles up
  where up.id = v_user_id;

  v_actor := coalesce(
    v_actor,
    nullif(btrim(auth.jwt() ->> 'email'), ''),
    nullif(btrim(new.marked_by), ''),
    'Пользователь'
  );

  new.marked_by_user_id := v_user_id;
  new.marked_by := v_actor;
  return new;
end;
$$;

revoke all on function public.attendance_set_actor() from public, anon, authenticated;

drop trigger if exists attendance_set_actor_before_write on public.attendance;
create trigger attendance_set_actor_before_write
before insert or update on public.attendance
for each row execute function public.attendance_set_actor();

create or replace function private.manager_report_people(
  p_company_id uuid,
  p_object_name text,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with effective_today as (
  select e.*
  from public.employees e
  where e.company_id = p_company_id
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
    and (
      (
        p_report_date >= current_date
        and e.is_active = true
        and e.archived_at is null
      )
      or (
        p_report_date < current_date
        and e.created_at::date <= p_report_date
        and (
          e.is_active = true
          or coalesce(e.archived_at::date, e.updated_at::date) > p_report_date
          or exists (
            select 1 from public.attendance fact
            where fact.company_id = e.company_id
              and fact.employee_id = e.id
              and fact.work_date = p_report_date
          )
        )
      )
    )
), effective_yesterday as (
  select e.*
  from public.employees e
  where e.company_id = p_company_id
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
    and e.created_at::date <= p_report_date - 1
    and (
      e.is_active = true
      or coalesce(e.archived_at::date, e.updated_at::date) > p_report_date - 1
      or exists (
        select 1 from public.attendance fact
        where fact.company_id = e.company_id
          and fact.employee_id = e.id
          and fact.work_date = p_report_date - 1
      )
    )
), employees as (
  select
    (select count(*) from effective_today)::integer as active,
    count(*) filter (where e.created_at::date = p_report_date)::integer as added,
    count(*) filter (
      where coalesce(
        e.archived_at::date,
        case when not e.is_active then e.updated_at::date end
      ) = p_report_date
    )::integer as archived
  from public.employees e
  where e.company_id = p_company_id
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
), attendance as (
  select
    count(distinct a.employee_id)::integer as marked,
    coalesce(sum(a.shifts), 0) as shifts
  from public.attendance a
  where a.company_id = p_company_id
    and a.work_date = p_report_date
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(a.object_name, ''))) = lower(btrim(p_object_name)))
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
      select 1 from public.attendance a
      where a.company_id = e.company_id
        and a.employee_id = e.id
        and a.work_date = p_report_date
    )
), missing_yesterday as (
  select count(*)::integer as count
  from effective_yesterday e
  where p_report_date - 1 <= current_date
    and not exists (
      select 1 from public.attendance a
      where a.company_id = e.company_id
        and a.employee_id = e.id
        and a.work_date = p_report_date - 1
    )
)
select jsonb_build_object(
  'employees', jsonb_build_object(
    'active', employees.active,
    'added', employees.added,
    'archived', employees.archived,
    'historical_estimate', p_report_date < current_date
  ),
  'attendance', jsonb_build_object(
    'active', employees.active,
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
from employees, attendance, missing_today, missing_yesterday;
$$;

revoke all on function private.manager_report_people(uuid,text,date) from public, anon, authenticated;

create or replace function private.manager_report_finance(
  p_company_id uuid,
  p_object_name text,
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
    count(*) filter (where p.payment_date = p_report_date)::integer as day_count,
    count(*) filter (
      where p.payment_date = p_report_date
        and not exists (
          select 1 from public.payment_receipts receipt
          where receipt.company_id = p.company_id and receipt.payment_id = p.id
        )
    )::integer as day_missing_receipts,
    count(*) filter (where not exists (
      select 1 from public.payment_receipts receipt
      where receipt.company_id = p.company_id and receipt.payment_id = p.id
    ))::integer as month_missing_receipts
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
), missing as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00')) || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(' · ', nullif(btrim(coalesce(p.payment_type, '')), ''), nullif(btrim(coalesce(p.comment, '')), ''))
  ) order by p.payment_date desc, e.fio), '[]'::jsonb) as items
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and p.payment_date = p_report_date
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
    and not exists (
      select 1 from public.payment_receipts receipt
      where receipt.company_id = p.company_id and receipt.payment_id = p.id
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

revoke all on function private.manager_report_finance(uuid,text,date) from public, anon, authenticated;

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
    coalesce((v_finance #>> '{metrics,missing_receipts_day}')::integer, 0) +
    coalesce((v_legal #>> '{metrics,overdue}')::integer, 0) +
    coalesce((v_legal #>> '{metrics,high_risk}')::integer, 0) +
    coalesce((v_milestones #>> '{metrics,overdue}')::integer, 0);

  v_attention :=
    coalesce((v_tasks #>> '{metrics,pending}')::integer, 0) +
    coalesce((v_finance #>> '{metrics,missing_receipts_month}')::integer, 0) +
    coalesce((v_legal #>> '{metrics,expiring_documents}')::integer, 0) +
    coalesce((v_milestones #>> '{metrics,upcoming}')::integer, 0);

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

alter function public.notification_role_for_entity(text)
  set search_path = public, pg_temp;
alter function public.notification_event_group(text)
  set search_path = public, pg_temp;

revoke all on function public.validate_task_milestone_link()
  from public, anon, authenticated;

create index if not exists app_notifications_target_user_id_fkey_idx
  on public.app_notifications(target_user_id)
  where target_user_id is not null;
create index if not exists dispatcher_summary_runs_object_id_fkey_idx
  on public.dispatcher_summary_runs(object_id)
  where object_id is not null;
create index if not exists dispatcher_summary_settings_object_id_fkey_idx
  on public.dispatcher_summary_settings(object_id)
  where object_id is not null;
create index if not exists notification_role_preferences_user_id_fkey_idx
  on public.notification_role_preferences(user_id);

alter policy tasks_select_company_object on public.tasks
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    not is_draft
    or (select public.is_admin())
    or created_by_user_id = (select auth.uid())
  )
);

alter policy notification_role_preferences_select_own
on public.notification_role_preferences
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);

alter policy notification_role_preferences_insert_own
on public.notification_role_preferences
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);

alter policy notification_role_preferences_update_own
on public.notification_role_preferences
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_admin())
)
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);
