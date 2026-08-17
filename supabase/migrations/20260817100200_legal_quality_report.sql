-- Технический контроль качества юридической базы.

create or replace function public.legal_quality_report()
returns table(
  issue_type text,
  severity text,
  entity_type text,
  entity_id uuid,
  title text,
  details text
)
language plpgsql
stable
security definer
set search_path = public, storage, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.documents.view')
    or public.current_user_has_permission('legal.directory.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к контролю юридической базы';
  end if;

  return query
  select
    'document_without_file', 'warning', 'legal_document', d.id,
    d.title, 'У документа нет ни одного активного файла'
  from public.legal_documents d
  where d.company_id = v_company and d.archived_at is null
    and not exists (
      select 1 from public.legal_document_files ldf
      join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
      where ldf.document_id = d.id and ldf.archived_at is null
    )

  union all

  select
    'unlinked_document', 'warning', 'legal_document', d.id,
    d.title, 'Документ не привязан к сотруднику, объекту, контрагенту или делу'
  from public.legal_documents d
  where d.company_id = v_company and d.archived_at is null
    and d.employee_id is null and d.object_id is null
    and d.counterparty_id is null and d.legal_matter_id is null

  union all

  select
    'broken_legal_file', 'danger', 'legal_document', ldf.document_id,
    coalesce(af.original_name, 'Файл'), 'Файл указан в базе, но отсутствует в Storage'
  from public.legal_document_files ldf
  join public.legal_documents d on d.id = ldf.document_id and d.company_id = v_company
  join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
  left join storage.objects so
    on so.bucket_id = af.bucket_name and so.name = af.storage_path
  where ldf.archived_at is null and so.id is null

  union all

  select
    'broken_employee_file', 'danger', 'employee', edf.employee_id,
    coalesce(nullif(edf.original_file_name,''), nullif(edf.document_type,''), 'Документ сотрудника'),
    'Кадровый файл указан в базе, но отсутствует в Storage'
  from public.employee_document_files edf
  left join storage.objects so
    on so.bucket_id = edf.storage_bucket and so.name = edf.storage_path
  where edf.company_id = v_company
    and coalesce(edf.storage_path, '') <> ''
    and so.id is null

  union all

  select
    'matter_without_responsible', 'info', 'legal_matter', m.id,
    m.title, 'У открытого дела не назначен ответственный'
  from public.legal_matters m
  where m.company_id = v_company
    and m.status not in ('resolved','closed')
    and m.responsible_user_id is null;
end;
$$;

revoke all on function public.legal_quality_report() from public, anon;
grant execute on function public.legal_quality_report() to authenticated;
