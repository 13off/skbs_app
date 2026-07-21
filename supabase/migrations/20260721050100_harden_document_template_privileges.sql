revoke delete, truncate, references, trigger
on table public.document_templates
from anon, authenticated;

revoke delete, truncate, references, trigger
on table public.document_template_versions
from anon, authenticated;

grant select, insert, update
on table public.document_templates
to authenticated;

grant select, insert, update
on table public.document_template_versions
to authenticated;
