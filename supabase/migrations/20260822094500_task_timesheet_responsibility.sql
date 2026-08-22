create or replace function public.get_task_responsibility_fast(
  p_task_date date,
  p_object_name text default null
)
returns table(
  task_id uuid,
  creator_user_id uuid,
  creator_full_name text,
  creator_avatar_path text,
  created_at timestamptz,
  last_editor_user_id uuid,
  last_editor_full_name text,
  last_editor_avatar_path text,
  last_edited_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    t.id as task_id,
    t.created_by_user_id as creator_user_id,
    coalesce(nullif(btrim(creator.full_name), ''), nullif(btrim(t.created_by), ''), 'Неизвестно') as creator_full_name,
    creator.avatar_path as creator_avatar_path,
    t.created_at,
    latest.actor_user_id as last_editor_user_id,
    coalesce(nullif(btrim(editor.full_name), ''), 'Неизвестно') as last_editor_full_name,
    editor.avatar_path as last_editor_avatar_path,
    latest.created_at as last_edited_at
  from public.get_task_rows_fast(p_task_date, p_object_name) visible
  join public.tasks t on t.id = visible.id
  left join public.user_profiles creator on creator.id = t.created_by_user_id
  left join lateral (
    select a.actor_user_id, a.created_at
    from public.task_action_audit a
    where a.task_id = t.id
      and a.actor_user_id is not null
      and a.action <> 'created'
    order by a.created_at desc
    limit 1
  ) latest on true
  left join public.user_profiles editor on editor.id = latest.actor_user_id
  where auth.uid() is not null;
$$;

revoke all on function public.get_task_responsibility_fast(date, text) from public;
revoke all on function public.get_task_responsibility_fast(date, text) from anon;
grant execute on function public.get_task_responsibility_fast(date, text) to authenticated;

create or replace function public.get_attendance_responsibility_fast(
  p_work_date date,
  p_object_name text default null
)
returns table(
  employee_id uuid,
  actor_user_id uuid,
  actor_full_name text,
  actor_avatar_path text,
  acted_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    a.employee_id,
    a.marked_by_user_id as actor_user_id,
    coalesce(nullif(btrim(profile.full_name), ''), nullif(btrim(a.marked_by), ''), 'Неизвестно') as actor_full_name,
    profile.avatar_path as actor_avatar_path,
    a.updated_at as acted_at
  from public.get_attendance_rows_fast(
    p_work_date,
    p_work_date,
    p_object_name,
    null::uuid[],
    false
  ) visible
  join public.attendance a
    on a.employee_id = visible.employee_id
   and a.work_date = visible.work_date
  left join public.user_profiles profile on profile.id = a.marked_by_user_id
  where auth.uid() is not null;
$$;

revoke all on function public.get_attendance_responsibility_fast(date, text) from public;
revoke all on function public.get_attendance_responsibility_fast(date, text) from anon;
grant execute on function public.get_attendance_responsibility_fast(date, text) to authenticated;
