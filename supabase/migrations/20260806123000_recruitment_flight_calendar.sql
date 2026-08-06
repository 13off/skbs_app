-- HR flight calendar: ticket attachment, exact departure time and employee reminders.

create table if not exists public.recruitment_flights (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null,
  employee_id uuid references public.employees(id) on delete set null,
  object_id uuid references public.objects(id) on delete set null,
  departure_at timestamptz not null,
  arrival_at timestamptz,
  origin text not null,
  destination text not null,
  flight_number text not null default '',
  status text not null default 'scheduled',
  remind_day_before boolean not null default true,
  remind_three_hours boolean not null default true,
  day_before_sent_at timestamptz,
  three_hours_sent_at timestamptz,
  last_manual_reminder_at timestamptz,
  ticket_bucket text not null default 'recruitment-documents',
  ticket_path text not null,
  ticket_original_name text not null,
  ticket_mime_type text not null default 'application/pdf',
  ticket_size_bytes bigint,
  notes text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_flights_company_application_fk
    foreign key (company_id, application_id)
    references public.recruitment_applications(company_id, id)
    on delete cascade,
  constraint recruitment_flights_route_check
    check (char_length(btrim(origin)) between 1 and 160 and char_length(btrim(destination)) between 1 and 160),
  constraint recruitment_flights_ticket_check
    check (char_length(btrim(ticket_bucket)) > 0 and char_length(btrim(ticket_path)) > 0 and char_length(btrim(ticket_original_name)) > 0),
  constraint recruitment_flights_status_check
    check (status in ('scheduled','checked_in','departed','arrived','cancelled')),
  constraint recruitment_flights_arrival_check
    check (arrival_at is null or arrival_at > departure_at),
  constraint recruitment_flights_notes_check
    check (char_length(notes) <= 5000)
);

create index if not exists recruitment_flights_company_departure_idx
  on public.recruitment_flights(company_id, departure_at, status);
create index if not exists recruitment_flights_application_idx
  on public.recruitment_flights(company_id, application_id, departure_at desc);
create index if not exists recruitment_flights_employee_idx
  on public.recruitment_flights(company_id, employee_id, departure_at desc)
  where employee_id is not null;
create index if not exists recruitment_flights_due_day_before_idx
  on public.recruitment_flights(company_id, departure_at)
  where remind_day_before and day_before_sent_at is null and status = 'scheduled';
create index if not exists recruitment_flights_due_three_hours_idx
  on public.recruitment_flights(company_id, departure_at)
  where remind_three_hours and three_hours_sent_at is null and status = 'scheduled';

create or replace function private.validate_recruitment_flight_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.recruitment_applications application
    where application.id = new.application_id
      and application.company_id = new.company_id
      and application.archived_at is null
  ) then
    raise exception 'Кандидат не найден в выбранной компании';
  end if;

  if new.employee_id is not null and not exists (
    select 1
    from public.employees employee
    where employee.id = new.employee_id
      and employee.archived_at is null
  ) then
    raise exception 'Сотрудник не найден';
  end if;

  if new.object_id is not null and not exists (
    select 1
    from public.objects object_row
    where object_row.id = new.object_id
      and object_row.company_id = new.company_id
  ) then
    raise exception 'Объект не относится к выбранной компании';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_recruitment_flight_scope()
  from public, anon, authenticated;

drop trigger if exists recruitment_flights_validate_scope on public.recruitment_flights;
create trigger recruitment_flights_validate_scope
  before insert or update on public.recruitment_flights
  for each row execute function private.validate_recruitment_flight_scope();

drop trigger if exists recruitment_flights_touch_updated_at on public.recruitment_flights;
create trigger recruitment_flights_touch_updated_at
  before update on public.recruitment_flights
  for each row execute function public.touch_updated_at();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_flights;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_flights
  for each row execute function private.broadcast_app_data_change();

alter table public.recruitment_flights enable row level security;
revoke all on table public.recruitment_flights from public, anon;
grant select, insert, update, delete on table public.recruitment_flights to authenticated;

create policy recruitment_flights_select on public.recruitment_flights
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );

create policy recruitment_flights_insert on public.recruitment_flights
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and updated_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  );

create policy recruitment_flights_update on public.recruitment_flights
  for update to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  ) with check (
    company_id = (select public.current_user_company_id())
    and updated_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  );

create policy recruitment_flights_delete on public.recruitment_flights
  for delete to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  );

create or replace function private.recruitment_flight_target_user(
  p_company_id uuid,
  p_employee_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select link.user_id
  from public.employees employee
  join public.employee_account_links link
    on link.company_id = p_company_id
   and link.person_id = employee.person_id
   and link.is_active
  join public.user_profiles profile
    on profile.id = link.user_id
   and profile.role = 'employee'
   and profile.is_active
  where employee.id = p_employee_id
    and employee.person_id is not null
  order by link.updated_at desc nulls last, link.created_at desc
  limit 1;
$$;

revoke all on function private.recruitment_flight_target_user(uuid,uuid)
  from public, anon, authenticated;

create or replace function private.create_recruitment_flight_notification(
  p_flight_id uuid,
  p_kind text,
  p_message text,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_flight public.recruitment_flights%rowtype;
  v_application public.recruitment_applications%rowtype;
  v_target_user_id uuid;
  v_notification_id uuid;
  v_object_name text := '';
  v_actor_name text := 'Система AppСтрой';
  v_actor_email text := '';
  v_title text;
begin
  select * into v_flight
  from public.recruitment_flights
  where id = p_flight_id;
  if v_flight.id is null then
    raise exception 'Вылет не найден';
  end if;

  select * into v_application
  from public.recruitment_applications
  where id = v_flight.application_id
    and company_id = v_flight.company_id;

  if v_flight.object_id is not null then
    select object_row.name into v_object_name
    from public.objects object_row
    where object_row.id = v_flight.object_id;
  end if;

  if p_actor_user_id is not null then
    select
      coalesce(nullif(btrim(profile.full_name), ''), nullif(btrim(profile.email), ''), 'Пользователь AppСтрой'),
      coalesce(profile.email, '')
    into v_actor_name, v_actor_email
    from public.user_profiles profile
    where profile.id = p_actor_user_id;
  end if;

  if v_flight.employee_id is not null then
    v_target_user_id := private.recruitment_flight_target_user(
      v_flight.company_id,
      v_flight.employee_id
    );
  end if;

  v_title := case p_kind
    when 'day_before' then 'Завтра вылет'
    when 'three_hours' then 'До вылета около 3 часов'
    else 'Напоминание о вылете'
  end;

  if v_target_user_id is not null then
    insert into public.app_notifications(
      title,
      body,
      actor_user_id,
      actor_name,
      actor_email,
      object_name,
      entity_type,
      entity_id,
      target_user_id,
      source_role,
      requires_action,
      due_at,
      priority
    ) values (
      v_title,
      left(btrim(p_message), 2000),
      p_actor_user_id,
      v_actor_name,
      v_actor_email,
      coalesce(v_object_name, ''),
      'recruitment_flight',
      v_flight.id::text,
      v_target_user_id,
      case when p_actor_user_id is null then 'system' else coalesce(public.current_user_role(), 'hr') end,
      false,
      v_flight.departure_at,
      'high'
    ) returning id into v_notification_id;
  end if;

  perform private.add_recruitment_crm_activity(
    v_flight.company_id,
    v_flight.application_id,
    'flight_reminder',
    v_title,
    left(btrim(p_message), 2000),
    jsonb_build_object(
      'flight_id', v_flight.id,
      'kind', p_kind,
      'target_user_id', v_target_user_id
    ),
    p_actor_user_id
  );

  return jsonb_build_object(
    'notification_id', v_notification_id,
    'application_id', v_flight.application_id,
    'message', left(btrim(p_message), 2000),
    'has_app_recipient', v_target_user_id is not null
  );
end;
$$;

revoke all on function private.create_recruitment_flight_notification(uuid,text,text,uuid)
  from public, anon, authenticated;

create or replace function public.send_recruitment_flight_reminder(
  p_flight_id uuid,
  p_kind text default 'manual',
  p_message text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if (select auth.uid()) is null or v_company_id is null then
    raise exception 'Нет активной сессии компании';
  end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для напоминания сотруднику';
  end if;
  if p_kind not in ('manual','day_before','three_hours') then
    raise exception 'Неизвестный тип напоминания';
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 2000 then
    raise exception 'Текст напоминания пустой или слишком длинный';
  end if;
  if not exists (
    select 1 from public.recruitment_flights flight
    where flight.id = p_flight_id and flight.company_id = v_company_id
  ) then
    raise exception 'Вылет не найден в выбранной компании';
  end if;

  update public.recruitment_flights
  set last_manual_reminder_at = now(),
      updated_by = (select auth.uid()),
      updated_at = now()
  where id = p_flight_id and company_id = v_company_id;

  v_result := private.create_recruitment_flight_notification(
    p_flight_id,
    p_kind,
    p_message,
    (select auth.uid())
  );
  return v_result;
end;
$$;

revoke all on function public.send_recruitment_flight_reminder(uuid,text,text)
  from public, anon;
grant execute on function public.send_recruitment_flight_reminder(uuid,text,text)
  to authenticated;

create or replace function public.dispatch_due_recruitment_flight_reminders()
returns setof jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_flight public.recruitment_flights%rowtype;
  v_kind text;
  v_message text;
  v_local timestamptz;
begin
  if (select auth.uid()) is null or v_company_id is null then
    return;
  end if;
  if not public.current_user_has_permission('recruitment.applications.view') then
    return;
  end if;

  for v_flight in
    select flight.*
    from public.recruitment_flights flight
    where flight.company_id = v_company_id
      and flight.status = 'scheduled'
      and flight.departure_at > now()
      and (
        (flight.remind_day_before and flight.day_before_sent_at is null
          and now() >= flight.departure_at - interval '24 hours')
        or
        (flight.remind_three_hours and flight.three_hours_sent_at is null
          and now() >= flight.departure_at - interval '3 hours')
      )
    order by flight.departure_at
    for update skip locked
  loop
    if v_flight.remind_three_hours
       and v_flight.three_hours_sent_at is null
       and now() >= v_flight.departure_at - interval '3 hours' then
      v_kind := 'three_hours';
      update public.recruitment_flights
      set three_hours_sent_at = now(), updated_at = now()
      where id = v_flight.id and three_hours_sent_at is null;
    else
      v_kind := 'day_before';
      update public.recruitment_flights
      set day_before_sent_at = now(), updated_at = now()
      where id = v_flight.id and day_before_sent_at is null;
    end if;

    v_local := v_flight.departure_at at time zone 'Europe/Moscow';
    v_message := case v_kind
      when 'three_hours' then 'До вылета осталось около 3 часов. '
      else 'Напоминаем: завтра вылет. '
    end ||
      to_char(v_local, 'DD.MM.YYYY в HH24:MI') || '. Маршрут: ' ||
      btrim(v_flight.origin) || ' → ' || btrim(v_flight.destination) || '. ' ||
      case when btrim(v_flight.flight_number) = '' then ''
        else 'Рейс ' || btrim(v_flight.flight_number) || '. ' end ||
      'Проверьте документы и приезжайте в аэропорт заранее.';

    return next private.create_recruitment_flight_notification(
      v_flight.id,
      v_kind,
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

create or replace function private.log_recruitment_flight_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_body text;
begin
  if tg_op = 'INSERT' then
    v_title := 'Билет прикреплён — вылет добавлен';
  elsif new.status is distinct from old.status then
    v_title := 'Статус вылета изменён';
  else
    v_title := 'Данные вылета обновлены';
  end if;
  v_body := btrim(new.origin) || ' → ' || btrim(new.destination) ||
    ', ' || to_char(new.departure_at at time zone 'Europe/Moscow', 'DD.MM.YYYY HH24:MI');
  perform private.add_recruitment_crm_activity(
    new.company_id,
    new.application_id,
    'flight',
    v_title,
    v_body,
    jsonb_build_object(
      'flight_id', new.id,
      'status', new.status,
      'flight_number', new.flight_number,
      'ticket_name', new.ticket_original_name
    ),
    coalesce(new.updated_by, new.created_by)
  );
  return new;
end;
$$;

revoke all on function private.log_recruitment_flight_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_flights_log_activity on public.recruitment_flights;
create trigger recruitment_flights_log_activity
  after insert or update on public.recruitment_flights
  for each row execute function private.log_recruitment_flight_activity();
