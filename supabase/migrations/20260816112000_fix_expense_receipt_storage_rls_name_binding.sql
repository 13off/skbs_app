-- Fix expense receipt Storage RLS.
-- Inside the EXISTS subquery, unqualified `name` bound to expenses.name
-- instead of storage.objects.name, so valid uploads were rejected.

drop policy if exists expense_receipts_storage_select on storage.objects;
create policy expense_receipts_storage_select on storage.objects
for select to authenticated
using (
  bucket_id = 'expense-receipts'
  and public.current_user_role() in ('admin', 'developer', 'accountant')
  and (storage.foldername(storage.objects.name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.expenses expense_row
    where expense_row.company_id = public.current_user_company_id()
      and expense_row.id::text = (storage.foldername(storage.objects.name))[2]
  )
);

drop policy if exists expense_receipts_storage_insert on storage.objects;
create policy expense_receipts_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'expense-receipts'
  and public.current_user_role() in ('admin', 'developer', 'accountant')
  and (storage.foldername(storage.objects.name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.expenses expense_row
    where expense_row.company_id = public.current_user_company_id()
      and expense_row.id::text = (storage.foldername(storage.objects.name))[2]
  )
);

drop policy if exists expense_receipts_storage_delete on storage.objects;
create policy expense_receipts_storage_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'expense-receipts'
  and public.current_user_role() in ('admin', 'developer', 'accountant')
  and (storage.foldername(storage.objects.name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.expenses expense_row
    where expense_row.company_id = public.current_user_company_id()
      and expense_row.id::text = (storage.foldername(storage.objects.name))[2]
  )
);
