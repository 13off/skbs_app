alter function public.normalize_notification_role(text)
  set search_path = public, pg_temp;

alter function public.task_policy_row_to_json(public.company_task_policies)
  set search_path = public, pg_temp;

create index if not exists company_task_policies_updated_by_idx
  on public.company_task_policies(updated_by)
  where updated_by is not null;

create index if not exists developer_settings_audit_changed_by_idx
  on public.developer_settings_audit(changed_by)
  where changed_by is not null;

create index if not exists developer_settings_audit_object_id_idx
  on public.developer_settings_audit(object_id)
  where object_id is not null;

drop index if exists public.objects_company_id_id_key;
