drop policy if exists attendance_select_company_accountant
  on public.attendance;
drop policy if exists attendance_select_company_object
  on public.attendance;
create policy attendance_select_company_access
on public.attendance
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.can_access_object(object_name)
    or (select public.current_user_has_permission('accounting.attendance.view'))
  )
);

drop policy if exists employees_select_company_accountant
  on public.employees;
drop policy if exists employees_select_company_object
  on public.employees;
create policy employees_select_company_access
on public.employees
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.can_access_object(object_name)
    or (select public.current_user_has_permission('accounting.directory.view'))
  )
);

drop policy if exists payments_select_company_accountant
  on public.payments;
drop policy if exists payments_select_company_admin
  on public.payments;
create policy payments_select_company_access
on public.payments
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.payments.view'))
  )
);

drop policy if exists payments_insert_company_accountant
  on public.payments;
drop policy if exists payments_insert_company_admin
  on public.payments;
create policy payments_insert_company_access
on public.payments
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.payments.edit'))
  )
);

drop policy if exists payments_update_company_accountant
  on public.payments;
drop policy if exists payments_update_company_admin
  on public.payments;
create policy payments_update_company_access
on public.payments
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.payments.edit'))
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.payments.edit'))
  )
);

drop policy if exists payments_delete_company_accountant
  on public.payments;
drop policy if exists payments_delete_company_admin
  on public.payments;
create policy payments_delete_company_access
on public.payments
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.payments.edit'))
  )
);

drop policy if exists payment_receipts_select_company_accountant
  on public.payment_receipts;
drop policy if exists payment_receipts_select_company_admin
  on public.payment_receipts;
create policy payment_receipts_select_company_access
on public.payment_receipts
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.receipts.view'))
  )
);

drop policy if exists payment_receipts_insert_company_accountant
  on public.payment_receipts;
drop policy if exists payment_receipts_insert_company_admin
  on public.payment_receipts;
create policy payment_receipts_insert_company_access
on public.payment_receipts
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.receipts.edit'))
  )
  and exists (
    select 1
    from public.payments p
    where p.id = payment_receipts.payment_id
      and p.company_id = payment_receipts.company_id
  )
);

drop policy if exists payment_receipts_delete_company_accountant
  on public.payment_receipts;
drop policy if exists payment_receipts_delete_company_admin
  on public.payment_receipts;
create policy payment_receipts_delete_company_access
on public.payment_receipts
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    (select public.is_admin())
    or (select public.current_user_has_permission('accounting.receipts.edit'))
  )
);
