insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'recruitment-documents',
  'recruitment-documents',
  false,
  20971520,
  array['image/jpeg','image/png','image/webp','application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.recruitment_documents
  alter column storage_bucket set default 'recruitment-documents',
  alter column is_test_copy set default false;

insert into public.role_permissions (role_code, permission_code)
values
  ('owner', 'recruitment.messages.view'),
  ('owner', 'recruitment.messages.send'),
  ('admin', 'recruitment.messages.view'),
  ('admin', 'recruitment.messages.send'),
  ('hr', 'recruitment.messages.view'),
  ('hr', 'recruitment.messages.send')
on conflict (role_code, permission_code) do nothing;

create table if not exists public.recruitment_messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  application_id uuid not null references public.recruitment_applications(id) on delete cascade,
  direction text not null check (direction = any (array['inbound'::text, 'outbound'::text, 'system'::text])),
  message_text text not null default '',
  storage_bucket text not null default '',
  storage_path text not null default '',
  original_name text not null default '',
  mime_type text not null default '',
  size_bytes bigint,
  telegram_message_id bigint,
  telegram_file_id text not null default '',
  telegram_file_unique_id text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint recruitment_messages_content_check
    check (message_text <> '' or storage_path <> '' or telegram_file_id <> '')
);

create index if not exists recruitment_messages_application_created_idx
  on public.recruitment_messages (application_id, created_at);
create index if not exists recruitment_messages_company_created_idx
  on public.recruitment_messages (company_id, created_at desc);

alter table public.recruitment_messages enable row level security;
revoke all on table public.recruitment_messages from anon;
grant select on table public.recruitment_messages to authenticated;

drop policy if exists recruitment_messages_select on public.recruitment_messages;
create policy recruitment_messages_select
  on public.recruitment_messages
  for select
  to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and public.current_user_has_permission('recruitment.messages.view')
  );

drop policy if exists recruitment_documents_storage_select on storage.objects;
create policy recruitment_documents_storage_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'recruitment-documents'
    and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
    and public.current_user_has_permission('recruitment.documents.view')
  );

drop trigger if exists app_data_broadcast_after_change on public.recruitment_messages;
create trigger app_data_broadcast_after_change
  after insert or update or delete on public.recruitment_messages
  for each row execute function private.broadcast_app_data_change();

create or replace function private.queue_recruitment_telegram_file_ingest()
returns trigger
language plpgsql
security definer
set search_path = public, net
as $$
declare
  entity_kind text;
begin
  if coalesce(new.telegram_file_id, '') = '' then
    return new;
  end if;
  if coalesce(new.storage_bucket, '') = 'recruitment-documents'
     and coalesce(new.storage_path, '') <> ''
     and new.storage_path not like 'telegram://%' then
    return new;
  end if;

  entity_kind := case when tg_table_name = 'recruitment_documents'
    then 'document' else 'message' end;

  perform net.http_post(
    url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/recruitment-ingest-telegram-file',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('kind', entity_kind, 'id', new.id),
    timeout_milliseconds := 15000
  );
  return new;
end;
$$;

revoke all on function private.queue_recruitment_telegram_file_ingest() from public;

drop trigger if exists recruitment_documents_ingest_telegram_file on public.recruitment_documents;
create trigger recruitment_documents_ingest_telegram_file
  after insert or update of telegram_file_id, storage_path
  on public.recruitment_documents
  for each row execute function private.queue_recruitment_telegram_file_ingest();

drop trigger if exists recruitment_messages_ingest_telegram_file on public.recruitment_messages;
create trigger recruitment_messages_ingest_telegram_file
  after insert or update of telegram_file_id, storage_path
  on public.recruitment_messages
  for each row execute function private.queue_recruitment_telegram_file_ingest();
