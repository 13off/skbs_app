-- Завершение рабочего контура юриста: комплектность, объектные досье,
-- версии документов, процессуальный таймлайн, автоматический «Сегодня» и контроль качества.

-- 1. Полный жизненный цикл документа.
alter table public.legal_documents
  drop constraint if exists legal_documents_status_check;

alter table public.legal_documents
  add constraint legal_documents_status_check
  check (status = any (array[
    'draft'::text,
    'prepared'::text,
    'review'::text,
    'awaiting_signature'::text,
    'signed'::text,
    'active'::text,
    'expired'::text,
    'needs_correction'::text,
    'terminated'::text,
    'archive'::text
  ]));

-- 2. Реальные версии файлов документа.
alter table public.legal_document_files
  add column if not exists version_no integer,
  add column if not exists version_label text not null default '',
  add column if not exists archived_at timestamptz;

with ranked as (
  select ctid,
         row_number() over (
           partition by document_id
           order by created_at asc, file_id asc
         ) as rn
  from public.legal_document_files
)
update public.legal_document_files ldf
set version_no = ranked.rn
from ranked
where ldf.ctid = ranked.ctid
  and ldf.version_no is null;

alter table public.legal_document_files
  alter column version_no set not null;

create unique index if not exists legal_document_files_version_uidx
  on public.legal_document_files(document_id, version_no)
  where archived_at is null;

create or replace function public.prepare_legal_document_file_version()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.version_no is null or new.version_no <= 0 then
    select coalesce(max(version_no), 0) + 1
      into new.version_no
    from public.legal_document_files
    where document_id = new.document_id;
  end if;

  if new.is_primary then
    update public.legal_document_files
       set is_primary = false
     where document_id = new.document_id
       and file_id <> new.file_id
       and archived_at is null;
  end if;
  return new;
end;
$$;

revoke all on function public.prepare_legal_document_file_version() from public, anon, authenticated;

drop trigger if exists legal_document_file_version_guard on public.legal_document_files;
create trigger legal_document_file_version_guard
before insert or update of is_primary on public.legal_document_files
for each row execute function public.prepare_legal_document_file_version();

-- 3. Неизменяемая история жизненного цикла документа.
create table if not exists public.legal_document_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  document_id uuid not null references public.legal_documents(id) on delete cascade,
  event_type text not null check (event_type = any (array['created','status','updated','file']::text[])),
  title text not null,
  body text not null default '',
  actor_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists legal_document_events_document_idx
  on public.legal_document_events(document_id, created_at desc);
create index if not exists legal_document_events_company_idx
  on public.legal_document_events(company_id, created_at desc);

alter table public.legal_document_events enable row level security;
revoke all on public.legal_document_events from public, anon, authenticated;
grant select on public.legal_document_events to authenticated;

drop policy if exists legal_document_events_select on public.legal_document_events;
create policy legal_document_events_select
on public.legal_document_events
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.documents.view')
    or public.is_admin()
  )
);

create or replace function public.log_legal_document_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := coalesce(new.updated_by, new.created_by, auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.legal_document_events(
      company_id, document_id, event_type, title, body, actor_user_id
    ) values (
      new.company_id, new.id, 'created', 'Документ создан', coalesce(new.title, ''), v_actor
    );
    return new;
  end if;

  if old.status is distinct from new.status then
    insert into public.legal_document_events(
      company_id, document_id, event_type, title, body, actor_user_id
    ) values (
      new.company_id,
      new.id,
      'status',
      'Статус изменён',
      coalesce(old.status, '') || ' → ' || coalesce(new.status, ''),
      v_actor
    );
  elsif row(old.title, old.document_type, old.document_number, old.expires_on,
            old.next_action, old.next_action_due_at, old.employee_id,
            old.object_id, old.counterparty_id)
        is distinct from
        row(new.title, new.document_type, new.document_number, new.expires_on,
            new.next_action, new.next_action_due_at, new.employee_id,
            new.object_id, new.counterparty_id) then
    insert into public.legal_document_events(
      company_id, document_id, event_type, title, body, actor_user_id
    ) values (
      new.company_id, new.id, 'updated', 'Карточка документа обновлена', '', v_actor
    );
  end if;
  return new;
end;
$$;

revoke all on function public.log_legal_document_change() from public, anon, authenticated;

drop trigger if exists legal_document_change_history on public.legal_documents;
create trigger legal_document_change_history
after insert or update on public.legal_documents
for each row execute function public.log_legal_document_change();

create or replace function public.log_legal_document_file_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid;
  v_name text;
begin
  select d.company_id into v_company
  from public.legal_documents d
  where d.id = new.document_id;

  select coalesce(original_name, '') into v_name
  from public.app_files
  where id = new.file_id;

  if v_company is not null then
    insert into public.legal_document_events(
      company_id, document_id, event_type, title, body, actor_user_id
    ) values (
      v_company,
      new.document_id,
      'file',
      'Добавлена версия файла',
      'Версия ' || new.version_no::text || case when v_name = '' then '' else ' • ' || v_name end,
      auth.uid()
    );
  end if;
  return new;
end;
$$;

revoke all on function public.log_legal_document_file_change() from public, anon, authenticated;

drop trigger if exists legal_document_file_history on public.legal_document_files;
create trigger legal_document_file_history
after insert on public.legal_document_files
for each row execute function public.log_legal_document_file_change();

-- 4. Юридический профиль объекта.
create table if not exists public.legal_object_profiles (
  object_id uuid primary key references public.objects(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  customer_counterparty_id uuid references public.legal_counterparties(id) on delete set null,
  main_contract_document_id uuid references public.legal_documents(id) on delete set null,
  responsible_user_id uuid references auth.users(id) on delete set null,
  contract_value numeric(16,2),
  contract_start date,
  contract_end date,
  notes text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_object_profiles_company_idx
  on public.legal_object_profiles(company_id, object_id);

create or replace function public.guard_legal_object_profile_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.objects o
    where o.id = new.object_id and o.company_id = new.company_id
  ) then
    raise exception 'Объект не принадлежит компании';
  end if;
  if new.customer_counterparty_id is not null and not exists (
    select 1 from public.legal_counterparties c
    where c.id = new.customer_counterparty_id and c.company_id = new.company_id
  ) then
    raise exception 'Контрагент не принадлежит компании';
  end if;
  if new.main_contract_document_id is not null and not exists (
    select 1 from public.legal_documents d
    where d.id = new.main_contract_document_id and d.company_id = new.company_id
  ) then
    raise exception 'Договор не принадлежит компании';
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

revoke all on function public.guard_legal_object_profile_tenant() from public, anon, authenticated;

drop trigger if exists legal_object_profile_tenant_guard on public.legal_object_profiles;
create trigger legal_object_profile_tenant_guard
before insert or update on public.legal_object_profiles
for each row execute function public.guard_legal_object_profile_tenant();

alter table public.legal_object_profiles enable row level security;
revoke all on public.legal_object_profiles from public, anon;
grant select, insert, update on public.legal_object_profiles to authenticated;

drop policy if exists legal_object_profiles_select on public.legal_object_profiles;
create policy legal_object_profiles_select
on public.legal_object_profiles
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  )
);

drop policy if exists legal_object_profiles_insert on public.legal_object_profiles;
create policy legal_object_profiles_insert
on public.legal_object_profiles
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.documents.edit')
    or public.current_user_has_permission('legal.matters.edit')
    or public.is_admin()
  )
);

drop policy if exists legal_object_profiles_update on public.legal_object_profiles;
create policy legal_object_profiles_update
on public.legal_object_profiles
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and (
    public.current_user_has_permission('legal.documents.edit')
    or public.current_user_has_permission('legal.matters.edit')
    or public.is_admin()
  )
)
with check (company_id = public.current_user_company_id());

create or replace function public.legal_object_profile(p_object_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view') or public.is_admin()
  ) then
    raise exception 'Нет доступа к досье объекта';
  end if;

  select jsonb_build_object(
    'object_id', o.id,
    'object_name', coalesce(o.name, ''),
    'address', coalesce(o.address, ''),
    'comment', coalesce(o.comment, ''),
    'is_active', coalesce(o.is_active, true),
    'customer_counterparty_id', p.customer_counterparty_id,
    'customer_name', coalesce(c.name, ''),
    'main_contract_document_id', p.main_contract_document_id,
    'main_contract_title', coalesce(d.title, ''),
    'responsible_user_id', p.responsible_user_id,
    'contract_value', p.contract_value,
    'contract_start', p.contract_start,
    'contract_end', p.contract_end,
    'notes', coalesce(p.notes, '')
  ) into v_result
  from public.objects o
  left join public.legal_object_profiles p
    on p.object_id = o.id and p.company_id = o.company_id
  left join public.legal_counterparties c
    on c.id = p.customer_counterparty_id and c.company_id = o.company_id
  left join public.legal_documents d
    on d.id = p.main_contract_document_id and d.company_id = o.company_id
  where o.id = p_object_id and o.company_id = v_company;

  if v_result is null then
    raise exception 'Объект не найден';
  end if;
  return v_result;
end;
$$;

revoke all on function public.legal_object_profile(uuid) from public, anon;
grant execute on function public.legal_object_profile(uuid) to authenticated;

-- 5. Настраиваемая комплектность документов сотрудника.
create table if not exists public.legal_document_requirements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null,
  title text not null,
  document_group text not null default 'other',
  matcher_regex text not null,
  is_required boolean not null default true,
  active_only boolean not null default true,
  citizenship_regex text not null default '',
  priority integer not null default 100,
  sort_order integer not null default 100,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists legal_document_requirements_scope_uidx
  on public.legal_document_requirements(coalesce(company_id, '00000000-0000-0000-0000-000000000000'::uuid), code);

alter table public.legal_document_requirements enable row level security;
revoke all on public.legal_document_requirements from public, anon;
grant select, insert, update, delete on public.legal_document_requirements to authenticated;

drop policy if exists legal_document_requirements_select on public.legal_document_requirements;
create policy legal_document_requirements_select
on public.legal_document_requirements
for select
to authenticated
using (
  (company_id is null or company_id = public.current_user_company_id())
  and (
    public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  )
);

drop policy if exists legal_document_requirements_write on public.legal_document_requirements;
create policy legal_document_requirements_write
on public.legal_document_requirements
for all
to authenticated
using (company_id = public.current_user_company_id() and public.is_admin())
with check (company_id = public.current_user_company_id() and public.is_admin());

insert into public.legal_document_requirements(
  company_id, code, title, document_group, matcher_regex,
  is_required, active_only, priority, sort_order
) values
  (null, 'passport', 'Паспорт', 'personal_document', '(passport|паспорт)', true, true, 10, 10),
  (null, 'registration', 'Регистрация / прописка', 'personal_document', '(registration|пропис|регистрац)', true, true, 20, 20),
  (null, 'snils', 'СНИЛС', 'personal_document', '(snils|снилс)', true, true, 30, 30),
  (null, 'inn', 'ИНН', 'personal_document', '(inn|инн)', true, true, 40, 40),
  (null, 'insurance', 'Полис', 'personal_document', '(polis|полис|insurance|страхов)', true, true, 50, 50),
  (null, 'photo', 'Фото', 'personal_document', '(photo|фото)', true, true, 60, 60),
  (null, 'employee_contract', 'Договор с сотрудником', 'contract', '(гпх|gph|civil|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)', true, true, 5, 70),
  (null, 'employment_application', 'Заявление на работу', 'application_consent', '(employment_application|заявлен.*работ|заявлен.*при[её]м)', true, true, 15, 80),
  (null, 'salary_transfer_application', 'Заявление о перечислении зарплаты', 'application_consent', '(salary_transfer_application|перечислен.*зарп|получен.*зарп|выплат.*реквиз)', true, true, 15, 90),
  (null, 'personal_data_consent', 'Согласие на обработку персональных данных', 'application_consent', '(personal_data_consent|персональн.*данн|соглас.*обработ)', true, true, 15, 100),
  (null, 'ticket_purchase_agreement', 'Соглашение на приобретение билетов', 'application_consent', '(ticket_purchase_agreement|приобретен.*билет|соглашен.*билет)', false, true, 150, 110),
  (null, 'termination_application', 'Заявление на увольнение', 'application_consent', '(termination_application|заявлен.*увольн)', false, false, 150, 120)
on conflict do nothing;

create or replace function public.legal_employee_completeness(p_employee_id uuid)
returns table(
  requirement_code text,
  requirement_title text,
  document_group text,
  is_required boolean,
  applicable boolean,
  present boolean,
  matched_title text,
  matched_source text,
  priority integer,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
  v_active boolean;
  v_citizenship text;
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view')
    or public.current_user_has_permission('legal.documents.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к комплектности документов';
  end if;

  select coalesce(e.is_active, true), coalesce(ra.citizenship, '')
    into v_active, v_citizenship
  from public.employees e
  left join lateral (
    select a.citizenship
    from public.recruitment_applications a
    where a.company_id = e.company_id and a.employee_id = e.id
    order by a.updated_at desc nulls last, a.created_at desc
    limit 1
  ) ra on true
  where e.id = p_employee_id and e.company_id = v_company;

  if not found then
    raise exception 'Сотрудник не найден';
  end if;

  return query
  with req as (
    select distinct on (r.code)
      r.code, r.title, r.document_group, r.matcher_regex, r.is_required,
      r.active_only, r.citizenship_regex, r.priority, r.sort_order,
      (not r.active_only or v_active)
      and (r.citizenship_regex = '' or v_citizenship ~* r.citizenship_regex) as is_applicable
    from public.legal_document_requirements r
    where r.enabled
      and (r.company_id = v_company or r.company_id is null)
    order by r.code, (r.company_id is not null) desc, r.updated_at desc
  ), docs as (
    select d.*,
      lower(
        coalesce(d.title, '') || ' ' ||
        coalesce(d.document_type, '') || ' ' ||
        coalesce(d.file_name, '')
      ) as haystack
    from public.legal_employee_dossier_documents(p_employee_id) d
  )
  select
    r.code,
    r.title,
    r.document_group,
    r.is_required,
    r.is_applicable,
    (m.source_id is not null) as present,
    coalesce(m.title, ''),
    coalesce(m.source_label, ''),
    r.priority,
    r.sort_order
  from req r
  left join lateral (
    select d.source_id, d.title, d.source_label
    from docs d
    where d.haystack ~* r.matcher_regex
    order by d.document_date desc nulls last
    limit 1
  ) m on true
  order by r.sort_order, r.title;
end;
$$;

revoke all on function public.legal_employee_completeness(uuid) from public, anon;
grant execute on function public.legal_employee_completeness(uuid) to authenticated;

-- 6. Процессуальный календарь судебных дел и претензий.
create table if not exists public.legal_matter_process_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  matter_id uuid not null references public.legal_matters(id) on delete cascade,
  event_kind text not null check (event_kind = any (array[
    'hearing','deadline','filing','incoming','outgoing','decision','enforcement','note'
  ]::text[])),
  title text not null,
  event_at timestamptz,
  due_at timestamptz,
  status text not null default 'scheduled' check (status = any (array['scheduled','completed','cancelled']::text[])),
  result text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_matter_process_events_matter_idx
  on public.legal_matter_process_events(matter_id, coalesce(event_at, due_at), created_at);
create index if not exists legal_matter_process_events_company_due_idx
  on public.legal_matter_process_events(company_id, status, due_at);

alter table public.legal_matter_process_events enable row level security;
revoke all on public.legal_matter_process_events from public, anon;
grant select, insert, update, delete on public.legal_matter_process_events to authenticated;

drop policy if exists legal_process_events_select on public.legal_matter_process_events;
create policy legal_process_events_select
on public.legal_matter_process_events
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.legal_matter_allowed_for_user(matter_id)
);

drop policy if exists legal_process_events_insert on public.legal_matter_process_events;
create policy legal_process_events_insert
on public.legal_matter_process_events
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
);

drop policy if exists legal_process_events_update on public.legal_matter_process_events;
create policy legal_process_events_update
on public.legal_matter_process_events
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
)
with check (company_id = public.current_user_company_id());

drop policy if exists legal_process_events_delete on public.legal_matter_process_events;
create policy legal_process_events_delete
on public.legal_matter_process_events
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
);

create or replace function public.guard_legal_process_event_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.legal_matters m
    where m.id = new.matter_id and m.company_id = new.company_id
  ) then
    raise exception 'Дело не принадлежит компании';
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

revoke all on function public.guard_legal_process_event_tenant() from public, anon, authenticated;

drop trigger if exists legal_process_event_tenant_guard on public.legal_matter_process_events;
create trigger legal_process_event_tenant_guard
before insert or update on public.legal_matter_process_events
for each row execute function public.guard_legal_process_event_tenant();

create or replace function public.sync_legal_process_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_matter_id uuid := coalesce(new.matter_id, old.matter_id);
  v_company uuid := coalesce(new.company_id, old.company_id);
  v_title text;
  v_result text;
begin
  select min(coalesce(event_at, due_at))
    into strict new.event_at
  from public.legal_matter_process_events
  where false;
exception when no_data_found then
  -- Ничего: блок выше нужен только для совместимости CREATE OR REPLACE в старых БД.
  null;
end;
$$;

-- Заменяем временную функцию корректной синхронизацией без зависимости от TG_OP-псевдозаписей.
create or replace function public.sync_legal_process_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_matter_id uuid;
  v_company uuid;
  v_event_kind text;
  v_title text;
  v_result text;
  v_next_hearing timestamptz;
begin
  if tg_op = 'DELETE' then
    v_matter_id := old.matter_id;
    v_company := old.company_id;
    v_event_kind := old.event_kind;
    v_title := old.title;
    v_result := old.result;
  else
    v_matter_id := new.matter_id;
    v_company := new.company_id;
    v_event_kind := new.event_kind;
    v_title := new.title;
    v_result := new.result;
  end if;

  select min(coalesce(e.event_at, e.due_at))
    into v_next_hearing
  from public.legal_matter_process_events e
  where e.matter_id = v_matter_id
    and e.event_kind = 'hearing'
    and e.status = 'scheduled'
    and coalesce(e.event_at, e.due_at) >= now();

  update public.legal_matters
     set next_hearing_at = v_next_hearing,
         updated_at = now()
   where id = v_matter_id and company_id = v_company;

  if tg_op = 'INSERT' then
    insert into public.legal_matter_events(
      company_id, matter_id, event_type, title, body, actor_user_id
    ) values (
      v_company,
      v_matter_id,
      'note',
      'Процесс: ' || coalesce(v_title, ''),
      coalesce(v_result, ''),
      auth.uid()
    );
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.sync_legal_process_event() from public, anon, authenticated;

drop trigger if exists legal_process_event_sync on public.legal_matter_process_events;
create trigger legal_process_event_sync
after insert or update or delete on public.legal_matter_process_events
for each row execute function public.sync_legal_process_event();

-- 7. Автоматическая рабочая очередь «Сегодня».
create or replace function public.legal_today_items()
returns table(
  item_type text,
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  due_at timestamptz,
  severity text,
  employee_id uuid,
  object_id uuid,
  action_code text,
  sort_key integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view')
    or public.current_user_has_permission('legal.documents.view')
    or public.current_user_has_permission('legal.matters.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к рабочей очереди юриста';
  end if;

  return query
  with missing as (
    select
      e.id as employee_id,
      e.object_id,
      e.fio,
      count(*) filter (where c.is_required and c.applicable and not c.present) as missing_count,
      string_agg(c.requirement_title, ', ' order by c.sort_order)
        filter (where c.is_required and c.applicable and not c.present) as missing_titles,
      min(c.priority) filter (where c.is_required and c.applicable and not c.present) as min_priority
    from public.employees e
    cross join lateral public.legal_employee_completeness(e.id) c
    where e.company_id = v_company
      and coalesce(e.is_active, true)
      and e.archived_at is null
    group by e.id, e.object_id, e.fio
  )
  select
    'missing_documents'::text,
    'employee'::text,
    m.employee_id,
    m.fio || ': неполный комплект',
    m.missing_count::text || ' • ' || coalesce(m.missing_titles, ''),
    null::timestamptz,
    case when coalesce(m.min_priority, 100) <= 15 then 'warning' else 'info' end,
    m.employee_id,
    m.object_id,
    'open_employee'::text,
    40
  from missing m
  where m.missing_count > 0

  union all

  select
    'document_attention',
    'legal_document',
    d.id,
    d.title,
    trim(both ' • ' from concat_ws(' • ',
      case d.status
        when 'awaiting_signature' then 'Ожидает подписи'
        when 'needs_correction' then 'Требует исправления'
        when 'expired' then 'Истёк'
        else null
      end,
      case when d.expires_on < current_date then 'Срок действия истёк'
           when d.expires_on <= current_date + 30 then 'Срок действия подходит'
           else null end,
      case when d.next_action_due_at < now() then 'Следующее действие просрочено'
           when d.next_action_due_at <= now() + interval '7 days' then coalesce(nullif(d.next_action,''), 'Ближайшее действие')
           else null end
    )),
    least(
      coalesce(d.next_action_due_at, 'infinity'::timestamptz),
      coalesce(d.expires_on::timestamptz, 'infinity'::timestamptz)
    ),
    case
      when d.status in ('needs_correction','expired')
        or d.expires_on < current_date
        or d.next_action_due_at < now() then 'danger'
      else 'warning'
    end,
    d.employee_id,
    d.object_id,
    'open_document',
    10
  from public.legal_documents d
  where d.company_id = v_company
    and d.archived_at is null
    and (
      d.status in ('awaiting_signature','needs_correction','expired')
      or d.approval_status = 'pending'
      or d.expires_on <= current_date + 30
      or d.next_action_due_at <= now() + interval '7 days'
    )

  union all

  select
    'matter_attention',
    'legal_matter',
    m.id,
    m.title,
    trim(both ' • ' from concat_ws(' • ',
      case when m.due_at < now() then 'Срок просрочен' end,
      case when m.risk_level in ('high','critical') then 'Высокий риск' end,
      case when m.requires_manager_decision and m.decision_status = 'pending' then 'Ждёт решения руководителя' end,
      case when m.matter_type = 'court' and m.next_hearing_at <= now() + interval '14 days' then 'Ближайшее заседание' end,
      case when m.matter_type = 'claim' and m.response_due_at <= now() + interval '7 days' then 'Срок ответа по претензии' end
    )),
    least(
      coalesce(m.due_at, 'infinity'::timestamptz),
      coalesce(m.next_hearing_at, 'infinity'::timestamptz),
      coalesce(m.response_due_at, 'infinity'::timestamptz)
    ),
    case
      when m.risk_level = 'critical'
        or m.due_at < now()
        or (m.matter_type = 'claim' and m.response_due_at < now()) then 'danger'
      else 'warning'
    end,
    m.employee_id,
    m.object_id,
    'open_matter',
    5
  from public.legal_matters m
  where m.company_id = v_company
    and m.status not in ('resolved','closed')
    and (
      m.due_at <= now() + interval '7 days'
      or m.risk_level in ('high','critical')
      or (m.requires_manager_decision and m.decision_status = 'pending')
      or (m.matter_type = 'court' and m.next_hearing_at <= now() + interval '14 days')
      or (m.matter_type = 'claim' and m.response_due_at <= now() + interval '7 days')
    )

  union all

  select
    'process_event',
    'legal_matter',
    e.matter_id,
    e.title,
    case e.event_kind
      when 'hearing' then 'Судебное заседание'
      when 'deadline' then 'Процессуальный срок'
      when 'filing' then 'Подача документа'
      when 'incoming' then 'Ожидаемый входящий документ'
      when 'outgoing' then 'Исходящий документ'
      when 'decision' then 'Решение'
      when 'enforcement' then 'Исполнение'
      else 'Событие дела'
    end,
    coalesce(e.due_at, e.event_at),
    case when coalesce(e.due_at, e.event_at) < now() then 'danger' else 'warning' end,
    m.employee_id,
    m.object_id,
    'open_matter',
    3
  from public.legal_matter_process_events e
  join public.legal_matters m on m.id = e.matter_id and m.company_id = e.company_id
  where e.company_id = v_company
    and e.status = 'scheduled'
    and coalesce(e.due_at, e.event_at) <= now() + interval '14 days'

  union all

  select
    'recovery',
    'absence_fine',
    f.id,
    coalesce(emp.fio, 'Сотрудник') || ': взыскание ' || round(f.amount)::text || ' ₽',
    concat_ws(' • ',
      case when coalesce(f.act_file_path, '') = '' then 'нет акта' else 'акт есть' end,
      case when coalesce(f.explanation_file_path, '') = '' then 'нет объяснительной' else 'объяснительная есть' end,
      'ожидает решения руководителя'
    ),
    null::timestamptz,
    case when coalesce(f.act_file_path, '') = '' or coalesce(f.explanation_file_path, '') = '' then 'danger' else 'warning' end,
    f.employee_id,
    emp.object_id,
    'open_employee',
    20
  from public.absence_fines f
  left join public.employees emp on emp.id = f.employee_id and emp.company_id = f.company_id
  where f.company_id = v_company and f.status = 'pending';
end;
$$;

revoke all on function public.legal_today_items() from public, anon;
grant execute on function public.legal_today_items() to authenticated;

-- 8. Технический контроль качества юридической базы.
create or replace function public.legal_quality_report()
returns table(
  issue_type text,
  severity text,
  entity_type text,
  entity_id uuid,
  title text,
  details text
)
language plpgsql
stable
security definer
set search_path = public, storage, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.documents.view')
    or public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к контролю юридической базы';
  end if;

  return query
  select
    'document_without_file', 'warning', 'legal_document', d.id,
    d.title, 'У документа нет ни одного активного файла'
  from public.legal_documents d
  where d.company_id = v_company and d.archived_at is null
    and not exists (
      select 1 from public.legal_document_files ldf
      join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
      where ldf.document_id = d.id and ldf.archived_at is null
    )

  union all

  select
    'unlinked_document', 'warning', 'legal_document', d.id,
    d.title, 'Документ не привязан к сотруднику, объекту, контрагенту или делу'
  from public.legal_documents d
  where d.company_id = v_company and d.archived_at is null
    and d.employee_id is null and d.object_id is null
    and d.counterparty_id is null and d.legal_matter_id is null

  union all

  select
    'broken_legal_file', 'danger', 'legal_document', ldf.document_id,
    coalesce(af.original_name, 'Файл'), 'Файл указан в базе, но отсутствует в Storage'
  from public.legal_document_files ldf
  join public.legal_documents d on d.id = ldf.document_id and d.company_id = v_company
  join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
  left join storage.objects so
    on so.bucket_id = af.bucket_name and so.name = af.storage_path
  where ldf.archived_at is null and so.id is null

  union all

  select
    'broken_employee_file', 'danger', 'employee', edf.employee_id,
    coalesce(nullif(edf.original_file_name,''), nullif(edf.document_type,''), 'Документ сотрудника'),
    'Кадровый файл указан в базе, но отсутствует в Storage'
  from public.employee_document_files edf
  left join storage.objects so
    on so.bucket_id = edf.storage_bucket and so.name = edf.storage_path
  where edf.company_id = v_company
    and coalesce(edf.storage_path, '') <> ''
    and so.id is null

  union all

  select
    'matter_without_responsible', 'info', 'legal_matter', m.id,
    m.title, 'У открытого дела не назначен ответственный'
  from public.legal_matters m
  where m.company_id = v_company
    and m.status not in ('resolved','closed')
    and m.responsible_user_id is null;
end;
$$;

revoke all on function public.legal_quality_report() from public, anon;
grant execute on function public.legal_quality_report() to authenticated;
