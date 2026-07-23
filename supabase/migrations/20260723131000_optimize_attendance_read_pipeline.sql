create index if not exists attendance_active_company_employee_date_idx
  on public.attendance (company_id, employee_id, work_date)
  where deleted_at is null;

create index if not exists attendance_active_company_object_date_idx
  on public.attendance (company_id, object_id, work_date, employee_id)
  where deleted_at is null;

create or replace function public.get_attendance_rows_fast(
  p_start_date date,
  p_end_date date,
  p_object_name text default null,
  p_employee_ids uuid[] default null,
  p_worked_only boolean default false
)
returns table (
  employee_id uuid,
  work_date date,
  shifts numeric,
  object_name text,
  status text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_company_id uuid;
  v_accounting_access boolean := false;
  v_allowed_object_ids uuid[] := '{}'::uuid[];
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
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
  if v_company_id is null then
    return;
  end if;

  v_accounting_access := public.current_user_has_permission(
    'accounting.attendance.view'
  );

  if not v_accounting_access then
    select coalesce(array_agg(object_row.id), '{}'::uuid[])
      into v_allowed_object_ids
      from public.objects object_row
     where object_row.company_id = v_company_id
       and object_row.is_active = true
       and public.current_user_has_object_scope(object_row.id)
       and public.current_user_has_object_permission(
         'attendance.view', object_row.id
       );
  end if;

  return query
  select attendance_row.employee_id,
         attendance_row.work_date,
         attendance_row.shifts,
         attendance_row.object_name,
         attendance_row.status
    from public.attendance attendance_row
   where attendance_row.company_id = v_company_id
     and attendance_row.deleted_at is null
     and attendance_row.work_date between p_start_date and p_end_date
     and (v_object_name is null or attendance_row.object_name = v_object_name)
     and (
       p_employee_ids is null
       or cardinality(p_employee_ids) = 0
       or attendance_row.employee_id = any(p_employee_ids)
     )
     and (not p_worked_only or attendance_row.status = 'worked')
     and (
       v_accounting_access
       or attendance_row.object_id = any(v_allowed_object_ids)
     )
   order by attendance_row.work_date, attendance_row.employee_id;
end;
$function$;

revoke all on function public.get_attendance_rows_fast(
  date,
  date,
  text,
  uuid[],
  boolean
) from public, anon;

grant execute on function public.get_attendance_rows_fast(
  date,
  date,
  text,
  uuid[],
  boolean
) to authenticated;
