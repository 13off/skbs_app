create or replace function public.get_executive_payment_summary(
  p_start_date date,
  p_end_date date,
  p_object_name text default null
)
returns table(
  employee_name text,
  person_id uuid,
  employee_ids uuid[],
  object_names text[],
  is_active boolean,
  shifts numeric,
  accrued numeric,
  paid numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_first_date date;
  v_last_date date;
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'invalid date range' using errcode = '22023';
  end if;

  v_first_date := least(p_start_date, p_end_date);
  v_last_date := greatest(p_start_date, p_end_date);

  if v_last_date - v_first_date > 370 then
    raise exception 'date range is too large' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  if not public.current_user_has_permission('accounting.directory.view')
     or not public.current_user_has_permission('accounting.attendance.view')
     or not public.current_user_has_permission('accounting.payments.view') then
    raise exception 'insufficient payment summary permissions'
      using errcode = '42501';
  end if;

  return query
  with visible_employees as materialized (
    select
      employee_row.id,
      employee_row.person_id,
      employee_row.fio,
      employee_row.object_name,
      coalesce(
        employee_row.monthly_salary,
        employee_row.daily_rate,
        0
      )::numeric as monthly_salary,
      coalesce(employee_row.ignore_timesheet, false) as ignore_timesheet,
      coalesce(employee_row.is_active, true) as employee_is_active
    from public.employees employee_row
    where employee_row.company_id = v_company_id
      and employee_row.archived_at is null
      and (
        v_object_name is null
        or employee_row.object_name = v_object_name
      )
  ),
  attendance_totals as materialized (
    select
      attendance_row.employee_id,
      sum(attendance_row.shifts)::numeric as total_shifts
    from public.attendance attendance_row
    join visible_employees employee_row
      on employee_row.id = attendance_row.employee_id
    where attendance_row.company_id = v_company_id
      and attendance_row.deleted_at is null
      and attendance_row.work_date between v_first_date and v_last_date
      and (
        v_object_name is null
        or attendance_row.object_name = v_object_name
      )
    group by attendance_row.employee_id
  ),
  payment_base as materialized (
    select
      payment_row.employee_id,
      payment_row.amount,
      make_date(
        payment_row.period_year,
        payment_row.period_month,
        1
      ) as period_start
    from public.payments payment_row
    join visible_employees employee_row
      on employee_row.id = payment_row.employee_id
    where payment_row.company_id = v_company_id
      and payment_row.deleted_at is null
      and payment_row.period_year > 0
      and payment_row.period_month between 1 and 12
  ),
  payment_totals as materialized (
    select
      payment_row.employee_id,
      sum(payment_row.amount)::numeric as total_paid
    from payment_base payment_row
    where payment_row.period_start <= v_last_date
      and (
        payment_row.period_start + interval '1 month - 1 day'
      )::date >= v_first_date
    group by payment_row.employee_id
  ),
  employee_calc as (
    select
      employee_row.id,
      employee_row.person_id,
      employee_row.fio,
      employee_row.object_name,
      employee_row.employee_is_active,
      coalesce(attendance_row.total_shifts, 0)::numeric as total_shifts,
      case
        when employee_row.ignore_timesheet then employee_row.monthly_salary
        else employee_row.monthly_salary / 30.0
          * coalesce(attendance_row.total_shifts, 0)
      end as total_accrued,
      coalesce(payment_row.total_paid, 0)::numeric as total_paid
    from visible_employees employee_row
    left join attendance_totals attendance_row
      on attendance_row.employee_id = employee_row.id
    left join payment_totals payment_row
      on payment_row.employee_id = employee_row.id
  ),
  person_calc as (
    select
      coalesce(
        'person:' || employee_row.person_id::text,
        'name:' || lower(
          regexp_replace(btrim(employee_row.fio), '\s+', ' ', 'g')
        )
      ) as person_key,
      min(btrim(employee_row.fio)) as grouped_employee_name,
      nullif(
        min(coalesce(employee_row.person_id::text, '')),
        ''
      )::uuid as grouped_person_id,
      array_agg(employee_row.id order by employee_row.id) as grouped_employee_ids,
      coalesce(
        array_agg(
          distinct btrim(employee_row.object_name)
          order by btrim(employee_row.object_name)
        ) filter (
          where nullif(btrim(employee_row.object_name), '') is not null
        ),
        '{}'::text[]
      ) as grouped_object_names,
      bool_or(employee_row.employee_is_active) as grouped_is_active,
      sum(employee_row.total_shifts)::numeric as grouped_shifts,
      sum(employee_row.total_accrued)::numeric as grouped_accrued,
      sum(employee_row.total_paid)::numeric as grouped_paid
    from employee_calc employee_row
    group by coalesce(
      'person:' || employee_row.person_id::text,
      'name:' || lower(
        regexp_replace(btrim(employee_row.fio), '\s+', ' ', 'g')
      )
    )
  )
  select
    person_row.grouped_employee_name,
    person_row.grouped_person_id,
    person_row.grouped_employee_ids,
    person_row.grouped_object_names,
    person_row.grouped_is_active,
    person_row.grouped_shifts,
    person_row.grouped_accrued,
    person_row.grouped_paid
  from person_calc person_row
  where abs(person_row.grouped_accrued - person_row.grouped_paid) > 0.005
  order by person_row.grouped_employee_name;
end;
$function$;

revoke all on function public.get_executive_payment_summary(
  date,
  date,
  text
) from public, anon;

grant execute on function public.get_executive_payment_summary(
  date,
  date,
  text
) to authenticated;

grant execute on function public.get_executive_payment_summary(
  date,
  date,
  text
) to service_role;
