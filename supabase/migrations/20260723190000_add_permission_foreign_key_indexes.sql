create index if not exists company_role_permission_overrides_permission_code_idx
  on public.company_role_permission_overrides (permission_code);

create index if not exists company_role_permission_overrides_updated_by_idx
  on public.company_role_permission_overrides (updated_by)
  where updated_by is not null;

create index if not exists object_role_permission_overrides_object_id_idx
  on public.object_role_permission_overrides (object_id);

create index if not exists object_role_permission_overrides_permission_code_idx
  on public.object_role_permission_overrides (permission_code);

create index if not exists object_role_permission_overrides_updated_by_idx
  on public.object_role_permission_overrides (updated_by)
  where updated_by is not null;

create index if not exists role_permission_audit_object_id_idx
  on public.role_permission_audit (object_id)
  where object_id is not null;
