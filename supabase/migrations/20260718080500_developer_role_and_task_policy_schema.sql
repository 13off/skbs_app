-- Developer role, profession, object-level task restrictions and audit log.

alter table public.user_profiles
  add column if not exists profession text not null default '';

alter table public.company_invitations
  add column if not exists profession text not null default '';

alter table public.company_memberships
  drop constraint if exists company_memberships_role_check;
alter table public.company_memberships
  add constraint company_memberships_role_check check (
    role = any(array['owner','admin','developer','foreman','lawyer','accountant','hr']::text[])
  );

alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
  add constraint user_profiles_role_check check (
    role = any(array['admin','developer','foreman','lawyer','accountant','hr']::text[])
  );

alter table public.company_invitations
  drop constraint if exists company_invitations_role_check;
alter table public.company_invitations
  add constraint company_invitations_role_check check (
    role = any(array['admin','developer','foreman','lawyer','accountant','hr']::text[])
  );

alter table public.role_permissions
  drop constraint if exists role_permissions_role_check;
alter table public.role_permissions
  add constraint role_permissions_role_check check (
    role_code = any(array['owner','admin','developer','foreman','lawyer','accountant','hr']::text[])
  );

insert into public.role_permissions(role_code, permission_code)
select 'developer', permission_code
from public.role_permissions
where role_code = 'admin'
on conflict(role_code, permission_code) do nothing;

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
      and m.role in ('owner', 'admin', 'developer')
      and m.is_active = true
      and c.status = 'active'
  );
$$;

create or replace function public.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_user_role() = 'developer', false);
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(public.current_user_role() in ('admin', 'developer'), false);
$$;

create or replace function public.normalize_notification_role(p_role text)
returns text
language sql
immutable
as $$
  select case lower(btrim(coalesce(p_role, '')))
    when 'owner' then 'admin'
    when 'developer' then 'admin'
    when 'accounting' then 'accountant'
    when 'accountant' then 'accountant'
    when 'admin' then 'admin'
    when 'foreman' then 'foreman'
    when 'hr' then 'hr'
    when 'lawyer' then 'lawyer'
    else 'admin'
  end;
$$;

-- Existing policies listed the allowed roles separately from the table constraint.
drop policy if exists company_memberships_insert_admins on public.company_memberships;
create policy company_memberships_insert_admins
on public.company_memberships for insert to authenticated
with check (
  (select public.is_company_admin(company_id))
  and role in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr')
  and public.company_can_add_member(company_id)
);

drop policy if exists company_memberships_update_admins on public.company_memberships;
create policy company_memberships_update_admins
on public.company_memberships for update to authenticated
using (
  (select public.is_company_admin(company_id))
  and role <> 'owner'
)
with check (
  (select public.is_company_admin(company_id))
  and role in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr')
);

create unique index if not exists objects_company_id_id_key
  on public.objects(company_id, id);

create table if not exists public.company_task_policies (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid,
  require_before_photo boolean not null default true,
  min_before_photos integer not null default 1,
  require_after_photo_on_complete boolean not null default true,
  min_after_photos integer not null default 1,
  require_not_done_comment boolean not null default true,
  foreman_can_create_any_date boolean not null default false,
  foreman_can_edit_past_tasks boolean not null default false,
  edit_window_days integer,
  foreman_can_edit_date boolean not null default true,
  foreman_can_edit_axes_work boolean not null default true,
  foreman_can_edit_assignees boolean not null default true,
  foreman_can_edit_status boolean not null default true,
  foreman_can_delete_before_photos boolean not null default true,
  foreman_can_delete_after_photos boolean not null default true,
  foreman_can_delete_task boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint company_task_policies_before_count_check check (
    min_before_photos between 0 and 20
  ),
  constraint company_task_policies_after_count_check check (
    min_after_photos between 0 and 20
  ),
  constraint company_task_policies_edit_window_check check (
    edit_window_days is null or edit_window_days between 0 and 3650
  ),
  constraint company_task_policies_object_company_fkey
    foreign key (company_id, object_id)
    references public.objects(company_id, id)
    on delete cascade
);

create unique index if not exists company_task_policies_company_default_key
  on public.company_task_policies(company_id)
  where object_id is null;
create unique index if not exists company_task_policies_company_object_key
  on public.company_task_policies(company_id, object_id)
  where object_id is not null;
create index if not exists company_task_policies_company_object_lookup_idx
  on public.company_task_policies(company_id, object_id);

alter table public.company_task_policies enable row level security;

drop policy if exists company_task_policies_select_company on public.company_task_policies;
create policy company_task_policies_select_company
on public.company_task_policies for select to authenticated
using (company_id = (select public.current_user_company_id()));

drop policy if exists company_task_policies_insert_admin on public.company_task_policies;
create policy company_task_policies_insert_admin
on public.company_task_policies for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);

drop policy if exists company_task_policies_update_admin on public.company_task_policies;
create policy company_task_policies_update_admin
on public.company_task_policies for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (select public.is_admin())
)
with check (
  company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);

drop policy if exists company_task_policies_delete_admin on public.company_task_policies;
create policy company_task_policies_delete_admin
on public.company_task_policies for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (select public.is_admin())
  and object_id is not null
);

grant select, insert, update, delete on public.company_task_policies to authenticated;
grant all on public.company_task_policies to service_role;

create table if not exists public.developer_settings_audit (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid references public.objects(id) on delete set null,
  setting_group text not null,
  action text not null,
  old_value jsonb,
  new_value jsonb,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  constraint developer_settings_audit_group_check check (
    setting_group in ('task_policy', 'role', 'profession', 'feature')
  ),
  constraint developer_settings_audit_action_check check (
    action in ('create', 'update', 'reset', 'delete')
  )
);

create index if not exists developer_settings_audit_company_time_idx
  on public.developer_settings_audit(company_id, changed_at desc);

alter table public.developer_settings_audit enable row level security;

drop policy if exists developer_settings_audit_select_admin on public.developer_settings_audit;
create policy developer_settings_audit_select_admin
on public.developer_settings_audit for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (select public.is_admin())
);

grant select on public.developer_settings_audit to authenticated;
grant all on public.developer_settings_audit to service_role;

insert into public.company_task_policies(company_id, object_id, updated_by)
select c.id, null, null
from public.companies c
on conflict(company_id) where object_id is null do nothing;

create or replace function public.task_policy_row_to_json(p public.company_task_policies)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', p.id,
    'company_id', p.company_id,
    'object_id', p.object_id,
    'require_before_photo', p.require_before_photo,
    'min_before_photos', p.min_before_photos,
    'require_after_photo_on_complete', p.require_after_photo_on_complete,
    'min_after_photos', p.min_after_photos,
    'require_not_done_comment', p.require_not_done_comment,
    'foreman_can_create_any_date', p.foreman_can_create_any_date,
    'foreman_can_edit_past_tasks', p.foreman_can_edit_past_tasks,
    'edit_window_days', p.edit_window_days,
    'foreman_can_edit_date', p.foreman_can_edit_date,
    'foreman_can_edit_axes_work', p.foreman_can_edit_axes_work,
    'foreman_can_edit_assignees', p.foreman_can_edit_assignees,
    'foreman_can_edit_status', p.foreman_can_edit_status,
    'foreman_can_delete_before_photos', p.foreman_can_delete_before_photos,
    'foreman_can_delete_after_photos', p.foreman_can_delete_after_photos,
    'foreman_can_delete_task', p.foreman_can_delete_task,
    'updated_at', p.updated_at,
    'updated_by', p.updated_by
  );
$$;

create or replace function public.get_effective_task_policy(p_object_name text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_policy public.company_task_policies;
begin
  if auth.uid() is null or v_company_id is null then
    raise exception 'Требуется вход в рабочую компанию';
  end if;

  select policy.* into v_policy
  from public.company_task_policies policy
  left join public.objects object
    on object.id = policy.object_id
   and object.company_id = policy.company_id
  where policy.company_id = v_company_id
    and (
      (policy.object_id is not null and lower(btrim(object.name)) = lower(btrim(coalesce(p_object_name, ''))))
      or policy.object_id is null
    )
  order by (policy.object_id is not null) desc
  limit 1;

  if v_policy.id is null then
    return jsonb_build_object(
      'id', null,
      'company_id', v_company_id,
      'object_id', null,
      'require_before_photo', true,
      'min_before_photos', 1,
      'require_after_photo_on_complete', true,
      'min_after_photos', 1,
      'require_not_done_comment', true,
      'foreman_can_create_any_date', false,
      'foreman_can_edit_past_tasks', false,
      'edit_window_days', 0,
      'foreman_can_edit_date', true,
      'foreman_can_edit_axes_work', true,
      'foreman_can_edit_assignees', true,
      'foreman_can_edit_status', true,
      'foreman_can_delete_before_photos', true,
      'foreman_can_delete_after_photos', true,
      'foreman_can_delete_task', false,
      'updated_at', null,
      'updated_by', null
    );
  end if;

  return public.task_policy_row_to_json(v_policy);
end;
$$;
