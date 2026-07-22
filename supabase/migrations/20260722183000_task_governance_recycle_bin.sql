alter table public.tasks
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.user_profiles(id) on delete set null,
  add column if not exists delete_reason text not null default '',
  add column if not exists restored_at timestamptz,
  add column if not exists restored_by uuid references public.user_profiles(id) on delete set null;

create index if not exists tasks_company_deleted_at_idx
  on public.tasks(company_id, deleted_at desc)
  where deleted_at is not null;

create table if not exists public.task_action_audit (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid references public.objects(id) on delete set null,
  task_id uuid,
  action text not null check (
    action in (
      'created',
      'updated',
      'status_changed',
      'photo_added',
      'photo_removed',
      'photo_updated',
      'assignee_added',
      'assignee_removed',
      'goal_linked',
      'goal_unlinked',
      'goal_updated',
      'archived',
      'restored'
    )
  ),
  actor_user_id uuid references public.user_profiles(id) on delete set null,
  actor_name text not null default '',
  task_date date,
  object_name text not null default '',
  before_value jsonb,
  after_value jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.task_action_audit enable row level security;
revoke all on table public.task_action_audit from anon, authenticated;
revoke all on sequence public.task_action_audit_id_seq from anon, authenticated;

create index if not exists task_action_audit_company_created_idx
  on public.task_action_audit(company_id, created_at desc);

create index if not exists task_action_audit_task_created_idx
  on public.task_action_audit(task_id, created_at desc);

create or replace function private.task_audit_actor_name()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    nullif(btrim(profile.full_name), ''),
    nullif(btrim(profile.email), ''),
    case when auth.uid() is null then 'Система' else auth.uid()::text end
  )
  from (select 1) seed
  left join public.user_profiles profile on profile.id = auth.uid();
$$;

revoke all on function private.task_audit_actor_name()
from public, anon, authenticated;

create or replace function private.write_task_audit(
  p_company_id uuid,
  p_object_id uuid,
  p_task_id uuid,
  p_action text,
  p_task_date date,
  p_object_name text,
  p_before jsonb,
  p_after jsonb,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_company_id is null or p_task_id is null then
    return;
  end if;

  insert into public.task_action_audit(
    company_id,
    object_id,
    task_id,
    action,
    actor_user_id,
    actor_name,
    task_date,
    object_name,
    before_value,
    after_value,
    metadata
  ) values (
    p_company_id,
    p_object_id,
    p_task_id,
    p_action,
    auth.uid(),
    private.task_audit_actor_name(),
    p_task_date,
    coalesce(p_object_name, ''),
    p_before,
    p_after,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function private.write_task_audit(
  uuid,
  uuid,
  uuid,
  text,
  date,
  text,
  jsonb,
  jsonb,
  jsonb
) from public, anon, authenticated;

create or replace function private.audit_task_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_action text;
begin
  if tg_op = 'INSERT' then
    if new.is_draft then
      return new;
    end if;

    perform private.write_task_audit(
      new.company_id,
      new.object_id,
      new.id,
      'created',
      new.task_date,
      new.object_name,
      null,
      to_jsonb(new),
      '{}'::jsonb
    );
    return new;
  end if;

  if old.deleted_at is null and new.deleted_at is not null then
    v_action := 'archived';
  elsif old.deleted_at is not null and new.deleted_at is null then
    v_action := 'restored';
  elsif old.is_draft and not new.is_draft then
    v_action := 'created';
  elsif old.status is distinct from new.status then
    v_action := 'status_changed';
  elsif old.task_date is distinct from new.task_date
     or old.object_id is distinct from new.object_id
     or old.object_name is distinct from new.object_name
     or old.axes is distinct from new.axes
     or old.work is distinct from new.work
     or old.not_done_comment is distinct from new.not_done_comment then
    v_action := 'updated';
  else
    return new;
  end if;

  perform private.write_task_audit(
    new.company_id,
    new.object_id,
    new.id,
    v_action,
    new.task_date,
    new.object_name,
    to_jsonb(old),
    to_jsonb(new),
    case
      when v_action = 'status_changed' then jsonb_build_object(
        'old_status', old.status,
        'new_status', new.status
      )
      when v_action = 'archived' then jsonb_build_object(
        'reason', new.delete_reason
      )
      else '{}'::jsonb
    end
  );

  return new;
end;
$$;

revoke all on function private.audit_task_change()
from public, anon, authenticated;

drop trigger if exists tasks_action_audit on public.tasks;
create trigger tasks_action_audit
after insert or update on public.tasks
for each row execute function private.audit_task_change();

create or replace function private.audit_task_child_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_task_id uuid;
  v_task public.tasks;
  v_action text;
  v_before jsonb;
  v_after jsonb;
  v_metadata jsonb := '{}'::jsonb;
begin
  v_task_id := case when tg_op = 'DELETE' then old.task_id else new.task_id end;

  select *
  into v_task
  from public.tasks
  where id = v_task_id;

  if v_task.id is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_table_name = 'task_photos' then
    if tg_op = 'INSERT' then
      v_action := 'photo_added';
      v_after := to_jsonb(new);
      v_metadata := jsonb_build_object(
        'photo_stage', new.photo_stage,
        'original_name', new.original_name
      );
    elsif tg_op = 'DELETE' then
      v_action := 'photo_removed';
      v_before := to_jsonb(old);
      v_metadata := jsonb_build_object(
        'photo_stage', old.photo_stage,
        'original_name', old.original_name
      );
    else
      v_action := 'photo_updated';
      v_before := to_jsonb(old);
      v_after := to_jsonb(new);
      v_metadata := jsonb_build_object(
        'old_stage', old.photo_stage,
        'new_stage', new.photo_stage
      );
    end if;
  elsif tg_table_name = 'task_assignees' then
    if tg_op = 'INSERT' then
      v_action := 'assignee_added';
      v_after := to_jsonb(new);
      v_metadata := jsonb_build_object('employee_id', new.employee_id);
    elsif tg_op = 'DELETE' then
      v_action := 'assignee_removed';
      v_before := to_jsonb(old);
      v_metadata := jsonb_build_object('employee_id', old.employee_id);
    else
      return new;
    end if;
  elsif tg_table_name = 'task_milestone_links' then
    if tg_op = 'INSERT' then
      v_action := 'goal_linked';
      v_after := to_jsonb(new);
    elsif tg_op = 'DELETE' then
      v_action := 'goal_unlinked';
      v_before := to_jsonb(old);
    else
      v_action := 'goal_updated';
      v_before := to_jsonb(old);
      v_after := to_jsonb(new);
    end if;
  else
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  perform private.write_task_audit(
    v_task.company_id,
    v_task.object_id,
    v_task.id,
    v_action,
    v_task.task_date,
    v_task.object_name,
    v_before,
    v_after,
    v_metadata
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.audit_task_child_change()
from public, anon, authenticated;

drop trigger if exists task_photos_action_audit on public.task_photos;
create trigger task_photos_action_audit
after insert or update or delete on public.task_photos
for each row execute function private.audit_task_child_change();

drop trigger if exists task_assignees_action_audit on public.task_assignees;
create trigger task_assignees_action_audit
after insert or delete on public.task_assignees
for each row execute function private.audit_task_child_change();

drop trigger if exists task_milestone_links_action_audit
on public.task_milestone_links;
create trigger task_milestone_links_action_audit
after insert or update or delete on public.task_milestone_links
for each row execute function private.audit_task_child_change();

create or replace function public.task_can_edit_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists(
    select 1
    from public.tasks task
    where task.id = p_task_id
      and task.company_id = public.current_user_company_id()
      and task.deleted_at is null
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
              and public.task_policy_bool(
                task.object_name,
                'foreman_can_create_any_date',
                false
              )
            )
            or (
              task.task_date < public.current_operational_date()
              and public.task_policy_bool(
                task.object_name,
                'foreman_can_edit_past_tasks',
                false
              )
              and (
                (public.get_effective_task_policy(task.object_name)
                  -> 'edit_window_days') = 'null'::jsonb
                or task.task_date >= public.current_operational_date()
                  - public.task_policy_int(
                    task.object_name,
                    'edit_window_days',
                    0
                  )
              )
            )
          )
        )
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
  select exists(
    select 1
    from public.tasks task
    where task.id = p_task_id
      and task.company_id = public.current_user_company_id()
      and task.deleted_at is null
      and not task.is_draft
      and (
        public.is_admin()
        or (
          public.task_can_edit_for_user(task.id)
          and public.task_policy_bool(
            task.object_name,
            'foreman_can_delete_task',
            false
          )
        )
      )
  );
$$;

drop policy if exists tasks_select_company_object on public.tasks;
create policy tasks_select_company_object
on public.tasks
for select
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    not is_draft
    or (select public.is_admin())
    or created_by_user_id = (select auth.uid())
  )
);

drop policy if exists tasks_delete_company_admin on public.tasks;
drop policy if exists tasks_delete_own_draft_only on public.tasks;
create policy tasks_delete_own_draft_only
on public.tasks
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and is_draft
  and deleted_at is null
  and (
    (select public.is_admin())
    or created_by_user_id = (select auth.uid())
  )
);

create or replace function public.archive_task(
  p_task_id uuid,
  p_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_task public.tasks;
  v_reason text := left(btrim(coalesce(p_reason, '')), 500);
begin
  if auth.uid() is null or v_company_id is null then
    raise exception 'Требуется активная сессия и компания';
  end if;

  select *
  into v_task
  from public.tasks
  where id = p_task_id
    and company_id = v_company_id
  for update;

  if v_task.id is null then
    raise exception 'Задача не найдена';
  end if;

  if v_task.deleted_at is not null then
    raise exception 'Задача уже находится в корзине';
  end if;

  if v_task.is_draft then
    raise exception 'Черновик нельзя переместить в корзину';
  end if;

  if not public.task_can_delete_for_user(v_task.id) then
    raise exception 'Недостаточно прав для удаления задачи';
  end if;

  update public.tasks
  set deleted_at = now(),
      deleted_by = auth.uid(),
      delete_reason = v_reason,
      restored_at = null,
      restored_by = null,
      updated_at = now()
  where id = v_task.id;

  return jsonb_build_object('id', v_task.id, 'archived', true);
end;
$$;

revoke all on function public.archive_task(uuid, text) from public, anon;
grant execute on function public.archive_task(uuid, text) to authenticated;

create or replace function public.restore_task(p_task_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_task public.tasks;
begin
  if auth.uid() is null
     or v_company_id is null
     or not public.is_admin() then
    raise exception 'Восстанавливать задачи может только администратор или разработчик';
  end if;

  select *
  into v_task
  from public.tasks
  where id = p_task_id
    and company_id = v_company_id
  for update;

  if v_task.id is null then
    raise exception 'Задача не найдена';
  end if;

  if v_task.deleted_at is null then
    raise exception 'Задача уже восстановлена';
  end if;

  if not public.is_active_object(v_task.object_name) then
    raise exception 'Сначала восстановите объект задачи';
  end if;

  update public.tasks
  set deleted_at = null,
      deleted_by = null,
      delete_reason = '',
      restored_at = now(),
      restored_by = auth.uid(),
      updated_at = now()
  where id = v_task.id;

  return jsonb_build_object('id', v_task.id, 'restored', true);
end;
$$;

revoke all on function public.restore_task(uuid) from public, anon;
grant execute on function public.restore_task(uuid) to authenticated;

create or replace function public.get_task_governance_center(
  p_object_id uuid default null,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_limit integer := greatest(20, least(coalesce(p_limit, 200), 500));
  v_object_exists boolean;
begin
  if auth.uid() is null
     or v_company_id is null
     or not public.is_admin() then
    raise exception 'Журнал и корзина доступны только администратору или разработчику';
  end if;

  if p_object_id is not null then
    select exists(
      select 1
      from public.objects object
      where object.id = p_object_id
        and object.company_id = v_company_id
    ) into v_object_exists;

    if not v_object_exists then
      raise exception 'Объект не найден или недоступен';
    end if;
  end if;

  return jsonb_build_object(
    'objects',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', object.id,
          'name', object.name,
          'is_active', object.is_active
        )
        order by object.is_active desc, object.name
      )
      from public.objects object
      where object.company_id = v_company_id
    ), '[]'::jsonb),
    'trash',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', task.id,
          'task_date', task.task_date,
          'object_id', task.object_id,
          'object_name', task.object_name,
          'axes', task.axes,
          'work', task.work,
          'status', task.status,
          'deleted_at', task.deleted_at,
          'deleted_by', task.deleted_by,
          'deleted_by_name', coalesce(
            nullif(btrim(profile.full_name), ''),
            nullif(btrim(profile.email), ''),
            ''
          ),
          'delete_reason', task.delete_reason
        )
        order by task.deleted_at desc
      )
      from public.tasks task
      left join public.user_profiles profile on profile.id = task.deleted_by
      where task.company_id = v_company_id
        and task.deleted_at is not null
        and (p_object_id is null or task.object_id = p_object_id)
    ), '[]'::jsonb),
    'audit',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', audit.id,
          'task_id', audit.task_id,
          'object_id', audit.object_id,
          'object_name', audit.object_name,
          'task_date', audit.task_date,
          'action', audit.action,
          'actor_user_id', audit.actor_user_id,
          'actor_name', audit.actor_name,
          'before_value', audit.before_value,
          'after_value', audit.after_value,
          'metadata', audit.metadata,
          'created_at', audit.created_at
        )
        order by audit.created_at desc
      )
      from (
        select entry.*
        from public.task_action_audit entry
        where entry.company_id = v_company_id
          and (p_object_id is null or entry.object_id = p_object_id)
        order by entry.created_at desc
        limit v_limit
      ) audit
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_task_governance_center(uuid, integer)
from public, anon;
grant execute on function public.get_task_governance_center(uuid, integer)
to authenticated;
