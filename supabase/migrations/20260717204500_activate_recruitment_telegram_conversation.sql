create or replace function public.activate_recruitment_telegram_conversation(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_application public.recruitment_applications%rowtype;
  v_existing_draft jsonb := '{}'::jsonb;
  v_existing_user_id text := '';
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;

  if not public.current_user_has_permission('recruitment.messages.send') then
    raise exception 'Нет доступа к переписке кандидатов';
  end if;

  select *
    into v_application
  from public.recruitment_applications
  where id = p_application_id
    and company_id = public.current_user_company_id()
    and source = 'telegram'
    and coalesce(external_chat_id, '') <> '';

  if not found then
    raise exception 'Telegram-заявка не найдена';
  end if;

  select coalesce(draft, '{}'::jsonb), coalesce(external_user_id, '')
    into v_existing_draft, v_existing_user_id
  from public.recruitment_bot_sessions
  where source = 'telegram'
    and external_chat_id = v_application.external_chat_id;

  insert into public.recruitment_bot_sessions (
    source,
    external_chat_id,
    external_user_id,
    company_id,
    step,
    draft,
    application_id,
    updated_at
  )
  values (
    'telegram',
    v_application.external_chat_id,
    coalesce(
      nullif(v_application.external_user_id, ''),
      nullif(v_existing_user_id, ''),
      v_application.external_chat_id
    ),
    v_application.company_id,
    'submitted',
    coalesce(v_existing_draft, '{}'::jsonb)
      || jsonb_build_object('full_name', v_application.full_name),
    v_application.id,
    now()
  )
  on conflict (source, external_chat_id)
  do update set
    external_user_id = excluded.external_user_id,
    company_id = excluded.company_id,
    step = 'submitted',
    draft = coalesce(public.recruitment_bot_sessions.draft, '{}'::jsonb)
      || jsonb_build_object('full_name', v_application.full_name),
    application_id = excluded.application_id,
    updated_at = now();
end;
$$;

revoke all on function public.activate_recruitment_telegram_conversation(uuid)
  from public, anon;
grant execute on function public.activate_recruitment_telegram_conversation(uuid)
  to authenticated;
