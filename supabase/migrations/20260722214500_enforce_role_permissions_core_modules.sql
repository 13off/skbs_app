create or replace function public.current_user_has_object_scope(p_object_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
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
        or membership.user_id is not null
        or lower(btrim(coalesce(profile.object_name, ''))) = lower(btrim(object_row.name))
      )
  );
$$;

create or replace function public.current_user_has_object_scope_by_name(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.objects object_row
    where object_row.company_id = public.current_user_company_id()
      and lower(btrim(object_row.name)) = lower(btrim(coalesce(p_object_name, '')))
      and public.current_user_has_object_scope(object_row.id)
  );
$$;

create or replace function public.task_temporal_access_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks task_row
    where task_row.id = p_task_id
      and task_row.company_id = public.current_user_company_id()
      and task_row.deleted_at is null
      and public.current_user_has_object_scope(task_row.object_id)
      and public.is_active_object(task_row.object_name)
      and (
        public.is_admin()
        or task_row.task_date = public.current_operational_date()
        or (
          task_row.task_date > public.current_operational_date()
          and public.task_policy_bool(task_row.object_name, 'foreman_can_create_any_date', false)
        )
        or (
          task_row.task_date < public.current_operational_date()
          and public.task_policy_bool(task_row.object_name, 'foreman_can_edit_past_tasks', false)
          and (
            (public.get_effective_task_policy(task_row.object_name) -> 'edit_window_days') = 'null'::jsonb
            or task_row.task_date >= public.current_operational_date() - public.task_policy_int(task_row.object_name, 'edit_window_days', 0)
          )
        )
      )
  );
$$;

create or replace function public.task_is_allowed_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks task_row
    where task_row.id = p_task_id
      and task_row.company_id = public.current_user_company_id()
      and task_row.deleted_at is null
      and public.current_user_has_object_scope(task_row.object_id)
      and public.current_user_has_object_permission('tasks.view', task_row.object_id)
      and public.is_active_object(task_row.object_name)
      and (
        not task_row.is_draft
        or public.is_admin()
        or task_row.created_by_user_id = (select auth.uid())
      )
  );
$$;

create or replace function public.task_can_create_for_user(p_task_date date, p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.objects object_row
    where object_row.company_id = public.current_user_company_id()
      and lower(btrim(object_row.name)) = lower(btrim(coalesce(p_object_name, '')))
      and object_row.is_active
      and public.current_user_has_object_scope(object_row.id)
      and public.current_user_has_object_permission('tasks.create', object_row.id)
      and (
        public.is_admin()
        or p_task_date = public.current_operational_date()
        or public.task_policy_bool(object_row.name, 'foreman_can_create_any_date', false)
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
  select public.task_temporal_access_for_user(p_task_id)
     and public.current_user_has_task_permission('tasks.edit', p_task_id);
$$;

create or replace function public.task_can_delete_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks task_row
    where task_row.id = p_task_id
      and not task_row.is_draft
      and public.task_temporal_access_for_user(task_row.id)
      and public.current_user_has_task_permission('tasks.delete', task_row.id)
      and (
        public.is_admin()
        or public.task_policy_bool(task_row.object_name, 'foreman_can_delete_task', false)
      )
  );
$$;

create or replace function public.task_can_edit_assignees_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks task_row
    where task_row.id = p_task_id
      and public.task_temporal_access_for_user(task_row.id)
      and public.current_user_has_task_permission('tasks.assignees.manage', task_row.id)
      and (
        public.is_admin()
        or public.task_policy_bool(task_row.object_name, 'foreman_can_edit_assignees', true)
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
  select public.task_temporal_access_for_user(p_task_id)
     and public.current_user_has_task_permission('tasks.photos.manage', p_task_id);
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
    join public.tasks task_row on task_row.id = photo.task_id
    where photo.id = p_photo_id
      and photo.company_id = public.current_user_company_id()
      and public.task_temporal_access_for_user(task_row.id)
      and public.current_user_has_task_permission('tasks.photos.manage', task_row.id)
      and (
        public.is_admin()
        or case photo.photo_stage
          when 'after' then public.task_policy_bool(task_row.object_name, 'foreman_can_delete_after_photos', true)
          else public.task_policy_bool(task_row.object_name, 'foreman_can_delete_before_photos', true)
        end
      )
  );
$$;

drop policy if exists tasks_select_company_object on public.tasks;
create policy tasks_select_company_object on public.tasks for select to authenticated
using (company_id = (select public.current_user_company_id()) and deleted_at is null and public.task_is_allowed_for_user(id));

drop policy if exists tasks_insert_company_object on public.tasks;
create policy tasks_insert_company_object on public.tasks for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and is_draft and created_by_user_id = (select auth.uid()) and public.task_can_create_for_user(task_date, object_name));

drop policy if exists tasks_update_company_object on public.tasks;
create policy tasks_update_company_object on public.tasks for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.task_can_edit_for_user(id))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('tasks.edit', object_id) and public.is_active_object(object_name));

drop policy if exists tasks_delete_company_admin on public.tasks;
create policy tasks_delete_company_admin on public.tasks for delete to authenticated
using (company_id = (select public.current_user_company_id()) and deleted_at is null and ((is_draft and (public.is_admin() or created_by_user_id = (select auth.uid()))) or (not is_draft and public.task_can_delete_for_user(id))));

drop policy if exists attendance_select_company_access on public.attendance;
create policy attendance_select_company_access on public.attendance for select to authenticated
using (company_id = (select public.current_user_company_id()) and ((public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('attendance.view', object_id)) or public.current_user_has_permission('accounting.attendance.view')));

drop policy if exists attendance_insert_company_object on public.attendance;
create policy attendance_insert_company_object on public.attendance for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('attendance.edit', object_id) and exists (select 1 from public.employees employee where employee.id = attendance.employee_id and employee.company_id = attendance.company_id and employee.object_id = attendance.object_id));

drop policy if exists attendance_update_company_object on public.attendance;
create policy attendance_update_company_object on public.attendance for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('attendance.edit', object_id))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('attendance.edit', object_id));

drop policy if exists attendance_delete_company_admin on public.attendance;
create policy attendance_delete_company_admin on public.attendance for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('attendance.delete', object_id));

create or replace function public.guard_employee_permission_update()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_archive_changed boolean;
  v_other_changed boolean;
begin
  v_archive_changed := old.is_active is distinct from new.is_active or old.archived_at is distinct from new.archived_at;
  v_other_changed := (to_jsonb(old) - 'updated_at' - 'is_active' - 'archived_at') is distinct from (to_jsonb(new) - 'updated_at' - 'is_active' - 'archived_at');
  if v_archive_changed and not public.current_user_has_object_permission('employees.archive', coalesce(new.object_id, old.object_id)) then
    raise exception 'Нет права архивировать или восстанавливать сотрудника';
  end if;
  if v_other_changed and not public.current_user_has_object_permission('employees.edit', coalesce(new.object_id, old.object_id)) then
    raise exception 'Нет права редактировать сотрудника';
  end if;
  return new;
end;
$$;

drop trigger if exists employees_permission_guard on public.employees;
create trigger employees_permission_guard before update on public.employees for each row execute function public.guard_employee_permission_update();

drop policy if exists employees_select_company_access on public.employees;
create policy employees_select_company_access on public.employees for select to authenticated
using (company_id = (select public.current_user_company_id()) and ((public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('employees.view', object_id)) or public.current_user_has_permission('accounting.directory.view')));

drop policy if exists employees_insert_company_admin on public.employees;
create policy employees_insert_company_admin on public.employees for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('employees.create', object_id) and exists (select 1 from public.objects object_row where object_row.id = employees.object_id and object_row.company_id = employees.company_id and object_row.is_active));

drop policy if exists employees_update_company_admin on public.employees;
create policy employees_update_company_admin on public.employees for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and (public.current_user_has_object_permission('employees.edit', object_id) or public.current_user_has_object_permission('employees.archive', object_id)))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and (public.current_user_has_object_permission('employees.edit', object_id) or public.current_user_has_object_permission('employees.archive', object_id)));

drop policy if exists employees_delete_company_admin on public.employees;
create policy employees_delete_company_admin on public.employees for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('employees.delete', object_id));

create or replace function public.guard_object_permission_update()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_archive_changed boolean;
  v_other_changed boolean;
begin
  v_archive_changed := old.is_active is distinct from new.is_active;
  v_other_changed := (to_jsonb(old) - 'updated_at' - 'is_active') is distinct from (to_jsonb(new) - 'updated_at' - 'is_active');
  if v_archive_changed and not public.current_user_has_object_permission('objects.archive', old.id) then
    raise exception 'Нет права архивировать или восстанавливать объект';
  end if;
  if v_other_changed and not public.current_user_has_object_permission('objects.edit', old.id) then
    raise exception 'Нет права редактировать объект';
  end if;
  return new;
end;
$$;

drop trigger if exists objects_permission_guard on public.objects;
create trigger objects_permission_guard before update on public.objects for each row execute function public.guard_object_permission_update();

drop policy if exists objects_select_company on public.objects;
create policy objects_select_company on public.objects for select to authenticated
using (company_id = (select public.current_user_company_id()) and (public.is_admin() or (is_active and public.current_user_has_object_scope(id) and public.current_user_has_object_permission('objects.view', id)) or public.current_user_has_permission('accounting.directory.view')));

drop policy if exists objects_insert_company_admin on public.objects;
create policy objects_insert_company_admin on public.objects for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('objects.create') and public.company_can_add_object(company_id));

drop policy if exists objects_update_company_admin on public.objects;
create policy objects_update_company_admin on public.objects for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(id) and (public.current_user_has_object_permission('objects.edit', id) or public.current_user_has_object_permission('objects.archive', id)))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(id) and (public.current_user_has_object_permission('objects.edit', id) or public.current_user_has_object_permission('objects.archive', id)));

drop policy if exists objects_delete_company_admin on public.objects;
create policy objects_delete_company_admin on public.objects for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(id) and public.current_user_has_object_permission('objects.delete', id));

drop policy if exists payments_select_company_access on public.payments;
create policy payments_select_company_access on public.payments for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_permission('accounting.payments.view', object_id));

drop policy if exists payments_insert_company_access on public.payments;
create policy payments_insert_company_access on public.payments for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_permission('accounting.payments.edit', object_id));

drop policy if exists payments_update_company_access on public.payments;
create policy payments_update_company_access on public.payments for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_permission('accounting.payments.edit', object_id))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_permission('accounting.payments.edit', object_id));

drop policy if exists payments_delete_company_access on public.payments;
create policy payments_delete_company_access on public.payments for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_permission('accounting.payments.edit', object_id));

drop policy if exists payment_receipts_select_company_access on public.payment_receipts;
create policy payment_receipts_select_company_access on public.payment_receipts for select to authenticated
using (company_id = (select public.current_user_company_id()) and exists (select 1 from public.payments payment_row where payment_row.id = payment_receipts.payment_id and payment_row.company_id = payment_receipts.company_id and public.current_user_has_object_permission('accounting.receipts.view', payment_row.object_id)));

drop policy if exists payment_receipts_insert_company_access on public.payment_receipts;
create policy payment_receipts_insert_company_access on public.payment_receipts for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and exists (select 1 from public.payments payment_row where payment_row.id = payment_receipts.payment_id and payment_row.company_id = payment_receipts.company_id and public.current_user_has_object_permission('accounting.receipts.edit', payment_row.object_id)));

drop policy if exists payment_receipts_delete_company_access on public.payment_receipts;
create policy payment_receipts_delete_company_access on public.payment_receipts for delete to authenticated
using (company_id = (select public.current_user_company_id()) and exists (select 1 from public.payments payment_row where payment_row.id = payment_receipts.payment_id and payment_row.company_id = payment_receipts.company_id and public.current_user_has_object_permission('accounting.receipts.edit', payment_row.object_id)));

insert into public.role_permissions(role_code, permission_code)
values ('foreman', 'documents.templates.view'), ('accountant', 'documents.templates.view'), ('lawyer', 'documents.templates.view')
on conflict do nothing;

drop policy if exists document_templates_select on public.document_templates;
create policy document_templates_select on public.document_templates for select to authenticated
using (company_id is null or (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.view')));

drop policy if exists document_templates_insert on public.document_templates;
create policy document_templates_insert on public.document_templates for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit'));

drop policy if exists document_templates_update on public.document_templates;
create policy document_templates_update on public.document_templates for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit'))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit'));

drop policy if exists document_template_versions_select on public.document_template_versions;
create policy document_template_versions_select on public.document_template_versions for select to authenticated
using (company_id is null or (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.view')));

drop policy if exists document_template_versions_insert on public.document_template_versions;
create policy document_template_versions_insert on public.document_template_versions for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit') and exists (select 1 from public.document_templates template where template.id = document_template_versions.template_id and template.company_id = document_template_versions.company_id));

drop policy if exists document_template_versions_update on public.document_template_versions;
create policy document_template_versions_update on public.document_template_versions for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit'))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_permission('documents.templates.edit'));

drop policy if exists project_milestones_select_company_object on public.project_milestones;
create policy project_milestones_select_company_object on public.project_milestones for select to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('goals.view', object_id));

drop policy if exists project_milestones_insert_company_object on public.project_milestones;
create policy project_milestones_insert_company_object on public.project_milestones for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('goals.edit', object_id));

drop policy if exists project_milestones_update_company_object on public.project_milestones;
create policy project_milestones_update_company_object on public.project_milestones for update to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('goals.edit', object_id))
with check (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('goals.edit', object_id));

drop policy if exists project_milestones_delete_company_object on public.project_milestones;
create policy project_milestones_delete_company_object on public.project_milestones for delete to authenticated
using (company_id = (select public.current_user_company_id()) and public.current_user_has_object_scope(object_id) and public.current_user_has_object_permission('goals.delete', object_id));

drop policy if exists milestone_checklist_select_company_object on public.milestone_checklist_items;
create policy milestone_checklist_select_company_object on public.milestone_checklist_items for select to authenticated
using (company_id = (select public.current_user_company_id()) and exists (select 1 from public.project_milestones milestone where milestone.id = milestone_checklist_items.milestone_id and milestone.company_id = milestone_checklist_items.company_id and public.current_user_has_object_scope(milestone.object_id) and public.current_user_has_object_permission('goals.view', milestone.object_id)));

drop policy if exists milestone_checklist_insert_company_object on public.milestone_checklist_items;
create policy milestone_checklist_insert_company_object on public.milestone_checklist_items for insert to authenticated
with check (company_id = (select public.current_user_company_id()) and exists (select 1 from public.project_milestones milestone where milestone.id = milestone_checklist_items.milestone_id and milestone.company_id = milestone_checklist_items.company_id and public.current_user_has_object_scope(milestone.object_id) and public.current_user_has_object_permission('goals.edit', milestone.object_id)));

drop policy if exists milestone_checklist_update_company_object on public.milestone_checklist_items;
create policy milestone_checklist_update_company_object on public.milestone_checklist_items for update to authenticated
using (company_id = (select public.current_user_company_id()) and exists (select 1 from public.project_milestones milestone where milestone.id = milestone_checklist_items.milestone_id and milestone.company_id = milestone_checklist_items.company_id and public.current_user_has_object_scope(milestone.object_id) and public.current_user_has_object_permission('goals.edit', milestone.object_id)))
with check (company_id = (select public.current_user_company_id()) and exists (select 1 from public.project_milestones milestone where milestone.id = milestone_checklist_items.milestone_id and milestone.company_id = milestone_checklist_items.company_id and public.current_user_has_object_scope(milestone.object_id) and public.current_user_has_object_permission('goals.edit', milestone.object_id)));

drop policy if exists milestone_checklist_delete_company_object on public.milestone_checklist_items;
create policy milestone_checklist_delete_company_object on public.milestone_checklist_items for delete to authenticated
using (company_id = (select public.current_user_company_id()) and exists (select 1 from public.project_milestones milestone where milestone.id = milestone_checklist_items.milestone_id and milestone.company_id = milestone_checklist_items.company_id and public.current_user_has_object_scope(milestone.object_id) and public.current_user_has_object_permission('goals.delete', milestone.object_id)));

revoke all on function public.current_user_has_object_scope(uuid) from public, anon;
revoke all on function public.current_user_has_object_scope_by_name(text) from public, anon;
revoke all on function public.task_temporal_access_for_user(uuid) from public, anon;
grant execute on function public.current_user_has_object_scope(uuid) to authenticated;
grant execute on function public.current_user_has_object_scope_by_name(text) to authenticated;
grant execute on function public.task_temporal_access_for_user(uuid) to authenticated;
