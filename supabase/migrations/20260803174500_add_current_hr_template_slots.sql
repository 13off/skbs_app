begin;

insert into public.document_templates (
  company_id,
  code,
  title,
  category,
  description,
  status
)
select
  null,
  source.code,
  source.title,
  'hr',
  source.description,
  'review'
from (
  values
    (
      'termination_application',
      'Заявление на увольнение',
      'Форма заявления на увольнение сотрудника.'
    ),
    (
      'ticket_purchase_agreement',
      'Соглашение на приобретение билетов',
      'Соглашение об условиях приобретения и возмещения стоимости билетов с подтверждением по СМС.'
    )
) as source(code, title, description)
where not exists (
  select 1
  from public.document_templates existing
  where existing.company_id is null
    and existing.code = source.code
);

commit;
