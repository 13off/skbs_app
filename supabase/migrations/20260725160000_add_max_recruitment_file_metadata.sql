alter table public.recruitment_documents
  add column if not exists transport text not null default 'telegram';

alter table public.recruitment_documents
  add column if not exists external_file_id text not null default '';

alter table public.recruitment_documents
  add column if not exists external_file_unique_id text not null default '';

alter table public.recruitment_documents
  alter column telegram_file_id set default '';

create unique index if not exists recruitment_documents_transport_external_file_uidx
  on public.recruitment_documents (transport, external_file_id)
  where btrim(external_file_id) <> '';

comment on column public.recruitment_documents.transport is
  'Канал, из которого получен документ кандидата: telegram, max или другой внешний источник.';

comment on column public.recruitment_documents.external_file_id is
  'Идентификатор вложения во внешнем канале для защиты от повторного сохранения.';

comment on column public.recruitment_documents.external_file_unique_id is
  'Составной уникальный идентификатор сообщения и вложения во внешнем канале.';
