alter table public.developer_settings_audit
  drop constraint if exists developer_settings_audit_action_check;
alter table public.developer_settings_audit
  add constraint developer_settings_audit_action_check
  check (action in ('create','insert','update','reset','delete'));

alter table public.developer_settings_audit
  drop constraint if exists developer_settings_audit_group_check;
alter table public.developer_settings_audit
  add constraint developer_settings_audit_group_check
  check (setting_group in (
    'task_policy','role','profession','feature',
    'dispatcher_summary','reminder_rule','custom_setting'
  ));

create or replace function private.audit_dispatcher_summary_settings()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.developer_settings_audit(
    company_id,object_id,setting_group,action,
    old_value,new_value,changed_by,changed_at
  ) values (
    coalesce(new.company_id,old.company_id),null,'dispatcher_summary',
    case tg_op when 'INSERT' then 'create' when 'DELETE' then 'delete' else 'update' end,
    case when tg_op='INSERT' then null else to_jsonb(old) end,
    case when tg_op='DELETE' then null else to_jsonb(new) end,
    auth.uid(),now()
  );
  return coalesce(new,old);
end;
$$;

create table if not exists public.developer_reminder_rules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  body text not null default '',
  enabled boolean not null default true,
  schedule_type text not null default 'daily',
  local_time time without time zone not null default '09:00',
  timezone text not null default 'Europe/Moscow',
  weekdays smallint[] not null default array[1,2,3,4,5,6,7]::smallint[],
  run_once_at timestamptz,
  recipient_roles text[] not null default array['admin']::text[],
  in_app_enabled boolean not null default true,
  push_enabled boolean not null default true,
  priority text not null default 'normal',
  object_name text not null default '',
  sort_order integer not null default 0,
  last_scheduled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  constraint developer_reminder_rules_name_check
    check(length(btrim(name)) between 1 and 120),
  constraint developer_reminder_rules_schedule_check
    check(schedule_type in ('daily','weekly','once')),
  constraint developer_reminder_rules_weekdays_check
    check(cardinality(weekdays)>0 and weekdays<@array[1,2,3,4,5,6,7]::smallint[]),
  constraint developer_reminder_rules_roles_check
    check(cardinality(recipient_roles)>0 and recipient_roles<@array['admin','developer','foreman','hr','accountant','lawyer']::text[]),
  constraint developer_reminder_rules_channels_check
    check(in_app_enabled or push_enabled),
  constraint developer_reminder_rules_priority_check
    check(priority in ('low','normal','high','critical')),
  constraint developer_reminder_rules_once_check
    check((schedule_type='once' and run_once_at is not null) or schedule_type<>'once')
);

create index if not exists developer_reminder_rules_company_sort_idx
  on public.developer_reminder_rules(company_id,sort_order,created_at);
create index if not exists developer_reminder_rules_due_idx
  on public.developer_reminder_rules(enabled,schedule_type,run_once_at);

create table if not exists public.developer_custom_settings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  setting_key text not null,
  name text not null,
  description text not null default '',
  category text not null default 'Общие',
  value_type text not null default 'text',
  value jsonb not null default '""'::jsonb,
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  constraint developer_custom_settings_company_key unique(company_id,setting_key),
  constraint developer_custom_settings_key_check
    check(setting_key~'^[a-z][a-z0-9_.-]{1,79}$'),
  constraint developer_custom_settings_name_check
    check(length(btrim(name)) between 1 and 120),
  constraint developer_custom_settings_type_check
    check(value_type in ('boolean','text','number','time','json'))
);

create index if not exists developer_custom_settings_company_sort_idx
  on public.developer_custom_settings(company_id,category,sort_order,created_at);

alter table public.developer_reminder_rules enable row level security;
alter table public.developer_custom_settings enable row level security;

drop policy if exists developer_reminder_rules_admin_all
  on public.developer_reminder_rules;
create policy developer_reminder_rules_admin_all
  on public.developer_reminder_rules for all to authenticated
  using(company_id=public.current_user_company_id() and public.is_admin())
  with check(company_id=public.current_user_company_id() and public.is_admin());

drop policy if exists developer_custom_settings_admin_all
  on public.developer_custom_settings;
create policy developer_custom_settings_admin_all
  on public.developer_custom_settings for all to authenticated
  using(company_id=public.current_user_company_id() and public.is_admin())
  with check(company_id=public.current_user_company_id() and public.is_admin());

create or replace function private.validate_developer_reminder_rule()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_object_exists boolean;
begin
  new.name:=btrim(new.name);
  new.body:=btrim(coalesce(new.body,''));
  new.object_name:=btrim(coalesce(new.object_name,''));
  new.weekdays:=array(select distinct x from unnest(new.weekdays)x order by x);
  new.recipient_roles:=array(select distinct lower(btrim(x)) from unnest(new.recipient_roles)x order by 1);
  if not exists(select 1 from pg_timezone_names where name=new.timezone) then
    raise exception 'Неизвестный часовой пояс: %',new.timezone;
  end if;
  if new.object_name<>'' then
    select exists(
      select 1 from public.objects o
      where o.company_id=new.company_id and o.is_active=true
        and lower(btrim(o.name))=lower(new.object_name)
    ) into v_object_exists;
    if not v_object_exists then raise exception 'Объект не найден'; end if;
  end if;
  if new.schedule_type<>'once' then new.run_once_at:=null; end if;
  new.updated_at:=now();
  new.updated_by:=coalesce(auth.uid(),new.updated_by);
  if tg_op='INSERT' then new.created_by:=coalesce(auth.uid(),new.created_by); end if;
  return new;
end;
$$;

drop trigger if exists developer_reminder_rules_validate
  on public.developer_reminder_rules;
create trigger developer_reminder_rules_validate
before insert or update on public.developer_reminder_rules
for each row execute function private.validate_developer_reminder_rule();

create or replace function private.validate_developer_custom_setting()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.setting_key:=lower(btrim(new.setting_key));
  new.name:=btrim(new.name);
  new.description:=btrim(coalesce(new.description,''));
  new.category:=coalesce(nullif(btrim(new.category),''),'Общие');
  if new.value_type='boolean' and jsonb_typeof(new.value)<>'boolean' then
    raise exception 'Значение должно быть переключателем';
  elsif new.value_type='number' and jsonb_typeof(new.value)<>'number' then
    raise exception 'Значение должно быть числом';
  elsif new.value_type in ('text','time') and jsonb_typeof(new.value)<>'string' then
    raise exception 'Значение должно быть строкой';
  end if;
  new.updated_at:=now();
  new.updated_by:=coalesce(auth.uid(),new.updated_by);
  if tg_op='INSERT' then new.created_by:=coalesce(auth.uid(),new.created_by); end if;
  return new;
end;
$$;

drop trigger if exists developer_custom_settings_validate
  on public.developer_custom_settings;
create trigger developer_custom_settings_validate
before insert or update on public.developer_custom_settings
for each row execute function private.validate_developer_custom_setting();

create or replace function private.audit_developer_constructor_item()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_group text:=case tg_table_name
    when 'developer_reminder_rules' then 'reminder_rule'
    else 'custom_setting'
  end;
begin
  insert into public.developer_settings_audit(
    company_id,object_id,setting_group,action,
    old_value,new_value,changed_by,changed_at
  ) values (
    coalesce(new.company_id,old.company_id),null,v_group,
    case tg_op when 'INSERT' then 'create' when 'DELETE' then 'delete' else 'update' end,
    case when tg_op='INSERT' then null else to_jsonb(old) end,
    case when tg_op='DELETE' then null else to_jsonb(new) end,
    auth.uid(),now()
  );
  return coalesce(new,old);
end;
$$;

drop trigger if exists developer_reminder_rules_audit
  on public.developer_reminder_rules;
create trigger developer_reminder_rules_audit
after insert or update or delete on public.developer_reminder_rules
for each row execute function private.audit_developer_constructor_item();

drop trigger if exists developer_custom_settings_audit
  on public.developer_custom_settings;
create trigger developer_custom_settings_audit
after insert or update or delete on public.developer_custom_settings
for each row execute function private.audit_developer_constructor_item();

alter table public.scheduled_reminders
  add column if not exists in_app_enabled boolean not null default true,
  add column if not exists push_enabled boolean not null default true;

create or replace function private.populate_developer_custom_reminders()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.scheduled_reminders(
    company_id,reminder_key,entity_type,entity_id,reminder_type,due_at,
    recipient_role,title,body,object_name,priority,in_app_enabled,push_enabled
  )
  select
    r.company_id,
    'developer-rule:'||r.id::text||':'||case
      when r.schedule_type='once' then to_char(r.run_once_at at time zone r.timezone,'YYYYMMDDHH24MI')
      else ((now() at time zone r.timezone)::date)::text end||':'||role_name,
    case when public.normalize_notification_role(role_name)='foreman'
      then 'foreman_reminder' else 'developer_reminder' end,
    r.id,'developer_custom',
    case when r.schedule_type='once' then r.run_once_at
      else (((now() at time zone r.timezone)::date+r.local_time) at time zone r.timezone) end,
    role_name,r.name,r.body,r.object_name,r.priority,r.in_app_enabled,r.push_enabled
  from public.developer_reminder_rules r
  cross join lateral unnest(r.recipient_roles) role_name
  where r.enabled and (
    (r.schedule_type='once' and r.run_once_at<=now()) or
    (r.schedule_type in ('daily','weekly')
      and extract(isodow from now() at time zone r.timezone)::smallint=any(r.weekdays)
      and (now() at time zone r.timezone)>=((now() at time zone r.timezone)::date+r.local_time))
  )
  on conflict(company_id,reminder_key) do nothing;

  update public.developer_reminder_rules r
  set last_scheduled_at=now(),
      enabled=case when r.schedule_type='once' then false else r.enabled end,
      updated_at=now()
  where r.enabled and exists(
    select 1 from public.scheduled_reminders s
    where s.company_id=r.company_id and s.entity_id=r.id
      and s.reminder_type='developer_custom'
      and s.created_at>=now()-interval '10 minutes'
  );
end;
$$;

create or replace function private.populate_role_operational_reminders()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform private.populate_foreman_configured_reminders();
  perform private.populate_backoffice_configured_reminders();
  perform private.populate_developer_custom_reminders();
end;
$$;

create or replace function private.process_due_scheduled_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reminder public.scheduled_reminders%rowtype;
  v_notification_id uuid;
  v_count integer:=0;
begin
  perform private.populate_role_operational_reminders();
  for v_reminder in
    select r.* from public.scheduled_reminders r
    where r.status='pending' and r.notification_id is null and r.due_at<=now()
    order by r.due_at,r.id for update skip locked
  loop
    insert into public.app_notifications(
      company_id,title,body,actor_user_id,actor_name,actor_email,
      object_name,entity_type,entity_id,target_user_id,target_role,source_role,
      requires_action,due_at,priority,is_push_only,push_requested
    ) values (
      v_reminder.company_id,v_reminder.title,v_reminder.body,null,
      'Система AppСтрой','',v_reminder.object_name,
      case when v_reminder.entity_type in ('legal_document','legal_matter')
        then 'legal_reminder' else v_reminder.entity_type end,
      v_reminder.entity_id::text,v_reminder.recipient_user_id,
      v_reminder.recipient_role,
      public.normalize_notification_role(coalesce(
        v_reminder.recipient_role,
        public.notification_role_for_entity(v_reminder.entity_type))),
      true,v_reminder.due_at,v_reminder.priority,
      not v_reminder.in_app_enabled,v_reminder.push_enabled
    ) returning id into v_notification_id;
    update public.scheduled_reminders
      set notification_id=v_notification_id,status='sent',sent_at=now()
      where id=v_reminder.id;
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.get_developer_constructor_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_company_id uuid:=public.current_user_company_id();
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Конструктор доступен только руководителю или разработчику';
  end if;
  return jsonb_build_object(
    'reminders',coalesce((
      select jsonb_agg(to_jsonb(r) order by r.sort_order,r.created_at)
      from public.developer_reminder_rules r where r.company_id=v_company_id
    ),'[]'::jsonb),
    'settings',coalesce((
      select jsonb_agg(to_jsonb(s) order by s.category,s.sort_order,s.created_at)
      from public.developer_custom_settings s where s.company_id=v_company_id
    ),'[]'::jsonb),
    'server_time',now()
  );
end;
$$;

create or replace function public.save_developer_reminder_rule(p_rule jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_id uuid;
  v_roles text[];
  v_days smallint[];
  v_row public.developer_reminder_rules%rowtype;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для конструктора';
  end if;
  begin v_id:=nullif(p_rule->>'id','')::uuid; exception when others then v_id:=null; end;
  select coalesce(array_agg(value order by value),array['admin']::text[])
    into v_roles from jsonb_array_elements_text(coalesce(p_rule->'recipient_roles','["admin"]'::jsonb)) value;
  select coalesce(array_agg(value::smallint order by value::smallint),array[1,2,3,4,5,6,7]::smallint[])
    into v_days from jsonb_array_elements_text(coalesce(p_rule->'weekdays','[1,2,3,4,5,6,7]'::jsonb)) value;

  if v_id is null then
    insert into public.developer_reminder_rules(
      company_id,name,body,enabled,schedule_type,local_time,timezone,weekdays,
      run_once_at,recipient_roles,in_app_enabled,push_enabled,priority,
      object_name,sort_order,created_by,updated_by
    ) values (
      v_company_id,coalesce(nullif(btrim(p_rule->>'name'),''),'Новое напоминание'),
      coalesce(p_rule->>'body',''),coalesce((p_rule->>'enabled')::boolean,true),
      coalesce(nullif(p_rule->>'schedule_type',''),'daily'),
      coalesce(nullif(p_rule->>'local_time','')::time,'09:00'::time),
      coalesce(nullif(p_rule->>'timezone',''),'Europe/Moscow'),v_days,
      case when p_rule->>'schedule_type'='once' then (p_rule->>'run_once_at')::timestamptz else null end,
      v_roles,coalesce((p_rule->>'in_app_enabled')::boolean,true),
      coalesce((p_rule->>'push_enabled')::boolean,true),
      coalesce(nullif(p_rule->>'priority',''),'normal'),coalesce(p_rule->>'object_name',''),
      coalesce((p_rule->>'sort_order')::integer,0),auth.uid(),auth.uid()
    ) returning * into v_row;
  else
    update public.developer_reminder_rules set
      name=coalesce(nullif(btrim(p_rule->>'name'),''),name),
      body=coalesce(p_rule->>'body',body),
      enabled=coalesce((p_rule->>'enabled')::boolean,enabled),
      schedule_type=coalesce(nullif(p_rule->>'schedule_type',''),schedule_type),
      local_time=coalesce(nullif(p_rule->>'local_time','')::time,local_time),
      timezone=coalesce(nullif(p_rule->>'timezone',''),timezone),weekdays=v_days,
      run_once_at=case when coalesce(p_rule->>'schedule_type',schedule_type)='once'
        then nullif(p_rule->>'run_once_at','')::timestamptz else null end,
      recipient_roles=v_roles,
      in_app_enabled=coalesce((p_rule->>'in_app_enabled')::boolean,in_app_enabled),
      push_enabled=coalesce((p_rule->>'push_enabled')::boolean,push_enabled),
      priority=coalesce(nullif(p_rule->>'priority',''),priority),
      object_name=coalesce(p_rule->>'object_name',object_name),
      sort_order=coalesce((p_rule->>'sort_order')::integer,sort_order),
      updated_by=auth.uid()
    where id=v_id and company_id=v_company_id returning * into v_row;
    if not found then raise exception 'Правило не найдено'; end if;
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.delete_developer_reminder_rule(p_rule_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_company_id uuid:=public.current_user_company_id(); v_count integer;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для конструктора';
  end if;
  delete from public.developer_reminder_rules
  where id=p_rule_id and company_id=v_company_id;
  get diagnostics v_count=row_count;
  return v_count>0;
end;
$$;

create or replace function public.test_developer_reminder_rule(p_rule_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_rule public.developer_reminder_rules%rowtype;
  v_role text;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для конструктора';
  end if;
  select * into v_rule from public.developer_reminder_rules
  where id=p_rule_id and company_id=v_company_id;
  if not found then raise exception 'Правило не найдено'; end if;
  foreach v_role in array v_rule.recipient_roles loop
    insert into public.scheduled_reminders(
      company_id,reminder_key,entity_type,entity_id,reminder_type,due_at,
      recipient_role,title,body,object_name,priority,in_app_enabled,push_enabled
    ) values (
      v_company_id,'developer-test:'||v_rule.id::text||':'||gen_random_uuid()::text,
      case when public.normalize_notification_role(v_role)='foreman'
        then 'foreman_reminder' else 'developer_reminder' end,
      v_rule.id,'developer_custom_test',now(),v_role,v_rule.name,v_rule.body,
      v_rule.object_name,v_rule.priority,v_rule.in_app_enabled,v_rule.push_enabled
    );
  end loop;
  return private.process_due_scheduled_reminders();
end;
$$;

create or replace function public.save_developer_custom_setting(p_setting jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid:=public.current_user_company_id();
  v_id uuid;
  v_value jsonb;
  v_row public.developer_custom_settings%rowtype;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для конструктора';
  end if;
  begin v_id:=nullif(p_setting->>'id','')::uuid; exception when others then v_id:=null; end;
  v_value:=coalesce(p_setting->'value','""'::jsonb);
  if v_id is null then
    insert into public.developer_custom_settings(
      company_id,setting_key,name,description,category,value_type,value,
      enabled,sort_order,created_by,updated_by
    ) values (
      v_company_id,coalesce(nullif(p_setting->>'setting_key',''),'custom.setting'),
      coalesce(nullif(btrim(p_setting->>'name'),''),'Новый параметр'),
      coalesce(p_setting->>'description',''),coalesce(p_setting->>'category','Общие'),
      coalesce(p_setting->>'value_type','text'),v_value,
      coalesce((p_setting->>'enabled')::boolean,true),
      coalesce((p_setting->>'sort_order')::integer,0),auth.uid(),auth.uid()
    ) returning * into v_row;
  else
    update public.developer_custom_settings set
      setting_key=coalesce(nullif(p_setting->>'setting_key',''),setting_key),
      name=coalesce(nullif(btrim(p_setting->>'name'),''),name),
      description=coalesce(p_setting->>'description',description),
      category=coalesce(nullif(p_setting->>'category',''),category),
      value_type=coalesce(nullif(p_setting->>'value_type',''),value_type),
      value=v_value,enabled=coalesce((p_setting->>'enabled')::boolean,enabled),
      sort_order=coalesce((p_setting->>'sort_order')::integer,sort_order),
      updated_by=auth.uid()
    where id=v_id and company_id=v_company_id returning * into v_row;
    if not found then raise exception 'Параметр не найден'; end if;
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function public.delete_developer_custom_setting(p_setting_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_company_id uuid:=public.current_user_company_id(); v_count integer;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав для конструктора';
  end if;
  delete from public.developer_custom_settings
  where id=p_setting_id and company_id=v_company_id;
  get diagnostics v_count=row_count;
  return v_count>0;
end;
$$;

create or replace function public.get_developer_setting(p_setting_key text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.value from public.developer_custom_settings s
  where s.company_id=public.current_user_company_id()
    and s.setting_key=lower(btrim(p_setting_key)) and s.enabled=true limit 1;
$$;

revoke all on function public.get_developer_constructor_center() from public,anon;
revoke all on function public.save_developer_reminder_rule(jsonb) from public,anon;
revoke all on function public.delete_developer_reminder_rule(uuid) from public,anon;
revoke all on function public.test_developer_reminder_rule(uuid) from public,anon;
revoke all on function public.save_developer_custom_setting(jsonb) from public,anon;
revoke all on function public.delete_developer_custom_setting(uuid) from public,anon;
revoke all on function public.get_developer_setting(text) from public,anon;
grant execute on function public.get_developer_constructor_center() to authenticated;
grant execute on function public.save_developer_reminder_rule(jsonb) to authenticated;
grant execute on function public.delete_developer_reminder_rule(uuid) to authenticated;
grant execute on function public.test_developer_reminder_rule(uuid) to authenticated;
grant execute on function public.save_developer_custom_setting(jsonb) to authenticated;
grant execute on function public.delete_developer_custom_setting(uuid) to authenticated;
grant execute on function public.get_developer_setting(text) to authenticated;
