create schema if not exists private;

create or replace function private.broadcast_app_data_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  changed_row jsonb;
  changed_company_id text;
begin
  changed_row := case
    when tg_op = 'DELETE' then to_jsonb(old)
    else to_jsonb(new)
  end;
  changed_company_id := nullif(changed_row ->> 'company_id', '');

  if changed_company_id is null then
    return null;
  end if;

  perform realtime.send(
    jsonb_strip_nulls(
      jsonb_build_object(
        'table', tg_table_name,
        'operation', tg_op,
        'object_name', changed_row ->> 'object_name',
        'work_date', changed_row ->> 'work_date',
        'task_date', changed_row ->> 'task_date',
        'period_year', changed_row ->> 'period_year',
        'period_month', changed_row ->> 'period_month',
        'employee_id', changed_row ->> 'employee_id',
        'task_id', changed_row ->> 'task_id',
        'payment_id', changed_row ->> 'payment_id'
      )
    ),
    'app_data_changed',
    'company:' || changed_company_id || ':data',
    true
  );

  return null;
end;
$function$;

revoke all on function private.broadcast_app_data_change()
from public, anon, authenticated;

do $block$
declare
  table_name text;
begin
  foreach table_name in array array[
    'attendance',
    'payments',
    'payment_receipts',
    'employees',
    'employee_comments',
    'employee_private_data',
    'tasks',
    'task_assignees',
    'task_photos',
    'objects',
    'app_notifications'
  ]
  loop
    execute format(
      'drop trigger if exists app_data_broadcast_after_change on public.%I',
      table_name
    );
    execute format(
      'create trigger app_data_broadcast_after_change after insert or update or delete on public.%I for each row execute function private.broadcast_app_data_change()',
      table_name
    );
  end loop;
end;
$block$;

drop policy if exists "company members receive app data broadcasts"
on realtime.messages;

create policy "company members receive app data broadcasts"
on realtime.messages
for select
to authenticated
using (
  extension = 'broadcast'
  and realtime.topic() =
    'company:' || (select public.current_user_company_id())::text || ':data'
);
