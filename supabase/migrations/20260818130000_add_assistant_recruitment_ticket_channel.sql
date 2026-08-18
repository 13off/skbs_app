create or replace function private.assistant_recruitment_ticket_request(p_body jsonb)
returns jsonb
language plpgsql
security definer
set search_path = 'private', 'public', 'extensions', 'vault', 'pg_temp'
as $$
declare
  v_url text;
  v_company_id uuid;
  v_nonce text;
  v_response extensions.http_response;
  v_result jsonb;
begin
  v_company_id := nullif(p_body->>'company_id', '')::uuid;
  if v_company_id is null then
    select company_id into v_company_id
    from public.recruitment_applications
    where id = nullif(p_body->>'application_id', '')::uuid;
  end if;

  if v_company_id is null then
    raise exception 'Recruitment application/company not found';
  end if;

  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'assistant_recruitment_ticket_edge_url'
  order by created_at desc
  limit 1;

  if coalesce(v_url, '') = '' then
    raise exception 'Assistant recruitment ticket channel is not configured';
  end if;

  v_nonce := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.assistant_operation_nonces(
    company_id,
    nonce_hash,
    scope,
    expires_at
  ) values (
    v_company_id,
    encode(extensions.digest(v_nonce, 'sha256'), 'hex'),
    'recruitment_ticket_upload',
    now() + interval '5 minutes'
  );

  p_body := p_body || jsonb_build_object('nonce', v_nonce);

  select * into v_response
  from extensions.http((
    'POST'::extensions.http_method,
    v_url,
    array[row('accept', 'application/json')::extensions.http_header],
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

create or replace function private.assistant_create_recruitment_flight(
  p_application_id uuid,
  p_departure_at timestamptz,
  p_arrival_at timestamptz,
  p_origin text,
  p_destination text,
  p_flight_number text,
  p_file_name text,
  p_file_base64 text,
  p_notes text default '',
  p_object_id uuid default null,
  p_stage_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = 'private', 'public', 'pg_temp'
as $$
  select private.assistant_recruitment_ticket_request(
    jsonb_strip_nulls(jsonb_build_object(
      'action', 'create_flight',
      'application_id', p_application_id,
      'departure_at', p_departure_at,
      'arrival_at', p_arrival_at,
      'origin', p_origin,
      'destination', p_destination,
      'flight_number', p_flight_number,
      'file_name', p_file_name,
      'content_type', 'application/pdf',
      'file_base64', p_file_base64,
      'notes', coalesce(p_notes, ''),
      'object_id', p_object_id,
      'stage_id', p_stage_id
    ))
  );
$$;

create or replace function private.assistant_attach_recruitment_ticket(
  p_application_id uuid,
  p_flight_id uuid,
  p_file_name text,
  p_file_base64 text
)
returns jsonb
language sql
security definer
set search_path = 'private', 'public', 'pg_temp'
as $$
  select private.assistant_recruitment_ticket_request(
    jsonb_build_object(
      'action', 'attach_ticket',
      'application_id', p_application_id,
      'flight_id', p_flight_id,
      'file_name', p_file_name,
      'content_type', 'application/pdf',
      'file_base64', p_file_base64
    )
  );
$$;

revoke all on function private.assistant_recruitment_ticket_request(jsonb) from public, anon, authenticated;
revoke all on function private.assistant_create_recruitment_flight(uuid,timestamptz,timestamptz,text,text,text,text,text,text,uuid,uuid) from public, anon, authenticated;
revoke all on function private.assistant_attach_recruitment_ticket(uuid,uuid,text,text) from public, anon, authenticated;
