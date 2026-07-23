do $$
declare
  existing_job record;
begin
  for existing_job in
    select jobid from cron.job where jobname = 'operational-notification-refresh'
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'operational-notification-refresh',
  '15 * * * *',
  'select private.refresh_all_operational_notifications();'
);
