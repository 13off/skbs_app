create or replace function public.notification_visible_for_current_user(
  p_source_role text,
  p_target_user_id uuid,
  p_target_role text,
  p_entity_type text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select auth.uid() is not null and (
    (
      public.is_admin()
      and public.current_admin_notification_in_app_enabled()
      and public.normalize_notification_role(p_source_role)
        = any(public.current_admin_notification_roles())
      and public.notification_event_group(p_entity_type)
        = any(public.current_admin_notification_event_groups())
    )
    or
    (
      not public.is_admin()
      and (
        p_target_user_id = auth.uid()
        or (
          p_target_user_id is null
          and (
            (
              p_target_role is not null
              and public.normalize_notification_role(p_target_role)
                = public.normalize_notification_role(public.current_user_role())
            )
            or (
              p_target_role is null
              and public.normalize_notification_role(p_source_role)
                = public.normalize_notification_role(public.current_user_role())
            )
          )
          and (
            public.normalize_notification_role(public.current_user_role())
              <> 'foreman'
            or (
              coalesce(p_entity_type,'') in (
                'attendance',
                'tasks',
                'task_assignees',
                'task_photos',
                'brigade_photo',
                'foreman_reminder',
                'dispatcher_summary'
              )
              and (
                coalesce(p_entity_type,'') = 'dispatcher_summary'
                or public.can_access_object(coalesce(p_object_name,''))
              )
            )
          )
        )
      )
    )
  );
$$;
