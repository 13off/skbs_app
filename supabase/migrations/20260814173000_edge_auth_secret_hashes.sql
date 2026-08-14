create table if not exists public.edge_auth_secret_hashes (
  name text primary key,
  secret_sha256 text not null,
  updated_at timestamptz not null default now(),
  constraint edge_auth_secret_hashes_name_check
    check (name in ('assistant_payment_receipts', 'recruitment_ingest')),
  constraint edge_auth_secret_hashes_value_check
    check (secret_sha256 ~ '^[0-9a-f]{64}$')
);

comment on table public.edge_auth_secret_hashes is
  'SHA-256 verifiers for internal Edge integrations. Plaintext shared secrets must not be stored here.';

alter table public.edge_auth_secret_hashes enable row level security;

revoke all on table public.edge_auth_secret_hashes from public;
revoke all on table public.edge_auth_secret_hashes from anon;
revoke all on table public.edge_auth_secret_hashes from authenticated;
revoke all on table public.edge_auth_secret_hashes from service_role;
grant select on table public.edge_auth_secret_hashes to service_role;
