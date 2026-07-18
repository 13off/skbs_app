alter table public.notification_role_preferences
  add column if not exists selected_bell_roles text[];

update public.notification_role_preferences
set selected_bell_roles = coalesce(
      selected_bell_roles,
      selected_roles,
      array['admin','foreman','hr','accountant','lawyer']::text[]
    ),
    selected_roles = array[]::text[];

alter table public.notification_role_preferences
  alter column selected_bell_roles set default array['admin','foreman','hr','accountant','lawyer']::text[],
  alter column selected_bell_roles set not null;

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_bell_roles_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_bell_roles_check check (
    selected_bell_roles <@ array['admin','foreman','hr','accountant','lawyer']::text[]
  );

create or replace function public.current_admin_notification_roles()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when not public.is_admin() then
      array[public.normalize_notification_role(public.current_user_role())]::text[]
    else coalesce(
      (
        select p.selected_bell_roles
        from public.notification_role_preferences p
        where p.company_id = public.current_user_company_id()
          and p.user_id = auth.uid()
      ),
      array['admin','foreman','hr','accountant','lawyer']::text[]
    )
  end;
$$;

create or replace function public.set_my_notification_role_preferences(p_roles text[])
returns text[]
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_roles text[];
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки ролей доступны только руководителю';
  end if;

  select coalesce(
    array_agg(
      distinct public.normalize_notification_role(value)
      order by public.normalize_notification_role(value)
    ),
    array[]::text[]
  )
  into v_roles
  from unnest(coalesce(p_roles, array[]::text[])) as value
  where public.normalize_notification_role(value)
    in ('admin','foreman','hr','accountant','lawyer');

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_bell_roles, updated_at
  ) values (
    v_company_id, auth.uid(), array[]::text[], v_roles, now()
  )
  on conflict(company_id, user_id) do update
    set selected_roles = array[]::text[],
        selected_bell_roles = excluded.selected_bell_roles,
        updated_at = now();

  return v_roles;
end;
$$;
