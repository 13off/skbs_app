-- Manual rollback for 20260821123000_performance_preload_indexes_reports_images.sql.
-- Derived thumbnails may safely be discarded; originals remain in task-photos.

drop function if exists public.get_payment_totals_fast(uuid[], integer, integer, date, date, boolean);
drop function if exists public.get_monthly_timesheet_fast(integer, integer, text, boolean);
drop function if exists public.get_period_timesheet_fast(date, date, text, boolean);

drop index if exists public.attendance_hot_period_cover_idx;
drop index if exists public.payments_hot_employee_date_idx;
drop index if exists public.payments_hot_employee_period_idx;
drop index if exists public.tasks_hot_scope_date_idx;
drop index if exists public.employees_hot_scope_fio_idx;
drop index if exists public.task_photos_thumbnail_path_uidx;

alter table public.task_photos drop column if exists thumbnail_path;
