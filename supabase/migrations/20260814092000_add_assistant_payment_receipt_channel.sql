alter table public.payment_receipts
  add column if not exists upload_source text not null default 'app';

alter table public.payment_receipts
  drop constraint if exists payment_receipts_upload_source_check;
alter table public.payment_receipts
  add constraint payment_receipts_upload_source_check
  check (upload_source in ('app', 'assistant'));

comment on column public.payment_receipts.upload_source is
  'Источник загрузки чека: app — пользователь AppСтрой, assistant — защищённый служебный канал ChatGPT.';

create schema if not exists private;

create or replace function private.assistant_payment_receipt_request(p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = private, public, extensions, vault, pg_temp
as $$
declare
  v_url text;
  v_secret text;
  v_response extensions.http_response;
  v_result jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'assistant_payment_receipt_edge_url'
  order by created_at desc
  limit 1;

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'assistant_payment_receipt_secret'
  order by created_at desc
  limit 1;

  if coalesce(v_url, '') = '' or coalesce(v_secret, '') = '' then
    raise exception 'Assistant payment receipt channel is not configured';
  end if;

  select * into v_response
  from extensions.http((
    'POST'::extensions.http_method,
    v_url,
    array[
      row('x-assistant-secret', v_secret)::extensions.http_header,
      row('accept', 'application/json')::extensions.http_header
    ],
    'application/json',
    p_body::text
  )::extensions.http_request);

  begin
    v_result := coalesce(v_response.content, '{}')::jsonb;
  exception when others then
    raise exception 'Assistant payment receipt channel returned non-JSON response (HTTP %)', v_response.status;
  end;

  if v_response.status < 200 or v_response.status >= 300 then
    raise exception 'Assistant payment receipt channel failed (HTTP %): %',
      v_response.status,
      coalesce(v_result->>'error', v_response.content);
  end if;

  return v_result;
end;
$$;

create or replace function private.assistant_add_payment_receipt(
  p_payment_id uuid,
  p_file_name text,
  p_content_type text,
  p_file_base64 text
)
returns jsonb
language sql
security definer
set search_path = private, public, pg_temp
as $$
  select private.assistant_payment_receipt_request(
    jsonb_build_object(
      'action', 'upload',
      'payment_id', p_payment_id,
      'file_name', p_file_name,
      'content_type', p_content_type,
      'file_base64', p_file_base64
    )
  );
$$;

create or replace function private.assistant_get_payment_receipt_download(p_receipt_id uuid)
returns jsonb
language sql
security definer
set search_path = private, public, pg_temp
as $$
  select private.assistant_payment_receipt_request(
    jsonb_build_object('action', 'signed_download', 'receipt_id', p_receipt_id)
  );
$$;

revoke all on function private.assistant_payment_receipt_request(jsonb) from public, anon, authenticated;
revoke all on function private.assistant_add_payment_receipt(uuid, text, text, text) from public, anon, authenticated;
revoke all on function private.assistant_get_payment_receipt_download(uuid) from public, anon, authenticated;
