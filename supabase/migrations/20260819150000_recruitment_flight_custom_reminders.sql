-- Configurable reminders for recruitment flights.
-- Keeps legacy reminder columns for compatibility, but dynamic rows become the source of truth.

create unique index if not exists recruitment_flights_company_id_id_uidx
  on public.recruitment_flights(company_id, id);

create table if not exists public.recruitment_flight_reminders (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  flight_id uuid not null,
  event_kind text not null,
  offset_minutes integer not null default 0,
  sent_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_flight_reminders_flight_fk
    foreign key (company_id, flight_id)
    references public.recruitment_flights(company_id, id)
    on delete cascade,
  constraint recruitment_flight_reminders_event_check
    check (event_kind in ('departure', 'arrival')),
  constraint recruitment_flight_reminders_offset_check
    check (offset_minutes between 0 and 43200),
  constraint recruitment_flight_reminders_unique
    unique (flight_id, event_kind, offset_minutes)
);

create index if not exists recruitment_flight_reminders_company_flight_idx
  on public.recruitment_flight_reminders(company_id, flight_id);
create index if not exists recruitment_flight_reminders_due_idx
  on public.recruitment_flight_reminders(company_id, sent_at, event_kind, offset_minutes)
  where sent_at is null;

alter table public.recruitment_flight_reminders enable row level security;
revoke all on table public.recruitment_flight_reminders from public, anon;
grant select on table public.recruitment_flight_reminders to authenticated;

create policy recruitment_flight_reminders_select on public.recruitment_flight_reminders
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );

-- Backfill the two historical switches without resending reminders already delivered.
insert into public.recruitment_flight_reminders(
  company_id,
  flight_id,
  event_kind,
  offset_minutes,
  sent_at,
  created_by,
  updated_by
)
select
  flight.company_id,
  flight.id,
  'departure',
  1440,
  flight.day_before_sent_at,
  flight.created_by,
  coalesce(flight.updated_by, flight.created_by)
from public.recruitment_flights flight
where flight.remind_day_before
on conflict (flight_id, event_kind, offset_minutes) do nothing;

insert into public.recruitment_flight_reminders(
  company_id,
  flight_id,
  event_kind,
  offset_minutes,
  sent_at,
  created_by,
  updated_by
)
select
  flight.company_id,
  flight.id,
  'departure',
  180,
  flight.three_hours_sent_at,
  flight.created_by,
  coalesce(flight.updated_by, flight.created_by)
from public.recruitment_flights flight
where flight.remind_three_hours
on conflict (flight_id, event_kind, offset_minutes) do nothing;

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

  -- Remove reminders absent from the submitted list. Existing matching rows keep sent_at.
  delete from public.recruitment_flight_reminders reminder
  where reminder.company_id = v_company_id
    and reminder.flight_id = p_flight_id
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb)) item
      where item->>'event_kind' = reminder.event_kind
        and (item->>'offset_minutes')::integer = reminder.offset_minutes
    );

  for v_item in
    select value from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb))
  loop
    v_event_kind := coalesce(v_item->>'event_kind', '');
    begin
      v_offset_minutes := (v_item->>'offset_minutes')::integer;
    exception when others then
      raise exception 'Некорректное время уведомления';
    end;

    if v_event_kind not in ('departure', 'arrival') then
      raise exception 'Некорректное событие уведомления';
    end if;
    if v_offset_minutes < 0 or v_offset_minutes > 43200 then
      raise exception 'Уведомление можно поставить не более чем за 30 дней';
    end if;
    if v_event_kind = 'arrival' and not exists (
      select 1 from public.recruitment_flights flight
      where flight.id = p_flight_id and flight.arrival_at is not null
    ) then
      raise exception 'Для уведомления о прибытии сначала укажите время прибытия';
    end if;

    insert into public.recruitment_flight_reminders(
      company_id,
      flight_id,
      event_kind,
      offset_minutes,
      created_by,
      updated_by
    ) values (
      v_company_id,
      p_flight_id,
      v_event_kind,
      v_offset_minutes,
      v_user_id,
      v_user_id
    )
    on conflict (flight_id, event_kind, offset_minutes) do update
      set updated_by = excluded.updated_by,
          updated_at = now();
  end loop;

  -- Legacy columns stay disabled for newly edited rows so there is one reminder source.
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

create or replace function public.dispatch_due_recruitment_flight_reminders()
returns setof jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_due record;
  v_event_at timestamptz;
  v_message text;
  v_local timestamp;
  v_prefix text;
  v_offset_text text;
begin
  if (select auth.uid()) is null or v_company_id is null then
    return;
  end if;
  if not public.current_user_has_permission('recruitment.applications.view') then
    return;
  end if;

  for v_due in
    select
      reminder.id as reminder_id,
      reminder.event_kind,
      reminder.offset_minutes,
      flight.*
    from public.recruitment_flight_reminders reminder
    join public.recruitment_flights flight
      on flight.company_id = reminder.company_id
     and flight.id = reminder.flight_id
    where reminder.company_id = v_company_id
      and reminder.sent_at is null
      and flight.status not in ('arrived', 'cancelled')
      and case reminder.event_kind
        when 'arrival' then flight.arrival_at is not null
          and now() >= flight.arrival_at - make_interval(mins => reminder.offset_minutes)
          and now() <= flight.arrival_at + interval '12 hours'
        else now() >= flight.departure_at - make_interval(mins => reminder.offset_minutes)
          and now() <= flight.departure_at + interval '12 hours'
      end
    order by
      case reminder.event_kind
        when 'arrival' then flight.arrival_at
        else flight.departure_at
      end,
      reminder.offset_minutes desc
    for update of reminder skip locked
  loop
    update public.recruitment_flight_reminders
    set sent_at = now(), updated_at = now()
    where id = v_due.reminder_id and sent_at is null;

    if not found then
      continue;
    end if;

    v_event_at := case v_due.event_kind
      when 'arrival' then v_due.arrival_at
      else v_due.departure_at
    end;
    v_local := v_event_at at time zone 'Europe/Moscow';

    v_offset_text := case
      when v_due.offset_minutes = 0 then 'сейчас'
      when v_due.offset_minutes < 60 then 'через ' || v_due.offset_minutes || ' мин.'
      when v_due.offset_minutes % 1440 = 0 then 'через ' || (v_due.offset_minutes / 1440) || ' дн.'
      when v_due.offset_minutes % 60 = 0 then 'через ' || (v_due.offset_minutes / 60) || ' ч.'
      else 'через ' || (v_due.offset_minutes / 60) || ' ч. ' || (v_due.offset_minutes % 60) || ' мин.'
    end;

    v_prefix := case v_due.event_kind
      when 'arrival' then
        case when v_due.offset_minutes = 0
          then 'По плану сейчас прибытие.'
          else 'До прибытия ' || v_offset_text || '.' end
      else
        case when v_due.offset_minutes = 0
          then 'По плану сейчас отправление.'
          else 'До отправления ' || v_offset_text || '.' end
    end;

    v_message := v_prefix || ' ' ||
      to_char(v_local, 'DD.MM.YYYY в HH24:MI') || '. Маршрут: ' ||
      btrim(v_due.origin) || ' → ' || btrim(v_due.destination) || '. ' ||
      case when btrim(v_due.flight_number) = '' then ''
        else 'Рейс ' || btrim(v_due.flight_number) || '. ' end ||
      'Проверьте документы и время поездки.';

    return next private.create_recruitment_flight_notification(
      v_due.id,
      case v_due.event_kind
        when 'arrival' then 'arrival_reminder'
        else 'departure_reminder'
      end,
      v_message,
      null
    );
  end loop;
end;
$$;

revoke all on function public.dispatch_due_recruitment_flight_reminders()
  from public, anon;
grant execute on function public.dispatch_due_recruitment_flight_reminders()
  to authenticated;
