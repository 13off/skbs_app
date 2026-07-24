begin;

create or replace function public.company_chat_thread_key(
  p_channel_kind text,
  p_user_id uuid,
  p_peer_user_id uuid default null
)
returns text
language plpgsql
immutable
set search_path to ''
as $$
declare
  v_kind text := lower(btrim(coalesce(p_channel_kind, 'general')));
  v_first text;
  v_second text;
begin
  if v_kind = 'general' then
    return 'general';
  end if;

  if p_user_id is null then
    raise exception 'Не удалось определить участника чата';
  end if;

  if v_kind = 'assistant' then
    return 'assistant:' || p_user_id::text;
  end if;

  if v_kind = 'direct' then
    if p_peer_user_id is null or p_peer_user_id = p_user_id then
      raise exception 'Некорректный собеседник';
    end if;
    v_first := least(p_user_id::text, p_peer_user_id::text);
    v_second := greatest(p_user_id::text, p_peer_user_id::text);
    return 'direct:' || v_first || ':' || v_second;
  end if;

  raise exception 'Неизвестный тип чата';
end;
$$;

alter table public.company_chat_messages
  add column if not exists channel_kind text not null default 'general',
  add column if not exists peer_user_id uuid,
  add column if not exists thread_key text not null default 'general';

with assistant_sources as (
  select distinct on (reply_to_id)
    reply_to_id,
    ai_requester_user_id
  from public.company_chat_messages
  where kind = 'assistant'
    and reply_to_id is not null
    and ai_requester_user_id is not null
  order by reply_to_id, created_at desc
)
update public.company_chat_messages source
set channel_kind = 'assistant',
    peer_user_id = assistant_sources.ai_requester_user_id,
    thread_key = public.company_chat_thread_key(
      'assistant',
      assistant_sources.ai_requester_user_id,
      assistant_sources.ai_requester_user_id
    )
from assistant_sources
where source.id = assistant_sources.reply_to_id;

update public.company_chat_messages message
set channel_kind = 'assistant',
    peer_user_id = message.ai_requester_user_id,
    thread_key = public.company_chat_thread_key(
      'assistant',
      message.ai_requester_user_id,
      message.ai_requester_user_id
    )
where message.kind = 'assistant'
  and message.ai_requester_user_id is not null;

alter table public.company_chat_messages
  drop constraint if exists company_chat_messages_channel_kind_check;
alter table public.company_chat_messages
  add constraint company_chat_messages_channel_kind_check
  check (channel_kind in ('general', 'direct', 'assistant'));

alter table public.company_chat_messages
  drop constraint if exists company_chat_messages_thread_shape_check;
alter table public.company_chat_messages
  add constraint company_chat_messages_thread_shape_check
  check (
    (channel_kind = 'general' and peer_user_id is null and thread_key = 'general')
    or
    (
      channel_kind = 'direct'
      and sender_user_id is not null
      and peer_user_id is not null
      and sender_user_id <> peer_user_id
      and thread_key = public.company_chat_thread_key(
        'direct',
        sender_user_id,
        peer_user_id
      )
    )
    or
    (
      channel_kind = 'assistant'
      and peer_user_id is not null
      and thread_key = public.company_chat_thread_key(
        'assistant',
        peer_user_id,
        peer_user_id
      )
    )
  );

create index if not exists company_chat_messages_thread_created_idx
  on public.company_chat_messages(company_id, thread_key, created_at desc, id desc);
create index if not exists company_chat_messages_direct_participants_idx
  on public.company_chat_messages(company_id, sender_user_id, peer_user_id, created_at desc)
  where channel_kind = 'direct';

alter table public.company_chat_reads
  add column if not exists thread_key text not null default 'general';

alter table public.company_chat_reads
  drop constraint if exists company_chat_reads_pkey;
alter table public.company_chat_reads
  add constraint company_chat_reads_pkey
  primary key (company_id, user_id, thread_key);

create or replace function public.can_view_company_chat_thread(
  p_company_id uuid,
  p_channel_kind text,
  p_sender_user_id uuid,
  p_peer_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select
    p_company_id = public.current_user_company_id()
    and public.current_user_has_permission('company_chat.view')
    and (
      p_channel_kind = 'general'
      or (
        p_channel_kind = 'direct'
        and (select auth.uid()) is not null
        and (
          p_sender_user_id = (select auth.uid())
          or p_peer_user_id = (select auth.uid())
        )
      )
      or (
        p_channel_kind = 'assistant'
        and p_peer_user_id = (select auth.uid())
      )
    );
$$;

revoke all on function public.can_view_company_chat_thread(uuid, text, uuid, uuid) from public;
grant execute on function public.can_view_company_chat_thread(uuid, text, uuid, uuid) to authenticated;

create or replace function public.get_company_chat_threads()
returns table(
  thread_key text,
  channel_kind text,
  peer_user_id uuid,
  title text,
  role text,
  unread_count bigint,
  last_message_at timestamptz,
  last_message_preview text
)
language sql
stable
security definer
set search_path to ''
as $$
  with identity as (
    select
      public.current_user_company_id() as company_id,
      (select auth.uid()) as user_id
  ),
  base as (
    select
      'general'::text as thread_key,
      'general'::text as channel_kind,
      null::uuid as peer_user_id,
      'Общий чат'::text as title,
      ''::text as role,
      0 as sort_group
    from identity
    where company_id is not null
      and user_id is not null
      and public.current_user_has_permission('company_chat.view')

    union all

    select
      public.company_chat_thread_key('direct', identity.user_id, membership.user_id),
      'direct'::text,
      membership.user_id,
      coalesce(
        nullif(btrim(profile.full_name), ''),
        nullif(btrim(profile.email), ''),
        'Сотрудник AppСтрой'
      ),
      membership.role,
      1
    from identity
    join public.company_memberships membership
      on membership.company_id = identity.company_id
     and membership.is_active
     and membership.user_id <> identity.user_id
    left join public.user_profiles profile on profile.id = membership.user_id
    where public.current_user_has_permission('company_chat.view')

    union all

    select
      public.company_chat_thread_key('assistant', identity.user_id, identity.user_id),
      'assistant'::text,
      identity.user_id,
      'ИИ-помощник'::text,
      'ai'::text,
      2
    from identity
    where company_id is not null
      and user_id is not null
      and public.current_user_has_permission('company_chat.view')
      and public.current_user_has_permission('ai.use')
  )
  select
    base.thread_key,
    base.channel_kind,
    base.peer_user_id,
    base.title,
    base.role,
    coalesce(unread.value, 0)::bigint as unread_count,
    latest.created_at as last_message_at,
    coalesce(latest.preview, '') as last_message_preview
  from base
  cross join identity
  left join public.company_chat_reads reads
    on reads.company_id = identity.company_id
   and reads.user_id = identity.user_id
   and reads.thread_key = base.thread_key
  left join lateral (
    select count(*)::bigint as value
    from public.company_chat_messages message
    where message.company_id = identity.company_id
      and message.thread_key = base.thread_key
      and message.deleted_at is null
      and message.sender_user_id is distinct from identity.user_id
      and message.created_at > coalesce(reads.last_read_at, '-infinity'::timestamptz)
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
  ) unread on true
  left join lateral (
    select
      message.created_at,
      case
        when message.deleted_at is not null then 'Сообщение удалено'
        when btrim(message.body) <> '' then left(message.body, 100)
        when exists (
          select 1
          from public.company_chat_attachments attachment
          where attachment.company_id = message.company_id
            and attachment.message_id = message.id
        ) then 'Файл'
        else ''
      end as preview
    from public.company_chat_messages message
    where message.company_id = identity.company_id
      and message.thread_key = base.thread_key
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
    order by message.created_at desc, message.id desc
    limit 1
  ) latest on true
  order by base.sort_group, lower(base.title), base.peer_user_id;
$$;

revoke all on function public.get_company_chat_threads() from public;
grant execute on function public.get_company_chat_threads() to authenticated;

drop function if exists public.get_company_chat_feed(integer, timestamptz);
create function public.get_company_chat_feed(
  p_limit integer default 100,
  p_before timestamptz default null,
  p_channel_kind text default 'general',
  p_peer_user_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_kind text := lower(btrim(coalesce(p_channel_kind, 'general')));
  v_peer_user_id uuid := p_peer_user_id;
  v_thread_key text;
begin
  if v_company_id is null or v_user_id is null then
    raise exception 'Требуется повторный вход';
  end if;
  if not public.current_user_has_permission('company_chat.view') then
    raise exception 'Нет доступа к чату';
  end if;

  if v_kind = 'general' then
    v_peer_user_id := null;
  elsif v_kind = 'assistant' then
    if not public.current_user_has_permission('ai.use') then
      raise exception 'Для этой роли ИИ-помощник отключён';
    end if;
    v_peer_user_id := v_user_id;
  elsif v_kind = 'direct' then
    if v_peer_user_id is null or v_peer_user_id = v_user_id then
      raise exception 'Собеседник не найден';
    end if;
    if not exists (
      select 1
      from public.company_memberships membership
      where membership.company_id = v_company_id
        and membership.user_id = v_peer_user_id
        and membership.is_active
    ) then
      raise exception 'Сотрудник больше не состоит в компании';
    end if;
  else
    raise exception 'Неизвестный тип чата';
  end if;

  v_thread_key := public.company_chat_thread_key(
    v_kind,
    v_user_id,
    v_peer_user_id
  );

  return (
    select coalesce(jsonb_agg(to_jsonb(feed) order by feed.created_at, feed.id), '[]'::jsonb)
    from (
      select
        message.id,
        message.company_id,
        message.sender_user_id,
        message.sender_name,
        message.sender_role,
        message.kind,
        message.channel_kind,
        message.peer_user_id,
        message.thread_key,
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
      where message.company_id = v_company_id
        and message.thread_key = v_thread_key
        and (p_before is null or message.created_at < p_before)
        and public.can_view_company_chat_thread(
          message.company_id,
          message.channel_kind,
          message.sender_user_id,
          message.peer_user_id
        )
      order by message.created_at desc, message.id desc
      limit least(greatest(coalesce(p_limit, 100), 1), 200)
    ) feed
  );
end;
$$;

revoke all on function public.get_company_chat_feed(integer, timestamptz, text, uuid) from public;
grant execute on function public.get_company_chat_feed(integer, timestamptz, text, uuid) to authenticated;

drop function if exists public.create_company_chat_message(text, uuid, uuid[], text);
create function public.create_company_chat_message(
  p_body text,
  p_reply_to_id uuid default null,
  p_mentioned_user_ids uuid[] default '{}'::uuid[],
  p_client_nonce text default null,
  p_channel_kind text default 'general',
  p_peer_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_sender_name text := '';
  v_sender_role text := '';
  v_message_id uuid;
  v_mentions uuid[] := '{}'::uuid[];
  v_kind text := lower(btrim(coalesce(p_channel_kind, 'general')));
  v_peer_user_id uuid := p_peer_user_id;
  v_thread_key text;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется повторный вход';
  end if;
  if not public.current_user_has_permission('company_chat.send') then
    raise exception 'Нет права писать в чат';
  end if;
  if char_length(coalesce(p_body, '')) > 5000 then
    raise exception 'Сообщение длиннее 5000 символов';
  end if;

  if v_kind = 'general' then
    v_peer_user_id := null;
  elsif v_kind = 'assistant' then
    if not public.current_user_has_permission('ai.use') then
      raise exception 'Для этой роли ИИ-помощник отключён';
    end if;
    v_peer_user_id := v_user_id;
  elsif v_kind = 'direct' then
    if v_peer_user_id is null or v_peer_user_id = v_user_id then
      raise exception 'Собеседник не найден';
    end if;
    if not exists (
      select 1
      from public.company_memberships membership
      where membership.company_id = v_company_id
        and membership.user_id = v_peer_user_id
        and membership.is_active
    ) then
      raise exception 'Сотрудник больше не состоит в компании';
    end if;
  else
    raise exception 'Неизвестный тип чата';
  end if;

  v_thread_key := public.company_chat_thread_key(
    v_kind,
    v_user_id,
    v_peer_user_id
  );

  if p_reply_to_id is not null and not exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = v_company_id
      and message.id = p_reply_to_id
      and message.thread_key = v_thread_key
      and message.deleted_at is null
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
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

  if v_kind = 'general' then
    select coalesce(array_agg(distinct membership.user_id), '{}'::uuid[])
    into v_mentions
    from public.company_memberships membership
    where membership.company_id = v_company_id
      and membership.is_active
      and membership.user_id = any(coalesce(p_mentioned_user_ids, '{}'::uuid[]));
  end if;

  insert into public.company_chat_messages(
    company_id,
    sender_user_id,
    sender_name,
    sender_role,
    kind,
    channel_kind,
    peer_user_id,
    thread_key,
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
    v_kind,
    v_peer_user_id,
    v_thread_key,
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

revoke all on function public.create_company_chat_message(text, uuid, uuid[], text, text, uuid) from public;
grant execute on function public.create_company_chat_message(text, uuid, uuid[], text, text, uuid) to authenticated;

drop function if exists public.mark_company_chat_read(timestamptz);
create function public.mark_company_chat_read(
  p_read_at timestamptz default now(),
  p_channel_kind text default 'general',
  p_peer_user_id uuid default null
)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_read_at timestamptz := least(coalesce(p_read_at, now()), now());
  v_kind text := lower(btrim(coalesce(p_channel_kind, 'general')));
  v_peer_user_id uuid := p_peer_user_id;
  v_thread_key text;
begin
  if v_user_id is null or v_company_id is null then return; end if;
  if not public.current_user_has_permission('company_chat.view') then return; end if;

  if v_kind = 'general' then
    v_peer_user_id := null;
  elsif v_kind = 'assistant' then
    v_peer_user_id := v_user_id;
  elsif v_kind = 'direct' then
    if v_peer_user_id is null or v_peer_user_id = v_user_id then return; end if;
    if not exists (
      select 1
      from public.company_memberships membership
      where membership.company_id = v_company_id
        and membership.user_id = v_peer_user_id
        and membership.is_active
    ) then return; end if;
  else
    return;
  end if;

  v_thread_key := public.company_chat_thread_key(
    v_kind,
    v_user_id,
    v_peer_user_id
  );

  insert into public.company_chat_reads(company_id, user_id, thread_key, last_read_at, updated_at)
  values (v_company_id, v_user_id, v_thread_key, v_read_at, now())
  on conflict (company_id, user_id, thread_key) do update
  set last_read_at = greatest(public.company_chat_reads.last_read_at, excluded.last_read_at),
      updated_at = now();
end;
$$;

revoke all on function public.mark_company_chat_read(timestamptz, text, uuid) from public;
grant execute on function public.mark_company_chat_read(timestamptz, text, uuid) to authenticated;

create or replace function public.get_company_chat_unread_state()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  with identity as (
    select
      public.current_user_company_id() as company_id,
      (select auth.uid()) as user_id
  )
  select jsonb_build_object(
    'unread_count', count(*) filter (
      where message.deleted_at is null
        and message.sender_user_id is distinct from identity.user_id
        and message.created_at > coalesce(reads.last_read_at, '-infinity'::timestamptz)
    ),
    'mention_count', count(*) filter (
      where message.deleted_at is null
        and message.created_at > coalesce(reads.last_read_at, '-infinity'::timestamptz)
        and identity.user_id = any(message.mentioned_user_ids)
    ),
    'last_message_at', max(message.created_at)
  )
  from identity
  left join public.company_chat_messages message
    on message.company_id = identity.company_id
   and public.can_view_company_chat_thread(
     message.company_id,
     message.channel_kind,
     message.sender_user_id,
     message.peer_user_id
   )
  left join public.company_chat_reads reads
    on reads.company_id = identity.company_id
   and reads.user_id = identity.user_id
   and reads.thread_key = message.thread_key
  where identity.company_id is not null
    and identity.user_id is not null
    and public.current_user_has_permission('company_chat.view');
$$;

revoke all on function public.get_company_chat_unread_state() from public;
grant execute on function public.get_company_chat_unread_state() to authenticated;

create or replace function public.delete_company_chat_message(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
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
    and public.can_view_company_chat_thread(
      message.company_id,
      message.channel_kind,
      message.sender_user_id,
      message.peer_user_id
    )
    and (
      message.sender_user_id = v_user_id
      or (
        message.channel_kind = 'general'
        and public.current_user_has_permission('company_chat.moderate')
      )
    );

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.delete_company_chat_message(uuid) from public;
grant execute on function public.delete_company_chat_message(uuid) to authenticated;

drop policy if exists company_chat_messages_select on public.company_chat_messages;
create policy company_chat_messages_select
on public.company_chat_messages
for select
to authenticated
using (
  public.can_view_company_chat_thread(
    company_id,
    channel_kind,
    sender_user_id,
    peer_user_id
  )
);

drop policy if exists company_chat_attachments_select on public.company_chat_attachments;
create policy company_chat_attachments_select
on public.company_chat_attachments
for select
to authenticated
using (
  exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = company_chat_attachments.company_id
      and message.id = company_chat_attachments.message_id
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
  )
);

drop policy if exists company_chat_attachments_delete on public.company_chat_attachments;
create policy company_chat_attachments_delete
on public.company_chat_attachments
for delete
to authenticated
using (
  exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = company_chat_attachments.company_id
      and message.id = company_chat_attachments.message_id
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
      and (
        message.sender_user_id = (select auth.uid())
        or (
          message.channel_kind = 'general'
          and public.current_user_has_permission('company_chat.moderate')
        )
      )
  )
);

drop policy if exists company_chat_files_select on storage.objects;
create policy company_chat_files_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'company-chat-files'
  and (storage.foldername(name))[1] = public.current_user_company_id()::text
  and exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = public.current_user_company_id()
      and message.id::text = (storage.foldername(storage.objects.name))[2]
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
  )
);

drop policy if exists company_chat_files_delete on storage.objects;
create policy company_chat_files_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'company-chat-files'
  and (storage.foldername(name))[1] = public.current_user_company_id()::text
  and exists (
    select 1
    from public.company_chat_messages message
    where message.company_id = public.current_user_company_id()
      and message.id::text = (storage.foldername(storage.objects.name))[2]
      and public.can_view_company_chat_thread(
        message.company_id,
        message.channel_kind,
        message.sender_user_id,
        message.peer_user_id
      )
      and (
        message.sender_user_id = (select auth.uid())
        or (
          message.channel_kind = 'general'
          and public.current_user_has_permission('company_chat.moderate')
        )
      )
  )
);

commit;
