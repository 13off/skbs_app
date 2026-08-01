create or replace function public.get_employee_route_geofences(p_employee_id uuid, p_work_date date)
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
  where up.id = v_user_id and up.is_active = true;
  if v_company_id is null or v_role not in ('admin', 'developer', 'foreman') then
    raise exception using errcode = '42501', message = 'Маршруты доступны только руководителю';
  end if;
  select e.object_name into v_employee_object_name
  from public.employees e
  where e.id = p_employee_id and e.company_id = v_company_id
    and e.is_active = true and e.archived_at is null;
  if not found then
    raise exception using errcode = 'P0002', message = 'Сотрудник не найден';
  end if;
  if v_role = 'foreman' and nullif(btrim(v_profile_object_name), '') is not null
     and btrim(v_employee_object_name) <> btrim(v_profile_object_name) then
    raise exception using errcode = '42501', message = 'Сотрудник относится к другому объекту';
  end if;
  return query
  select distinct g.object_id, o.name, g.latitude, g.longitude, g.radius_m
  from public.employee_work_shifts s
  join public.object_geofences g
    on g.company_id = s.company_id and g.object_id = s.object_id
  join public.objects o
    on o.company_id = s.company_id and o.id = s.object_id
  where s.company_id = v_company_id and s.employee_id = p_employee_id
    and s.work_date = p_work_date and s.status <> 'cancelled'
  order by o.name;
end;
$$;
revoke all on function public.get_employee_route_geofences(uuid, date) from public, anon;
grant execute on function public.get_employee_route_geofences(uuid, date) to authenticated;
