-- Покрывающие индексы для внешних ключей, добавленных после аудита 23.07.2026.
-- Они не меняют данные или правила доступа, но исключают полные сканирования
-- дочерних таблиц при проверке и каскадных операциях внешних ключей.

create index if not exists attendance_company_object_employee_fk_idx
  on public.attendance (company_id, object_id, employee_id);

create index if not exists company_chat_attachments_uploaded_by_fk_idx
  on public.company_chat_attachments (uploaded_by);

create index if not exists company_chat_messages_ai_requester_fk_idx
  on public.company_chat_messages (ai_requester_user_id);

create index if not exists company_chat_messages_deleted_by_fk_idx
  on public.company_chat_messages (deleted_by);

create index if not exists company_chat_messages_sender_user_fk_idx
  on public.company_chat_messages (sender_user_id);

create index if not exists company_chat_reads_user_fk_idx
  on public.company_chat_reads (user_id);

create index if not exists employee_account_links_created_by_fk_idx
  on public.employee_account_links (created_by);

create index if not exists employee_account_links_person_fk_idx
  on public.employee_account_links (person_id);

create index if not exists employee_work_shift_points_employee_fk_idx
  on public.employee_work_shift_points (employee_id);

create index if not exists employee_work_shift_points_identity_fk_idx
  on public.employee_work_shift_points (company_id, shift_id, employee_id);

create index if not exists employee_work_shifts_employee_fk_idx
  on public.employee_work_shifts (employee_id);

create index if not exists employee_work_shifts_ended_by_fk_idx
  on public.employee_work_shifts (ended_by);

create index if not exists employee_work_shifts_object_fk_idx
  on public.employee_work_shifts (object_id);

create index if not exists employee_work_shifts_started_by_fk_idx
  on public.employee_work_shifts (started_by);

create index if not exists employee_work_shifts_task_fk_idx
  on public.employee_work_shifts (task_id);

create index if not exists object_geofences_created_by_fk_idx
  on public.object_geofences (created_by);

create index if not exists object_geofences_object_fk_idx
  on public.object_geofences (object_id);

create index if not exists object_memberships_company_user_fk_idx
  on public.object_memberships (company_id, user_id);

create index if not exists payment_receipts_company_payment_fk_idx
  on public.payment_receipts (company_id, payment_id);

create index if not exists payments_company_object_employee_fk_idx
  on public.payments (company_id, object_id, employee_id);

create index if not exists recruitment_applications_responsible_user_fk_idx
  on public.recruitment_applications (responsible_user_id);

create index if not exists recruitment_crm_activities_actor_user_fk_idx
  on public.recruitment_crm_activities (actor_user_id);

create index if not exists recruitment_crm_automation_rules_assigned_to_fk_idx
  on public.recruitment_crm_automation_rules (assigned_to);

create index if not exists recruitment_crm_automation_rules_created_by_fk_idx
  on public.recruitment_crm_automation_rules (created_by);

create index if not exists recruitment_crm_automation_runs_application_fk_idx
  on public.recruitment_crm_automation_runs (company_id, application_id);

create index if not exists recruitment_crm_comments_created_by_fk_idx
  on public.recruitment_crm_comments (created_by);

create index if not exists recruitment_crm_saved_views_user_fk_idx
  on public.recruitment_crm_saved_views (user_id);

create index if not exists recruitment_crm_tasks_assigned_to_fk_idx
  on public.recruitment_crm_tasks (assigned_to);

create index if not exists recruitment_crm_tasks_completed_by_fk_idx
  on public.recruitment_crm_tasks (completed_by);

create index if not exists recruitment_crm_tasks_created_by_fk_idx
  on public.recruitment_crm_tasks (created_by);

create index if not exists task_employee_contributions_recorded_by_fk_idx
  on public.task_employee_contributions (recorded_by);
