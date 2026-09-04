create table if not exists public.accounting_counterparties (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  name text not null,
  inn text not null default '',
  kpp text not null default '',
  contract_number text not null default '',
  contract_date date,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists accounting_counterparties_company_name_idx
  on public.accounting_counterparties(company_id, name);

create table if not exists public.accounting_bank_transactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  operation_date date not null default current_date,
  direction text not null check (direction in ('in','out')),
  amount numeric(18,2) not null check (amount >= 0),
  counterparty_id uuid references public.accounting_counterparties(id) on delete set null,
  counterparty_name text not null default '',
  purpose text not null default '',
  bank_reference text not null default '',
  status text not null default 'new' check (status in ('new','matched','attention')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists accounting_bank_transactions_company_date_idx
  on public.accounting_bank_transactions(company_id, operation_date desc);

create table if not exists public.accounting_primary_documents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  document_type text not null check (document_type in ('purchase','sale')),
  document_number text not null default '',
  document_date date not null default current_date,
  counterparty_id uuid references public.accounting_counterparties(id) on delete set null,
  counterparty_name text not null default '',
  object_id uuid references public.objects(id) on delete set null,
  object_name text not null default '',
  amount numeric(18,2) not null default 0,
  vat_amount numeric(18,2) not null default 0,
  invoice_number text not null default '',
  invoice_date date,
  nomenclature text not null default '',
  comment text not null default '',
  status text not null default 'draft' check (status in ('draft','ready','posted','attention')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists accounting_primary_documents_company_date_idx
  on public.accounting_primary_documents(company_id, document_date desc);

create table if not exists public.accounting_document_files (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  document_id uuid not null references public.accounting_primary_documents(id) on delete cascade,
  bucket text not null default 'accounting-documents',
  file_path text not null,
  file_name text not null default '',
  content_type text not null default 'application/octet-stream',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists accounting_document_files_document_idx
  on public.accounting_document_files(document_id);

create table if not exists public.accounting_material_movements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  movement_date date not null default current_date,
  movement_type text not null default 'writeoff' check (movement_type in ('receipt','writeoff','adjustment')),
  object_id uuid references public.objects(id) on delete set null,
  object_name text not null default '',
  material_name text not null,
  quantity numeric(18,3) not null default 0,
  unit text not null default 'шт',
  amount numeric(18,2) not null default 0,
  document_number text not null default '',
  comment text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists accounting_material_movements_company_date_idx
  on public.accounting_material_movements(company_id, movement_date desc);

create table if not exists public.accounting_calendar_tasks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  due_date date not null,
  title text not null,
  kind text not null default 'other' check (kind in ('tax','report','salary','payment','other')),
  status text not null default 'open' check (status in ('open','done','cancelled')),
  comment text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists accounting_calendar_tasks_company_due_idx
  on public.accounting_calendar_tasks(company_id, due_date, status);

create table if not exists public.accounting_journal_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  entry_date date not null default current_date,
  document_number text not null default '',
  description text not null default '',
  status text not null default 'posted' check (status in ('draft','posted','cancelled')),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create index if not exists accounting_journal_entries_company_date_idx
  on public.accounting_journal_entries(company_id, entry_date desc);

create table if not exists public.accounting_journal_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  entry_id uuid not null references public.accounting_journal_entries(id) on delete cascade,
  account_code text not null,
  debit numeric(18,2) not null default 0 check (debit >= 0),
  credit numeric(18,2) not null default 0 check (credit >= 0),
  created_at timestamptz not null default now(),
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create index if not exists accounting_journal_lines_company_account_idx
  on public.accounting_journal_lines(company_id, account_code);
create index if not exists accounting_journal_lines_entry_idx
  on public.accounting_journal_lines(entry_id);

alter table public.accounting_counterparties enable row level security;
alter table public.accounting_bank_transactions enable row level security;
alter table public.accounting_primary_documents enable row level security;
alter table public.accounting_document_files enable row level security;
alter table public.accounting_material_movements enable row level security;
alter table public.accounting_calendar_tasks enable row level security;
alter table public.accounting_journal_entries enable row level security;
alter table public.accounting_journal_lines enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array[
    'accounting_counterparties',
    'accounting_bank_transactions',
    'accounting_primary_documents',
    'accounting_document_files',
    'accounting_material_movements',
    'accounting_calendar_tasks',
    'accounting_journal_entries'
  ] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))',
      t, t
    );
    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format(
      'create policy %I_insert on public.%I for insert with check (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))',
      t, t
    );
    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format(
      'create policy %I_update on public.%I for update using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text])) with check (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))',
      t, t
    );
    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format(
      'create policy %I_delete on public.%I for delete using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))',
      t, t
    );
  end loop;
end $$;

drop policy if exists accounting_journal_lines_read on public.accounting_journal_lines;
create policy accounting_journal_lines_read on public.accounting_journal_lines
for select using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
);

drop policy if exists accounting_journal_lines_insert on public.accounting_journal_lines;
create policy accounting_journal_lines_insert on public.accounting_journal_lines
for insert with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  and exists (
    select 1 from public.accounting_journal_entries e
    where e.id = entry_id and e.company_id = public.current_user_company_id()
  )
);

drop policy if exists accounting_journal_lines_update on public.accounting_journal_lines;
create policy accounting_journal_lines_update on public.accounting_journal_lines
for update using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
) with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  and exists (
    select 1 from public.accounting_journal_entries e
    where e.id = entry_id and e.company_id = public.current_user_company_id()
  )
);

drop policy if exists accounting_journal_lines_delete on public.accounting_journal_lines;
create policy accounting_journal_lines_delete on public.accounting_journal_lines
for delete using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
);

create or replace function public.get_accounting_trial_balance(
  p_start_date date,
  p_end_date date
)
returns table (
  account_code text,
  opening_debit numeric,
  opening_credit numeric,
  debit_turnover numeric,
  credit_turnover numeric,
  closing_debit numeric,
  closing_credit numeric
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with allowed as (
    select public.current_user_company_id() as company_id
    where public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  ),
  sums as (
    select
      l.account_code,
      coalesce(sum(case when e.entry_date < p_start_date then l.debit else 0 end),0) as opening_d,
      coalesce(sum(case when e.entry_date < p_start_date then l.credit else 0 end),0) as opening_c,
      coalesce(sum(case when e.entry_date between p_start_date and p_end_date then l.debit else 0 end),0) as turn_d,
      coalesce(sum(case when e.entry_date between p_start_date and p_end_date then l.credit else 0 end),0) as turn_c
    from public.accounting_journal_lines l
    join public.accounting_journal_entries e on e.id = l.entry_id
    join allowed a on a.company_id = l.company_id and a.company_id = e.company_id
    where e.status = 'posted' and e.entry_date <= p_end_date
    group by l.account_code
  )
  select
    s.account_code,
    greatest(s.opening_d - s.opening_c,0),
    greatest(s.opening_c - s.opening_d,0),
    s.turn_d,
    s.turn_c,
    greatest((s.opening_d + s.turn_d) - (s.opening_c + s.turn_c),0),
    greatest((s.opening_c + s.turn_c) - (s.opening_d + s.turn_d),0)
  from sums s
  order by s.account_code;
$$;

revoke all on function public.get_accounting_trial_balance(date,date) from public;
grant execute on function public.get_accounting_trial_balance(date,date) to authenticated;
