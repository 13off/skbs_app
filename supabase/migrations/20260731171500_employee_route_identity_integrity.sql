-- Маршрут всегда принадлежит тому же сотруднику и той же компании,
-- что и родительская рабочая смена. ФИО при показе маршрута берётся
-- из employees по этому неизменяемому employee_id, а не хранится копией.

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'employee_work_shifts_company_shift_employee_key'
      and conrelid = 'public.employee_work_shifts'::regclass
  ) then
    alter table public.employee_work_shifts
      add constraint employee_work_shifts_company_shift_employee_key
      unique (company_id, id, employee_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'employee_work_shift_points_shift_identity_fkey'
      and conrelid = 'public.employee_work_shift_points'::regclass
  ) then
    alter table public.employee_work_shift_points
      add constraint employee_work_shift_points_shift_identity_fkey
      foreign key (company_id, shift_id, employee_id)
      references public.employee_work_shifts (company_id, id, employee_id)
      on delete cascade
      not valid;
  end if;
end
$$;

alter table public.employee_work_shift_points
  validate constraint employee_work_shift_points_shift_identity_fkey;
