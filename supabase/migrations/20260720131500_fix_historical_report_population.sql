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
        and (
          exists (
            select 1 from public.attendance fact
            where fact.company_id = e.company_id
              and fact.employee_id = e.id
              and fact.work_date = p_report_date
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
    )
), effective_yesterday as (
  select e.*
  from public.employees e
  where e.company_id = p_company_id
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
    and (
      exists (
        select 1 from public.attendance fact
        where fact.company_id = e.company_id
          and fact.employee_id = e.id
          and fact.work_date = p_report_date - 1
      )
      or (
        e.created_at::date <= p_report_date - 1
        and (
          e.is_active = true
          or coalesce(e.archived_at::date, e.updated_at::date) > p_report_date - 1
        )
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

revoke all on function private.manager_report_people(uuid,text,date)
  from public, anon, authenticated;
