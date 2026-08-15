-- Отменённый невыход не является действующим взысканием.
-- Юридическая панель показывает только ожидающие подтверждения и подтверждённые взыскания.

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
     where af.company_id = e.company_id and af.employee_id = e.id
       and af.status in ('pending', 'confirmed'))::bigint as fines_count,
    (select count(*) from public.absence_fines af
     where af.company_id = e.company_id and af.employee_id = e.id and af.status = 'pending')::bigint as pending_fines_count
  from public.employees e
  left join public.objects o on o.id = e.object_id and o.company_id = e.company_id
  where e.company_id = public.current_user_company_id()
    and e.archived_at is null
  order by e.fio;
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
    and af.status in ('pending', 'confirmed')
  order by af.absence_date desc, e.fio;
end;
$$;

revoke all on function public.legal_workspace_employee_directory() from public;
revoke all on function public.legal_workspace_recoveries() from public;
grant execute on function public.legal_workspace_employee_directory() to authenticated;
grant execute on function public.legal_workspace_recoveries() to authenticated;
