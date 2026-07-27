create table if not exists public.employee_max_links (
  company_id uuid not null references public.companies(id) on delete cascade,
  person_id uuid not null references private.people(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  max_user_id bigint not null,
  max_chat_id bigint,
  max_username text not null default '',
  source text not null default 'recruitment'
    check (source in ('recruitment', 'bot_contact', 'manual')),
  is_active boolean not null default true,
  linked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, person_id),
  unique (company_id, user_id),
  unique (company_id, max_user_id)
);

comment on table public.employee_max_links is
  'Серверная связь кабинета сотрудника с подтвержденным пользователем MAX для бесплатной доставки одноразовых кодов.';
comment on column public.employee_max_links.source is
  'Источник подтверждения: заявка кандидата MAX, контакт из бота или ручная серверная миграция.';

create index if not exists employee_max_links_phone_active_idx
  on public.employee_max_links (phone_e164)
  where is_active;

alter table public.employee_max_links enable row level security;
revoke all on public.employee_max_links from anon, authenticated;
grant all on public.employee_max_links to service_role;

create table if not exists public.employee_max_link_tokens (
  token_hash text primary key check (length(token_hash) = 64),
  company_id uuid not null references public.companies(id) on delete cascade,
  person_id uuid not null references private.people(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  expires_at timestamptz not null,
  used_at timestamptz,
  claimed_max_user_id bigint,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

comment on table public.employee_max_link_tokens is
  'Одноразовые токены для привязки карточки сотрудника к существующему боту СКБС Работа; хранится только SHA-256 хеш.';

create index if not exists employee_max_link_tokens_person_active_idx
  on public.employee_max_link_tokens (company_id, person_id, expires_at desc)
  where used_at is null;

alter table public.employee_max_link_tokens enable row level security;
revoke all on public.employee_max_link_tokens from anon, authenticated;
grant all on public.employee_max_link_tokens to service_role;
