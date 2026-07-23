create or replace function public.get_finance_summary_fast(
  p_year integer default null,
  p_month integer default null,
  p_object_name text default null
)
returns table (
  accrued numeric,
  paid numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $body$
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
    select employee.id, employee.daily_rate
    from public.employees employee
    where employee.company_id = v_company_id
      and employee.archived_at is null
      and employee.object_id = any(v_employee_object_ids)
  ),
  attendance_totals as materialized (
    select attendance.employee_id, sum(attendance.shifts) as shifts
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
    coalesce(
      sum(coalesce(attendance.shifts, 0) * employee.daily_rate),
      0
    ),
    coalesce(sum(coalesce(payment.amount, 0)), 0)
  from visible_employees employee
  left join attendance_totals attendance
    on attendance.employee_id = employee.id
  left join payment_totals payment
    on payment.employee_id = employee.id;
end;
$body$;

comment on function public.get_finance_summary_fast(integer, integer, text) is
  'Возвращает начислено и выплачено для главной одним защищённым агрегатом.';

revoke all on function public.get_finance_summary_fast(integer, integer, text)
  from public, anon;
grant execute on function public.get_finance_summary_fast(integer, integer, text)
  to authenticated;
