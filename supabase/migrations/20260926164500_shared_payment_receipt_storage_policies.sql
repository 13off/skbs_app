drop policy if exists payment_receipts_storage_select_company_accountant
on storage.objects;
create policy payment_receipts_storage_select_company_accountant
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.current_user_has_permission('accounting.receipts.view')
  and exists (
    select 1
    from public.payment_receipts receipt
    where receipt.company_id = public.current_user_company_id()
      and receipt.file_path = objects.name
  )
);

drop policy if exists payment_receipts_storage_select_company_admin
on storage.objects;
create policy payment_receipts_storage_select_company_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.is_admin()
  and exists (
    select 1
    from public.payment_receipts receipt
    where receipt.company_id = public.current_user_company_id()
      and receipt.file_path = objects.name
  )
);

drop policy if exists payment_receipts_storage_delete_company_accountant
on storage.objects;
create policy payment_receipts_storage_delete_company_accountant
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.current_user_has_permission('accounting.receipts.edit')
  and exists (
    select 1
    from public.payment_receipts receipt
    where receipt.company_id = public.current_user_company_id()
      and receipt.file_path = objects.name
  )
);

drop policy if exists payment_receipts_storage_delete_company_admin
on storage.objects;
create policy payment_receipts_storage_delete_company_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.is_admin()
  and exists (
    select 1
    from public.payment_receipts receipt
    where receipt.company_id = public.current_user_company_id()
      and receipt.file_path = objects.name
  )
);
