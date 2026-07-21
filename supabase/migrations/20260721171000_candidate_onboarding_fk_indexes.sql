create index if not exists recruitment_applications_employee_id_fk_idx
  on public.recruitment_applications (employee_id);

create index if not exists recruitment_onboarding_forms_created_by_fk_idx
  on public.recruitment_onboarding_forms (created_by)
  where created_by is not null;

create index if not exists recruitment_onboarding_forms_updated_by_fk_idx
  on public.recruitment_onboarding_forms (updated_by)
  where updated_by is not null;
