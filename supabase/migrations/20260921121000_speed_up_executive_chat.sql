create table if not exists public.executive_task_feed (
  task_id uuid primary key references public.tasks(id) on delete cascade,
  company_id uuid not null,
  task_date date not null,
  object_name text not null default '',
  creator_name text not null default 'Мастер',
  status text not null default '',
  message_text text not null default '',
  media_count integer not null default 0,
  task_created_at timestamptz not null,
  refreshed_at timestamptz not null default now(),
  constraint executive_task_feed_media_count_check check (media_count >= 0)
);

create index if not exists executive_task_feed_company_date_created_idx
  on public.executive_task_feed (
    company_id,
    task_date desc,
    task_created_at desc
  );

create index if not exists executive_task_feed_company_object_date_idx
  on public.executive_task_feed (
    company_id,
    object_name,
    task_date desc,
    task_created_at desc
  );

alter table public.executive_task_feed enable row level security;

revoke all on table public.executive_task_feed from public, anon, authenticated;

create or replace function private.executive_format_quantity(p_value numeric)
returns text
language plpgsql
immutable
strict
set search_path = pg_catalog
as $function$
declare
  v_text text;
  v_integer text;
  v_fraction text;
begin
  v_text := trim(trailing '.' from trim(trailing '0' from to_char(p_value, 'FM999999999999990.000')));
  v_integer := split_part(v_text, '.', 1);
  v_fraction := split_part(v_text, '.', 2);

  v_integer := regexp_replace(v_integer, '(?<=\d)(?=(\d{3})+(?!\d))', ' ', 'g');

  if v_fraction = '' then
    return v_integer;
  end if;
  return v_integer || ',' || v_fraction;
end;
$function$;

revoke all on function private.executive_format_quantity(numeric)
from public, anon, authenticated;

create or replace function private.refresh_executive_task_feed(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
declare
  v_task public.tasks%rowtype;
  v_assignees text;
  v_planned numeric;
  v_without_volume boolean := false;
  v_plan_unit text := '';
  v_actual numeric;
  v_actual_unit text := '';
  v_unit text := '';
  v_media_count integer := 0;
  v_sections text[] := '{}'::text[];
  v_completion numeric;
  v_creator text;
begin
  if p_task_id is null then
    return;
  end if;

  select *
    into v_task
    from public.tasks
   where id = p_task_id;

  if not found
     or coalesce(v_task.is_draft, false)
     or v_task.deleted_at is not null then
    delete from public.executive_task_feed
     where task_id = p_task_id;
    return;
  end if;

  select string_agg(btrim(employee.fio), E'\n' order by lower(btrim(employee.fio)))
    into v_assignees
    from public.task_assignees assignment
    join public.employees employee
      on employee.id = assignment.employee_id
   where assignment.task_id = p_task_id
     and nullif(btrim(employee.fio), '') is not null;

  select
      plan.planned_quantity,
      coalesce(plan.without_volume, false),
      btrim(coalesce(plan.unit, ''))
    into v_planned, v_without_volume, v_plan_unit
    from public.task_work_plans plan
   where plan.task_id = p_task_id;

  select
      sum(day.quantity)::numeric,
      coalesce(
        min(nullif(btrim(day.unit), '')) filter (
          where nullif(btrim(day.unit), '') is not null
        ),
        ''
      )
    into v_actual, v_actual_unit
    from public.task_work_days day
   where day.task_id = p_task_id;

  select count(*)::integer
    into v_media_count
    from public.task_photos media
   where media.task_id = p_task_id
     and nullif(btrim(media.storage_path), '') is not null;

  v_unit := case
    when v_plan_unit <> '' then v_plan_unit
    else v_actual_unit
  end;

  if nullif(btrim(v_task.axes), '') is not null then
    v_sections := array_append(
      v_sections,
      'Оси / участок' || E'\n' || btrim(v_task.axes)
    );
  end if;

  if nullif(btrim(v_task.work), '') is not null then
    v_sections := array_append(
      v_sections,
      'Работа' || E'\n' || btrim(v_task.work)
    );
  end if;

  if nullif(v_assignees, '') is not null then
    v_sections := array_append(
      v_sections,
      'Исполнители' || E'\n' || v_assignees
    );
  end if;

  if v_without_volume then
    v_sections := array_append(v_sections, 'Объём' || E'\n' || 'Без объёма');
  else
    if v_planned is not null then
      v_sections := array_append(
        v_sections,
        'Плановый объём' || E'\n' ||
        private.executive_format_quantity(v_planned) ||
        case when v_unit = '' then '' else ' ' || v_unit end
      );
    end if;

    if v_actual is not null then
      v_sections := array_append(
        v_sections,
        'Фактический объём' || E'\n' ||
        private.executive_format_quantity(v_actual) ||
        case when v_unit = '' then '' else ' ' || v_unit end
      );
    end if;

    if v_planned is not null and v_planned > 0
       and v_actual is not null and v_actual >= 0 then
      v_completion := round((v_actual / v_planned) * 1000) / 10;
      v_sections := array_append(
        v_sections,
        'Выполнение плана' || E'\n' ||
        private.executive_format_quantity(v_completion) || '%'
      );
    end if;
  end if;

  if nullif(btrim(v_task.status), '') is not null then
    v_sections := array_append(
      v_sections,
      'Статус' || E'\n' || btrim(v_task.status)
    );
  end if;

  if nullif(btrim(v_task.not_done_comment), '') is not null then
    v_sections := array_append(
      v_sections,
      'Комментарий' || E'\n' || btrim(v_task.not_done_comment)
    );
  end if;

  v_creator := coalesce(nullif(btrim(v_task.created_by), ''), 'Мастер');

  insert into public.executive_task_feed (
    task_id,
    company_id,
    task_date,
    object_name,
    creator_name,
    status,
    message_text,
    media_count,
    task_created_at,
    refreshed_at
  ) values (
    v_task.id,
    v_task.company_id,
    v_task.task_date,
    coalesce(btrim(v_task.object_name), ''),
    v_creator,
    coalesce(btrim(v_task.status), ''),
    array_to_string(v_sections, E'\n\n'),
    coalesce(v_media_count, 0),
    coalesce(v_task.created_at, now()),
    now()
  )
  on conflict (task_id) do update
  set company_id = excluded.company_id,
      task_date = excluded.task_date,
      object_name = excluded.object_name,
      creator_name = excluded.creator_name,
      status = excluded.status,
      message_text = excluded.message_text,
      media_count = excluded.media_count,
      task_created_at = excluded.task_created_at,
      refreshed_at = excluded.refreshed_at;
end;
$function$;

revoke all on function private.refresh_executive_task_feed(uuid)
from public, anon, authenticated;

create or replace function private.refresh_executive_task_feed_from_task()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
begin
  perform private.refresh_executive_task_feed(
    case when tg_op = 'DELETE' then old.id else new.id end
  );
  return null;
end;
$function$;

create or replace function private.refresh_executive_task_feed_from_child()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
declare
  v_old_task_id uuid;
  v_new_task_id uuid;
begin
  if tg_op <> 'INSERT' then
    v_old_task_id := old.task_id;
  end if;
  if tg_op <> 'DELETE' then
    v_new_task_id := new.task_id;
  end if;

  if v_old_task_id is not null then
    perform private.refresh_executive_task_feed(v_old_task_id);
  end if;
  if v_new_task_id is not null and v_new_task_id is distinct from v_old_task_id then
    perform private.refresh_executive_task_feed(v_new_task_id);
  end if;
  return null;
end;
$function$;

revoke all on function private.refresh_executive_task_feed_from_task()
from public, anon, authenticated;
revoke all on function private.refresh_executive_task_feed_from_child()
from public, anon, authenticated;

drop trigger if exists executive_task_feed_after_task_change on public.tasks;
create trigger executive_task_feed_after_task_change
after insert or update or delete on public.tasks
for each row execute function private.refresh_executive_task_feed_from_task();

do $block$
declare
  v_table text;
begin
  foreach v_table in array array[
    'task_assignees',
    'task_work_plans',
    'task_work_days',
    'task_photos'
  ]
  loop
    execute format(
      'drop trigger if exists executive_task_feed_after_change on public.%I',
      v_table
    );
    execute format(
      'create trigger executive_task_feed_after_change after insert or update or delete on public.%I for each row execute function private.refresh_executive_task_feed_from_child()',
      v_table
    );
  end loop;
end;
$block$;

-- Existing tasks are converted once. Realtime broadcasting is attached only
-- after this backfill so the migration does not emit hundreds of fake chat updates.
do $block$
declare
  v_task_id uuid;
begin
  for v_task_id in
    select id
      from public.tasks
     where is_draft = false
       and deleted_at is null
  loop
    perform private.refresh_executive_task_feed(v_task_id);
  end loop;
end;
$block$;

create or replace function public.get_executive_task_feed(
  p_start_date date,
  p_end_date date,
  p_object_name text default null
)
returns table(
  task_id uuid,
  task_date date,
  task_created_at timestamptz,
  object_name text,
  creator_name text,
  status text,
  message_text text,
  media_count integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_company_id uuid;
  v_first date;
  v_last date;
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_start_date is null or p_end_date is null then
    raise exception 'invalid date range' using errcode = '22023';
  end if;

  v_first := least(p_start_date, p_end_date);
  v_last := greatest(p_start_date, p_end_date);

  if v_last - v_first > 370 then
    raise exception 'date range is too large' using errcode = '22023';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  if not public.current_user_has_permission('tasks.view') then
    raise exception 'insufficient task view permission' using errcode = '42501';
  end if;

  return query
  select
    feed.task_id,
    feed.task_date,
    feed.task_created_at,
    feed.object_name,
    feed.creator_name,
    feed.status,
    feed.message_text,
    feed.media_count
  from public.executive_task_feed feed
  where feed.company_id = v_company_id
    and feed.task_date between v_first and v_last
    and (v_object_name is null or feed.object_name = v_object_name)
  order by feed.task_date desc, feed.task_created_at desc;
end;
$function$;

revoke all on function public.get_executive_task_feed(date, date, text)
from public, anon;
grant execute on function public.get_executive_task_feed(date, date, text)
to authenticated, service_role;

drop trigger if exists app_data_broadcast_after_change
on public.executive_task_feed;
create trigger app_data_broadcast_after_change
after insert or update or delete on public.executive_task_feed
for each row execute function private.broadcast_app_data_change();

comment on table public.executive_task_feed is
  'Denormalized, server-maintained task text feed for the executive chat.';
