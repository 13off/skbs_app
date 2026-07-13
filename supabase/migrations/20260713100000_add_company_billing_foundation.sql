create table public.billing_plans (
  code text primary key,
  name text not null,
  description text not null default '',
  monthly_price_rub integer,
  seat_limit integer not null,
  object_limit integer not null,
  features jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint billing_plans_code_check
    check (code in ('starter', 'business', 'enterprise')),
  constraint billing_plans_monthly_price_check
    check (monthly_price_rub is null or monthly_price_rub >= 0),
  constraint billing_plans_seat_limit_check
    check (seat_limit > 0),
  constraint billing_plans_object_limit_check
    check (object_limit > 0),
  constraint billing_plans_features_check
    check (jsonb_typeof(features) = 'array')
);

comment on table public.billing_plans is
  'Public product catalog for authenticated company administrators.';

alter table public.billing_plans enable row level security;

revoke all on table public.billing_plans from anon;
revoke all on table public.billing_plans from authenticated;
grant select on table public.billing_plans to authenticated;
grant all on table public.billing_plans to service_role;

create policy "authenticated users can view active billing plans"
on public.billing_plans
for select
to authenticated
using (is_active = true);

insert into public.billing_plans (
  code,
  name,
  description,
  monthly_price_rub,
  seat_limit,
  object_limit,
  features,
  is_active,
  sort_order
) values
  (
    'starter',
    'Старт',
    'Для небольшой компании или одной строительной бригады.',
    2990,
    10,
    5,
    '["Все рабочие функции", "До 10 пользователей", "До 5 объектов", "Поддержка по email"]'::jsonb,
    true,
    10
  ),
  (
    'business',
    'Бизнес',
    'Для нескольких объектов и растущей команды.',
    7990,
    30,
    20,
    '["Все рабочие функции", "До 30 пользователей", "До 20 объектов", "Приоритетная поддержка", "Помощь с запуском"]'::jsonb,
    true,
    20
  ),
  (
    'enterprise',
    'Корпоративный',
    'Для крупных подрядчиков и индивидуальных требований.',
    null,
    1000,
    1000,
    '["Все рабочие функции", "Индивидуальные лимиты", "Персональное сопровождение", "План внедрения"]'::jsonb,
    true,
    30
  );

create table public.company_plan_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null
    references public.companies(id) on delete cascade,
  requested_plan text not null
    references public.billing_plans(code) on update cascade,
  contact_name text not null default '',
  contact_email text not null,
  note text not null default '',
  status text not null default 'new',
  created_by uuid not null default auth.uid()
    references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint company_plan_requests_email_check
    check (position('@' in contact_email) > 1),
  constraint company_plan_requests_status_check
    check (status in ('new', 'contacted', 'activated', 'declined', 'canceled'))
);

comment on table public.company_plan_requests is
  'Sales requests submitted by administrators of the same company.';

create index company_plan_requests_company_created_idx
  on public.company_plan_requests (company_id, created_at desc);

create index company_plan_requests_created_by_idx
  on public.company_plan_requests (created_by);

create unique index company_plan_requests_one_open_idx
  on public.company_plan_requests (company_id)
  where status in ('new', 'contacted');

alter table public.company_plan_requests enable row level security;

revoke all on table public.company_plan_requests from anon;
revoke all on table public.company_plan_requests from authenticated;
grant select, insert on table public.company_plan_requests to authenticated;
grant all on table public.company_plan_requests to service_role;

create policy "company admins can view own plan requests"
on public.company_plan_requests
for select
to authenticated
using (public.is_company_admin(company_id));

create policy "company admins can create own plan requests"
on public.company_plan_requests
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.is_company_admin(company_id)
  and exists (
    select 1
    from public.billing_plans as plan
    where plan.code = requested_plan
      and plan.is_active = true
  )
);
