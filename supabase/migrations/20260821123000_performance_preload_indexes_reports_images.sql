-- Performance package: hot-path indexes, server-side timesheet/payment aggregates,
-- and a derived thumbnail path for task photos. All changes are additive.

alter table public.task_photos
  add column if not exists thumbnail_path text;

create unique index if not exists task_photos_thumbnail_path_uidx
  on public.task_photos (thumbnail_path)
  where thumbnail_path is not null;

create index if not exists employees_hot_scope_fio_idx
  on public.employees (company_id, object_id, is_active, fio)
  where archived_at is null;

create index if not exists tasks_hot_scope_date_idx
  on public.tasks (company_id, object_id, task_date, created_at desc)
  include (status, is_draft)
  where deleted_at is null;

create index if not exists payments_hot_employee_period_idx
  on public.payments (company_id, employee_id, period_year, period_month)
  include (amount, payment_date)
  where deleted_at is null;

create index if not exists payments_hot_employee_date_idx
  on public.payments (company_id, employee_id, payment_date)
  include (amount, period_year, period_month)
  where deleted_at is null;

create index if not exists attendance_hot_period_cover_idx
  on public.attendance (company_id, object_id, work_date, employee_id)
  include (shifts, status)
  where deleted_at is null;

create or replace function public.get_period_timesheet_fast(
  p_start_date date,
  p_end_date date,
  p_object_name text default null,
  p_include_fired boolean default false
)
returns table(
  id uuid,
  person_id uuid,
  object_id uuid,
  fio text,
  position text,
  phone text,
  object_name text,
  daily_rate integer,
  is_active boolean,
  comment text,
  shifts_by_date jsonb
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid;
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
  v_directory_access boolean := false;
  v_attendance_access boolean := false;
  v_employee_object_ids uuid[] := '{}'::uuid[];
  v_attendance_object_ids uuid[] := '{}'::uuid[];
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_start_date is null or p_end_date is null or p_start_date > p_end_date then
    raise exception 'invalid date range' using errcode = '22023';
  end if;
  if p_end_date - p_start_date > 370 then
    raise exception 'date range is too large' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then return; end if;

  v_directory_access := public.current_user_has_permission('accounting.directory.view');
  v_attendance_access := public.current_user_has_permission('accounting.attendance.view');

  select
    coalesce(array_agg(o.id) filter (
      where v_directory_access or (
        public.current_user_has_object_scope(o.id)
        and public.current_user_has_object_permission('employees.view', o.id)
      )
    ), '{}'::uuid[]),
    coalesce(array_agg(o.id) filter (
      where v_attendance_access or (
        public.current_user_has_object_scope(o.id)
        and public.current_user_has_object_permission('attendance.view', o.id)
      )
    ), '{}'::uuid[])
  into v_employee_object_ids, v_attendance_object_ids
  from public.objects o
  where o.company_id = v_company_id
    and o.is_active = true
    and (v_object_name is null or o.name = v_object_name);

  return query
  with visible_employees as materialized (
    select e.*
    from public.employees e
    where e.company_id = v_company_id
      and e.archived_at is null
      and (p_include_fired or e.is_active)
      and e.object_id = any(v_employee_object_ids)
      and (v_object_name is null or e.object_name = v_object_name)
  ), attendance_by_employee as materialized (
    select
      a.employee_id,
      jsonb_object_agg(to_char(a.work_date, 'YYYY-MM-DD'), a.shifts order by a.work_date) as shifts_by_date
    from public.attendance a
    join visible_employees e on e.id = a.employee_id
    where a.company_id = v_company_id
      and a.deleted_at is null
      and a.object_id = any(v_attendance_object_ids)
      and a.work_date between p_start_date and p_end_date
    group by a.employee_id
  )
  select
    e.id, e.person_id, e.object_id, e.fio, e.position, e.phone,
    e.object_name, e.daily_rate, e.is_active, e.comment,
    coalesce(a.shifts_by_date, '{}'::jsonb)
  from visible_employees e
  left join attendance_by_employee a on a.employee_id = e.id
  order by e.fio;
end;
$$;

create or replace function public.get_monthly_timesheet_fast(
  p_year integer,
  p_month integer,
  p_object_name text default null,
  p_include_fired boolean default false
)
returns table(
  id uuid,
  person_id uuid,
  object_id uuid,
  fio text,
  position text,
  phone text,
  object_name text,
  daily_rate integer,
  is_active boolean,
  comment text,
  shifts_by_day jsonb,
  paid numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
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
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_month < 1 or p_month > 12 then
    raise exception 'invalid month' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then return; end if;
  v_first_date := make_date(p_year, p_month, 1);
  v_last_date := (v_first_date + interval '1 month - 1 day')::date;

  v_directory_access := public.current_user_has_permission('accounting.directory.view');
  v_attendance_access := public.current_user_has_permission('accounting.attendance.view');

  select
    coalesce(array_agg(o.id) filter (
      where v_directory_access or (
        public.current_user_has_object_scope(o.id)
        and public.current_user_has_object_permission('employees.view', o.id)
      )
    ), '{}'::uuid[]),
    coalesce(array_agg(o.id) filter (
      where v_attendance_access or (
        public.current_user_has_object_scope(o.id)
        and public.current_user_has_object_permission('attendance.view', o.id)
      )
    ), '{}'::uuid[]),
    coalesce(array_agg(o.id) filter (
      where public.current_user_has_object_permission('accounting.payments.view', o.id)
    ), '{}'::uuid[])
  into v_employee_object_ids, v_attendance_object_ids, v_payment_object_ids
  from public.objects o
  where o.company_id = v_company_id
    and o.is_active = true
    and (v_object_name is null or o.name = v_object_name);

  return query
  with visible_employees as materialized (
    select e.*
    from public.employees e
    where e.company_id = v_company_id
      and e.archived_at is null
      and (p_include_fired or e.is_active)
      and e.object_id = any(v_employee_object_ids)
      and (v_object_name is null or e.object_name = v_object_name)
  ), attendance_by_employee as materialized (
    select
      a.employee_id,
      jsonb_object_agg(extract(day from a.work_date)::int::text, a.shifts order by a.work_date) as shifts_by_day
    from public.attendance a
    join visible_employees e on e.id = a.employee_id
    where a.company_id = v_company_id
      and a.deleted_at is null
      and a.object_id = any(v_attendance_object_ids)
      and a.work_date between v_first_date and v_last_date
    group by a.employee_id
  ), payments_by_employee as materialized (
    select p.employee_id, sum(p.amount) as paid
    from public.payments p
    join visible_employees e on e.id = p.employee_id
    where p.company_id = v_company_id
      and p.deleted_at is null
      and p.object_id = any(v_payment_object_ids)
      and p.period_year = p_year
      and p.period_month = p_month
    group by p.employee_id
  )
  select
    e.id, e.person_id, e.object_id, e.fio, e.position, e.phone,
    e.object_name, e.daily_rate, e.is_active, e.comment,
    coalesce(a.shifts_by_day, '{}'::jsonb),
    coalesce(p.paid, 0)
  from visible_employees e
  left join attendance_by_employee a on a.employee_id = e.id
  left join payments_by_employee p on p.employee_id = e.id
  order by e.fio;
end;
$$;

create or replace function public.get_payment_totals_fast(
  p_employee_ids uuid[],
  p_period_year integer default null,
  p_period_month integer default null,
  p_start_date date default null,
  p_end_date date default null,
  p_by_payment_date boolean default false
)
returns table(employee_id uuid, paid numeric)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid;
  v_payment_object_ids uuid[] := '{}'::uuid[];
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if cardinality(coalesce(p_employee_ids, '{}'::uuid[])) = 0 then return; end if;
  if p_by_payment_date and (p_start_date is null or p_end_date is null or p_start_date > p_end_date) then
    raise exception 'invalid date range' using errcode = '22023';
  end if;
  if not p_by_payment_date and (p_period_year is null or p_period_month is null or p_period_month < 1 or p_period_month > 12) then
    raise exception 'invalid period' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then return; end if;

  select coalesce(array_agg(o.id) filter (
    where public.current_user_has_object_permission('accounting.payments.view', o.id)
  ), '{}'::uuid[])
  into v_payment_object_ids
  from public.objects o
  where o.company_id = v_company_id and o.is_active = true;

  return query
  select p.employee_id, coalesce(sum(p.amount), 0)
  from public.payments p
  where p.company_id = v_company_id
    and p.deleted_at is null
    and p.object_id = any(v_payment_object_ids)
    and p.employee_id = any(p_employee_ids)
    and (
      (p_by_payment_date and p.payment_date between p_start_date and p_end_date)
      or
      (not p_by_payment_date and p.period_year = p_period_year and p.period_month = p_period_month)
    )
  group by p.employee_id;
end;
$$;

grant execute on function public.get_period_timesheet_fast(date, date, text, boolean) to authenticated;
grant execute on function public.get_monthly_timesheet_fast(integer, integer, text, boolean) to authenticated;
grant execute on function public.get_payment_totals_fast(uuid[], integer, integer, date, date, boolean) to authenticated;
