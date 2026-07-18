create or replace function private.manager_report_milestones(
  p_company_id uuid,
  p_object_name text,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with metrics as (
  select
    count(*) filter (
      where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
    )::integer as open_count,
    count(*) filter (
      where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
        and m.target_date < p_report_date
    )::integer as overdue,
    count(*) filter (
      where lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
        and m.target_date between p_report_date and p_report_date + 7
    )::integer as upcoming
  from public.project_milestones m
  where m.company_id = p_company_id
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(m.object_name, ''))) = lower(btrim(p_object_name)))
), attention as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'title', coalesce(nullif(btrim(m.title), ''), 'Этап'),
    'subtitle', concat_ws(' · ', nullif(btrim(coalesce(m.location, '')), ''), 'срок ' || to_char(m.target_date, 'DD.MM.YYYY')),
    'note', btrim(coalesce(m.notes, ''))
  ) order by m.target_date, m.title), '[]'::jsonb) as items
  from public.project_milestones m
  where m.company_id = p_company_id
    and lower(coalesce(m.status, '')) not in ('выполнено','закрыто','completed','closed')
    and m.target_date <= p_report_date + 7
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(m.object_name, ''))) = lower(btrim(p_object_name)))
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'open', metrics.open_count,
    'overdue', metrics.overdue,
    'upcoming', metrics.upcoming
  ),
  'attention_items', attention.items
)
from metrics, attention;
$$;

revoke all on function private.manager_report_milestones(uuid,text,date) from public, anon, authenticated;
