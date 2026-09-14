alter table public.accounting_counterparties
  add column if not exists entity_type text not null default 'legal_entity';

alter table public.accounting_counterparties
  drop constraint if exists accounting_counterparties_entity_type_check;
alter table public.accounting_counterparties
  add constraint accounting_counterparties_entity_type_check
  check (entity_type in ('legal_entity', 'individual'));

create unique index if not exists accounting_counterparties_company_name_uidx
  on public.accounting_counterparties (company_id, lower(btrim(name)));

drop policy if exists expense_categories_developer_insert
  on public.expense_categories;
drop policy if exists expense_categories_developer_update
  on public.expense_categories;
drop policy if exists expense_categories_developer_delete
  on public.expense_categories;
drop policy if exists expense_categories_write_insert
  on public.expense_categories;
drop policy if exists expense_categories_write_update
  on public.expense_categories;
drop policy if exists expense_categories_write_delete
  on public.expense_categories;

create policy expense_categories_write_insert
on public.expense_categories
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

create policy expense_categories_write_update
on public.expense_categories
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

create policy expense_categories_write_delete
on public.expense_categories
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists accounting_counterparties_read
  on public.accounting_counterparties;
drop policy if exists accounting_counterparties_insert
  on public.accounting_counterparties;
drop policy if exists accounting_counterparties_update
  on public.accounting_counterparties;
drop policy if exists accounting_counterparties_delete
  on public.accounting_counterparties;

create policy accounting_counterparties_read
on public.accounting_counterparties
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

create policy accounting_counterparties_insert
on public.accounting_counterparties
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

create policy accounting_counterparties_update
on public.accounting_counterparties
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

create policy accounting_counterparties_delete
on public.accounting_counterparties
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

comment on column public.accounting_counterparties.entity_type is
  'Тип контрагента: legal_entity — юридическое лицо, individual — физическое лицо.';
comment on table public.expense_categories is
  'Статьи расходов компании. Управляются из настроек расходов ролями admin, developer и accountant.';
