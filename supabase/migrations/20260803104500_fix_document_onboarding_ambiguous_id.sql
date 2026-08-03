create or replace function public.create_document_onboarding(
  p_company_id uuid,
  p_recruitment_application_id uuid default null,
  p_employee_id uuid default null,
  p_package_id uuid default null,
  p_object_id uuid default null,
  p_onboarding_type text default 'gph',
  p_assigned_user_id uuid default null,
  p_due_at timestamptz default null,
  p_conditions jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_onboarding_id uuid;
  v_effective_object_id uuid := p_object_id;
  v_effective_employee_id uuid := p_employee_id;
  v_effective_assignee uuid := coalesce(p_assigned_user_id, auth.uid());
  v_step_code text;
begin
  if auth.uid() is null then raise exception 'Требуется авторизация'; end if;
  if p_company_id is distinct from public.current_user_company_id() then raise exception 'Недоступная компания'; end if;
  if not public.current_user_has_permission('documents.onboarding.create') then raise exception 'Нет права создавать оформление'; end if;
  if p_onboarding_type not in ('employment','gph','transfer','termination','custom') then raise exception 'Неизвестный тип оформления'; end if;

  if p_recruitment_application_id is not null then
    select a.object_id, coalesce(v_effective_employee_id, a.employee_id)
      into v_effective_object_id, v_effective_employee_id
    from public.recruitment_applications a
    where a.id = p_recruitment_application_id and a.company_id = p_company_id;
    if not found then raise exception 'Кандидат не найден в активной компании'; end if;
  end if;

  if v_effective_employee_id is not null and not exists(
    select 1 from public.employees e where e.id = v_effective_employee_id and e.company_id = p_company_id
  ) then raise exception 'Сотрудник не найден в активной компании'; end if;

  if v_effective_object_id is not null and not exists(
    select 1 from public.objects o where o.id = v_effective_object_id and o.company_id = p_company_id and o.is_active
  ) then raise exception 'Объект не найден в активной компании'; end if;

  if p_package_id is not null and not exists(
    select 1 from public.document_packages p where p.id = p_package_id and p.company_id = p_company_id and p.is_active
  ) then raise exception 'Пакет документов недоступен'; end if;

  if v_effective_assignee is not null and not exists(
    select 1 from public.company_memberships m
    where m.company_id = p_company_id and m.user_id = v_effective_assignee and m.is_active
  ) then raise exception 'Ответственный не состоит в компании'; end if;

  if p_recruitment_application_id is not null and exists(
    select 1 from public.employee_onboardings x
    where x.company_id = p_company_id
      and x.recruitment_application_id = p_recruitment_application_id
      and x.status not in ('cancelled','completed')
  ) then raise exception 'Для кандидата уже есть незавершённое оформление'; end if;

  insert into public.employee_onboardings(
    company_id, recruitment_application_id, employee_id, package_id,
    status, current_step, onboarding_type, object_id, assigned_user_id,
    due_at, conditions, created_by
  ) values (
    p_company_id, p_recruitment_application_id, v_effective_employee_id,
    p_package_id, 'in_progress', 'source_files', p_onboarding_type,
    v_effective_object_id, v_effective_assignee, p_due_at,
    coalesce(p_conditions, '{}'::jsonb), auth.uid()
  ) returning id into v_onboarding_id;

  foreach v_step_code in array array[
    'source_files','source_completeness','recognition','hr_verification',
    'employee_card','package_and_conditions','generation','printing',
    'signing','signed_documents','final_scans','archive_verification','completion'
  ] loop
    insert into public.employee_onboarding_steps(
      company_id, onboarding_id, step_code, status, assigned_user_id, is_required
    ) values (
      p_company_id, v_onboarding_id, v_step_code,
      case when v_step_code = 'source_files' then 'in_progress' else 'pending' end,
      v_effective_assignee, true
    );
  end loop;

  if p_recruitment_application_id is not null then
    insert into public.employee_document_files(
      company_id, onboarding_id, employee_id, recruitment_document_id,
      file_kind, document_type, storage_bucket, storage_path,
      original_file_name, mime_type, file_size, version_no, metadata,
      quality_status, verification_status, uploaded_by
    )
    select p_company_id, v_onboarding_id, v_effective_employee_id, d.id,
      'source', d.document_type, d.storage_bucket, d.storage_path,
      coalesce(nullif(d.original_name,''),d.document_type), d.mime_type,
      d.size_bytes, 1,
      jsonb_build_object('source','recruitment','application_id',p_recruitment_application_id,'linked_without_copy',true),
      'not_checked','pending',auth.uid()
    from public.recruitment_documents d
    where d.company_id = p_company_id
      and d.application_id = p_recruitment_application_id
      and btrim(d.storage_path) <> ''
    on conflict (onboarding_id,recruitment_document_id)
      where recruitment_document_id is not null
    do nothing;

    insert into public.employee_document_files(
      company_id, onboarding_id, employee_id, recruitment_onboarding_form_id,
      file_kind, document_type, storage_bucket, storage_path,
      original_file_name, mime_type, file_size, version_no, metadata,
      quality_status, verification_status, uploaded_by
    )
    select p_company_id, v_onboarding_id, v_effective_employee_id, f.id,
      case when f.signed_at is not null then 'signed' else 'generated' end,
      f.form_code, f.storage_bucket, f.storage_path,
      coalesce(nullif(f.original_name,''),f.form_code),
      coalesce(nullif(f.mime_type,''),'application/octet-stream'), f.size_bytes, 1,
      jsonb_build_object('source','recruitment_onboarding_form','application_id',p_recruitment_application_id,'form_status',f.status,'linked_without_copy',true),
      'not_checked', case when f.signed_at is not null then 'pending' else 'accepted' end, auth.uid()
    from public.recruitment_onboarding_forms f
    where f.company_id = p_company_id
      and f.application_id = p_recruitment_application_id
      and btrim(f.storage_path) <> ''
    on conflict (onboarding_id,recruitment_onboarding_form_id)
      where recruitment_onboarding_form_id is not null
    do nothing;
  end if;

  insert into public.document_audit_log(
    company_id,onboarding_id,employee_id,entity_type,entity_id,action,actor_user_id,details
  ) values (
    p_company_id,v_onboarding_id,v_effective_employee_id,'employee_onboarding',
    v_onboarding_id::text,'created',auth.uid(),
    jsonb_build_object('recruitment_application_id',p_recruitment_application_id,'package_id',p_package_id,'onboarding_type',p_onboarding_type)
  );

  return v_onboarding_id;
end
$function$;