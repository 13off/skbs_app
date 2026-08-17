-- Жизненный цикл, реальные версии файлов и append-only история юридического документа.

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
