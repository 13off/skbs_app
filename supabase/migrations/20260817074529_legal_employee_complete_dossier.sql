-- Полное юридическое досье сотрудника.
-- Персональные данные не открываются напрямую: юрист получает их через
-- security-definer RPC с отдельным правом, company isolation и audit log.

insert into public.permission_catalog (
  permission_code, category, title, description, supports_object_scope, sort_order
) values (
  'legal.personal_data.view',
  'Юридический блок',
  'Личные данные сотрудников',
  'Просмотр персональных и кадровых данных сотрудников в юридическом досье',
  false,
  2010
)
on conflict (permission_code) do update set
  category = excluded.category,
  title = excluded.title,
  description = excluded.description,
  supports_object_scope = excluded.supports_object_scope,
  sort_order = excluded.sort_order,
  updated_at = now();

insert into public.role_permissions (role_code, permission_code)
values
  ('lawyer', 'legal.personal_data.view'),
  ('admin', 'legal.personal_data.view')
on conflict (role_code, permission_code) do nothing;

create or replace function public.legal_employee_dossier(p_employee_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid;
  v_payload jsonb;
begin
  v_company_id := public.current_user_company_id();
  if auth.uid() is null or v_company_id is null or not (
    public.current_user_has_permission('legal.personal_data.view') or public.is_admin()
  ) then
    raise exception 'Нет доступа к персональным данным сотрудников';
  end if;

  select jsonb_build_object(
    'employee_id', e.id,
    'fio', coalesce(e.fio, ''),
    'position', coalesce(e.position, ''),
    'phone', coalesce(nullif(pd.phone, ''), e.phone, ''),
    'object_id', e.object_id,
    'object_name', coalesce(o.name, e.object_name, ''),
    'daily_rate', e.daily_rate,
    'is_active', coalesce(e.is_active, true),
    'archived_at', e.archived_at,
    'employee_comment', coalesce(e.comment, ''),
    'employee_created_at', e.created_at,
    'employee_updated_at', e.updated_at,
    'birth_date', coalesce(pd.birth_date, ''),
    'birth_place', coalesce(pd.birth_place, ''),
    'passport_series', coalesce(pd.passport_series, ''),
    'passport_number', coalesce(pd.passport_number, ''),
    'passport_issued_by', coalesce(pd.passport_issued_by, ''),
    'passport_issued_date', coalesce(pd.passport_issued_date, ''),
    'passport_department_code', coalesce(pd.passport_department_code, ''),
    'snils', coalesce(pd.snils, ''),
    'inn', coalesce(pd.inn, ''),
    'registration_address', coalesce(pd.registration_address, ''),
    'living_address', coalesce(pd.living_address, ''),
    'clothes_size', coalesce(pd.clothes_size, ''),
    'shoe_size', coalesce(pd.shoe_size, ''),
    'bank_name', coalesce(pd.bank_name, ''),
    'bank_card', coalesce(pd.bank_card, ''),
    'bank_account', coalesce(pd.bank_account, ''),
    'bank_bik', coalesce(pd.bank_bik, ''),
    'bank_corr_account', coalesce(pd.bank_corr_account, ''),
    'bank_inn', coalesce(pd.bank_inn, ''),
    'bank_kpp', coalesce(pd.bank_kpp, ''),
    'bank_okpo', coalesce(pd.bank_okpo, ''),
    'bank_ogrn', coalesce(pd.bank_ogrn, ''),
    'bank_swift', coalesce(pd.bank_swift, ''),
    'bank_address', coalesce(pd.bank_address, ''),
    'bank_office_address', coalesce(pd.bank_office_address, ''),
    'contract_number', coalesce(pd.contract_number, ''),
    'employment_start_date', coalesce(pd.employment_start_date, ''),
    'dismissal_date', coalesce(pd.dismissal_date, ''),
    'phone', coalesce(nullif(pd.phone, ''), e.phone, ''),
    'private_comment', coalesce(pd.comment, ''),
    'citizenship', coalesce(ra.citizenship, ''),
    'consent_personal_data', ra.consent_personal_data,
    'consented_at', ra.consented_at,
    'application_id', ra.id
  )
  into v_payload
  from public.employees e
  left join public.objects o
    on o.id = e.object_id and o.company_id = e.company_id
  left join public.employee_private_data pd
    on pd.employee_id = e.id and pd.company_id = e.company_id
  left join lateral (
    select a.id, a.citizenship, a.consent_personal_data, a.consented_at
    from public.recruitment_applications a
    where a.company_id = e.company_id and a.employee_id = e.id
    order by a.updated_at desc nulls last, a.created_at desc
    limit 1
  ) ra on true
  where e.id = p_employee_id and e.company_id = v_company_id;

  if v_payload is null then
    raise exception 'Сотрудник не найден в текущей компании';
  end if;

  insert into public.personal_data_access_log (
    company_id, user_id, action, entity_type, entity_id, metadata
  ) values (
    v_company_id,
    auth.uid(),
    'view',
    'legal_employee_dossier',
    p_employee_id::text,
    jsonb_build_object('section', 'personal_data')
  );

  return v_payload;
end;
$$;

revoke all on function public.legal_employee_dossier(uuid) from public, anon;
grant execute on function public.legal_employee_dossier(uuid) to authenticated;

create or replace function public.legal_employee_dossier_documents(p_employee_id uuid)
returns table(
  source_type text,
  source_id uuid,
  title text,
  document_group text,
  document_type text,
  status text,
  document_number text,
  file_name text,
  bucket_name text,
  storage_path text,
  document_date timestamptz,
  valid_from date,
  expires_on date,
  legal_document_id uuid,
  source_label text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid;
begin
  v_company_id := public.current_user_company_id();
  if auth.uid() is null or v_company_id is null or not (
    public.current_user_has_permission('legal.documents.view') or
    public.current_user_has_permission('legal.directory.view') or
    public.is_admin()
  ) then
    raise exception 'Нет доступа к документам сотрудника';
  end if;

  if not exists (
    select 1 from public.employees e
    where e.id = p_employee_id and e.company_id = v_company_id
  ) then
    raise exception 'Сотрудник не найден в текущей компании';
  end if;

  return query
  with docs as (
    select
      'legal_document'::text as source_type,
      d.id as source_id,
      d.title,
      case
        when lower(coalesce(d.document_type, '') || ' ' || coalesce(d.title, '')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|договор|contract)' then 'contract'
        when lower(coalesce(d.document_type, '') || ' ' || coalesce(d.title, '')) ~ '(акт| act )' then 'act_explanation'
        when lower(coalesce(d.document_type, '') || ' ' || coalesce(d.title, '')) ~ '(объясн)' then 'act_explanation'
        when lower(coalesce(d.document_type, '') || ' ' || coalesce(d.title, '')) ~ '(заявлен|application|соглас|consent|agreement)' then 'application_consent'
        when lower(coalesce(d.document_type, '') || ' ' || coalesce(d.title, '')) ~ '(паспорт|passport|снилс|snils|инн|inn|полис|polis|insurance|фото|photo|пропис|регистрац)' then 'personal_document'
        else 'other'
      end::text as document_group,
      coalesce(d.document_type, '') as document_type,
      coalesce(d.status, '') as status,
      coalesce(d.document_number, '') as document_number,
      coalesce(f.original_name, '') as file_name,
      coalesce(f.bucket_name, '') as bucket_name,
      coalesce(f.storage_path, '') as storage_path,
      coalesce(d.signed_on::timestamptz, d.created_on::timestamptz, d.created_at) as document_date,
      d.valid_from,
      d.expires_on,
      d.id as legal_document_id,
      'Юридические документы'::text as source_label
    from public.legal_documents d
    left join lateral (
      select af.original_name, af.bucket_name, af.storage_path
      from public.legal_document_files ldf
      join public.app_files af on af.id = ldf.file_id and af.deleted_at is null
      where ldf.document_id = d.id and ldf.company_id = d.company_id
      order by ldf.is_primary desc, ldf.created_at desc
      limit 1
    ) f on true
    where d.company_id = v_company_id
      and d.employee_id = p_employee_id
      and d.archived_at is null

    union all

    select
      'employee_document'::text,
      edf.id,
      coalesce(nullif(dt.title, ''), nullif(edf.original_file_name, ''), nullif(edf.document_type, ''), 'Документ сотрудника'),
      case
        when lower(coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(edf.document_type, '') || ' ' || coalesce(edf.file_kind, '') || ' ' || coalesce(edf.original_file_name, '')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)' then 'contract'
        when lower(coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(edf.document_type, '') || ' ' || coalesce(edf.file_kind, '')) ~ '(акт|объясн)' then 'act_explanation'
        when lower(coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(edf.document_type, '') || ' ' || coalesce(edf.file_kind, '')) ~ '(application|заявлен|consent|соглас|agreement|соглашен)' then 'application_consent'
        when lower(coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(edf.document_type, '') || ' ' || coalesce(edf.file_kind, '') || ' ' || coalesce(edf.original_file_name, '')) ~ '(passport|паспорт|snils|снилс|inn|инн|polis|полис|insurance|фото|photo|registration|пропис|регистрац)' then 'personal_document'
        else 'other'
      end::text,
      coalesce(nullif(edf.document_type, ''), dt.code, '') as document_type,
      coalesce(nullif(edf.verification_status, ''), nullif(edf.quality_status, ''), '') as status,
      coalesce(edf.metadata->>'document_number', '') as document_number,
      coalesce(edf.original_file_name, '') as file_name,
      coalesce(edf.storage_bucket, '') as bucket_name,
      coalesce(edf.storage_path, '') as storage_path,
      edf.created_at as document_date,
      null::date,
      null::date,
      null::uuid,
      'Кадровые документы'::text
    from public.employee_document_files edf
    left join public.document_templates dt
      on dt.id = edf.template_id and dt.company_id = edf.company_id
    where edf.company_id = v_company_id and edf.employee_id = p_employee_id

    union all

    select
      'recruitment_document'::text,
      rd.id,
      coalesce(nullif(rd.original_name, ''), nullif(rd.document_type, ''), 'Документ кандидата'),
      case
        when lower(coalesce(rd.document_type, '') || ' ' || coalesce(rd.original_name, '')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|договор|contract)' then 'contract'
        when lower(coalesce(rd.document_type, '') || ' ' || coalesce(rd.original_name, '')) ~ '(акт|объясн)' then 'act_explanation'
        when lower(coalesce(rd.document_type, '') || ' ' || coalesce(rd.original_name, '')) ~ '(application|заявлен|consent|соглас|agreement|соглашен)' then 'application_consent'
        when lower(coalesce(rd.document_type, '') || ' ' || coalesce(rd.original_name, '')) ~ '(passport|паспорт|snils|снилс|inn|инн|polis|полис|insurance|фото|photo|registration|пропис|регистрац)' then 'personal_document'
        else 'other'
      end::text,
      coalesce(rd.document_type, '') as document_type,
      ''::text as status,
      ''::text as document_number,
      coalesce(rd.original_name, '') as file_name,
      coalesce(rd.storage_bucket, '') as bucket_name,
      coalesce(rd.storage_path, '') as storage_path,
      rd.created_at as document_date,
      null::date,
      null::date,
      null::uuid,
      'Документы кандидата'::text
    from public.recruitment_documents rd
    join public.recruitment_applications ra
      on ra.id = rd.application_id and ra.company_id = rd.company_id
    where rd.company_id = v_company_id and ra.employee_id = p_employee_id

    union all

    select
      'onboarding_form'::text,
      f.id,
      coalesce(nullif(dt.title, ''), nullif(f.original_name, ''), nullif(f.form_code, ''), 'Документ оформления'),
      case
        when lower(coalesce(f.form_code, '') || ' ' || coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(f.original_name, '')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)' then 'contract'
        when lower(coalesce(f.form_code, '') || ' ' || coalesce(dt.code, '') || ' ' || coalesce(dt.title, '')) ~ '(акт|объясн)' then 'act_explanation'
        when lower(coalesce(f.form_code, '') || ' ' || coalesce(dt.code, '') || ' ' || coalesce(dt.title, '')) ~ '(application|заявлен|consent|соглас|agreement|соглашен)' then 'application_consent'
        when lower(coalesce(f.form_code, '') || ' ' || coalesce(dt.code, '') || ' ' || coalesce(dt.title, '') || ' ' || coalesce(f.original_name, '')) ~ '(passport|паспорт|snils|снилс|inn|инн|polis|полис|insurance|фото|photo|registration|пропис|регистрац)' then 'personal_document'
        else 'other'
      end::text,
      coalesce(nullif(f.form_code, ''), dt.code, '') as document_type,
      coalesce(f.status, '') as status,
      ''::text as document_number,
      coalesce(f.original_name, '') as file_name,
      coalesce(f.storage_bucket, '') as bucket_name,
      coalesce(f.storage_path, '') as storage_path,
      coalesce(f.signed_at, f.printed_at, f.generated_at, f.created_at) as document_date,
      null::date,
      null::date,
      null::uuid,
      'Формы оформления'::text
    from public.recruitment_onboarding_forms f
    left join public.document_templates dt
      on dt.code = f.form_code and dt.company_id = f.company_id
    where f.company_id = v_company_id and f.employee_id = p_employee_id

    union all

    select
      'absence_fine_act'::text,
      af.id,
      'Акт о невыходе — ' || to_char(af.absence_date, 'DD.MM.YYYY'),
      'act_explanation'::text,
      'absence_fine_act'::text,
      af.status,
      ''::text,
      coalesce(af.act_file_name, ''),
      'absence-fine-acts'::text,
      coalesce(af.act_file_path, ''),
      coalesce(af.act_uploaded_at, af.created_at),
      null::date,
      null::date,
      null::uuid,
      'Невыход / взыскание'::text
    from public.absence_fines af
    where af.company_id = v_company_id
      and af.employee_id = p_employee_id
      and nullif(af.act_file_path, '') is not null

    union all

    select
      'absence_explanation'::text,
      af.id,
      'Объяснительная о невыходе — ' || to_char(af.absence_date, 'DD.MM.YYYY'),
      'act_explanation'::text,
      'absence_explanation'::text,
      af.status,
      ''::text,
      coalesce(af.explanation_file_name, ''),
      'absence-explanations'::text,
      coalesce(af.explanation_file_path, ''),
      coalesce(af.explanation_uploaded_at, af.created_at),
      null::date,
      null::date,
      null::uuid,
      'Невыход / взыскание'::text
    from public.absence_fines af
    where af.company_id = v_company_id
      and af.employee_id = p_employee_id
      and nullif(af.explanation_file_path, '') is not null
  )
  select d.*
  from docs d
  order by d.document_date desc nulls last, d.title;
end;
$$;

revoke all on function public.legal_employee_dossier_documents(uuid) from public, anon;
grant execute on function public.legal_employee_dossier_documents(uuid) to authenticated;

-- Юрист видит и действующих, и уволенных/архивных сотрудников. История досье
-- не исчезает после увольнения.
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
      (select count(*) from public.legal_documents d where d.company_id=e.company_id and d.employee_id=e.id and d.archived_at is null)
      + (select count(*) from public.employee_document_files f where f.company_id=e.company_id and f.employee_id=e.id)
      + (select count(*) from public.recruitment_documents rd join public.recruitment_applications ra on ra.id=rd.application_id and ra.company_id=rd.company_id where rd.company_id=e.company_id and ra.employee_id=e.id)
      + (select count(*) from public.recruitment_onboarding_forms f where f.company_id=e.company_id and f.employee_id=e.id)
      + (select count(*) from public.absence_fines af where af.company_id=e.company_id and af.employee_id=e.id and nullif(af.act_file_path,'') is not null)
      + (select count(*) from public.absence_fines af where af.company_id=e.company_id and af.employee_id=e.id and nullif(af.explanation_file_path,'') is not null)
    )::bigint,
    (
      (select count(*) from public.legal_documents d where d.company_id=e.company_id and d.employee_id=e.id and d.archived_at is null and lower(coalesce(d.document_type,'')||' '||coalesce(d.title,'')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|договор|contract)')
      + (select count(*) from public.employee_document_files f left join public.document_templates dt on dt.id=f.template_id and dt.company_id=f.company_id where f.company_id=e.company_id and f.employee_id=e.id and lower(coalesce(dt.code,'')||' '||coalesce(dt.title,'')||' '||coalesce(f.document_type,'')||' '||coalesce(f.file_kind,'')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)')
      + (select count(*) from public.recruitment_onboarding_forms f left join public.document_templates dt on dt.code=f.form_code and dt.company_id=f.company_id where f.company_id=e.company_id and f.employee_id=e.id and lower(coalesce(f.form_code,'')||' '||coalesce(dt.code,'')||' '||coalesce(dt.title,'')) ~ '(гпх|gph|civil|service|оказан.*услуг|подряд|employment_contract|трудов.*договор|договор|contract)')
    )::bigint,
    (
      (select count(*) from public.legal_documents d where d.company_id=e.company_id and d.employee_id=e.id and d.archived_at is null and lower(coalesce(d.document_type,'')||' '||coalesce(d.title,'')) ~ '(акт| act )')
      + (select count(*) from public.employee_document_files f where f.company_id=e.company_id and f.employee_id=e.id and lower(coalesce(f.document_type,'')||' '||coalesce(f.file_kind,'')) ~ '(акт| act )')
      + (select count(*) from public.absence_fines af where af.company_id=e.company_id and af.employee_id=e.id and nullif(af.act_file_path,'') is not null)
    )::bigint,
    (select count(*) from public.legal_matters m where m.company_id=e.company_id and m.employee_id=e.id)::bigint,
    (select count(*) from public.absence_fines af where af.company_id=e.company_id and af.employee_id=e.id and af.status in ('pending','confirmed'))::bigint,
    (select count(*) from public.absence_fines af where af.company_id=e.company_id and af.employee_id=e.id and af.status='pending')::bigint
  from public.employees e
  left join public.objects o on o.id=e.object_id and o.company_id=e.company_id
  where e.company_id=public.current_user_company_id()
  order by coalesce(e.is_active,false) desc, e.archived_at nulls first, e.fio;
end;
$$;

revoke all on function public.legal_workspace_employee_directory() from public, anon;
grant execute on function public.legal_workspace_employee_directory() to authenticated;

-- Расширяем уже существующую проверку Storage только на реально привязанные
-- кадровые файлы своей компании.
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
      or exists (
        select 1
        from public.recruitment_documents rd
        join public.recruitment_applications ra
          on ra.id = rd.application_id and ra.company_id = rd.company_id
        where rd.company_id = public.current_user_company_id()
          and ra.employee_id is not null
          and rd.storage_bucket = p_bucket
          and rd.storage_path = p_name
      )
      or exists (
        select 1 from public.recruitment_onboarding_forms f
        where f.company_id = public.current_user_company_id()
          and f.employee_id is not null
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

revoke all on function public.can_access_legal_workspace_storage(text,text) from public, anon;
grant execute on function public.can_access_legal_workspace_storage(text,text) to authenticated;
