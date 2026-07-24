create or replace function public.delete_recruitment_pipeline_stage(
  p_stage_id uuid,
  p_replacement_stage_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_stage public.recruitment_pipeline_stages%rowtype;
  v_replacement public.recruitment_pipeline_stages%rowtype;
  v_candidate_count integer := 0;
  v_moved_count integer := 0;
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;
  if v_company_id is null then
    raise exception 'Активная компания не выбрана';
  end if;
  if not public.current_user_has_permission('recruitment.crm.configure') then
    raise exception 'Недостаточно прав для настройки CRM';
  end if;

  select *
    into v_stage
  from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.id = p_stage_id
  for update;

  if not found then
    raise exception 'Колонка не найдена';
  end if;

  select count(*)
    into v_candidate_count
  from public.recruitment_applications application
  where application.company_id = v_company_id
    and application.stage_id = p_stage_id;

  if v_candidate_count > 0 then
    if p_replacement_stage_id is null then
      raise exception 'Выберите колонку, куда перенести кандидатов';
    end if;
    if p_replacement_stage_id = p_stage_id then
      raise exception 'Нельзя перенести кандидатов в удаляемую колонку';
    end if;

    select *
      into v_replacement
    from public.recruitment_pipeline_stages stage
    where stage.company_id = v_company_id
      and stage.id = p_replacement_stage_id
      and stage.is_active
    for update;

    if not found then
      raise exception 'Колонка для переноса не найдена или скрыта';
    end if;

    insert into public.recruitment_status_history (
      company_id,
      application_id,
      status,
      stage_id,
      stage_title,
      source,
      created_by
    )
    select
      application.company_id,
      application.id,
      v_replacement.legacy_status,
      v_replacement.id,
      v_replacement.title,
      'appstroy_hr',
      (select auth.uid())
    from public.recruitment_applications application
    where application.company_id = v_company_id
      and application.stage_id = p_stage_id;

    update public.recruitment_applications application
    set stage_id = v_replacement.id,
        status = v_replacement.legacy_status,
        updated_at = now()
    where application.company_id = v_company_id
      and application.stage_id = p_stage_id;
    get diagnostics v_moved_count = row_count;
  end if;

  delete from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.id = p_stage_id;

  with ordered as (
    select
      stage.id,
      row_number() over (
        order by stage.sort_order, stage.created_at, stage.id
      ) as position
    from public.recruitment_pipeline_stages stage
    where stage.company_id = v_company_id
      and stage.is_active
  )
  update public.recruitment_pipeline_stages stage
  set sort_order = ordered.position * 10
  from ordered
  where stage.id = ordered.id;

  return v_moved_count;
end;
$$;

revoke all on function public.delete_recruitment_pipeline_stage(uuid, uuid) from public;
grant execute on function public.delete_recruitment_pipeline_stage(uuid, uuid) to authenticated;

comment on function public.delete_recruitment_pipeline_stage(uuid, uuid) is
  'Удаляет колонку CRM. При наличии кандидатов атомарно переносит их в выбранную активную колонку, удаляет связанные автоматизации каскадом и нормализует порядок оставшихся колонок.';
