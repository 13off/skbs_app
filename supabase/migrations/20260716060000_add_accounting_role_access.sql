insert into public.role_permissions (role_code, permission_code)
values
  ('owner', 'accounting.directory.view'),
  ('owner', 'accounting.attendance.view'),
  ('owner', 'accounting.payments.view'),
  ('owner', 'accounting.payments.edit'),
  ('owner', 'accounting.receipts.view'),
  ('owner', 'accounting.receipts.edit'),
  ('owner', 'accounting.reports.export'),
  ('admin', 'accounting.directory.view'),
  ('admin', 'accounting.attendance.view'),
  ('admin', 'accounting.payments.view'),
  ('admin', 'accounting.payments.edit'),
  ('admin', 'accounting.receipts.view'),
  ('admin', 'accounting.receipts.edit'),
  ('admin', 'accounting.reports.export'),
  ('accountant', 'accounting.directory.view'),
  ('accountant', 'accounting.attendance.view'),
  ('accountant', 'accounting.payments.view'),
  ('accountant', 'accounting.payments.edit'),
  ('accountant', 'accounting.receipts.view'),
  ('accountant', 'accounting.receipts.edit'),
  ('accountant', 'accounting.reports.export')
on conflict (role_code, permission_code) do nothing;

create policy employees_select_company_accountant
on public.employees
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.directory.view')
);

create policy attendance_select_company_accountant
on public.attendance
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.attendance.view')
);

create policy payments_select_company_accountant
on public.payments
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.payments.view')
);

create policy payments_insert_company_accountant
on public.payments
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.payments.edit')
  and exists (
    select 1
    from public.employees employee
    where employee.id = payments.employee_id
      and employee.company_id = payments.company_id
  )
);

create policy payments_update_company_accountant
on public.payments
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.payments.edit')
)
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.payments.edit')
);

create policy payments_delete_company_accountant
on public.payments
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.payments.edit')
);

create policy payment_receipts_select_company_accountant
on public.payment_receipts
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.receipts.view')
);

create policy payment_receipts_insert_company_accountant
on public.payment_receipts
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.receipts.edit')
  and exists (
    select 1
    from public.payments payment
    where payment.id = payment_receipts.payment_id
      and payment.company_id = payment_receipts.company_id
      and (
        payment_receipts.employee_id is null
        or payment.employee_id = payment_receipts.employee_id
      )
  )
);

create policy payment_receipts_delete_company_accountant
on public.payment_receipts
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('accounting.receipts.edit')
);

create policy payment_receipts_storage_select_company_accountant
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.current_user_has_permission('accounting.receipts.view')
  and exists (
    select 1
    from public.payments payment
    join public.employees employee
      on employee.id = payment.employee_id
     and employee.company_id = payment.company_id
    where payment.company_id = public.current_user_company_id()
      and employee.id::text = (storage.foldername(objects.name))[1]
      and payment.id::text = (storage.foldername(objects.name))[2]
  )
);

create policy payment_receipts_storage_insert_company_accountant
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'payment-receipts'
  and public.current_user_has_permission('accounting.receipts.edit')
  and exists (
    select 1
    from public.payments payment
    join public.employees employee
      on employee.id = payment.employee_id
     and employee.company_id = payment.company_id
    where payment.company_id = public.current_user_company_id()
      and employee.id::text = (storage.foldername(objects.name))[1]
      and payment.id::text = (storage.foldername(objects.name))[2]
  )
);

create policy payment_receipts_storage_delete_company_accountant
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'payment-receipts'
  and public.current_user_has_permission('accounting.receipts.edit')
  and exists (
    select 1
    from public.payments payment
    join public.employees employee
      on employee.id = payment.employee_id
     and employee.company_id = payment.company_id
    where payment.company_id = public.current_user_company_id()
      and employee.id::text = (storage.foldername(objects.name))[1]
      and payment.id::text = (storage.foldername(objects.name))[2]
  )
);
