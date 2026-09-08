alter table public.company_task_policies
  add column if not exists foreman_timesheet_edit_window_days integer;

comment on column public.company_task_policies.foreman_timesheet_edit_window_days is
  'How many previous calendar days a foreman may edit attendance. NULL means unlimited, 0 means today only.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'company_task_policies_timesheet_window_check'
      and conrelid = 'public.company_task_policies'::regclass
  ) then
    alter table public.company_task_policies
      add constraint company_task_policies_timesheet_window_check
      check (
        foreman_timesheet_edit_window_days is null
        or foreman_timesheet_edit_window_days between 0 and 3650
      );
  end if;
end;
$$;

create or replace function public.task_policy_row_to_json(
  p public.company_task_policies
)
returns jsonb
language sql
stable
set search_path to 'public', 'pg_temp'
as $$
select jsonb_build_object(
  'id', p.id,
  'company_id', p.company_id,
  'object_id', p.object_id,
  'require_before_photo', p.require_before_photo,
  'min_before_photos', p.min_before_photos,
  'require_after_photo_on_complete', p.require_after_photo_on_complete,
  'min_after_photos', p.min_after_photos,
  'require_not_done_comment', p.require_not_done_comment,
  'foreman_can_create_any_date', p.foreman_can_create_any_date,
  'foreman_can_edit_past_tasks', p.foreman_can_edit_past_tasks,
  'edit_window_days', p.edit_window_days,
  'foreman_timesheet_edit_window_days', p.foreman_timesheet_edit_window_days,
  'foreman_can_edit_date', p.foreman_can_edit_date,
  'foreman_can_edit_axes_work', p.foreman_can_edit_axes_work,
  'foreman_can_edit_assignees', p.foreman_can_edit_assignees,
  'foreman_can_edit_status', p.foreman_can_edit_status,
  'foreman_can_delete_before_photos', p.foreman_can_delete_before_photos,
  'foreman_can_delete_after_photos', p.foreman_can_delete_after_photos,
  'foreman_can_delete_task', p.foreman_can_delete_task,
  'updated_at', p.updated_at,
  'updated_by', p.updated_by
);
$$;

create or replace function public.get_effective_task_policy(p_object_name text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_policy public.company_task_policies;
begin
  if auth.uid() is null or v_company_id is null then
    raise exception 'Требуется вход в рабочую компанию';
  end if;

  select policy.*
    into v_policy
    from public.company_task_policies policy
    left join public.objects object
      on object.id = policy.object_id
     and object.company_id = policy.company_id
   where policy.company_id = v_company_id
     and (
       (
         policy.object_id is not null
         and lower(btrim(object.name)) = lower(btrim(coalesce(p_object_name, '')))
       )
       or policy.object_id is null
     )
   order by (policy.object_id is not null) desc
   limit 1;

  if v_policy.id is null then
    return jsonb_build_object(
      'id', null,
      'company_id', v_company_id,
      'object_id', null,
      'require_before_photo', true,
      'min_before_photos', 1,
      'require_after_photo_on_complete', true,
      'min_after_photos', 1,
      'require_not_done_comment', true,
      'foreman_can_create_any_date', false,
      'foreman_can_edit_past_tasks', false,
      'edit_window_days', 0,
      'foreman_timesheet_edit_window_days', null,
      'foreman_can_edit_date', true,
      'foreman_can_edit_axes_work', true,
      'foreman_can_edit_assignees', true,
      'foreman_can_edit_status', true,
      'foreman_can_delete_before_photos', true,
      'foreman_can_delete_after_photos', true,
      'foreman_can_delete_task', false,
      'updated_at', null,
      'updated_by', null
    );
  end if;

  return public.task_policy_row_to_json(v_policy);
end;
$$;

create or replace function public.save_task_policy_setting(
  p_object_id uuid,
  p_policy jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_existing public.company_task_policies;
  v_saved public.company_task_policies;
  v_action text;
  v_require_before boolean := coalesce((p_policy->>'require_before_photo')::boolean, true);
  v_min_before integer := greatest(0, least(20, coalesce((p_policy->>'min_before_photos')::integer, 1)));
  v_require_after boolean := coalesce((p_policy->>'require_after_photo_on_complete')::boolean, true);
  v_min_after integer := greatest(0, least(20, coalesce((p_policy->>'min_after_photos')::integer, 1)));
  v_require_comment boolean := coalesce((p_policy->>'require_not_done_comment')::boolean, true);
  v_create_any boolean := coalesce((p_policy->>'foreman_can_create_any_date')::boolean, false);
  v_edit_past boolean := coalesce((p_policy->>'foreman_can_edit_past_tasks')::boolean, false);
  v_window integer := case
    when not (p_policy ? 'edit_window_days') or p_policy->'edit_window_days' = 'null'::jsonb then null
    else greatest(0, least(3650, (p_policy->>'edit_window_days')::integer))
  end;
  v_timesheet_window integer := case
    when not (p_policy ? 'foreman_timesheet_edit_window_days')
      or p_policy->'foreman_timesheet_edit_window_days' = 'null'::jsonb then null
    else greatest(
      0,
      least(3650, (p_policy->>'foreman_timesheet_edit_window_days')::integer)
    )
  end;
  v_edit_date boolean := coalesce((p_policy->>'foreman_can_edit_date')::boolean, true);
  v_edit_axes boolean := coalesce((p_policy->>'foreman_can_edit_axes_work')::boolean, true);
  v_edit_assignees boolean := coalesce((p_policy->>'foreman_can_edit_assignees')::boolean, true);
  v_edit_status boolean := coalesce((p_policy->>'foreman_can_edit_status')::boolean, true);
  v_delete_before boolean := coalesce((p_policy->>'foreman_can_delete_before_photos')::boolean, true);
  v_delete_after boolean := coalesce((p_policy->>'foreman_can_delete_after_photos')::boolean, true);
  v_delete_task boolean := coalesce((p_policy->>'foreman_can_delete_task')::boolean, false);
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Изменять ограничения может только администратор или разработчик';
  end if;

  if p_object_id is not null and not exists (
    select 1
      from public.objects
     where id = p_object_id
       and company_id = v_company_id
       and is_active = true
  ) then
    raise exception 'Объект не найден или недоступен';
  end if;

  select *
    into v_existing
    from public.company_task_policies
   where company_id = v_company_id
     and object_id is not distinct from p_object_id
   limit 1;

  v_action := case when v_existing.id is null then 'create' else 'update' end;

  if p_object_id is null then
    insert into public.company_task_policies(
      company_id,
      object_id,
      require_before_photo,
      min_before_photos,
      require_after_photo_on_complete,
      min_after_photos,
      require_not_done_comment,
      foreman_can_create_any_date,
      foreman_can_edit_past_tasks,
      edit_window_days,
      foreman_timesheet_edit_window_days,
      foreman_can_edit_date,
      foreman_can_edit_axes_work,
      foreman_can_edit_assignees,
      foreman_can_edit_status,
      foreman_can_delete_before_photos,
      foreman_can_delete_after_photos,
      foreman_can_delete_task,
      updated_at,
      updated_by
    ) values (
      v_company_id,
      null,
      v_require_before,
      v_min_before,
      v_require_after,
      v_min_after,
      v_require_comment,
      v_create_any,
      v_edit_past,
      v_window,
      v_timesheet_window,
      v_edit_date,
      v_edit_axes,
      v_edit_assignees,
      v_edit_status,
      v_delete_before,
      v_delete_after,
      v_delete_task,
      now(),
      auth.uid()
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
      foreman_timesheet_edit_window_days = excluded.foreman_timesheet_edit_window_days,
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
      company_id,
      object_id,
      require_before_photo,
      min_before_photos,
      require_after_photo_on_complete,
      min_after_photos,
      require_not_done_comment,
      foreman_can_create_any_date,
      foreman_can_edit_past_tasks,
      edit_window_days,
      foreman_timesheet_edit_window_days,
      foreman_can_edit_date,
      foreman_can_edit_axes_work,
      foreman_can_edit_assignees,
      foreman_can_edit_status,
      foreman_can_delete_before_photos,
      foreman_can_delete_after_photos,
      foreman_can_delete_task,
      updated_at,
      updated_by
    ) values (
      v_company_id,
      p_object_id,
      v_require_before,
      v_min_before,
      v_require_after,
      v_min_after,
      v_require_comment,
      v_create_any,
      v_edit_past,
      v_window,
      v_timesheet_window,
      v_edit_date,
      v_edit_axes,
      v_edit_assignees,
      v_edit_status,
      v_delete_before,
      v_delete_after,
      v_delete_task,
      now(),
      auth.uid()
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
      foreman_timesheet_edit_window_days = excluded.foreman_timesheet_edit_window_days,
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
    company_id,
    object_id,
    setting_group,
    action,
    old_value,
    new_value,
    changed_by
  ) values (
    v_company_id,
    p_object_id,
    'task_policy',
    v_action,
    case
      when v_existing.id is null then null
      else public.task_policy_row_to_json(v_existing)
    end,
    public.task_policy_row_to_json(v_saved),
    auth.uid()
  );

  return public.get_developer_task_policy_center();
end;
$$;

create or replace function public.current_user_can_edit_attendance_date(
  p_work_date date,
  p_object_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
  v_window integer;
  v_has_object_override boolean := false;
begin
  if auth.uid() is null or v_company_id is null or p_work_date is null then
    return false;
  end if;

  if v_role is distinct from 'foreman' then
    return true;
  end if;

  if p_object_id is not null then
    select exists(
      select 1
        from public.company_task_policies policy
       where policy.company_id = v_company_id
         and policy.object_id = p_object_id
    ) into v_has_object_override;
  end if;

  if v_has_object_override then
    select policy.foreman_timesheet_edit_window_days
      into v_window
      from public.company_task_policies policy
     where policy.company_id = v_company_id
       and policy.object_id = p_object_id
     limit 1;
  else
    select policy.foreman_timesheet_edit_window_days
      into v_window
      from public.company_task_policies policy
     where policy.company_id = v_company_id
       and policy.object_id is null
     limit 1;
  end if;

  if v_window is null then
    return true;
  end if;

  return p_work_date >= current_date - v_window;
end;
$$;

revoke all on function public.current_user_can_edit_attendance_date(date, uuid) from public;
grant execute on function public.current_user_can_edit_attendance_date(date, uuid) to authenticated;
grant execute on function public.current_user_can_edit_attendance_date(date, uuid) to service_role;

drop policy if exists attendance_insert_company_object on public.attendance;
create policy attendance_insert_company_object
on public.attendance
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.edit', object_id)
  and public.current_user_can_edit_attendance_date(work_date, object_id)
  and exists (
    select 1
      from public.employees employee
     where employee.id = attendance.employee_id
       and employee.company_id = attendance.company_id
       and employee.object_id = attendance.object_id
  )
);

drop policy if exists attendance_update_company_object on public.attendance;
create policy attendance_update_company_object
on public.attendance
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.edit', object_id)
  and public.current_user_can_edit_attendance_date(work_date, object_id)
)
with check (
  company_id = public.current_user_company_id()
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.edit', object_id)
  and public.current_user_can_edit_attendance_date(work_date, object_id)
);
