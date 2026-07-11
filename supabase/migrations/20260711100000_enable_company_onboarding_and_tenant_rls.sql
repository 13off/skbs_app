-- Tenant isolation, self-service company onboarding and company switching.

alter table public.companies
  add column if not exists plan_code text not null default 'trial'
    check (plan_code in ('trial', 'starter', 'business', 'enterprise', 'internal')),
  add column if not exists billing_status text not null default 'trialing'
    check (billing_status in ('trialing', 'active', 'past_due', 'canceled', 'internal')),
  add column if not exists trial_ends_at timestamptz default (now() + interval '14 days'),
  add column if not exists seat_limit integer not null default 10 check (seat_limit > 0),
  add column if not exists object_limit integer not null default 5 check (object_limit > 0);

update public.companies
set plan_code = 'internal',
    billing_status = 'internal',
    trial_ends_at = null,
    seat_limit = 1000,
    object_limit = 1000
where slug = 'skbs';

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case m.role when 'owner' then 'admin' else m.role end
  from public.company_memberships m
  join public.user_profiles p on p.id = m.user_id
  join public.companies c on c.id = m.company_id
  where m.user_id = (select auth.uid())
    and m.company_id = public.current_user_company_id()
    and m.is_active = true
    and p.is_active = true
    and c.status = 'active'
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_user_role() = 'admin', false);
$$;

create or replace function public.is_foreman()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_user_role() = 'foreman', false);
$$;

create or replace function public.current_user_object_name()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (
      select o.name
      from public.object_memberships om
      join public.objects o
        on o.company_id = om.company_id and o.id = om.object_id
      where om.user_id = (select auth.uid())
        and om.company_id = public.current_user_company_id()
        and o.is_active = true
      order by om.created_at, o.name
      limit 1
    ),
    (
      select nullif(btrim(p.object_name), '')
      from public.user_profiles p
      where p.id = (select auth.uid())
      limit 1
    )
  );
$$;

create or replace function public.can_access_object(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.is_admin()
    or (
      public.is_foreman()
      and exists (
        select 1
        from public.objects o
        left join public.object_memberships om
          on om.company_id = o.company_id
         and om.object_id = o.id
         and om.user_id = (select auth.uid())
        left join public.user_profiles p
          on p.id = (select auth.uid())
        where o.company_id = public.current_user_company_id()
          and o.is_active = true
          and lower(btrim(o.name)) = lower(btrim(coalesce(p_object_name, '')))
          and (
            om.user_id is not null
            or lower(btrim(coalesce(p.object_name, ''))) = lower(btrim(o.name))
          )
      )
    );
$$;

create or replace function public.is_active_object(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.objects o
    where o.company_id = public.current_user_company_id()
      and lower(btrim(o.name)) = lower(btrim(coalesce(p_object_name, '')))
      and o.is_active = true
  );
$$;

create or replace function public.employee_is_allowed_for_user(p_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.employees e
    where e.id = p_employee_id
      and e.company_id = public.current_user_company_id()
      and public.can_access_object(e.object_name)
  );
$$;

create or replace function public.task_is_allowed_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and t.company_id = public.current_user_company_id()
      and public.can_access_object(t.object_name)
      and public.is_active_object(t.object_name)
  );
$$;

create or replace function public.app_notification_allowed_for_user(
  p_entity_type text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.is_admin()
    or (
      public.is_foreman()
      and coalesce(p_entity_type, '') in (
        'attendance', 'tasks', 'task_assignees', 'task_photos'
      )
      and public.can_access_object(coalesce(p_object_name, ''))
    );
$$;

create or replace function public.profile_visible_to_current_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p_user_id = (select auth.uid())
    or (
      public.is_admin()
      and exists (
        select 1
        from public.company_memberships m
        where m.company_id = public.current_user_company_id()
          and m.user_id = p_user_id
      )
    );
$$;

create or replace function public.profile_manageable_by_current_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_admin()
    and exists (
      select 1
      from public.company_memberships m
      where m.company_id = public.current_user_company_id()
        and m.user_id = p_user_id
        and m.role <> 'owner'
    );
$$;

create or replace function public.company_can_add_object(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.companies c
    where c.id = p_company_id
      and c.status = 'active'
      and (
        select count(*) from public.objects o where o.company_id = c.id
      ) < c.object_limit
  );
$$;

create or replace function public.company_can_add_member(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.companies c
    where c.id = p_company_id
      and c.status = 'active'
      and (
        select count(*)
        from public.company_memberships m
        where m.company_id = c.id and m.is_active = true
      ) < c.seat_limit
  );
$$;

create or replace function public.create_company_for_current_user(
  p_company_name text,
  p_full_name text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_company_name text := btrim(coalesce(p_company_name, ''));
  v_full_name text := btrim(coalesce(p_full_name, ''));
  v_company_id uuid;
  v_role text;
  v_slug text;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;

  select email into v_email from auth.users where id = v_user_id;

  select m.company_id, m.role
  into v_company_id, v_role
  from public.company_memberships m
  where m.user_id = v_user_id and m.is_active = true
  order by m.created_at, m.company_id
  limit 1;

  if v_company_id is null then
    if length(v_company_name) < 2 then
      raise exception 'Введите название компании';
    end if;

    v_slug := 'company-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 16);

    insert into public.companies (
      name, slug, owner_user_id, plan_code, billing_status,
      trial_ends_at, seat_limit, object_limit
    ) values (
      v_company_name, v_slug, v_user_id, 'trial', 'trialing',
      now() + interval '14 days', 10, 5
    ) returning id into v_company_id;

    insert into public.company_memberships (
      company_id, user_id, role, is_active
    ) values (
      v_company_id, v_user_id, 'owner', true
    );

    v_role := 'owner';
  end if;

  insert into public.user_profiles (
    id, email, full_name, role, object_name, is_active, active_company_id
  ) values (
    v_user_id,
    coalesce(v_email, ''),
    coalesce(nullif(v_full_name, ''), split_part(coalesce(v_email, ''), '@', 1)),
    case when v_role in ('owner', 'admin') then 'admin' else 'foreman' end,
    null,
    true,
    v_company_id
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = case
          when excluded.full_name = '' then public.user_profiles.full_name
          else excluded.full_name
        end,
        role = excluded.role,
        is_active = true,
        active_company_id = excluded.active_company_id,
        updated_at = now();

  return jsonb_build_object(
    'company_id', v_company_id,
    'company_name', (
      select c.name from public.companies c where c.id = v_company_id
    ),
    'role', case when v_role in ('owner', 'admin') then 'admin' else 'foreman' end
  );
end;
$$;

create or replace function public.set_active_company(p_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_membership_role text;
  v_object_name text;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;

  select m.role
  into v_membership_role
  from public.company_memberships m
  join public.companies c on c.id = m.company_id
  where m.company_id = p_company_id
    and m.user_id = v_user_id
    and m.is_active = true
    and c.status = 'active';

  if not found then
    raise exception 'Нет доступа к этой компании';
  end if;

  select o.name
  into v_object_name
  from public.object_memberships om
  join public.objects o
    on o.company_id = om.company_id and o.id = om.object_id
  where om.company_id = p_company_id
    and om.user_id = v_user_id
    and o.is_active = true
  order by om.created_at, o.name
  limit 1;

  update public.user_profiles
  set active_company_id = p_company_id,
      role = case when v_membership_role in ('owner', 'admin') then 'admin' else 'foreman' end,
      object_name = v_object_name,
      is_active = true,
      updated_at = now()
  where id = v_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;

  return jsonb_build_object(
    'company_id', p_company_id,
    'role', case when v_membership_role in ('owner', 'admin') then 'admin' else 'foreman' end,
    'object_name', coalesce(v_object_name, '')
  );
end;
$$;

create or replace function public.clear_current_company_notifications(
  p_object_name text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid := public.current_user_company_id();
  v_object_name text := btrim(coalesce(p_object_name, ''));
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется вход в компанию';
  end if;
  if v_object_name <> '' and not public.can_access_object(v_object_name) then
    raise exception 'Нет доступа к объекту';
  end if;

  insert into public.app_notification_clears (
    user_id, object_name, company_id, cleared_at
  ) values (
    v_user_id, v_object_name, v_company_id, now()
  )
  on conflict (user_id, object_name) do update
    set company_id = excluded.company_id,
        cleared_at = excluded.cleared_at;
end;
$$;

create or replace function public.archive_object(p_name text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_company_id uuid := public.current_user_company_id();
  v_now timestamptz := now();
begin
  if not public.is_admin() then
    raise exception 'Недостаточно прав для архивации объекта';
  end if;
  if v_name = '' or v_company_id is null then
    raise exception 'Не найден объект';
  end if;

  update public.objects
  set is_active = false, updated_at = v_now
  where company_id = v_company_id
    and lower(btrim(name)) = lower(v_name);

  if not found then
    insert into public.objects (
      company_id, name, address, comment, is_active, created_by, updated_at
    ) values (
      v_company_id, v_name, '', '', false, auth.uid(), v_now
    );
  end if;

  update public.employees
  set is_active = false, updated_at = v_now
  where company_id = v_company_id
    and lower(btrim(object_name)) = lower(v_name)
    and is_active = true;
end;
$$;

create or replace function public.restore_object(p_name text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_company_id uuid := public.current_user_company_id();
begin
  if not public.is_admin() then
    raise exception 'Недостаточно прав для восстановления объекта';
  end if;
  if v_name = '' or v_company_id is null then
    raise exception 'Не найден объект';
  end if;

  update public.objects
  set is_active = true, updated_at = now()
  where company_id = v_company_id
    and lower(btrim(name)) = lower(v_name);

  if not found then
    raise exception 'Объект "%" не найден в архиве', v_name;
  end if;
end;
$$;

create or replace function public.archived_object_delete_manifest(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_company_id uuid := public.current_user_company_id();
  v_is_active boolean;
  v_employee_ids jsonb := '[]'::jsonb;
  v_employee_document_paths jsonb := '[]'::jsonb;
  v_payment_receipt_paths jsonb := '[]'::jsonb;
  v_task_photo_paths jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'Доступно только администратору';
  end if;

  select o.is_active into v_is_active
  from public.objects o
  where o.company_id = v_company_id
    and lower(btrim(o.name)) = lower(v_name);

  if not found then raise exception 'Объект не найден'; end if;
  if v_is_active then raise exception 'Сначала переместите объект в архив'; end if;

  select coalesce(jsonb_agg(e.id order by e.id), '[]'::jsonb)
  into v_employee_ids
  from public.employees e
  where e.company_id = v_company_id
    and lower(btrim(e.object_name)) = lower(v_name);

  select coalesce(jsonb_agg(so.name order by so.name), '[]'::jsonb)
  into v_employee_document_paths
  from storage.objects so
  join public.employees e
    on e.company_id = v_company_id
   and lower(btrim(e.object_name)) = lower(v_name)
   and so.name like e.id::text || '/%'
  where so.bucket_id = 'employee-documents';

  select coalesce(jsonb_agg(pr.file_path order by pr.file_path), '[]'::jsonb)
  into v_payment_receipt_paths
  from public.payment_receipts pr
  join public.payments p
    on p.id = pr.payment_id and p.company_id = pr.company_id
  join public.employees e
    on e.id = p.employee_id and e.company_id = p.company_id
  where pr.company_id = v_company_id
    and lower(btrim(e.object_name)) = lower(v_name);

  select coalesce(jsonb_agg(tp.storage_path order by tp.storage_path), '[]'::jsonb)
  into v_task_photo_paths
  from public.task_photos tp
  join public.tasks t on t.id = tp.task_id and t.company_id = tp.company_id
  where tp.company_id = v_company_id
    and lower(btrim(t.object_name)) = lower(v_name);

  return jsonb_build_object(
    'object_name', v_name,
    'employee_ids', v_employee_ids,
    'employee_document_paths', v_employee_document_paths,
    'payment_receipt_paths', v_payment_receipt_paths,
    'task_photo_paths', v_task_photo_paths
  );
end;
$$;

create or replace function public.permanently_delete_employee(p_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_is_active boolean;
  v_archived_at timestamptz;
  v_employee_name text;
  v_employee_document_paths jsonb := '[]'::jsonb;
  v_payment_receipt_paths jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'Удаление доступно только администратору';
  end if;

  select coalesce(e.is_active, true), e.archived_at, e.fio
  into v_is_active, v_archived_at, v_employee_name
  from public.employees e
  where e.id = p_employee_id and e.company_id = v_company_id;

  if not found then raise exception 'Сотрудник не найден'; end if;
  if v_is_active or v_archived_at is null then
    raise exception 'Сначала переместите сотрудника в архив';
  end if;

  select coalesce(jsonb_agg(so.name order by so.name), '[]'::jsonb)
  into v_employee_document_paths
  from storage.objects so
  where so.bucket_id = 'employee-documents'
    and so.name like p_employee_id::text || '/%';

  select coalesce(jsonb_agg(pr.file_path order by pr.file_path), '[]'::jsonb)
  into v_payment_receipt_paths
  from public.payment_receipts pr
  where pr.company_id = v_company_id
    and (
      pr.employee_id = p_employee_id
      or exists (
        select 1 from public.payments p
        where p.id = pr.payment_id
          and p.company_id = v_company_id
          and p.employee_id = p_employee_id
      )
    );

  delete from public.employees
  where id = p_employee_id and company_id = v_company_id;

  return jsonb_build_object(
    'employee_name', coalesce(v_employee_name, ''),
    'employee_document_paths', v_employee_document_paths,
    'payment_receipt_paths', v_payment_receipt_paths,
    'task_photo_paths', '[]'::jsonb
  );
end;
$$;

do $$
declare
  v_policy record;
begin
  for v_policy in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = any (array[
        'objects', 'employees', 'attendance', 'payments',
        'employee_comments', 'employee_private_data', 'tasks',
        'task_assignees', 'task_photos', 'payment_receipts',
        'app_notifications', 'app_notification_reads',
        'app_notification_clears', 'user_profiles'
      ])
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      v_policy.policyname, v_policy.schemaname, v_policy.tablename
    );
  end loop;
end;
$$;

drop policy if exists company_memberships_insert_admins
on public.company_memberships;
create policy company_memberships_insert_admins
on public.company_memberships for insert to authenticated
with check (
  (select public.is_company_admin(company_id))
  and role in ('admin', 'foreman')
  and public.company_can_add_member(company_id)
);

create policy objects_select_company
on public.objects for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (public.is_admin() or public.can_access_object(name))
);
create policy objects_insert_company_admin
on public.objects for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and public.company_can_add_object(company_id)
);
create policy objects_update_company_admin
on public.objects for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin())
with check (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy objects_delete_company_admin
on public.objects for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy employees_select_company_object
on public.employees for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
);
create policy employees_insert_company_admin
on public.employees for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and exists (
    select 1 from public.objects o
    where o.company_id = employees.company_id
      and lower(btrim(o.name)) = lower(btrim(employees.object_name))
      and o.is_active = true
  )
);
create policy employees_update_company_admin
on public.employees for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin())
with check (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy employees_delete_company_admin
on public.employees for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy attendance_select_company_object
on public.attendance for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
);
create policy attendance_insert_company_object
on public.attendance for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and exists (
    select 1 from public.employees e
    where e.id = attendance.employee_id
      and e.company_id = attendance.company_id
      and lower(btrim(e.object_name)) = lower(btrim(attendance.object_name))
  )
);
create policy attendance_update_company_object
on public.attendance for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
)
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
);
create policy attendance_delete_company_admin
on public.attendance for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy payments_select_company_admin
on public.payments for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy payments_insert_company_admin
on public.payments for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.id = payments.employee_id and e.company_id = payments.company_id
  )
);
create policy payments_update_company_admin
on public.payments for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin())
with check (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy payments_delete_company_admin
on public.payments for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy employee_comments_select_company_admin
on public.employee_comments for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy employee_comments_insert_company_admin
on public.employee_comments for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.id = employee_comments.employee_id
      and e.company_id = employee_comments.company_id
  )
);
create policy employee_comments_update_company_admin
on public.employee_comments for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin())
with check (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy employee_comments_delete_company_admin
on public.employee_comments for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy employee_private_data_select_company_admin
on public.employee_private_data for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy employee_private_data_insert_company_admin
on public.employee_private_data for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.id = employee_private_data.employee_id
      and e.company_id = employee_private_data.company_id
  )
);
create policy employee_private_data_update_company_admin
on public.employee_private_data for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin())
with check (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy employee_private_data_delete_company_admin
on public.employee_private_data for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy tasks_select_company_object
on public.tasks for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
);
create policy tasks_insert_company_object
on public.tasks for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
);
create policy tasks_update_company_object
on public.tasks for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
)
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
);
create policy tasks_delete_company_admin
on public.tasks for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy task_assignees_select_company_task
on public.task_assignees for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_allowed_for_user(task_id)
);
create policy task_assignees_insert_company_task
on public.task_assignees for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and exists (
    select 1
    from public.tasks t
    join public.employees e
      on e.id = task_assignees.employee_id
     and e.company_id = t.company_id
     and lower(btrim(e.object_name)) = lower(btrim(t.object_name))
    where t.id = task_assignees.task_id
      and t.company_id = task_assignees.company_id
      and public.task_is_allowed_for_user(t.id)
  )
);
create policy task_assignees_delete_company_task
on public.task_assignees for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_allowed_for_user(task_id)
);

create policy task_photos_select_company_task
on public.task_photos for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_allowed_for_user(task_id)
);
create policy task_photos_insert_company_task
on public.task_photos for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.task_is_allowed_for_user(task_id)
);
create policy task_photos_delete_company_task
on public.task_photos for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_allowed_for_user(task_id)
);

create policy payment_receipts_select_company_admin
on public.payment_receipts for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());
create policy payment_receipts_insert_company_admin
on public.payment_receipts for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.is_admin()
  and exists (
    select 1 from public.payments p
    where p.id = payment_receipts.payment_id
      and p.company_id = payment_receipts.company_id
      and (
        payment_receipts.employee_id is null
        or p.employee_id = payment_receipts.employee_id
      )
  )
);
create policy payment_receipts_delete_company_admin
on public.payment_receipts for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy notifications_select_company_role
on public.app_notifications for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.app_notification_allowed_for_user(entity_type, object_name)
);
create policy notifications_insert_company_role
on public.app_notifications for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and actor_user_id = (select auth.uid())
  and (
    public.is_admin()
    or (
      public.is_foreman()
      and coalesce(entity_type, '') in (
        'attendance', 'tasks', 'task_assignees', 'task_photos'
      )
      and public.can_access_object(object_name)
    )
  )
);
create policy notifications_delete_company_admin
on public.app_notifications for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.is_admin());

create policy notification_reads_select_own_company
on public.app_notification_reads for select to authenticated
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
);
create policy notification_reads_insert_own_company
on public.app_notification_reads for insert to authenticated
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and exists (
    select 1 from public.app_notifications n
    where n.id = app_notification_reads.notification_id
      and n.company_id = app_notification_reads.company_id
  )
);
create policy notification_reads_update_own_company
on public.app_notification_reads for update to authenticated
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
)
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
);

create policy notification_clears_select_own_company
on public.app_notification_clears for select to authenticated
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
);
create policy notification_clears_insert_own_company
on public.app_notification_clears for insert to authenticated
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
  and (object_name = '' or public.can_access_object(object_name))
);
create policy notification_clears_update_own_company
on public.app_notification_clears for update to authenticated
using (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
)
with check (
  user_id = (select auth.uid())
  and company_id = (select public.current_user_company_id())
);
create policy notification_clears_delete_company
on public.app_notification_clears for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (user_id = (select auth.uid()) or public.is_admin())
);

create policy profiles_select_own_or_company_admin
on public.user_profiles for select to authenticated
using (public.profile_visible_to_current_user(id));
create policy profiles_insert_company_admin
on public.user_profiles for insert to authenticated
with check (public.profile_manageable_by_current_admin(id));
create policy profiles_update_company_admin
on public.user_profiles for update to authenticated
using (public.profile_manageable_by_current_admin(id))
with check (public.profile_manageable_by_current_admin(id));

drop policy if exists "employee documents delete admin only" on storage.objects;
drop policy if exists "employee documents insert admin only" on storage.objects;
drop policy if exists "employee documents select admin only" on storage.objects;
drop policy if exists "employee documents update admin only" on storage.objects;
drop policy if exists "payment receipts storage delete admin only" on storage.objects;
drop policy if exists "payment receipts storage insert admin only" on storage.objects;
drop policy if exists "payment receipts storage select admin only" on storage.objects;
drop policy if exists "task photos storage delete by task object" on storage.objects;
drop policy if exists "task photos storage insert authenticated" on storage.objects;
drop policy if exists "task photos storage select by task object" on storage.objects;

create policy employee_documents_select_company_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
  )
);
create policy employee_documents_insert_company_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
  )
);
create policy employee_documents_update_company_admin
on storage.objects for update to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
  )
)
with check (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
  )
);
create policy employee_documents_delete_company_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'employee-documents'
  and public.is_admin()
  and exists (
    select 1 from public.employees e
    where e.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
  )
);

create policy payment_receipts_storage_select_company_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.is_admin()
  and exists (
    select 1
    from public.payments p
    join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
    where p.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
      and p.id::text = (storage.foldername(name))[2]
  )
);
create policy payment_receipts_storage_insert_company_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'payment-receipts'
  and public.is_admin()
  and exists (
    select 1
    from public.payments p
    join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
    where p.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
      and p.id::text = (storage.foldername(name))[2]
  )
);
create policy payment_receipts_storage_delete_company_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.is_admin()
  and exists (
    select 1
    from public.payments p
    join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
    where p.company_id = public.current_user_company_id()
      and e.id::text = (storage.foldername(name))[1]
      and p.id::text = (storage.foldername(name))[2]
  )
);

create policy task_photos_storage_select_company_task
on storage.objects for select to authenticated
using (
  bucket_id = 'task-photos'
  and exists (
    select 1 from public.tasks t
    where t.company_id = public.current_user_company_id()
      and t.id::text = (storage.foldername(name))[1]
      and public.task_is_allowed_for_user(t.id)
  )
);
create policy task_photos_storage_insert_company_task
on storage.objects for insert to authenticated
with check (
  bucket_id = 'task-photos'
  and exists (
    select 1 from public.tasks t
    where t.company_id = public.current_user_company_id()
      and t.id::text = (storage.foldername(name))[1]
      and public.task_is_allowed_for_user(t.id)
  )
);
create policy task_photos_storage_delete_company_task
on storage.objects for delete to authenticated
using (
  bucket_id = 'task-photos'
  and exists (
    select 1 from public.tasks t
    where t.company_id = public.current_user_company_id()
      and t.id::text = (storage.foldername(name))[1]
      and public.task_is_allowed_for_user(t.id)
  )
);

revoke all on function public.create_company_for_current_user(text, text) from public, anon;
revoke all on function public.set_active_company(uuid) from public, anon;
revoke all on function public.clear_current_company_notifications(text) from public, anon;
revoke all on function public.archive_object(text) from public, anon;
revoke all on function public.restore_object(text) from public, anon;
revoke all on function public.archived_object_delete_manifest(text) from public, anon;
revoke all on function public.permanently_delete_employee(uuid) from public, anon;

revoke all on function public.current_user_role() from public, anon;
revoke all on function public.current_user_object_name() from public, anon;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_foreman() from public, anon;
revoke all on function public.can_access_object(text) from public, anon;
revoke all on function public.is_active_object(text) from public, anon;
revoke all on function public.employee_is_allowed_for_user(uuid) from public, anon;
revoke all on function public.task_is_allowed_for_user(uuid) from public, anon;
revoke all on function public.app_notification_allowed_for_user(text, text) from public, anon;
revoke all on function public.profile_visible_to_current_user(uuid) from public, anon;
revoke all on function public.profile_manageable_by_current_admin(uuid) from public, anon;
revoke all on function public.company_can_add_object(uuid) from public, anon;
revoke all on function public.company_can_add_member(uuid) from public, anon;

grant execute on function public.create_company_for_current_user(text, text) to authenticated;
grant execute on function public.set_active_company(uuid) to authenticated;
grant execute on function public.clear_current_company_notifications(text) to authenticated;
grant execute on function public.archive_object(text) to authenticated;
grant execute on function public.restore_object(text) to authenticated;
grant execute on function public.archived_object_delete_manifest(text) to authenticated;
grant execute on function public.permanently_delete_employee(uuid) to authenticated;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.current_user_object_name() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_foreman() to authenticated;
grant execute on function public.can_access_object(text) to authenticated;
grant execute on function public.is_active_object(text) to authenticated;
grant execute on function public.employee_is_allowed_for_user(uuid) to authenticated;
grant execute on function public.task_is_allowed_for_user(uuid) to authenticated;
grant execute on function public.app_notification_allowed_for_user(text, text) to authenticated;
grant execute on function public.profile_visible_to_current_user(uuid) to authenticated;
grant execute on function public.profile_manageable_by_current_admin(uuid) to authenticated;
grant execute on function public.company_can_add_object(uuid) to authenticated;
grant execute on function public.company_can_add_member(uuid) to authenticated;
