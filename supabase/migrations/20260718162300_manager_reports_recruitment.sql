create or replace function private.manager_report_recruitment(
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
with applications as (
  select
    count(*) filter (
      where a.archived_at is null
        and lower(coalesce(a.status, '')) not in ('принят','отказ','отклонён','архив','hired','rejected','reserve')
    )::integer as active,
    count(*) filter (
      where a.archived_at is null and a.created_at::date = p_report_date
    )::integer as new_count
  from public.recruitment_applications a
  where a.company_id = p_company_id
    and (p_object_id is null or a.object_id = p_object_id)
), messages as (
  select count(*)::integer as incoming
  from public.recruitment_messages m
  join public.recruitment_applications a
    on a.id = m.application_id and a.company_id = m.company_id
  where m.company_id = p_company_id
    and m.direction = 'incoming'
    and m.created_at::date = p_report_date
    and (p_object_id is null or a.object_id = p_object_id)
)
select jsonb_build_object(
  'active', applications.active,
  'new', applications.new_count,
  'incoming_messages', messages.incoming
)
from applications, messages;
$$;

revoke all on function private.manager_report_recruitment(uuid,uuid,date) from public, anon, authenticated;
