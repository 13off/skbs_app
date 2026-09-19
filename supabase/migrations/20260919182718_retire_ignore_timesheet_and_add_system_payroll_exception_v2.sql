alter table public.employees
  add column if not exists timesheet_excluded boolean not null default false;

alter table public.employees
  add column if not exists automatic_salary_start_date date;

comment on column public.employees.timesheet_excluded is
  'System-managed flag: employee stays active in the directory but is omitted from timesheet entry screens. No user-facing toggle.';

comment on column public.employees.automatic_salary_start_date is
  'System-managed start date for automatic fixed monthly salary when timesheet_excluded=true.';

alter table public.employees disable trigger employees_permission_guard;

update public.employees
set ignore_timesheet = false
where coalesce(ignore_timesheet, false);

update public.employees
set is_active = true,
    monthly_salary = 180000,
    daily_rate = 180000,
    timesheet_excluded = true,
    automatic_salary_start_date = date '2026-06-06',
    comment = case
      when position('С 06.06.2026' in coalesce(comment, '')) > 0 then comment
      when btrim(coalesce(comment, '')) = '' then
        'Действующий сотрудник. С 06.06.2026 — 180 000 ₽/мес. В табеле не участвует; начисление зарплаты рассчитывается автоматически.'
      else
        btrim(comment) || E'\nДействующий сотрудник. С 06.06.2026 — 180 000 ₽/мес. В табеле не участвует; начисление зарплаты рассчитывается автоматически.'
    end
where fio = 'Одинцев Илья Александрович'
  and object_name = 'Мурманск'
  and archived_at is null;

alter table public.employees enable trigger employees_permission_guard;

alter table public.employees
  drop constraint if exists employees_ignore_timesheet_disabled_check;

alter table public.employees
  add constraint employees_ignore_timesheet_disabled_check
  check (coalesce(ignore_timesheet, false) = false);

create or replace function private.calculate_fixed_monthly_accrual(
  p_monthly_salary numeric,
  p_salary_start_date date,
  p_period_start date,
  p_period_end date
)
returns numeric
language sql
immutable
set search_path = public, pg_temp
as $function$
  with bounds as (
    select
      greatest(p_salary_start_date, p_period_start) as first_date,
      p_period_end as last_date
    where p_monthly_salary > 0
      and p_salary_start_date is not null
      and p_period_start is not null
      and p_period_end is not null
      and greatest(p_salary_start_date, p_period_start) <= p_period_end
  ),
  months as (
    select
      month_value::date as month_start,
      (month_value + interval '1 month - 1 day')::date as month_end,
      bounds.first_date,
      bounds.last_date
    from bounds
    cross join lateral generate_series(
      date_trunc('month', bounds.first_date)::date,
      date_trunc('month', bounds.last_date)::date,
      interval '1 month'
    ) as month_value
  ),
  slices as (
    select
      month_start,
      month_end,
      greatest(first_date, month_start) as slice_start,
      least(last_date, month_end) as slice_end
    from months
  )
  select coalesce(
    sum(
      case
        when slice_start = month_start and slice_end = month_end
          then p_monthly_salary
        else p_monthly_salary
          * (slice_end - slice_start + 1)::numeric
          / (month_end - month_start + 1)::numeric
      end
    ),
    0
  )
  from slices;
$function$;

drop function if exists public.get_employee_rows_fast(text, boolean);

create function public.get_employee_rows_fast(
  p_object_name text default null,
  p_include_fired boolean default false
)
returns table(
  id uuid,
  person_id uuid,
  object_id uuid,
  fio text,
  "position" text,
  phone text,
  object_name text,
  monthly_salary integer,
  daily_rate integer,
  timesheet_excluded boolean,
  automatic_salary_start_date date,
  is_active boolean,
  comment text,
  archived_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_accounting_access boolean := false;
  v_allowed_object_ids uuid[] := '{}'::uuid[];
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  v_accounting_access := public.current_user_has_permission(
    'accounting.directory.view'
  );

  if not v_accounting_access then
    select coalesce(array_agg(object_row.id), '{}'::uuid[])
      into v_allowed_object_ids
      from public.objects object_row
     where object_row.company_id = v_company_id
       and public.current_user_has_object_scope(object_row.id)
       and public.current_user_has_object_permission(
         'employees.view', object_row.id
       );
  end if;

  return query
  select
    employee.id,
    employee.person_id,
    employee.object_id,
    employee.fio,
    employee.position,
    employee.phone,
    employee.object_name,
    coalesce(employee.monthly_salary, employee.daily_rate, 0),
    employee.daily_rate,
    coalesce(employee.timesheet_excluded, false),
    employee.automatic_salary_start_date,
    employee.is_active,
    employee.comment,
    employee.archived_at
  from public.employees employee
  where employee.company_id = v_company_id
    and employee.archived_at is null
    and (coalesce(p_include_fired, false) or employee.is_active)
    and (v_object_name is null or employee.object_name = v_object_name)
    and (
      v_accounting_access
      or employee.object_id = any(v_allowed_object_ids)
    )
  order by employee.fio;
end;
$function$;

revoke all on function public.get_employee_rows_fast(text, boolean)
  from public, anon;
grant execute on function public.get_employee_rows_fast(text, boolean)
  to authenticated;
grant execute on function public.get_employee_rows_fast(text, boolean)
  to service_role;

drop function if exists public.get_executive_payment_summary(date, date, text);

create function public.get_executive_payment_summary(
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
  automatic_salary boolean,
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
      coalesce(employee_row.timesheet_excluded, false) as timesheet_excluded,
      employee_row.automatic_salary_start_date,
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
      make_date(payment_row.period_year, payment_row.period_month, 1)
        as period_start
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
      employee_row.timesheet_excluded
        and employee_row.automatic_salary_start_date is not null
        as automatic_salary,
      coalesce(attendance_row.total_shifts, 0)::numeric as total_shifts,
      case
        when employee_row.timesheet_excluded
             and employee_row.automatic_salary_start_date is not null
          then private.calculate_fixed_monthly_accrual(
            employee_row.monthly_salary,
            employee_row.automatic_salary_start_date,
            v_first_date,
            v_last_date
          )
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
      nullif(min(coalesce(employee_row.person_id::text, '')), '')::uuid
        as grouped_person_id,
      array_agg(employee_row.id order by employee_row.id)
        as grouped_employee_ids,
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
      bool_or(employee_row.automatic_salary) as grouped_automatic_salary,
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
    person_row.grouped_automatic_salary,
    person_row.grouped_shifts,
    person_row.grouped_accrued,
    person_row.grouped_paid
  from person_calc person_row
  where abs(person_row.grouped_accrued - person_row.grouped_paid) > 0.005
  order by person_row.grouped_employee_name;
end;
$function$;

revoke all on function public.get_executive_payment_summary(date, date, text)
  from public, anon;
grant execute on function public.get_executive_payment_summary(date, date, text)
  to authenticated;
grant execute on function public.get_executive_payment_summary(date, date, text)
  to service_role;
