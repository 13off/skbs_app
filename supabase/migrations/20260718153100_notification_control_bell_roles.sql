create or replace function public.set_my_notification_control_preferences(
  p_in_app_enabled boolean,
  p_push_enabled boolean,
  p_roles text[],
  p_event_groups text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_roles text[];
  v_groups text[];
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки уведомлений доступны только руководителю';
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

  select coalesce(
    array_agg(distinct lower(btrim(value)) order by lower(btrim(value))),
    array[]::text[]
  )
  into v_groups
  from unnest(coalesce(p_event_groups, array[]::text[])) as value
  where lower(btrim(value))
    in ('tasks','attendance','employees','hr','payments','legal','system');

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_bell_roles,
    selected_event_groups, in_app_enabled, push_enabled, updated_at
  ) values (
    v_company_id,
    auth.uid(),
    array[]::text[],
    v_roles,
    v_groups,
    coalesce(p_in_app_enabled, true),
    coalesce(p_push_enabled, true),
    now()
  )
  on conflict(company_id, user_id) do update
    set selected_roles = array[]::text[],
        selected_bell_roles = excluded.selected_bell_roles,
        selected_event_groups = excluded.selected_event_groups,
        in_app_enabled = excluded.in_app_enabled,
        push_enabled = excluded.push_enabled,
        updated_at = now();

  return public.get_my_notification_control_center();
end;
$$;

create or replace function public.get_my_notification_control_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки уведомлений доступны только руководителю';
  end if;

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_bell_roles,
    selected_event_groups, in_app_enabled, push_enabled, updated_at
  ) values (
    v_company_id,
    auth.uid(),
    array[]::text[],
    array['admin','foreman','hr','accountant','lawyer']::text[],
    array['tasks','attendance','employees','hr','payments','legal','system']::text[],
    true,
    true,
    now()
  )
  on conflict(company_id, user_id) do nothing;

  perform private.ensure_company_reminder_settings(v_company_id);

  select jsonb_build_object(
    'in_app_enabled', p.in_app_enabled,
    'push_enabled', p.push_enabled,
    'selected_roles', to_jsonb(p.selected_bell_roles),
    'selected_event_groups', to_jsonb(p.selected_event_groups),
    'reminders', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'key', r.reminder_key,
            'recipient_role', r.recipient_role,
            'enabled', r.enabled,
            'local_time', to_char(r.local_time, 'HH24:MI')
          ) order by r.reminder_key
        )
        from public.company_reminder_settings r
        where r.company_id = v_company_id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.notification_role_preferences p
  where p.company_id = v_company_id
    and p.user_id = auth.uid();

  return v_result;
end;
$$;
