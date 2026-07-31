begin;

alter table public.employee_work_shifts
  alter column start_latitude drop not null,
  alter column start_longitude drop not null,
  alter column start_accuracy_m drop not null,
  alter column start_distance_m drop not null;

create or replace function public.start_employee_shift_without_location(
  p_employee_id uuid,
  p_work_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_person_id uuid;
  v_employee public.employees%rowtype;
  v_shift public.employee_work_shifts%rowtype;
begin
  if v_user_id is null then raise exception 'Требуется повторный вход'; end if;

  select up.active_company_id, up.role into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id and up.is_active = true;

  if v_company_id is null or v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception 'Рабочие действия недоступны';
  end if;

  if v_role = 'employee' then
    select eal.person_id into v_person_id
    from public.employee_account_links eal
    where eal.company_id = v_company_id and eal.user_id = v_user_id and eal.is_active = true
    limit 1;
    if v_person_id is null then raise exception 'Рабочая карточка не привязана'; end if;

    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.person_id = v_person_id
      and e.is_active = true and e.archived_at is null
    order by e.updated_at desc limit 1;
    if v_employee.id is null or v_employee.id <> p_employee_id then
      raise exception 'Нельзя выполнять действия от имени другого сотрудника';
    end if;
  else
    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.id = p_employee_id
      and e.is_active = true and e.archived_at is null
    limit 1;
  end if;

  if v_employee.id is null then raise exception 'Сотрудник не найден'; end if;
  if v_employee.object_id is null then raise exception 'У сотрудника не указан объект'; end if;

  select s.* into v_shift
  from public.employee_work_shifts s
  where s.company_id = v_company_id and s.employee_id = v_employee.id and s.status = 'active'
  limit 1;

  if v_shift.id is null then
    insert into public.employee_work_shifts (
      company_id, employee_id, task_id, object_id, work_date, status, started_at,
      start_latitude, start_longitude, start_accuracy_m, start_distance_m,
      permission_scope, tracking_mode, route_point_count, last_point_at, started_by
    ) values (
      v_company_id, v_employee.id, null, v_employee.object_id,
      coalesce(p_work_date, current_date), 'active', now(),
      null, null, null, null, 'unavailable', 'web_foreground', 0, null, v_user_id
    ) returning * into v_shift;
  end if;

  return jsonb_build_object('ok', true, 'active_shift', to_jsonb(v_shift));
end;
$$;

create or replace function public.finish_employee_shift_without_location(
  p_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_person_id uuid;
  v_employee public.employees%rowtype;
  v_shift public.employee_work_shifts%rowtype;
begin
  if v_user_id is null then raise exception 'Требуется повторный вход'; end if;

  select up.active_company_id, up.role into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id and up.is_active = true;

  if v_company_id is null or v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception 'Рабочие действия недоступны';
  end if;

  if v_role = 'employee' then
    select eal.person_id into v_person_id
    from public.employee_account_links eal
    where eal.company_id = v_company_id and eal.user_id = v_user_id and eal.is_active = true
    limit 1;

    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.person_id = v_person_id
      and e.is_active = true and e.archived_at is null
    order by e.updated_at desc limit 1;
    if v_employee.id is null or v_employee.id <> p_employee_id then
      raise exception 'Нельзя выполнять действия от имени другого сотрудника';
    end if;
  else
    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.id = p_employee_id
      and e.is_active = true and e.archived_at is null
    limit 1;
  end if;

  if v_employee.id is null then raise exception 'Сотрудник не найден'; end if;

  update public.employee_work_shifts s
     set status = 'completed', ended_at = now(), ended_by = v_user_id, updated_at = now()
   where s.company_id = v_company_id and s.employee_id = v_employee.id and s.status = 'active'
  returning s.* into v_shift;

  if v_shift.id is null then raise exception 'Рабочий день не начат'; end if;
  return jsonb_build_object('ok', true, 'completed_shift', to_jsonb(v_shift));
end;
$$;

revoke all on function public.start_employee_shift_without_location(uuid, date) from public;
revoke all on function public.finish_employee_shift_without_location(uuid) from public;
grant execute on function public.start_employee_shift_without_location(uuid, date) to authenticated;
grant execute on function public.finish_employee_shift_without_location(uuid) to authenticated;

comment on function public.start_employee_shift_without_location(uuid, date) is
  'Начинает рабочий день в web/PWA без синтетической координаты, если WebKit не отдал геопозицию.';
comment on function public.finish_employee_shift_without_location(uuid) is
  'Завершает web/PWA рабочий день без синтетической конечной координаты.';

commit;
