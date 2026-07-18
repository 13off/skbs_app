create table if not exists public.dispatcher_summary_settings (
  company_id uuid primary key references public.companies(id) on delete cascade,
  enabled boolean not null default false,
  local_time time without time zone not null default '18:30',
  timezone text not null default 'Europe/Moscow',
  weekdays smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  recipient_roles text[] not null default array['admin']::text[],
  in_app_enabled boolean not null default true,
  push_enabled boolean not null default true,
  include_tasks boolean not null default true,
  include_attendance boolean not null default true,
  include_employees boolean not null default true,
  include_payments boolean not null default true,
  include_recruitment boolean not null default true,
  include_legal boolean not null default true,
  include_milestones boolean not null default true,
  include_empty_sections boolean not null default false,
  ai_commentary boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint dispatcher_summary_settings_channels_check
    check (in_app_enabled or push_enabled),
  constraint dispatcher_summary_settings_weekdays_check
    check (
      cardinality(weekdays) > 0
      and weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
    ),
  constraint dispatcher_summary_settings_roles_check
    check (
      cardinality(recipient_roles) > 0
      and recipient_roles <@ array['admin','foreman','hr','accountant','lawyer']::text[]
    )
);

create table if not exists public.dispatcher_summary_runs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  summary_date date not null,
  scheduled_for timestamptz not null,
  status text not null default 'pending',
  dispatch_token uuid not null default gen_random_uuid(),
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  title text not null default '',
  body text not null default '',
  payload jsonb not null default '{}'::jsonb,
  ai_used boolean not null default false,
  error_text text not null default '',
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dispatcher_summary_runs_status_check
    check (status in ('pending','processing','sent','failed')),
  constraint dispatcher_summary_runs_company_date_key
    unique(company_id, summary_date)
);

create index if not exists dispatcher_summary_runs_due_idx
  on public.dispatcher_summary_runs(status, next_attempt_at, scheduled_for)
  where status in ('pending','processing','failed');

alter table public.dispatcher_summary_settings enable row level security;
alter table public.dispatcher_summary_runs enable row level security;

drop policy if exists dispatcher_summary_settings_select_admin
  on public.dispatcher_summary_settings;
create policy dispatcher_summary_settings_select_admin
  on public.dispatcher_summary_settings
  for select to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.is_admin()
  );

drop policy if exists dispatcher_summary_settings_insert_admin
  on public.dispatcher_summary_settings;
create policy dispatcher_summary_settings_insert_admin
  on public.dispatcher_summary_settings
  for insert to authenticated
  with check (
    company_id = public.current_user_company_id()
    and public.is_admin()
  );

drop policy if exists dispatcher_summary_settings_update_admin
  on public.dispatcher_summary_settings;
create policy dispatcher_summary_settings_update_admin
  on public.dispatcher_summary_settings
  for update to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.is_admin()
  )
  with check (
    company_id = public.current_user_company_id()
    and public.is_admin()
  );

drop policy if exists dispatcher_summary_runs_select_admin
  on public.dispatcher_summary_runs;
create policy dispatcher_summary_runs_select_admin
  on public.dispatcher_summary_runs
  for select to authenticated
  using (
    company_id = public.current_user_company_id()
    and public.is_admin()
  );

create or replace function private.validate_dispatcher_summary_settings()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from pg_timezone_names where name = new.timezone
  ) then
    raise exception 'Неизвестный часовой пояс: %', new.timezone;
  end if;

  new.weekdays := array(
    select distinct value
    from unnest(new.weekdays) value
    order by value
  );
  new.recipient_roles := array(
    select distinct value
    from unnest(new.recipient_roles) value
    order by value
  );
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

drop trigger if exists dispatcher_summary_settings_validate
  on public.dispatcher_summary_settings;
create trigger dispatcher_summary_settings_validate
before insert or update on public.dispatcher_summary_settings
for each row execute function private.validate_dispatcher_summary_settings();

create or replace function private.audit_dispatcher_summary_settings()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.developer_settings_audit(
    company_id,
    object_id,
    setting_group,
    action,
    old_value,
    new_value,
    changed_by,
    changed_at
  ) values (
    coalesce(new.company_id, old.company_id),
    null,
    'dispatcher_summary',
    lower(tg_op),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end,
    auth.uid(),
    now()
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists dispatcher_summary_settings_audit
  on public.dispatcher_summary_settings;
create trigger dispatcher_summary_settings_audit
after insert or update or delete on public.dispatcher_summary_settings
for each row execute function private.audit_dispatcher_summary_settings();

create or replace function public.get_dispatcher_summary_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_settings public.dispatcher_summary_settings%rowtype;
  v_runs jsonb;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для настроек ИИ-диспетчера';
  end if;

  insert into public.dispatcher_summary_settings(company_id, updated_by)
  values(v_company_id, auth.uid())
  on conflict(company_id) do nothing;

  select * into v_settings
  from public.dispatcher_summary_settings
  where company_id = v_company_id;

  select coalesce(
    jsonb_agg(to_jsonb(r) order by r.created_at desc),
    '[]'::jsonb
  ) into v_runs
  from (
    select
      id,
      summary_date,
      scheduled_for,
      status,
      title,
      body,
      payload,
      ai_used,
      error_text,
      sent_at,
      attempts,
      created_at
    from public.dispatcher_summary_runs
    where company_id = v_company_id
    order by created_at desc
    limit 14
  ) r;

  return jsonb_build_object(
    'settings', to_jsonb(v_settings),
    'runs', v_runs,
    'server_time', now()
  );
end;
$$;

grant execute on function public.get_dispatcher_summary_center()
  to authenticated;

create or replace function public.save_dispatcher_summary_settings(
  p_settings jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_value public.dispatcher_summary_settings%rowtype;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для настроек ИИ-диспетчера';
  end if;

  insert into public.dispatcher_summary_settings(
    company_id,
    enabled,
    local_time,
    timezone,
    weekdays,
    recipient_roles,
    in_app_enabled,
    push_enabled,
    include_tasks,
    include_attendance,
    include_employees,
    include_payments,
    include_recruitment,
    include_legal,
    include_milestones,
    include_empty_sections,
    ai_commentary,
    updated_by
  ) values (
    v_company_id,
    coalesce((p_settings->>'enabled')::boolean, false),
    coalesce((p_settings->>'local_time')::time, '18:30'::time),
    coalesce(
      nullif(btrim(p_settings->>'timezone'), ''),
      'Europe/Moscow'
    ),
    coalesce(
      array(
        select jsonb_array_elements_text(
          p_settings->'weekdays'
        )::smallint
      ),
      array[1,2,3,4,5,6,7]::smallint[]
    ),
    coalesce(
      array(
        select jsonb_array_elements_text(
          p_settings->'recipient_roles'
        )
      ),
      array['admin']::text[]
    ),
    coalesce((p_settings->>'in_app_enabled')::boolean, true),
    coalesce((p_settings->>'push_enabled')::boolean, true),
    coalesce((p_settings->>'include_tasks')::boolean, true),
    coalesce((p_settings->>'include_attendance')::boolean, true),
    coalesce((p_settings->>'include_employees')::boolean, true),
    coalesce((p_settings->>'include_payments')::boolean, true),
    coalesce((p_settings->>'include_recruitment')::boolean, true),
    coalesce((p_settings->>'include_legal')::boolean, true),
    coalesce((p_settings->>'include_milestones')::boolean, true),
    coalesce((p_settings->>'include_empty_sections')::boolean, false),
    coalesce((p_settings->>'ai_commentary')::boolean, true),
    auth.uid()
  )
  on conflict(company_id) do update set
    enabled = excluded.enabled,
    local_time = excluded.local_time,
    timezone = excluded.timezone,
    weekdays = excluded.weekdays,
    recipient_roles = excluded.recipient_roles,
    in_app_enabled = excluded.in_app_enabled,
    push_enabled = excluded.push_enabled,
    include_tasks = excluded.include_tasks,
    include_attendance = excluded.include_attendance,
    include_employees = excluded.include_employees,
    include_payments = excluded.include_payments,
    include_recruitment = excluded.include_recruitment,
    include_legal = excluded.include_legal,
    include_milestones = excluded.include_milestones,
    include_empty_sections = excluded.include_empty_sections,
    ai_commentary = excluded.ai_commentary,
    updated_by = auth.uid()
  returning * into v_value;

  return to_jsonb(v_value);
end;
$$;

grant execute on function public.save_dispatcher_summary_settings(jsonb)
  to authenticated;

create or replace function private.process_due_dispatcher_summaries()
returns integer
language plpgsql
security definer
set search_path = public, net, pg_temp
as $$
declare
  v_setting public.dispatcher_summary_settings%rowtype;
  v_run public.dispatcher_summary_runs%rowtype;
  v_local_now timestamp;
  v_local_date date;
  v_scheduled_for timestamptz;
  v_count integer := 0;
begin
  for v_setting in
    select s.*
    from public.dispatcher_summary_settings s
    join public.companies c
      on c.id = s.company_id
     and c.status = 'active'
    where s.enabled = true
  loop
    v_local_now := now() at time zone v_setting.timezone;
    v_local_date := v_local_now::date;

    if extract(isodow from v_local_date)::smallint = any(v_setting.weekdays)
       and v_local_now::time >= v_setting.local_time then
      v_scheduled_for :=
        (v_local_date + v_setting.local_time)
        at time zone v_setting.timezone;

      insert into public.dispatcher_summary_runs(
        company_id,
        summary_date,
        scheduled_for,
        status,
        next_attempt_at
      ) values (
        v_setting.company_id,
        v_local_date,
        v_scheduled_for,
        'pending',
        now()
      )
      on conflict(company_id, summary_date) do nothing;
    end if;
  end loop;

  for v_run in
    select r.*
    from public.dispatcher_summary_runs r
    where r.attempts < 5
      and (
        (
          r.status in ('pending','failed')
          and coalesce(r.next_attempt_at, r.scheduled_for) <= now()
        )
        or (
          r.status = 'processing'
          and r.updated_at <= now() - interval '15 minutes'
        )
      )
    order by r.scheduled_for, r.created_at
    for update skip locked
  loop
    update public.dispatcher_summary_runs
    set
      status = 'processing',
      attempts = attempts + 1,
      updated_at = now(),
      error_text = ''
    where id = v_run.id;

    perform net.http_post(
      url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/daily-dispatcher-summary',
      headers := jsonb_build_object(
        'Content-Type',
        'application/json'
      ),
      body := jsonb_build_object(
        'run_id',
        v_run.id,
        'dispatch_token',
        v_run.dispatch_token
      ),
      timeout_milliseconds := 30000
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.process_due_dispatcher_summaries()
  from public;

create or replace function public.run_dispatcher_summary_now()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_settings public.dispatcher_summary_settings%rowtype;
  v_run_id uuid;
  v_local_date date;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для запуска ИИ-диспетчера';
  end if;

  select * into v_settings
  from public.dispatcher_summary_settings
  where company_id = v_company_id;

  if not found then
    insert into public.dispatcher_summary_settings(
      company_id,
      updated_by
    ) values (
      v_company_id,
      auth.uid()
    ) returning * into v_settings;
  end if;

  v_local_date := (now() at time zone v_settings.timezone)::date;

  insert into public.dispatcher_summary_runs(
    company_id,
    summary_date,
    scheduled_for,
    status,
    next_attempt_at
  ) values (
    v_company_id,
    v_local_date,
    now(),
    'pending',
    now()
  )
  on conflict(company_id, summary_date) do update set
    status = 'pending',
    dispatch_token = gen_random_uuid(),
    attempts = 0,
    next_attempt_at = now(),
    title = '',
    body = '',
    payload = '{}'::jsonb,
    ai_used = false,
    error_text = '',
    sent_at = null,
    updated_at = now()
  returning id into v_run_id;

  perform private.process_due_dispatcher_summaries();
  return v_run_id;
end;
$$;

grant execute on function public.run_dispatcher_summary_now()
  to authenticated;

alter table public.app_notifications
  add column if not exists push_requested boolean not null default true;

create or replace function private.queue_push_notification_job()
returns trigger
language plpgsql
security definer
set search_path = public, net, pg_temp
as $$
declare
  v_job public.push_notification_jobs%rowtype;
begin
  if new.push_requested is not true then
    return new;
  end if;

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
    headers := jsonb_build_object(
      'Content-Type',
      'application/json'
    ),
    body := jsonb_build_object(
      'job_id',
      v_job.id,
      'dispatch_token',
      v_job.dispatch_token
    ),
    timeout_milliseconds := 15000
  );

  return new;
end;
$$;

do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid
  from cron.job
  where jobname = 'appstroy-dispatcher-daily-summary'
  limit 1;

  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;

  perform cron.schedule(
    'appstroy-dispatcher-daily-summary',
    '*/5 * * * *',
    'select private.process_due_dispatcher_summaries();'
  );
end;
$$;
