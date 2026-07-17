create table if not exists public.notification_role_preferences (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  selected_roles text[] not null default array['admin','foreman','hr','accountant','lawyer']::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, user_id),
  constraint notification_role_preferences_roles_check check (
    selected_roles <@ array['admin','foreman','hr','accountant','lawyer']::text[]
  )
);

alter table public.notification_role_preferences enable row level security;

drop policy if exists notification_role_preferences_select_own on public.notification_role_preferences;
create policy notification_role_preferences_select_own
on public.notification_role_preferences for select to authenticated
using (
  user_id = auth.uid()
  and company_id = public.current_user_company_id()
  and public.is_admin()
);

drop policy if exists notification_role_preferences_insert_own on public.notification_role_preferences;
create policy notification_role_preferences_insert_own
on public.notification_role_preferences for insert to authenticated
with check (
  user_id = auth.uid()
  and company_id = public.current_user_company_id()
  and public.is_admin()
);

drop policy if exists notification_role_preferences_update_own on public.notification_role_preferences;
create policy notification_role_preferences_update_own
on public.notification_role_preferences for update to authenticated
using (
  user_id = auth.uid()
  and company_id = public.current_user_company_id()
  and public.is_admin()
)
with check (
  user_id = auth.uid()
  and company_id = public.current_user_company_id()
  and public.is_admin()
);

grant select, insert, update on public.notification_role_preferences to authenticated;
grant all on public.notification_role_preferences to service_role;

create or replace function public.normalize_notification_role(p_role text)
returns text
language sql
immutable
as $$
  select case lower(btrim(coalesce(p_role, '')))
    when 'owner' then 'admin'
    when 'accounting' then 'accountant'
    when 'accountant' then 'accountant'
    when 'admin' then 'admin'
    when 'foreman' then 'foreman'
    when 'hr' then 'hr'
    when 'lawyer' then 'lawyer'
    else 'admin'
  end;
$$;

create or replace function public.notification_role_for_entity(p_entity_type text)
returns text
language sql
immutable
as $$
  select case
    when coalesce(p_entity_type, '') in (
      'attendance','tasks','task_assignees','task_photos','brigade_photo','foreman_reminder'
    ) then 'foreman'
    when coalesce(p_entity_type, '') in (
      'recruitment_application','recruitment_applications','recruitment_message',
      'recruitment_messages','recruitment_document','recruitment_documents',
      'employees','employee_private_data','hr_reminder'
    ) then 'hr'
    when coalesce(p_entity_type, '') in (
      'payments','payment_receipts','accountant_reminder'
    ) then 'accountant'
    when coalesce(p_entity_type, '') like 'legal_%'
      or coalesce(p_entity_type, '') in ('legal_document','legal_matter','lawyer_reminder')
      then 'lawyer'
    else 'admin'
  end;
$$;

alter table public.app_notifications
  add column if not exists source_role text;

update public.app_notifications
set source_role = public.notification_role_for_entity(entity_type)
where source_role is null or btrim(source_role) = '';

alter table public.app_notifications
  alter column source_role set default 'admin',
  alter column source_role set not null;

alter table public.app_notifications
  drop constraint if exists app_notifications_source_role_check;
alter table public.app_notifications
  add constraint app_notifications_source_role_check check (
    source_role in ('admin','foreman','hr','accountant','lawyer')
  );

create index if not exists app_notifications_company_source_role_created_idx
  on public.app_notifications(company_id, source_role, created_at desc);

create or replace function private.assign_notification_source_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.target_role is not null and btrim(new.target_role) <> '' then
    new.target_role := public.normalize_notification_role(new.target_role);
  end if;
  new.source_role := public.normalize_notification_role(
    coalesce(nullif(btrim(new.source_role), ''), new.target_role, public.notification_role_for_entity(new.entity_type))
  );
  return new;
end;
$$;

revoke all on function private.assign_notification_source_role() from public, anon, authenticated;
grant execute on function private.assign_notification_source_role() to service_role;

drop trigger if exists app_notifications_assign_source_role on public.app_notifications;
create trigger app_notifications_assign_source_role
before insert or update of entity_type, target_role, source_role
on public.app_notifications
for each row execute function private.assign_notification_source_role();

create or replace function public.current_admin_notification_roles()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when not public.is_admin() then array[public.normalize_notification_role(public.current_user_role())]::text[]
    else coalesce(
      (
        select p.selected_roles
        from public.notification_role_preferences p
        where p.company_id = public.current_user_company_id()
          and p.user_id = auth.uid()
      ),
      array['admin','foreman','hr','accountant','lawyer']::text[]
    )
  end;
$$;

revoke all on function public.current_admin_notification_roles() from public, anon;
grant execute on function public.current_admin_notification_roles() to authenticated, service_role;

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
      p_target_user_id = auth.uid()
      or (
        public.is_admin()
        and public.normalize_notification_role(p_source_role) = any(public.current_admin_notification_roles())
      )
      or (
        not public.is_admin()
        and p_target_user_id is null
        and public.normalize_notification_role(p_source_role) = public.normalize_notification_role(public.current_user_role())
        and (
          p_target_role is null
          or public.normalize_notification_role(p_target_role) = public.normalize_notification_role(public.current_user_role())
        )
        and (
          public.normalize_notification_role(public.current_user_role()) <> 'foreman'
          or (
            coalesce(p_entity_type, '') in ('attendance','tasks','task_assignees','task_photos','brigade_photo','foreman_reminder')
            and public.can_access_object(coalesce(p_object_name, ''))
          )
        )
      )
    );
$$;

revoke all on function public.notification_visible_for_current_user(text, uuid, text, text, text) from public, anon;
grant execute on function public.notification_visible_for_current_user(text, uuid, text, text, text) to authenticated, service_role;

drop policy if exists notifications_select_company_role on public.app_notifications;
create policy notifications_select_company_role
on public.app_notifications for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.notification_visible_for_current_user(
    source_role,
    target_user_id,
    target_role,
    entity_type,
    object_name
  )
);

create or replace function public.get_my_notification_role_preferences()
returns text[]
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.current_admin_notification_roles();
$$;

revoke all on function public.get_my_notification_role_preferences() from public, anon;
grant execute on function public.get_my_notification_role_preferences() to authenticated;

create or replace function public.set_my_notification_role_preferences(p_roles text[])
returns text[]
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_roles text[];
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Настройки ролей доступны только руководителю';
  end if;

  select coalesce(array_agg(distinct public.normalize_notification_role(value) order by public.normalize_notification_role(value)), array[]::text[])
  into v_roles
  from unnest(coalesce(p_roles, array[]::text[])) as value
  where public.normalize_notification_role(value) in ('admin','foreman','hr','accountant','lawyer');

  insert into public.notification_role_preferences(company_id, user_id, selected_roles, updated_at)
  values(v_company_id, auth.uid(), v_roles, now())
  on conflict(company_id, user_id) do update
    set selected_roles = excluded.selected_roles,
        updated_at = now();

  return v_roles;
end;
$$;

revoke all on function public.set_my_notification_role_preferences(text[]) from public, anon;
grant execute on function public.set_my_notification_role_preferences(text[]) to authenticated;

alter table public.task_photos
  add column if not exists photo_stage text;

update public.task_photos
set photo_stage = 'before'
where photo_stage is null or btrim(photo_stage) = '';

alter table public.task_photos
  alter column photo_stage set default 'before',
  alter column photo_stage set not null;

alter table public.task_photos
  drop constraint if exists task_photos_stage_check;
alter table public.task_photos
  add constraint task_photos_stage_check check (photo_stage in ('before','after'));

create index if not exists task_photos_task_stage_idx
  on public.task_photos(task_id, photo_stage, created_at);

alter table public.tasks
  add column if not exists is_draft boolean not null default false,
  add column if not exists photo_requirements_enforced boolean not null default false,
  add column if not exists created_by_user_id uuid references auth.users(id) on delete set null;

alter table public.tasks
  alter column photo_requirements_enforced set default true;

update public.tasks
set created_by_user_id = null
where created_by_user_id is null;

create or replace function private.validate_task_photo_requirements()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.photo_requirements_enforced and not new.is_draft then
      raise exception 'Новая задача должна быть создана через фото «До»';
    end if;
    if new.created_by_user_id is null then
      new.created_by_user_id := auth.uid();
    end if;
    return new;
  end if;

  if new.photo_requirements_enforced
     and old.is_draft
     and not new.is_draft
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = new.id and p.photo_stage = 'before'
     ) then
    raise exception 'Добавьте хотя бы одно фото «До», чтобы создать задачу';
  end if;

  if new.photo_requirements_enforced
     and new.status = 'Выполнено'
     and old.status is distinct from new.status
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = new.id and p.photo_stage = 'after'
     ) then
    raise exception 'Добавьте хотя бы одно фото «После», чтобы выполнить задачу';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_task_photo_requirements() from public, anon, authenticated;
grant execute on function private.validate_task_photo_requirements() to service_role;

drop trigger if exists tasks_validate_photo_requirements on public.tasks;
create trigger tasks_validate_photo_requirements
before insert or update of is_draft, status, photo_requirements_enforced
on public.tasks
for each row execute function private.validate_task_photo_requirements();

create or replace function private.prevent_required_task_photo_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_task public.tasks%rowtype;
begin
  select * into v_task from public.tasks where id = old.task_id;
  if not found or not v_task.photo_requirements_enforced then
    return old;
  end if;

  if old.photo_stage = 'before'
     and not v_task.is_draft
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = old.task_id
         and p.photo_stage = 'before'
         and p.id <> old.id
     ) then
    raise exception 'Нельзя удалить последнее обязательное фото «До»';
  end if;

  if old.photo_stage = 'after'
     and v_task.status = 'Выполнено'
     and not exists (
       select 1 from public.task_photos p
       where p.task_id = old.task_id
         and p.photo_stage = 'after'
         and p.id <> old.id
     ) then
    raise exception 'Нельзя удалить последнее обязательное фото «После» у выполненной задачи';
  end if;

  return old;
end;
$$;

revoke all on function private.prevent_required_task_photo_delete() from public, anon, authenticated;
grant execute on function private.prevent_required_task_photo_delete() to service_role;

drop trigger if exists task_photos_prevent_required_delete on public.task_photos;
create trigger task_photos_prevent_required_delete
before delete on public.task_photos
for each row execute function private.prevent_required_task_photo_delete();

create or replace function public.task_is_allowed_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and t.company_id = public.current_user_company_id()
      and public.can_access_object(t.object_name)
      and public.is_active_object(t.object_name)
      and (
        not t.is_draft
        or public.is_admin()
        or t.created_by_user_id = auth.uid()
      )
  );
$$;

drop policy if exists tasks_insert_company_object on public.tasks;
create policy tasks_insert_company_object
on public.tasks for insert to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and is_draft
  and photo_requirements_enforced
  and created_by_user_id = auth.uid()
  and (
    public.is_admin()
    or (public.is_foreman() and task_date = public.current_operational_date())
  )
);

drop policy if exists tasks_select_company_object on public.tasks;
create policy tasks_select_company_object
on public.tasks for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    not is_draft
    or public.is_admin()
    or created_by_user_id = auth.uid()
  )
);

create or replace function private.filter_draft_task_notifications()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.entity_type = 'tasks'
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1 from public.tasks t
       where t.id = new.entity_id::uuid and t.is_draft
     ) then
    return null;
  end if;

  if new.entity_type in ('task_assignees','task_photos')
     and coalesce(new.entity_id, '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
     and exists (
       select 1
       from public.tasks t
       where t.is_draft
         and t.id = case
           when new.entity_type = 'task_assignees' then (
             select a.task_id from public.task_assignees a where a.id = new.entity_id::uuid
           )
           else (
             select p.task_id from public.task_photos p where p.id = new.entity_id::uuid
           )
         end
     ) then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function private.filter_draft_task_notifications() from public, anon, authenticated;
grant execute on function private.filter_draft_task_notifications() to service_role;

drop trigger if exists app_notifications_filter_task_drafts on public.app_notifications;
create trigger app_notifications_filter_task_drafts
before insert on public.app_notifications
for each row execute function private.filter_draft_task_notifications();

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
    (v_today + time '07:30') at time zone 'Europe/Moscow',
    'foreman', 'Фото бригады',
    'Сделайте и прикрепите утреннее фото бригады на объекте.',
    o.name, 'normal'
  from public.objects o
  where o.is_active = true
    and v_now_local >= v_today + time '07:25'
  on conflict(company_id, reminder_key) do nothing;

  insert into public.scheduled_reminders(
    company_id, reminder_key, entity_type, entity_id, reminder_type, due_at,
    recipient_role, title, body, object_name, priority
  )
  select
    o.company_id,
    'foreman-fill-tasks:' || o.id::text || ':' || v_today::text,
    'foreman_reminder', o.id, 'fill_daily_tasks',
    (v_today + time '08:00') at time zone 'Europe/Moscow',
    'foreman', 'Заполните задачи на сегодня',
    'На объекте ещё не создано ни одной задачи на текущий день.',
    o.name, 'high'
  from public.objects o
  where o.is_active = true
    and v_now_local >= v_today + time '07:55'
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
    (v_today + time '09:00') at time zone 'Europe/Moscow',
    'foreman', 'Нет фото «До»',
    t.axes || ' · ' || t.work,
    coalesce(t.object_name, ''), 'high'
  from public.tasks t
  where t.task_date = v_today
    and not t.is_draft
    and v_now_local >= v_today + time '08:55'
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
    (v_today + time '17:30') at time zone 'Europe/Moscow',
    'foreman', 'Добавьте фото «После»',
    t.axes || ' · ' || t.work || ' — без фото «После» задача не закроется.',
    coalesce(t.object_name, ''), 'high'
  from public.tasks t
  where t.task_date = v_today
    and not t.is_draft
    and t.status <> 'Выполнено'
    and v_now_local >= v_today + time '17:25'
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
    (v_today + time '09:15') at time zone 'Europe/Moscow',
    'hr', 'Кандидаты без документов',
    count(*)::text || ' кандидатов ожидают первый комплект документов.',
    '', 'high'
  from public.companies c
  join public.recruitment_applications a on a.company_id = c.id
  where a.archived_at is null
    and a.status not in ('hired','reserve','rejected','arrived')
    and v_now_local >= v_today + time '09:10'
    and not exists (
      select 1 from public.recruitment_documents d where d.application_id = a.id
    )
  group by c.id
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
    (v_today + time '16:00') at time zone 'Europe/Moscow',
    'hr', 'Есть сообщения кандидатов без ответа',
    count(*)::text || ' переписок ждут ответа HR.',
    '', 'high'
  from public.companies c
  join public.recruitment_applications a on a.company_id = c.id and a.archived_at is null
  where v_now_local >= v_today + time '15:55'
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
  group by c.id
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
    (v_today + time '10:00') at time zone 'Europe/Moscow',
    'accountant', 'Не прикреплены чеки к выплатам',
    count(*)::text || ' выплат за последние 7 дней остаются без чека.',
    '', 'high'
  from public.companies c
  join public.payments p on p.company_id = c.id
  where p.payment_date >= v_today - 7
    and v_now_local >= v_today + time '09:55'
    and not exists (
      select 1 from public.payment_receipts r where r.payment_id = p.id
    )
  group by c.id
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
    (v_today + time '08:45') at time zone 'Europe/Moscow',
    'lawyer', 'Проверьте юридические сроки',
    'Есть документы или вопросы со сроком в ближайшие 3 дня либо просроченные.',
    '', 'high'
  from public.companies c
  where v_now_local >= v_today + time '08:40'
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
    (v_today + time '18:00') at time zone 'Europe/Moscow',
    'admin', 'Итоги рабочего дня',
    'Проверьте незакрытые задачи, кадровые вопросы, выплаты и юридические сроки.',
    '', 'normal'
  from public.companies c
  where v_now_local >= v_today + time '17:55'
  on conflict(company_id, reminder_key) do nothing;
end;
$$;

revoke all on function private.populate_role_operational_reminders() from public, anon, authenticated;
grant execute on function private.populate_role_operational_reminders() to service_role;

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

revoke all on function private.process_due_scheduled_reminders() from public, anon, authenticated;
grant execute on function private.process_due_scheduled_reminders() to service_role;
