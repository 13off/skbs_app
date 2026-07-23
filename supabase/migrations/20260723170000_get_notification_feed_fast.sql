create or replace function public.get_notification_feed_fast(
  p_object_name text default null,
  p_limit integer default 40
)
returns table (
  id uuid,
  title text,
  body text,
  actor_user_id uuid,
  actor_name text,
  actor_email text,
  object_name text,
  entity_type text,
  entity_id text,
  target_user_id uuid,
  target_role text,
  source_role text,
  requires_action boolean,
  due_at timestamptz,
  priority text,
  created_at timestamptz,
  is_read boolean
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $function$
  with ctx as materialized (
    select
      (select auth.uid()) as user_id,
      public.normalize_notification_role(
        coalesce(
          (
            select profile.role
            from public.user_profiles profile
            where profile.id = (select auth.uid())
            limit 1
          ),
          public.current_user_role()
        )
      ) as user_role,
      nullif(
        btrim(
          coalesce(
            (
              select profile.object_name
              from public.user_profiles profile
              where profile.id = (select auth.uid())
              limit 1
            ),
            ''
          )
        ),
        ''
      ) as profile_object,
      nullif(btrim(coalesce(p_object_name, '')), '') as requested_object
  ),
  scope as materialized (
    select
      ctx.user_id,
      ctx.user_role,
      ctx.user_role = 'foreman' as is_foreman,
      case
        when ctx.user_role = 'foreman'
          then coalesce(ctx.requested_object, ctx.profile_object)
        else ctx.requested_object
      end as visible_object
    from ctx
  ),
  clear_mark as materialized (
    select max(clear_row.cleared_at) as cleared_at
    from public.app_notification_clears clear_row
    cross join scope
    where clear_row.user_id = scope.user_id
      and (
        clear_row.object_name = ''
        or (
          scope.visible_object is not null
          and clear_row.object_name = scope.visible_object
        )
      )
  )
  select
    notification.id,
    notification.title,
    notification.body,
    notification.actor_user_id,
    notification.actor_name,
    notification.actor_email,
    notification.object_name,
    notification.entity_type,
    notification.entity_id,
    notification.target_user_id,
    notification.target_role,
    notification.source_role,
    notification.requires_action,
    notification.due_at,
    notification.priority,
    notification.created_at,
    exists (
      select 1
      from public.app_notification_reads read_row
      where read_row.user_id = scope.user_id
        and read_row.notification_id = notification.id
    ) as is_read
  from public.app_notifications notification
  cross join scope
  cross join clear_mark
  where scope.user_id is not null
    and (
      scope.visible_object is null
      or notification.object_name = scope.visible_object
    )
    and (
      not scope.is_foreman
      or notification.entity_type = any (
        array[
          'attendance',
          'tasks',
          'task_assignees',
          'task_photos',
          'legal_document',
          'legal_matter',
          'foreman_reminder',
          'brigade_photo',
          'operational_overdue_tasks',
          'operational_missing_photos',
          'operational_timesheet_missing',
          'ai_draft'
        ]::text[]
      )
    )
    and (
      clear_mark.cleared_at is null
      or notification.created_at > clear_mark.cleared_at
    )
  order by notification.created_at desc
  limit least(greatest(coalesce(p_limit, 40), 1), 100);
$function$;

comment on function public.get_notification_feed_fast(text, integer) is
  'Возвращает ленту уведомлений, дату очистки и статус прочтения одним защищённым запросом.';

revoke all on function public.get_notification_feed_fast(text, integer)
  from public, anon;
grant execute on function public.get_notification_feed_fast(text, integer)
  to authenticated;
