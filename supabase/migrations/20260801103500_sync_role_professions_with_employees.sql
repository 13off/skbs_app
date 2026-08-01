create or replace function private.sync_employee_profession_to_user_profiles(
  p_company_id uuid,
  p_person_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_profession text;
begin
  if p_company_id is null or p_person_id is null then
    return;
  end if;

  select btrim(coalesce(e.position, ''))
    into v_profession
  from public.employees e
  where e.company_id = p_company_id
    and e.person_id = p_person_id
  order by
    (e.archived_at is null) desc,
    e.is_active desc,
    e.updated_at desc,
    e.id
  limit 1;

  if not found then
    return;
  end if;

  update public.user_profiles up
  set profession = v_profession,
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
  and up.profession is distinct from v_profession;
end;
$$;

revoke all on function private.sync_employee_profession_to_user_profiles(uuid, uuid)
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

  perform private.sync_employee_profession_to_user_profiles(
    new.company_id,
    new.person_id
  );

  return new;
end;
$$;

revoke all on function private.sync_employee_personal_fields()
  from public, anon, authenticated;

with canonical_employee as (
  select distinct on (e.company_id, e.person_id)
    e.company_id,
    e.person_id,
    btrim(e.position) as profession
  from public.employees e
  where e.person_id is not null
    and btrim(coalesce(e.position, '')) <> ''
  order by
    e.company_id,
    e.person_id,
    (e.archived_at is null) desc,
    e.is_active desc,
    e.updated_at desc,
    e.id
), linked_accounts as (
  select cm.company_id, cm.person_id, cm.user_id
  from public.company_memberships cm
  where cm.person_id is not null
    and cm.is_active = true
  union
  select eal.company_id, eal.person_id, eal.user_id
  from public.employee_account_links eal
  where eal.is_active = true
)
update public.user_profiles up
set profession = canonical_employee.profession,
    updated_at = now()
from linked_accounts
join canonical_employee
  on canonical_employee.company_id = linked_accounts.company_id
 and canonical_employee.person_id = linked_accounts.person_id
where up.id = linked_accounts.user_id
  and up.profession is distinct from canonical_employee.profession;

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
  v_profession text := btrim(coalesce(p_profession, ''));
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
  set profession = v_profession,
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
    update public.employees e
    set position = v_profession,
        updated_at = now()
    where e.company_id = p_company_id
      and e.person_id = v_person_id
      and e.archived_at is null
      and e.position is distinct from v_profession;

    perform private.sync_person_to_user_profiles(
      p_company_id,
      v_person_id,
      coalesce(v_profile_name, ''),
      coalesce(v_profile_phone, '')
    );

    perform private.sync_employee_profession_to_user_profiles(
      p_company_id,
      v_person_id
    );
  end if;

  return jsonb_build_object(
    'updated', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'role', p_role,
    'object_id', p_object_id,
    'object_name', coalesce(v_object_name, ''),
    'person_id', v_person_id,
    'profession', v_profession
  );
end;
$$;

revoke all on function public.update_company_member_access(uuid, uuid, text, text, uuid)
  from public, anon;
grant execute on function public.update_company_member_access(uuid, uuid, text, text, uuid)
  to authenticated, service_role;
