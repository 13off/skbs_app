alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;

alter table public.user_profiles
  add constraint user_profiles_role_check
  check (
    role = any (
      array[
        'admin'::text,
        'developer'::text,
        'foreman'::text,
        'employee'::text,
        'lawyer'::text,
        'accountant'::text,
        'hr'::text
      ]
    )
  );

create table public.employee_account_links (
  company_id uuid not null references public.companies(id) on delete cascade,
  person_id uuid not null references private.people(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  phone_e164 text not null,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (company_id, person_id),
  unique (company_id, user_id),
  constraint employee_account_links_phone_check
    check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$')
);

comment on table public.employee_account_links is
  'Отдельный контур доступа работников: связывает Auth-пользователя с постоянной записью человека, не добавляя его в корпоративные места тарифа.';
comment on column public.employee_account_links.person_id is
  'Постоянная личность сотрудника, объединяющая его записи на разных объектах.';
comment on column public.employee_account_links.user_id is
  'Телефонный Auth-пользователь, которому разрешён личный кабинет сотрудника.';

create index employee_account_links_user_active_idx
  on public.employee_account_links (user_id, is_active, company_id);

create index employee_account_links_phone_idx
  on public.employee_account_links (phone_e164);

alter table public.employee_account_links enable row level security;

revoke all on table public.employee_account_links from anon, authenticated;
