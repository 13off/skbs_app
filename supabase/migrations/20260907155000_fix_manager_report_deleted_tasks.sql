create or replace function private.manager_report_tasks_v2(
  p_company_id uuid,
  p_object_id uuid,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
with today as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done,
    count(*) filter (
      where btrim(coalesce(t.not_done_comment, '')) <> ''
    )::integer as problem
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date
    and t.deleted_at is null
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), yesterday as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date - 1
    and t.deleted_at is null
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), week_data as (
  select
    count(*)::integer as total,
    count(*) filter (
      where lower(coalesce(t.status, '')) in
        ('выполнено','готово','completed','done')
    )::integer as done
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date between p_report_date - 6 and p_report_date
    and t.deleted_at is null
    and not coalesce(t.is_draft, false)
    and (p_object_id is null or t.object_id = p_object_id)
), pending as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'title', coalesce(nullif(btrim(t.work), ''), 'Задача'),
    'subtitle', concat_ws(
      ' · ',
      nullif(btrim(coalesce(t.axes, '')), ''),
      nullif(btrim(coalesce(t.status, '')), '')
    ),
    'note', btrim(coalesce(t.not_done_comment, ''))
  ) order by t.work, t.id), '[]'::jsonb) as items
  from public.tasks t
  where t.company_id = p_company_id
    and t.task_date = p_report_date
    and t.deleted_at is null
    and not coalesce(t.is_draft, false)
    and lower(coalesce(t.status, '')) not in
      ('выполнено','готово','completed','done')
    and (p_object_id is null or t.object_id = p_object_id)
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'total', today.total,
    'done', today.done,
    'pending', today.total - today.done,
    'problem', today.problem
  ),
  'trend', jsonb_build_object(
    'done_rate', case
      when today.total = 0 then 0
      else round(today.done::numeric * 100 / today.total, 1)
    end,
    'yesterday_done_rate', case
      when yesterday.total = 0 then 0
      else round(yesterday.done::numeric * 100 / yesterday.total, 1)
    end,
    'week_done_rate', case
      when week_data.total = 0 then 0
      else round(week_data.done::numeric * 100 / week_data.total, 1)
    end
  ),
  'pending_items', pending.items
)
from today, yesterday, week_data, pending;
$function$;
