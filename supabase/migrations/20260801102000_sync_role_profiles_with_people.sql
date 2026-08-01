alter table public.company_memberships
  add column if not exists person_id uuid;

alter table public.company_memberships
  drop constraint if exists company_memberships_person_id_fkey;

alter table public.company_memberships
  add constraint company_memberships_person_id_fkey
  foreign key (person_id)
  references private.people(id)
  on delete set null;

create index if not exists company_memberships_person_id_idx
  on public.company_memberships(company_id, person_id)
  where person_id is not null;

create index if not exists people_company_normalized_phone_idx
  on private.people(company_id, private.normalized_phone(phone))
  where private.normalized_phone(phone) <> '';

create index if not exists people_company_normalized_name_idx
  on private.people(company_id, private.normalized_employee_name(fio));

create or replace function private.resolve_company_person_identity(
  p_company_id uuid,
  p_full_name text,
  p_phone text
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_phone text := private.normalized_phone(p_phone);
  v_name text := private.normalized_employee_name(p_full_name);
  v_matches uuid[];
begin
  if p_company_id is null then
    return null;
  end if;

  if char_length(v_phone) >= 7 then
    select array_agg(p.id order by p.id)
      into v_matches
    from private.people p
    where p.company_id = p_company_id
      and private.normalized_phone(p.phone) = v_phone;

    if coalesce(array_length(v_matches, 1), 0) = 1 then
      return v_matches[1];
    end if;
  end if;

  if v_name <> '' then
    select array_agg(p.id order by p.id)
      into v_matches
    from private.people p
    where p.company_id = p_company_id
      and private.normalized_employee_name(p.fio) = v_name;

    if coalesce(array_length(v_matches, 1), 0) = 1 then
      return v_matches[1];
    end if;
  end if;

  return null;
end;
$$;

revoke all on function private.resolve_company_person_identity(uuid, text, text)
  from public, anon, authenticated;

create or replace function private.guard_company_membership_person()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.person_id is not null and not exists (
    select 1
    from private.people p
    where p.id = new.person_id
      and p.company_id = new.company_id
  ) then
    raise exception 'Профиль человека относится к другой компании';
  end if;

  return new;
end;
$$;

revoke all on function private.guard_company_membership_person()
  from public, anon, authenticated;

drop trigger if exists company_memberships_guard_person on public.company_memberships;
create trigger company_memberships_guard_person
before insert or update of company_id, person_id
on public.company_memberships
for each row
execute function private.guard_company_membership_person();

create or replace function private.try_service_link_company_membership_person()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_profile public.user_profiles%rowtype;
  v_person_id uuid;
begin
  if new.person_id is not null or coalesce(auth.role(), '') <> 'service_role' then
    return new;
  end if;

  select *
    into v_profile
  from public.user_profiles up
  where up.id = new.user_id;

  if not found then
    return new;
  end if;

  v_person_id := private.resolve_company_person_identity(
    new.company_id,
    v_profile.full_name,
    v_profile.phone
  );

  if v_person_id is not null then
    update public.company_memberships cm
    set person_id = v_person_id,
        updated_at = now()
    where cm.company_id = new.company_id
      and cm.user_id = new.user_id
      and cm.person_id is null;
  end if;

  return new;
end;
$$;

revoke all on function private.try_service_link_company_membership_person()
  from public, anon, authenticated;

drop trigger if exists company_memberships_service_link_person
  on public.company_memberships;
create trigger company_memberships_service_link_person
after insert
on public.company_memberships
for each row
execute function private.try_service_link_company_membership_person();

create or replace function private.try_service_link_profile_memberships()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_membership record;
  v_person_id uuid;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    return new;
  end if;

  for v_membership in
    select cm.company_id, cm.user_id
    from public.company_memberships cm
    where cm.user_id = new.id
      and cm.person_id is null
  loop
    v_person_id := private.resolve_company_person_identity(
      v_membership.company_id,
      new.full_name,
      new.phone
    );

    if v_person_id is not null then
      update public.company_memberships cm
      set person_id = v_person_id,
          updated_at = now()
      where cm.company_id = v_membership.company_id
        and cm.user_id = v_membership.user_id
        and cm.person_id is null;
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function private.try_service_link_profile_memberships()
  from public, anon, authenticated;

drop trigger if exists user_profiles_service_link_memberships
  on public.user_profiles;
create trigger user_profiles_service_link_memberships
after insert or update of full_name, phone, active_company_id
on public.user_profiles
for each row
execute function private.try_service_link_profile_memberships();

update public.company_memberships cm
set person_id = eal.person_id,
    updated_at = now()
from public.employee_account_links eal
where cm.company_id = eal.company_id
  and cm.user_id = eal.user_id
  and eal.is_active = true
  and cm.person_id is null;

create or replace function private.sync_person_to_user_profiles(
  p_company_id uuid,
  p_person_id uuid,
  p_full_name text,
  p_phone text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_full_name text := btrim(coalesce(p_full_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
begin
  if p_company_id is null or p_person_id is null or v_full_name = '' then
    return;
  end if;

  update public.user_profiles up
  set full_name = v_full_name,
      phone = case when v_phone <> '' then v_phone else up.phone end,
      updated_at = now()
  where up.id in (
    select eal.user_id
    from public.employee_account_links eal
    where eal.company_id = p_company_id
      and eal.person_id = p_person_id
      and eal.is_active = true
    union
    select cm.user_id
    from public.company_memberships cm
    where cm.company_id = p_company_id
      and cm.person_id = p_person_id
      and cm.is_active = true
  )
  and (
    up.full_name is distinct from v_full_name
    or (v_phone <> '' and up.phone is distinct from v_phone)
  );
end;
$$;

revoke all on function private.sync_person_to_user_profiles(uuid, uuid, text, text)
  from public, anon, authenticated;

create or replace function private.sync_employee_personal_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.person_id is null then
    return new;
  end if;

  update private.people p
  set fio = coalesce(nullif(btrim(new.fio), ''), p.fio),
      phone = case
        when btrim(coalesce(new.phone, '')) <> '' then btrim(new.phone)
        else p.phone
      end,
      updated_at = now()
  where p.id = new.person_id;

  update public.employees sibling
  set fio = new.fio,
      phone = case
        when btrim(coalesce(new.phone, '')) <> '' then new.phone
        else sibling.phone
      end,
      updated_at = now()
  where sibling.person_id = new.person_id
    and sibling.id <> new.id
    and (
      sibling.fio is distinct from new.fio
      or (
        btrim(coalesce(new.phone, '')) <> ''
        and sibling.phone is distinct from new.phone
      )
    );

  perform private.sync_person_to_user_profiles(
    new.company_id,
    new.person_id,
    new.fio,
    new.phone
  );

  return new;
end;
$$;

revoke all on function private.sync_employee_personal_fields()
  from public, anon, authenticated;

create or replace function public.get_current_user_personal_profile()
returns table (
  full_name text,
  phone text,
  avatar_path text
)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_person_id uuid;
begin
  if v_user_id is null then
    raise exception 'Пользователь не авторизован';
  end if;

  select up.active_company_id
    into v_company_id
  from public.user_profiles up
  where up.id = v_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  if v_company_id is not null then
    select cm.person_id
      into v_person_id
    from public.company_memberships cm
    where cm.company_id = v_company_id
      and cm.user_id = v_user_id
      and cm.is_active = true
    limit 1;

    if v_person_id is null then
      select eal.person_id
        into v_person_id
      from public.employee_account_links eal
      where eal.company_id = v_company_id
        and eal.user_id = v_user_id
        and eal.is_active = true
      limit 1;
    end if;
  end if;

  return query
  select
    coalesce(nullif(btrim(p.fio), ''), up.full_name),
    coalesce(nullif(btrim(p.phone), ''), up.phone, ''),
    coalesce(up.avatar_path, '')
  from public.user_profiles up
  left join private.people p on p.id = v_person_id
  where up.id = v_user_id;
end;
$$;

revoke all on function public.get_current_user_personal_profile()
  from public, anon;
grant execute on function public.get_current_user_personal_profile()
  to authenticated, service_role;

create or replace function public.update_current_user_profile(
  p_full_name text,
  p_phone text,
  p_avatar_path text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth, storage, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_full_name text := btrim(coalesce(p_full_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_avatar_path text := btrim(coalesce(p_avatar_path, ''));
  v_company_id uuid;
  v_person_id uuid;
  v_employee_id uuid;
begin
  if v_user_id is null then
    raise exception 'Пользователь не авторизован';
  end if;

  if char_length(v_full_name) < 2 then
    raise exception 'Укажите ФИО';
  end if;

  if char_length(v_full_name) > 160 then
    raise exception 'ФИО слишком длинное';
  end if;

  if char_length(v_phone) > 40 then
    raise exception 'Номер телефона слишком длинный';
  end if;

  if v_avatar_path <> ''
     and v_avatar_path not like v_user_id::text || '/%' then
    raise exception 'Недопустимый путь фотографии';
  end if;

  select up.active_company_id
    into v_company_id
  from public.user_profiles up
  where up.id = v_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  if v_company_id is not null then
    select cm.person_id
      into v_person_id
    from public.company_memberships cm
    where cm.company_id = v_company_id
      and cm.user_id = v_user_id
      and cm.is_active = true
    limit 1;

    if v_person_id is null then
      select eal.person_id
        into v_person_id
      from public.employee_account_links eal
      where eal.company_id = v_company_id
        and eal.user_id = v_user_id
        and eal.is_active = true
      limit 1;
    end if;
  end if;

  update public.user_profiles
  set full_name = v_full_name,
      phone = v_phone,
      avatar_path = v_avatar_path,
      updated_at = now()
  where id = v_user_id;

  if v_person_id is null then
    return;
  end if;

  update private.people p
  set fio = v_full_name,
      phone = case when v_phone <> '' then v_phone else p.phone end,
      updated_at = now()
  where p.id = v_person_id
    and p.company_id = v_company_id;

  select e.id
    into v_employee_id
  from public.employees e
  where e.company_id = v_company_id
    and e.person_id = v_person_id
  order by
    (e.archived_at is null) desc,
    e.is_active desc,
    e.updated_at desc
  limit 1;

  if v_employee_id is not null then
    update public.employees e
    set fio = v_full_name,
        phone = case when v_phone <> '' then v_phone else e.phone end,
        updated_at = now()
    where e.id = v_employee_id;
  else
    perform private.sync_person_to_user_profiles(
      v_company_id,
      v_person_id,
      v_full_name,
      v_phone
    );
  end if;
end;
$$;

revoke all on function public.update_current_user_profile(text, text, text)
  from public, anon;
grant execute on function public.update_current_user_profile(text, text, text)
  to authenticated, service_role;

create or replace function public.update_company_member_access(
  p_company_id uuid,
  p_user_id uuid,
  p_role text,
  p_profession text default '',
  p_object_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_object_name text;
  v_person_id uuid;
  v_profile_name text;
  v_profile_phone text;
begin
  if v_actor_id is null then
    raise exception 'Требуется вход в аккаунт' using errcode = '42501';
  end if;

  select m.role into v_actor_role
  from public.company_memberships m
  join public.companies c on c.id = m.company_id
  where m.company_id = p_company_id
    and m.user_id = v_actor_id
    and m.is_active = true
    and m.role in ('owner', 'admin', 'developer')
    and c.status = 'active';

  if v_actor_role is null then
    raise exception 'Изменять пользователей может только администратор или разработчик компании'
      using errcode = '42501';
  end if;

  if p_user_id = v_actor_id then
    raise exception 'Нельзя изменить собственную роль через управление командой'
      using errcode = '42501';
  end if;

  if p_role not in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr') then
    raise exception 'Недопустимая роль' using errcode = '22023';
  end if;

  select m.role, m.person_id
    into v_target_role, v_person_id
  from public.company_memberships m
  where m.company_id = p_company_id and m.user_id = p_user_id
  for update;

  if v_target_role is null then
    raise exception 'Пользователь не найден в компании';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Нельзя изменить роль владельца компании'
      using errcode = '42501';
  end if;

  if p_role = 'foreman' then
    select o.name into v_object_name
    from public.objects o
    where o.company_id = p_company_id
      and o.id = p_object_id
      and o.is_active = true;

    if v_object_name is null then
      raise exception 'Для прораба выберите действующий объект';
    end if;
  else
    p_object_id := null;
    v_object_name := null;
  end if;

  if v_person_id is null then
    select up.full_name, up.phone
      into v_profile_name, v_profile_phone
    from public.user_profiles up
    where up.id = p_user_id;

    v_person_id := private.resolve_company_person_identity(
      p_company_id,
      v_profile_name,
      v_profile_phone
    );
  end if;

  update public.company_memberships m
  set role = p_role,
      person_id = coalesce(m.person_id, v_person_id),
      is_active = true,
      updated_at = now()
  where m.company_id = p_company_id and m.user_id = p_user_id;

  delete from public.object_memberships a
  where a.company_id = p_company_id and a.user_id = p_user_id;

  if p_role = 'foreman' then
    insert into public.object_memberships(company_id, object_id, user_id, created_by)
    values (p_company_id, p_object_id, p_user_id, v_actor_id);
  end if;

  update public.user_profiles p
  set profession = btrim(coalesce(p_profession, '')),
      role = case when p.active_company_id = p_company_id then p_role else p.role end,
      object_name = case
        when p.active_company_id = p_company_id
          then case when p_role = 'foreman' then v_object_name else null end
        else p.object_name
      end,
      updated_at = now()
  where p.id = p_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  if v_person_id is not null then
    perform private.sync_person_to_user_profiles(
      p_company_id,
      v_person_id,
      coalesce(v_profile_name, ''),
      coalesce(v_profile_phone, '')
    );
  end if;

  return jsonb_build_object(
    'updated', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'role', p_role,
    'object_id', p_object_id,
    'object_name', coalesce(v_object_name, ''),
    'person_id', v_person_id
  );
end;
$$;

revoke all on function public.update_company_member_access(uuid, uuid, text, text, uuid)
  from public, anon;
grant execute on function public.update_company_member_access(uuid, uuid, text, text, uuid)
  to authenticated, service_role;
