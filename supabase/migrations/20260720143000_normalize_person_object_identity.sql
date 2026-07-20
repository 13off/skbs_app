create unique index if not exists objects_company_normalized_name_key
  on public.objects(company_id, lower(btrim(name)));

create table if not exists private.people (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  identity_key text not null,
  fio text not null default '',
  phone text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, identity_key)
);

revoke all on table private.people from public, anon, authenticated;
create index if not exists people_company_id_idx
  on private.people(company_id);

create or replace function private.normalized_employee_name(p_fio text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select lower(regexp_replace(btrim(coalesce(p_fio, '')), '\s+', ' ', 'g'));
$$;

create or replace function private.normalized_phone(p_phone text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
$$;

revoke all on function private.normalized_employee_name(text)
  from public, anon, authenticated;
revoke all on function private.normalized_phone(text)
  from public, anon, authenticated;

alter table public.employees
  add column if not exists person_id uuid
    references private.people(id) on delete restrict,
  add column if not exists object_id uuid
    references public.objects(id) on delete restrict;

alter table public.tasks
  add column if not exists object_id uuid
    references public.objects(id) on delete restrict;

alter table public.attendance
  add column if not exists object_id uuid
    references public.objects(id) on delete restrict;

alter table public.payments
  add column if not exists object_id uuid
    references public.objects(id) on delete restrict;

alter table public.project_milestones
  add column if not exists object_id uuid
    references public.objects(id) on delete restrict;

-- Служебный backfill не должен создавать рабочие уведомления, менять автора
-- табеля или запускать проверки фотографий задач.
alter table public.employees disable trigger user;
alter table public.tasks disable trigger user;
alter table public.attendance disable trigger user;
alter table public.payments disable trigger user;
alter table public.project_milestones disable trigger user;

update public.employees e
set object_id = o.id
from public.objects o
where e.object_id is null
  and o.company_id = e.company_id
  and lower(btrim(o.name)) = lower(btrim(e.object_name));

update public.tasks t
set object_id = o.id
from public.objects o
where t.object_id is null
  and o.company_id = t.company_id
  and lower(btrim(o.name)) = lower(btrim(t.object_name));

update public.attendance a
set object_id = o.id
from public.objects o
where a.object_id is null
  and o.company_id = a.company_id
  and lower(btrim(o.name)) = lower(btrim(a.object_name));

update public.project_milestones m
set object_id = o.id
from public.objects o
where m.object_id is null
  and o.company_id = m.company_id
  and lower(btrim(o.name)) = lower(btrim(m.object_name));

-- Объект выплаты фиксируется на момент её создания и впоследствии не
-- перемещается вместе с текущей карточкой сотрудника.
update public.payments p
set object_id = e.object_id
from public.employees e
where p.object_id is null
  and e.id = p.employee_id
  and e.company_id = p.company_id;

create temporary table employee_identity_backfill
on commit drop
as
with normalized as (
  select
    e.id,
    e.company_id,
    e.fio,
    e.phone,
    e.is_active,
    private.normalized_employee_name(e.fio) as normalized_name,
    private.normalized_phone(e.phone) as phone_digits
  from public.employees e
), grouped as (
  select
    n.*,
    count(*) over (
      partition by n.company_id, n.normalized_name
    ) as same_name_count,
    count(*) filter (where n.is_active) over (
      partition by n.company_id, n.normalized_name
    ) as same_name_active_count
  from normalized n
)
select
  g.id as employee_id,
  g.company_id,
  g.fio,
  g.phone,
  case
    when g.phone_digits <> ''
      then g.normalized_name || '|phone:' || g.phone_digits
    when g.same_name_count > 1 and g.same_name_active_count <= 1
      then g.normalized_name || '|legacy-copy'
    else g.normalized_name || '|employee:' || g.id::text
  end as identity_key
from grouped g;

insert into private.people(company_id, identity_key, fio, phone)
select
  b.company_id,
  b.identity_key,
  min(b.fio),
  coalesce(max(nullif(btrim(b.phone), '')), '')
from employee_identity_backfill b
group by b.company_id, b.identity_key
on conflict (company_id, identity_key) do update
set
  fio = excluded.fio,
  phone = case
    when excluded.phone <> '' then excluded.phone
    else private.people.phone
  end,
  updated_at = now();

update public.employees e
set person_id = p.id
from employee_identity_backfill b
join private.people p
  on p.company_id = b.company_id
 and p.identity_key = b.identity_key
where e.id = b.employee_id
  and e.person_id is null;

alter table public.employees enable trigger user;
alter table public.tasks enable trigger user;
alter table public.attendance enable trigger user;
alter table public.payments enable trigger user;
alter table public.project_milestones enable trigger user;

create or replace function private.ensure_employee_identity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_normalized_name text;
  v_phone_digits text;
  v_identity_key text;
begin
  if new.company_id is null then
    raise exception 'Для сотрудника не определена компания';
  end if;

  if new.person_id is not null then
    if not exists (
      select 1
      from private.people p
      where p.id = new.person_id
        and p.company_id = new.company_id
    ) then
      raise exception 'Профиль человека относится к другой компании';
    end if;

    update private.people p
    set
      fio = coalesce(nullif(btrim(new.fio), ''), p.fio),
      phone = case
        when btrim(coalesce(new.phone, '')) <> '' then btrim(new.phone)
        else p.phone
      end,
      updated_at = now()
    where p.id = new.person_id;

    return new;
  end if;

  v_normalized_name := private.normalized_employee_name(new.fio);
  v_phone_digits := private.normalized_phone(new.phone);

  if v_normalized_name = '' then
    raise exception 'Введите ФИО сотрудника';
  end if;

  -- Телефон позволяет безопасно узнать уже существующего человека.
  -- При пустом телефоне создаём отдельный профиль: однофамильцев нельзя
  -- объединять автоматически. Копирование между объектами передаёт person_id.
  v_identity_key := case
    when v_phone_digits <> ''
      then v_normalized_name || '|phone:' || v_phone_digits
    else v_normalized_name || '|employee:' || new.id::text
  end;

  insert into private.people(company_id, identity_key, fio, phone)
  values (
    new.company_id,
    v_identity_key,
    btrim(coalesce(new.fio, '')),
    btrim(coalesce(new.phone, ''))
  )
  on conflict (company_id, identity_key) do update
  set
    fio = excluded.fio,
    phone = case
      when excluded.phone <> '' then excluded.phone
      else private.people.phone
    end,
    updated_at = now()
  returning id into new.person_id;

  return new;
end;
$$;

create or replace function private.sync_named_object_reference()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_object_id uuid;
  v_object_name text;
  v_name_was_changed boolean := false;
  v_id_was_changed boolean := false;
begin
  if new.company_id is null then
    raise exception 'Не определена компания записи';
  end if;

  if tg_op = 'UPDATE' then
    v_name_was_changed := new.object_name is distinct from old.object_name;
    v_id_was_changed := new.object_id is distinct from old.object_id;
  end if;

  if tg_op = 'UPDATE' and v_name_was_changed and not v_id_was_changed then
    select o.id, o.name
      into v_object_id, v_object_name
    from public.objects o
    where o.company_id = new.company_id
      and lower(btrim(o.name)) = lower(btrim(coalesce(new.object_name, '')));
  elsif new.object_id is not null then
    select o.id, o.name
      into v_object_id, v_object_name
    from public.objects o
    where o.id = new.object_id
      and o.company_id = new.company_id;
  else
    select o.id, o.name
      into v_object_id, v_object_name
    from public.objects o
    where o.company_id = new.company_id
      and lower(btrim(o.name)) = lower(btrim(coalesce(new.object_name, '')));
  end if;

  if v_object_id is null then
    raise exception 'Объект не найден или относится к другой компании';
  end if;

  new.object_id := v_object_id;
  new.object_name := v_object_name;
  return new;
end;
$$;

create or replace function private.sync_payment_object_reference()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_object_id uuid;
begin
  select e.object_id
    into v_object_id
  from public.employees e
  where e.id = new.employee_id
    and e.company_id = new.company_id;

  if v_object_id is null then
    raise exception 'Не удалось определить объект выплаты по сотруднику';
  end if;

  new.object_id := v_object_id;
  return new;
end;
$$;

create or replace function private.sync_object_legacy_names()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.name is not distinct from old.name then
    return new;
  end if;

  update public.employees
  set object_name = new.name
  where object_id = new.id
    and object_name is distinct from new.name;

  update public.tasks
  set object_name = new.name
  where object_id = new.id
    and object_name is distinct from new.name;

  update public.attendance
  set object_name = new.name
  where object_id = new.id
    and object_name is distinct from new.name;

  update public.project_milestones
  set object_name = new.name
  where object_id = new.id
    and object_name is distinct from new.name;

  update public.user_profiles
  set object_name = new.name
  where active_company_id = new.company_id
    and lower(btrim(coalesce(object_name, ''))) = lower(btrim(old.name));

  return new;
end;
$$;

revoke all on function private.ensure_employee_identity()
  from public, anon, authenticated;
revoke all on function private.sync_named_object_reference()
  from public, anon, authenticated;
revoke all on function private.sync_payment_object_reference()
  from public, anon, authenticated;
revoke all on function private.sync_object_legacy_names()
  from public, anon, authenticated;

drop trigger if exists employees_00_identity on public.employees;
create trigger employees_00_identity
before insert or update of company_id, fio, phone, person_id
on public.employees
for each row execute function private.ensure_employee_identity();

drop trigger if exists employees_01_object_reference on public.employees;
create trigger employees_01_object_reference
before insert or update of company_id, object_id, object_name
on public.employees
for each row execute function private.sync_named_object_reference();

drop trigger if exists tasks_00_object_reference on public.tasks;
create trigger tasks_00_object_reference
before insert or update of company_id, object_id, object_name
on public.tasks
for each row execute function private.sync_named_object_reference();

drop trigger if exists attendance_00_object_reference on public.attendance;
create trigger attendance_00_object_reference
before insert or update of company_id, object_id, object_name
on public.attendance
for each row execute function private.sync_named_object_reference();

drop trigger if exists project_milestones_00_object_reference
  on public.project_milestones;
create trigger project_milestones_00_object_reference
before insert or update of company_id, object_id, object_name
on public.project_milestones
for each row execute function private.sync_named_object_reference();

drop trigger if exists payments_00_object_reference on public.payments;
create trigger payments_00_object_reference
before insert or update of company_id, employee_id
on public.payments
for each row execute function private.sync_payment_object_reference();

drop trigger if exists objects_sync_legacy_names_after_rename
  on public.objects;
create trigger objects_sync_legacy_names_after_rename
after update of name
on public.objects
for each row execute function private.sync_object_legacy_names();

alter table public.employees alter column person_id set not null;
alter table public.employees alter column object_id set not null;
alter table public.tasks alter column object_id set not null;
alter table public.attendance alter column object_id set not null;
alter table public.payments alter column object_id set not null;
alter table public.project_milestones alter column object_id set not null;

create index if not exists employees_person_id_idx
  on public.employees(person_id);
create index if not exists employees_company_object_id_idx
  on public.employees(company_id, object_id);
create index if not exists tasks_company_object_id_date_idx
  on public.tasks(company_id, object_id, task_date);
create index if not exists attendance_company_object_id_date_idx
  on public.attendance(company_id, object_id, work_date);
create index if not exists payments_company_object_id_period_idx
  on public.payments(company_id, object_id, period_year, period_month);
create index if not exists project_milestones_company_object_id_idx
  on public.project_milestones(company_id, object_id);
