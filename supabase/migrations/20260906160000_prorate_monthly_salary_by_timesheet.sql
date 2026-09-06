-- Monthly salary is the only business salary value.
-- By default payroll is prorated against a 30-shift month. Employees with
-- ignore_timesheet=true receive the full monthly salary regardless of shifts.
-- daily_rate remains only as a compatibility mirror for older clients/RPCs.

alter table public.employees
  add column if not exists monthly_salary integer;

update public.employees
set monthly_salary = case
  when monthly_salary is not null then monthly_salary
  when daily_rate is null or daily_rate <= 100 then 0
  when daily_rate < 20000 then
    round((daily_rate * 30)::numeric, -3)::integer
  else daily_rate
end
where monthly_salary is null;

alter table public.employees
  alter column monthly_salary set default 0;

alter table public.employees
  add column if not exists ignore_timesheet boolean not null default false;

comment on column public.employees.monthly_salary is
  'Monthly salary. Normal accrual is monthly_salary / 30 * counted shifts.';
comment on column public.employees.ignore_timesheet is
  'When true, timesheet shifts do not reduce payroll and full monthly_salary is accrued.';
comment on column public.employees.daily_rate is
  'Deprecated compatibility mirror. Current clients must not interpret this value as a per-shift rate.';

-- Keep the compatibility mirror aligned for rows already migrated to a monthly salary.
update public.employees
set daily_rate = monthly_salary
where monthly_salary is not null
  and coalesce(daily_rate, -1) <> monthly_salary;

-- Return the payroll behavior flag together with employee rows.
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
  ignore_timesheet boolean,
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
  select employee.id,
         employee.person_id,
         employee.object_id,
         employee.fio,
         employee.position,
         employee.phone,
         employee.object_name,
         coalesce(employee.monthly_salary, employee.daily_rate, 0),
         employee.daily_rate,
         coalesce(employee.ignore_timesheet, false),
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

revoke all on function public.get_employee_rows_fast(text, boolean) from public;
grant execute on function public.get_employee_rows_fast(text, boolean) to authenticated;
grant execute on function public.get_employee_rows_fast(text, boolean) to service_role;

create or replace function public.get_finance_summary_fast(
  p_year integer default null,
  p_month integer default null,
  p_object_name text default null
)
returns table(accrued numeric, paid numeric)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
  v_first_date date;
  v_last_date date;
  v_directory_access boolean := false;
  v_attendance_access boolean := false;
  v_employee_object_ids uuid[] := '{}'::uuid[];
  v_attendance_object_ids uuid[] := '{}'::uuid[];
  v_payment_object_ids uuid[] := '{}'::uuid[];
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  if p_year is not null and p_month is not null then
    if p_month < 1 or p_month > 12 then
      raise exception 'invalid month' using errcode = '22023';
    end if;
    v_first_date := make_date(p_year, p_month, 1);
    v_last_date := (v_first_date + interval '1 month - 1 day')::date;
  end if;

  v_directory_access := public.current_user_has_permission(
    'accounting.directory.view'
  );
  v_attendance_access := public.current_user_has_permission(
    'accounting.attendance.view'
  );

  select
    coalesce(
      array_agg(object_row.id) filter (
        where v_directory_access
           or (
             public.current_user_has_object_scope(object_row.id)
             and public.current_user_has_object_permission(
               'employees.view', object_row.id
             )
           )
      ),
      '{}'::uuid[]
    ),
    coalesce(
      array_agg(object_row.id) filter (
        where v_attendance_access
           or (
             public.current_user_has_object_scope(object_row.id)
             and public.current_user_has_object_permission(
               'attendance.view', object_row.id
             )
           )
      ),
      '{}'::uuid[]
    ),
    coalesce(
      array_agg(object_row.id) filter (
        where public.current_user_has_object_permission(
          'accounting.payments.view', object_row.id
        )
      ),
      '{}'::uuid[]
    )
  into
    v_employee_object_ids,
    v_attendance_object_ids,
    v_payment_object_ids
  from public.objects object_row
  where object_row.company_id = v_company_id
    and object_row.is_active = true
    and (v_object_name is null or object_row.name = v_object_name);

  return query
  with visible_employees as materialized (
    select employee.id,
           employee.created_at,
           coalesce(employee.monthly_salary, employee.daily_rate, 0)::numeric
             as monthly_salary,
           coalesce(employee.ignore_timesheet, false) as ignore_timesheet
    from public.employees employee
    where employee.company_id = v_company_id
      and employee.archived_at is null
      and employee.object_id = any(v_employee_object_ids)
      and (v_last_date is null or employee.created_at::date <= v_last_date)
  ),
  attendance_totals as materialized (
    select attendance.employee_id, sum(attendance.shifts)::numeric as shifts
    from public.attendance attendance
    join visible_employees employee on employee.id = attendance.employee_id
    where attendance.company_id = v_company_id
      and attendance.deleted_at is null
      and attendance.object_id = any(v_attendance_object_ids)
      and (
        v_first_date is null
        or attendance.work_date between v_first_date and v_last_date
      )
    group by attendance.employee_id
  ),
  payment_totals as materialized (
    select payment.employee_id, sum(payment.amount)::numeric as amount
    from public.payments payment
    join visible_employees employee on employee.id = payment.employee_id
    where payment.company_id = v_company_id
      and payment.deleted_at is null
      and payment.object_id = any(v_payment_object_ids)
      and (
        v_first_date is null
        or (
          payment.period_year = p_year
          and payment.period_month = p_month
        )
      )
    group by payment.employee_id
  )
  select
    coalesce(
      sum(
        case
          when employee.ignore_timesheet then
            case
              when v_first_date is null then
                employee.monthly_salary * greatest(
                  1,
                  (
                    extract(year from age(date_trunc('month', current_date), date_trunc('month', employee.created_at))) * 12
                    + extract(month from age(date_trunc('month', current_date), date_trunc('month', employee.created_at)))
                    + 1
                  )::integer
                )
              else employee.monthly_salary
            end
          else employee.monthly_salary / 30.0 * coalesce(attendance.shifts, 0)
        end
      ),
      0
    ),
    coalesce(sum(coalesce(payment.amount, 0)), 0)
  from visible_employees employee
  left join attendance_totals attendance
    on attendance.employee_id = employee.id
  left join payment_totals payment
    on payment.employee_id = employee.id;
end;
$function$;

revoke all on function public.get_finance_summary_fast(integer, integer, text) from public;
grant execute on function public.get_finance_summary_fast(integer, integer, text) to authenticated;
grant execute on function public.get_finance_summary_fast(integer, integer, text) to service_role;
