-- Atomic CRM configuration reordering and candidate saves with stage history.

alter table public.recruitment_custom_fields
  add column if not exists description text not null default '';

alter table public.recruitment_custom_fields
  drop constraint if exists recruitment_custom_fields_description_check;
alter table public.recruitment_custom_fields
  add constraint recruitment_custom_fields_description_check
  check (char_length(description) <= 500);

create or replace function public.reorder_recruitment_pipeline_stages(
  p_stage_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_expected integer;
  v_updated integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('recruitment.crm.configure') then
    raise exception 'Недостаточно прав для настройки CRM';
  end if;
  if p_stage_ids is null or cardinality(p_stage_ids) = 0 then
    raise exception 'Передан пустой порядок колонок';
  end if;
  if cardinality(p_stage_ids) <> (
    select count(distinct id) from unnest(p_stage_ids) as ids(id)
  ) then
    raise exception 'В порядке колонок есть повторы';
  end if;

  select count(*)
    into v_expected
  from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.is_active;

  if cardinality(p_stage_ids) <> v_expected then
    raise exception 'Порядок должен содержать все активные колонки';
  end if;
  if exists (
    select 1
    from unnest(p_stage_ids) as ids(id)
    left join public.recruitment_pipeline_stages stage
      on stage.id = ids.id
     and stage.company_id = v_company_id
     and stage.is_active
    where stage.id is null
  ) then
    raise exception 'В порядке есть недоступная колонка';
  end if;

  update public.recruitment_pipeline_stages stage
  set sort_order = ordered.position * 10
  from unnest(p_stage_ids) with ordinality as ordered(id, position)
  where stage.company_id = v_company_id
    and stage.id = ordered.id
    and stage.is_active;
  get diagnostics v_updated = row_count;

  if v_updated <> v_expected then
    raise exception 'Не удалось сохранить полный порядок колонок';
  end if;
end;
$$;

revoke all on function public.reorder_recruitment_pipeline_stages(uuid[])
  from public, anon;
grant execute on function public.reorder_recruitment_pipeline_stages(uuid[])
  to authenticated;

create or replace function public.reorder_recruitment_custom_fields(
  p_field_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_expected integer;
  v_updated integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('recruitment.crm.configure') then
    raise exception 'Недостаточно прав для настройки CRM';
  end if;
  if p_field_ids is null or cardinality(p_field_ids) = 0 then
    raise exception 'Передан пустой порядок полей';
  end if;
  if cardinality(p_field_ids) <> (
    select count(distinct id) from unnest(p_field_ids) as ids(id)
  ) then
    raise exception 'В порядке полей есть повторы';
  end if;

  select count(*)
    into v_expected
  from public.recruitment_custom_fields field
  where field.company_id = v_company_id
    and field.is_active;

  if cardinality(p_field_ids) <> v_expected then
    raise exception 'Порядок должен содержать все активные поля';
  end if;
  if exists (
    select 1
    from unnest(p_field_ids) as ids(id)
    left join public.recruitment_custom_fields field
      on field.id = ids.id
     and field.company_id = v_company_id
     and field.is_active
    where field.id is null
  ) then
    raise exception 'В порядке есть недоступное поле';
  end if;

  update public.recruitment_custom_fields field
  set sort_order = ordered.position * 10
  from unnest(p_field_ids) with ordinality as ordered(id, position)
  where field.company_id = v_company_id
    and field.id = ordered.id
    and field.is_active;
  get diagnostics v_updated = row_count;

  if v_updated <> v_expected then
    raise exception 'Не удалось сохранить полный порядок полей';
  end if;
end;
$$;

revoke all on function public.reorder_recruitment_custom_fields(uuid[])
  from public, anon;
grant execute on function public.reorder_recruitment_custom_fields(uuid[])
  to authenticated;

create or replace function public.save_recruitment_application_from_crm(
  p_application_id uuid,
  p_full_name text,
  p_phone text,
  p_citizenship text,
  p_vacancy_id uuid,
  p_position_title text,
  p_object_id uuid,
  p_experience_text text,
  p_ready_date date,
  p_stage_id uuid,
  p_hr_comment text,
  p_custom_values jsonb,
  p_source text default 'manual',
  p_external_user_id text default '',
  p_external_chat_id text default ''
)
returns public.recruitment_applications
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_stage public.recruitment_pipeline_stages%rowtype;
  v_previous_stage_id uuid;
  v_result public.recruitment_applications%rowtype;
  v_is_new boolean := p_application_id is null;
begin
  if (select auth.uid()) is null then
    raise exception 'Требуется авторизация';
  end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения кандидатов';
  end if;
  if char_length(btrim(coalesce(p_full_name, ''))) < 2
     or btrim(coalesce(p_phone, '')) = ''
     or btrim(coalesce(p_position_title, '')) = '' then
    raise exception 'Укажите ФИО, телефон и вакансию';
  end if;
  if p_object_id is null or not exists (
    select 1
    from public.objects object
    where object.company_id = v_company_id
      and object.id = p_object_id
      and object.is_active
  ) then
    raise exception 'Объект не найден или недоступен';
  end if;
  if p_custom_values is null or jsonb_typeof(p_custom_values) <> 'object' then
    raise exception 'Дополнительные поля должны быть объектом';
  end if;

  select *
    into v_stage
  from public.recruitment_pipeline_stages stage
  where stage.company_id = v_company_id
    and stage.id = p_stage_id
    and stage.is_active;
  if v_stage.id is null then
    raise exception 'Колонка CRM не найдена или недоступна';
  end if;

  if v_is_new then
    insert into public.recruitment_applications(
      company_id,
      source,
      external_user_id,
      external_chat_id,
      full_name,
      phone,
      citizenship,
      object_id,
      vacancy_id,
      position_title,
      experience_text,
      ready_date,
      status,
      stage_id,
      hr_comment,
      custom_values,
      submitted_at,
      updated_at
    )
    values (
      v_company_id,
      case when btrim(coalesce(p_source, '')) = '' then 'manual' else btrim(p_source) end,
      btrim(coalesce(p_external_user_id, '')),
      btrim(coalesce(p_external_chat_id, '')),
      btrim(p_full_name),
      btrim(p_phone),
      btrim(coalesce(p_citizenship, '')),
      p_object_id,
      p_vacancy_id,
      btrim(p_position_title),
      btrim(coalesce(p_experience_text, '')),
      p_ready_date,
      v_stage.legacy_status,
      v_stage.id,
      btrim(coalesce(p_hr_comment, '')),
      p_custom_values,
      now(),
      now()
    )
    returning * into v_result;
  else
    select application.stage_id
      into v_previous_stage_id
    from public.recruitment_applications application
    where application.company_id = v_company_id
      and application.id = p_application_id
    for update;
    if not found then
      raise exception 'Кандидат не найден или недоступен';
    end if;

    update public.recruitment_applications application
    set full_name = btrim(p_full_name),
        phone = btrim(p_phone),
        citizenship = btrim(coalesce(p_citizenship, '')),
        object_id = p_object_id,
        vacancy_id = p_vacancy_id,
        position_title = btrim(p_position_title),
        experience_text = btrim(coalesce(p_experience_text, '')),
        ready_date = p_ready_date,
        status = v_stage.legacy_status,
        stage_id = v_stage.id,
        hr_comment = btrim(coalesce(p_hr_comment, '')),
        custom_values = p_custom_values,
        updated_at = now()
    where application.company_id = v_company_id
      and application.id = p_application_id
    returning * into v_result;
  end if;

  if v_is_new or v_previous_stage_id is distinct from v_stage.id then
    insert into public.recruitment_status_history(
      company_id,
      application_id,
      status,
      stage_id,
      stage_title,
      source,
      created_by
    ) values (
      v_company_id,
      v_result.id,
      v_result.status,
      v_stage.id,
      v_stage.title,
      'appstroy_hr',
      (select auth.uid())
    );
  end if;

  return v_result;
end;
$$;

revoke all on function public.save_recruitment_application_from_crm(
  uuid, text, text, text, uuid, text, uuid, text, date, uuid, text, jsonb,
  text, text, text
) from public, anon;
grant execute on function public.save_recruitment_application_from_crm(
  uuid, text, text, text, uuid, text, uuid, text, date, uuid, text, jsonb,
  text, text, text
) to authenticated;
