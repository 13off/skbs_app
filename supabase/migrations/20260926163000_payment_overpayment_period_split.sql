-- One receipt file may document several period allocations of the same bank transfer.
alter table public.payment_receipts
  drop constraint if exists payment_receipts_file_path_key;

create unique index if not exists payment_receipts_payment_file_path_uidx
  on public.payment_receipts(payment_id, file_path);

create index if not exists payment_receipts_file_path_idx
  on public.payment_receipts(file_path);

create or replace function public.get_employee_payment_period_balances(
  p_employee_id uuid,
  p_start_month date,
  p_end_month date
)
returns table(
  period_year integer,
  period_month integer,
  accrued numeric,
  paid numeric,
  balance numeric
)
language plpgsql
stable
security definer
set search_path = public, private, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_employee public.employees%rowtype;
  v_first_month date;
  v_last_month date;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_employee_id is null or p_start_month is null or p_end_month is null then
    raise exception 'employee and period are required' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  if not public.current_user_has_permission('accounting.directory.view')
     or not public.current_user_has_permission('accounting.attendance.view')
     or not public.current_user_has_permission('accounting.payments.view') then
    raise exception 'insufficient payment balance permissions'
      using errcode = '42501';
  end if;

  select employee_row.*
    into v_employee
    from public.employees employee_row
   where employee_row.id = p_employee_id
     and employee_row.company_id = v_company_id
     and employee_row.archived_at is null;

  if not found then
    return;
  end if;

  v_first_month := date_trunc('month', least(p_start_month, p_end_month))::date;
  v_last_month := date_trunc('month', greatest(p_start_month, p_end_month))::date;

  if v_last_month > (date_trunc('month', current_date) + interval '1 month')::date then
    raise exception 'period range extends too far into the future'
      using errcode = '22023';
  end if;

  if v_last_month - v_first_month > 730 then
    raise exception 'period range is too large' using errcode = '22023';
  end if;

  return query
  with months as (
    select month_start::date
      from generate_series(
        v_first_month::timestamp,
        v_last_month::timestamp,
        interval '1 month'
      ) month_start
  ),
  attendance_totals as (
    select
      date_trunc('month', attendance_row.work_date)::date as month_start,
      sum(attendance_row.shifts)::numeric as shifts
    from public.attendance attendance_row
    where attendance_row.company_id = v_company_id
      and attendance_row.employee_id = p_employee_id
      and attendance_row.deleted_at is null
      and attendance_row.work_date >= v_first_month
      and attendance_row.work_date < (v_last_month + interval '1 month')
    group by 1
  ),
  payment_totals as (
    select
      make_date(payment_row.period_year, payment_row.period_month, 1) as month_start,
      sum(payment_row.amount)::numeric as paid
    from public.payments payment_row
    where payment_row.company_id = v_company_id
      and payment_row.employee_id = p_employee_id
      and payment_row.deleted_at is null
      and make_date(payment_row.period_year, payment_row.period_month, 1)
          between v_first_month and v_last_month
    group by 1
  ),
  period_calc as (
    select
      month_row.month_start,
      case
        when coalesce(v_employee.timesheet_excluded, false)
             and v_employee.automatic_salary_start_date is not null
          then private.calculate_fixed_monthly_accrual(
            coalesce(v_employee.monthly_salary, v_employee.daily_rate, 0)::numeric,
            v_employee.automatic_salary_start_date,
            month_row.month_start,
            (month_row.month_start + interval '1 month - 1 day')::date
          )
        else
          coalesce(v_employee.monthly_salary, v_employee.daily_rate, 0)::numeric
          / 30.0
          * coalesce(attendance_row.shifts, 0)
      end::numeric as accrued,
      coalesce(payment_row.paid, 0)::numeric as paid
    from months month_row
    left join attendance_totals attendance_row
      on attendance_row.month_start = month_row.month_start
    left join payment_totals payment_row
      on payment_row.month_start = month_row.month_start
  )
  select
    extract(year from period_row.month_start)::integer,
    extract(month from period_row.month_start)::integer,
    period_row.accrued,
    period_row.paid,
    (period_row.accrued - period_row.paid)::numeric
  from period_calc period_row
  order by period_row.month_start desc;
end;
$function$;

revoke all on function public.get_employee_payment_period_balances(uuid, date, date)
from public, anon;
grant execute on function public.get_employee_payment_period_balances(uuid, date, date)
to authenticated, service_role;
