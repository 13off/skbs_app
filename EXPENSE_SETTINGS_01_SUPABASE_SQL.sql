begin;

alter table public.accounting_counterparties
  add column if not exists counterparty_type text not null default 'other';

update public.accounting_counterparties
set counterparty_type = 'other'
where counterparty_type is null or btrim(counterparty_type) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'accounting_counterparties_type_check'
      and conrelid = 'public.accounting_counterparties'::regclass
  ) then
    alter table public.accounting_counterparties
      add constraint accounting_counterparties_type_check
      check (
        counterparty_type in (
          'legal_entity',
          'individual_entrepreneur',
          'self_employed',
          'individual',
          'other'
        )
      );
  end if;
end
$$;

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
  and public.current_user_role() = any (
    array['admin'::text, 'developer'::text, 'accountant'::text]
  )
);

create policy expense_categories_write_update
on public.expense_categories
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (
    array['admin'::text, 'developer'::text, 'accountant'::text]
  )
)
with check (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (
    array['admin'::text, 'developer'::text, 'accountant'::text]
  )
);

create policy expense_categories_write_delete
on public.expense_categories
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() = any (
    array['admin'::text, 'developer'::text, 'accountant'::text]
  )
);

commit;
