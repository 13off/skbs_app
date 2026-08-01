-- Route timeline support and a safe way to cancel an accidental shift start.

create or replace function public.cancel_recent_employee_shift(
  p_employee_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_profile_object_name text;
  v_employee public.employees%rowtype;
  v_shift public.employee_work_shifts%rowtype;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Требуется повторный вход';
  end if;

  select up.active_company_id, up.role, coalesce(up.object_name, '')
    into v_company_id, v_role, v_profile_object_name
  from public.user_profiles up
  where up.id = v_user_id
    and up.is_active = true;

  if v_company_id is null or v_role is null then
    raise exception using errcode = '42501', message = 'Рабочий профиль не найден';
  end if;

  if v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception using errcode = '42501', message = 'Исправление смены недоступно';
  end if;

  select e.*
    into v_employee
  from public.employees e
  where e.id = p_employee_id
    and e.company_id = v_company_id
    and e.is_active = true
    and e.archived_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'Сотрудник не найден';
  end if;

  if v_role = 'employee' and not exists (
    select 1
    from public.employee_account_links l
    where l.company_id = v_company_id
      and l.user_id = v_user_id
      and l.person_id = v_employee.person_id
      and l.is_active = true
  ) then
    raise exception using errcode = '42501', message = 'Нельзя исправить смену другого сотрудника';
  end if;

  if v_role = 'foreman'
     and nullif(btrim(v_profile_object_name), '') is not null
     and btrim(v_employee.object_name) <> btrim(v_profile_object_name) then
    raise exception using errcode = '42501', message = 'Сотрудник относится к другому объекту';
  end if;

  select s.*
    into v_shift
  from public.employee_work_shifts s
  where s.company_id = v_company_id
    and s.employee_id = p_employee_id
    and s.status = 'active'
  order by s.started_at desc
  limit 1
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Активная смена не найдена';
  end if;

  if clock_timestamp() - v_shift.started_at > interval '10 minutes' then
    raise exception using errcode = '22023', message = 'Отменить ошибочный старт можно только в первые 10 минут';
  end if;

  if coalesce(v_shift.route_point_count, 0) > 30 then
    raise exception using errcode = '22023', message = 'Смена уже содержит рабочий маршрут и не может быть отменена как ошибочная';
  end if;

  update public.employee_work_shifts
  set status = 'cancelled',
      ended_at = clock_timestamp(),
      ended_by = v_user_id,
      updated_at = clock_timestamp()
  where id = v_shift.id
    and company_id = v_company_id
    and status = 'active';

  return v_shift.id;
end;
$$;

revoke all on function public.cancel_recent_employee_shift(uuid) from public, anon;
grant execute on function public.cancel_recent_employee_shift(uuid) to authenticated;

comment on function public.cancel_recent_employee_shift(uuid) is
  'Marks a just-started active shift as cancelled. The action is limited to ten minutes and a small route.';

create or replace function public.get_employee_route_geofences(
  p_employee_id uuid,
  p_work_date date
)
returns table (
  object_id uuid,
  object_name text,
  latitude double precision,
  longitude double precision,
  radius_m integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_profile_object_name text;
  v_employee_object_name text;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Требуется повторный вход';
  end if;

  select up.active_company_id, up.role, coalesce(up.object_name, '')
    into v_company_id, v_role, v_profile_object_name
  from public.user_profiles up
  where up.id = v_user_id
    and up.is_active = true;

  if v_company_id is null or v_role not in ('admin', 'developer', 'foreman') then
    raise exception using errcode = '42501', message = 'Маршруты доступны только руководителю';
  end if;

  select e.object_name
    into v_employee_object_name
  from public.employees e
  where e.id = p_employee_id
    and e.company_id = v_company_id
    and e.is_active = true
    and e.archived_at is null;

  if not found then
    raise exception using errcode = 'P0002', message = 'Сотрудник не найден';
  end if;

  if v_role = 'foreman'
     and nullif(btrim(v_profile_object_name), '') is not null
     and btrim(v_employee_object_name) <> btrim(v_profile_object_name) then
    raise exception using errcode = '42501', message = 'Сотрудник относится к другому объекту';
  end if;

  return query
  select distinct
    g.object_id,
    o.name,
    g.latitude,
    g.longitude,
    g.radius_m
  from public.employee_work_shifts s
  join public.object_geofences g
    on g.company_id = s.company_id
   and g.object_id = s.object_id
  join public.objects o
    on o.company_id = s.company_id
   and o.id = s.object_id
  where s.company_id = v_company_id
    and s.employee_id = p_employee_id
    and s.work_date = p_work_date
    and s.status <> 'cancelled'
  order by o.name;
end;
$$;

revoke all on function public.get_employee_route_geofences(uuid, date) from public, anon;
grant execute on function public.get_employee_route_geofences(uuid, date) to authenticated;

comment on function public.get_employee_route_geofences(uuid, date) is
  'Returns object geofences needed to explain route points and automatic exits for an employee day.';
