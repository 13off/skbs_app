create or replace function public.create_task_batch(
  p_object_name text,
  p_tasks jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := auth.uid();
  v_actor_name text;
  v_object_name text := btrim(coalesce(p_object_name, ''));
  v_item jsonb;
  v_task public.tasks%rowtype;
  v_task_date date;
  v_axes text;
  v_work text;
  v_assignee_ids uuid[];
  v_milestone_id uuid;
  v_checklist_item_id uuid;
  v_result jsonb := '[]'::jsonb;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Требуется авторизация и активная компания';
  end if;
  if v_object_name = '' then raise exception 'Объект не указан'; end if;
  if p_tasks is null or jsonb_typeof(p_tasks) <> 'array' then
    raise exception 'Пакет задач должен быть массивом';
  end if;
  if jsonb_array_length(p_tasks) < 2 or jsonb_array_length(p_tasks) > 50 then
    raise exception 'В пакете должно быть от 2 до 50 задач';
  end if;
  if public.task_policy_bool(v_object_name, 'require_before_photo', true) then
    raise exception 'Для объекта обязательны фото. Создайте задачи по одной';
  end if;

  select coalesce(
      nullif(btrim(profile.full_name), ''),
      nullif(btrim(profile.email), ''),
      'Пользователь AppСтрой'
    )
    into v_actor_name
  from public.user_profiles profile
  where profile.id = v_user_id;
  v_actor_name := coalesce(v_actor_name, 'Пользователь AppСтрой');

  for v_item in select value from jsonb_array_elements(p_tasks)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'Каждая задача в пакете должна быть объектом';
    end if;
    begin
      v_task_date := (v_item ->> 'task_date')::date;
    exception when invalid_text_representation or datetime_field_overflow then
      raise exception 'Некорректная дата задачи';
    end;
    if v_task_date is null then raise exception 'Дата задачи не указана'; end if;
    v_axes := btrim(coalesce(v_item ->> 'axes', ''));
    v_work := btrim(coalesce(v_item ->> 'work', ''));

    if v_axes = '' or v_work = '' then
      raise exception 'У каждой задачи должны быть заполнены оси и вид работ';
    end if;
    if char_length(v_axes) > 1000 or char_length(v_work) > 4000 then
      raise exception 'Оси или вид работ превышают допустимую длину';
    end if;
    if not public.task_can_create_for_user(v_task_date, v_object_name) then
      raise exception 'Недостаточно прав для создания задачи на %', v_task_date;
    end if;

    select coalesce(array_agg(distinct clean_id), '{}'::uuid[])
      into v_assignee_ids
    from (
      select nullif(btrim(value), '')::uuid as clean_id
      from jsonb_array_elements_text(case
        when jsonb_typeof(v_item -> 'assignee_ids') = 'array'
          then v_item -> 'assignee_ids'
        else '[]'::jsonb
      end)
    ) ids
    where clean_id is not null;

    if cardinality(v_assignee_ids) > 100 then
      raise exception 'У задачи слишком много исполнителей';
    end if;
    if cardinality(v_assignee_ids) <> (
      select count(*)
      from public.employees employee
      where employee.company_id = v_company_id
        and employee.id = any(v_assignee_ids)
        and employee.is_active
        and employee.archived_at is null
    ) then
      raise exception 'Один из исполнителей недоступен или находится в архиве';
    end if;

    insert into public.tasks(
      company_id,
      task_date,
      object_name,
      axes,
      work,
      status,
      not_done_comment,
      created_by,
      created_by_user_id,
      is_draft,
      photo_requirements_enforced
    )
    values (
      v_company_id,
      v_task_date,
      v_object_name,
      v_axes,
      v_work,
      'Запланировано',
      '',
      v_actor_name,
      v_user_id,
      false,
      false
    )
    returning * into v_task;

    insert into public.task_assignees(company_id, task_id, employee_id)
    select v_company_id, v_task.id, assignee_id
    from unnest(v_assignee_ids) assignee_id;

    begin
      v_milestone_id := nullif(btrim(v_item ->> 'milestone_id'), '')::uuid;
      v_checklist_item_id := nullif(
        btrim(v_item ->> 'checklist_item_id'),
        ''
      )::uuid;
    exception when invalid_text_representation then
      raise exception 'Некорректная связь задачи с контрольной точкой';
    end;

    if (v_milestone_id is null) <> (v_checklist_item_id is null) then
      raise exception 'Контрольная точка и пункт чек-листа должны быть указаны вместе';
    end if;
    if v_milestone_id is not null then
      if not exists (
        select 1
        from public.project_milestones milestone
        join public.milestone_checklist_items item
          on item.milestone_id = milestone.id
        where milestone.id = v_milestone_id
          and milestone.company_id = v_company_id
          and lower(btrim(milestone.object_name)) = lower(v_object_name)
          and milestone.deleted_at is null
          and item.id = v_checklist_item_id
      ) then
        raise exception 'Контрольная точка недоступна для выбранного объекта';
      end if;

      insert into public.task_milestone_links(
        company_id,
        task_id,
        milestone_id,
        checklist_item_id,
        created_by
      )
      values (
        v_company_id,
        v_task.id,
        v_milestone_id,
        v_checklist_item_id,
        v_user_id
      );
    end if;

    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'id', v_task.id,
      'task_date', v_task.task_date,
      'object_name', v_task.object_name,
      'axes', v_task.axes,
      'work', v_task.work,
      'status', v_task.status,
      'not_done_comment', v_task.not_done_comment,
      'milestone_id', v_milestone_id,
      'checklist_item_id', v_checklist_item_id
    ));
  end loop;

  return v_result;
end;
$$;

revoke all on function public.create_task_batch(text,jsonb)
  from public, anon;
grant execute on function public.create_task_batch(text,jsonb)
  to authenticated;

create or replace function public.bulk_assign_recruitment_responsible(
  p_application_ids uuid[],
  p_responsible_user_id uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if (select auth.uid()) is null then raise exception 'Требуется авторизация'; end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения кандидатов';
  end if;
  if p_application_ids is null or cardinality(p_application_ids) = 0 then
    return 0;
  end if;
  if cardinality(p_application_ids) > 500 then
    raise exception 'За один раз можно изменить не более 500 кандидатов';
  end if;
  if cardinality(p_application_ids) <>
      (select count(distinct id) from unnest(p_application_ids) ids(id)) then
    raise exception 'В списке кандидатов есть повторы';
  end if;
  if p_responsible_user_id is not null and not exists (
    select 1
    from public.company_memberships membership
    where membership.company_id = v_company_id
      and membership.user_id = p_responsible_user_id
      and membership.is_active
      and membership.role in ('owner', 'admin', 'developer', 'hr')
  ) then
    raise exception 'Ответственный недоступен в активной компании';
  end if;
  if cardinality(p_application_ids) <> (
    select count(*)
    from public.recruitment_applications application
    where application.company_id = v_company_id
      and application.id = any(p_application_ids)
      and application.archived_at is null
  ) then
    raise exception 'Один из кандидатов не найден или находится в архиве';
  end if;

  update public.recruitment_applications application
  set responsible_user_id = p_responsible_user_id,
      updated_at = now()
  where application.company_id = v_company_id
    and application.id = any(p_application_ids)
    and application.responsible_user_id is distinct from p_responsible_user_id;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.bulk_assign_recruitment_responsible(uuid[],uuid)
  from public, anon;
grant execute on function public.bulk_assign_recruitment_responsible(uuid[],uuid)
  to authenticated;
