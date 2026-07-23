create or replace function public.notification_event_group(p_entity_type text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when lower(coalesce(p_entity_type, '')) in (
      'tasks', 'task', 'task_assignees', 'task_assignee',
      'task_photos', 'task_photo', 'brigade_photo', 'foreman_reminder',
      'task_missing_photo', 'operational_overdue_tasks',
      'operational_missing_photos'
    ) then 'tasks'
    when lower(coalesce(p_entity_type, '')) in (
      'attendance', 'timesheet', 'timesheet_missing',
      'operational_timesheet_missing'
    ) then 'attendance'
    when lower(coalesce(p_entity_type, '')) in (
      'employees', 'employee', 'employee_private_data',
      'employee_documents', 'employee_comment', 'employee_profile',
      'operational_missing_rate'
    ) then 'employees'
    when lower(coalesce(p_entity_type, '')) in (
      'recruitment_application', 'recruitment_applications',
      'recruitment_message', 'recruitment_messages',
      'recruitment_document', 'recruitment_documents',
      'recruitment_vacancy', 'employee_mobilization', 'hr_reminder'
    ) then 'hr'
    when lower(coalesce(p_entity_type, '')) in (
      'payments', 'payment', 'payment_receipts', 'payment_receipt',
      'payment_missing_receipt', 'accountant_reminder',
      'operational_payment_debt'
    ) then 'payments'
    when lower(coalesce(p_entity_type, '')) like 'legal_%'
      or lower(coalesce(p_entity_type, '')) in (
        'legal_document', 'legal_matter', 'legal_report',
        'legal_approval', 'lawyer_reminder',
        'operational_document_deadline',
        'operational_document_approval'
      ) then 'legal'
    else 'system'
  end;
$$;
