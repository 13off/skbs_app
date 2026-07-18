alter table public.dispatcher_summary_settings
  add column if not exists object_id uuid references public.objects(id) on delete set null,
  add column if not exists object_name text not null default '';

alter table public.dispatcher_summary_runs
  add column if not exists object_id uuid references public.objects(id) on delete set null,
  add column if not exists object_name text not null default '';

alter table public.dispatcher_summary_runs
  drop constraint if exists dispatcher_summary_runs_company_date_key;
create unique index if not exists dispatcher_summary_runs_company_object_date_key
  on public.dispatcher_summary_runs(company_id,object_id,summary_date)
  where object_id is not null;
create index if not exists dispatcher_summary_runs_object_idx
  on public.dispatcher_summary_runs(company_id,object_id,created_at desc);

create or replace function private.validate_dispatcher_summary_settings()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_object_name text;
begin
  if not exists(select 1 from pg_timezone_names where name=new.timezone) then
    raise exception 'Неизвестный часовой пояс: %',new.timezone;
  end if;
  new.weekdays:=array(select distinct value from unnest(new.weekdays)value order by value);
  new.recipient_roles:=array(select distinct value from unnest(new.recipient_roles)value order by value);
  if new.object_id is not null then
    select o.name into v_object_name
    from public.objects o
    where o.id=new.object_id and o.company_id=new.company_id and o.is_active=true;
    if not found then raise exception 'Выбранный объект не найден или отключён'; end if;
    new.object_name:=v_object_name;
  else
    new.object_name:='';
    if new.enabled then raise exception 'Выберите объект для ежедневной сводки'; end if;
  end if;
  new.updated_at:=now();
  new.updated_by:=coalesce(auth.uid(),new.updated_by);
  return new;
end;
$$;

create or replace function public.get_dispatcher_summary_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_settings public.dispatcher_summary_settings%rowtype;
  v_runs jsonb;
  v_objects jsonb;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для настроек ИИ-диспетчера';
  end if;
  insert into public.dispatcher_summary_settings(company_id,updated_by)
  values(v_company_id,auth.uid()) on conflict(company_id) do nothing;
  select * into v_settings
  from public.dispatcher_summary_settings where company_id=v_company_id;
  select coalesce(
    jsonb_agg(jsonb_build_object('id',o.id,'name',o.name) order by o.name),
    '[]'::jsonb
  ) into v_objects
  from public.objects o
  where o.company_id=v_company_id and o.is_active=true;
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc),'[]'::jsonb)
  into v_runs
  from (
    select id,object_id,object_name,summary_date,scheduled_for,status,title,body,
      payload,ai_used,error_text,sent_at,attempts,created_at
    from public.dispatcher_summary_runs
    where company_id=v_company_id
    order by created_at desc limit 30
  )r;
  return jsonb_build_object(
    'settings',to_jsonb(v_settings),'objects',v_objects,'runs',v_runs,'server_time',now());
end;
$$;

create or replace function public.save_dispatcher_summary_settings(p_settings jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_value public.dispatcher_summary_settings%rowtype;
  v_object_id uuid;
  v_enabled boolean:=coalesce((p_settings->>'enabled')::boolean,false);
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для настроек ИИ-диспетчера';
  end if;
  begin v_object_id:=nullif(btrim(p_settings->>'object_id'),'')::uuid;
  exception when others then raise exception 'Некорректный объект'; end;
  if v_enabled and v_object_id is null then
    raise exception 'Выберите объект для ежедневной сводки';
  end if;
  insert into public.dispatcher_summary_settings(
    company_id,object_id,enabled,local_time,timezone,weekdays,recipient_roles,
    in_app_enabled,push_enabled,include_tasks,include_attendance,include_employees,
    include_payments,include_recruitment,include_legal,include_milestones,
    include_empty_sections,ai_commentary,updated_by
  ) values (
    v_company_id,v_object_id,v_enabled,
    coalesce((p_settings->>'local_time')::time,'18:30'::time),
    coalesce(nullif(btrim(p_settings->>'timezone'),''),'Europe/Moscow'),
    coalesce(array(select jsonb_array_elements_text(p_settings->'weekdays')::smallint),array[1,2,3,4,5,6,7]::smallint[]),
    coalesce(array(select jsonb_array_elements_text(p_settings->'recipient_roles')),array['admin']::text[]),
    coalesce((p_settings->>'in_app_enabled')::boolean,true),
    coalesce((p_settings->>'push_enabled')::boolean,true),
    coalesce((p_settings->>'include_tasks')::boolean,true),
    coalesce((p_settings->>'include_attendance')::boolean,true),
    coalesce((p_settings->>'include_employees')::boolean,true),
    coalesce((p_settings->>'include_payments')::boolean,true),
    coalesce((p_settings->>'include_recruitment')::boolean,true),
    coalesce((p_settings->>'include_legal')::boolean,true),
    coalesce((p_settings->>'include_milestones')::boolean,true),
    coalesce((p_settings->>'include_empty_sections')::boolean,false),
    coalesce((p_settings->>'ai_commentary')::boolean,true),auth.uid()
  ) on conflict(company_id) do update set
    object_id=excluded.object_id,enabled=excluded.enabled,
    local_time=excluded.local_time,timezone=excluded.timezone,
    weekdays=excluded.weekdays,recipient_roles=excluded.recipient_roles,
    in_app_enabled=excluded.in_app_enabled,push_enabled=excluded.push_enabled,
    include_tasks=excluded.include_tasks,include_attendance=excluded.include_attendance,
    include_employees=excluded.include_employees,include_payments=excluded.include_payments,
    include_recruitment=excluded.include_recruitment,include_legal=excluded.include_legal,
    include_milestones=excluded.include_milestones,
    include_empty_sections=excluded.include_empty_sections,
    ai_commentary=excluded.ai_commentary,updated_by=auth.uid()
  returning * into v_value;
  return to_jsonb(v_value);
end;
$$;

create or replace function public.prepare_dispatcher_object_summary(
  p_run_id uuid,
  p_dispatch_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.dispatcher_summary_runs%rowtype;
  v_settings public.dispatcher_summary_settings%rowtype;
  v_company_name text;
  v_object_name text;
  v_start timestamptz;
  v_finish timestamptz;
  v_week_end date;
  v_sections text[]:=array[]::text[];
  v_payload jsonb;
  v_title text;
  v_fallback text;
  v_critical integer:=0;
  v_tasks_total integer:=0;
  v_tasks_done integer:=0;
  v_tasks_blocked integer:=0;
  v_active_employees integer:=0;
  v_attendance_marked integer:=0;
  v_missing_attendance integer:=0;
  v_total_shifts numeric:=0;
  v_new_employees integer:=0;
  v_payment_count integer:=0;
  v_payment_amount numeric:=0;
  v_payment_today integer:=0;
  v_missing_receipts integer:=0;
  v_candidates_active integer:=0;
  v_candidates_new integer:=0;
  v_incoming_messages integer:=0;
  v_legal_open integer:=0;
  v_legal_overdue integer:=0;
  v_legal_high integer:=0;
  v_documents_expiring integer:=0;
  v_milestones_open integer:=0;
  v_milestones_overdue integer:=0;
  v_milestones_upcoming integer:=0;
begin
  select * into v_run from public.dispatcher_summary_runs
  where id=p_run_id and dispatch_token=p_dispatch_token;
  if not found then raise exception 'Запуск не найден'; end if;
  if v_run.status='sent' then
    return jsonb_build_object('already_sent',true,'run_id',v_run.id);
  end if;
  if v_run.object_id is null then raise exception 'Для сводки не выбран объект'; end if;
  select * into v_settings from public.dispatcher_summary_settings
  where company_id=v_run.company_id;
  if not found then raise exception 'Настройки диспетчера не найдены'; end if;
  select c.name into v_company_name from public.companies c where c.id=v_run.company_id;
  select o.name into v_object_name from public.objects o
  where o.id=v_run.object_id and o.company_id=v_run.company_id and o.is_active=true;
  if v_object_name is null then raise exception 'Объект не найден или отключён'; end if;
  v_start:=(v_run.summary_date::timestamp at time zone v_settings.timezone);
  v_finish:=((v_run.summary_date+1)::timestamp at time zone v_settings.timezone);
  v_week_end:=v_run.summary_date+7;

  if v_settings.include_tasks then
    select count(*)::integer,
      count(*) filter(where t.status='Выполнено')::integer,
      count(*) filter(where btrim(coalesce(t.not_done_comment,''))<>'')::integer
    into v_tasks_total,v_tasks_done,v_tasks_blocked
    from public.tasks t
    where t.company_id=v_run.company_id
      and lower(btrim(coalesce(t.object_name,'')))=lower(btrim(v_object_name))
      and t.task_date=v_run.summary_date and not coalesce(t.is_draft,false);
    v_critical:=v_critical+v_tasks_blocked;
    if v_tasks_total>0 or v_settings.include_empty_sections then
      v_sections:=array_append(v_sections,format(
        'Задачи: %s выполнено из %s, незакрыто %s, с проблемой %s.',
        v_tasks_done,v_tasks_total,v_tasks_total-v_tasks_done,v_tasks_blocked));
    end if;
  end if;

  if v_settings.include_attendance or v_settings.include_employees then
    select count(*)::integer,
      count(*) filter(where e.created_at>=v_start and e.created_at<v_finish)::integer
    into v_active_employees,v_new_employees
    from public.employees e
    where e.company_id=v_run.company_id
      and lower(btrim(coalesce(e.object_name,'')))=lower(btrim(v_object_name))
      and e.is_active=true and e.archived_at is null;
    select count(distinct a.employee_id)::integer,coalesce(sum(a.shifts),0)
    into v_attendance_marked,v_total_shifts
    from public.attendance a
    where a.company_id=v_run.company_id
      and lower(btrim(coalesce(a.object_name,'')))=lower(btrim(v_object_name))
      and a.work_date=v_run.summary_date;
    select count(*)::integer into v_missing_attendance
    from public.employees e
    where e.company_id=v_run.company_id
      and lower(btrim(coalesce(e.object_name,'')))=lower(btrim(v_object_name))
      and e.is_active=true and e.archived_at is null
      and not exists(
        select 1 from public.attendance a
        where a.company_id=e.company_id and a.employee_id=e.id
          and a.work_date=v_run.summary_date
          and lower(btrim(coalesce(a.object_name,'')))=lower(btrim(v_object_name)));
    v_critical:=v_critical+v_missing_attendance;
    if v_settings.include_attendance and (v_active_employees>0 or v_settings.include_empty_sections) then
      v_sections:=array_append(v_sections,format(
        'Табель: отмечено %s из %s, без отметки %s, смен %s.',
        v_attendance_marked,v_active_employees,v_missing_attendance,round(v_total_shifts,1)));
    end if;
    if v_settings.include_employees and (v_active_employees>0 or v_settings.include_empty_sections) then
      v_sections:=array_append(v_sections,format(
        'Сотрудники: активных %s, добавлено сегодня %s.',v_active_employees,v_new_employees));
    end if;
  end if;

  if v_settings.include_payments then
    select count(*)::integer,coalesce(sum(p.amount),0),
      count(*) filter(where p.payment_date=v_run.summary_date)::integer,
      count(*) filter(where not exists(
        select 1 from public.payment_receipts r
        where r.company_id=p.company_id and r.payment_id=p.id))::integer
    into v_payment_count,v_payment_amount,v_payment_today,v_missing_receipts
    from public.payments p
    join public.employees e on e.id=p.employee_id and e.company_id=p.company_id
    where p.company_id=v_run.company_id
      and lower(btrim(coalesce(e.object_name,'')))=lower(btrim(v_object_name))
      and p.period_year=extract(year from v_run.summary_date)::integer
      and p.period_month=extract(month from v_run.summary_date)::integer;
    v_critical:=v_critical+v_missing_receipts;
    if v_payment_count>0 or v_settings.include_empty_sections then
      v_sections:=array_append(v_sections,format(
        'Выплаты: за месяц %s операций на %s ₽, сегодня %s, без чека %s.',
        v_payment_count,round(v_payment_amount),v_payment_today,v_missing_receipts));
    end if;
  end if;

  if v_settings.include_recruitment then
    select
      count(*) filter(where a.archived_at is null and lower(coalesce(a.status,'')) not in ('принят','отказ','отклонён','архив','hired','rejected','reserve'))::integer,
      count(*) filter(where a.archived_at is null and a.created_at>=v_start and a.created_at<v_finish)::integer
    into v_candidates_active,v_candidates_new
    from public.recruitment_applications a
    where a.company_id=v_run.company_id and a.object_id=v_run.object_id;
    select count(*)::integer into v_incoming_messages
    from public.recruitment_messages m
    join public.recruitment_applications a
      on a.id=m.application_id and a.company_id=m.company_id
    where m.company_id=v_run.company_id and a.object_id=v_run.object_id
      and m.direction='incoming' and m.created_at>=v_start and m.created_at<v_finish;
    if v_candidates_active>0 or v_candidates_new>0 or v_incoming_messages>0
       or v_settings.include_empty_sections then
      v_sections:=array_append(v_sections,format(
        'Подбор: активных кандидатов %s, новых %s, входящих сообщений %s.',
        v_candidates_active,v_candidates_new,v_incoming_messages));
    end if;
  end if;

  if v_settings.include_legal then
    select
      count(*) filter(where m.resolved_at is null and lower(coalesce(m.status,'')) not in ('закрыт','решён','resolved','closed'))::integer,
      count(*) filter(where m.resolved_at is null and m.due_at<v_start and lower(coalesce(m.status,'')) not in ('закрыт','решён','resolved','closed'))::integer,
      count(*) filter(where m.resolved_at is null and lower(coalesce(m.risk_level,'')) in ('высокий','критический','high','critical'))::integer
    into v_legal_open,v_legal_overdue,v_legal_high
    from public.legal_matters m
    where m.company_id=v_run.company_id and m.object_id=v_run.object_id;
    select count(*)::integer into v_documents_expiring
    from public.legal_documents d
    where d.company_id=v_run.company_id and d.object_id=v_run.object_id
      and d.archived_at is null
      and d.expires_on between v_run.summary_date and v_week_end;
    v_critical:=v_critical+v_legal_overdue+v_legal_high;
    if v_legal_open>0 or v_documents_expiring>0 or v_settings.include_empty_sections then
      v_sections:=array_append(v_sections,format(
        'Юридическое: открыто %s, просрочено %s, высокий риск %s, истекает документов за 7 дней %s.',
        v_legal_open,v_legal_overdue,v_legal_high,v_documents_expiring));
    end if;
  end if;

  if v_settings.include_milestones then
    select
      count(*) filter(where lower(coalesce(m.status,'')) not in ('выполнено','закрыто','completed','closed'))::integer,
      count(*) filter(where lower(coalesce(m.status,'')) not in ('выполнено','закрыто','completed','closed') and m.target_date<v_run.summary_date)::integer,
      count(*) filter(where lower(coalesce(m.status,'')) not in ('выполнено','закрыто','completed','closed') and m.target_date between v_run.summary_date and v_week_end)::integer
    into v_milestones_open,v_milestones_overdue,v_milestones_upcoming
    from public.project_milestones m
    where m.company_id=v_run.company_id
      and lower(btrim(coalesce(m.object_name,'')))=lower(btrim(v_object_name));
    v_critical:=v_critical+v_milestones_overdue;
    if v_milestones_open>0 or v_settings.include_empty_sections then
      v_sections:=array_append(v_sections,format(
        'Цели и этапы: открыто %s, просрочено %s, срок в ближайшие 7 дней у %s.',
        v_milestones_open,v_milestones_overdue,v_milestones_upcoming));
    end if;
  end if;

  v_payload:=jsonb_build_object(
    'company',v_company_name,
    'object',jsonb_build_object('id',v_run.object_id,'name',v_object_name),
    'date',v_run.summary_date,
    'tasks',jsonb_build_object('total',v_tasks_total,'done',v_tasks_done,'pending',v_tasks_total-v_tasks_done,'blocked',v_tasks_blocked),
    'attendance',jsonb_build_object('active_employees',v_active_employees,'marked',v_attendance_marked,'missing',v_missing_attendance,'total_shifts',v_total_shifts),
    'employees',jsonb_build_object('active',v_active_employees,'added_today',v_new_employees),
    'payments',jsonb_build_object('month_operations',v_payment_count,'month_amount',v_payment_amount,'today_operations',v_payment_today,'missing_receipts',v_missing_receipts),
    'recruitment',jsonb_build_object('active',v_candidates_active,'new_today',v_candidates_new,'incoming_messages_today',v_incoming_messages),
    'legal',jsonb_build_object('open_matters',v_legal_open,'overdue',v_legal_overdue,'high_risk',v_legal_high,'expiring_documents_7d',v_documents_expiring),
    'milestones',jsonb_build_object('open',v_milestones_open,'overdue',v_milestones_overdue,'upcoming_7d',v_milestones_upcoming),
    'critical_count',v_critical,'generated_at',now());
  v_title:=format('Сводка · %s · %s',v_object_name,to_char(v_run.summary_date,'DD.MM.YYYY'));
  v_fallback:=concat_ws(E'\n\n',
    format('%s. Объект: %s. Итог за %s.',v_company_name,v_object_name,to_char(v_run.summary_date,'DD.MM.YYYY')),
    array_to_string(v_sections,E'\n\n'),
    case when v_critical>0
      then format('Требует внимания: %s отклонений по объекту «%s». Открой соответствующие разделы и назначь ответственных.',v_critical,v_object_name)
      else format('Критичных отклонений по объекту «%s» в выбранных разделах не найдено.',v_object_name) end);
  return jsonb_build_object(
    'already_sent',false,'run_id',v_run.id,'company_id',v_run.company_id,
    'object_id',v_run.object_id,'object_name',v_object_name,
    'title',v_title,'fallback',v_fallback,'payload',v_payload,
    'critical_count',v_critical,'ai_commentary',v_settings.ai_commentary);
end;
$$;

create or replace function public.finalize_dispatcher_object_summary(
  p_run_id uuid,
  p_dispatch_token uuid,
  p_title text,
  p_body text,
  p_payload jsonb,
  p_ai_used boolean,
  p_critical_count integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run public.dispatcher_summary_runs%rowtype;
  v_settings public.dispatcher_summary_settings%rowtype;
  v_role text;
begin
  select * into v_run from public.dispatcher_summary_runs
  where id=p_run_id and dispatch_token=p_dispatch_token for update;
  if not found then raise exception 'Запуск не найден'; end if;
  if v_run.status='sent' then return false; end if;
  if v_run.object_id is null or btrim(v_run.object_name)='' then
    raise exception 'Для сводки не выбран объект';
  end if;
  select * into v_settings from public.dispatcher_summary_settings
  where company_id=v_run.company_id;
  if not found then raise exception 'Настройки диспетчера не найдены'; end if;
  foreach v_role in array v_settings.recipient_roles loop
    insert into public.app_notifications(
      company_id,title,body,actor_user_id,actor_name,actor_email,object_name,
      entity_type,entity_id,target_user_id,target_role,source_role,
      requires_action,due_at,priority,is_push_only,push_requested
    ) values (
      v_run.company_id,left(coalesce(p_title,''),240),left(coalesce(p_body,''),8000),
      null,'ИИ-диспетчер AppСтрой','',v_run.object_name,
      'dispatcher_summary',v_run.id::text,null,v_role,'admin',
      coalesce(p_critical_count,0)>0,null,
      case when coalesce(p_critical_count,0)>0 then 'high' else 'normal' end,
      not v_settings.in_app_enabled,v_settings.push_enabled);
  end loop;
  update public.dispatcher_summary_runs set
    object_name=v_run.object_name,status='sent',title=left(coalesce(p_title,''),240),
    body=left(coalesce(p_body,''),8000),payload=coalesce(p_payload,'{}'::jsonb),
    ai_used=coalesce(p_ai_used,false),error_text='',sent_at=now(),updated_at=now()
  where id=v_run.id;
  return true;
end;
$$;

create or replace function public.fail_dispatcher_object_summary(
  p_run_id uuid,
  p_dispatch_token uuid,
  p_error_text text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  update public.dispatcher_summary_runs set
    status='failed',error_text=left(coalesce(p_error_text,'Неизвестная ошибка'),4000),
    next_attempt_at=now()+interval '15 minutes',updated_at=now()
  where id=p_run_id and dispatch_token=p_dispatch_token and status<>'sent';
  get diagnostics v_count=row_count;
  return v_count>0;
end;
$$;

revoke all on function public.prepare_dispatcher_object_summary(uuid,uuid)
  from public,anon,authenticated;
revoke all on function public.finalize_dispatcher_object_summary(uuid,uuid,text,text,jsonb,boolean,integer)
  from public,anon,authenticated;
revoke all on function public.fail_dispatcher_object_summary(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.prepare_dispatcher_object_summary(uuid,uuid) to service_role;
grant execute on function public.finalize_dispatcher_object_summary(uuid,uuid,text,text,jsonb,boolean,integer) to service_role;
grant execute on function public.fail_dispatcher_object_summary(uuid,uuid,text) to service_role;

create or replace function private.process_due_dispatcher_summaries()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_setting public.dispatcher_summary_settings%rowtype;
  v_run public.dispatcher_summary_runs%rowtype;
  v_local_now timestamp;
  v_local_date date;
  v_scheduled_for timestamptz;
  v_prepared jsonb;
  v_count integer:=0;
begin
  for v_setting in
    select s.* from public.dispatcher_summary_settings s
    join public.companies c on c.id=s.company_id and c.status='active'
    join public.objects o on o.id=s.object_id and o.company_id=s.company_id and o.is_active=true
    where s.enabled=true and s.object_id is not null
  loop
    v_local_now:=now() at time zone v_setting.timezone;
    v_local_date:=v_local_now::date;
    if extract(isodow from v_local_date)::smallint=any(v_setting.weekdays)
       and v_local_now::time>=v_setting.local_time then
      v_scheduled_for:=(v_local_date+v_setting.local_time) at time zone v_setting.timezone;
      insert into public.dispatcher_summary_runs(
        company_id,object_id,object_name,summary_date,scheduled_for,status,next_attempt_at
      ) values (
        v_setting.company_id,v_setting.object_id,v_setting.object_name,
        v_local_date,v_scheduled_for,'pending',now()
      ) on conflict(company_id,object_id,summary_date)
        where object_id is not null do nothing;
    end if;
  end loop;
  for v_run in
    select r.* from public.dispatcher_summary_runs r
    where r.object_id is not null and r.attempts<5 and (
      (r.status in ('pending','failed') and coalesce(r.next_attempt_at,r.scheduled_for)<=now())
      or (r.status='processing' and r.updated_at<=now()-interval '15 minutes'))
    order by r.scheduled_for,r.created_at for update skip locked
  loop
    begin
      update public.dispatcher_summary_runs
      set status='processing',attempts=attempts+1,updated_at=now(),error_text=''
      where id=v_run.id;
      v_prepared:=public.prepare_dispatcher_object_summary(v_run.id,v_run.dispatch_token);
      if coalesce((v_prepared->>'already_sent')::boolean,false)=false then
        perform public.finalize_dispatcher_object_summary(
          v_run.id,v_run.dispatch_token,v_prepared->>'title',v_prepared->>'fallback',
          v_prepared->'payload',false,coalesce((v_prepared->>'critical_count')::integer,0));
      end if;
      v_count:=v_count+1;
    exception when others then
      update public.dispatcher_summary_runs set
        status='failed',error_text=left(sqlerrm,4000),
        next_attempt_at=now()+interval '15 minutes',updated_at=now()
      where id=v_run.id and status<>'sent';
    end;
  end loop;
  return v_count;
end;
$$;

create or replace function public.run_dispatcher_summary_now()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_settings public.dispatcher_summary_settings%rowtype;
  v_run_id uuid;
  v_local_date date;
begin
  if v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для запуска ИИ-диспетчера';
  end if;
  select * into v_settings from public.dispatcher_summary_settings
  where company_id=v_company_id;
  if not found or v_settings.object_id is null then
    raise exception 'Сначала выберите объект и сохраните настройки';
  end if;
  if not exists(select 1 from public.objects o
    where o.id=v_settings.object_id and o.company_id=v_company_id and o.is_active=true) then
    raise exception 'Выбранный объект больше недоступен';
  end if;
  v_local_date:=(now() at time zone v_settings.timezone)::date;
  insert into public.dispatcher_summary_runs(
    company_id,object_id,object_name,summary_date,scheduled_for,status,next_attempt_at
  ) values (
    v_company_id,v_settings.object_id,v_settings.object_name,
    v_local_date,now(),'pending',now()
  ) on conflict(company_id,object_id,summary_date)
      where object_id is not null do update set
    object_name=excluded.object_name,status='pending',dispatch_token=gen_random_uuid(),
    attempts=0,next_attempt_at=now(),title='',body='',payload='{}'::jsonb,
    ai_used=false,error_text='',sent_at=null,updated_at=now()
  returning id into v_run_id;
  perform private.process_due_dispatcher_summaries();
  return v_run_id;
end;
$$;
