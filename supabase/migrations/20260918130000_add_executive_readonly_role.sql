-- Read-only executive ("Повелитель") role for the executive panel.
-- The role is company-wide for visibility, but receives no create/edit/delete
-- permissions. Manual "for sending" edits remain client-side only.

alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
  add constraint user_profiles_role_check check (
    role = any (array[
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'employee'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

alter table public.company_memberships
  drop constraint if exists company_memberships_role_check;
alter table public.company_memberships
  add constraint company_memberships_role_check check (
    role = any (array[
      'owner'::text,
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

alter table public.company_invitations
  drop constraint if exists company_invitations_role_check;
alter table public.company_invitations
  add constraint company_invitations_role_check check (
    role = any (array[
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

alter table public.role_permissions
  drop constraint if exists role_permissions_role_check;
alter table public.role_permissions
  add constraint role_permissions_role_check check (
    role_code = any (array[
      'owner'::text,
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

-- Keep notification schemas role-compatible even though the executive shell
-- deliberately has no notification tab.
alter table public.app_notifications
  drop constraint if exists app_notifications_source_role_check;
alter table public.app_notifications
  add constraint app_notifications_source_role_check check (
    source_role = any (array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

alter table public.app_notifications
  drop constraint if exists app_notifications_target_role_check;
alter table public.app_notifications
  add constraint app_notifications_target_role_check check (
    target_role is null or target_role = any (array[
      'admin'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ])
  );

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_roles_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_roles_check check (
    selected_roles <@ array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ]
  );

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_bell_roles_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_bell_roles_check check (
    selected_bell_roles <@ array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text,
      'executive'::text
    ]
  );

-- Normalize every currently supported specialist explicitly. In particular,
-- executive must never fall through to the legacy admin fallback.
create or replace function public.normalize_notification_role(p_role text)
returns text
language sql
immutable
as $function$
  select case lower(btrim(coalesce(p_role, '')))
    when 'owner' then 'admin'
    when 'developer' then 'admin'
    when 'accounting' then 'accountant'
    when 'accountant' then 'accountant'
    when 'admin' then 'admin'
    when 'foreman' then 'foreman'
    when 'hr' then 'hr'
    when 'lawyer' then 'lawyer'
    when 'procurement' then 'procurement'
    when 'estimator' then 'estimator'
    when 'executive' then 'executive'
    else 'admin'
  end;
$function$;

-- Keep direct membership policies aligned with the RPC/edge-function whitelist.
drop policy if exists company_memberships_insert_admins
  on public.company_memberships;
create policy company_memberships_insert_admins
on public.company_memberships
for insert
to authenticated
with check (
  (select public.is_company_admin(company_id))
  and role in (
    'admin',
    'developer',
    'foreman',
    'lawyer',
    'accountant',
    'hr',
    'procurement',
    'estimator',
    'executive'
  )
  and public.company_can_add_member(company_id)
);

drop policy if exists company_memberships_update_admins
  on public.company_memberships;
create policy company_memberships_update_admins
on public.company_memberships
for update
to authenticated
using (
  (select public.is_company_admin(company_id))
  and role <> 'owner'
)
with check (
  (select public.is_company_admin(company_id))
  and role in (
    'admin',
    'developer',
    'foreman',
    'lawyer',
    'accountant',
    'hr',
    'procurement',
    'estimator',
    'executive'
  )
);

-- Executive is company-wide, like estimator. The permission matrix below
-- still decides what can actually be read or changed.
create or replace function public.current_user_has_object_scope(p_object_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1
    from public.objects object_row
    left join public.object_memberships membership
      on membership.company_id = object_row.company_id
     and membership.object_id = object_row.id
     and membership.user_id = (select auth.uid())
    left join public.user_profiles profile
      on profile.id = (select auth.uid())
    where object_row.id = p_object_id
      and object_row.company_id = public.current_user_company_id()
      and (
        public.is_admin()
        or public.current_user_role() in ('estimator', 'executive')
        or membership.user_id is not null
        or lower(btrim(coalesce(profile.object_name, ''))) =
           lower(btrim(object_row.name))
      )
  );
$function$;

-- Strictly read-only defaults required by the two executive tabs.
insert into public.role_permissions (role_code, permission_code)
values
  ('executive', 'objects.view'),
  ('executive', 'tasks.view'),
  ('executive', 'employees.view'),
  ('executive', 'attendance.view'),
  ('executive', 'accounting.directory.view'),
  ('executive', 'accounting.attendance.view'),
  ('executive', 'accounting.payments.view')
on conflict (role_code, permission_code) do nothing;

-- Preserve the actual specialist role when switching active company.
create or replace function public.set_active_company(p_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_membership_role text;
  v_profile_role text;
  v_object_name text;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;

  select membership.role
    into v_membership_role
    from public.company_memberships membership
    join public.companies company on company.id = membership.company_id
   where membership.company_id = p_company_id
     and membership.user_id = v_user_id
     and membership.is_active = true
     and company.status = 'active';

  if not found then
    raise exception 'Нет доступа к этой компании';
  end if;

  v_profile_role := case
    when v_membership_role = 'owner' then 'admin'
    else v_membership_role
  end;

  if v_membership_role = 'foreman' then
    select object_row.name
      into v_object_name
      from public.object_memberships assignment
      join public.objects object_row
        on object_row.company_id = assignment.company_id
       and object_row.id = assignment.object_id
     where assignment.company_id = p_company_id
       and assignment.user_id = v_user_id
       and object_row.is_active = true
     order by assignment.created_at, object_row.name
     limit 1;
  else
    v_object_name := null;
  end if;

  update public.user_profiles profile
     set active_company_id = p_company_id,
         role = v_profile_role,
         object_name = v_object_name,
         is_active = true,
         updated_at = now()
   where profile.id = v_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  return jsonb_build_object(
    'company_id', p_company_id,
    'role', v_profile_role,
    'object_name', coalesce(v_object_name, '')
  );
end;
$function$;

revoke all on function public.set_active_company(uuid) from public, anon;
grant execute on function public.set_active_company(uuid) to authenticated;

-- Keep the latest person/profession synchronization semantics and only extend
-- the accepted role list with executive.
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
set search_path to 'public', 'auth', 'pg_temp'
as $function$
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

  select membership.role
    into v_actor_role
    from public.company_memberships membership
    join public.companies company on company.id = membership.company_id
   where membership.company_id = p_company_id
     and membership.user_id = v_actor_id
     and membership.is_active = true
     and membership.role in ('owner', 'admin', 'developer')
     and company.status = 'active';

  if v_actor_role is null then
    raise exception 'Изменять пользователей может только администратор или разработчик компании'
      using errcode = '42501';
  end if;

  if p_user_id = v_actor_id then
    raise exception 'Нельзя изменить собственную роль через управление командой'
      using errcode = '42501';
  end if;

  if p_role not in (
    'admin',
    'developer',
    'foreman',
    'lawyer',
    'accountant',
    'hr',
    'procurement',
    'estimator',
    'executive'
  ) then
    raise exception 'Недопустимая роль' using errcode = '22023';
  end if;

  select membership.role, membership.person_id
    into v_target_role, v_person_id
    from public.company_memberships membership
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id
   for update;

  if v_target_role is null then
    raise exception 'Пользователь не найден в компании';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Нельзя изменить роль владельца компании'
      using errcode = '42501';
  end if;

  if p_role = 'foreman' then
    select object_row.name
      into v_object_name
      from public.objects object_row
     where object_row.company_id = p_company_id
       and object_row.id = p_object_id
       and object_row.is_active = true;

    if v_object_name is null then
      raise exception 'Для прораба выберите действующий объект';
    end if;
  else
    p_object_id := null;
    v_object_name := null;
  end if;

  if v_person_id is null then
    select profile.full_name, profile.phone
      into v_profile_name, v_profile_phone
      from public.user_profiles profile
     where profile.id = p_user_id;

    v_person_id := private.resolve_company_person_identity(
      p_company_id,
      v_profile_name,
      v_profile_phone
    );
  end if;

  update public.company_memberships membership
     set role = p_role,
         person_id = coalesce(membership.person_id, v_person_id),
         is_active = true,
         updated_at = now()
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id;

  delete from public.object_memberships assignment
   where assignment.company_id = p_company_id
     and assignment.user_id = p_user_id;

  if p_role = 'foreman' then
    insert into public.object_memberships(
      company_id,
      object_id,
      user_id,
      created_by
    ) values (
      p_company_id,
      p_object_id,
      p_user_id,
      v_actor_id
    );
  end if;

  update public.user_profiles profile
     set profession = v_profession,
         role = case
           when profile.active_company_id = p_company_id then p_role
           else profile.role
         end,
         object_name = case
           when profile.active_company_id = p_company_id
             then case when p_role = 'foreman' then v_object_name else null end
           else profile.object_name
         end,
         updated_at = now()
   where profile.id = p_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  if v_person_id is not null then
    update public.employees employee
       set position = v_profession,
           updated_at = now()
     where employee.company_id = p_company_id
       and employee.person_id = v_person_id
       and employee.archived_at is null
       and employee.position is distinct from v_profession;

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
$function$;

revoke all on function public.update_company_member_access(
  uuid, uuid, text, text, uuid
) from public, anon;
grant execute on function public.update_company_member_access(
  uuid, uuid, text, text, uuid
) to authenticated;
