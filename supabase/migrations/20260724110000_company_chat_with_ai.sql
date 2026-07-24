-- Общий защищённый чат компании с ответами, упоминаниями, файлами,
-- непрочитанными сообщениями и ответами ИИ-помощника.

insert into public.permission_catalog(
  permission_code, category, title, description, supports_object_scope, sort_order
)
values
  ('company_chat.view', 'Коммуникации', 'Просмотр чата компании', 'Открывать общий чат активных сотрудников компании.', false, 650),
  ('company_chat.send', 'Коммуникации', 'Сообщения в чате компании', 'Писать сообщения, отвечать и упоминать сотрудников.', false, 660),
  ('company_chat.files', 'Коммуникации', 'Файлы в чате компании', 'Прикреплять и скачивать файлы общего чата.', false, 670),
  ('company_chat.moderate', 'Коммуникации', 'Модерация чата компании', 'Удалять сообщения и вложения других участников.', false, 680)
on conflict (permission_code) do update set
  category = excluded.category,
  title = excluded.title,
  description = excluded.description,
  supports_object_scope = excluded.supports_object_scope,
  sort_order = excluded.sort_order,
  updated_at = now();

insert into public.role_permissions(role_code, permission_code)
select role_code, permission_code
from (values
  ('owner'), ('admin'), ('developer'), ('foreman'), ('lawyer'), ('accountant'), ('hr')
) roles(role_code)
cross join (values
  ('company_chat.view'), ('company_chat.send'), ('company_chat.files')
) permissions(permission_code)
on conflict do nothing;

insert into public.role_permissions(role_code, permission_code)
values
  ('owner', 'company_chat.moderate'),
  ('admin', 'company_chat.moderate'),
  ('developer', 'company_chat.moderate')
on conflict do nothing;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'company-chat-files',
  'company-chat-files',
  false,
  20971520,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf', 'text/plain', 'text/csv',
    'application/zip',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.company_chat_messages (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_name text not null default '',
  sender_role text not null default '',
  kind text not null default 'user',
  body text not null default '',
  reply_to_id uuid,
  mentioned_user_ids uuid[] not null default '{}'::uuid[],
  client_nonce text,
  ai_payload jsonb not null default '{}'::jsonb,
  ai_requester_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  deleted_by uuid references auth.users(id) on delete set null,
  constraint company_chat_messages_kind_check
    check (kind in ('user', 'assistant', 'system')),
  constraint company_chat_messages_body_length_check
    check (char_length(body) <= 5000),
  constraint company_chat_messages_ai_payload_check
    check (jsonb_typeof(ai_payload) = 'object'),
  constraint company_chat_messages_mentions_limit_check
    check (cardinality(mentioned_user_ids) <= 50)
);

alter table public.company_chat_messages
  drop constraint if exists company_chat_messages_company_id_id_unique;
alter table public.company_chat_messages
  add constraint company_chat_messages_company_id_id_unique
  unique (company_id, id);

alter table public.company_chat_messages
  drop constraint if exists company_chat_messages_company_reply_fk;
alter table public.company_chat_messages
  add constraint company_chat_messages_company_reply_fk
  foreign key (company_id, reply_to_id)
  references public.company_chat_messages(company_id, id)
  on delete set null;

create unique index if not exists company_chat_messages_client_nonce_uidx
  on public.company_chat_messages(company_id, sender_user_id, client_nonce)
  where client_nonce is not null;
create unique index if not exists company_chat_messages_ai_reply_uidx
  on public.company_chat_messages(company_id, reply_to_id)
  where kind = 'assistant' and reply_to_id is not null and deleted_at is null;
create index if not exists company_chat_messages_company_created_idx
  on public.company_chat_messages(company_id, created_at desc, id desc)
  where deleted_at is null;
create index if not exists company_chat_messages_mentions_idx
  on public.company_chat_messages using gin(mentioned_user_ids)
  where deleted_at is null;

create table if not exists public.company_chat_attachments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  message_id uuid not null,
  storage_bucket text not null default 'company-chat-files',
  storage_path text not null,
  file_name text not null,
  mime_type text not null default 'application/octet-stream',
  size_bytes bigint not null default 0,
  uploaded_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint company_chat_attachments_company_message_fk
    foreign key (company_id, message_id)
    references public.company_chat_messages(company_id, id)
    on delete cascade,
  constraint company_chat_attachments_bucket_check
    check (storage_bucket = 'company-chat-files'),
  constraint company_chat_attachments_path_check
    check (char_length(btrim(storage_path)) between 3 and 1000),
  constraint company_chat_attachments_name_check
    check (char_length(btrim(file_name)) between 1 and 255),
  constraint company_chat_attachments_size_check
    check (size_bytes between 0 and 20971520)
);

create unique index if not exists company_chat_attachments_path_uidx
  on public.company_chat_attachments(storage_bucket, storage_path);
create index if not exists company_chat_attachments_message_idx
  on public.company_chat_attachments(company_id, message_id, created_at);

create table if not exists public.company_chat_reads (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, user_id)
);

alter table public.company_chat_messages enable row level security;
alter table public.company_chat_attachments enable row level security;
alter table public.company_chat_reads enable row level security;

revoke all on table public.company_chat_messages from public, anon;
revoke all on table public.company_chat_attachments from public, anon;
revoke all on table public.company_chat_reads from public, anon;

grant select on table public.company_chat_messages to authenticated;
grant select, insert, delete on table public.company_chat_attachments to authenticated;
grant select, insert, update on table public.company_chat_reads to authenticated;

create policy company_chat_messages_select
on public.company_chat_messages
for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('company_chat.view')
);

create policy company_chat_attachments_select
on public.company_chat_attachments
for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_has_permission('company_chat.view')
);

create policy company_chat_attachments_insert
on public.company_chat_attachments
for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and uploaded_by = (select auth.uid())
  and public.current_user_has_permission('company_chat.files')
  and exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = company_chat_attachments.company_id
      and message.id = company_chat_attachments.message_id
      and message.sender_user_id = (select auth.uid())
      and message.kind = 'user'
      and message.deleted_at is null
  )
);

create policy company_chat_attachments_delete
on public.company_chat_attachments
for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    uploaded_by = (select auth.uid())
    or public.current_user_has_permission('company_chat.moderate')
  )
);

create policy company_chat_reads_select
on public.company_chat_reads
for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and user_id = (select auth.uid())
  and public.current_user_has_permission('company_chat.view')
);

create policy company_chat_reads_insert
on public.company_chat_reads
for insert to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and user_id = (select auth.uid())
  and public.current_user_has_permission('company_chat.view')
);

create policy company_chat_reads_update
on public.company_chat_reads
for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and user_id = (select auth.uid())
)
with check (
  company_id = (select public.current_user_company_id())
  and user_id = (select auth.uid())
);

create or replace function public.get_company_chat_members()
returns table(user_id uuid, full_name text, role text)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    membership.user_id,
    coalesce(
      nullif(btrim(profile.full_name), ''),
      nullif(btrim(profile.email), ''),
      'Сотрудник AppСтрой'
    ) as full_name,
    membership.role
  from public.company_memberships membership
  left join public.user_profiles profile on profile.id = membership.user_id
  where membership.company_id = public.current_user_company_id()
    and membership.is_active
    and public.current_user_has_permission('company_chat.view')
  order by lower(coalesce(profile.full_name, profile.email, '')), membership.user_id;
$$;

revoke all on function public.get_company_chat_members() from public, anon;
grant execute on function public.get_company_chat_members() to authenticated;

create or replace function public.create_company_chat_message(
  p_body text,
  p_reply_to_id uuid default null,
  p_mentioned_user_ids uuid[] default '{}'::uuid[],
  p_client_nonce text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_sender_name text := '';
  v_sender_role text := '';
  v_message_id uuid;
  v_mentions uuid[] := '{}'::uuid[];
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется повторный вход';
  end if;
  if not public.current_user_has_permission('company_chat.send') then
    raise exception 'Нет права писать в чат компании';
  end if;
  if char_length(coalesce(p_body, '')) > 5000 then
    raise exception 'Сообщение длиннее 5000 символов';
  end if;
  if p_reply_to_id is not null and not exists (
    select 1 from public.company_chat_messages message
    where message.company_id = v_company_id
      and message.id = p_reply_to_id
      and message.deleted_at is null
  ) then
    raise exception 'Сообщение для ответа недоступно';
  end if;

  select
    coalesce(nullif(btrim(profile.full_name), ''), nullif(btrim(profile.email), ''), 'Сотрудник AppСтрой'),
    membership.role
  into v_sender_name, v_sender_role
  from public.company_memberships membership
  left join public.user_profiles profile on profile.id = membership.user_id
  where membership.company_id = v_company_id
    and membership.user_id = v_user_id
    and membership.is_active;

  if v_sender_role = '' then
    raise exception 'Активное участие в компании не найдено';
  end if;

  select coalesce(array_agg(distinct membership.user_id), '{}'::uuid[])
  into v_mentions
  from public.company_memberships membership
  where membership.company_id = v_company_id
    and membership.is_active
    and membership.user_id = any(coalesce(p_mentioned_user_ids, '{}'::uuid[]));

  insert into public.company_chat_messages(
    company_id,
    sender_user_id,
    sender_name,
    sender_role,
    kind,
    body,
    reply_to_id,
    mentioned_user_ids,
    client_nonce
  ) values (
    v_company_id,
    v_user_id,
    v_sender_name,
    v_sender_role,
    'user',
    btrim(coalesce(p_body, '')),
    p_reply_to_id,
    v_mentions,
    nullif(btrim(coalesce(p_client_nonce, '')), '')
  )
  on conflict (company_id, sender_user_id, client_nonce)
    where client_nonce is not null
  do update set client_nonce = excluded.client_nonce
  returning id into v_message_id;

  return v_message_id;
end;
$$;

revoke all on function public.create_company_chat_message(text,uuid,uuid[],text)
  from public, anon;
grant execute on function public.create_company_chat_message(text,uuid,uuid[],text)
  to authenticated;

create or replace function public.delete_company_chat_message(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_updated integer := 0;
begin
  if v_user_id is null then raise exception 'Требуется повторный вход'; end if;
  update public.company_chat_messages message
  set body = '',
      mentioned_user_ids = '{}'::uuid[],
      ai_payload = '{}'::jsonb,
      deleted_at = now(),
      deleted_by = v_user_id
  where message.company_id = v_company_id
    and message.id = p_message_id
    and message.deleted_at is null
    and (
      message.sender_user_id = v_user_id
      or public.current_user_has_permission('company_chat.moderate')
    );
  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.delete_company_chat_message(uuid) from public, anon;
grant execute on function public.delete_company_chat_message(uuid) to authenticated;

create or replace function public.mark_company_chat_read(p_read_at timestamptz default now())
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_read_at timestamptz := least(coalesce(p_read_at, now()), now());
begin
  if v_user_id is null or v_company_id is null then return; end if;
  if not public.current_user_has_permission('company_chat.view') then return; end if;

  insert into public.company_chat_reads(company_id, user_id, last_read_at, updated_at)
  values (v_company_id, v_user_id, v_read_at, now())
  on conflict (company_id, user_id) do update
  set last_read_at = greatest(public.company_chat_reads.last_read_at, excluded.last_read_at),
      updated_at = now();
end;
$$;

revoke all on function public.mark_company_chat_read(timestamptz) from public, anon;
grant execute on function public.mark_company_chat_read(timestamptz) to authenticated;

create or replace function public.get_company_chat_unread_state()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with state as (
    select coalesce(
      (select reads.last_read_at
       from public.company_chat_reads reads
       where reads.company_id = public.current_user_company_id()
         and reads.user_id = (select auth.uid())),
      '-infinity'::timestamptz
    ) as last_read_at
  )
  select jsonb_build_object(
    'unread_count', count(*) filter (
      where message.created_at > state.last_read_at
        and message.sender_user_id is distinct from (select auth.uid())
    ),
    'mention_count', count(*) filter (
      where message.created_at > state.last_read_at
        and (select auth.uid()) = any(message.mentioned_user_ids)
    ),
    'last_message_at', max(message.created_at)
  )
  from state
  left join public.company_chat_messages message
    on message.company_id = public.current_user_company_id()
   and message.deleted_at is null
  where public.current_user_has_permission('company_chat.view');
$$;

revoke all on function public.get_company_chat_unread_state() from public, anon;
grant execute on function public.get_company_chat_unread_state() to authenticated;

create or replace function public.get_company_chat_feed(
  p_limit integer default 100,
  p_before timestamptz default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(feed) order by feed.created_at, feed.id), '[]'::jsonb)
  from (
    select
      message.id,
      message.company_id,
      message.sender_user_id,
      message.sender_name,
      message.sender_role,
      message.kind,
      message.body,
      message.reply_to_id,
      message.mentioned_user_ids,
      message.ai_payload,
      message.ai_requester_user_id,
      message.created_at,
      message.edited_at,
      message.deleted_at,
      case when reply.id is null then null else jsonb_build_object(
        'id', reply.id,
        'sender_name', reply.sender_name,
        'kind', reply.kind,
        'body', case when reply.deleted_at is null then left(reply.body, 280) else '' end,
        'deleted', reply.deleted_at is not null
      ) end as reply,
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', attachment.id,
          'storage_bucket', attachment.storage_bucket,
          'storage_path', attachment.storage_path,
          'file_name', attachment.file_name,
          'mime_type', attachment.mime_type,
          'size_bytes', attachment.size_bytes,
          'created_at', attachment.created_at
        ) order by attachment.created_at, attachment.id)
        from public.company_chat_attachments attachment
        where attachment.company_id = message.company_id
          and attachment.message_id = message.id
      ), '[]'::jsonb) as attachments
    from public.company_chat_messages message
    left join public.company_chat_messages reply
      on reply.company_id = message.company_id
     and reply.id = message.reply_to_id
    where message.company_id = public.current_user_company_id()
      and (p_before is null or message.created_at < p_before)
      and public.current_user_has_permission('company_chat.view')
    order by message.created_at desc, message.id desc
    limit least(greatest(coalesce(p_limit, 100), 1), 200)
  ) feed;
$$;

revoke all on function public.get_company_chat_feed(integer,timestamptz)
  from public, anon;
grant execute on function public.get_company_chat_feed(integer,timestamptz)
  to authenticated;

create or replace function private.broadcast_company_chat_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_company_id text := nullif(v_row ->> 'company_id', '');
begin
  if v_company_id is null then return null; end if;
  perform realtime.send(
    jsonb_build_object(
      'table', tg_table_name,
      'operation', tg_op,
      'message_id', coalesce(v_row ->> 'message_id', v_row ->> 'id')
    ),
    'company_chat_changed',
    'company:' || v_company_id || ':chat',
    true
  );
  return null;
end;
$$;

revoke all on function private.broadcast_company_chat_change()
  from public, anon, authenticated;

drop trigger if exists company_chat_broadcast_after_change on public.company_chat_messages;
create trigger company_chat_broadcast_after_change
  after insert or update or delete on public.company_chat_messages
  for each row execute function private.broadcast_company_chat_change();

drop trigger if exists company_chat_broadcast_after_change on public.company_chat_attachments;
create trigger company_chat_broadcast_after_change
  after insert or update or delete on public.company_chat_attachments
  for each row execute function private.broadcast_company_chat_change();

drop policy if exists company_members_receive_company_chat_broadcasts
  on realtime.messages;
create policy company_members_receive_company_chat_broadcasts
on realtime.messages
for select to authenticated
using (
  extension = 'broadcast'
  and realtime.topic() =
    'company:' || (select public.current_user_company_id())::text || ':chat'
  and public.current_user_has_permission('company_chat.view')
);

-- Доступ к файлам привязан к company_id/message_id в первых папках пути.
drop policy if exists company_chat_files_select on storage.objects;
create policy company_chat_files_select
on storage.objects
for select to authenticated
using (
  bucket_id = 'company-chat-files'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and public.current_user_has_permission('company_chat.view')
);

drop policy if exists company_chat_files_insert on storage.objects;
create policy company_chat_files_insert
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'company-chat-files'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and public.current_user_has_permission('company_chat.files')
  and exists (
    select 1 from public.company_chat_messages message
    where message.company_id = public.current_user_company_id()
      and message.id::text = (storage.foldername(name))[2]
      and message.sender_user_id = (select auth.uid())
      and message.deleted_at is null
  )
);

drop policy if exists company_chat_files_delete on storage.objects;
create policy company_chat_files_delete
on storage.objects
for delete to authenticated
using (
  bucket_id = 'company-chat-files'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and exists (
    select 1 from public.company_chat_messages message
    where message.company_id = public.current_user_company_id()
      and message.id::text = (storage.foldername(name))[2]
      and (
        message.sender_user_id = (select auth.uid())
        or public.current_user_has_permission('company_chat.moderate')
      )
  )
);
