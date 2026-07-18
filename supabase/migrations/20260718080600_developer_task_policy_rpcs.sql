create or replace function public.get_developer_task_policy_center()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Панель разработчика доступна только администратору или разработчику';
  end if;

  insert into public.company_task_policies(company_id, object_id, updated_by)
  values (v_company_id, null, auth.uid())
  on conflict(company_id) where object_id is null do nothing;

  select jsonb_build_object(
    'company_policy', public.task_policy_row_to_json(company_policy),
    'objects', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', object.id,
          'name', object.name,
          'has_override', object_policy.id is not null,
          'policy', case when object_policy.id is null then public.task_policy_row_to_json(company_policy) else public.task_policy_row_to_json(object_policy) end
        ) order by object.name
      )
      from public.objects object
      left join public.company_task_policies object_policy
        on object_policy.company_id = object.company_id
       and object_policy.object_id = object.id
      where object.company_id = v_company_id
        and object.is_active = true
    ), '[]'::jsonb),
    'audit', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', audit.id,
        'object_id', audit.object_id,
        'object_name', object.name,
        'action', audit.action,
        'old_value', audit.old_value,
        'new_value', audit.new_value,
        'changed_at', audit.changed_at,
        'changed_by', audit.changed_by,
        'changed_by_name', profile.full_name
      ) order by audit.changed_at desc)
      from (
        select *
        from public.developer_settings_audit
        where company_id = v_company_id
          and setting_group = 'task_policy'
        order by changed_at desc
        limit 30
      ) audit
      left join public.objects object on object.id = audit.object_id
      left join public.user_profiles profile on profile.id = audit.changed_by
    ), '[]'::jsonb)
  ) into v_result
  from public.company_task_policies company_policy
  where company_policy.company_id = v_company_id
    and company_policy.object_id is null;

  return v_result;
end;
$$;

create or replace function public.save_task_policy_setting(
  p_object_id uuid,
  p_policy jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_existing public.company_task_policies;
  v_saved public.company_task_policies;
  v_object_exists boolean;
  v_action text;
  v_require_before boolean := coalesce((p_policy ->> 'require_before_photo')::boolean, true);
  v_min_before integer := greatest(0, least(20, coalesce((p_policy ->> 'min_before_photos')::integer, 1)));
  v_require_after boolean := coalesce((p_policy ->> 'require_after_photo_on_complete')::boolean, true);
  v_min_after integer := greatest(0, least(20, coalesce((p_policy ->> 'min_after_photos')::integer, 1)));
  v_require_comment boolean := coalesce((p_policy ->> 'require_not_done_comment')::boolean, true);
  v_create_any_date boolean := coalesce((p_policy ->> 'foreman_can_create_any_date')::boolean, false);
  v_edit_past boolean := coalesce((p_policy ->> 'foreman_can_edit_past_tasks')::boolean, false);
  v_edit_window integer := case
    when not (p_policy ? 'edit_window_days') or p_policy -> 'edit_window_days' = 'null'::jsonb then null
    else greatest(0, least(3650, (p_policy ->> 'edit_window_days')::integer))
  end;
  v_edit_date boolean := coalesce((p_policy ->> 'foreman_can_edit_date')::boolean, true);
  v_edit_axes boolean := coalesce((p_policy ->> 'foreman_can_edit_axes_work')::boolean, true);
  v_edit_assignees boolean := coalesce((p_policy ->> 'foreman_can_edit_assignees')::boolean, true);
  v_edit_status boolean := coalesce((p_policy ->> 'foreman_can_edit_status')::boolean, true);
  v_delete_before boolean := coalesce((p_policy ->> 'foreman_can_delete_before_photos')::boolean, true);
  v_delete_after boolean := coalesce((p_policy ->> 'foreman_can_delete_after_photos')::boolean, true);
  v_delete_task boolean := coalesce((p_policy ->> 'foreman_can_delete_task')::boolean, false);
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Изменять ограничения может только администратор или разработчик';
  end if;

  if p_object_id is not null then
    select exists(
      select 1 from public.objects
      where id = p_object_id
        and company_id = v_company_id
        and is_active = true
    ) into v_object_exists;
    if not v_object_exists then
      raise exception 'Объект не найден или недоступен';
    end if;
  end if;

  select * into v_existing
  from public.company_task_policies
  where company_id = v_company_id
    and object_id is not distinct from p_object_id
  limit 1;

  v_action := case when v_existing.id is null then 'create' else 'update' end;

  if p_object_id is null then
    insert into public.company_task_policies(
      company_id, object_id,
      require_before_photo, min_before_photos,
      require_after_photo_on_complete, min_after_photos,
      require_not_done_comment,
      foreman_can_create_any_date, foreman_can_edit_past_tasks, edit_window_days,
      foreman_can_edit_date, foreman_can_edit_axes_work,
      foreman_can_edit_assignees, foreman_can_edit_status,
      foreman_can_delete_before_photos, foreman_can_delete_after_photos,
      foreman_can_delete_task, updated_at, updated_by
    ) values (
      v_company_id, null,
      v_require_before, v_min_before,
      v_require_after, v_min_after,
      v_require_comment,
      v_create_any_date, v_edit_past, v_edit_window,
      v_edit_date, v_edit_axes,
      v_edit_assignees, v_edit_status,
      v_delete_before, v_delete_after,
      v_delete_task, now(), auth.uid()
    )
    on conflict(company_id) where object_id is null do update set
      require_before_photo = excluded.require_before_photo,
      min_before_photos = excluded.min_before_photos,
      require_after_photo_on_complete = excluded.require_after_photo_on_complete,
      min_after_photos = excluded.min_after_photos,
      require_not_done_comment = excluded.require_not_done_comment,
      foreman_can_create_any_date = excluded.foreman_can_create_any_date,
      foreman_can_edit_past_tasks = excluded.foreman_can_edit_past_tasks,
      edit_window_days = excluded.edit_window_days,
      foreman_can_edit_date = excluded.foreman_can_edit_date,
      foreman_can_edit_axes_work = excluded.foreman_can_edit_axes_work,
      foreman_can_edit_assignees = excluded.foreman_can_edit_assignees,
      foreman_can_edit_status = excluded.foreman_can_edit_status,
      foreman_can_delete_before_photos = excluded.foreman_can_delete_before_photos,
      foreman_can_delete_after_photos = excluded.foreman_can_delete_after_photos,
      foreman_can_delete_task = excluded.foreman_can_delete_task,
      updated_at = now(),
      updated_by = auth.uid()
    returning * into v_saved;
  else
    insert into public.company_task_policies(
      company_id, object_id,
      require_before_photo, min_before_photos,
      require_after_photo_on_complete, min_after_photos,
      require_not_done_comment,
      foreman_can_create_any_date, foreman_can_edit_past_tasks, edit_window_days,
      foreman_can_edit_date, foreman_can_edit_axes_work,
      foreman_can_edit_assignees, foreman_can_edit_status,
      foreman_can_delete_before_photos, foreman_can_delete_after_photos,
      foreman_can_delete_task, updated_at, updated_by
    ) values (
      v_company_id, p_object_id,
      v_require_before, v_min_before,
      v_require_after, v_min_after,
      v_require_comment,
      v_create_any_date, v_edit_past, v_edit_window,
      v_edit_date, v_edit_axes,
      v_edit_assignees, v_edit_status,
      v_delete_before, v_delete_after,
      v_delete_task, now(), auth.uid()
    )
    on conflict(company_id, object_id) where object_id is not null do update set
      require_before_photo = excluded.require_before_photo,
      min_before_photos = excluded.min_before_photos,
      require_after_photo_on_complete = excluded.require_after_photo_on_complete,
      min_after_photos = excluded.min_after_photos,
      require_not_done_comment = excluded.require_not_done_comment,
      foreman_can_create_any_date = excluded.foreman_can_create_any_date,
      foreman_can_edit_past_tasks = excluded.foreman_can_edit_past_tasks,
      edit_window_days = excluded.edit_window_days,
      foreman_can_edit_date = excluded.foreman_can_edit_date,
      foreman_can_edit_axes_work = excluded.foreman_can_edit_axes_work,
      foreman_can_edit_assignees = excluded.foreman_can_edit_assignees,
      foreman_can_edit_status = excluded.foreman_can_edit_status,
      foreman_can_delete_before_photos = excluded.foreman_can_delete_before_photos,
      foreman_can_delete_after_photos = excluded.foreman_can_delete_after_photos,
      foreman_can_delete_task = excluded.foreman_can_delete_task,
      updated_at = now(),
      updated_by = auth.uid()
    returning * into v_saved;
  end if;

  insert into public.developer_settings_audit(
    company_id, object_id, setting_group, action,
    old_value, new_value, changed_by
  ) values (
    v_company_id,
    p_object_id,
    'task_policy',
    v_action,
    case when v_existing.id is null then null else public.task_policy_row_to_json(v_existing) end,
    public.task_policy_row_to_json(v_saved),
    auth.uid()
  );

  return public.get_developer_task_policy_center();
end;
$$;

create or replace function public.reset_task_policy_override(p_object_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_existing public.company_task_policies;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Изменять ограничения может только администратор или разработчик';
  end if;
  if p_object_id is null then
    raise exception 'Настройки компании нельзя удалить';
  end if;

  select * into v_existing
  from public.company_task_policies
  where company_id = v_company_id
    and object_id = p_object_id;

  delete from public.company_task_policies
  where company_id = v_company_id
    and object_id = p_object_id;

  if v_existing.id is not null then
    insert into public.developer_settings_audit(
      company_id, object_id, setting_group, action,
      old_value, new_value, changed_by
    ) values (
      v_company_id,
      p_object_id,
      'task_policy',
      'reset',
      public.task_policy_row_to_json(v_existing),
      null,
      auth.uid()
    );
  end if;

  return public.get_developer_task_policy_center();
end;
$$;

create or replace function public.task_policy_bool(
  p_object_name text,
  p_key text,
  p_default boolean
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((public.get_effective_task_policy(p_object_name) ->> p_key)::boolean, p_default);
$$;

create or replace function public.task_policy_int(
  p_object_name text,
  p_key text,
  p_default integer
)
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((public.get_effective_task_policy(p_object_name) ->> p_key)::integer, p_default);
$$;

create or replace function public.task_can_create_for_user(
  p_task_date date,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    public.can_access_object(p_object_name)
    and public.is_active_object(p_object_name)
    and (
      public.is_admin()
      or (
        public.is_foreman()
        and (
          p_task_date = public.current_operational_date()
          or public.task_policy_bool(p_object_name, 'foreman_can_create_any_date', false)
        )
      )
    );
$$;

create or replace function public.task_can_edit_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks task
    where task.id = p_task_id
      and task.company_id = public.current_user_company_id()
      and public.can_access_object(task.object_name)
      and public.is_active_object(task.object_name)
      and (
        public.is_admin()
        or (
          public.is_foreman()
          and (
            task.task_date = public.current_operational_date()
            or (
              task.task_date > public.current_operational_date()
              and public.task_policy_bool(task.object_name, 'foreman_can_create_any_date', false)
            )
            or (
              task.task_date < public.current_operational_date()
              and public.task_policy_bool(task.object_name, 'foreman_can_edit_past_tasks', false)
              and (
                (public.get_effective_task_policy(task.object_name) -> 'edit_window_days') = 'null'::jsonb
                or task.task_date >= public.current_operational_date()
                  - public.task_policy_int(task.object_name, 'edit_window_days', 0)
              )
            )
          )
        )
      )
  );
$$;

create or replace function public.task_is_mutable_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.task_can_edit_for_user(p_task_id);
$$;

create or replace function public.task_can_edit_assignees_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.tasks task
    where task.id = p_task_id
      and public.task_can_edit_for_user(task.id)
      and (
        public.is_admin()
        or public.task_policy_bool(task.object_name, 'foreman_can_edit_assignees', true)
      )
  );
$$;

create or replace function public.task_can_add_photo_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.task_can_edit_for_user(p_task_id);
$$;

create or replace function public.task_photo_can_delete_for_user(p_photo_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.task_photos photo
    join public.tasks task on task.id = photo.task_id
    where photo.id = p_photo_id
      and photo.company_id = public.current_user_company_id()
      and public.task_can_edit_for_user(task.id)
      and (
        public.is_admin()
        or case photo.photo_stage
          when 'after' then public.task_policy_bool(task.object_name, 'foreman_can_delete_after_photos', true)
          else public.task_policy_bool(task.object_name, 'foreman_can_delete_before_photos', true)
        end
      )
  );
$$;

create or replace function public.task_can_delete_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.tasks task
    where task.id = p_task_id
      and task.company_id = public.current_user_company_id()
      and (
        public.is_admin()
        or (
          public.task_can_edit_for_user(task.id)
          and public.task_policy_bool(task.object_name, 'foreman_can_delete_task', false)
        )
      )
  );
$$;
