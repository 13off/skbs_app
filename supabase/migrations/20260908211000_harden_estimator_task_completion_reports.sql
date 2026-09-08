-- Prevent one foreman from silently replacing another foreman's pending/returned
-- completion report while preserving admin/developer recovery access.

create or replace function public.submit_task_completion_report(
  p_task_id uuid,
  p_reported_quantity numeric default null,
  p_unit text default '',
  p_work_location text default '',
  p_completion_comment text default ''
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_role text := public.current_user_role();
  v_user_name text := '';
  v_existing public.task_completion_reports%rowtype;
  v_report_id uuid;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;
  if v_role not in ('admin', 'developer', 'foreman') then
    raise exception 'Передавать выполненную работу может только прораб или руководитель';
  end if;
  if p_reported_quantity is not null and p_reported_quantity <= 0 then
    raise exception 'Фактический объём должен быть больше нуля';
  end if;
  if p_reported_quantity is not null and btrim(coalesce(p_unit, '')) = '' then
    raise exception 'Для объёма укажите единицу измерения';
  end if;
  if not public.task_is_allowed_for_user(p_task_id) then
    raise exception 'Нет доступа к задаче';
  end if;
  if not exists (
    select 1
    from public.tasks task_row
    where task_row.id = p_task_id
      and task_row.company_id = public.current_user_company_id()
      and task_row.deleted_at is null
      and task_row.status = 'Выполнено'
  ) then
    raise exception 'Сначала завершите задачу';
  end if;

  select coalesce(profile.full_name, '')
    into v_user_name
    from public.user_profiles profile
   where profile.id = v_user_id;

  select *
    into v_existing
    from public.task_completion_reports report
   where report.task_id = p_task_id
   for update;

  if found and v_existing.review_status = 'approved' then
    raise exception 'Подтверждённый объём нельзя отправить повторно';
  end if;

  if found
     and v_role = 'foreman'
     and v_existing.submitted_by is distinct from v_user_id then
    raise exception 'Отчёт по этой задаче уже передан другим мастером';
  end if;

  if found then
    update public.task_completion_reports
       set reported_quantity = p_reported_quantity,
           unit = btrim(coalesce(p_unit, '')),
           work_location = btrim(coalesce(p_work_location, '')),
           completion_comment = btrim(coalesce(p_completion_comment, '')),
           review_status = 'pending',
           approved_quantity = null,
           review_comment = '',
           submitted_by = v_user_id,
           submitted_by_name = v_user_name,
           submitted_at = now(),
           reviewed_by = null,
           reviewed_by_name = '',
           reviewed_at = null,
           updated_at = now()
     where id = v_existing.id
     returning id into v_report_id;
  else
    insert into public.task_completion_reports (
      task_id,
      reported_quantity,
      unit,
      work_location,
      completion_comment,
      submitted_by,
      submitted_by_name
    ) values (
      p_task_id,
      p_reported_quantity,
      btrim(coalesce(p_unit, '')),
      btrim(coalesce(p_work_location, '')),
      btrim(coalesce(p_completion_comment, '')),
      v_user_id,
      v_user_name
    ) returning id into v_report_id;
  end if;

  return v_report_id;
end;
$function$;

grant execute on function public.submit_task_completion_report(uuid, numeric, text, text, text) to authenticated;
