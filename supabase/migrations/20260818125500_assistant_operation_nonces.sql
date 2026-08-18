create table if not exists public.assistant_operation_nonces (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  nonce_hash text not null unique,
  scope text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists assistant_operation_nonces_lookup_idx
  on public.assistant_operation_nonces (nonce_hash, scope, expires_at)
  where used_at is null;

alter table public.assistant_operation_nonces enable row level security;

revoke all on public.assistant_operation_nonces from anon, authenticated;
comment on table public.assistant_operation_nonces is
  'Short-lived one-time nonces for protected server-side assistant operations. No client access.';
