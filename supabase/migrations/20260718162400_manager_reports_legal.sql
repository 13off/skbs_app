create or replace function private.manager_report_legal(
  p_company_id uuid,
  p_object_id uuid,
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
      where m.resolved_at is null
        and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
    )::integer as open_count,
    count(*) filter (
      where m.resolved_at is null
        and m.due_at < p_report_date::timestamp
        and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
    )::integer as overdue,
    count(*) filter (
      where m.resolved_at is null
        and lower(coalesce(m.risk_level, '')) in ('высокий','критический','high','critical')
    )::integer as high_risk
  from public.legal_matters m
  where m.company_id = p_company_id
    and (p_object_id is null or m.object_id = p_object_id)
), documents as (
  select count(*)::integer as expiring
  from public.legal_documents d
  where d.company_id = p_company_id
    and d.archived_at is null
    and d.expires_on between p_report_date and p_report_date + 7
    and (p_object_id is null or d.object_id = p_object_id)
), attention as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'title', coalesce(nullif(btrim(m.title), ''), 'Юридический вопрос'),
    'subtitle', concat_ws(' · ', nullif(btrim(coalesce(m.risk_level, '')), ''), nullif(btrim(coalesce(m.status, '')), '')),
    'note', btrim(coalesce(m.required_actions, m.description, ''))
  ) order by m.due_at, m.title), '[]'::jsonb) as items
  from public.legal_matters m
  where m.company_id = p_company_id
    and m.resolved_at is null
    and lower(coalesce(m.status, '')) not in ('закрыт','решён','resolved','closed')
    and (
      m.due_at < p_report_date::timestamp
      or lower(coalesce(m.risk_level, '')) in ('высокий','критический','high','critical')
    )
    and (p_object_id is null or m.object_id = p_object_id)
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'open', metrics.open_count,
    'overdue', metrics.overdue,
    'high_risk', metrics.high_risk,
    'expiring_documents', documents.expiring
  ),
  'attention_items', attention.items
)
from metrics, documents, attention;
$$;

revoke all on function private.manager_report_legal(uuid,uuid,date) from public, anon, authenticated;
