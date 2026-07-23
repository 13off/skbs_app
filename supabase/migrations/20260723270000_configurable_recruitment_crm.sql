-- Configurable recruitment CRM: company-defined pipeline stages and custom fields.

insert into public.permission_catalog(
  permission_code,
  category,
  title,
  description,
  supports_object_scope,
  sort_order
)
values (
  'recruitment.crm.configure',
  'Подбор',
  'Настройка CRM кандидатов',
  'Создание и изменение колонок воронки и пользовательских полей карточки кандидата',
  false,
  2010
)
on conflict (permission_code) do update
set category = excluded.category,
    title = excluded.title,
    description = excluded.description,
    supports_object_scope = excluded.supports_object_scope,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.role_permissions(role_code, permission_code)
select role_code, 'recruitment.crm.configure'
from (values ('owner'), ('admin'), ('developer'), ('hr')) as roles(role_code)
on conflict do nothing;

create table if not exists public.recruitment_pipeline_stages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  system_key text,
  title text not null,
  description text not null default '',
  color_hex text not null default '#2F80ED',
  sort_order integer not null default 100,
  legacy_status text not null default 'new',
  is_final boolean not null default false,
  is_active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_pipeline_stages_title_check
    check (char_length(btrim(title)) between 1 and 80),
  constraint recruitment_pipeline_stages_color_check
    check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  constraint recruitment_pipeline_stages_status_check
    check (legacy_status in (
      'draft','new','contacted','waiting_documents','review','medical',
      'approved','ticket_request','in_transit','arrived','hired','reserve','rejected'
    )),
  constraint recruitment_pipeline_stages_company_id_id_unique
    unique (company_id, id)
);

create unique index if not exists recruitment_pipeline_stages_company_system_key_uidx
  on public.recruitment_pipeline_stages(company_id, system_key)
  where system_key is not null;
create unique index if not exists recruitment_pipeline_stages_company_title_uidx
  on public.recruitment_pipeline_stages(company_id, lower(btrim(title)))
  where is_active;
create index if not exists recruitment_pipeline_stages_company_order_idx
  on public.recruitment_pipeline_stages(company_id, is_active, sort_order, created_at);

create table if not exists public.recruitment_custom_fields (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  title text not null,
  field_type text not null default 'text',
  options jsonb not null default '[]'::jsonb,
  is_required boolean not null default false,
  show_on_card boolean not null default false,
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recruitment_custom_fields_title_check
    check (char_length(btrim(title)) between 1 and 100),
  constraint recruitment_custom_fields_type_check
    check (field_type in (
      'text','multiline','number','money','phone','email','date',
      'boolean','select','multiselect'
    )),
  constraint recruitment_custom_fields_options_check
    check (jsonb_typeof(options) = 'array')
);

create unique index if not exists recruitment_custom_fields_company_title_uidx
  on public.recruitment_custom_fields(company_id, lower(btrim(title)))
  where is_active;
create index if not exists recruitment_custom_fields_company_order_idx
  on public.recruitment_custom_fields(company_id, is_active, sort_order, created_at);

create or replace function private.seed_recruitment_pipeline_stages(p_company_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.recruitment_pipeline_stages(
    company_id,
    system_key,
    title,
    description,
    color_hex,
    sort_order,
    legacy_status,
    is_final
  )
  select
    p_company_id,
    seed.system_key,
    seed.title,
    seed.description,
    seed.color_hex,
    seed.sort_order,
    seed.legacy_status,
    seed.is_final
  from (values
    ('new',       'Новые',           'Новые заявки и первичный контакт',  '#2F80ED', 10, 'new',               false),
    ('documents', 'Ждём документы',  'Собираем документы и медкомиссию',  '#4C6076', 20, 'waiting_documents', false),
    ('problems',  'Косяки',          'Есть замечания или нужна проверка',  '#C04B45', 30, 'review',            false),
    ('ready',     'Готовы к вылету', 'Проверены и готовы к отправке',      '#2E8B57', 40, 'approved',          false),
    ('tickets',   'Нужны билеты',    'Билеты куплены или кандидат в пути', '#C48718', 50, 'ticket_request',    false),
    ('completed', 'Оформлены',       'Прибыли на объект или оформлены',    '#2E8B57', 60, 'arrived',           true),
    ('reserve',   'Резерв',          'Подходят, но пока не запускаем',     '#6C5B7B', 70, 'reserve',           true),
    ('rejected',  'Отказ',           'Отказ или кандидат не подходит',     '#9A403A', 80, 'rejected',          true)
  ) as seed(system_key, title, description, color_hex, sort_order, legacy_status, is_final)
  on conflict (company_id, system_key) where system_key is not null do nothing;
$$;

revoke all on function private.seed_recruitment_pipeline_stages(uuid)
  from public, anon, authenticated;

create or replace function private.seed_recruitment_pipeline_stages_after_company_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.seed_recruitment_pipeline_stages(new.id);
  return new;
end;
$$;

revoke all on function private.seed_recruitment_pipeline_stages_after_company_insert()
  from public, anon, authenticated;

drop trigger if exists companies_seed_recruitment_pipeline_stages
  on public.companies;
create trigger companies_seed_recruitment_pipeline_stages
  after insert on public.companies
  for each row execute function private.seed_recruitment_pipeline_stages_after_company_insert();

do $$
declare
  company_row record;
begin
  for company_row in select id from public.companies loop
    perform private.seed_recruitment_pipeline_stages(company_row.id);
  end loop;
end;
$$;

alter table public.recruitment_applications
  add column if not exists stage_id uuid,
  add column if not exists custom_values jsonb not null default '{}'::jsonb;

alter table public.recruitment_applications
  drop constraint if exists recruitment_applications_custom_values_check;
alter table public.recruitment_applications
  add constraint recruitment_applications_custom_values_check
  check (jsonb_typeof(custom_values) = 'object');

alter table public.recruitment_applications
  drop constraint if exists recruitment_applications_company_stage_fk;
alter table public.recruitment_applications
  add constraint recruitment_applications_company_stage_fk
  foreign key (company_id, stage_id)
  references public.recruitment_pipeline_stages(company_id, id)
  on delete restrict;

alter table public.recruitment_status_history
  add column if not exists stage_id uuid,
  add column if not exists stage_title text not null default '';

alter table public.recruitment_status_history
  drop constraint if exists recruitment_status_history_company_stage_fk;
alter table public.recruitment_status_history
  drop constraint if exists recruitment_status_history_stage_fk;
alter table public.recruitment_status_history
  add constraint recruitment_status_history_stage_fk
  foreign key (stage_id)
  references public.recruitment_pipeline_stages(id)
  on delete set null;

create index if not exists recruitment_applications_company_stage_idx
  on public.recruitment_applications(company_id, stage_id, archived_at, updated_at desc);
create index if not exists recruitment_status_history_stage_idx
  on public.recruitment_status_history(company_id, stage_id, created_at desc)
  where stage_id is not null;

update public.recruitment_applications application
set stage_id = stage.id
from public.recruitment_pipeline_stages stage
where stage.company_id = application.company_id
  and stage.system_key = case
    when application.status in ('waiting_documents', 'medical') then 'documents'
    when application.status = 'review' then 'problems'
    when application.status = 'approved' then 'ready'
    when application.status in ('ticket_request', 'in_transit') then 'tickets'
    when application.status in ('arrived', 'hired') then 'completed'
    when application.status = 'reserve' then 'reserve'
    when application.status = 'rejected' then 'rejected'
    else 'new'
  end
  and application.stage_id is null;

create or replace function private.sync_recruitment_pipeline_stage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_system_key text;
  resolved_stage_id uuid;
  resolved_status text;
begin
  target_system_key := case
    when new.status in ('waiting_documents', 'medical') then 'documents'
    when new.status = 'review' then 'problems'
    when new.status = 'approved' then 'ready'
    when new.status in ('ticket_request', 'in_transit') then 'tickets'
    when new.status in ('arrived', 'hired') then 'completed'
    when new.status = 'reserve' then 'reserve'
    when new.status = 'rejected' then 'rejected'
    else 'new'
  end;

  if new.stage_id is null
     or (tg_op = 'UPDATE'
         and new.status is distinct from old.status
         and new.stage_id is not distinct from old.stage_id) then
    select stage.id
      into resolved_stage_id
    from public.recruitment_pipeline_stages stage
    where stage.company_id = new.company_id
      and stage.system_key = target_system_key
      and stage.is_active
    limit 1;

    if resolved_stage_id is null then
      select stage.id
        into resolved_stage_id
      from public.recruitment_pipeline_stages stage
      where stage.company_id = new.company_id
        and stage.is_active
      order by stage.sort_order, stage.created_at, stage.id
      limit 1;
    end if;

    new.stage_id := resolved_stage_id;
  elsif tg_op = 'INSERT' or new.stage_id is distinct from old.stage_id then
    select stage.legacy_status
      into resolved_status
    from public.recruitment_pipeline_stages stage
    where stage.company_id = new.company_id
      and stage.id = new.stage_id
      and stage.is_active;

    if resolved_status is null then
      raise exception 'Выбранный этап CRM недоступен';
    end if;
    new.status := resolved_status;
  end if;

  if new.stage_id is null then
    raise exception 'В компании нет активных этапов CRM';
  end if;

  return new;
end;
$$;

revoke all on function private.sync_recruitment_pipeline_stage()
  from public, anon, authenticated;

drop trigger if exists recruitment_applications_sync_pipeline_stage
  on public.recruitment_applications;
create trigger recruitment_applications_sync_pipeline_stage
  before insert or update of status, stage_id, company_id
  on public.recruitment_applications
  for each row execute function private.sync_recruitment_pipeline_stage();

create or replace function private.guard_recruitment_stage_archive()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.is_active and not new.is_active then
    if exists (
      select 1
      from public.recruitment_applications application
      where application.company_id = old.company_id
        and application.stage_id = old.id
        and application.archived_at is null
    ) then
      raise exception 'Сначала переместите кандидатов из этой колонки';
    end if;

    if not exists (
      select 1
      from public.recruitment_pipeline_stages stage
      where stage.company_id = old.company_id
        and stage.is_active
        and stage.id <> old.id
    ) then
      raise exception 'В CRM должна остаться хотя бы одна активная колонка';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_recruitment_stage_archive()
  from public, anon, authenticated;

drop trigger if exists recruitment_pipeline_stages_guard_archive
  on public.recruitment_pipeline_stages;
create trigger recruitment_pipeline_stages_guard_archive
  before update of is_active on public.recruitment_pipeline_stages
  for each row execute function private.guard_recruitment_stage_archive();

alter table public.recruitment_applications
  alter column stage_id set not null;

create or replace function public.move_recruitment_application_stage(
  p_application_id uuid,
  p_stage_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_company_id uuid := public.current_user_company_id();
  selected_stage_title text;
  resulting_status text;
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;

  select stage.title
    into selected_stage_title
  from public.recruitment_pipeline_stages stage
  where stage.company_id = current_company_id
    and stage.id = p_stage_id
    and stage.is_active;

  if selected_stage_title is null then
    raise exception 'Этап CRM не найден или недоступен';
  end if;

  update public.recruitment_applications application
  set stage_id = p_stage_id,
      updated_at = now()
  where application.company_id = current_company_id
    and application.id = p_application_id
  returning application.status into resulting_status;

  if resulting_status is null then
    raise exception 'Кандидат не найден или недоступен';
  end if;

  insert into public.recruitment_status_history(
    company_id,
    application_id,
    status,
    stage_id,
    stage_title,
    source,
    created_by
  )
  values (
    current_company_id,
    p_application_id,
    resulting_status,
    p_stage_id,
    selected_stage_title,
    'appstroy_hr',
    (select auth.uid())
  );
end;
$$;

revoke all on function public.move_recruitment_application_stage(uuid, uuid)
  from public, anon;
grant execute on function public.move_recruitment_application_stage(uuid, uuid)
  to authenticated;

alter table public.recruitment_pipeline_stages enable row level security;
alter table public.recruitment_custom_fields enable row level security;

revoke all on table public.recruitment_pipeline_stages from public, anon;
revoke all on table public.recruitment_custom_fields from public, anon;
grant select, insert, update on table public.recruitment_pipeline_stages to authenticated;
grant select, insert, update on table public.recruitment_custom_fields to authenticated;

drop policy if exists recruitment_pipeline_stages_select
  on public.recruitment_pipeline_stages;
drop policy if exists recruitment_pipeline_stages_insert
  on public.recruitment_pipeline_stages;
drop policy if exists recruitment_pipeline_stages_update
  on public.recruitment_pipeline_stages;
drop policy if exists recruitment_pipeline_stages_delete
  on public.recruitment_pipeline_stages;

create policy recruitment_pipeline_stages_select
  on public.recruitment_pipeline_stages
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_pipeline_stages_insert
  on public.recruitment_pipeline_stages
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
    and (created_by is null or created_by = (select auth.uid()))
  );
create policy recruitment_pipeline_stages_update
  on public.recruitment_pipeline_stages
  for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  );

drop policy if exists recruitment_custom_fields_select
  on public.recruitment_custom_fields;
drop policy if exists recruitment_custom_fields_insert
  on public.recruitment_custom_fields;
drop policy if exists recruitment_custom_fields_update
  on public.recruitment_custom_fields;
drop policy if exists recruitment_custom_fields_delete
  on public.recruitment_custom_fields;

create policy recruitment_custom_fields_select
  on public.recruitment_custom_fields
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.applications.view')
  );
create policy recruitment_custom_fields_insert
  on public.recruitment_custom_fields
  for insert to authenticated
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
    and (created_by is null or created_by = (select auth.uid()))
  );
create policy recruitment_custom_fields_update
  on public.recruitment_custom_fields
  for update to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  )
  with check (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.crm.configure')
  );

drop trigger if exists recruitment_pipeline_stages_touch_updated_at
  on public.recruitment_pipeline_stages;
create trigger recruitment_pipeline_stages_touch_updated_at
  before update on public.recruitment_pipeline_stages
  for each row execute function public.touch_updated_at();

drop trigger if exists recruitment_custom_fields_touch_updated_at
  on public.recruitment_custom_fields;
create trigger recruitment_custom_fields_touch_updated_at
  before update on public.recruitment_custom_fields
  for each row execute function public.touch_updated_at();

drop trigger if exists app_data_broadcast_after_change
  on public.recruitment_pipeline_stages;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_pipeline_stages
  for each row execute function private.broadcast_app_data_change();

drop trigger if exists app_data_broadcast_after_change
  on public.recruitment_custom_fields;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_custom_fields
  for each row execute function private.broadcast_app_data_change();
