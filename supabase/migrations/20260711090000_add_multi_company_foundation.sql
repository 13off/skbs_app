-- Compatible multi-company foundation for AppStroy.
-- Existing SKBS data stays available to the current client while every row
-- receives an explicit tenant key for the next RLS migration.

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 2 and 160),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_memberships (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'foreman')),
  is_active boolean not null default true,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

create table if not exists public.company_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  email text not null check (position('@' in email) > 1),
  role text not null default 'foreman' check (role in ('admin', 'foreman')),
  object_id uuid,
  invited_by uuid not null references auth.users(id) on delete restrict,
  invited_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked', 'expired')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_profiles
  add column if not exists active_company_id uuid
  references public.companies(id) on delete set null;

alter table public.user_profiles disable trigger app_notify_user_profiles;

do $$
declare
  v_owner_id uuid;
  v_company_id uuid;
begin
  select id
  into v_owner_id
  from public.user_profiles
  where role = 'admin' and is_active = true
  order by created_at, id
  limit 1;

  if v_owner_id is null then
    select id
    into v_owner_id
    from public.user_profiles
    where is_active = true
    order by created_at, id
    limit 1;
  end if;

  if v_owner_id is null then
    raise exception 'Cannot seed the SKBS company without an active user profile';
  end if;

  insert into public.companies (name, slug, owner_user_id)
  values ('СКБС', 'skbs', v_owner_id)
  on conflict (slug) do update
    set name = excluded.name,
        updated_at = now()
  returning id into v_company_id;

  insert into public.company_memberships (company_id, user_id, role, is_active)
  select
    v_company_id,
    p.id,
    case
      when p.id = v_owner_id then 'owner'
      when p.role = 'admin' then 'admin'
      else 'foreman'
    end,
    p.is_active
  from public.user_profiles p
  on conflict (company_id, user_id) do update
    set role = excluded.role,
        is_active = excluded.is_active,
        updated_at = now();

  update public.user_profiles
  set active_company_id = v_company_id
  where active_company_id is null;
end;
$$;

create or replace function public.current_user_company_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (
      select p.active_company_id
      from public.user_profiles p
      where p.id = (select auth.uid())
        and exists (
          select 1
          from public.company_memberships m
          where m.company_id = p.active_company_id
            and m.user_id = p.id
            and m.is_active = true
        )
      limit 1
    ),
    (
      select m.company_id
      from public.company_memberships m
      where m.user_id = (select auth.uid())
        and m.is_active = true
      order by
        case m.role when 'owner' then 0 when 'admin' then 1 else 2 end,
        m.created_at,
        m.company_id
      limit 1
    )
  );
$$;

create or replace function public.is_company_member(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.company_memberships m
    join public.companies c on c.id = m.company_id
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and c.status = 'active'
  );
$$;

create or replace function public.is_company_admin(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.company_memberships m
    join public.companies c on c.id = m.company_id
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner', 'admin')
      and m.is_active = true
      and c.status = 'active'
  );
$$;

revoke all on function public.current_user_company_id() from public, anon;
revoke all on function public.is_company_member(uuid) from public, anon;
revoke all on function public.is_company_admin(uuid) from public, anon;
grant execute on function public.current_user_company_id() to authenticated;
grant execute on function public.is_company_member(uuid) to authenticated;
grant execute on function public.is_company_admin(uuid) to authenticated;

-- Avoid creating hundreds of business notifications while only tenant keys are
-- backfilled. Trigger state is transaction-safe and restored below.
alter table public.objects disable trigger app_notify_objects;
alter table public.employees disable trigger app_notify_employees;
alter table public.tasks disable trigger app_notify_tasks;
alter table public.task_assignees disable trigger app_notify_task_assignees;
alter table public.task_photos disable trigger app_notify_task_photos;
alter table public.payments disable trigger app_notify_payments;
alter table public.payment_receipts disable trigger app_notify_payment_receipts;
alter table public.employee_private_data disable trigger app_notify_employee_private_data;

alter table public.objects add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.employees add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.attendance add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.payments add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.employee_comments add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.task_assignees add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.task_photos add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.employee_private_data add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.tasks add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.payment_receipts add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.app_notifications add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.app_notification_reads add column if not exists company_id uuid
  references public.companies(id) on delete restrict;
alter table public.app_notification_clears add column if not exists company_id uuid
  references public.companies(id) on delete restrict;

update public.objects
set company_id = (select id from public.companies where slug = 'skbs')
where company_id is null;

update public.employees
set company_id = (select id from public.companies where slug = 'skbs')
where company_id is null;

update public.tasks
set company_id = (select id from public.companies where slug = 'skbs')
where company_id is null;

update public.attendance a
set company_id = coalesce(
  (select e.company_id from public.employees e where e.id = a.employee_id),
  (select id from public.companies where slug = 'skbs')
)
where a.company_id is null;

update public.payments p
set company_id = coalesce(
  (select e.company_id from public.employees e where e.id = p.employee_id),
  (select id from public.companies where slug = 'skbs')
)
where p.company_id is null;

update public.employee_comments ec
set company_id = coalesce(
  (select e.company_id from public.employees e where e.id = ec.employee_id),
  (select id from public.companies where slug = 'skbs')
)
where ec.company_id is null;

update public.employee_private_data epd
set company_id = coalesce(
  (select e.company_id from public.employees e where e.id = epd.employee_id),
  (select id from public.companies where slug = 'skbs')
)
where epd.company_id is null;

update public.task_assignees ta
set company_id = coalesce(
  (select t.company_id from public.tasks t where t.id = ta.task_id),
  (select id from public.companies where slug = 'skbs')
)
where ta.company_id is null;

update public.task_photos tp
set company_id = coalesce(
  (select t.company_id from public.tasks t where t.id = tp.task_id),
  (select id from public.companies where slug = 'skbs')
)
where tp.company_id is null;

update public.payment_receipts pr
set company_id = coalesce(
  (select p.company_id from public.payments p where p.id = pr.payment_id),
  (select e.company_id from public.employees e where e.id = pr.employee_id),
  (select id from public.companies where slug = 'skbs')
)
where pr.company_id is null;

update public.app_notifications
set company_id = (select id from public.companies where slug = 'skbs')
where company_id is null;

update public.app_notification_reads r
set company_id = coalesce(
  (select n.company_id from public.app_notifications n where n.id = r.notification_id),
  (select id from public.companies where slug = 'skbs')
)
where r.company_id is null;

update public.app_notification_clears
set company_id = (select id from public.companies where slug = 'skbs')
where company_id is null;

alter table public.objects alter column company_id set not null;
alter table public.employees alter column company_id set not null;
alter table public.attendance alter column company_id set not null;
alter table public.payments alter column company_id set not null;
alter table public.employee_comments alter column company_id set not null;
alter table public.task_assignees alter column company_id set not null;
alter table public.task_photos alter column company_id set not null;
alter table public.employee_private_data alter column company_id set not null;
alter table public.tasks alter column company_id set not null;
alter table public.payment_receipts alter column company_id set not null;
alter table public.app_notifications alter column company_id set not null;
alter table public.app_notification_reads alter column company_id set not null;
alter table public.app_notification_clears alter column company_id set not null;

alter table public.objects alter column company_id
  set default public.current_user_company_id();
alter table public.employees alter column company_id
  set default public.current_user_company_id();
alter table public.attendance alter column company_id
  set default public.current_user_company_id();
alter table public.payments alter column company_id
  set default public.current_user_company_id();
alter table public.employee_comments alter column company_id
  set default public.current_user_company_id();
alter table public.task_assignees alter column company_id
  set default public.current_user_company_id();
alter table public.task_photos alter column company_id
  set default public.current_user_company_id();
alter table public.employee_private_data alter column company_id
  set default public.current_user_company_id();
alter table public.tasks alter column company_id
  set default public.current_user_company_id();
alter table public.payment_receipts alter column company_id
  set default public.current_user_company_id();
alter table public.app_notifications alter column company_id
  set default public.current_user_company_id();
alter table public.app_notification_reads alter column company_id
  set default public.current_user_company_id();
alter table public.app_notification_clears alter column company_id
  set default public.current_user_company_id();

alter table public.objects drop constraint if exists objects_name_key;
create unique index if not exists objects_company_name_unique
  on public.objects (company_id, lower(btrim(name)));
create unique index if not exists objects_company_id_id_unique
  on public.objects (company_id, id);

create index if not exists objects_company_id_idx on public.objects(company_id);
create index if not exists employees_company_id_idx on public.employees(company_id);
create index if not exists attendance_company_id_idx on public.attendance(company_id);
create index if not exists payments_company_id_idx on public.payments(company_id);
create index if not exists employee_comments_company_id_idx on public.employee_comments(company_id);
create index if not exists task_assignees_company_id_idx on public.task_assignees(company_id);
create index if not exists task_photos_company_id_idx on public.task_photos(company_id);
create index if not exists employee_private_data_company_id_idx on public.employee_private_data(company_id);
create index if not exists tasks_company_id_idx on public.tasks(company_id);
create index if not exists payment_receipts_company_id_idx on public.payment_receipts(company_id);
create index if not exists app_notifications_company_created_idx
  on public.app_notifications(company_id, created_at desc);
create index if not exists app_notification_reads_company_id_idx
  on public.app_notification_reads(company_id);
create index if not exists app_notification_clears_company_id_idx
  on public.app_notification_clears(company_id);
create index if not exists company_memberships_user_active_idx
  on public.company_memberships(user_id, is_active, company_id);
create index if not exists company_invitations_company_status_idx
  on public.company_invitations(company_id, status, created_at desc);
create unique index if not exists company_invitations_pending_email_unique
  on public.company_invitations(company_id, lower(btrim(email)))
  where status = 'pending';

alter table public.company_invitations
  add constraint company_invitations_object_id_fkey
  foreign key (company_id, object_id)
  references public.objects(company_id, id) on delete cascade;

create table if not exists public.object_memberships (
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (company_id, object_id, user_id),
  foreign key (company_id, object_id)
    references public.objects(company_id, id) on delete cascade
);

insert into public.object_memberships (company_id, object_id, user_id)
select o.company_id, o.id, p.id
from public.user_profiles p
join public.objects o
  on lower(btrim(o.name)) = lower(btrim(coalesce(p.object_name, '')))
where p.role = 'foreman'
  and p.is_active = true
on conflict do nothing;

create index if not exists object_memberships_user_company_idx
  on public.object_memberships(user_id, company_id, object_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists companies_touch_updated_at on public.companies;
create trigger companies_touch_updated_at
before update on public.companies
for each row execute function public.touch_updated_at();

drop trigger if exists company_memberships_touch_updated_at on public.company_memberships;
create trigger company_memberships_touch_updated_at
before update on public.company_memberships
for each row execute function public.touch_updated_at();

drop trigger if exists company_invitations_touch_updated_at on public.company_invitations;
create trigger company_invitations_touch_updated_at
before update on public.company_invitations
for each row execute function public.touch_updated_at();

alter table public.companies enable row level security;
alter table public.company_memberships enable row level security;
alter table public.company_invitations enable row level security;
alter table public.object_memberships enable row level security;

create policy companies_select_members
on public.companies for select to authenticated
using ((select public.is_company_member(id)));

create policy companies_update_admins
on public.companies for update to authenticated
using ((select public.is_company_admin(id)))
with check ((select public.is_company_admin(id)));

create policy company_memberships_select_members
on public.company_memberships for select to authenticated
using ((select public.is_company_member(company_id)));

create policy company_memberships_insert_admins
on public.company_memberships for insert to authenticated
with check (
  (select public.is_company_admin(company_id))
  and role in ('admin', 'foreman')
);

create policy company_memberships_update_admins
on public.company_memberships for update to authenticated
using (
  (select public.is_company_admin(company_id))
  and role <> 'owner'
)
with check (
  (select public.is_company_admin(company_id))
  and role in ('admin', 'foreman')
);

create policy company_memberships_delete_admins
on public.company_memberships for delete to authenticated
using (
  (select public.is_company_admin(company_id))
  and role <> 'owner'
);

create policy company_invitations_select_admins
on public.company_invitations for select to authenticated
using ((select public.is_company_admin(company_id)));

create policy company_invitations_insert_admins
on public.company_invitations for insert to authenticated
with check (
  (select public.is_company_admin(company_id))
  and invited_by = (select auth.uid())
);

create policy company_invitations_update_admins
on public.company_invitations for update to authenticated
using ((select public.is_company_admin(company_id)))
with check ((select public.is_company_admin(company_id)));

create policy object_memberships_select_members
on public.object_memberships for select to authenticated
using ((select public.is_company_member(company_id)));

create policy object_memberships_insert_admins
on public.object_memberships for insert to authenticated
with check ((select public.is_company_admin(company_id)));

create policy object_memberships_delete_admins
on public.object_memberships for delete to authenticated
using ((select public.is_company_admin(company_id)));

grant select on public.companies to authenticated;
grant update (name) on public.companies to authenticated;
grant select, insert, update, delete on public.company_memberships to authenticated;
grant select, insert, update on public.company_invitations to authenticated;
grant select, insert, delete on public.object_memberships to authenticated;

alter table public.objects enable trigger app_notify_objects;
alter table public.employees enable trigger app_notify_employees;
alter table public.tasks enable trigger app_notify_tasks;
alter table public.task_assignees enable trigger app_notify_task_assignees;
alter table public.task_photos enable trigger app_notify_task_photos;
alter table public.payments enable trigger app_notify_payments;
alter table public.payment_receipts enable trigger app_notify_payment_receipts;
alter table public.employee_private_data enable trigger app_notify_employee_private_data;
alter table public.user_profiles enable trigger app_notify_user_profiles;
