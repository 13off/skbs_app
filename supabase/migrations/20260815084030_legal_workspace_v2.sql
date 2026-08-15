-- Единая юридическая база: сотрудники, объекты, документы, акты и взыскания.
-- Все RPC жёстко ограничены текущей компанией и юридическими правами пользователя.

create or replace function public.legal_workspace_employee_directory()
returns table(
  id uuid,
  fio text,
  "position" text,
  object_id uuid,
  object_name text,
  is_active boolean,
  documents_count bigint,
  contracts_count bigint,
  acts_count bigint,
  matters_count bigint,
  fines_count bigint,
  pending_fines_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not (
    public.current_user_has_permission('legal.directory.view') or public.is_admin()
  ) then
    raise exception 'Нет доступа к юридической базе сотрудников';
  end if;

  return query
  select
    e.id,
    e.fio,
    coalesce(e.position, ''),
    e.object_id,
    coalesce(o.name, e.object_name, ''),
    coalesce(e.is_active, true),
    (
      (select count(*) from public.legal_documents d
       where d.company_id = e.company_id and d.employee_id = e.id and d.archived_at is null)
      +
      (select count(*) from public.employee_document_files f
       where f.company_id = e.company_id and f.employee_id = e.id)
      +
      (select count(*) from public.absence_fines af
       where af.company_id = e.company_id and af.employee_id = e.id
         and (nullif(af.act_file_path, '') is not null or nullif(af.explanation_file_path, '') is not null))
    )::bigint as documents_count,
    (
      select count(*) from public.legal_documents d
      where d.company_id = e.company_id and d.employee_id = e.id and d.archived_at is null
        and (lower(d.document_type) like '%договор%' or lower(d.document_type) like '%contract%'
             or lower(d.title) like '%договор%' or lower(d.title) like '%contract%')
    )::bigint as contracts_count,
    (
      (select count(*) from public.legal_documents d
       where d.company_id = e.company_id and d.employee_id = e.id and d.archived_at is null
         and (lower(d.document_type) like '%акт%' or lower(d.title) like '%акт%' or lower(d.document_type) = 'act'))
      +
      (select count(*) from public.absence_fines af
       where af.company_id = e.company_id and af.employee_id = e.id and nullif(af.act_file_path, '') is not null)
    )::bigint as acts_count,
    (select count(*) from public.legal_matters m
     where m.company_id = e.company_id and m.employee_id = e.id)::bigint as matters_count,
    (select count(*) from public.absence_fines af
     where af.company_id = e.company_id and af.employee_id = e.id)::bigint as fines_count,
    (select count(*) from public.absence_fines af
     where af.company_id = e.company_id and af.employee_id = e.id and af.status = 'pending')::bigint as pending_fines_count
  from public.employees e
  left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
  where e.company_id = public.current_user_company_id()
    and e.archived_at is null
  order by e.fio;
end;
$$;

create or replace function public.legal_workspace_object_directory()
returns table(
  id uuid,
  name text,
  address text,
  is_active boolean,
  employees_count bigint,
  contracts_count bigint,
  acts_count bigint,
  matters_count bigint,
  open_matters_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not (
    public.current_user_has_permission('legal.directory.view') or public.is_admin()
  ) then
    raise exception 'Нет доступа к юридической базе объектов';
  end if;

  return query
  select
    o.id,
    o.name,
    coalesce(o.address, ''),
    o.is_active,
    (select count(*) from public.employees e
     where e.company_id = o.company_id and e.object_id = o.id and e.archived_at is null)::bigint,
    (select count(*) from public.legal_documents d
     where d.company_id = o.company_id and d.object_id = o.id and d.archived_at is null
       and (lower(d.document_type) like '%договор%' or lower(d.document_type) like '%contract%'
            or lower(d.title) like '%договор%' or lower(d.title) like '%contract%'))::bigint,
    (select count(*) from public.legal_documents d
     where d.company_id = o.company_id and d.object_id = o.id and d.archived_at is null
       and (lower(d.document_type) like '%акт%' or lower(d.title) like '%акт%' or lower(d.document_type) = 'act'))::bigint,
    (select count(*) from public.legal_matters m
     where m.company_id = o.company_id and m.object_id = o.id)::bigint,
    (select count(*) from public.legal_matters m
     where m.company_id = o.company_id and m.object_id = o.id and m.status not in ('resolved', 'closed'))::bigint
  from public.objects o
  where o.company_id = public.current_user_company_id()
  order by o.is_active desc, o.name;
end;
$$;

create or replace function public.legal_workspace_documents(
  p_employee_id uuid default null,
  p_object_id uuid default null,
  p_category text default null
)
returns table(
  source_type text,
  source_id uuid,
  employee_id uuid,
  employee_name text,
  object_id uuid,
  object_name text,
  title text,
  category text,
  document_type text,
  status text,
  file_name text,
  bucket_name text,
  storage_path text,
  document_date timestamptz,
  legal_document_id uuid
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not (
    public.current_user_has_permission('legal.directory.view') or
    public.current_user_has_permission('legal.documents.view') or
    public.is_admin()
  ) then
    raise exception 'Нет доступа к юридическим документам';
  end if;

  return query
  with docs as (
    select
      'legal_document'::text as source_type,
      d.id as source_id,
      d.employee_id,
      coalesce(e.fio, '') as employee_name,
      d.object_id,
      coalesce(o.name, '') as object_name,
      d.title,
      case
        when lower(d.document_type) like '%договор%' or lower(d.document_type) like '%contract%'
          or lower(d.title) like '%договор%' or lower(d.title) like '%contract%' then 'contract'
        when lower(d.document_type) like '%акт%' or lower(d.title) like '%акт%' or lower(d.document_type) = 'act' then 'act'
        else 'document'
      end::text as category,
      d.document_type,
      d.status,
      coalesce(f.original_name, '') as file_name,
      coalesce(f.bucket_name, '') as bucket_name,
      coalesce(f.storage_path, '') as storage_path,
      d.created_at as document_date,
      d.id as legal_document_id
    from public.legal_documents d
    left join public.employees e on e.id = d.employee_id and e.company_id = d.company_id
    left join public.objects o on o.id = d.object_id and o.company_id = d.company_id
    left join lateral (
      select af.original_name, af.bucket_name, af.storage_path
      from public.legal_document_files ldf
      join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
      where ldf.document_id = d.id and ldf.company_id = d.company_id
      order by ldf.is_primary desc, ldf.created_at desc
      limit 1
    ) f on true
    where d.company_id = public.current_user_company_id() and d.archived_at is null

    union all

    select
      'employee_document'::text,
      edf.id,
      edf.employee_id,
      coalesce(e.fio, ''),
      e.object_id,
      coalesce(o.name, e.object_name, ''),
      coalesce(nullif(edf.original_file_name, ''), edf.document_type, 'Документ сотрудника'),
      case
        when lower(edf.document_type) like '%договор%' or lower(edf.document_type) like '%contract%'
          or lower(edf.file_kind) like '%договор%' or lower(edf.file_kind) like '%contract%' then 'contract'
        when lower(edf.document_type) like '%акт%' or lower(edf.file_kind) like '%акт%' or lower(edf.document_type) = 'act' then 'act'
        else 'employee_document'
      end::text,
      edf.document_type,
      edf.verification_status,
      edf.original_file_name,
      edf.storage_bucket,
      edf.storage_path,
      edf.created_at,
      null::uuid
    from public.employee_document_files edf
    join public.employees e on e.id = edf.employee_id and e.company_id = edf.company_id
    left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
    where edf.company_id = public.current_user_company_id()

    union all

    select
      'absence_fine_act'::text,
      af.id,
      af.employee_id,
      coalesce(e.fio, ''),
      e.object_id,
      coalesce(o.name, e.object_name, ''),
      'Акт о невыходе — ' || to_char(af.absence_date, 'DD.MM.YYYY'),
      'act'::text,
      'absence_fine_act'::text,
      af.status,
      coalesce(af.act_file_name, ''),
      'absence-fine-acts'::text,
      coalesce(af.act_file_path, ''),
      coalesce(af.act_uploaded_at, af.created_at),
      null::uuid
    from public.absence_fines af
    join public.employees e on e.id = af.employee_id and e.company_id = af.company_id
    left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
    where af.company_id = public.current_user_company_id() and nullif(af.act_file_path, '') is not null

    union all

    select
      'absence_explanation'::text,
      af.id,
      af.employee_id,
      coalesce(e.fio, ''),
      e.object_id,
      coalesce(o.name, e.object_name, ''),
      'Объяснительная о невыходе — ' || to_char(af.absence_date, 'DD.MM.YYYY'),
      'explanation'::text,
      'absence_explanation'::text,
      af.status,
      coalesce(af.explanation_file_name, ''),
      'absence-explanations'::text,
      coalesce(af.explanation_file_path, ''),
      coalesce(af.explanation_uploaded_at, af.created_at),
      null::uuid
    from public.absence_fines af
    join public.employees e on e.id = af.employee_id and e.company_id = af.company_id
    left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
    where af.company_id = public.current_user_company_id() and nullif(af.explanation_file_path, '') is not null
  )
  select d.*
  from docs d
  where (p_employee_id is null or d.employee_id = p_employee_id)
    and (p_object_id is null or d.object_id = p_object_id)
    and (p_category is null or btrim(p_category) = '' or d.category = p_category)
  order by d.document_date desc nulls last, d.title;
end;
$$;

create or replace function public.legal_workspace_recoveries()
returns table(
  id uuid,
  employee_id uuid,
  employee_name text,
  object_id uuid,
  object_name text,
  absence_date date,
  amount numeric,
  status text,
  act_file_name text,
  act_file_path text,
  explanation_file_name text,
  explanation_file_path text,
  created_at timestamptz,
  confirmed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not (
    public.current_user_has_permission('legal.directory.view') or
    public.current_user_has_permission('legal.matters.view') or
    public.is_admin()
  ) then
    raise exception 'Нет доступа к взысканиям';
  end if;

  return query
  select
    af.id,
    af.employee_id,
    e.fio,
    e.object_id,
    coalesce(o.name, e.object_name, ''),
    af.absence_date,
    af.amount,
    af.status,
    coalesce(af.act_file_name, ''),
    coalesce(af.act_file_path, ''),
    coalesce(af.explanation_file_name, ''),
    coalesce(af.explanation_file_path, ''),
    af.created_at,
    af.confirmed_at
  from public.absence_fines af
  join public.employees e on e.id = af.employee_id and e.company_id = af.company_id
  left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
  where af.company_id = public.current_user_company_id()
  order by af.absence_date desc, e.fio;
end;
$$;

-- Юрист может открывать только файлы своей компании, которые уже привязаны
-- к юридическому документу, документу сотрудника либо акту/объяснительной.
create or replace function public.can_access_legal_workspace_storage(
  p_bucket text,
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, storage, pg_temp
as $$
  select auth.uid() is not null
    and public.current_user_company_id() is not null
    and (public.current_user_has_permission('legal.files.view') or public.is_admin())
    and (
      exists (
        select 1 from public.app_files f
        where f.company_id = public.current_user_company_id()
          and f.bucket_name = p_bucket
          and f.storage_path = p_name
          and f.deleted_at is null
      )
      or exists (
        select 1 from public.employee_document_files f
        where f.company_id = public.current_user_company_id()
          and f.storage_bucket = p_bucket
          and f.storage_path = p_name
      )
      or (
        p_bucket = 'absence-fine-acts'
        and exists (
          select 1 from public.absence_fines af
          where af.company_id = public.current_user_company_id()
            and af.act_file_path = p_name
        )
      )
      or (
        p_bucket = 'absence-explanations'
        and exists (
          select 1 from public.absence_fines af
          where af.company_id = public.current_user_company_id()
            and af.explanation_file_path = p_name
        )
      )
    );
$$;

revoke all on function public.legal_workspace_employee_directory() from public;
revoke all on function public.legal_workspace_object_directory() from public;
revoke all on function public.legal_workspace_documents(uuid, uuid, text) from public;
revoke all on function public.legal_workspace_recoveries() from public;
revoke all on function public.can_access_legal_workspace_storage(text, text) from public;
grant execute on function public.legal_workspace_employee_directory() to authenticated;
grant execute on function public.legal_workspace_object_directory() to authenticated;
grant execute on function public.legal_workspace_documents(uuid, uuid, text) to authenticated;
grant execute on function public.legal_workspace_recoveries() to authenticated;
grant execute on function public.can_access_legal_workspace_storage(text, text) to authenticated;

drop policy if exists legal_workspace_files_select on storage.objects;
create policy legal_workspace_files_select
on storage.objects
for select
to authenticated
using (public.can_access_legal_workspace_storage(bucket_id, name));
