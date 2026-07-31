create index if not exists employee_tracking_gaps_employee_id_idx
  on public.employee_tracking_gaps (employee_id);

create index if not exists employee_tracking_gaps_created_by_idx
  on public.employee_tracking_gaps (created_by)
  where created_by is not null;
