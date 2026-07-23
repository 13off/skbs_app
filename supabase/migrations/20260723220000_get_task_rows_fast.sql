create or replace function public.get_task_rows_fast(
  p_task_date date,
  p_object_name text default null
)
returns table (
  id uuid,
  task_date date,
  object_name text,
  axes text,
  work text,
  status text,
  not_done_comment text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $body$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_allowed_object_ids uuid[] := '{}'::uuid[];
  v_object_name text := nullif(btrim(coalesce(p_object_name, '')), '');
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_company_id := public.current_user_company_id();
  if v_company_id is null then
    return;
  end if;

  select coalesce(array_agg(object_row.id), '{}'::uuid[])
    into v_allowed_object_ids
    from public.objects object_row
   where object_row.company_id = v_company_id
     and object_row.is_active = true
     and public.current_user_has_object_scope(object_row.id)
     and public.current_user_has_object_permission('tasks.view', object_row.id);

  return query
  select task_row.id,
         task_row.task_date,
         task_row.object_name,
         task_row.axes,
         task_row.work,
         task_row.status,
         task_row.not_done_comment
    from public.tasks task_row
   where task_row.company_id = v_company_id
     and task_row.deleted_at is null
     and task_row.is_draft = false
     and task_row.task_date = p_task_date
     and (v_object_name is null or task_row.object_name = v_object_name)
     and task_row.object_id = any(v_allowed_object_ids)
   order by task_row.created_at;
end;
$body$;

comment on function public.get_task_rows_fast(date, text) is
  'Быстрая защищённая выборка задач за день с однократным вычислением объектного доступа.';

revoke all on function public.get_task_rows_fast(date, text)
  from public, anon;
grant execute on function public.get_task_rows_fast(date, text)
  to authenticated;
