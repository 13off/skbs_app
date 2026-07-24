-- Full recruitment CRM workspace: responsible HR, activity feed, comments,
-- tasks/reminders, saved views and stage-entry automations.

alter table public.recruitment_applications
  add column if not exists responsible_user_id uuid references auth.users(id) on delete set null;

alter table public.recruitment_applications
  drop constraint if exists recruitment_applications_company_id_id_unique;
alter table public.recruitment_applications
  add constraint recruitment_applications_company_id_id_unique
  unique (company_id, id);

create index if not exists recruitment_applications_responsible_idx
  on public.recruitment_applications(company_id, responsible_user_id, archived_at, updated_at desc)
  where responsible_user_id is not null;

create table if not exists public.recruitment_crm_comments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null,
  body text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_crm_comments_company_application_fk
    foreign key (company_id, application_id)
    references public.recruitment_applications(company_id, id)
    on delete cascade,
  constraint recruitment_crm_comments_body_check
    check (char_length(btrim(body)) between 1 and 5000)
);

create table if not exists public.recruitment_crm_tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null,
  title text not null,
  description text not null default '',
  task_type text not null default 'other',
  priority text not null default 'normal',
  due_at timestamptz,
  assigned_to uuid references auth.users(id) on delete set null,
  status text not null default 'pending',
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_crm_tasks_company_application_fk
    foreign key (company_id, application_id)
    references public.recruitment_applications(company_id, id)
    on delete cascade,
  constraint recruitment_crm_tasks_title_check
    check (char_length(btrim(title)) between 1 and 200),
  constraint recruitment_crm_tasks_type_check
    check (task_type in ('call','documents','review','ticket','meeting','message','other')),
  constraint recruitment_crm_tasks_priority_check
    check (priority in ('low','normal','high','critical')),
  constraint recruitment_crm_tasks_status_check
    check (status in ('pending','completed','cancelled'))
);

create table if not exists public.recruitment_crm_activities (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null,
  event_type text not null,
  title text not null,
  body text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default 'Система AppСтрой',
  created_at timestamptz not null default now(),
  constraint recruitment_crm_activities_company_application_fk
    foreign key (company_id, application_id)
    references public.recruitment_applications(company_id, id)
    on delete cascade,
  constraint recruitment_crm_activities_metadata_check
    check (jsonb_typeof(metadata) = 'object'),
  constraint recruitment_crm_activities_title_check
    check (char_length(btrim(title)) between 1 and 300)
);

create table if not exists public.recruitment_crm_saved_views (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  filters jsonb not null default '{}'::jsonb,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_crm_saved_views_filters_check
    check (jsonb_typeof(filters) = 'object'),
  constraint recruitment_crm_saved_views_title_check
    check (char_length(btrim(title)) between 1 and 100)
);

create table if not exists public.recruitment_crm_automation_rules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  trigger_stage_id uuid not null,
  title text not null,
  action_type text not null default 'create_task',
  task_title text not null default '',
  task_type text not null default 'other',
  task_priority text not null default 'normal',
  due_offset_hours integer not null default 24,
  message_text text not null default '',
  assigned_to uuid references auth.users(id) on delete set null,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_crm_automation_rules_company_stage_fk
    foreign key (company_id, trigger_stage_id)
    references public.recruitment_pipeline_stages(company_id, id)
    on delete cascade,
  constraint recruitment_crm_automation_rules_title_check
    check (char_length(btrim(title)) between 1 and 120),
  constraint recruitment_crm_automation_rules_action_check
    check (action_type in ('create_task','send_message','create_task_and_message')),
  constraint recruitment_crm_automation_rules_task_type_check
    check (task_type in ('call','documents','review','ticket','meeting','message','other')),
  constraint recruitment_crm_automation_rules_priority_check
    check (task_priority in ('low','normal','high','critical')),
  constraint recruitment_crm_automation_rules_due_check
    check (due_offset_hours between 0 and 8760)
);

create table if not exists public.recruitment_crm_automation_runs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  rule_id uuid not null references public.recruitment_crm_automation_rules(id) on delete cascade,
  application_id uuid not null,
  application_updated_at timestamptz not null,
  status text not null default 'processing',
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint recruitment_crm_automation_runs_company_application_fk
    foreign key (company_id, application_id)
    references public.recruitment_applications(company_id, id)
    on delete cascade,
  constraint recruitment_crm_automation_runs_status_check
    check (status in ('processing','completed','failed','skipped')),
  constraint recruitment_crm_automation_runs_result_check
    check (jsonb_typeof(result) = 'object'),
  constraint recruitment_crm_automation_runs_idempotency_unique
    unique (rule_id, application_id, application_updated_at)
);

create index if not exists recruitment_crm_comments_application_created_idx
  on public.recruitment_crm_comments(company_id, application_id, created_at desc);
create index if not exists recruitment_crm_tasks_application_status_due_idx
  on public.recruitment_crm_tasks(company_id, application_id, status, due_at, created_at desc);
create index if not exists recruitment_crm_tasks_assigned_due_idx
  on public.recruitment_crm_tasks(company_id, assigned_to, status, due_at)
  where assigned_to is not null;
create index if not exists recruitment_crm_activities_application_created_idx
  on public.recruitment_crm_activities(company_id, application_id, created_at desc);
create index if not exists recruitment_crm_saved_views_user_idx
  on public.recruitment_crm_saved_views(company_id, user_id, updated_at desc);
create unique index if not exists recruitment_crm_saved_views_default_uidx
  on public.recruitment_crm_saved_views(company_id, user_id)
  where is_default;
create index if not exists recruitment_crm_automation_rules_stage_idx
  on public.recruitment_crm_automation_rules(company_id, trigger_stage_id, is_active, sort_order);

create or replace function private.recruitment_actor_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    nullif(btrim(profile.full_name), ''),
    nullif(btrim(profile.email), ''),
    case when p_user_id is null then 'Система AppСтрой' else 'Пользователь AppСтрой' end
  )
  from (select 1) seed
  left join public.user_profiles profile on profile.id = p_user_id;
$$;

revoke all on function private.recruitment_actor_name(uuid)
  from public, anon, authenticated;

create or replace function private.add_recruitment_crm_activity(
  p_company_id uuid,
  p_application_id uuid,
  p_event_type text,
  p_title text,
  p_body text default '',
  p_metadata jsonb default '{}'::jsonb,
  p_actor_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_company_id is null or p_application_id is null or btrim(coalesce(p_title, '')) = '' then
    return;
  end if;

  insert into public.recruitment_crm_activities(
    company_id,
    application_id,
    event_type,
    title,
    body,
    metadata,
    actor_user_id,
    actor_name
  ) values (
    p_company_id,
    p_application_id,
    coalesce(nullif(btrim(p_event_type), ''), 'system'),
    btrim(p_title),
    btrim(coalesce(p_body, '')),
    case when p_metadata is null or jsonb_typeof(p_metadata) <> 'object'
      then '{}'::jsonb else p_metadata end,
    p_actor_user_id,
    private.recruitment_actor_name(p_actor_user_id)
  );
end;
$$;

revoke all on function private.add_recruitment_crm_activity(uuid,uuid,text,text,text,jsonb,uuid)
  from public, anon, authenticated;

create or replace function private.validate_recruitment_responsible()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.responsible_user_id is not null and not exists (
    select 1
    from public.company_memberships membership
    where membership.company_id = new.company_id
      and membership.user_id = new.responsible_user_id
      and membership.is_active
      and membership.role in ('owner','admin','developer','hr')
  ) then
    raise exception 'Ответственный не состоит в компании или не имеет доступа к подбору';
  end if;
  return new;
end;
$$;

revoke all on function private.validate_recruitment_responsible()
  from public, anon, authenticated;

drop trigger if exists recruitment_applications_validate_responsible
  on public.recruitment_applications;
create trigger recruitment_applications_validate_responsible
  before insert or update of company_id, responsible_user_id
  on public.recruitment_applications
  for each row execute function private.validate_recruitment_responsible();

create or replace function private.validate_recruitment_crm_task_assignee()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.assigned_to is not null and not exists (
    select 1
    from public.company_memberships membership
    where membership.company_id = new.company_id
      and membership.user_id = new.assigned_to
      and membership.is_active
      and membership.role in ('owner','admin','developer','hr')
  ) then
    raise exception 'Исполнитель дела не состоит в компании или не имеет доступа к подбору';
  end if;
  return new;
end;
$$;

revoke all on function private.validate_recruitment_crm_task_assignee()
  from public, anon, authenticated;

drop trigger if exists recruitment_crm_tasks_validate_assignee
  on public.recruitment_crm_tasks;
create trigger recruitment_crm_tasks_validate_assignee
  before insert or update of company_id, assigned_to
  on public.recruitment_crm_tasks
  for each row execute function private.validate_recruitment_crm_task_assignee();

create or replace function private.track_recruitment_application_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_old_stage text := '';
  v_new_stage text := '';
  v_old_responsible text := '';
  v_new_responsible text := '';
begin
  if tg_op = 'INSERT' then
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.id,
      'created',
      'Кандидат добавлен',
      new.full_name,
      jsonb_build_object('source', new.source, 'status', new.status),
      v_actor
    );
    return new;
  end if;

  if old.stage_id is distinct from new.stage_id then
    select coalesce(stage.title, '') into v_old_stage
    from public.recruitment_pipeline_stages stage where stage.id = old.stage_id;
    select coalesce(stage.title, '') into v_new_stage
    from public.recruitment_pipeline_stages stage where stage.id = new.stage_id;
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.id,
      'stage_changed',
      'Этап изменён',
      concat_ws(' → ', nullif(v_old_stage, ''), nullif(v_new_stage, '')),
      jsonb_build_object('from_stage_id', old.stage_id, 'to_stage_id', new.stage_id),
      v_actor
    );
  end if;

  if old.responsible_user_id is distinct from new.responsible_user_id then
    v_old_responsible := private.recruitment_actor_name(old.responsible_user_id);
    v_new_responsible := private.recruitment_actor_name(new.responsible_user_id);
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.id,
      'responsible_changed',
      'Изменён ответственный',
      concat_ws(' → ', nullif(v_old_responsible, 'Система AppСтрой'), nullif(v_new_responsible, 'Система AppСтрой')),
      jsonb_build_object('from_user_id', old.responsible_user_id, 'to_user_id', new.responsible_user_id),
      v_actor
    );
  end if;

  if row(
    old.full_name, old.phone, old.citizenship, old.object_id, old.vacancy_id,
    old.position_title, old.experience_text, old.ready_date, old.hr_comment,
    old.custom_values
  ) is distinct from row(
    new.full_name, new.phone, new.citizenship, new.object_id, new.vacancy_id,
    new.position_title, new.experience_text, new.ready_date, new.hr_comment,
    new.custom_values
  ) then
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.id,
      'updated',
      'Данные кандидата обновлены',
      '',
      '{}'::jsonb,
      v_actor
    );
  end if;

  if old.archived_at is distinct from new.archived_at then
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.id,
      case when new.archived_at is null then 'restored' else 'archived' end,
      case when new.archived_at is null then 'Кандидат восстановлен из архива' else 'Кандидат перемещён в архив' end,
      '',
      '{}'::jsonb,
      v_actor
    );
  end if;

  return new;
end;
$$;

revoke all on function private.track_recruitment_application_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_applications_track_crm_activity
  on public.recruitment_applications;
create trigger recruitment_applications_track_crm_activity
  after insert or update on public.recruitment_applications
  for each row execute function private.track_recruitment_application_activity();

create or replace function private.track_recruitment_comment_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.add_recruitment_crm_activity(
      new.company_id, new.application_id, 'comment_added', 'Добавлен комментарий',
      left(new.body, 500), jsonb_build_object('comment_id', new.id), new.created_by
    );
  elsif old.body is distinct from new.body then
    perform private.add_recruitment_crm_activity(
      new.company_id, new.application_id, 'comment_updated', 'Комментарий изменён',
      left(new.body, 500), jsonb_build_object('comment_id', new.id), (select auth.uid())
    );
  end if;
  return new;
end;
$$;

revoke all on function private.track_recruitment_comment_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_crm_comments_track_activity
  on public.recruitment_crm_comments;
create trigger recruitment_crm_comments_track_activity
  after insert or update of body on public.recruitment_crm_comments
  for each row execute function private.track_recruitment_comment_activity();

create or replace function private.track_recruitment_task_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.add_recruitment_crm_activity(
      new.company_id, new.application_id, 'task_created', 'Создано дело',
      new.title, jsonb_build_object('task_id', new.id, 'due_at', new.due_at, 'task_type', new.task_type), new.created_by
    );
  elsif old.status is distinct from new.status then
    perform private.add_recruitment_crm_activity(
      new.company_id,
      new.application_id,
      case when new.status = 'completed' then 'task_completed'
           when new.status = 'cancelled' then 'task_cancelled'
           else 'task_reopened' end,
      case when new.status = 'completed' then 'Дело выполнено'
           when new.status = 'cancelled' then 'Дело отменено'
           else 'Дело возвращено в работу' end,
      new.title,
      jsonb_build_object('task_id', new.id, 'status', new.status),
      coalesce(new.completed_by, (select auth.uid()))
    );
  elsif row(old.title, old.description, old.due_at, old.assigned_to, old.priority)
        is distinct from row(new.title, new.description, new.due_at, new.assigned_to, new.priority) then
    perform private.add_recruitment_crm_activity(
      new.company_id, new.application_id, 'task_updated', 'Дело изменено',
      new.title, jsonb_build_object('task_id', new.id, 'due_at', new.due_at), (select auth.uid())
    );
  end if;
  return new;
end;
$$;

revoke all on function private.track_recruitment_task_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_crm_tasks_track_activity
  on public.recruitment_crm_tasks;
create trigger recruitment_crm_tasks_track_activity
  after insert or update on public.recruitment_crm_tasks
  for each row execute function private.track_recruitment_task_activity();

create or replace function private.track_recruitment_document_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.add_recruitment_crm_activity(
    new.company_id,
    new.application_id,
    'document_received',
    'Получен документ',
    coalesce(nullif(new.original_name, ''), new.document_type),
    jsonb_build_object('document_id', new.id, 'document_type', new.document_type),
    (select auth.uid())
  );
  return new;
end;
$$;

revoke all on function private.track_recruitment_document_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_documents_track_crm_activity
  on public.recruitment_documents;
create trigger recruitment_documents_track_crm_activity
  after insert on public.recruitment_documents
  for each row execute function private.track_recruitment_document_activity();

create or replace function private.track_recruitment_message_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.add_recruitment_crm_activity(
    new.company_id,
    new.application_id,
    case when new.direction = 'inbound' then 'message_received' else 'message_sent' end,
    case when new.direction = 'inbound' then 'Получено сообщение' else 'Отправлено сообщение' end,
    left(coalesce(new.message_text, ''), 500),
    jsonb_build_object('message_id', new.id, 'direction', new.direction),
    new.created_by
  );
  return new;
end;
$$;

revoke all on function private.track_recruitment_message_activity()
  from public, anon, authenticated;

drop trigger if exists recruitment_messages_track_crm_activity
  on public.recruitment_messages;
create trigger recruitment_messages_track_crm_activity
  after insert on public.recruitment_messages
  for each row execute function private.track_recruitment_message_activity();

create or replace function private.sync_recruitment_crm_task_reminder()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_name text := '';
  v_key text := 'recruitment_crm_task:' || new.id::text;
begin
  select application.full_name into v_candidate_name
  from public.recruitment_applications application
  where application.id = new.application_id
    and application.company_id = new.company_id;

  if new.status = 'pending' and new.due_at is not null then
    insert into public.scheduled_reminders(
      company_id,
      reminder_key,
      entity_type,
      entity_id,
      reminder_type,
      due_at,
      recipient_user_id,
      recipient_role,
      status,
      title,
      body,
      object_name,
      priority,
      in_app_enabled,
      push_enabled
    ) values (
      new.company_id,
      v_key,
      'recruitment_crm_task',
      new.id,
      'recruitment_crm_task_due',
      new.due_at,
      new.assigned_to,
      'hr',
      'pending',
      'Дело по кандидату: ' || new.title,
      case when coalesce(v_candidate_name, '') = '' then new.description
           else v_candidate_name || case when new.description = '' then '' else ' — ' || new.description end end,
      '',
      new.priority,
      true,
      true
    )
    on conflict (company_id, reminder_key) do update
    set due_at = excluded.due_at,
        recipient_user_id = excluded.recipient_user_id,
        recipient_role = excluded.recipient_role,
        status = 'pending',
        title = excluded.title,
        body = excluded.body,
        priority = excluded.priority,
        notification_id = null,
        sent_at = null;
  else
    update public.scheduled_reminders
    set status = case when status = 'sent' then status else 'cancelled' end
    where company_id = new.company_id
      and reminder_key = v_key;
  end if;

  return new;
end;
$$;

revoke all on function private.sync_recruitment_crm_task_reminder()
  from public, anon, authenticated;

drop trigger if exists recruitment_crm_tasks_sync_reminder
  on public.recruitment_crm_tasks;
create trigger recruitment_crm_tasks_sync_reminder
  after insert or update of status, due_at, assigned_to, title, description, priority
  on public.recruitment_crm_tasks
  for each row execute function private.sync_recruitment_crm_task_reminder();

create or replace function public.get_recruitment_responsibles()
returns table(user_id uuid, full_name text, role text)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    membership.user_id,
    coalesce(nullif(btrim(profile.full_name), ''), nullif(btrim(profile.email), ''), 'Пользователь AppСтрой') as full_name,
    membership.role
  from public.company_memberships membership
  left join public.user_profiles profile on profile.id = membership.user_id
  where membership.company_id = public.current_user_company_id()
    and membership.is_active
    and membership.role in ('owner','admin','developer','hr')
    and public.current_user_has_permission('recruitment.applications.view')
  order by lower(coalesce(profile.full_name, profile.email, '')), membership.user_id;
$$;

revoke all on function public.get_recruitment_responsibles()
  from public, anon;
grant execute on function public.get_recruitment_responsibles()
  to authenticated;

create or replace function public.assign_recruitment_responsible(
  p_application_id uuid,
  p_responsible_user_id uuid
)
returns public.recruitment_applications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_result public.recruitment_applications%rowtype;
begin
  if (select auth.uid()) is null then raise exception 'Требуется авторизация'; end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения кандидата';
  end if;

  update public.recruitment_applications application
  set responsible_user_id = p_responsible_user_id,
      updated_at = now()
  where application.company_id = v_company_id
    and application.id = p_application_id
  returning * into v_result;

  if v_result.id is null then raise exception 'Кандидат не найден или недоступен'; end if;
  return v_result;
end;
$$;

revoke all on function public.assign_recruitment_responsible(uuid,uuid)
  from public, anon;
grant execute on function public.assign_recruitment_responsible(uuid,uuid)
  to authenticated;

create or replace function public.bulk_move_recruitment_applications(
  p_application_ids uuid[],
  p_stage_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_stage public.recruitment_pipeline_stages%rowtype;
  v_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception 'Требуется авторизация'; end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения кандидатов';
  end if;
  if p_application_ids is null or cardinality(p_application_ids) = 0 then return 0; end if;
  if cardinality(p_application_ids) <> (select count(distinct id) from unnest(p_application_ids) ids(id)) then
    raise exception 'В списке кандидатов есть повторы';
  end if;

  select * into v_stage
  from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.id = p_stage_id
    and stage.is_active;
  if v_stage.id is null then raise exception 'Колонка CRM недоступна'; end if;

  with moved as (
    update public.recruitment_applications application
    set stage_id = v_stage.id,
        updated_at = now()
    where application.company_id = v_company_id
      and application.id = any(p_application_ids)
      and application.archived_at is null
      and application.stage_id is distinct from v_stage.id
    returning application.id, application.status
  ), history as (
    insert into public.recruitment_status_history(
      company_id, application_id, status, stage_id, stage_title, source, created_by
    )
    select v_company_id, moved.id, moved.status, v_stage.id, v_stage.title, 'appstroy_hr_bulk', (select auth.uid())
    from moved
    returning 1
  )
  select count(*) into v_count from moved;

  return v_count;
end;
$$;

revoke all on function public.bulk_move_recruitment_applications(uuid[],uuid)
  from public, anon;
grant execute on function public.bulk_move_recruitment_applications(uuid[],uuid)
  to authenticated;

alter table public.recruitment_crm_comments enable row level security;
alter table public.recruitment_crm_tasks enable row level security;
alter table public.recruitment_crm_activities enable row level security;
alter table public.recruitment_crm_saved_views enable row level security;
alter table public.recruitment_crm_automation_rules enable row level security;
alter table public.recruitment_crm_automation_runs enable row level security;

revoke all on table public.recruitment_crm_comments from public, anon;
revoke all on table public.recruitment_crm_tasks from public, anon;
revoke all on table public.recruitment_crm_activities from public, anon;
revoke all on table public.recruitment_crm_saved_views from public, anon;
revoke all on table public.recruitment_crm_automation_rules from public, anon;
revoke all on table public.recruitment_crm_automation_runs from public, anon;

grant select, insert, update, delete on table public.recruitment_crm_comments to authenticated;
grant select, insert, update, delete on table public.recruitment_crm_tasks to authenticated;
grant select on table public.recruitment_crm_activities to authenticated;
grant select, insert, update, delete on table public.recruitment_crm_saved_views to authenticated;
grant select, insert, update, delete on table public.recruitment_crm_automation_rules to authenticated;

create policy recruitment_crm_comments_select on public.recruitment_crm_comments
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_crm_comments_insert on public.recruitment_crm_comments
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_crm_comments_update on public.recruitment_crm_comments
  for update to authenticated using (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  ) with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_crm_comments_delete on public.recruitment_crm_comments
  for delete to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
    and (created_by = (select auth.uid()) or (select public.current_user_role()) in ('owner','admin','developer'))
  );

create policy recruitment_crm_tasks_select on public.recruitment_crm_tasks
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_crm_tasks_insert on public.recruitment_crm_tasks
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_crm_tasks_update on public.recruitment_crm_tasks
  for update to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  ) with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  );
create policy recruitment_crm_tasks_delete on public.recruitment_crm_tasks
  for delete to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.edit')
  );

create policy recruitment_crm_activities_select on public.recruitment_crm_activities
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );

create policy recruitment_crm_saved_views_select on public.recruitment_crm_saved_views
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and user_id = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_crm_saved_views_insert on public.recruitment_crm_saved_views
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and user_id = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_crm_saved_views_update on public.recruitment_crm_saved_views
  for update to authenticated using (
    company_id = (select public.current_user_company_id()) and user_id = (select auth.uid())
  ) with check (
    company_id = (select public.current_user_company_id()) and user_id = (select auth.uid())
  );
create policy recruitment_crm_saved_views_delete on public.recruitment_crm_saved_views
  for delete to authenticated using (
    company_id = (select public.current_user_company_id()) and user_id = (select auth.uid())
  );

create policy recruitment_crm_automation_rules_select on public.recruitment_crm_automation_rules
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_crm_automation_rules_insert on public.recruitment_crm_automation_rules
  for insert to authenticated with check (
    company_id = (select public.current_user_company_id())
    and created_by = (select auth.uid())
    and public.current_user_has_permission('recruitment.crm.configure')
  );
create policy recruitment_crm_automation_rules_update on public.recruitment_crm_automation_rules
  for update to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  ) with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  );
create policy recruitment_crm_automation_rules_delete on public.recruitment_crm_automation_rules
  for delete to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  );

create policy recruitment_crm_automation_runs_select on public.recruitment_crm_automation_runs
  for select to authenticated using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  );

drop trigger if exists recruitment_crm_comments_touch_updated_at on public.recruitment_crm_comments;
create trigger recruitment_crm_comments_touch_updated_at
  before update on public.recruitment_crm_comments
  for each row execute function public.touch_updated_at();
drop trigger if exists recruitment_crm_tasks_touch_updated_at on public.recruitment_crm_tasks;
create trigger recruitment_crm_tasks_touch_updated_at
  before update on public.recruitment_crm_tasks
  for each row execute function public.touch_updated_at();
drop trigger if exists recruitment_crm_saved_views_touch_updated_at on public.recruitment_crm_saved_views;
create trigger recruitment_crm_saved_views_touch_updated_at
  before update on public.recruitment_crm_saved_views
  for each row execute function public.touch_updated_at();
drop trigger if exists recruitment_crm_automation_rules_touch_updated_at on public.recruitment_crm_automation_rules;
create trigger recruitment_crm_automation_rules_touch_updated_at
  before update on public.recruitment_crm_automation_rules
  for each row execute function public.touch_updated_at();

drop trigger if exists app_data_broadcast_after_change on public.recruitment_crm_comments;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_crm_comments
  for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.recruitment_crm_tasks;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_crm_tasks
  for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.recruitment_crm_activities;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_crm_activities
  for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.recruitment_crm_saved_views;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_crm_saved_views
  for each row execute function private.broadcast_app_data_change();
drop trigger if exists app_data_broadcast_after_change on public.recruitment_crm_automation_rules;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_crm_automation_rules
  for each row execute function private.broadcast_app_data_change();

-- Seed a concise activity history for existing candidates.
insert into public.recruitment_crm_activities(
  company_id, application_id, event_type, title, body, metadata, actor_user_id, actor_name, created_at
)
select
  application.company_id,
  application.id,
  'created',
  'Кандидат добавлен',
  application.full_name,
  jsonb_build_object('source', application.source, 'status', application.status),
  null,
  'Система AppСтрой',
  application.created_at
from public.recruitment_applications application
where not exists (
  select 1 from public.recruitment_crm_activities activity
  where activity.application_id = application.id and activity.event_type = 'created'
);
