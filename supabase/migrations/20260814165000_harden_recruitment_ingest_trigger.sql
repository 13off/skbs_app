create or replace function private.queue_recruitment_telegram_file_ingest()
returns trigger
language plpgsql
security definer
set search_path = public, net, vault, pg_temp
as $$
declare
  v_entity_kind text;
  v_secret text;
begin
  if coalesce(new.telegram_file_id, '') = '' then
    return new;
  end if;

  if coalesce(new.storage_bucket, '') = 'recruitment-documents'
     and coalesce(new.storage_path, '') <> ''
     and new.storage_path not like 'telegram://%' then
    return new;
  end if;

  select decrypted_secret
  into v_secret
  from vault.decrypted_secrets
  where name = 'recruitment_ingest_secret'
  order by created_at desc
  limit 1;

  if coalesce(v_secret, '') = '' then
    raise warning 'Recruitment ingest secret is not configured; queue request skipped';
    return new;
  end if;

  v_entity_kind := case when tg_table_name = 'recruitment_documents'
    then 'document' else 'message' end;

  perform net.http_post(
    url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/recruitment-ingest-telegram-file',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-recruitment-ingest-secret', v_secret
    ),
    body := jsonb_build_object('kind', v_entity_kind, 'id', new.id),
    timeout_milliseconds := 15000
  );

  return new;
end;
$$;

revoke all on function private.queue_recruitment_telegram_file_ingest()
  from public, anon, authenticated;
