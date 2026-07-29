create index if not exists employee_max_login_attempts_company_idx
  on public.employee_max_login_attempts (company_id);

create index if not exists employee_max_login_attempts_person_idx
  on public.employee_max_login_attempts (person_id);

create index if not exists employee_max_login_attempts_user_idx
  on public.employee_max_login_attempts (user_id);
