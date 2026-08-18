create or replace function private.assistant_recruitment_ticket_request(p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = 'private', 'public', 'extensions', 'vault', 'pg_temp'
as $$
declare
  v_url text;
  v_secret text;
  v_response extensions.http_response;
  v_result jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'assistant_recruitment_ticket_edge_url'
  order by created_at desc
  limit 1;

  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'assistant_recruitment_ticket_secret'
  order by created_at desc
  limit 1;

  if coalesce(v_url, '') = '' or coalesce(v_secret, '') = '' then
    raise exception 'Assistant recruitment ticket channel is not configured';
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
    raise exception 'Assistant recruitment ticket channel returned non-JSON response (HTTP %)', v_response.status;
  end;

  if v_response.status < 200 or v_response.status >= 300 then
    raise exception 'Assistant recruitment ticket channel failed (HTTP %): %',
      v_response.status,
      coalesce(v_result->>'error', v_response.content);
  end if;

  return v_result;
end;
$$;

revoke all on function private.assistant_recruitment_ticket_request(jsonb) from public, anon, authenticated;
