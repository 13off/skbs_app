create or replace function public.has_unread_notifications(
  p_object_name text default null
)
returns boolean
language sql
stable
security definer
set search_path = public, private, pg_temp
as $function$
  with ctx as materialized (
    select
      (select auth.uid()) as user_id,
      public.current_user_company_id() as company_id,
      nullif(btrim(coalesce(p_object_name, '')), '') as object_name
  ),
  clear_mark as materialized (
    select max(clear_row.cleared_at) as cleared_at
    from public.app_notification_clears clear_row
    cross join ctx
    where clear_row.user_id = ctx.user_id
      and clear_row.company_id = ctx.company_id
      and (
        clear_row.object_name = ''
        or (
          ctx.object_name is not null
          and clear_row.object_name = ctx.object_name
        )
      )
  ),
  visible as materialized (
    select visible_row.notification_id
    from private.current_user_visible_notification_ids()
      as visible_row(notification_id)
  )
  select exists (
    select 1
    from visible visible_row
    join public.app_notifications notification
      on notification.id = visible_row.notification_id
    cross join ctx
    cross join clear_mark
    left join public.app_notification_reads read_row
      on read_row.user_id = ctx.user_id
     and read_row.company_id = ctx.company_id
     and read_row.notification_id = notification.id
    where ctx.user_id is not null
      and ctx.company_id is not null
      and notification.company_id = ctx.company_id
      and (ctx.object_name is null or notification.object_name = ctx.object_name)
      and notification.created_at > coalesce(
        clear_mark.cleared_at,
        '-infinity'::timestamptz
      )
      and read_row.notification_id is null
    order by notification.created_at desc
    limit 1
  );
$function$;

revoke all on function public.has_unread_notifications(text)
  from public, anon;
grant execute on function public.has_unread_notifications(text)
  to authenticated;
