create table if not exists public.employee_tracking_gaps (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  shift_id uuid not null references public.employee_work_shifts(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  reason text not null check (
    reason in (
      'application_interrupted',
      'location_service_disabled',
      'permission_missing',
      'stream_error',
      'health_check_error',
      'tracking_interruption',
      'no_coordinates'
    )
  ),
  details text not null default '',
  detected_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (ended_at > started_at),
  unique (shift_id, started_at, ended_at, reason)
);

create index if not exists employee_tracking_gaps_employee_date_idx
  on public.employee_tracking_gaps (
    company_id,
    employee_id,
    started_at desc
  );

create index if not exists employee_tracking_gaps_shift_idx
  on public.employee_tracking_gaps (shift_id, started_at);

alter table public.employee_tracking_gaps enable row level security;

revoke all on public.employee_tracking_gaps from anon, authenticated;
grant all on public.employee_tracking_gaps to service_role;

create or replace function public.record_employee_tracking_gap(
  p_employee_id uuid,
  p_shift_id uuid,
  p_started_at timestamptz,
  p_ended_at timestamptz,
  p_reason text,
  p_details text default ''
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
  v_gap_id uuid;
  v_reason text := lower(trim(coalesce(p_reason, '')));
begin
  if v_user_id is null then
    raise exception 'Требуется повторный вход';
  end if;

  select up.active_company_id, up.role
  into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id
    and up.is_active = true;

  if v_company_id is null or v_role is null then
    raise exception 'Компания пользователя не определена';
  end if;

  if v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception 'Запись разрывов геолокации недоступна';
  end if;

  if p_started_at is null
     or p_ended_at is null
     or p_ended_at <= p_started_at then
    raise exception 'Некорректный период разрыва геолокации';
  end if;

  if p_ended_at - p_started_at > interval '7 days' then
    raise exception 'Слишком длинный период разрыва геолокации';
  end if;

  if v_reason not in (
    'application_interrupted',
    'location_service_disabled',
    'permission_missing',
    'stream_error',
    'health_check_error',
    'tracking_interruption',
    'no_coordinates'
  ) then
    v_reason := 'tracking_interruption';
  end if;

  if not exists (
    select 1
    from public.employee_work_shifts s
    where s.id = p_shift_id
      and s.company_id = v_company_id
      and s.employee_id = p_employee_id
  ) then
    raise exception 'Рабочий день не найден';
  end if;

  if v_role = 'employee' and not exists (
    select 1
    from public.employee_account_links l
    join public.employees e
      on e.company_id = l.company_id
     and e.person_id = l.person_id
    where l.company_id = v_company_id
      and l.user_id = v_user_id
      and l.is_active = true
      and e.id = p_employee_id
      and e.is_active = true
      and e.archived_at is null
  ) then
    raise exception 'Нельзя записывать данные другого сотрудника';
  end if;

  insert into public.employee_tracking_gaps (
    company_id,
    shift_id,
    employee_id,
    started_at,
    ended_at,
    reason,
    details,
    detected_at,
    created_by
  )
  values (
    v_company_id,
    p_shift_id,
    p_employee_id,
    p_started_at,
    p_ended_at,
    v_reason,
    left(trim(coalesce(p_details, '')), 1000),
    now(),
    v_user_id
  )
  on conflict (shift_id, started_at, ended_at, reason)
  do update set
    details = excluded.details,
    detected_at = now()
  returning id into v_gap_id;

  return v_gap_id;
end;
$$;

create or replace function public.fetch_employee_tracking_gaps(
  p_employee_id uuid,
  p_work_date date
)
returns table (
  id uuid,
  shift_id uuid,
  employee_id uuid,
  started_at timestamptz,
  ended_at timestamptz,
  reason text,
  details text,
  detected_at timestamptz
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
begin
  if v_user_id is null then
    raise exception 'Требуется повторный вход';
  end if;

  select up.active_company_id, up.role
  into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id
    and up.is_active = true;

  if v_company_id is null or v_role is null then
    raise exception 'Компания пользователя не определена';
  end if;

  if v_role not in ('admin', 'developer', 'foreman') then
    raise exception 'Разрывы маршрута доступны только руководителю';
  end if;

  if not exists (
    select 1
    from public.employees e
    where e.id = p_employee_id
      and e.company_id = v_company_id
  ) then
    raise exception 'Сотрудник не найден';
  end if;

  return query
  select
    g.id,
    g.shift_id,
    g.employee_id,
    g.started_at,
    g.ended_at,
    g.reason,
    g.details,
    g.detected_at
  from public.employee_tracking_gaps g
  join public.employee_work_shifts s
    on s.id = g.shift_id
   and s.company_id = g.company_id
  where g.company_id = v_company_id
    and g.employee_id = p_employee_id
    and s.work_date = coalesce(p_work_date, current_date)
  order by g.started_at, g.id;
end;
$$;

revoke all on function public.record_employee_tracking_gap(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  text,
  text
) from public, anon, authenticated;

revoke all on function public.fetch_employee_tracking_gaps(
  uuid,
  date
) from public, anon, authenticated;

grant execute on function public.record_employee_tracking_gap(
  uuid,
  uuid,
  timestamptz,
  timestamptz,
  text,
  text
) to authenticated;

grant execute on function public.fetch_employee_tracking_gaps(
  uuid,
  date
) to authenticated;
