create or replace function public.get_data_governance_center(
  p_object_id uuid default null,
  p_entity_type text default null,
  p_limit integer default 250
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_limit integer := greatest(20, least(coalesce(p_limit, 250), 500));
begin
  if v_company_id is null
     or not (
       public.current_user_has_permission('system.audit.view')
       or public.current_user_has_permission('system.recycle_bin.manage')
     ) then
    raise exception 'Недостаточно прав для общего контроля данных';
  end if;

  if p_object_id is not null and not exists (
    select 1 from public.objects object_row
    where object_row.id = p_object_id
      and object_row.company_id = v_company_id
  ) then
    raise exception 'Объект не найден';
  end if;

  return jsonb_build_object(
    'objects', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', object_row.id,
        'name', object_row.name,
        'is_active', object_row.is_active
      ) order by object_row.is_active desc, lower(object_row.name))
      from public.objects object_row
      where object_row.company_id = v_company_id
    ), '[]'::jsonb),
    'trash', coalesce((
      with trash_rows as (
        select
          'task'::text entity_type,
          task_row.id::text entity_id,
          coalesce(nullif(task_row.work, ''), 'Задача') title,
          concat_ws(' • ', nullif(task_row.axes, ''), task_row.status,
            to_char(task_row.task_date, 'DD.MM.YYYY')) subtitle,
          task_row.object_id,
          task_row.object_name,
          task_row.deleted_at,
          task_row.delete_reason,
          coalesce(nullif(profile.full_name, ''), nullif(profile.email, ''), '') deleted_by_name,
          jsonb_build_object('task_date', task_row.task_date, 'status', task_row.status) metadata
        from public.tasks task_row
        left join public.user_profiles profile on profile.id = task_row.deleted_by
        where task_row.company_id = v_company_id and task_row.deleted_at is not null

        union all

        select
          'attendance', attendance_row.id::text,
          coalesce(nullif(employee.fio, ''), 'Запись табеля'),
          concat_ws(' • ', to_char(attendance_row.work_date, 'DD.MM.YYYY'),
            attendance_row.status, attendance_row.shifts::text || ' смен.'),
          attendance_row.object_id, attendance_row.object_name,
          attendance_row.deleted_at, attendance_row.delete_reason,
          coalesce(nullif(profile.full_name, ''), nullif(profile.email, ''), ''),
          jsonb_build_object('employee_id', attendance_row.employee_id,
            'work_date', attendance_row.work_date, 'status', attendance_row.status,
            'shifts', attendance_row.shifts, 'hours', attendance_row.hours)
        from public.attendance attendance_row
        left join public.employees employee
          on employee.id = attendance_row.employee_id
         and employee.company_id = attendance_row.company_id
        left join public.user_profiles profile on profile.id = attendance_row.deleted_by
        where attendance_row.company_id = v_company_id and attendance_row.deleted_at is not null

        union all

        select
          'payment', payment_row.id::text,
          coalesce(nullif(employee.fio, ''), 'Выплата'),
          concat_ws(' • ', to_char(payment_row.payment_date, 'DD.MM.YYYY'),
            trim(to_char(payment_row.amount, 'FM999999999990D00')) || ' ₽',
            nullif(payment_row.payment_type, '')),
          payment_row.object_id, coalesce(object_row.name, employee.object_name, ''),
          payment_row.deleted_at, payment_row.delete_reason,
          coalesce(nullif(profile.full_name, ''), nullif(profile.email, ''), ''),
          jsonb_build_object('employee_id', payment_row.employee_id,
            'payment_date', payment_row.payment_date, 'amount', payment_row.amount,
            'payment_type', payment_row.payment_type)
        from public.payments payment_row
        left join public.employees employee
          on employee.id = payment_row.employee_id
         and employee.company_id = payment_row.company_id
        left join public.objects object_row
          on object_row.id = payment_row.object_id
         and object_row.company_id = payment_row.company_id
        left join public.user_profiles profile on profile.id = payment_row.deleted_by
        where payment_row.company_id = v_company_id and payment_row.deleted_at is not null

        union all

        select
          'milestone', milestone.id::text,
          coalesce(nullif(milestone.title, ''), 'Цель или этап'),
          concat_ws(' • ', nullif(milestone.location, ''), milestone.status,
            to_char(milestone.target_date, 'DD.MM.YYYY')),
          milestone.object_id, milestone.object_name, milestone.deleted_at,
          milestone.delete_reason,
          coalesce(nullif(profile.full_name, ''), nullif(profile.email, ''), ''),
          jsonb_build_object('target_date', milestone.target_date,
            'status', milestone.status, 'location', milestone.location)
        from public.project_milestones milestone
        left join public.user_profiles profile on profile.id = milestone.deleted_by
        where milestone.company_id = v_company_id and milestone.deleted_at is not null

        union all

        select
          'employee', employee.id::text,
          coalesce(nullif(employee.fio, ''), 'Сотрудник'),
          concat_ws(' • ', nullif(employee.position, ''), nullif(employee.phone, '')),
          employee.object_id, employee.object_name, employee.archived_at,
          'Сотрудник в архиве', '',
          jsonb_build_object('position', employee.position, 'phone', employee.phone)
        from public.employees employee
        where employee.company_id = v_company_id
          and not employee.is_active and employee.archived_at is not null

        union all

        select
          'object', object_row.id::text, object_row.name,
          concat_ws(' • ', nullif(object_row.address, ''), nullif(object_row.comment, '')),
          object_row.id, object_row.name, object_row.updated_at,
          'Объект в архиве', '', jsonb_build_object('address', object_row.address)
        from public.objects object_row
        where object_row.company_id = v_company_id and not object_row.is_active

        union all

        select
          'legal_document', document.id::text, document.title,
          concat_ws(' • ', document.document_type,
            nullif(document.document_number, ''), document.status),
          document.object_id, coalesce(object_row.name, ''), document.archived_at,
          'Документ в архиве', '',
          jsonb_build_object('document_type', document.document_type,
            'document_number', document.document_number, 'status', document.status)
        from public.legal_documents document
        left join public.objects object_row
          on object_row.id = document.object_id
         and object_row.company_id = document.company_id
        where document.company_id = v_company_id and document.archived_at is not null
      )
      select jsonb_agg(jsonb_build_object(
        'entity_type', row_item.entity_type,
        'entity_id', row_item.entity_id,
        'title', row_item.title,
        'subtitle', row_item.subtitle,
        'object_id', row_item.object_id,
        'object_name', row_item.object_name,
        'deleted_at', row_item.deleted_at,
        'delete_reason', row_item.delete_reason,
        'deleted_by_name', row_item.deleted_by_name,
        'metadata', row_item.metadata
      ) order by row_item.deleted_at desc nulls last)
      from (
        select * from trash_rows
        where (p_object_id is null or object_id = p_object_id)
          and (nullif(btrim(coalesce(p_entity_type, '')), '') is null
            or entity_type = p_entity_type)
        order by deleted_at desc nulls last
        limit v_limit
      ) row_item
    ), '[]'::jsonb),
    'audit', coalesce((
      with audit_rows as (
        select
          audit.id::text audit_id, audit.entity_type, audit.entity_id,
          audit.action, audit.actor_user_id,
          coalesce(nullif(profile.full_name, ''), nullif(profile.email, ''), '') actor_name,
          audit.created_at,
          coalesce(nullif(audit.after_data ->> 'object_id', ''),
            nullif(audit.before_data ->> 'object_id', ''))::uuid object_id,
          coalesce(nullif(audit.after_data ->> 'object_name', ''),
            nullif(audit.before_data ->> 'object_name', ''),
            nullif(audit.after_data ->> 'name', ''),
            nullif(audit.before_data ->> 'name', ''), '') object_name,
          audit.before_data, audit.after_data, audit.changed_fields metadata
        from public.audit_log audit
        left join public.user_profiles profile on profile.id = audit.actor_user_id
        where audit.company_id = v_company_id

        union all

        select
          ('task-' || task_audit.id::text), 'task', task_audit.task_id::text,
          task_audit.action, task_audit.actor_user_id, task_audit.actor_name,
          task_audit.created_at, task_audit.object_id, task_audit.object_name,
          task_audit.before_value, task_audit.after_value, task_audit.metadata
        from public.task_action_audit task_audit
        where task_audit.company_id = v_company_id
      )
      select jsonb_agg(jsonb_build_object(
        'audit_id', row_item.audit_id,
        'entity_type', row_item.entity_type,
        'entity_id', row_item.entity_id,
        'action', row_item.action,
        'actor_name', row_item.actor_name,
        'created_at', row_item.created_at,
        'object_id', row_item.object_id,
        'object_name', row_item.object_name,
        'before_value', row_item.before_data,
        'after_value', row_item.after_data,
        'metadata', row_item.metadata
      ) order by row_item.created_at desc)
      from (
        select * from audit_rows
        where (p_object_id is null or object_id = p_object_id)
          and (nullif(btrim(coalesce(p_entity_type, '')), '') is null
            or entity_type = p_entity_type)
        order by created_at desc
        limit v_limit
      ) row_item
    ), '[]'::jsonb)
  );
end;
$$;
