-- One logical event should produce one push notification.
-- The generic notification already reaches owner/admin recipients through the normal dispatcher,
-- so the old manager-specific push-only copy is redundant and doubles delivery.
DROP TRIGGER IF EXISTS app_notifications_route_manager_push
ON public.app_notifications;

-- With the manager-copy route removed, directly targeted owner/admin notifications must use
-- the same normal push queue as every other recipient.
CREATE OR REPLACE FUNCTION private.queue_push_notification_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'net', 'pg_temp'
AS $function$
DECLARE
  v_job public.push_notification_jobs%ROWTYPE;
BEGIN
  IF NEW.push_requested IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.push_notification_jobs(notification_id)
  VALUES (NEW.id)
  ON CONFLICT(notification_id) DO UPDATE
    SET updated_at = now()
  RETURNING * INTO v_job;

  PERFORM net.http_post(
    url := 'https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/dispatch-push-job',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'job_id', v_job.id,
      'dispatch_token', v_job.dispatch_token
    ),
    timeout_milliseconds := 15000
  );

  RETURN NEW;
END;
$function$;

-- Keep insert/delete notifications unchanged, but do not emit "Изменена задача"
-- when an UPDATE changed only the technical updated_at timestamp.
DROP TRIGGER IF EXISTS app_notify_tasks ON public.tasks;
DROP TRIGGER IF EXISTS app_notify_tasks_insert ON public.tasks;
DROP TRIGGER IF EXISTS app_notify_tasks_update ON public.tasks;
DROP TRIGGER IF EXISTS app_notify_tasks_delete ON public.tasks;

CREATE TRIGGER app_notify_tasks_insert
AFTER INSERT ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.app_notify_change();

CREATE TRIGGER app_notify_tasks_update
AFTER UPDATE ON public.tasks
FOR EACH ROW
WHEN (
  (to_jsonb(OLD) - 'updated_at')
  IS DISTINCT FROM
  (to_jsonb(NEW) - 'updated_at')
)
EXECUTE FUNCTION public.app_notify_change();

CREATE TRIGGER app_notify_tasks_delete
AFTER DELETE ON public.tasks
FOR EACH ROW
EXECUTE FUNCTION public.app_notify_change();
