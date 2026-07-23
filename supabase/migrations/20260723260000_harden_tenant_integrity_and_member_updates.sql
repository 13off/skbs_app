-- Critical tenant-integrity hardening for core operational entities.
-- The existing data is validated before these constraints are applied.

create unique index if not exists employees_company_object_id_unique
  on public.employees (company_id, object_id, id);

create unique index if not exists payments_company_id_id_unique
  on public.payments (company_id, id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'object_memberships_company_user_membership_fkey'
      and conrelid = 'public.object_memberships'::regclass
  ) then
    alter table public.object_memberships
      add constraint object_memberships_company_user_membership_fkey
      foreign key (company_id, user_id)
      references public.company_memberships (company_id, user_id)
      on delete cascade
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'employees_company_object_fkey'
      and conrelid = 'public.employees'::regclass
  ) then
    alter table public.employees
      add constraint employees_company_object_fkey
      foreign key (company_id, object_id)
      references public.objects (company_id, id)
      on delete restrict
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'attendance_company_object_employee_fkey'
      and conrelid = 'public.attendance'::regclass
  ) then
    alter table public.attendance
      add constraint attendance_company_object_employee_fkey
      foreign key (company_id, object_id, employee_id)
      references public.employees (company_id, object_id, id)
      on delete cascade
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'payments_company_object_employee_fkey'
      and conrelid = 'public.payments'::regclass
  ) then
    alter table public.payments
      add constraint payments_company_object_employee_fkey
      foreign key (company_id, object_id, employee_id)
      references public.employees (company_id, object_id, id)
      on delete cascade
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'payment_receipts_company_payment_fkey'
      and conrelid = 'public.payment_receipts'::regclass
  ) then
    alter table public.payment_receipts
      add constraint payment_receipts_company_payment_fkey
      foreign key (company_id, payment_id)
      references public.payments (company_id, id)
      on delete cascade
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'tasks_company_object_fkey'
      and conrelid = 'public.tasks'::regclass
  ) then
    alter table public.tasks
      add constraint tasks_company_object_fkey
      foreign key (company_id, object_id)
      references public.objects (company_id, id)
      on delete restrict
      not valid;
  end if;
end;
$$;

alter table public.object_memberships
  validate constraint object_memberships_company_user_membership_fkey;
alter table public.employees
  validate constraint employees_company_object_fkey;
alter table public.attendance
  validate constraint attendance_company_object_employee_fkey;
alter table public.payments
  validate constraint payments_company_object_employee_fkey;
alter table public.payment_receipts
  validate constraint payment_receipts_company_payment_fkey;
alter table public.tasks
  validate constraint tasks_company_object_fkey;

create or replace function private.enforce_task_object_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_object_name text;
begin
  select object_row.name
    into v_object_name
    from public.objects object_row
   where object_row.company_id = new.company_id
     and object_row.id = new.object_id;

  if not found then
    raise exception 'Объект задачи не принадлежит выбранной компании'
      using errcode = '23514';
  end if;

  if lower(btrim(coalesce(new.object_name, '')))
       <> lower(btrim(coalesce(v_object_name, ''))) then
    raise exception 'Название объекта задачи не совпадает с выбранным объектом'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_task_object_identity() from public;

drop trigger if exists tasks_enforce_object_identity on public.tasks;
create trigger tasks_enforce_object_identity
before insert or update of company_id, object_id, object_name
on public.tasks
for each row execute function private.enforce_task_object_identity();

create or replace function private.enforce_payment_receipt_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee_id uuid;
begin
  select payment.employee_id
    into v_employee_id
    from public.payments payment
   where payment.company_id = new.company_id
     and payment.id = new.payment_id;

  if not found then
    raise exception 'Выплата не принадлежит выбранной компании'
      using errcode = '23514';
  end if;

  if new.employee_id is null then
    new.employee_id := v_employee_id;
  elsif new.employee_id <> v_employee_id then
    raise exception 'Чек относится к другому сотруднику'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_payment_receipt_identity() from public;

drop trigger if exists payment_receipts_enforce_identity
  on public.payment_receipts;
create trigger payment_receipts_enforce_identity
before insert or update of company_id, payment_id, employee_id
on public.payment_receipts
for each row execute function private.enforce_payment_receipt_identity();

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
set search_path = 'public', 'auth', 'pg_temp'
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_object_name text;
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

  if p_role not in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr') then
    raise exception 'Недопустимая роль' using errcode = '22023';
  end if;

  select membership.role
    into v_target_role
    from public.company_memberships membership
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id
   for update;

  if v_target_role is null then
    raise exception 'Пользователь не найден в компании' using errcode = 'P0002';
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
      raise exception 'Для прораба выберите действующий объект'
        using errcode = '22023';
    end if;
  else
    p_object_id := null;
    v_object_name := null;
  end if;

  update public.company_memberships membership
     set role = p_role,
         is_active = true,
         updated_at = now()
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id;

  delete from public.object_memberships assignment
   where assignment.company_id = p_company_id
     and assignment.user_id = p_user_id;

  if p_role = 'foreman' then
    insert into public.object_memberships (
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
     set profession = btrim(coalesce(p_profession, '')),
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
    raise exception 'Профиль пользователя не найден' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'updated', true,
    'company_id', p_company_id,
    'user_id', p_user_id,
    'role', p_role,
    'object_id', p_object_id,
    'object_name', coalesce(v_object_name, '')
  );
end;
$$;

revoke all on function public.update_company_member_access(
  uuid, uuid, text, text, uuid
) from public;
revoke execute on function public.update_company_member_access(
  uuid, uuid, text, text, uuid
) from anon;
grant execute on function public.update_company_member_access(
  uuid, uuid, text, text, uuid
) to authenticated;

create or replace function public.remove_company_member(
  p_company_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'auth', 'pg_temp'
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_target_email text;
  v_next_company_id uuid;
  v_next_role text;
  v_next_profile_role text;
  v_next_object_name text;
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
    raise exception 'Удалять пользователей может только администратор или разработчик компании'
      using errcode = '42501';
  end if;

  if p_user_id = v_actor_id then
    raise exception 'Нельзя удалить самого себя' using errcode = '42501';
  end if;

  select membership.role
    into v_target_role
    from public.company_memberships membership
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id
   for update;

  if v_target_role is null then
    raise exception 'Пользователь уже удалён из компании';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Нельзя удалить владельца компании' using errcode = '42501';
  end if;

  select lower(account.email)
    into v_target_email
    from auth.users account
   where account.id = p_user_id;

  update public.company_invitations invitation
     set status = 'revoked',
         updated_at = now()
   where invitation.company_id = p_company_id
     and invitation.status = 'pending'
     and (
       invitation.invited_user_id = p_user_id
       or (v_target_email is not null and lower(invitation.email) = v_target_email)
     );

  delete from public.push_device_tokens token
   where token.company_id = p_company_id
     and token.user_id = p_user_id;

  delete from public.object_memberships assignment
   where assignment.company_id = p_company_id
     and assignment.user_id = p_user_id;

  delete from public.company_memberships membership
   where membership.company_id = p_company_id
     and membership.user_id = p_user_id;

  if exists (
    select 1
    from public.user_profiles profile
    where profile.id = p_user_id
      and profile.active_company_id = p_company_id
  ) then
    select membership.company_id, membership.role
      into v_next_company_id, v_next_role
      from public.company_memberships membership
     where membership.user_id = p_user_id
       and membership.is_active = true
     order by membership.created_at
     limit 1;

    if v_next_company_id is null then
      update public.user_profiles profile
         set active_company_id = null,
             role = 'foreman',
             object_name = null,
             updated_at = now()
       where profile.id = p_user_id;
    else
      v_next_profile_role := case
        when v_next_role = 'owner' then 'admin'
        else v_next_role
      end;

      if v_next_role = 'foreman' then
        select object_row.name
          into v_next_object_name
          from public.object_memberships assignment
          join public.objects object_row
            on object_row.company_id = assignment.company_id
           and object_row.id = assignment.object_id
         where assignment.company_id = v_next_company_id
           and assignment.user_id = p_user_id
         order by assignment.created_at
         limit 1;
      end if;

      update public.user_profiles profile
         set active_company_id = v_next_company_id,
             role = v_next_profile_role,
             object_name = case
               when v_next_role = 'foreman' then v_next_object_name
               else null
             end,
             updated_at = now()
       where profile.id = p_user_id;
    end if;
  end if;

  return jsonb_build_object(
    'removed', true,
    'company_id', p_company_id,
    'user_id', p_user_id
  );
end;
$$;

revoke all on function public.remove_company_member(uuid, uuid) from public;
revoke execute on function public.remove_company_member(uuid, uuid) from anon;
grant execute on function public.remove_company_member(uuid, uuid) to authenticated;
