alter table public.recruitment_import_tokens
  add column if not exists processing_at timestamptz,
  add column if not exists processing_nonce uuid;

create or replace function public.claim_recruitment_import_token(
  p_token_hash text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nonce uuid := gen_random_uuid();
begin
  update public.recruitment_import_tokens token
  set processing_at = clock_timestamp(),
      processing_nonce = v_nonce
  where token.token_hash = btrim(coalesce(p_token_hash, ''))
    and token.purpose = 'candidate_documents'
    and token.used_at is null
    and token.expires_at > clock_timestamp()
    and (
      token.processing_at is null
      or token.processing_at < clock_timestamp() - interval '30 minutes'
    );
  if not found then return null; end if;
  return v_nonce;
end;
$$;

create or replace function public.complete_recruitment_import_token(
  p_token_hash text,
  p_processing_nonce uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.recruitment_import_tokens token
  set used_at = clock_timestamp(),
      processing_at = null,
      processing_nonce = null
  where token.token_hash = btrim(coalesce(p_token_hash, ''))
    and token.processing_nonce = p_processing_nonce
    and token.used_at is null;
  return found;
end;
$$;

create or replace function public.release_recruitment_import_token(
  p_token_hash text,
  p_processing_nonce uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.recruitment_import_tokens token
  set processing_at = null,
      processing_nonce = null
  where token.token_hash = btrim(coalesce(p_token_hash, ''))
    and token.processing_nonce = p_processing_nonce
    and token.used_at is null;
  return found;
end;
$$;

revoke all on function public.claim_recruitment_import_token(text)
  from public, anon, authenticated;
revoke all on function public.complete_recruitment_import_token(text,uuid)
  from public, anon, authenticated;
revoke all on function public.release_recruitment_import_token(text,uuid)
  from public, anon, authenticated;
grant execute on function public.claim_recruitment_import_token(text)
  to service_role;
grant execute on function public.complete_recruitment_import_token(text,uuid)
  to service_role;
grant execute on function public.release_recruitment_import_token(text,uuid)
  to service_role;
