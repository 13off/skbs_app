-- Restore departure/arrival context for personal flight reminders and add a custom title.
alter table public.recruitment_flight_reminders
  add column if not exists reminder_title text not null default '';

create index if not exists recruitment_flight_reminders_target_user_idx
  on public.recruitment_flight_reminders(target_user_id);

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
  v_title text;
  v_offset_minutes integer;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Нет активной сессии компании';
  end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения уведомлений';
  end if;
  if not exists (
    select 1 from public.recruitment_flights flight
    where flight.id = p_flight_id and flight.company_id = v_company_id
  ) then
    raise exception 'Вылет не найден в выбранной компании';
  end if;
  if jsonb_typeof(coalesce(p_reminders, '[]'::jsonb)) <> 'array' then
    raise exception 'Некорректный список уведомлений';
  end if;
  if jsonb_array_length(coalesce(p_reminders, '[]'::jsonb)) > 20 then
    raise exception 'Для одного вылета можно добавить не больше 20 уведомлений';
  end if;

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
    v_event_kind := case when v_item->>'event_kind' = 'arrival'
      then 'arrival' else 'departure' end;
    v_title := btrim(coalesce(v_item->>'reminder_title', v_item->>'title', ''));

    if v_item ? 'remind_at' then
      begin
        v_remind_at := date_trunc('minute', (v_item->>'remind_at')::timestamptz);
      exception when others then
        raise exception 'Некорректные дата или время уведомления';
      end;
    else
      -- Compatibility for clients that still send the old event + offset payload.
      begin
        v_offset_minutes := (v_item->>'offset_minutes')::integer;
      exception when others then
        raise exception 'Некорректное время уведомления';
      end;
      select date_trunc(
        'minute',
        (case when v_event_kind = 'arrival' then flight.arrival_at else flight.departure_at end)
          - make_interval(mins => greatest(v_offset_minutes, 0))
      ) into v_remind_at
      from public.recruitment_flights flight
      where flight.id = p_flight_id and flight.company_id = v_company_id;
    end if;

    if v_remind_at is null then
      raise exception 'Укажите дату и время уведомления';
    end if;
    if v_event_kind = 'arrival' and not exists (
      select 1 from public.recruitment_flights flight
      where flight.id = p_flight_id
        and flight.company_id = v_company_id
        and flight.arrival_at is not null
    ) then
      raise exception 'Для уведомления о прибытии укажите время прибытия';
    end if;
    if v_title = '' then
      -- Compatibility for the immediately previous client during PWA cache rollover.
      v_title := case when v_event_kind = 'arrival'
        then 'Напоминание о прибытии' else 'Напоминание об отправлении' end;
    end if;
    if char_length(v_title) > 120 then
      raise exception 'Название уведомления должно быть короче 120 символов';
    end if;
    if v_remind_at <= now() and not exists (
      select 1 from public.recruitment_flight_reminders reminder
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
      reminder_title,
      target_user_id,
      created_by,
      updated_by
    ) values (
      v_company_id,
      p_flight_id,
      v_event_kind,
      0,
      v_remind_at,
      v_title,
      v_user_id,
      v_user_id,
      v_user_id
    )
    on conflict (flight_id, target_user_id, remind_at) do update
      set event_kind = excluded.event_kind,
          reminder_title = excluded.reminder_title,
          updated_by = excluded.updated_by,
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
      reminder.event_kind,
      reminder.reminder_title,
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

    v_body := case when v_due.event_kind = 'arrival'
        then 'Прибытие. ' else 'Отправление. ' end ||
      v_due.full_name || '. ' ||
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
      coalesce(nullif(btrim(v_due.reminder_title), ''), 'Напоминание о вылете'),
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
