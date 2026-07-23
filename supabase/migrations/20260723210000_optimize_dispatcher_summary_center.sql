create or replace function public.get_dispatcher_summary_center()
returns jsonb
language plpgsql
security definer
set search_path to public, pg_temp
as $body$
declare
  v_company_id uuid := public.current_user_company_id();
  v_settings public.dispatcher_summary_settings%rowtype;
  v_runs jsonb;
  v_objects jsonb;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для настроек ИИ-диспетчера';
  end if;

  select * into v_settings
  from public.dispatcher_summary_settings
  where company_id = v_company_id;

  if not found then
    insert into public.dispatcher_summary_settings(company_id, updated_by)
    values(v_company_id, auth.uid())
    returning * into v_settings;
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object('id', object_row.id, 'name', object_row.name)
             order by object_row.name
           ),
           '[]'::jsonb
         )
  into v_objects
  from public.objects object_row
  where object_row.company_id = v_company_id
    and object_row.is_active = true;

  select coalesce(
           jsonb_agg(to_jsonb(run_row) order by run_row.created_at desc),
           '[]'::jsonb
         )
  into v_runs
  from (
    select id, object_id, object_name, summary_date, scheduled_for, status,
           title, body, payload, ai_used, error_text, sent_at, attempts,
           created_at
    from public.dispatcher_summary_runs
    where company_id = v_company_id
    order by created_at desc
    limit 30
  ) run_row;

  return jsonb_build_object(
    'settings', to_jsonb(v_settings),
    'objects', v_objects,
    'runs', v_runs,
    'server_time', now()
  );
end;
$body$;
