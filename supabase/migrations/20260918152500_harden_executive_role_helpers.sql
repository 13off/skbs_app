-- Harden helper introduced/overridden by the executive role migration.
alter function public.normalize_notification_role(text)
  set search_path = public, pg_temp;
