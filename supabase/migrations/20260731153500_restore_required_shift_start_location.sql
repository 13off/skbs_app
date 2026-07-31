begin;

drop function if exists public.start_employee_shift_without_location(uuid, date);
drop function if exists public.finish_employee_shift_without_location(uuid);

alter table public.employee_work_shifts
  alter column start_latitude set not null,
  alter column start_longitude set not null,
  alter column start_accuracy_m set not null;

comment on column public.employee_work_shifts.start_latitude is
  'Реальная широта обязательной начальной точки рабочего дня.';
comment on column public.employee_work_shifts.start_longitude is
  'Реальная долгота обязательной начальной точки рабочего дня.';
comment on column public.employee_work_shifts.start_accuracy_m is
  'Точность обязательной начальной точки рабочего дня.';

commit;
