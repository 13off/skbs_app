create extension if not exists pg_cron with schema pg_catalog;

alter table public.app_notifications
  drop constraint if exists app_notifications_target_role_check;

alter table public.app_notifications
  add constraint app_notifications_target_role_check
  check (
    target_role is null
    or target_role = any (
      array['admin','foreman','lawyer','accountant','hr']::text[]
    )
  );

create table if not exists public.push_notification_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique
    references public.app_notifications(id) on delete cascade,
  dispatch_token uuid not null default gen_random_uuid(),
  status text not null default 'pending'
    check (status = any (array[
      'pending','processing','sent','partial','no_recipients','failed'
    ]::text[])),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz,
  last_error text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.push_notification_jobs is
  'Server-only queue for automatic FCM delivery of app_notifications.';

create index if not exists push_notification_jobs_retry_idx
  on public.push_notification_jobs(next_attempt_at, status)
  where status = 'failed';

alter table public.push_notification_jobs enable row level security;
revoke all on table public.push_notification_jobs from anon, authenticated;
grant all on table public.push_notification_jobs to service_role;

alter table public.scheduled_reminders
  add column if not exists title text not null default 'Напоминание',
  add column if not exists body text not null default '',
  add column if not exists object_name text not null default '',
  add column if not exists priority text not null default 'normal';

alter table public.scheduled_reminders
  drop constraint if exists scheduled_reminders_priority_check;

alter table public.scheduled_reminders
  add constraint scheduled_reminders_priority_check
  check (priority = any (array['low','normal','high','critical']::text[]));

create index if not exists scheduled_reminders_due_pending_idx
  on public.scheduled_reminders(due_at, id)
  where status = 'pending' and notification_id is null;

create or replace function private.queue_push_notification_job()
returns trigger
language plpgsql
security definer
set search_path = public, net, pg_temp
as $$
declare
  v_job public.push_notification_jobs%rowtype;
begin
  insert into public.push_notification_jobs(notification_id)
  values (new.id)
  on conflict (notification_id) do update
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

drop trigger if exists app_notifications_queue_push
  on public.app_notifications;
create trigger app_notifications_queue_push
after insert on public.app_notifications
for each row execute function private.queue_push_notification_job();

create or replace function private.populate_legal_scheduled_reminders()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.scheduled_reminders(
    company_id,
    reminder_key,
    entity_type,
    entity_id,
    reminder_type,
    due_at,
    recipient_user_id,
    recipient_role,
    title,
    body,
    object_name,
    priority
  )
  select
    d.company_id,
    'document-expiry-window:' || d.id::text || ':' || d.expires_on::text || ':' ||
      case
        when d.expires_on < current_date then 'expired'
        when d.expires_on <= current_date + 7 then 'seven-days'
        else 'thirty-days'
      end,
    'legal_document',
    d.id,
    case
      when d.expires_on < current_date then 'document_expired'
      else 'document_expiring'
    end,
    now(),
    d.responsible_user_id,
    case when d.responsible_user_id is null then 'lawyer' else null end,
    case
      when d.expires_on < current_date then 'Документ просрочен'
      when d.expires_on <= current_date + 7
        then 'До окончания документа не больше 7 дней'
      else 'До окончания документа не больше 30 дней'
    end,
    d.title,
    coalesce(o.name, ''),
    case when d.expires_on < current_date then 'high' else 'normal' end
  from public.legal_documents d
  left join public.objects o
    on o.id = d.object_id and o.company_id = d.company_id
  where d.archived_at is null
    and d.status not in ('terminated','archive')
    and d.expires_on is not null
    and d.expires_on <= current_date + 30
  on conflict (company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id,
    reminder_key,
    entity_type,
    entity_id,
    reminder_type,
    due_at,
    recipient_user_id,
    recipient_role,
    title,
    body,
    object_name,
    priority
  )
  select
    d.company_id,
    'document-action:' || d.id::text || ':' ||
      d.next_action_due_at::date::text || ':' ||
      case when d.next_action_due_at < now() then 'overdue' else 'due' end,
    'legal_document',
    d.id,
    case
      when d.next_action_due_at < now() then 'document_action_overdue'
      else 'document_action_due'
    end,
    now(),
    d.responsible_user_id,
    case when d.responsible_user_id is null then 'lawyer' else null end,
    case
      when d.next_action_due_at < now()
        then 'Действие по документу просрочено'
      else 'Приближается действие по документу'
    end,
    case
      when btrim(d.next_action) <> '' then d.title || ' · ' || d.next_action
      else d.title
    end,
    coalesce(o.name, ''),
    case when d.next_action_due_at < now() then 'high' else 'normal' end
  from public.legal_documents d
  left join public.objects o
    on o.id = d.object_id and o.company_id = d.company_id
  where d.archived_at is null
    and d.status not in ('terminated','archive')
    and d.next_action_due_at is not null
    and d.next_action_due_at <= now() + interval '3 days'
  on conflict (company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id,
    reminder_key,
    entity_type,
    entity_id,
    reminder_type,
    due_at,
    recipient_user_id,
    recipient_role,
    title,
    body,
    object_name,
    priority
  )
  select
    m.company_id,
    'matter-due:' || m.id::text || ':' || m.due_at::date::text || ':' ||
      case when m.due_at < now() then 'overdue' else 'due' end,
    'legal_matter',
    m.id,
    case when m.due_at < now() then 'matter_overdue' else 'matter_due' end,
    now(),
    m.responsible_user_id,
    case when m.responsible_user_id is null then 'lawyer' else null end,
    case
      when m.due_at < now() then 'Юридический вопрос просрочен'
      else 'Приближается срок юридического вопроса'
    end,
    m.title,
    coalesce(o.name, ''),
    case when m.due_at < now() then 'high' else 'normal' end
  from public.legal_matters m
  left join public.objects o
    on o.id = m.object_id and o.company_id = m.company_id
  where m.status not in ('resolved','closed')
    and m.due_at is not null
    and m.due_at <= now() + interval '3 days'
  on conflict (company_id, reminder_key) do nothing;
end;
$$;

revoke all on function private.populate_legal_scheduled_reminders()
  from public, anon, authenticated;

create or replace function private.sync_recruitment_application_reminders(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_application public.recruitment_applications%rowtype;
  v_object_name text := '';
  v_body text;
  v_day_before timestamptz;
  v_day_of timestamptz;
  v_role text;
begin
  select * into v_application
  from public.recruitment_applications
  where id = p_application_id;

  if not found then
    return;
  end if;

  update public.scheduled_reminders
  set status = 'cancelled'
  where company_id = v_application.company_id
    and entity_type = 'recruitment_application'
    and entity_id = v_application.id
    and status = 'pending';

  if v_application.archived_at is not null
     or v_application.ready_date is null
     or v_application.status in (
       'in_transit','arrived','hired','reserve','rejected'
     ) then
    return;
  end if;

  select coalesce(name, '') into v_object_name
  from public.objects
  where id = v_application.object_id
    and company_id = v_application.company_id;

  v_body := v_application.full_name || ' · ' ||
    v_application.position_title ||
    case
      when btrim(v_object_name) <> '' then ' · ' || v_object_name
      else ''
    end;

  v_day_before := ((v_application.ready_date - 1) + time '09:00')
    at time zone 'Europe/Moscow';
  v_day_of := (v_application.ready_date + time '09:00')
    at time zone 'Europe/Moscow';

  foreach v_role in array array['admin','hr']::text[] loop
    if v_day_before > now() then
      insert into public.scheduled_reminders(
        company_id,
        reminder_key,
        entity_type,
        entity_id,
        reminder_type,
        due_at,
        recipient_role,
        title,
        body,
        object_name,
        priority
      ) values (
        v_application.company_id,
        'recruitment-ready:' || v_application.id::text || ':' ||
          v_application.ready_date::text || ':' || v_role || ':day-before',
        'recruitment_application',
        v_application.id,
        'candidate_ready_tomorrow',
        v_day_before,
        v_role,
        'Кандидат готов к выезду завтра',
        v_body,
        v_object_name,
        'normal'
      )
      on conflict (company_id, reminder_key) do update
      set due_at = excluded.due_at,
          title = excluded.title,
          body = excluded.body,
          object_name = excluded.object_name,
          priority = excluded.priority,
          status = case
            when public.scheduled_reminders.status = 'sent' then 'sent'
            else 'pending'
          end,
          notification_id = case
            when public.scheduled_reminders.status = 'sent'
              then public.scheduled_reminders.notification_id
            else null
          end,
          sent_at = case
            when public.scheduled_reminders.status = 'sent'
              then public.scheduled_reminders.sent_at
            else null
          end;
    end if;

    if v_application.ready_date >= current_date then
      insert into public.scheduled_reminders(
        company_id,
        reminder_key,
        entity_type,
        entity_id,
        reminder_type,
        due_at,
        recipient_role,
        title,
        body,
        object_name,
        priority
      ) values (
        v_application.company_id,
        'recruitment-ready:' || v_application.id::text || ':' ||
          v_application.ready_date::text || ':' || v_role || ':day-of',
        'recruitment_application',
        v_application.id,
        'candidate_ready_today',
        v_day_of,
        v_role,
        'Кандидат готов к выезду сегодня',
        v_body,
        v_object_name,
        'high'
      )
      on conflict (company_id, reminder_key) do update
      set due_at = excluded.due_at,
          title = excluded.title,
          body = excluded.body,
          object_name = excluded.object_name,
          priority = excluded.priority,
          status = case
            when public.scheduled_reminders.status = 'sent' then 'sent'
            else 'pending'
          end,
          notification_id = case
            when public.scheduled_reminders.status = 'sent'
              then public.scheduled_reminders.notification_id
            else null
          end,
          sent_at = case
            when public.scheduled_reminders.status = 'sent'
              then public.scheduled_reminders.sent_at
            else null
          end;
    end if;
  end loop;
end;
$$;

revoke all on function private.sync_recruitment_application_reminders(uuid)
  from public, anon, authenticated;

create or replace function private.sync_recruitment_application_reminders_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform private.sync_recruitment_application_reminders(new.id);
  return new;
end;
$$;

revoke all on function private.sync_recruitment_application_reminders_trigger()
  from public, anon, authenticated;

drop trigger if exists recruitment_applications_sync_reminders
  on public.recruitment_applications;
create trigger recruitment_applications_sync_reminders
after insert or update of
  ready_date,
  status,
  full_name,
  position_title,
  object_id,
  archived_at
on public.recruitment_applications
for each row
execute function private.sync_recruitment_application_reminders_trigger();

create or replace function private.process_due_scheduled_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reminder public.scheduled_reminders%rowtype;
  v_notification_id uuid;
  v_count integer := 0;
begin
  perform private.populate_legal_scheduled_reminders();

  for v_reminder in
    select r.*
    from public.scheduled_reminders r
    where r.status = 'pending'
      and r.notification_id is null
      and r.due_at <= now()
    order by r.due_at, r.id
    for update skip locked
  loop
    insert into public.app_notifications(
      company_id,
      title,
      body,
      actor_user_id,
      actor_name,
      actor_email,
      object_name,
      entity_type,
      entity_id,
      target_user_id,
      target_role,
      requires_action,
      due_at,
      priority
    ) values (
      v_reminder.company_id,
      v_reminder.title,
      v_reminder.body,
      null,
      'Система AppСтрой',
      '',
      v_reminder.object_name,
      case
        when v_reminder.entity_type in ('legal_document','legal_matter')
          then 'legal_reminder'
        else v_reminder.entity_type
      end,
      v_reminder.entity_id::text,
      v_reminder.recipient_user_id,
      v_reminder.recipient_role,
      true,
      v_reminder.due_at,
      v_reminder.priority
    ) returning id into v_notification_id;

    update public.scheduled_reminders
    set notification_id = v_notification_id,
        status = 'sent',
        sent_at = now()
    where id = v_reminder.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.process_due_scheduled_reminders()
  from public, anon, authenticated;

create or replace function private.retry_failed_push_notification_jobs()
returns integer
language plpgsql
security definer
set search_path = public, net, pg_temp
as $$
declare
  v_job public.push_notification_jobs%rowtype;
  v_count integer := 0;
begin
  for v_job in
    select j.*
    from public.push_notification_jobs j
    where j.status = 'failed'
      and j.attempts < 12
      and coalesce(j.next_attempt_at, now()) <= now()
    order by j.next_attempt_at nulls first, j.created_at
    for update skip locked
  loop
    update public.push_notification_jobs
    set status = 'pending',
        updated_at = now()
    where id = v_job.id;

    perform net.http_post(
      url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/dispatch-push-job',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := jsonb_build_object(
        'job_id', v_job.id,
        'dispatch_token', v_job.dispatch_token
      ),
      timeout_milliseconds := 15000
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.retry_failed_push_notification_jobs()
  from public, anon, authenticated;

do $$
declare
  v_application_id uuid;
  v_job_id bigint;
begin
  for v_application_id in
    select id from public.recruitment_applications
  loop
    perform private.sync_recruitment_application_reminders(v_application_id);
  end loop;

  for v_job_id in
    select jobid
    from cron.job
    where jobname in (
      'appstroy-process-due-reminders',
      'appstroy-retry-failed-push-jobs'
    )
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

select cron.schedule(
  'appstroy-process-due-reminders',
  '*/5 * * * *',
  'select private.process_due_scheduled_reminders();'
);

select cron.schedule(
  'appstroy-retry-failed-push-jobs',
  '*/10 * * * *',
  'select private.retry_failed_push_notification_jobs();'
);
