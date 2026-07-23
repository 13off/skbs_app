create or replace function public.current_user_visible_notification_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  with ctx as materialized (
    select
      (select auth.uid()) as user_id,
      public.current_user_company_id() as company_id,
      public.normalize_notification_role(public.current_user_role()) as user_role,
      public.is_admin() as is_admin,
      public.current_admin_notification_in_app_enabled() as admin_in_app_enabled,
      public.current_admin_notification_roles() as admin_roles,
      public.current_admin_notification_event_groups() as admin_event_groups,
      coalesce(
        array(
          select lower(btrim(object_row.name))
          from public.objects object_row
          left join public.object_memberships membership
            on membership.company_id = object_row.company_id
           and membership.object_id = object_row.id
           and membership.user_id = (select auth.uid())
          left join public.user_profiles profile
            on profile.id = (select auth.uid())
          where object_row.company_id = public.current_user_company_id()
            and object_row.is_active = true
            and (
              membership.user_id is not null
              or lower(btrim(coalesce(profile.object_name, '')))
                = lower(btrim(object_row.name))
            )
        ),
        array[]::text[]
      ) as accessible_object_names
  )
  select notification.id
  from public.app_notifications notification
  cross join ctx
  where ctx.user_id is not null
    and ctx.company_id is not null
    and notification.company_id = ctx.company_id
    and notification.is_push_only = false
    and (
      (
        ctx.is_admin
        and ctx.admin_in_app_enabled
        and public.normalize_notification_role(notification.source_role)
          = any(ctx.admin_roles)
        and public.notification_event_group(notification.entity_type)
          = any(ctx.admin_event_groups)
      )
      or (
        not ctx.is_admin
        and (
          notification.target_user_id = ctx.user_id
          or (
            notification.target_user_id is null
            and (
              (
                notification.target_role is not null
                and public.normalize_notification_role(notification.target_role)
                  = ctx.user_role
              )
              or (
                notification.target_role is null
                and public.normalize_notification_role(notification.source_role)
                  = ctx.user_role
              )
            )
            and (
              ctx.user_role <> 'foreman'
              or (
                coalesce(notification.entity_type, '') in (
                  'attendance',
                  'tasks',
                  'task_assignees',
                  'task_photos',
                  'brigade_photo',
                  'foreman_reminder',
                  'dispatcher_summary'
                )
                and (
                  coalesce(notification.entity_type, '') = 'dispatcher_summary'
                  or lower(btrim(coalesce(notification.object_name, '')))
                    = any(ctx.accessible_object_names)
                )
              )
            )
          )
        )
      )
    );
$function$;

comment on function public.current_user_visible_notification_ids() is
  'Возвращает видимые текущему пользователю уведомления с однократным вычислением компании, роли и настроек.';

revoke all on function public.current_user_visible_notification_ids()
  from public, anon;
grant execute on function public.current_user_visible_notification_ids()
  to authenticated;

drop policy if exists notifications_select_company_role
  on public.app_notifications;

create policy notifications_select_company_role
on public.app_notifications
for select
to authenticated
using (
  not is_push_only
  and company_id = (select public.current_user_company_id())
  and id in (
    select public.current_user_visible_notification_ids()
  )
);
