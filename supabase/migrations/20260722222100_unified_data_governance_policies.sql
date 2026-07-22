create or replace function public.soft_delete_governance_entity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.company_id <> public.current_user_company_id() then
    raise exception 'Запись другой компании недоступна';
  end if;

  if tg_table_name = 'attendance' then
    if not public.current_user_has_object_scope(old.object_id)
       or not public.current_user_has_object_permission(
         'attendance.delete',
         old.object_id
       ) then
      raise exception 'Нет права удалять запись табеля';
    end if;
    update public.attendance
       set deleted_at = now(),
           deleted_by = auth.uid(),
           delete_reason = coalesce(nullif(btrim(old.delete_reason), ''), 'Удалено пользователем'),
           restored_at = null,
           restored_by = null,
           updated_at = now()
     where id = old.id and company_id = old.company_id and deleted_at is null;
    return null;
  end if;

  if tg_table_name = 'payments' then
    if not public.current_user_has_object_permission(
      'accounting.payments.edit',
      old.object_id
    ) then
      raise exception 'Нет права удалять выплату';
    end if;
    update public.payments
       set deleted_at = now(),
           deleted_by = auth.uid(),
           delete_reason = coalesce(nullif(btrim(old.delete_reason), ''), 'Удалено пользователем'),
           restored_at = null,
           restored_by = null,
           updated_at = now()
     where id = old.id and company_id = old.company_id and deleted_at is null;
    return null;
  end if;

  if tg_table_name = 'project_milestones' then
    if not public.current_user_has_object_scope(old.object_id)
       or not public.current_user_has_object_permission(
         'goals.delete',
         old.object_id
       ) then
      raise exception 'Нет права удалять цель или этап';
    end if;
    update public.project_milestones
       set deleted_at = now(),
           deleted_by = auth.uid(),
           delete_reason = coalesce(nullif(btrim(old.delete_reason), ''), 'Удалено пользователем'),
           restored_at = null,
           restored_by = null,
           updated_at = now()
     where id = old.id and company_id = old.company_id and deleted_at is null;
    return null;
  end if;

  raise exception 'Мягкое удаление для таблицы % не поддерживается', tg_table_name;
end;
$$;

revoke all on function public.soft_delete_governance_entity()
  from public, anon, authenticated;

drop trigger if exists attendance_soft_delete on public.attendance;
create trigger attendance_soft_delete
before delete on public.attendance
for each row execute function public.soft_delete_governance_entity();

drop trigger if exists payments_soft_delete on public.payments;
create trigger payments_soft_delete
before delete on public.payments
for each row execute function public.soft_delete_governance_entity();

drop trigger if exists milestones_soft_delete on public.project_milestones;
create trigger milestones_soft_delete
before delete on public.project_milestones
for each row execute function public.soft_delete_governance_entity();

drop policy if exists attendance_select_company_access on public.attendance;
create policy attendance_select_company_access
on public.attendance for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and (
    (
      public.current_user_has_object_scope(object_id)
      and public.current_user_has_object_permission('attendance.view', object_id)
    )
    or public.current_user_has_permission('accounting.attendance.view')
  )
);

drop policy if exists attendance_update_company_object on public.attendance;
create policy attendance_update_company_object
on public.attendance for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.edit', object_id)
)
with check (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.edit', object_id)
);

drop policy if exists attendance_delete_company_admin on public.attendance;
create policy attendance_delete_company_admin
on public.attendance for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('attendance.delete', object_id)
);

drop policy if exists payments_select_company_access on public.payments;
create policy payments_select_company_access
on public.payments for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_permission(
    'accounting.payments.view',
    object_id
  )
);

drop policy if exists payments_update_company_access on public.payments;
create policy payments_update_company_access
on public.payments for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_permission(
    'accounting.payments.edit',
    object_id
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_permission(
    'accounting.payments.edit',
    object_id
  )
);

drop policy if exists payments_delete_company_access on public.payments;
create policy payments_delete_company_access
on public.payments for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_permission(
    'accounting.payments.edit',
    object_id
  )
);

drop policy if exists project_milestones_select_company_object
  on public.project_milestones;
create policy project_milestones_select_company_object
on public.project_milestones for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('goals.view', object_id)
);

drop policy if exists project_milestones_update_company_object
  on public.project_milestones;
create policy project_milestones_update_company_object
on public.project_milestones for update to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('goals.edit', object_id)
)
with check (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('goals.edit', object_id)
);

drop policy if exists project_milestones_delete_company_object
  on public.project_milestones;
create policy project_milestones_delete_company_object
on public.project_milestones for delete to authenticated
using (
  company_id = (select public.current_user_company_id())
  and deleted_at is null
  and public.current_user_has_object_scope(object_id)
  and public.current_user_has_object_permission('goals.delete', object_id)
);

drop policy if exists audit_log_select_company on public.audit_log;
create policy audit_log_select_company
on public.audit_log for select to authenticated
using (
  company_id = (select public.current_user_company_id())
  and (
    public.is_admin()
    or public.current_user_has_permission('system.audit.view')
    or (
      public.current_user_has_permission('legal.documents.view')
      and entity_type = any(array[
        'legal_documents',
        'legal_document_files',
        'legal_counterparties',
        'legal_matters',
        'weekly_reports'
      ])
    )
  )
);

drop policy if exists permission_catalog_deny_direct on public.permission_catalog;
create policy permission_catalog_deny_direct
on public.permission_catalog for all
to authenticated
using (false)
with check (false);

drop policy if exists company_role_permission_overrides_deny_direct on public.company_role_permission_overrides;
create policy company_role_permission_overrides_deny_direct
on public.company_role_permission_overrides for all
to authenticated
using (false)
with check (false);

drop policy if exists object_role_permission_overrides_deny_direct on public.object_role_permission_overrides;
create policy object_role_permission_overrides_deny_direct
on public.object_role_permission_overrides for all
to authenticated
using (false)
with check (false);

drop policy if exists role_permission_audit_deny_direct on public.role_permission_audit;
create policy role_permission_audit_deny_direct
on public.role_permission_audit for all
to authenticated
using (false)
with check (false);
