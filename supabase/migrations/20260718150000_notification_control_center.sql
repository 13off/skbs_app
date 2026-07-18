alter table public.notification_role_preferences
  add column if not exists in_app_enabled boolean not null default true,
  add column if not exists push_enabled boolean not null default true,
  add column if not exists selected_event_groups text[] not null default array[
    'tasks','attendance','employees','hr','payments','legal','system'
  ]::text[];

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_event_groups_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_event_groups_check check (
    selected_event_groups <@ array[
      'tasks','attendance','employees','hr','payments','legal','system'
    ]::text[]
  );

create or replace function public.notification_event_group(p_entity_type text)
returns text
language sql
immutable
as $$
  select case
    when coalesce(p_entity_type, '') in (
      'tasks','task_assignees','task_photos','brigade_photo','foreman_reminder'
    ) then 'tasks'
    when coalesce(p_entity_type, '') = 'attendance' then 'attendance'
    when coalesce(p_entity_type, '') in (
      'employees','employee_private_data','employee_documents'
    ) then 'employees'
    when coalesce(p_entity_type, '') in (
      'recruitment_application','recruitment_applications','recruitment_message',
      'recruitment_messages','recruitment_document','recruitment_documents','hr_reminder'
    ) then 'hr'
    when coalesce(p_entity_type, '') in (
      'payments','payment_receipts','accountant_reminder'
    ) then 'payments'
    when coalesce(p_entity_type, '') like 'legal_%'
      or coalesce(p_entity_type, '') in ('legal_document','legal_matter','lawyer_reminder')
      then 'legal'
    else 'system'
  end;
$$;

create or replace function public.current_admin_notification_in_app_enabled()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when not public.is_admin() then true
    else coalesce(
      (
        select p.in_app_enabled
        from public.notification_role_preferences p
        where p.company_id = public.current_user_company_id()
          and p.user_id = auth.uid()
      ),
      true
    )
  end;
$$;

create or replace function public.current_admin_notification_event_groups()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when not public.is_admin() then array[
      public.notification_event_group(public.normalize_notification_role(public.current_user_role()))
    ]::text[]
    else coalesce(
      (
        select p.selected_event_groups
        from public.notification_role_preferences p
        where p.company_id = public.current_user_company_id()
          and p.user_id = auth.uid()
      ),
      array['tasks','attendance','employees','hr','payments','legal','system']::text[]
    )
  end;
$$;

revoke all on function public.current_admin_notification_in_app_enabled() from public, anon;
revoke all on function public.current_admin_notification_event_groups() from public, anon;
grant execute on function public.current_admin_notification_in_app_enabled() to authenticated, service_role;
grant execute on function public.current_admin_notification_event_groups() to authenticated, service_role;

create or replace function public.notification_visible_for_current_user(
  p_source_role text,
  p_target_user_id uuid,
  p_target_role text,
  p_entity_type text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    auth.uid() is not null
    and (
      (
        public.is_admin()
        and public.current_admin_notification_in_app_enabled()
        and public.normalize_notification_role(p_source_role) = any(public.current_admin_notification_roles())
        and public.notification_event_group(p_entity_type) = any(public.current_admin_notification_event_groups())
      )
      or (
        not public.is_admin()
        and (
          p_target_user_id = auth.uid()
          or (
            p_target_user_id is null
            and public.normalize_notification_role(p_source_role) = public.normalize_notification_role(public.current_user_role())
            and (
              p_target_role is null
              or public.normalize_notification_role(p_target_role) = public.normalize_notification_role(public.current_user_role())
            )
            and (
              public.normalize_notification_role(public.current_user_role()) <> 'foreman'
              or (
                coalesce(p_entity_type, '') in (
                  'attendance','tasks','task_assignees','task_photos','brigade_photo','foreman_reminder'
                )
                and public.can_access_object(coalesce(p_object_name, ''))
              )
            )
          )
        )
      )
    );
$$;

revoke all on function public.notification_visible_for_current_user(text, uuid, text, text, text) from public, anon;
grant execute on function public.notification_visible_for_current_user(text, uuid, text, text, text) to authenticated, service_role;

create table if not exists public.company_reminder_settings (
  company_id uuid not null references public.companies(id) on delete cascade,
  reminder_key text not null,
  recipient_role text not null,
  enabled boolean not null default false,
  local_time time not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (company_id, reminder_key),
  constraint company_reminder_settings_key_check check (
    reminder_key in (
      'foreman_brigade_photo','foreman_fill_tasks','foreman_missing_before',
      'foreman_missing_after','hr_missing_documents','hr_unanswered_messages',
      'accountant_missing_receipts','lawyer_due_summary','admin_evening_summary'
    )
  ),
  constraint company_reminder_settings_role_check check (
    recipient_role in ('admin','foreman','hr','accountant','lawyer')
  )
);

alter table public.company_reminder_settings enable row level security;

drop policy if exists company_reminder_settings_select_admin on public.company_reminder_settings;
create policy company_reminder_settings_select_admin
on public.company_reminder_settings for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.is_admin()
);

drop policy if exists company_reminder_settings_insert_admin on public.company_reminder_settings;
create policy company_reminder_settings_insert_admin
on public.company_reminder_settings for insert to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.is_admin()
);

drop policy if exists company_reminder_settings_update_admin on public.company_reminder_settings;
create policy company_reminder_settings_update_admin
on public.company_reminder_settings for update to authenticated
using (
  company_id = public.current_user_company_id()
  and public.is_admin()
)
with check (
  company_id = public.current_user_company_id()
  and public.is_admin()
);

grant select, insert, update on public.company_reminder_settings to authenticated;
grant all on public.company_reminder_settings to service_role;

insert into public.company_reminder_settings(
  company_id, reminder_key, recipient_role, enabled, local_time
)
select c.id, defaults.reminder_key, defaults.recipient_role, false, defaults.local_time
from public.companies c
cross join (
  values
    ('foreman_brigade_photo', 'foreman', time '07:30'),
    ('foreman_fill_tasks', 'foreman', time '08:00'),
    ('foreman_missing_before', 'foreman', time '09:00'),
    ('foreman_missing_after', 'foreman', time '17:30'),
    ('hr_missing_documents', 'hr', time '09:15'),
    ('hr_unanswered_messages', 'hr', time '16:00'),
    ('accountant_missing_receipts', 'accountant', time '10:00'),
    ('lawyer_due_summary', 'lawyer', time '08:45'),
    ('admin_evening_summary', 'admin', time '18:00')
) as defaults(reminder_key, recipient_role, local_time)
on conflict(company_id, reminder_key) do nothing;

create or replace function private.ensure_company_reminder_settings(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.company_reminder_settings(
    company_id, reminder_key, recipient_role, enabled, local_time
  )
  select p_company_id, defaults.reminder_key, defaults.recipient_role, false, defaults.local_time
  from (
    values
      ('foreman_brigade_photo', 'foreman', time '07:30'),
      ('foreman_fill_tasks', 'foreman', time '08:00'),
      ('foreman_missing_before', 'foreman', time '09:00'),
      ('foreman_missing_after', 'foreman', time '17:30'),
      ('hr_missing_documents', 'hr', time '09:15'),
      ('hr_unanswered_messages', 'hr', time '16:00'),
      ('accountant_missing_receipts', 'accountant', time '10:00'),
      ('lawyer_due_summary', 'lawyer', time '08:45'),
      ('admin_evening_summary', 'admin', time '18:00')
  ) as defaults(reminder_key, recipient_role, local_time)
  on conflict(company_id, reminder_key) do nothing;
end;
$$;

revoke all on function private.ensure_company_reminder_settings(uuid) from public, anon, authenticated;
grant execute on function private.ensure_company_reminder_settings(uuid) to service_role;

create or replace function public.get_my_notification_control_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки уведомлений доступны только руководителю';
  end if;

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_event_groups,
    in_app_enabled, push_enabled, updated_at
  ) values (
    v_company_id,
    auth.uid(),
    array['admin','foreman','hr','accountant','lawyer']::text[],
    array['tasks','attendance','employees','hr','payments','legal','system']::text[],
    true,
    true,
    now()
  )
  on conflict(company_id, user_id) do nothing;

  perform private.ensure_company_reminder_settings(v_company_id);

  select jsonb_build_object(
    'in_app_enabled', p.in_app_enabled,
    'push_enabled', p.push_enabled,
    'selected_roles', to_jsonb(p.selected_roles),
    'selected_event_groups', to_jsonb(p.selected_event_groups),
    'reminders', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'key', r.reminder_key,
            'recipient_role', r.recipient_role,
            'enabled', r.enabled,
            'local_time', to_char(r.local_time, 'HH24:MI')
          ) order by r.reminder_key
        )
        from public.company_reminder_settings r
        where r.company_id = v_company_id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.notification_role_preferences p
  where p.company_id = v_company_id
    and p.user_id = auth.uid();

  return v_result;
end;
$$;

create or replace function public.set_my_notification_control_preferences(
  p_in_app_enabled boolean,
  p_push_enabled boolean,
  p_roles text[],
  p_event_groups text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_roles text[];
  v_groups text[];
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки уведомлений доступны только руководителю';
  end if;

  select coalesce(array_agg(distinct public.normalize_notification_role(value) order by public.normalize_notification_role(value)), array[]::text[])
  into v_roles
  from unnest(coalesce(p_roles, array[]::text[])) as value
  where public.normalize_notification_role(value) in ('admin','foreman','hr','accountant','lawyer');

  select coalesce(array_agg(distinct lower(btrim(value)) order by lower(btrim(value))), array[]::text[])
  into v_groups
  from unnest(coalesce(p_event_groups, array[]::text[])) as value
  where lower(btrim(value)) in ('tasks','attendance','employees','hr','payments','legal','system');

  insert into public.notification_role_preferences(
    company_id, user_id, selected_roles, selected_event_groups,
    in_app_enabled, push_enabled, updated_at
  ) values (
    v_company_id, auth.uid(), v_roles, v_groups,
    coalesce(p_in_app_enabled, true), coalesce(p_push_enabled, true), now()
  )
  on conflict(company_id, user_id) do update
    set selected_roles = excluded.selected_roles,
        selected_event_groups = excluded.selected_event_groups,
        in_app_enabled = excluded.in_app_enabled,
        push_enabled = excluded.push_enabled,
        updated_at = now();

  return public.get_my_notification_control_center();
end;
$$;

create or replace function public.set_company_reminder_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_item jsonb;
  v_key text;
  v_enabled boolean;
  v_time time;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки напоминаний доступны только руководителю';
  end if;

  perform private.ensure_company_reminder_settings(v_company_id);

  for v_item in select value from jsonb_array_elements(coalesce(p_settings, '[]'::jsonb))
  loop
    v_key := btrim(coalesce(v_item ->> 'key', ''));
    if v_key not in (
      'foreman_brigade_photo','foreman_fill_tasks','foreman_missing_before',
      'foreman_missing_after','hr_missing_documents','hr_unanswered_messages',
      'accountant_missing_receipts','lawyer_due_summary','admin_evening_summary'
    ) then
      continue;
    end if;

    v_enabled := coalesce((v_item ->> 'enabled')::boolean, false);
    begin
      v_time := (v_item ->> 'local_time')::time;
    exception when others then
      v_time := null;
    end;

    update public.company_reminder_settings
    set enabled = v_enabled,
        local_time = coalesce(v_time, local_time),
        updated_at = now(),
        updated_by = auth.uid()
    where company_id = v_company_id
      and reminder_key = v_key;
  end loop;

  delete from public.scheduled_reminders
  where company_id = v_company_id
    and status = 'cancelled'
    and notification_id is null;

  return public.get_my_notification_control_center();
end;
$$;

revoke all on function public.get_my_notification_control_center() from public, anon;
revoke all on function public.set_my_notification_control_preferences(boolean, boolean, text[], text[]) from public, anon;
revoke all on function public.set_company_reminder_settings(jsonb) from public, anon;
grant execute on function public.get_my_notification_control_center() to authenticated;
grant execute on function public.set_my_notification_control_preferences(boolean, boolean, text[], text[]) to authenticated;
grant execute on function public.set_company_reminder_settings(jsonb) to authenticated;

create or replace function private.populate_legal_scheduled_reminders()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return;
end;
$$;

create or replace function private.populate_role_operational_reminders()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
begin
  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    o.company_id,
    'foreman-brigade-photo:' || o.id::text || ':' || v_today::text,
    'foreman_reminder', o.id, 'brigade_photo',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Фото бригады',
    'Сделайте и прикрепите утреннее фото бригады на объекте.',
    o.name, 'normal'
  from public.objects o
  join public.company_reminder_settings s
    on s.company_id = o.company_id
   and s.reminder_key = 'foreman_brigade_photo'
   and s.enabled = true
  where o.is_active = true
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    o.company_id,
    'foreman-fill-tasks:' || o.id::text || ':' || v_today::text,
    'foreman_reminder', o.id, 'fill_daily_tasks',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Заполните задачи на сегодня',
    'На объекте ещё не создано ни одной задачи на текущий день.',
    o.name, 'high'
  from public.objects o
  join public.company_reminder_settings s
    on s.company_id = o.company_id
   and s.reminder_key = 'foreman_fill_tasks'
   and s.enabled = true
  where o.is_active = true
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
    and not exists (
      select 1 from public.tasks t
      where t.company_id = o.company_id
        and lower(btrim(t.object_name)) = lower(btrim(o.name))
        and t.task_date = v_today
        and not t.is_draft
    )
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    t.company_id,
    'foreman-before-photo:' || t.id::text || ':' || v_today::text,
    'tasks', t.id, 'task_before_photo_missing',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Нет фото «До»',
    t.axes || ' · ' || t.work,
    coalesce(t.object_name, ''), 'high'
  from public.tasks t
  join public.company_reminder_settings s
    on s.company_id = t.company_id
   and s.reminder_key = 'foreman_missing_before'
   and s.enabled = true
  where t.task_date = v_today
    and not t.is_draft
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
    and not exists (
      select 1 from public.task_photos p
      where p.task_id = t.id and p.photo_stage = 'before'
    )
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    t.company_id,
    'foreman-after-photo:' || t.id::text || ':' || v_today::text,
    'tasks', t.id, 'task_after_photo_missing',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Добавьте фото «После»',
    t.axes || ' · ' || t.work || ' — без фото «После» задача не закроется.',
    coalesce(t.object_name, ''), 'high'
  from public.tasks t
  join public.company_reminder_settings s
    on s.company_id = t.company_id
   and s.reminder_key = 'foreman_missing_after'
   and s.enabled = true
  where t.task_date = v_today
    and not t.is_draft
    and t.status <> 'Выполнено'
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
    and not exists (
      select 1 from public.task_photos p
      where p.task_id = t.id and p.photo_stage = 'after'
    )
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    c.id,
    'hr-missing-documents:' || c.id::text || ':' || v_today::text,
    'hr_reminder', c.id, 'candidate_documents_missing',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Кандидаты без документов',
    count(*)::text || ' кандидатов ожидают первый комплект документов.',
    '', 'high'
  from public.companies c
  join public.company_reminder_settings s
    on s.company_id = c.id
   and s.reminder_key = 'hr_missing_documents'
   and s.enabled = true
  join public.recruitment_applications a on a.company_id = c.id
  where a.archived_at is null
    and a.status not in ('hired','reserve','rejected','arrived')
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
    and not exists (
      select 1 from public.recruitment_documents d where d.application_id = a.id
    )
  group by c.id, s.local_time, s.recipient_role
  having count(*) > 0
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    c.id,
    'hr-unanswered-messages:' || c.id::text || ':' || v_today::text,
    'hr_reminder', c.id, 'candidate_message_unanswered',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Есть сообщения кандидатов без ответа',
    count(*)::text || ' переписок ждут ответа HR.',
    '', 'high'
  from public.companies c
  join public.company_reminder_settings s
    on s.company_id = c.id
   and s.reminder_key = 'hr_unanswered_messages'
   and s.enabled = true
  join public.recruitment_applications a on a.company_id = c.id and a.archived_at is null
  where v_now_local >= v_today + s.local_time - interval '5 minutes'
    and exists (
      select 1
      from public.recruitment_messages incoming
      where incoming.application_id = a.id
        and incoming.direction = 'inbound'
        and not exists (
          select 1 from public.recruitment_messages outgoing
          where outgoing.application_id = a.id
            and outgoing.direction = 'outbound'
            and outgoing.created_at > incoming.created_at
        )
    )
  group by c.id, s.local_time, s.recipient_role
  having count(*) > 0
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    c.id,
    'accountant-missing-receipts:' || c.id::text || ':' || v_today::text,
    'accountant_reminder', c.id, 'payment_receipt_missing',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Не прикреплены чеки к выплатам',
    count(*)::text || ' выплат за последние 7 дней остаются без чека.',
    '', 'high'
  from public.companies c
  join public.company_reminder_settings s
    on s.company_id = c.id
   and s.reminder_key = 'accountant_missing_receipts'
   and s.enabled = true
  join public.payments p on p.company_id = c.id
  where p.payment_date >= v_today - 7
    and v_now_local >= v_today + s.local_time - interval '5 minutes'
    and not exists (
      select 1 from public.payment_receipts r where r.payment_id = p.id
    )
  group by c.id, s.local_time, s.recipient_role
  having count(*) > 0
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    c.id,
    'lawyer-due-summary:' || c.id::text || ':' || v_today::text,
    'lawyer_reminder', c.id, 'legal_due_summary',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Проверьте юридические сроки',
    'Есть документы или вопросы со сроком в ближайшие 3 дня либо просроченные.',
    '', 'high'
  from public.companies c
  join public.company_reminder_settings s
    on s.company_id = c.id
   and s.reminder_key = 'lawyer_due_summary'
   and s.enabled = true
  where v_now_local >= v_today + s.local_time - interval '5 minutes'
    and (
      exists (
        select 1 from public.legal_documents d
        where d.company_id = c.id
          and d.archived_at is null
          and d.status not in ('terminated','archive')
          and (
            d.expires_on <= v_today + 3
            or d.next_action_due_at <= now() + interval '3 days'
          )
      )
      or exists (
        select 1 from public.legal_matters m
        where m.company_id = c.id
          and m.status not in ('resolved','closed')
          and m.due_at <= now() + interval '3 days'
      )
    )
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    c.id,
    'admin-evening-summary:' || c.id::text || ':' || v_today::text,
    'admin_reminder', c.id, 'manager_evening_summary',
    (v_today + s.local_time) at time zone 'Europe/Moscow',
    s.recipient_role, 'Итоги рабочего дня',
    'Проверьте незакрытые задачи, кадровые вопросы, выплаты и юридические сроки.',
    '', 'normal'
  from public.companies c
  join public.company_reminder_settings s
    on s.company_id = c.id
   and s.reminder_key = 'admin_evening_summary'
   and s.enabled = true
  where v_now_local >= v_today + s.local_time - interval '5 minutes'
  on conflict(company_id, reminder_key) do nothing;
end;
$$;

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
  perform private.populate_role_operational_reminders();

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
      company_id, title, body, actor_user_id, actor_name, actor_email,
      object_name, entity_type, entity_id, target_user_id, target_role,
      source_role, requires_action, due_at, priority
    ) values (
      v_reminder.company_id,
      v_reminder.title,
      v_reminder.body,
      null,
      'Система AppСтрой',
      '',
      v_reminder.object_name,
      case
        when v_reminder.entity_type in ('legal_document','legal_matter') then 'legal_reminder'
        else v_reminder.entity_type
      end,
      v_reminder.entity_id::text,
      v_reminder.recipient_user_id,
      v_reminder.recipient_role,
      public.normalize_notification_role(
        coalesce(v_reminder.recipient_role, public.notification_role_for_entity(v_reminder.entity_type))
      ),
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

revoke all on function private.populate_legal_scheduled_reminders() from public, anon, authenticated;
revoke all on function private.populate_role_operational_reminders() from public, anon, authenticated;
revoke all on function private.process_due_scheduled_reminders() from public, anon, authenticated;
grant execute on function private.populate_legal_scheduled_reminders() to service_role;
grant execute on function private.populate_role_operational_reminders() to service_role;
grant execute on function private.process_due_scheduled_reminders() to service_role;
