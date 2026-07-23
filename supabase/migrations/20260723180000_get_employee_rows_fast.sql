create or replace function public.get_employee_rows_fast(
  p_object_name text default null,
  p_include_fired boolean default false
)
returns table (
  id uuid,
  person_id uuid,
  object_id uuid,
  fio text,
  "position" text,
  phone text,
  object_name text,
  daily_rate integer,
  is_active boolean,
  comment text,
  archived_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_accounting_access boolean := false;
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

  v_accounting_access := public.current_user_has_permission(
    'accounting.directory.view'
  );

  if not v_accounting_access then
    select coalesce(array_agg(object_row.id), '{}'::uuid[])
      into v_allowed_object_ids
      from public.objects object_row
     where object_row.company_id = v_company_id
       and public.current_user_has_object_scope(object_row.id)
       and public.current_user_has_object_permission(
         'employees.view', object_row.id
       );
  end if;

  return query
  select employee.id,
         employee.person_id,
         employee.object_id,
         employee.fio,
         employee.position,
         employee.phone,
         employee.object_name,
         employee.daily_rate,
         employee.is_active,
         employee.comment,
         employee.archived_at
    from public.employees employee
   where employee.company_id = v_company_id
     and employee.archived_at is null
     and (coalesce(p_include_fired, false) or employee.is_active)
     and (v_object_name is null or employee.object_name = v_object_name)
     and (
       v_accounting_access
       or employee.object_id = any(v_allowed_object_ids)
     )
   order by employee.fio;
end;
$function$;

comment on function public.get_employee_rows_fast(text, boolean) is
  'Быстрая защищённая выборка сотрудников с однократной проверкой компании, общих прав и объектного доступа.';

revoke all on function public.get_employee_rows_fast(text, boolean)
  from public, anon;
grant execute on function public.get_employee_rows_fast(text, boolean)
  to authenticated;
