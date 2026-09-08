-- Accountant reuses the management People workspace for payroll and employee work.
-- Keep company/account administration restricted to admins, while allowing the
-- accountant to work with employee records, private data, documents and fines.

insert into public.role_permissions (role_code, permission_code)
values
  ('accountant', 'employees.create'),
  ('accountant', 'employees.edit'),
  ('accountant', 'employees.archive'),
  ('accountant', 'documents.workflow.view'),
  ('accountant', 'documents.onboarding.create'),
  ('accountant', 'documents.onboarding.edit')
on conflict do nothing;

-- The accountant works across all company objects, just like the accounting
-- directory already does for SELECT. These policies deliberately do not grant
-- employee deletion or company/access administration.
drop policy if exists employees_insert_company_accountant_workspace on public.employees;
create policy employees_insert_company_accountant_workspace
on public.employees
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and exists (
    select 1
    from public.objects object_row
    where object_row.id = employees.object_id
      and object_row.company_id = employees.company_id
      and object_row.is_active
  )
);

drop policy if exists employees_update_company_accountant_workspace on public.employees;
create policy employees_update_company_accountant_workspace
on public.employees
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and exists (
    select 1
    from public.objects object_row
    where object_row.id = employees.object_id
      and object_row.company_id = employees.company_id
      and object_row.is_active
  )
);

-- Employee private data: same-company accountant access only.
drop policy if exists employee_private_data_select_company_accountant on public.employee_private_data;
create policy employee_private_data_select_company_accountant
on public.employee_private_data
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled(company_id)
);

drop policy if exists employee_private_data_insert_company_accountant on public.employee_private_data;
create policy employee_private_data_insert_company_accountant
on public.employee_private_data
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled(company_id)
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.id = employee_private_data.employee_id
      and employee_row.company_id = employee_private_data.company_id
  )
);

drop policy if exists employee_private_data_update_company_accountant on public.employee_private_data;
create policy employee_private_data_update_company_accountant
on public.employee_private_data
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled(company_id)
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled(company_id)
);

drop policy if exists employee_private_data_delete_company_accountant on public.employee_private_data;
create policy employee_private_data_delete_company_accountant
on public.employee_private_data
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled(company_id)
);

-- Comments are part of the existing employee card workflow.
drop policy if exists employee_comments_select_company_accountant on public.employee_comments;
create policy employee_comments_select_company_accountant
on public.employee_comments
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
);

drop policy if exists employee_comments_insert_company_accountant on public.employee_comments;
create policy employee_comments_insert_company_accountant
on public.employee_comments
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.id = employee_comments.employee_id
      and employee_row.company_id = employee_comments.company_id
  )
);

drop policy if exists employee_comments_update_company_accountant on public.employee_comments;
create policy employee_comments_update_company_accountant
on public.employee_comments
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
)
with check (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
);

drop policy if exists employee_comments_delete_company_accountant on public.employee_comments;
create policy employee_comments_delete_company_accountant
on public.employee_comments
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.current_user_role() = 'accountant'
);

-- Legacy employee document screen stores files as employee_id/file.
drop policy if exists employee_documents_select_company_accountant on storage.objects;
create policy employee_documents_select_company_accountant
on storage.objects
for select
to authenticated
using (
  bucket_id = 'employee-documents'
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.company_id = (select public.current_user_company_id())
      and employee_row.id::text = (storage.foldername(objects.name))[1]
  )
);

drop policy if exists employee_documents_insert_company_accountant on storage.objects;
create policy employee_documents_insert_company_accountant
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'employee-documents'
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.company_id = (select public.current_user_company_id())
      and employee_row.id::text = (storage.foldername(objects.name))[1]
  )
);

drop policy if exists employee_documents_update_company_accountant on storage.objects;
create policy employee_documents_update_company_accountant
on storage.objects
for update
to authenticated
using (
  bucket_id = 'employee-documents'
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.company_id = (select public.current_user_company_id())
      and employee_row.id::text = (storage.foldername(objects.name))[1]
  )
)
with check (
  bucket_id = 'employee-documents'
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.company_id = (select public.current_user_company_id())
      and employee_row.id::text = (storage.foldername(objects.name))[1]
  )
);

drop policy if exists employee_documents_delete_company_accountant on storage.objects;
create policy employee_documents_delete_company_accountant
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'employee-documents'
  and public.current_user_role() = 'accountant'
  and public.document_tool_is_enabled((select public.current_user_company_id()))
  and exists (
    select 1
    from public.employees employee_row
    where employee_row.company_id = (select public.current_user_company_id())
      and employee_row.id::text = (storage.foldername(objects.name))[1]
  )
);

-- Manager-style fines are also exposed from the People action bar.
create or replace function public.can_access_absence_fine_storage(
  p_employee_id text,
  p_fine_id text,
  p_require_pending boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    auth.uid() is not null
    and (public.is_admin() or public.current_user_role() = 'accountant')
    and public.current_user_company_id() is not null
    and exists (
      select 1
      from public.absence_fines fine
      where fine.company_id = public.current_user_company_id()
        and fine.employee_id::text = btrim(coalesce(p_employee_id, ''))
        and fine.id::text = btrim(coalesce(p_fine_id, ''))
        and (not p_require_pending or fine.status = 'pending')
    );
$$;

create or replace function public.get_pending_absence_fines()
returns table(
  id uuid,
  employee_id uuid,
  employee_name text,
  object_name text,
  absence_date date,
  amount numeric,
  status text,
  explanation_file_name text,
  explanation_file_path text,
  explanation_content_type text,
  explanation_uploaded_at timestamptz,
  act_file_name text,
  act_file_path text,
  act_content_type text,
  act_uploaded_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    fine.id,
    fine.employee_id,
    coalesce(nullif(btrim(employee.fio), ''), 'Сотрудник'),
    coalesce(nullif(btrim(employee.object_name), ''), 'Без объекта'),
    fine.absence_date,
    fine.amount,
    fine.status,
    fine.explanation_file_name,
    fine.explanation_file_path,
    fine.explanation_content_type,
    fine.explanation_uploaded_at,
    fine.act_file_name,
    fine.act_file_path,
    fine.act_content_type,
    fine.act_uploaded_at,
    fine.created_at
  from public.absence_fines fine
  join public.employees employee
    on employee.id = fine.employee_id
   and employee.company_id = fine.company_id
  where auth.uid() is not null
    and (public.is_admin() or public.current_user_role() = 'accountant')
    and fine.company_id = public.current_user_company_id()
    and fine.status = 'pending'
  order by fine.absence_date desc, employee.fio;
$$;

create or replace function public.attach_absence_fine_explanation(
  p_fine_id uuid,
  p_file_name text,
  p_file_path text,
  p_content_type text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if auth.uid() is null or v_company_id is null
     or not (public.is_admin() or public.current_user_role() = 'accountant') then
    raise exception 'Недостаточно прав';
  end if;
  if btrim(coalesce(p_file_path, '')) = '' then
    raise exception 'Не указан файл объяснительной';
  end if;
  if not exists (
    select 1
    from storage.objects object_row
    join public.absence_fines fine on fine.id = p_fine_id
    where object_row.bucket_id = 'absence-explanations'
      and object_row.name = p_file_path
      and fine.company_id = v_company_id
      and fine.status = 'pending'
  ) then
    raise exception 'Файл объяснительной не найден в хранилище';
  end if;
  update public.absence_fines
  set explanation_file_name = left(btrim(coalesce(p_file_name, '')), 300),
      explanation_file_path = btrim(p_file_path),
      explanation_content_type = left(btrim(coalesce(p_content_type, '')), 120),
      explanation_uploaded_at = now(),
      explanation_uploaded_by = auth.uid(),
      updated_at = now()
  where id = p_fine_id and company_id = v_company_id and status = 'pending';
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

create or replace function public.attach_absence_fine_act(
  p_fine_id uuid,
  p_file_name text,
  p_file_path text,
  p_content_type text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if auth.uid() is null or v_company_id is null
     or not (public.is_admin() or public.current_user_role() = 'accountant') then
    raise exception 'Недостаточно прав';
  end if;
  if btrim(coalesce(p_file_path, '')) = '' then
    raise exception 'Не указан файл акта';
  end if;
  if not exists (
    select 1
    from storage.objects object_row
    join public.absence_fines fine on fine.id = p_fine_id
    where object_row.bucket_id = 'absence-fine-acts'
      and object_row.name = p_file_path
      and fine.company_id = v_company_id
      and fine.status = 'pending'
  ) then
    raise exception 'Файл акта не найден в хранилище';
  end if;
  update public.absence_fines
  set act_file_name = left(btrim(coalesce(p_file_name, '')), 300),
      act_file_path = btrim(p_file_path),
      act_content_type = left(btrim(coalesce(p_content_type, '')), 120),
      act_uploaded_at = now(),
      act_uploaded_by = auth.uid(),
      updated_at = now()
  where id = p_fine_id and company_id = v_company_id and status = 'pending';
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

create or replace function public.confirm_absence_fine(p_fine_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_fine public.absence_fines%rowtype;
  v_payment_id uuid;
begin
  if auth.uid() is null or v_company_id is null
     or not (public.is_admin() or public.current_user_role() = 'accountant') then
    raise exception 'Недостаточно прав';
  end if;

  select * into v_fine
  from public.absence_fines
  where id = p_fine_id and company_id = v_company_id
  for update;

  if not found then raise exception 'Штраф не найден'; end if;
  if v_fine.status = 'confirmed' and v_fine.payment_id is not null then
    return v_fine.payment_id;
  end if;
  if v_fine.status <> 'pending' then raise exception 'Штраф нельзя подтвердить'; end if;
  if btrim(coalesce(v_fine.explanation_file_path, '')) = '' then
    raise exception 'Сначала прикрепите скан объяснительной';
  end if;
  if btrim(coalesce(v_fine.act_file_path, '')) = '' then
    raise exception 'Сначала прикрепите подписанный акт о нарушении';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'absence-explanations' and name = v_fine.explanation_file_path
  ) then
    raise exception 'Скан объяснительной не найден';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'absence-fine-acts' and name = v_fine.act_file_path
  ) then
    raise exception 'Скан подписанного акта не найден';
  end if;

  insert into public.payments(
    company_id, employee_id, period_year, period_month,
    payment_date, amount, payment_type, comment, updated_at
  ) values (
    v_fine.company_id,
    v_fine.employee_id,
    extract(year from v_fine.absence_date)::integer,
    extract(month from v_fine.absence_date)::integer,
    current_date,
    10000,
    'fine',
    format(
      'Штраф за невыход %s. Объяснительная и подписанный акт приложены.',
      to_char(v_fine.absence_date, 'DD.MM.YYYY')
    ),
    now()
  ) returning id into v_payment_id;

  update public.absence_fines
  set status = 'confirmed',
      payment_id = v_payment_id,
      confirmed_at = now(),
      confirmed_by = auth.uid(),
      updated_at = now()
  where id = v_fine.id;

  return v_payment_id;
end;
$$;

create or replace function public.cancel_absence_fine(p_fine_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_fine public.absence_fines%rowtype;
begin
  if auth.uid() is null or v_company_id is null
     or not (public.is_admin() or public.current_user_role() = 'accountant') then
    raise exception 'Недостаточно прав';
  end if;

  select * into v_fine
  from public.absence_fines
  where id = p_fine_id and company_id = v_company_id
  for update;

  if not found then raise exception 'Штраф не найден'; end if;
  if v_fine.status = 'cancelled' then return true; end if;
  if v_fine.status <> 'pending' then raise exception 'Штраф нельзя отменить'; end if;
  if v_fine.payment_id is not null then
    raise exception 'Нельзя отменить штраф, уже связанный с выплатой';
  end if;

  update public.absence_fines
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      updated_at = now()
  where id = v_fine.id
    and company_id = v_company_id
    and status = 'pending';

  if not found then raise exception 'Штраф уже изменён другим пользователем'; end if;
  return true;
end;
$$;
