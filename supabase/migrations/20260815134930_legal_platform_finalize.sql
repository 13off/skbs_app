-- Завершение юридической платформы: реальные реквизиты судебных дел и претензий.
-- Поля хранятся в legal_matters, чтобы не создавать второй параллельный реестр дел.

alter table public.legal_matters
  add column if not exists court_case_number text not null default '',
  add column if not exists court_name text not null default '',
  add column if not exists court_parties text not null default '',
  add column if not exists claim_amount numeric(18,2),
  add column if not exists proceeding_stage text not null default '',
  add column if not exists next_hearing_at timestamptz,
  add column if not exists outgoing_sent_at timestamptz,
  add column if not exists response_due_at timestamptz;

create index if not exists legal_matters_next_hearing_idx
  on public.legal_matters (company_id, next_hearing_at)
  where next_hearing_at is not null;

create index if not exists legal_matters_response_due_idx
  on public.legal_matters (company_id, response_due_at)
  where response_due_at is not null;

create index if not exists legal_matters_type_status_idx
  on public.legal_matters (company_id, matter_type, status);

comment on column public.legal_matters.court_case_number is 'Номер судебного дела';
comment on column public.legal_matters.court_name is 'Наименование суда';
comment on column public.legal_matters.court_parties is 'Стороны судебного спора';
comment on column public.legal_matters.claim_amount is 'Сумма требований по спору/претензии';
comment on column public.legal_matters.proceeding_stage is 'Текущая стадия судебного/претензионного процесса';
comment on column public.legal_matters.next_hearing_at is 'Дата и время ближайшего судебного заседания';
comment on column public.legal_matters.outgoing_sent_at is 'Дата отправки претензии/исходящего документа';
comment on column public.legal_matters.response_due_at is 'Крайний срок ответа/процессуального действия';
