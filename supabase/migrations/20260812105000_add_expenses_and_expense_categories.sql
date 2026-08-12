create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  sort_order integer not null default 0,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists expense_categories_company_name_uidx
  on public.expense_categories (company_id, lower(btrim(name)));
create index if not exists expense_categories_company_sort_idx
  on public.expense_categories (company_id, sort_order, name);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  category_id uuid references public.expense_categories(id) on delete set null,
  object_id uuid references public.objects(id) on delete set null,
  name text not null check (length(btrim(name)) > 0),
  amount numeric(14,2) not null check (amount > 0),
  expense_date date not null default current_date,
  comment text not null default '',
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  updated_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists expenses_company_date_idx
  on public.expenses (company_id, expense_date desc);
create index if not exists expenses_company_category_idx
  on public.expenses (company_id, category_id);
create index if not exists expenses_company_object_idx
  on public.expenses (company_id, object_id);

create or replace function public.touch_expenses_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  if tg_table_name = 'expenses' then
    new.updated_by = auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists expense_categories_touch_updated_at on public.expense_categories;
create trigger expense_categories_touch_updated_at
before update on public.expense_categories
for each row execute function public.touch_expenses_updated_at();

drop trigger if exists expenses_touch_updated_at on public.expenses;
create trigger expenses_touch_updated_at
before update on public.expenses
for each row execute function public.touch_expenses_updated_at();

alter table public.expense_categories enable row level security;
alter table public.expenses enable row level security;

grant select, insert, update, delete on public.expense_categories to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;

drop policy if exists expense_categories_read on public.expense_categories;
create policy expense_categories_read
on public.expense_categories
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists expense_categories_developer_insert on public.expense_categories;
create policy expense_categories_developer_insert
on public.expense_categories
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() = 'developer'
);

drop policy if exists expense_categories_developer_update on public.expense_categories;
create policy expense_categories_developer_update
on public.expense_categories
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = 'developer'
)
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() = 'developer'
);

drop policy if exists expense_categories_developer_delete on public.expense_categories;
create policy expense_categories_developer_delete
on public.expense_categories
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = 'developer'
);

drop policy if exists expenses_read on public.expenses;
create policy expenses_read
on public.expenses
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists expenses_write_insert on public.expenses;
create policy expenses_write_insert
on public.expenses
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists expenses_write_update on public.expenses;
create policy expenses_write_update
on public.expenses
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
)
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists expenses_write_delete on public.expenses;
create policy expenses_write_delete
on public.expenses
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

comment on table public.expense_categories is 'Статьи расходов компании. Изменяются только ролью developer.';
comment on table public.expenses is 'Ручные расходы компании. Выплаты сотрудникам остаются в payments и объединяются на уровне приложения.';
