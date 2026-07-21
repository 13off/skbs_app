create index if not exists document_templates_created_by_idx
  on public.document_templates (created_by)
  where created_by is not null;

create index if not exists document_templates_current_version_idx
  on public.document_templates (current_version_id)
  where current_version_id is not null;

create index if not exists document_template_versions_created_by_idx
  on public.document_template_versions (created_by)
  where created_by is not null;
