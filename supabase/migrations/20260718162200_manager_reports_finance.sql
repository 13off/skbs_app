create or replace function private.manager_report_finance(
  p_company_id uuid,
  p_object_name text,
  p_report_date date
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
with payments as (
  select
    count(*)::integer as month_count,
    coalesce(sum(p.amount), 0) as month_amount,
    count(*) filter (where p.payment_date = p_report_date)::integer as day_count,
    count(*) filter (where not exists (
      select 1 from public.payment_receipts receipt
      where receipt.company_id = p.company_id and receipt.payment_id = p.id
    ))::integer as missing_receipts
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
), missing as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00')) || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(' · ', nullif(btrim(coalesce(p.payment_type, '')), ''), nullif(btrim(coalesce(p.comment, '')), ''))
  ) order by p.payment_date desc, e.fio), '[]'::jsonb) as items
  from public.payments p
  join public.employees e on e.id = p.employee_id and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (nullif(btrim(p_object_name), '') is null
      or lower(btrim(coalesce(e.object_name, ''))) = lower(btrim(p_object_name)))
    and not exists (
      select 1 from public.payment_receipts receipt
      where receipt.company_id = p.company_id and receipt.payment_id = p.id
    )
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'month_count', payments.month_count,
    'month_amount', payments.month_amount,
    'day_count', payments.day_count,
    'missing_receipts', payments.missing_receipts
  ),
  'missing_items', missing.items
)
from payments, missing;
$$;

revoke all on function private.manager_report_finance(uuid,text,date) from public, anon, authenticated;
