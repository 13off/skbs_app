drop policy if exists expense_categories_manage_insert
  on public.expense_categories;
drop policy if exists expense_categories_manage_update
  on public.expense_categories;
drop policy if exists expense_categories_manage_delete
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
