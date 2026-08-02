-- Cover document workflow foreign keys reported by the Supabase advisor.
-- Indexes are additive and do not change existing data or behavior.

create index if not exists document_tool_installations_enabled_by_idx
  on public.document_tool_installations(enabled_by)
  where enabled_by is not null;

create index if not exists document_packages_created_by_idx
  on public.document_packages(created_by)
  where created_by is not null;

create index if not exists document_package_templates_company_idx
  on public.document_package_templates(company_id);

create index if not exists employee_onboardings_created_by_idx
  on public.employee_onboardings(created_by)
  where created_by is not null;

create index if not exists employee_onboardings_completed_by_idx
  on public.employee_onboardings(completed_by)
  where completed_by is not null;

create index if not exists employee_onboarding_steps_company_idx
  on public.employee_onboarding_steps(company_id);

create index if not exists employee_onboarding_steps_completed_by_idx
  on public.employee_onboarding_steps(completed_by)
  where completed_by is not null;

create index if not exists employee_document_files_recruitment_document_idx
  on public.employee_document_files(recruitment_document_id)
  where recruitment_document_id is not null;

create index if not exists employee_document_files_recruitment_form_idx
  on public.employee_document_files(recruitment_onboarding_form_id)
  where recruitment_onboarding_form_id is not null;

create index if not exists employee_document_files_template_id_idx
  on public.employee_document_files(template_id)
  where template_id is not null;

create index if not exists employee_document_files_uploaded_by_idx
  on public.employee_document_files(uploaded_by)
  where uploaded_by is not null;

create index if not exists employee_document_files_verified_by_idx
  on public.employee_document_files(verified_by)
  where verified_by is not null;

create index if not exists document_audit_log_employee_idx
  on public.document_audit_log(employee_id, created_at desc)
  where employee_id is not null;

create index if not exists document_audit_log_actor_idx
  on public.document_audit_log(actor_user_id, created_at desc)
  where actor_user_id is not null;
