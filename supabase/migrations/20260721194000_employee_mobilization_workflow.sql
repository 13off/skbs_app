create table if not exists public.employee_mobilizations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid references public.recruitment_applications(id) on delete set null,
  employee_id uuid not null references public.employees(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  planned_start_date date,
  ticket_booked boolean not null default false,
  arrival_confirmed boolean not null default false,
  accommodation_confirmed boolean not null default false,
  medical_cleared boolean not null default false,
  clothing_issued boolean not null default false,
  safety_inducted boolean not null default false,
  object_assigned boolean not null default false,
  attendance_enabled boolean not null default false,
  status text not null default 'draft' check (
    status = any (array['draft'::text, 'in_progress'::text, 'completed'::text])
  ),
  notes text not null default '',
  completed_at timestamptz,
  foreman_notified_at timestamptz,
  accountant_notified_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, employee_id)
);

create index if not exists employee_mobilizations_company_status_idx
  on public.employee_mobilizations(company_id, status, updated_at desc);
create index if not exists employee_mobilizations_application_fk_idx
  on public.employee_mobilizations(application_id);
create index if not exists employee_mobilizations_employee_fk_idx
  on public.employee_mobilizations(employee_id);
create index if not exists employee_mobilizations_object_fk_idx
  on public.employee_mobilizations(object_id);
create index if not exists employee_mobilizations_created_by_fk_idx
  on public.employee_mobilizations(created_by);
create index if not exists employee_mobilizations_updated_by_fk_idx
  on public.employee_mobilizations(updated_by);

insert into public.role_permissions (role_code, permission_code)
values
  ('owner', 'recruitment.mobilization.view'),
  ('admin', 'recruitment.mobilization.view'),
  ('developer', 'recruitment.mobilization.view'),
  ('hr', 'recruitment.mobilization.view'),
  ('foreman', 'recruitment.mobilization.view'),
  ('accountant', 'recruitment.mobilization.view'),
  ('owner', 'recruitment.mobilization.edit'),
  ('admin', 'recruitment.mobilization.edit'),
  ('developer', 'recruitment.mobilization.edit'),
  ('hr', 'recruitment.mobilization.edit')
on conflict (role_code, permission_code) do nothing;

grant select, insert, update on public.employee_mobilizations to authenticated;
alter table public.employee_mobilizations enable row level security;

drop policy if exists employee_mobilizations_select on public.employee_mobilizations;
create policy employee_mobilizations_select
  on public.employee_mobilizations
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.mobilization.view')
  );

drop policy if exists employee_mobilizations_insert on public.employee_mobilizations;
create policy employee_mobilizations_insert
  on public.employee_mobilizations
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.mobilization.edit')
    and created_by = (select auth.uid())
    and updated_by = (select auth.uid())
    and exists (
      select 1
      from public.employees e
      where e.id = employee_id and e.company_id = company_id
    )
    and exists (
      select 1
      from public.objects o
      where o.id = object_id and o.company_id = company_id and o.is_active
    )
  );

drop policy if exists employee_mobilizations_update on public.employee_mobilizations;
create policy employee_mobilizations_update
  on public.employee_mobilizations
  for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.mobilization.edit')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.mobilization.edit')
    and updated_by = (select auth.uid())
    and exists (
      select 1
      from public.employees e
      where e.id = employee_id and e.company_id = company_id
    )
    and exists (
      select 1
      from public.objects o
      where o.id = object_id and o.company_id = company_id and o.is_active
    )
  );

create or replace function private.prepare_employee_mobilization()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  object_name_value text := '';
  complete boolean := false;
begin
  if auth.uid() is null
     or new.company_id <> public.current_user_company_id()
     or not public.current_user_has_permission('recruitment.mobilization.edit') then
    raise exception 'Mobilization update is not allowed';
  end if;

  select o.name into object_name_value
  from public.objects o
  where o.id = new.object_id
    and o.company_id = new.company_id
    and o.is_active;

  if coalesce(object_name_value, '') = '' then
    raise exception 'Active object was not found';
  end if;

  new.updated_at := now();
  new.updated_by := auth.uid();
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  end if;

  complete := new.planned_start_date is not null
    and new.ticket_booked
    and new.arrival_confirmed
    and new.accommodation_confirmed
    and new.medical_cleared
    and new.clothing_issued
    and new.safety_inducted
    and new.object_assigned
    and new.attendance_enabled;

  if complete then
    new.status := 'completed';
    new.completed_at := coalesce(new.completed_at, now());
    new.foreman_notified_at := coalesce(new.foreman_notified_at, now());
    new.accountant_notified_at := coalesce(new.accountant_notified_at, now());

    update public.employees
    set object_id = new.object_id,
        object_name = object_name_value,
        is_active = true,
        updated_at = now()
    where id = new.employee_id
      and company_id = new.company_id;
  elsif new.planned_start_date is not null
        or new.ticket_booked
        or new.arrival_confirmed
        or new.accommodation_confirmed
        or new.medical_cleared
        or new.clothing_issued
        or new.safety_inducted
        or new.object_assigned
        or new.attendance_enabled then
    new.status := 'in_progress';
    new.completed_at := null;
  else
    new.status := 'draft';
    new.completed_at := null;
  end if;

  return new;
end;
$$;

revoke all on function private.prepare_employee_mobilization() from public;

drop trigger if exists prepare_employee_mobilization_before_write
  on public.employee_mobilizations;
create trigger prepare_employee_mobilization_before_write
  before insert or update on public.employee_mobilizations
  for each row execute function private.prepare_employee_mobilization();

create or replace function private.notify_employee_mobilization_completed()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  actor_name_value text := '';
  actor_email_value text := '';
  employee_name_value text := '';
  object_name_value text := '';
begin
  if new.status <> 'completed'
     or (tg_op = 'UPDATE' and old.status = 'completed') then
    return new;
  end if;

  select coalesce(p.full_name, ''), coalesce(p.email, '')
    into actor_name_value, actor_email_value
  from public.user_profiles p
  where p.id = auth.uid();

  select e.fio into employee_name_value
  from public.employees e
  where e.id = new.employee_id and e.company_id = new.company_id;

  select o.name into object_name_value
  from public.objects o
  where o.id = new.object_id and o.company_id = new.company_id;

  insert into public.app_notifications(
    company_id,
    title,
    body,
    actor_user_id,
    actor_name,
    actor_email,
    object_name,
    entity_type,
    entity_id,
    target_role,
    requires_action,
    priority,
    source_role,
    is_push_only,
    push_requested
  ) values
  (
    new.company_id,
    'Сотрудник готов к выходу',
    coalesce(employee_name_value, 'Сотрудник') || ' подготовлен к выходу на объект «' ||
      coalesce(object_name_value, '') || '». Добавьте его в рабочий график.',
    auth.uid(),
    coalesce(actor_name_value, ''),
    coalesce(actor_email_value, ''),
    coalesce(object_name_value, ''),
    'employee_mobilization',
    new.id::text,
    'foreman',
    true,
    'high',
    'hr',
    false,
    true
  ),
  (
    new.company_id,
    'Оформление сотрудника завершено',
    coalesce(employee_name_value, 'Сотрудник') || ' вышел на объект «' ||
      coalesce(object_name_value, '') || '». Проверьте ставку и расчётный контур.',
    auth.uid(),
    coalesce(actor_name_value, ''),
    coalesce(actor_email_value, ''),
    coalesce(object_name_value, ''),
    'employee_mobilization',
    new.id::text,
    'accountant',
    true,
    'normal',
    'hr',
    false,
    true
  );

  return new;
end;
$$;

revoke all on function private.notify_employee_mobilization_completed() from public;

drop trigger if exists notify_employee_mobilization_completed_after_write
  on public.employee_mobilizations;
create trigger notify_employee_mobilization_completed_after_write
  after insert or update on public.employee_mobilizations
  for each row execute function private.notify_employee_mobilization_completed();
