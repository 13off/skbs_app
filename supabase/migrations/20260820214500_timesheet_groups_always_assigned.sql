-- Every active employee always belongs to a visible timesheet group.
-- Unassigned employees are kept in one protected system group named «Общая» per object.

alter table public.timesheet_groups
  add column if not exists is_system boolean not null default false;

-- Reuse an existing «Общая» group if an admin happened to create one already.
with candidates as (
  select distinct on (g.company_id, g.object_id)
    g.id
  from public.timesheet_groups g
  where lower(btrim(g.name)) = 'общая'
  order by g.company_id, g.object_id, g.created_at, g.id
)
update public.timesheet_groups g
set is_system = true,
    sort_order = 1000000,
    updated_at = now()
from candidates c
where g.id = c.id
  and not exists (
    select 1
    from public.timesheet_groups existing
    where existing.company_id = g.company_id
      and existing.object_id = g.object_id
      and existing.is_system = true
  );

insert into public.timesheet_groups (
  company_id,
  object_id,
  name,
  sort_order,
  is_system,
  created_by,
  updated_at
)
select
  o.company_id,
  o.id,
  'Общая',
  1000000,
  true,
  null,
  now()
from public.objects o
where o.is_active = true
  and not exists (
    select 1
    from public.timesheet_groups g
    where g.company_id = o.company_id
      and g.object_id = o.id
      and g.is_system = true
  )
  and not exists (
    select 1
    from public.timesheet_groups g
    where g.company_id = o.company_id
      and g.object_id = o.id
      and lower(btrim(g.name)) = 'общая'
  );

create unique index if not exists timesheet_groups_one_system_per_object_uidx
  on public.timesheet_groups(company_id, object_id)
  where is_system = true;

create or replace function private.ensure_timesheet_default_group(
  p_company_id uuid,
  p_object_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
begin
  select g.id
    into v_group_id
  from public.timesheet_groups g
  where g.company_id = p_company_id
    and g.object_id = p_object_id
    and g.is_system = true
  limit 1;

  if v_group_id is not null then
    return v_group_id;
  end if;

  select g.id
    into v_group_id
  from public.timesheet_groups g
  where g.company_id = p_company_id
    and g.object_id = p_object_id
    and lower(btrim(g.name)) = 'общая'
  limit 1;

  if v_group_id is not null then
    update public.timesheet_groups
    set is_system = true,
        sort_order = 1000000,
        updated_at = now()
    where id = v_group_id;
    return v_group_id;
  end if;

  begin
    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      is_system,
      created_by,
      updated_at
    ) values (
      p_company_id,
      p_object_id,
      'Общая',
      1000000,
      true,
      null,
      now()
    )
    returning id into v_group_id;
  exception
    when unique_violation then
      select g.id
        into v_group_id
      from public.timesheet_groups g
      where g.company_id = p_company_id
        and g.object_id = p_object_id
        and g.is_system = true
      limit 1;
  end;

  return v_group_id;
end;
$$;

-- Backfill every currently active employee that has no group yet.
insert into public.timesheet_group_members (
  company_id,
  group_id,
  employee_id,
  assigned_by
)
select
  e.company_id,
  g.id,
  e.id,
  null
from public.employees e
join public.timesheet_groups g
  on g.company_id = e.company_id
 and g.object_id = e.object_id
 and g.is_system = true
where e.is_active = true
  and not exists (
    select 1
    from public.timesheet_group_members m
    where m.company_id = e.company_id
      and m.employee_id = e.id
  )
on conflict (company_id, employee_id) do nothing;

-- The result shape changes by adding is_system, so PostgreSQL requires a drop/recreate.
drop function if exists public.list_timesheet_groups(text);

create function public.list_timesheet_groups(
  p_object_name text default null
)
returns table (
  id uuid,
  object_id uuid,
  object_name text,
  name text,
  sort_order integer,
  is_system boolean,
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
    g.is_system,
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
  group by g.id, g.object_id, o.name, g.name, g.sort_order, g.is_system
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
  v_default_group_id uuid;
  v_employee_ids uuid[] := coalesce(p_employee_ids, '{}'::uuid[]);
  v_previous_employee_ids uuid[] := '{}'::uuid[];
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

  v_default_group_id := private.ensure_timesheet_default_group(
    v_company_id,
    v_object_id
  );

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
    select coalesce(max(g.sort_order) filter (where g.is_system = false), 0) + 10
      into v_next_order
    from public.timesheet_groups g
    where g.company_id = v_company_id
      and g.object_id = v_object_id;

    insert into public.timesheet_groups (
      company_id,
      object_id,
      name,
      sort_order,
      is_system,
      created_by,
      updated_at
    ) values (
      v_company_id,
      v_object_id,
      v_name,
      v_next_order,
      false,
      (select auth.uid()),
      now()
    )
    returning id into v_group_id;
  else
    if exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
        and g.is_system = true
    ) then
      raise exception 'Системную группу нельзя изменять';
    end if;

    if not exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
    ) then
      raise exception 'Группа не найдена';
    end if;

    if exists (
      select 1
      from public.timesheet_groups g
      where g.id = v_group_id
        and g.company_id = v_company_id
        and g.object_id <> v_object_id
    ) then
      raise exception 'Группу нельзя перенести на другой объект';
    end if;

    select coalesce(array_agg(m.employee_id), '{}'::uuid[])
      into v_previous_employee_ids
    from public.timesheet_group_members m
    where m.company_id = v_company_id
      and m.group_id = v_group_id;

    update public.timesheet_groups
    set name = v_name,
        updated_at = now()
    where id = v_group_id
      and company_id = v_company_id;
  end if;

  delete from public.timesheet_group_members
  where group_id = v_group_id
    and company_id = v_company_id;

  if cardinality(v_employee_ids) > 0 then
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

  -- Anyone removed from this custom group immediately falls back to «Общая».
  if cardinality(v_previous_employee_ids) > 0 then
    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_default_group_id,
      previous.employee_id,
      (select auth.uid())
    from unnest(v_previous_employee_ids) as previous(employee_id)
    join public.employees e
      on e.id = previous.employee_id
     and e.company_id = v_company_id
     and e.object_id = v_object_id
     and e.is_active = true
    where not (previous.employee_id = any(v_employee_ids))
    on conflict (company_id, employee_id) do nothing;
  end if;

  -- Repair any drift so the invariant holds for the whole object.
  insert into public.timesheet_group_members (
    company_id,
    group_id,
    employee_id,
    assigned_by
  )
  select
    e.company_id,
    v_default_group_id,
    e.id,
    (select auth.uid())
  from public.employees e
  where e.company_id = v_company_id
    and e.object_id = v_object_id
    and e.is_active = true
    and not exists (
      select 1
      from public.timesheet_group_members m
      where m.company_id = e.company_id
        and m.employee_id = e.id
    )
  on conflict (company_id, employee_id) do nothing;

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
  v_object_id uuid;
  v_is_system boolean;
  v_default_group_id uuid;
  v_employee_ids uuid[] := '{}'::uuid[];
begin
  if v_company_id is null or v_role <> 'admin' then
    raise exception 'Недостаточно прав для управления группами табеля'
      using errcode = '42501';
  end if;

  select g.object_id, g.is_system
    into v_object_id, v_is_system
  from public.timesheet_groups g
  where g.id = p_group_id
    and g.company_id = v_company_id
  limit 1;

  if v_object_id is null then
    return;
  end if;
  if v_is_system then
    raise exception 'Системную группу нельзя удалить';
  end if;

  select coalesce(array_agg(m.employee_id), '{}'::uuid[])
    into v_employee_ids
  from public.timesheet_group_members m
  where m.company_id = v_company_id
    and m.group_id = p_group_id;

  v_default_group_id := private.ensure_timesheet_default_group(
    v_company_id,
    v_object_id
  );

  delete from public.timesheet_groups
  where id = p_group_id
    and company_id = v_company_id;

  if cardinality(v_employee_ids) > 0 then
    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    )
    select
      v_company_id,
      v_default_group_id,
      removed.employee_id,
      (select auth.uid())
    from unnest(v_employee_ids) as removed(employee_id)
    join public.employees e
      on e.id = removed.employee_id
     and e.company_id = v_company_id
     and e.object_id = v_object_id
     and e.is_active = true
    on conflict (company_id, employee_id) do nothing;
  end if;
end;
$$;

-- New employees and employees moved between objects are always assigned immediately.
create or replace function private.assign_employee_timesheet_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_default_group_id uuid;
begin
  delete from public.timesheet_group_members m
  using public.timesheet_groups g
  where m.group_id = g.id
    and m.employee_id = new.id
    and (
      g.company_id <> new.company_id
      or g.object_id <> new.object_id
      or new.is_active is not true
    );

  if new.is_active is true then
    v_default_group_id := private.ensure_timesheet_default_group(
      new.company_id,
      new.object_id
    );

    insert into public.timesheet_group_members (
      company_id,
      group_id,
      employee_id,
      assigned_by
    ) values (
      new.company_id,
      v_default_group_id,
      new.id,
      (select auth.uid())
    )
    on conflict (company_id, employee_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists employees_cleanup_timesheet_group_members on public.employees;
drop trigger if exists employees_assign_timesheet_group on public.employees;
create trigger employees_assign_timesheet_group
  after insert or update of object_id, company_id, is_active on public.employees
  for each row execute function private.assign_employee_timesheet_group();

create or replace function private.ensure_object_timesheet_default_group()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_active is true then
    perform private.ensure_timesheet_default_group(new.company_id, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists objects_ensure_timesheet_default_group on public.objects;
create trigger objects_ensure_timesheet_default_group
  after insert or update of is_active on public.objects
  for each row execute function private.ensure_object_timesheet_default_group();

revoke all on function public.list_timesheet_groups(text) from public;
revoke all on function public.save_timesheet_group(uuid, text, text, uuid[]) from public;
revoke all on function public.delete_timesheet_group(uuid) from public;
grant execute on function public.list_timesheet_groups(text) to authenticated;
grant execute on function public.save_timesheet_group(uuid, text, text, uuid[]) to authenticated;
grant execute on function public.delete_timesheet_group(uuid) to authenticated;
