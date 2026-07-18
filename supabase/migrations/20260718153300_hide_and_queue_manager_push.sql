create or replace function private.queue_push_notification_job()
returns trigger
language plpgsql
security definer
set search_path = public, net, pg_temp
as $$
declare
  v_job public.push_notification_jobs%rowtype;
begin
  if not new.is_push_only
     and new.target_user_id is not null
     and exists (
       select 1
       from public.company_memberships m
       where m.company_id = new.company_id
         and m.user_id = new.target_user_id
         and m.is_active = true
         and m.role in ('admin','owner')
     ) then
    return new;
  end if;

  insert into public.push_notification_jobs(notification_id)
  values(new.id)
  on conflict(notification_id) do update
    set updated_at = now()
  returning * into v_job;

  perform net.http_post(
    url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/dispatch-push-job',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'job_id', v_job.id,
      'dispatch_token', v_job.dispatch_token
    ),
    timeout_milliseconds := 15000
  );

  return new;
end;
$$;

revoke all on function private.queue_push_notification_job()
  from public, anon, authenticated;
grant execute on function private.queue_push_notification_job()
  to service_role;

drop policy if exists notifications_select_company_role
  on public.app_notifications;
create policy notifications_select_company_role
on public.app_notifications for select to authenticated
using (
  not is_push_only
  and company_id = public.current_user_company_id()
  and public.notification_visible_for_current_user(
    source_role,
    target_user_id,
    target_role,
    entity_type,
    object_name
  )
);
