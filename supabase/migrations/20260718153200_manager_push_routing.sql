alter table public.app_notifications
  add column if not exists is_push_only boolean not null default false;

create index if not exists app_notifications_push_only_idx
  on public.app_notifications(company_id, is_push_only, created_at desc);

create or replace function private.ensure_manager_push_preferences(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_bell_roles,
    selected_event_groups, in_app_enabled, push_enabled, updated_at
  )
  select
    m.company_id,
    m.user_id,
    array[]::text[],
    array['admin','foreman','hr','accountant','lawyer']::text[],
    array['tasks','attendance','employees','hr','payments','legal','system']::text[],
    true,
    true,
    now()
  from public.company_memberships m
  where m.company_id = p_company_id
    and m.is_active = true
    and m.role in ('admin','owner')
  on conflict(company_id, user_id) do update
    set selected_roles = array[]::text[];
end;
$$;

create or replace function private.ensure_manager_push_preferences_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.company_id is not null then
    perform private.ensure_manager_push_preferences(new.company_id);
  end if;
  return new;
end;
$$;

create or replace function private.route_manager_push_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.is_push_only then
    return new;
  end if;

  perform private.ensure_manager_push_preferences(new.company_id);

  insert into public.app_notifications(
    company_id, title, body, actor_user_id, actor_name, actor_email,
    object_name, entity_type, entity_id, target_user_id, target_role,
    source_role, requires_action, due_at, priority, is_push_only
  )
  select
    new.company_id,
    new.title,
    new.body,
    new.actor_user_id,
    new.actor_name,
    new.actor_email,
    new.object_name,
    new.entity_type,
    new.entity_id,
    m.user_id,
    'admin',
    new.source_role,
    new.requires_action,
    new.due_at,
    new.priority,
    true
  from public.company_memberships m
  join public.notification_role_preferences p
    on p.company_id = m.company_id
   and p.user_id = m.user_id
  where m.company_id = new.company_id
    and m.is_active = true
    and m.role in ('admin','owner')
    and (new.actor_user_id is null or m.user_id <> new.actor_user_id)
    and p.push_enabled = true
    and public.normalize_notification_role(new.source_role)
      = any(p.selected_bell_roles)
    and public.notification_event_group(new.entity_type)
      = any(p.selected_event_groups);

  return new;
end;
$$;

revoke all on function private.ensure_manager_push_preferences(uuid)
  from public, anon, authenticated;
revoke all on function private.ensure_manager_push_preferences_on_notification()
  from public, anon, authenticated;
revoke all on function private.route_manager_push_notifications()
  from public, anon, authenticated;

grant execute on function private.ensure_manager_push_preferences(uuid)
  to service_role;
grant execute on function private.ensure_manager_push_preferences_on_notification()
  to service_role;
grant execute on function private.route_manager_push_notifications()
  to service_role;

drop trigger if exists app_notifications_ensure_manager_push_preferences
  on public.app_notifications;
drop trigger if exists zz_app_notifications_ensure_manager_push_preferences
  on public.app_notifications;
create trigger zz_app_notifications_ensure_manager_push_preferences
before insert on public.app_notifications
for each row execute function private.ensure_manager_push_preferences_on_notification();

drop trigger if exists app_notifications_route_manager_push
  on public.app_notifications;
create trigger app_notifications_route_manager_push
after insert on public.app_notifications
for each row execute function private.route_manager_push_notifications();
