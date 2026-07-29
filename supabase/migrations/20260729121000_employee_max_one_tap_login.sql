create table if not exists public.employee_max_login_attempts (
  id uuid primary key default gen_random_uuid(),
  client_token_hash text not null unique check (length(client_token_hash) = 64),
  confirm_token_hash text unique check (confirm_token_hash is null or length(confirm_token_hash) = 64),
  company_id uuid not null references public.companies(id) on delete cascade,
  person_id uuid not null references private.people(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  max_user_id bigint,
  state text not null default 'pending'
    check (state in ('linking', 'pending', 'code_ready', 'confirmed', 'session_ready', 'expired')),
  otp_ciphertext text,
  session_ciphertext text,
  confirmed_at timestamptz,
  session_ready_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at)
);

comment on table public.employee_max_login_attempts is
  'Короткоживущие попытки входа сотрудника через кнопку подтверждения в MAX. Клиентский и MAX-токены хранятся только как SHA-256.';
comment on column public.employee_max_login_attempts.otp_ciphertext is
  'OTP Supabase, зашифрованный AES-GCM ключом, производным от service role key; очищается после создания сессии.';
comment on column public.employee_max_login_attempts.session_ciphertext is
  'Короткоживущая зашифрованная Supabase-сессия для безопасного повторного получения приложением при сетевом сбое.';

create index if not exists employee_max_login_attempts_phone_pending_idx
  on public.employee_max_login_attempts (phone_e164, created_at desc)
  where state in ('linking', 'pending', 'code_ready', 'confirmed');

create index if not exists employee_max_login_attempts_expiry_idx
  on public.employee_max_login_attempts (expires_at);

alter table public.employee_max_login_attempts enable row level security;
revoke all on public.employee_max_login_attempts from anon, authenticated;
grant all on public.employee_max_login_attempts to service_role;

alter table public.employee_max_link_tokens
  add column if not exists login_attempt_id uuid
  references public.employee_max_login_attempts(id) on delete cascade;

create index if not exists employee_max_link_tokens_login_attempt_idx
  on public.employee_max_link_tokens (login_attempt_id)
  where login_attempt_id is not null and used_at is null;
