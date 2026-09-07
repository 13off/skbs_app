-- Engineer-estimator workflow v1: role, completed-work reports, secure submit/review RPCs.

alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
  add constraint user_profiles_role_check check (
    role = any (array[
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'employee'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.company_memberships
  drop constraint if exists company_memberships_role_check;
alter table public.company_memberships
  add constraint company_memberships_role_check check (
    role = any (array[
      'owner'::text,
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.company_invitations
  drop constraint if exists company_invitations_role_check;
alter table public.company_invitations
  add constraint company_invitations_role_check check (
    role = any (array[
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.role_permissions
  drop constraint if exists role_permissions_role_check;
alter table public.role_permissions
  add constraint role_permissions_role_check check (
    role_code = any (array[
      'owner'::text,
      'admin'::text,
      'developer'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.app_notifications
  drop constraint if exists app_notifications_source_role_check;
alter table public.app_notifications
  add constraint app_notifications_source_role_check check (
    source_role = any (array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.app_notifications
  drop constraint if exists app_notifications_target_role_check;
alter table public.app_notifications
  add constraint app_notifications_target_role_check check (
    target_role is null or target_role = any (array[
      'admin'::text,
      'foreman'::text,
      'lawyer'::text,
      'accountant'::text,
      'hr'::text,
      'procurement'::text,
      'estimator'::text
    ])
  );

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_roles_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_roles_check check (
    selected_roles <@ array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text
    ]
  );

alter table public.notification_role_preferences
  drop constraint if exists notification_role_preferences_bell_roles_check;
alter table public.notification_role_preferences
  add constraint notification_role_preferences_bell_roles_check check (
    selected_bell_roles <@ array[
      'admin'::text,
      'foreman'::text,
      'hr'::text,
      'accountant'::text,
      'lawyer'::text,
      'procurement'::text,
      'estimator'::text
    ]
  );

-- An estimator is a company-wide specialist. Object membership still controls
-- foremen, while estimator access is restricted further by role permissions.
create or replace function public.current_user_has_object_scope(p_object_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1
    from public.objects object_row
    left join public.object_memberships membership
      on membership.company_id = object_row.company_id
     and membership.object_id = object_row.id
     and membership.user_id = (select auth.uid())
    left join public.user_profiles profile
      on profile.id = (select auth.uid())
    where object_row.id = p_object_id
      and object_row.company_id = public.current_user_company_id()
      and (
        public.is_admin()
        or public.current_user_role() = 'estimator'
        or membership.user_id is not null
        or lower(btrim(coalesce(profile.object_name, ''))) = lower(btrim(object_row.name))
      )
  );
$function$;

insert into public.role_permissions (role_code, permission_code)
values
  ('estimator', 'company_chat.files'),
  ('estimator', 'company_chat.send'),
  ('estimator', 'company_chat.view'),
  ('estimator', 'documents.templates.view'),
  ('estimator', 'notifications.center.view'),
  ('estimator', 'objects.view'),
  ('estimator', 'reports.view'),
  ('estimator', 'tasks.view')
on conflict (role_code, permission_code) do nothing;

create table if not exists public.task_completion_reports (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  reported_quantity numeric,
  unit text not null default '',
  work_location text not null default '',
  completion_comment text not null default '',
  review_status text not null default 'pending' check (
    review_status = any (array['pending'::text, 'approved'::text, 'returned'::text])
  ),
  approved_quantity numeric,
  review_comment text not null default '',
  submitted_by uuid not null references auth.users(id) on delete restrict,
  submitted_by_name text not null default '',
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_by_name text not null default '',
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint task_completion_reports_task_unique unique (task_id),
  constraint task_completion_reports_reported_quantity_positive check (
    reported_quantity is null or reported_quantity > 0
  ),
  constraint task_completion_reports_approved_quantity_positive check (
    approved_quantity is null or approved_quantity > 0
  )
);

create index if not exists task_completion_reports_status_idx
  on public.task_completion_reports (review_status, submitted_at desc);
create index if not exists task_completion_reports_submitted_by_idx
  on public.task_completion_reports (submitted_by, submitted_at desc);

alter table public.task_completion_reports enable row level security;

create policy task_completion_reports_select_allowed
on public.task_completion_reports
for select
to authenticated
using (
  public.task_is_allowed_for_user(task_id)
  and (
    submitted_by = (select auth.uid())
    or public.current_user_role() in ('admin', 'developer', 'estimator')
  )
);

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

create or replace function public.review_task_completion_report(
  p_report_id uuid,
  p_action text,
  p_approved_quantity numeric default null,
  p_comment text default ''
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_role text := public.current_user_role();
  v_user_name text := '';
  v_report public.task_completion_reports%rowtype;
  v_action text := lower(btrim(coalesce(p_action, '')));
  v_quantity numeric;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Проверять объёмы может только инженер-сметчик или руководитель';
  end if;

  select *
    into v_report
    from public.task_completion_reports report
   where report.id = p_report_id
   for update;
  if not found then
    raise exception 'Передача выполненной работы не найдена';
  end if;
  if not public.task_is_allowed_for_user(v_report.task_id) then
    raise exception 'Нет доступа к задаче';
  end if;
  if v_report.review_status <> 'pending' then
    raise exception 'Эта работа уже обработана';
  end if;

  select coalesce(profile.full_name, '')
    into v_user_name
    from public.user_profiles profile
   where profile.id = v_user_id;

  if v_action = 'returned' then
    if btrim(coalesce(p_comment, '')) = '' then
      raise exception 'Укажите причину возврата мастеру';
    end if;
    update public.task_completion_reports
       set review_status = 'returned',
           approved_quantity = null,
           review_comment = btrim(p_comment),
           reviewed_by = v_user_id,
           reviewed_by_name = v_user_name,
           reviewed_at = now(),
           updated_at = now()
     where id = p_report_id;
    return;
  end if;

  if v_action <> 'approved' then
    raise exception 'Недопустимое действие проверки';
  end if;

  v_quantity := coalesce(p_approved_quantity, v_report.reported_quantity);
  if v_quantity is not null and v_quantity <= 0 then
    raise exception 'Подтверждённый объём должен быть больше нуля';
  end if;

  update public.task_completion_reports
     set review_status = 'approved',
         approved_quantity = v_quantity,
         review_comment = btrim(coalesce(p_comment, '')),
         reviewed_by = v_user_id,
         reviewed_by_name = v_user_name,
         reviewed_at = now(),
         updated_at = now()
   where id = p_report_id;
end;
$function$;

grant execute on function public.submit_task_completion_report(uuid, numeric, text, text, text) to authenticated;
grant execute on function public.review_task_completion_report(uuid, text, numeric, text) to authenticated;
