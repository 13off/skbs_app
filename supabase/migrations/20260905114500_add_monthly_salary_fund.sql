-- Fixed monthly payroll replaces per-shift accrual in the application.
-- The legacy daily_rate column is intentionally preserved for older clients
-- during rollout, but new code reads/writes monthly_salary.

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

comment on column public.employees.monthly_salary is
  'Fixed salary for one settlement month. Payroll accrual does not depend on timesheet shifts.';

-- Include the new field in the fast employee directory RPC. Return type changes,
-- so PostgreSQL requires the old function to be dropped before recreation.
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
         employee.monthly_salary,
         employee.daily_rate,
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

-- Financial summary now represents the monthly salary fund, not
-- timesheet shifts multiplied by a per-shift rate.
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
  v_employee_object_ids uuid[] := '{}'::uuid[];
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
        where public.current_user_has_object_permission(
          'accounting.payments.view', object_row.id
        )
      ),
      '{}'::uuid[]
    )
  into
    v_employee_object_ids,
    v_payment_object_ids
  from public.objects object_row
  where object_row.company_id = v_company_id
    and object_row.is_active = true
    and (v_object_name is null or object_row.name = v_object_name);

  return query
  with visible_employees as materialized (
    select employee.id,
           coalesce(employee.monthly_salary, 0)::numeric as monthly_salary
    from public.employees employee
    where employee.company_id = v_company_id
      and employee.archived_at is null
      and employee.object_id = any(v_employee_object_ids)
  ),
  payment_totals as materialized (
    select payment.employee_id, sum(payment.amount) as amount
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
    coalesce(sum(employee.monthly_salary), 0),
    coalesce(sum(coalesce(payment.amount, 0)), 0)
  from visible_employees employee
  left join payment_totals payment
    on payment.employee_id = employee.id;
end;
$function$;

revoke all on function public.get_finance_summary_fast(integer, integer, text) from public;
grant execute on function public.get_finance_summary_fast(integer, integer, text) to authenticated;
grant execute on function public.get_finance_summary_fast(integer, integer, text) to service_role;
