-- AppСтрой Документооборот v3: runtime, transitions and storage access.

insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values (
  'employee-documents',
  'employee-documents',
  false,
  20971520,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/plain'
  ]::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.touch_document_workflow_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'document_tool_installations_touch'
  ) then
    create trigger document_tool_installations_touch
    before update on public.document_tool_installations
    for each row execute function public.touch_document_workflow_updated_at();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'document_packages_touch'
  ) then
    create trigger document_packages_touch
    before update on public.document_packages
    for each row execute function public.touch_document_workflow_updated_at();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'employee_onboardings_touch'
  ) then
    create trigger employee_onboardings_touch
    before update on public.employee_onboardings
    for each row execute function public.touch_document_workflow_updated_at();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'employee_onboarding_steps_touch'
  ) then
    create trigger employee_onboarding_steps_touch
    before update on public.employee_onboarding_steps
    for each row execute function public.touch_document_workflow_updated_at();
  end if;
end $$;

create or replace function public.validate_document_workflow_company()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  related_company uuid;
begin
  if tg_table_name = 'document_package_templates' then
    select company_id into related_company
    from public.document_packages
    where id = new.package_id;
    if related_company is distinct from new.company_id then
      raise exception 'Пакет относится к другой компании';
    end if;

    if not exists (
      select 1
      from public.document_templates template
      where template.id = new.template_id
        and (template.company_id is null or template.company_id = new.company_id)
    ) then
      raise exception 'Шаблон недоступен выбранной компании';
    end if;
  end if;

  if tg_table_name = 'employee_onboardings' then
    if new.recruitment_application_id is not null then
      select company_id into related_company
      from public.recruitment_applications
      where id = new.recruitment_application_id;
      if related_company is distinct from new.company_id then
        raise exception 'Кандидат относится к другой компании';
      end if;
    end if;

    if new.employee_id is not null then
      select company_id into related_company
      from public.employees
      where id = new.employee_id;
      if related_company is distinct from new.company_id then
        raise exception 'Сотрудник относится к другой компании';
      end if;
    end if;

    if new.object_id is not null then
      select company_id into related_company
      from public.objects
      where id = new.object_id;
      if related_company is distinct from new.company_id then
        raise exception 'Объект относится к другой компании';
      end if;
    end if;

    if new.package_id is not null then
      select company_id into related_company
      from public.document_packages
      where id = new.package_id;
      if related_company is distinct from new.company_id then
        raise exception 'Пакет относится к другой компании';
      end if;
    end if;
  end if;

  if tg_table_name = 'employee_onboarding_steps' then
    select company_id into related_company
    from public.employee_onboardings
    where id = new.onboarding_id;
    if related_company is distinct from new.company_id then
      raise exception 'Этап относится к другому процессу компании';
    end if;
  end if;

  if tg_table_name = 'employee_document_files' then
    if new.onboarding_id is not null then
      select company_id into related_company
      from public.employee_onboardings
      where id = new.onboarding_id;
      if related_company is distinct from new.company_id then
        raise exception 'Файл относится к другому процессу компании';
      end if;
    end if;

    if new.employee_id is not null then
      select company_id into related_company
      from public.employees
      where id = new.employee_id;
      if related_company is distinct from new.company_id then
        raise exception 'Файл относится к сотруднику другой компании';
      end if;
    end if;

    if new.recruitment_document_id is not null then
      select company_id into related_company
      from public.recruitment_documents
      where id = new.recruitment_document_id;
      if related_company is distinct from new.company_id then
        raise exception 'Исходный документ относится к другой компании';
      end if;
    end if;

    if new.recruitment_onboarding_form_id is not null then
      select company_id into related_company
      from public.recruitment_onboarding_forms
      where id = new.recruitment_onboarding_form_id;
      if related_company is distinct from new.company_id then
        raise exception 'Сформированная форма относится к другой компании';
      end if;
    end if;

    if new.template_id is not null and not exists (
      select 1
      from public.document_templates template
      where template.id = new.template_id
        and (template.company_id is null or template.company_id = new.company_id)
    ) then
      raise exception 'Шаблон файла недоступен компании';
    end if;

    if new.template_version_id is not null and not exists (
      select 1
      from public.document_template_versions version
      join public.document_templates template on template.id = version.template_id
      where version.id = new.template_version_id
        and (template.company_id is null or template.company_id = new.company_id)
    ) then
      raise exception 'Версия шаблона недоступна компании';
    end if;
  end if;

  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'document_package_templates_company_guard'
  ) then
    create trigger document_package_templates_company_guard
    before insert or update on public.document_package_templates
    for each row execute function public.validate_document_workflow_company();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'employee_onboardings_company_guard'
  ) then
    create trigger employee_onboardings_company_guard
    before insert or update on public.employee_onboardings
    for each row execute function public.validate_document_workflow_company();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'employee_onboarding_steps_company_guard'
  ) then
    create trigger employee_onboarding_steps_company_guard
    before insert or update on public.employee_onboarding_steps
    for each row execute function public.validate_document_workflow_company();
  end if;

  if not exists (
    select 1 from pg_trigger where tgname = 'employee_document_files_company_guard'
  ) then
    create trigger employee_document_files_company_guard
    before insert or update on public.employee_document_files
    for each row execute function public.validate_document_workflow_company();
  end if;
end $$;

create or replace function public.document_workflow_permission_map()
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'view', public.current_user_has_permission('documents.workflow.view'),
    'manage', public.current_user_has_permission('documents.workflow.manage'),
    'create', public.current_user_has_permission('documents.onboarding.create'),
    'edit', public.current_user_has_permission('documents.onboarding.edit'),
    'verify', public.current_user_has_permission('documents.onboarding.verify'),
    'packages', public.current_user_has_permission('documents.packages.manage'),
    'audit', public.current_user_has_permission('documents.audit.view'),
    'templates_view', public.current_user_has_permission('documents.templates.view'),
    'templates_edit', public.current_user_has_permission('documents.templates.edit')
  );
$$;

revoke all on function public.document_workflow_permission_map() from public, anon;
grant execute on function public.document_workflow_permission_map() to authenticated;

create or replace function public.record_document_workflow_audit(
  p_company_id uuid,
  p_onboarding_id uuid,
  p_employee_id uuid,
  p_entity_type text,
  p_entity_id text,
  p_action text,
  p_details jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  audit_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if p_company_id is distinct from public.current_user_company_id() then
    raise exception 'Недоступная компания';
  end if;
  if not (
    public.current_user_has_permission('documents.onboarding.edit')
    or public.current_user_has_permission('documents.onboarding.verify')
    or public.current_user_has_permission('documents.workflow.manage')
    or public.current_user_has_permission('documents.packages.manage')
  ) then
    raise exception 'Нет права записывать действия документооборота';
  end if;
  if btrim(coalesce(p_entity_type, '')) = ''
     or btrim(coalesce(p_entity_id, '')) = ''
     or btrim(coalesce(p_action, '')) = '' then
    raise exception 'Не заполнены реквизиты события';
  end if;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    p_company_id, p_onboarding_id, p_employee_id, p_entity_type, p_entity_id,
    p_action, auth.uid(), coalesce(p_details, '{}'::jsonb)
  )
  returning id into audit_id;

  return audit_id;
end;
$$;

revoke all on function public.record_document_workflow_audit(
  uuid, uuid, uuid, text, text, text, jsonb
) from public, anon;
grant execute on function public.record_document_workflow_audit(
  uuid, uuid, uuid, text, text, text, jsonb
) to authenticated;

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
set search_path = public, pg_temp
as $$
declare
  onboarding_id uuid;
  effective_object_id uuid := p_object_id;
  effective_employee_id uuid := p_employee_id;
  effective_assignee uuid := coalesce(p_assigned_user_id, auth.uid());
  step_code text;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if p_company_id is distinct from public.current_user_company_id() then
    raise exception 'Недоступная компания';
  end if;
  if not public.current_user_has_permission('documents.onboarding.create') then
    raise exception 'Нет права создавать оформление';
  end if;
  if p_onboarding_type not in ('employment', 'gph', 'transfer', 'termination', 'custom') then
    raise exception 'Неизвестный тип оформления';
  end if;

  if p_recruitment_application_id is not null then
    select application.object_id, coalesce(effective_employee_id, application.employee_id)
      into effective_object_id, effective_employee_id
    from public.recruitment_applications application
    where application.id = p_recruitment_application_id
      and application.company_id = p_company_id;

    if not found then
      raise exception 'Кандидат не найден в активной компании';
    end if;
  end if;

  if effective_employee_id is not null and not exists (
    select 1 from public.employees employee
    where employee.id = effective_employee_id
      and employee.company_id = p_company_id
  ) then
    raise exception 'Сотрудник не найден в активной компании';
  end if;

  if effective_object_id is not null and not exists (
    select 1 from public.objects object_row
    where object_row.id = effective_object_id
      and object_row.company_id = p_company_id
      and object_row.is_active
  ) then
    raise exception 'Объект не найден в активной компании';
  end if;

  if p_package_id is not null and not exists (
    select 1 from public.document_packages package
    where package.id = p_package_id
      and package.company_id = p_company_id
      and package.is_active
  ) then
    raise exception 'Пакет документов недоступен';
  end if;

  if effective_assignee is not null and not exists (
    select 1 from public.company_memberships membership
    where membership.company_id = p_company_id
      and membership.user_id = effective_assignee
      and membership.is_active
  ) then
    raise exception 'Ответственный не состоит в компании';
  end if;

  if p_recruitment_application_id is not null and exists (
    select 1
    from public.employee_onboardings existing
    where existing.company_id = p_company_id
      and existing.recruitment_application_id = p_recruitment_application_id
      and existing.status not in ('cancelled', 'completed')
  ) then
    raise exception 'Для кандидата уже есть незавершённое оформление';
  end if;

  insert into public.employee_onboardings (
    company_id, recruitment_application_id, employee_id, package_id,
    status, current_step, onboarding_type, object_id, assigned_user_id,
    due_at, conditions, created_by
  )
  values (
    p_company_id, p_recruitment_application_id, effective_employee_id, p_package_id,
    'in_progress', 'source_files', p_onboarding_type, effective_object_id,
    effective_assignee, p_due_at, coalesce(p_conditions, '{}'::jsonb), auth.uid()
  )
  returning id into onboarding_id;

  foreach step_code in array array[
    'source_files', 'source_completeness', 'recognition', 'hr_verification',
    'employee_card', 'package_and_conditions', 'generation', 'printing',
    'signing', 'signed_documents', 'final_scans', 'archive_verification',
    'completion'
  ]
  loop
    insert into public.employee_onboarding_steps (
      company_id, onboarding_id, step_code, status, assigned_user_id, is_required
    )
    values (
      p_company_id,
      onboarding_id,
      step_code,
      case when step_code = 'source_files' then 'in_progress' else 'pending' end,
      effective_assignee,
      true
    );
  end loop;

  if p_recruitment_application_id is not null then
    insert into public.employee_document_files (
      company_id, onboarding_id, employee_id, recruitment_document_id,
      file_kind, document_type, storage_bucket, storage_path,
      original_file_name, mime_type, file_size, version_no, metadata,
      quality_status, verification_status, uploaded_by
    )
    select
      p_company_id,
      onboarding_id,
      effective_employee_id,
      document.id,
      'source',
      document.document_type,
      document.storage_bucket,
      document.storage_path,
      coalesce(nullif(document.original_name, ''), document.document_type),
      document.mime_type,
      document.size_bytes,
      1,
      jsonb_build_object(
        'source', 'recruitment',
        'application_id', p_recruitment_application_id,
        'linked_without_copy', true
      ),
      'not_checked',
      'pending',
      auth.uid()
    from public.recruitment_documents document
    where document.company_id = p_company_id
      and document.application_id = p_recruitment_application_id
      and btrim(document.storage_path) <> ''
    on conflict (onboarding_id, recruitment_document_id)
      where recruitment_document_id is not null
    do nothing;

    insert into public.employee_document_files (
      company_id, onboarding_id, employee_id, recruitment_onboarding_form_id,
      file_kind, document_type, storage_bucket, storage_path,
      original_file_name, mime_type, file_size, version_no, metadata,
      quality_status, verification_status, uploaded_by
    )
    select
      p_company_id,
      onboarding_id,
      effective_employee_id,
      form.id,
      case when form.signed_at is not null then 'signed' else 'generated' end,
      form.form_code,
      form.storage_bucket,
      form.storage_path,
      coalesce(nullif(form.original_name, ''), form.form_code),
      coalesce(nullif(form.mime_type, ''), 'application/octet-stream'),
      form.size_bytes,
      1,
      jsonb_build_object(
        'source', 'recruitment_onboarding_form',
        'application_id', p_recruitment_application_id,
        'form_status', form.status,
        'linked_without_copy', true
      ),
      'not_checked',
      case when form.signed_at is not null then 'pending' else 'accepted' end,
      auth.uid()
    from public.recruitment_onboarding_forms form
    where form.company_id = p_company_id
      and form.application_id = p_recruitment_application_id
      and btrim(form.storage_path) <> ''
    on conflict (onboarding_id, recruitment_onboarding_form_id)
      where recruitment_onboarding_form_id is not null
    do nothing;
  end if;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    p_company_id, onboarding_id, effective_employee_id,
    'employee_onboarding', onboarding_id::text, 'created', auth.uid(),
    jsonb_build_object(
      'recruitment_application_id', p_recruitment_application_id,
      'package_id', p_package_id,
      'onboarding_type', p_onboarding_type
    )
  );

  return onboarding_id;
end;
$$;

revoke all on function public.create_document_onboarding(
  uuid, uuid, uuid, uuid, uuid, text, uuid, timestamptz, jsonb
) from public, anon;
grant execute on function public.create_document_onboarding(
  uuid, uuid, uuid, uuid, uuid, text, uuid, timestamptz, jsonb
) to authenticated;

create or replace function public.set_document_onboarding_context(
  p_onboarding_id uuid,
  p_employee_id uuid default null,
  p_package_id uuid default null,
  p_object_id uuid default null,
  p_onboarding_type text default null,
  p_conditions jsonb default null,
  p_recognized_data jsonb default null,
  p_verification_data jsonb default null,
  p_assigned_user_id uuid default null,
  p_due_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  process public.employee_onboardings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('documents.onboarding.edit') then
    raise exception 'Нет права изменять оформление';
  end if;

  select * into process
  from public.employee_onboardings
  where id = p_onboarding_id
    and company_id = public.current_user_company_id()
  for update;

  if not found then
    raise exception 'Оформление не найдено';
  end if;
  if process.status in ('completed', 'cancelled') then
    raise exception 'Завершённое оформление нельзя изменить';
  end if;

  update public.employee_onboardings
  set employee_id = coalesce(p_employee_id, employee_id),
      package_id = coalesce(p_package_id, package_id),
      object_id = coalesce(p_object_id, object_id),
      onboarding_type = coalesce(p_onboarding_type, onboarding_type),
      conditions = coalesce(p_conditions, conditions),
      recognized_data = coalesce(p_recognized_data, recognized_data),
      verification_data = coalesce(p_verification_data, verification_data),
      assigned_user_id = coalesce(p_assigned_user_id, assigned_user_id),
      due_at = coalesce(p_due_at, due_at)
  where id = p_onboarding_id;

  update public.employee_document_files
  set employee_id = coalesce(p_employee_id, employee_id)
  where onboarding_id = p_onboarding_id;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    process.company_id, process.id, coalesce(p_employee_id, process.employee_id),
    'employee_onboarding', process.id::text, 'context_updated', auth.uid(),
    jsonb_strip_nulls(jsonb_build_object(
      'employee_id', p_employee_id,
      'package_id', p_package_id,
      'object_id', p_object_id,
      'onboarding_type', p_onboarding_type,
      'assigned_user_id', p_assigned_user_id,
      'due_at', p_due_at
    ))
  );
end;
$$;

revoke all on function public.set_document_onboarding_context(
  uuid, uuid, uuid, uuid, text, jsonb, jsonb, jsonb, uuid, timestamptz
) from public, anon;
grant execute on function public.set_document_onboarding_context(
  uuid, uuid, uuid, uuid, text, jsonb, jsonb, jsonb, uuid, timestamptz
) to authenticated;

create or replace function public.replace_document_package_templates(
  p_company_id uuid,
  p_package_id uuid,
  p_templates jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item jsonb;
  template_id uuid;
  template_required boolean;
  template_order integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if p_company_id is distinct from public.current_user_company_id() then
    raise exception 'Недоступная компания';
  end if;
  if not public.current_user_has_permission('documents.packages.manage') then
    raise exception 'Нет права изменять пакеты документов';
  end if;
  if jsonb_typeof(coalesce(p_templates, '[]'::jsonb)) <> 'array' then
    raise exception 'Список шаблонов имеет неверный формат';
  end if;
  if not exists (
    select 1 from public.document_packages package
    where package.id = p_package_id
      and package.company_id = p_company_id
  ) then
    raise exception 'Пакет не найден';
  end if;

  delete from public.document_package_templates
  where package_id = p_package_id
    and company_id = p_company_id;

  for item in select value from jsonb_array_elements(coalesce(p_templates, '[]'::jsonb))
  loop
    template_id := nullif(item->>'template_id', '')::uuid;
    template_required := coalesce((item->>'required')::boolean, true);

    if template_id is null or not exists (
      select 1
      from public.document_templates template
      where template.id = template_id
        and template.status = 'active'
        and template.current_version_id is not null
        and (template.company_id is null or template.company_id = p_company_id)
    ) then
      raise exception 'В пакет можно добавить только утверждённый шаблон с активной версией';
    end if;

    insert into public.document_package_templates (
      company_id, package_id, template_id, sort_order, is_required
    )
    values (
      p_company_id, p_package_id, template_id, template_order, template_required
    );

    template_order := template_order + 1;
  end loop;

  insert into public.document_audit_log (
    company_id, entity_type, entity_id, action, actor_user_id, details
  )
  values (
    p_company_id, 'document_package', p_package_id::text,
    'templates_replaced', auth.uid(),
    jsonb_build_object('count', template_order)
  );
end;
$$;

revoke all on function public.replace_document_package_templates(uuid, uuid, jsonb)
from public, anon;
grant execute on function public.replace_document_package_templates(uuid, uuid, jsonb)
to authenticated;

create or replace function public.seed_default_document_packages(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  gph_package_id uuid;
  employment_package_id uuid;
  transfer_package_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if p_company_id is distinct from public.current_user_company_id() then
    raise exception 'Недоступная компания';
  end if;
  if not public.current_user_has_permission('documents.packages.manage') then
    raise exception 'Нет права создавать пакеты документов';
  end if;

  insert into public.document_packages (
    company_id, code, title, description, onboarding_type, is_active, created_by
  )
  values (
    p_company_id, 'gph', 'Оформление по ГПХ',
    'Договор ГПХ/оказания услуг, согласие, заявление и анкета исполнителя.',
    'gph', true, auth.uid()
  )
  on conflict (company_id, code) do update
  set title = excluded.title,
      description = excluded.description,
      onboarding_type = excluded.onboarding_type,
      is_active = true
  returning id into gph_package_id;

  insert into public.document_packages (
    company_id, code, title, description, onboarding_type, is_active, created_by
  )
  values (
    p_company_id, 'employment', 'Приём по трудовому договору',
    'Трудовой договор, заявления, согласие и анкета.',
    'employment', true, auth.uid()
  )
  on conflict (company_id, code) do update
  set title = excluded.title,
      description = excluded.description,
      onboarding_type = excluded.onboarding_type
  returning id into employment_package_id;

  insert into public.document_packages (
    company_id, code, title, description, onboarding_type, is_active, created_by
  )
  values (
    p_company_id, 'transfer', 'Перевод или изменение условий',
    'Дополнительное соглашение, заявление и уведомление.',
    'transfer', true, auth.uid()
  )
  on conflict (company_id, code) do update
  set title = excluded.title,
      description = excluded.description,
      onboarding_type = excluded.onboarding_type
  returning id into transfer_package_id;

  insert into public.document_package_templates (
    company_id, package_id, template_id, sort_order, is_required
  )
  select
    p_company_id,
    gph_package_id,
    template.id,
    row_number() over (order by
      case template.code
        when 'personal_data_consent' then 1
        when 'salary_transfer_application' then 2
        when 'employment_application' then 3
        else 99
      end
    ) - 1,
    true
  from public.document_templates template
  where template.code in (
      'personal_data_consent',
      'salary_transfer_application',
      'employment_application',
      'gph_contract',
      'service_contract',
      'contractor_questionnaire'
    )
    and template.status = 'active'
    and template.current_version_id is not null
    and (template.company_id is null or template.company_id = p_company_id)
  on conflict (package_id, template_id) do nothing;

  insert into public.document_package_templates (
    company_id, package_id, template_id, sort_order, is_required
  )
  select
    p_company_id,
    employment_package_id,
    template.id,
    row_number() over (order by
      case template.code
        when 'employment_contract' then 1
        when 'employment_application' then 2
        when 'personal_data_consent' then 3
        when 'salary_transfer_application' then 4
        else 99
      end
    ) - 1,
    true
  from public.document_templates template
  where template.code in (
      'employment_contract',
      'employment_application',
      'personal_data_consent',
      'salary_transfer_application',
      'employee_questionnaire'
    )
    and template.status = 'active'
    and template.current_version_id is not null
    and (template.company_id is null or template.company_id = p_company_id)
  on conflict (package_id, template_id) do nothing;

  insert into public.document_audit_log (
    company_id, entity_type, entity_id, action, actor_user_id, details
  )
  values (
    p_company_id, 'document_packages', p_company_id::text,
    'defaults_seeded', auth.uid(),
    jsonb_build_object(
      'gph_package_id', gph_package_id,
      'employment_package_id', employment_package_id,
      'transfer_package_id', transfer_package_id
    )
  );
end;
$$;

revoke all on function public.seed_default_document_packages(uuid) from public, anon;
grant execute on function public.seed_default_document_packages(uuid) to authenticated;

create or replace function public.document_onboarding_blockers(p_onboarding_id uuid)
returns table(code text, message text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  process public.employee_onboardings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('documents.workflow.view') then
    raise exception 'Нет права просматривать оформление';
  end if;

  select * into process
  from public.employee_onboardings
  where id = p_onboarding_id
    and company_id = public.current_user_company_id();

  if not found then
    raise exception 'Оформление не найдено';
  end if;

  return query
  select
    'step:' || step.step_code,
    'Не завершён обязательный этап: ' || step.step_code
  from public.employee_onboarding_steps step
  where step.onboarding_id = p_onboarding_id
    and step.is_required
    and step.step_code <> 'completion'
    and step.status <> 'completed';

  if process.employee_id is null then
    code := 'employee';
    message := 'Не создана или не выбрана карточка сотрудника';
    return next;
  end if;

  if process.package_id is null then
    code := 'package';
    message := 'Не выбран пакет документов';
    return next;
  end if;

  if coalesce((process.verification_data->>'hr_confirmed')::boolean, false) is not true then
    code := 'hr_verification';
    message := 'HR не подтвердил распознанные данные';
    return next;
  end if;

  if not exists (
    select 1
    from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id
      and file.file_kind = 'generated'
  ) then
    code := 'generated_documents';
    message := 'Нет сформированного документа';
    return next;
  end if;

  if not exists (
    select 1
    from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id
      and file.file_kind = 'signed'
      and file.verification_status = 'accepted'
  ) then
    code := 'signed_documents';
    message := 'Нет проверенного подписанного документа';
    return next;
  end if;

  if not exists (
    select 1
    from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id
      and file.file_kind = 'final_scan'
      and file.verification_status = 'accepted'
  ) then
    code := 'final_scans';
    message := 'Нет проверенного финального скана';
    return next;
  end if;
end;
$$;

revoke all on function public.document_onboarding_blockers(uuid) from public, anon;
grant execute on function public.document_onboarding_blockers(uuid) to authenticated;

create or replace function public.complete_document_onboarding(p_onboarding_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  process public.employee_onboardings%rowtype;
  blockers jsonb;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('documents.onboarding.verify') then
    raise exception 'Завершить оформление может пользователь с правом проверки';
  end if;

  select * into process
  from public.employee_onboardings
  where id = p_onboarding_id
    and company_id = public.current_user_company_id()
  for update;

  if not found then
    raise exception 'Оформление не найдено';
  end if;
  if process.status = 'completed' then
    return;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('code', item.code, 'message', item.message)), '[]'::jsonb)
    into blockers
  from public.document_onboarding_blockers(p_onboarding_id) item;

  if jsonb_array_length(blockers) > 0 then
    raise exception 'Оформление не завершено: %', blockers::text;
  end if;

  update public.employee_onboarding_steps
  set status = 'completed',
      completed_at = coalesce(completed_at, now()),
      completed_by = coalesce(completed_by, auth.uid()),
      payload = payload || jsonb_build_object('completed', true)
  where onboarding_id = p_onboarding_id
    and step_code = 'completion';

  update public.employee_onboardings
  set status = 'completed',
      current_step = 'completion',
      completed_at = now(),
      completed_by = auth.uid(),
      completion_snapshot = jsonb_build_object(
        'completed_at', now(),
        'employee_id', employee_id,
        'package_id', package_id,
        'object_id', object_id,
        'generated_files', (
          select count(*) from public.employee_document_files file
          where file.onboarding_id = p_onboarding_id and file.file_kind = 'generated'
        ),
        'signed_files', (
          select count(*) from public.employee_document_files file
          where file.onboarding_id = p_onboarding_id
            and file.file_kind = 'signed'
            and file.verification_status = 'accepted'
        ),
        'final_scans', (
          select count(*) from public.employee_document_files file
          where file.onboarding_id = p_onboarding_id
            and file.file_kind = 'final_scan'
            and file.verification_status = 'accepted'
        )
      )
  where id = p_onboarding_id;

  if process.recruitment_application_id is not null and process.employee_id is not null then
    update public.recruitment_applications
    set employee_id = process.employee_id,
        updated_at = now()
    where id = process.recruitment_application_id
      and company_id = process.company_id;
  end if;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    process.company_id, process.id, process.employee_id,
    'employee_onboarding', process.id::text,
    'completed', auth.uid(), blockers
  );
end;
$$;

revoke all on function public.complete_document_onboarding(uuid) from public, anon;
grant execute on function public.complete_document_onboarding(uuid) to authenticated;

create or replace function public.advance_document_onboarding(
  p_onboarding_id uuid,
  p_step_code text,
  p_payload jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  process public.employee_onboardings%rowtype;
  step_index integer;
  next_step text;
  ordered_steps constant text[] := array[
    'source_files', 'source_completeness', 'recognition', 'hr_verification',
    'employee_card', 'package_and_conditions', 'generation', 'printing',
    'signing', 'signed_documents', 'final_scans', 'archive_verification',
    'completion'
  ];
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;

  select * into process
  from public.employee_onboardings
  where id = p_onboarding_id
    and company_id = public.current_user_company_id()
  for update;

  if not found then
    raise exception 'Оформление не найдено';
  end if;
  if process.status in ('completed', 'cancelled') then
    raise exception 'Процесс уже закрыт';
  end if;
  if process.current_step <> p_step_code then
    raise exception 'Сначала завершите текущий этап: %', process.current_step;
  end if;

  if p_step_code in (
    'hr_verification', 'signed_documents', 'final_scans', 'archive_verification'
  ) then
    if not public.current_user_has_permission('documents.onboarding.verify') then
      raise exception 'Этот этап должен подтвердить пользователь с правом проверки';
    end if;
  elsif not public.current_user_has_permission('documents.onboarding.edit') then
    raise exception 'Нет права вести оформление';
  end if;

  if p_step_code = 'source_files' and not exists (
    select 1 from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id and file.file_kind = 'source'
  ) then
    raise exception 'Загрузите хотя бы один исходный документ';
  end if;

  if p_step_code = 'source_completeness'
     and coalesce((p_payload->>'confirmed')::boolean, false) is not true then
    raise exception 'Подтвердите комплектность исходных документов';
  end if;

  if p_step_code = 'recognition' and jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then
    raise exception 'Данные распознавания имеют неверный формат';
  end if;

  if p_step_code = 'hr_verification'
     and coalesce((p_payload->>'hr_confirmed')::boolean, false) is not true then
    raise exception 'Подтвердите ручную проверку распознанных данных';
  end if;

  if p_step_code = 'employee_card' and process.employee_id is null then
    raise exception 'Создайте или выберите карточку сотрудника';
  end if;

  if p_step_code = 'package_and_conditions' and process.package_id is null then
    raise exception 'Выберите пакет документов';
  end if;

  if p_step_code = 'generation' and not exists (
    select 1 from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id and file.file_kind = 'generated'
  ) then
    raise exception 'Сформируйте или загрузите документ по утверждённому шаблону';
  end if;

  if p_step_code = 'printing'
     and coalesce((p_payload->>'printed')::boolean, false) is not true then
    raise exception 'Подтвердите передачу документов на печать';
  end if;

  if p_step_code = 'signing'
     and coalesce((p_payload->>'signed')::boolean, false) is not true then
    raise exception 'Подтвердите факт подписания';
  end if;

  if p_step_code = 'signed_documents' and not exists (
    select 1 from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id
      and file.file_kind = 'signed'
      and file.verification_status = 'accepted'
  ) then
    raise exception 'Загрузите и примите хотя бы один подписанный документ';
  end if;

  if p_step_code = 'final_scans' and not exists (
    select 1 from public.employee_document_files file
    where file.onboarding_id = p_onboarding_id
      and file.file_kind = 'final_scan'
      and file.verification_status = 'accepted'
  ) then
    raise exception 'Загрузите и примите хотя бы один финальный скан';
  end if;

  if p_step_code = 'archive_verification'
     and coalesce((p_payload->>'archive_confirmed')::boolean, false) is not true then
    raise exception 'Подтвердите проверку архива';
  end if;

  update public.employee_onboarding_steps
  set status = 'completed',
      payload = coalesce(p_payload, '{}'::jsonb),
      completed_at = now(),
      completed_by = auth.uid()
  where onboarding_id = p_onboarding_id
    and step_code = p_step_code;

  if p_step_code = 'recognition' then
    update public.employee_onboardings
    set recognized_data = coalesce(p_payload, '{}'::jsonb)
    where id = p_onboarding_id;
  elsif p_step_code = 'hr_verification' then
    update public.employee_onboardings
    set verification_data = coalesce(p_payload, '{}'::jsonb)
    where id = p_onboarding_id;
  end if;

  step_index := array_position(ordered_steps, p_step_code);
  if step_index is null then
    raise exception 'Неизвестный этап';
  end if;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    process.company_id, process.id, process.employee_id,
    'employee_onboarding_step', process.id::text || ':' || p_step_code,
    'completed', auth.uid(), coalesce(p_payload, '{}'::jsonb)
  );

  if p_step_code = 'completion' then
    perform public.complete_document_onboarding(p_onboarding_id);
    return 'completed';
  end if;

  next_step := ordered_steps[step_index + 1];

  update public.employee_onboarding_steps
  set status = 'in_progress'
  where onboarding_id = p_onboarding_id
    and step_code = next_step
    and status = 'pending';

  update public.employee_onboardings
  set current_step = next_step,
      status = 'in_progress'
  where id = p_onboarding_id;

  return next_step;
end;
$$;

revoke all on function public.advance_document_onboarding(uuid, text, jsonb)
from public, anon;
grant execute on function public.advance_document_onboarding(uuid, text, jsonb)
to authenticated;

create or replace function public.verify_employee_document_file(
  p_file_id uuid,
  p_accepted boolean,
  p_quality_status text default 'accepted',
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  file_row public.employee_document_files%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('documents.onboarding.verify') then
    raise exception 'Нет права проверять документы';
  end if;

  select * into file_row
  from public.employee_document_files
  where id = p_file_id
    and company_id = public.current_user_company_id()
  for update;

  if not found then
    raise exception 'Файл не найден';
  end if;

  update public.employee_document_files
  set verification_status = case when p_accepted then 'accepted' else 'rejected' end,
      quality_status = case
        when p_accepted then coalesce(nullif(p_quality_status, ''), 'accepted')
        else 'rejected'
      end,
      verified_by = auth.uid(),
      verified_at = now(),
      metadata = metadata || jsonb_build_object('verification_comment', coalesce(p_comment, ''))
  where id = p_file_id;

  insert into public.document_audit_log (
    company_id, onboarding_id, employee_id, entity_type, entity_id,
    action, actor_user_id, details
  )
  values (
    file_row.company_id, file_row.onboarding_id, file_row.employee_id,
    'employee_document_file', file_row.id::text,
    case when p_accepted then 'accepted' else 'rejected' end,
    auth.uid(),
    jsonb_build_object(
      'quality_status', p_quality_status,
      'comment', coalesce(p_comment, '')
    )
  );
end;
$$;

revoke all on function public.verify_employee_document_file(uuid, boolean, text, text)
from public, anon;
grant execute on function public.verify_employee_document_file(uuid, boolean, text, text)
to authenticated;

-- Keep the existing employee-id-first policies for legacy employee archives.
-- New workflow files use company-id as the first segment and receive separate policies.
drop policy if exists document_workflow_files_select on storage.objects;
drop policy if exists document_workflow_files_insert on storage.objects;
drop policy if exists document_workflow_files_delete on storage.objects;

create policy document_workflow_files_select
on storage.objects for select to authenticated
using (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and public.current_user_has_permission('documents.workflow.view')
);

create policy document_workflow_files_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and public.current_user_has_permission('documents.onboarding.edit')
);

create policy document_workflow_files_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'employee-documents'
  and (storage.foldername(name))[1] = (select public.current_user_company_id())::text
  and owner_id = (select auth.uid()::text)
  and public.current_user_has_permission('documents.onboarding.edit')
);

revoke all on function public.touch_document_workflow_updated_at() from public, anon;
revoke all on function public.validate_document_workflow_company() from public, anon;
