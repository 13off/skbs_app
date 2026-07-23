-- Lightweight unread probe for notification bells.
-- The query remains SECURITY INVOKER, so existing RLS stays authoritative.
create or replace function public.has_unread_notifications(
  p_object_name text default null
)
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $function$
  with params as (
    select nullif(btrim(coalesce(p_object_name, '')), '') as object_name
  ),
  clear_mark as (
    select max(clear_row.cleared_at) as cleared_at
    from public.app_notification_clears clear_row
    cross join params
    where clear_row.user_id = (select auth.uid())
      and clear_row.company_id = public.current_user_company_id()
      and (
        clear_row.object_name = ''
        or (
          params.object_name is not null
          and clear_row.object_name = params.object_name
        )
      )
  )
  select exists (
    select 1
    from public.app_notifications notification
    cross join params
    cross join clear_mark
    where (params.object_name is null or notification.object_name = params.object_name)
      and notification.created_at > coalesce(
        clear_mark.cleared_at,
        '-infinity'::timestamptz
      )
      and not exists (
        select 1
        from public.app_notification_reads read_row
        where read_row.user_id = (select auth.uid())
          and read_row.notification_id = notification.id
      )
    order by notification.created_at desc
    limit 1
  );
$function$;

revoke all on function public.has_unread_notifications(text) from public, anon;
grant execute on function public.has_unread_notifications(text) to authenticated;
