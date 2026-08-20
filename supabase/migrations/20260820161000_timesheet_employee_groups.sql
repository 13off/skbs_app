-- Custom employee groups inside the timesheet.
-- Company admins manage membership; foremen can read/filter groups.

create table if not exists public.timesheet_groups (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint timesheet_groups_name_check
    check (char_length(btrim(name)) between 1 and 80)
);

create unique index if not exists timesheet_groups_company_object_name_uidx
  on public.timesheet_groups(company_id, object_id, lower(btrim(name)));
create index if not exists timesheet_groups_company_object_idx
  on public.timesheet_groups(company_id, object_id, sort_order, name);

create table if not exists public.timesheet_group_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  group_id uuid not null references public.timesheet_groups(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (group_id, employee_id)
);

create unique index if not exists timesheet_group_members_company_employee_uidx
  on public.timesheet_group_members(company_id, employee_id);
create index if not exists timesheet_group_members_group_idx
  on public.timesheet_group_members(group_id, employee_id);

alter table public.timesheet_groups enable row level security;
alter table public.timesheet_group_members enable row level security;

drop policy if exists timesheet_groups_company_read on public.timesheet_groups;
create policy timesheet_groups_company_read
  on public.timesheet_groups
  for select
  to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.current_user_role() in ('admin', 'foreman')
  );

drop policy if exists timesheet_group_members_company_read on public.timesheet_group_members;
create policy timesheet_group_members_company_read
  on public.timesheet_group_members
  for select
  to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.current_user_role() in ('admin', 'foreman')
  );

grant select on public.timesheet_groups to authenticated;
grant select on public.timesheet_group_members to authenticated;

create or replace function public.list_timesheet_groups(
  p_object_name text default null
)
returns table (
  id uuid,
  object_id uuid,
  object_name text,
  name text,
  sort_order integer,
  employee_ids uuid[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_object_name text := nullif(btrim(p_object_name), '');
begin
  if v_company_id is null or v_role not in ('admin', 'foreman') then
    return;
  end if;

  return query
  select
    g.id,
    g.object_id,
    o.name as object_name,
    g.name,
    g.sort_order,
    coalesce(
      array_agg(m.employee_id order by e.fio)
        filter (where m.employee_id is not null),
      '{}'::uuid[]
    ) as employee_ids
  from public.timesheet_groups g
  join public.objects o
    on o.id = g.object_id
   and o.company_id = g.company_id
  left join public.timesheet_group_members m
    on m.group_id = g.id
   and m.company_id = g.company_id
  left join public.employees e
    on e.id = m.employee_id
   and e.company_id = g.company_id
  where g.company_id = v_company_id
    and (v_object_name is null or o.name = v_object_name)
  group by g.id, g.object_id, o.name, g.name, g.sort_order
  order by o.name, g.sort_order, lower(g.name), g.id;
end;
$$;

create or replace function public.save_timesheet_group(
  p_group_id uuid,
  p_object_name text,
  p_name text,
  p_employee_ids uuid[] default '{}'::uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_object_name text := nullif(btrim(p_object_name), '');
  v_name text := nullif(btrim(p_name), '');
  v_object_id uuid;
  v_group_id uuid := p_group_id;
  v_employee_ids uuid[] := coalesce(p_employee_ids, '{}'::uuid[]);
  v_next_order integer;
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;
  if v_object_name is null then
    raise exception 'Выберите объект';
  end if;
  if v_name is null then
    raise exception 'Введите название группы';
  end if;
  if char_length(v_name) > 80 then
    raise exception 'Название группы должно быть короче 80 символов';
  end if;

  select o.id
    into v_object_id
  from public.objects o
  where o.company_id = v_company_id
    and o.name = v_object_name
    and o.is_active = true
  limit 1;

  if v_object_id is null then
    raise exception 'Объект не найден';
  end if;

  if exists (
    select 1
    from unnest(v_employee_ids) as selected(employee_id)
    left join public.employees e on e.id = selected.employee_id
    where e.id is null
       or e.company_id <> v_company_id
       or e.object_id <> v_object_id
       or e.is_active is not true
  ) then
    raise exception 'В группе есть сотрудник другого объекта или неактивный сотрудник';
  end if;

  if v_group_id is null then
    select coalesce(max(g.sort_order), 0) + 10
      into v_next_order
    from public.timesheet_groups g
    where g.company_id = v_company_id
      and g.object_id = v_object_id;

    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      created_by,
      updated_at
    ) values (
      v_company_id,
      v_object_id,
      v_name,
      v_next_order,
      (select auth.uid()),
      now()
    )
    returning id into v_group_id;
  else
    if not exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
    ) then
      raise exception 'Группа не найдена';
    end if;

    update public.timesheet_groups
    set object_id = v_object_id,
        name = v_name,
        updated_at = now()
    where id = v_group_id
      and company_id = v_company_id;
  end if;

  delete from public.timesheet_group_members
  where group_id = v_group_id
    and company_id = v_company_id;

  if cardinality(v_employee_ids) > 0 then
    -- An employee can be shown in only one timesheet section at a time.
    delete from public.timesheet_group_members m
    where m.company_id = v_company_id
      and m.employee_id = any(v_employee_ids);

    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_group_id,
      selected.employee_id,
      (select auth.uid())
    from unnest(v_employee_ids) as selected(employee_id);
  end if;

  return v_group_id;
exception
  when unique_violation then
    raise exception 'Группа с таким названием уже есть на этом объекте';
end;
$$;

create or replace function public.delete_timesheet_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;

  delete from public.timesheet_groups
  where id = p_group_id
    and company_id = v_company_id;
end;
$$;

revoke all on function public.list_timesheet_groups(text) from public;
revoke all on function public.save_timesheet_group(uuid, text, text, uuid[]) from public;
revoke all on function public.delete_timesheet_group(uuid) from public;
grant execute on function public.list_timesheet_groups(text) to authenticated;
grant execute on function public.save_timesheet_group(uuid, text, text, uuid[]) to authenticated;
grant execute on function public.delete_timesheet_group(uuid) to authenticated;

create or replace function private.cleanup_timesheet_group_members_on_employee_move()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.object_id is distinct from new.object_id
     or old.company_id is distinct from new.company_id
     or old.is_active is distinct from new.is_active then
    delete from public.timesheet_group_members m
    using public.timesheet_groups g
    where m.group_id = g.id
      and m.employee_id = new.id
      and (
        g.company_id <> new.company_id
        or g.object_id <> new.object_id
        or new.is_active is not true
      );
  end if;
  return new;
end;
$$;

drop trigger if exists employees_cleanup_timesheet_group_members on public.employees;
create trigger employees_cleanup_timesheet_group_members
  after update of object_id, company_id, is_active on public.employees
  for each row execute function private.cleanup_timesheet_group_members_on_employee_move();

drop trigger if exists timesheet_groups_app_data_broadcast on public.timesheet_groups;
create trigger timesheet_groups_app_data_broadcast
  after insert or update or delete on public.timesheet_groups
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists timesheet_group_members_app_data_broadcast on public.timesheet_group_members;
create trigger timesheet_group_members_app_data_broadcast
  after insert or update or delete on public.timesheet_group_members
  for each row execute function private.broadcast_app_data_change();
