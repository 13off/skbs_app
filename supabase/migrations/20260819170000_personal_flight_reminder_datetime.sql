-- Personal flight reminders use an exact timestamp chosen by the current user.
-- Arrival/departure fields on recruitment_flights remain unchanged.

alter table public.recruitment_flight_reminders
  add column if not exists remind_at timestamptz;
alter table public.recruitment_flight_reminders
  add column if not exists target_user_id uuid references auth.users(id) on delete cascade;

-- Rows created by the previous automatic 24h/3h employee-reminder model are intentionally
-- removed: the product now creates reminders only when a user explicitly picks date/time.
delete from public.recruitment_flight_reminders
where remind_at is null or target_user_id is null;

alter table public.recruitment_flight_reminders
  alter column remind_at set not null;
alter table public.recruitment_flight_reminders
  alter column target_user_id set not null;

alter table public.recruitment_flight_reminders
  drop constraint if exists recruitment_flight_reminders_unique;
drop index if exists public.recruitment_flight_reminders_due_idx;

create unique index if not exists recruitment_flight_reminders_personal_time_uidx
  on public.recruitment_flight_reminders(flight_id, target_user_id, remind_at);
create index if not exists recruitment_flight_reminders_personal_due_idx
  on public.recruitment_flight_reminders(remind_at, sent_at)
  where sent_at is null;

-- A user sees only their own reminders. Writes stay behind the scoped RPC below.
drop policy if exists recruitment_flight_reminders_select
  on public.recruitment_flight_reminders;
create policy recruitment_flight_reminders_select
  on public.recruitment_flight_reminders
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and target_user_id = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.view')
  );

create or replace function public.replace_recruitment_flight_reminders(
  p_flight_id uuid,
  p_reminders jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_item jsonb;
  v_remind_at timestamptz;
  v_event_kind text;
  v_offset_minutes integer;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Нет активной сессии компании';
  end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения уведомлений';
  end if;
  if not exists (
    select 1
    from public.recruitment_flights flight
    where flight.id = p_flight_id
      and flight.company_id = v_company_id
  ) then
    raise exception 'Вылет не найден в выбранной компании';
  end if;
  if jsonb_typeof(coalesce(p_reminders, '[]'::jsonb)) <> 'array' then
    raise exception 'Некорректный список уведомлений';
  end if;
  if jsonb_array_length(coalesce(p_reminders, '[]'::jsonb)) > 20 then
    raise exception 'Для одного вылета можно добавить не больше 20 уведомлений';
  end if;

  -- Submitted timestamps are the full source of truth for the current user's reminders.
  delete from public.recruitment_flight_reminders reminder
  where reminder.company_id = v_company_id
    and reminder.flight_id = p_flight_id
    and reminder.target_user_id = v_user_id
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb)) item
      where item ? 'remind_at'
        and date_trunc('minute', (item->>'remind_at')::timestamptz)
          = date_trunc('minute', reminder.remind_at)
    );

  for v_item in
    select value from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb))
  loop
    if v_item ? 'remind_at' then
      begin
        v_remind_at := date_trunc('minute', (v_item->>'remind_at')::timestamptz);
      exception when others then
        raise exception 'Некорректные дата или время уведомления';
      end;
    else
      -- Compatibility for older installed clients during the rollout.
      v_event_kind := case when v_item->>'event_kind' = 'arrival'
        then 'arrival' else 'departure' end;
      begin
        v_offset_minutes := (v_item->>'offset_minutes')::integer;
      exception when others then
        raise exception 'Некорректное время уведомления';
      end;
      select date_trunc(
        'minute',
        (case when v_event_kind = 'arrival' then flight.arrival_at else flight.departure_at end)
          - make_interval(mins => greatest(v_offset_minutes, 0))
      )
      into v_remind_at
      from public.recruitment_flights flight
      where flight.id = p_flight_id
        and flight.company_id = v_company_id;
    end if;

    if v_remind_at is null then
      raise exception 'Укажите дату и время уведомления';
    end if;
    if v_remind_at <= now() and not exists (
      select 1
      from public.recruitment_flight_reminders reminder
      where reminder.company_id = v_company_id
        and reminder.flight_id = p_flight_id
        and reminder.target_user_id = v_user_id
        and reminder.remind_at = v_remind_at
        and reminder.sent_at is not null
    ) then
      raise exception 'Дата и время уведомления уже прошли';
    end if;

    insert into public.recruitment_flight_reminders(
      company_id,
      flight_id,
      event_kind,
      offset_minutes,
      remind_at,
      target_user_id,
      created_by,
      updated_by
    ) values (
      v_company_id,
      p_flight_id,
      'departure',
      0,
      v_remind_at,
      v_user_id,
      v_user_id,
      v_user_id
    )
    on conflict (flight_id, target_user_id, remind_at) do update
      set updated_by = excluded.updated_by,
          updated_at = now();
  end loop;

  update public.recruitment_flights
  set remind_day_before = false,
      remind_three_hours = false,
      updated_by = v_user_id,
      updated_at = now()
  where id = p_flight_id and company_id = v_company_id;
end;
$$;

revoke all on function public.replace_recruitment_flight_reminders(uuid,jsonb)
  from public, anon;
grant execute on function public.replace_recruitment_flight_reminders(uuid,jsonb)
  to authenticated;

create or replace function private.process_due_recruitment_flight_personal_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_due record;
  v_body text;
  v_departure_local timestamp;
  v_arrival_local timestamp;
  v_count integer := 0;
begin
  for v_due in
    select
      reminder.id as reminder_id,
      reminder.company_id,
      reminder.target_user_id,
      reminder.remind_at,
      flight.id as flight_id,
      flight.origin,
      flight.destination,
      flight.flight_number,
      flight.departure_at,
      flight.arrival_at,
      coalesce(application.full_name, 'Сотрудник') as full_name,
      coalesce(object_row.name, '') as object_name
    from public.recruitment_flight_reminders reminder
    join public.recruitment_flights flight
      on flight.company_id = reminder.company_id
     and flight.id = reminder.flight_id
    left join public.recruitment_applications application
      on application.company_id = flight.company_id
     and application.id = flight.application_id
    left join public.objects object_row
      on object_row.company_id = flight.company_id
     and object_row.id = flight.object_id
    where reminder.sent_at is null
      and reminder.remind_at <= now()
      and flight.status <> 'cancelled'
    order by reminder.remind_at, reminder.id
    for update of reminder skip locked
  loop
    v_departure_local := v_due.departure_at at time zone 'Europe/Moscow';
    v_arrival_local := case when v_due.arrival_at is null
      then null else v_due.arrival_at at time zone 'Europe/Moscow' end;

    v_body := v_due.full_name || '. ' ||
      btrim(v_due.origin) || ' → ' || btrim(v_due.destination) || '. ' ||
      'Вылет ' || to_char(v_departure_local, 'DD.MM.YYYY в HH24:MI') || '.' ||
      case when v_arrival_local is null then ''
        else ' Прибытие ' || to_char(v_arrival_local, 'DD.MM.YYYY в HH24:MI') || '.' end ||
      case when btrim(v_due.flight_number) = '' then ''
        else ' Рейс ' || btrim(v_due.flight_number) || '.' end;

    insert into public.app_notifications(
      title,
      body,
      actor_user_id,
      actor_name,
      actor_email,
      object_name,
      entity_type,
      entity_id,
      company_id,
      target_user_id,
      target_role,
      requires_action,
      due_at,
      priority,
      source_role,
      is_push_only,
      push_requested
    ) values (
      'Напоминание о вылете',
      v_body,
      null,
      'AppСтрой',
      '',
      v_due.object_name,
      'recruitment_flight_reminder',
      v_due.flight_id::text,
      v_due.company_id,
      v_due.target_user_id,
      null,
      false,
      v_due.remind_at,
      'normal',
      'hr',
      false,
      true
    );

    update public.recruitment_flight_reminders
    set sent_at = now(), updated_at = now()
    where id = v_due.reminder_id and sent_at is null;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.process_due_recruitment_flight_personal_reminders()
  from public, anon, authenticated;

-- Old clients may still invoke this public dispatcher while caches roll over.
-- It intentionally returns no employee-facing rows; scheduled delivery is cron-owned.
create or replace function public.dispatch_due_recruitment_flight_reminders()
returns setof jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return;
end;
$$;

revoke all on function public.dispatch_due_recruitment_flight_reminders()
  from public, anon;
grant execute on function public.dispatch_due_recruitment_flight_reminders()
  to authenticated;

-- Exact reminders are checked every minute. Push delivery is queued by the existing
-- app_notifications trigger, so the creator receives both in-app and push delivery.
do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'appstroy-flight-personal-reminders';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'appstroy-flight-personal-reminders',
    '* * * * *',
    'select private.process_due_recruitment_flight_personal_reminders();'
  );
end;
$$;
