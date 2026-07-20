create or replace function private.manager_report_finance_v2(
  p_company_id uuid,
  p_object_id uuid,
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
    count(*) filter (
      where p.payment_date = p_report_date
    )::integer as day_count,
    count(*) filter (
      where p.payment_date = p_report_date
        and not exists (
          select 1
          from public.payment_receipts receipt
          where receipt.company_id = p.company_id
            and receipt.payment_id = p.id
        )
    )::integer as day_missing_receipts,
    count(*) filter (
      where not exists (
        select 1
        from public.payment_receipts receipt
        where receipt.company_id = p.company_id
          and receipt.payment_id = p.id
      )
    )::integer as month_missing_receipts
  from public.payments p
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (p_object_id is null or p.object_id = p_object_id)
), missing_month as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00'))
      || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(
      ' · ',
      nullif(btrim(coalesce(p.payment_type, '')), ''),
      nullif(btrim(coalesce(p.comment, '')), '')
    )
  ) order by p.payment_date desc, e.fio), '[]'::jsonb) as items
  from public.payments p
  join public.employees e
    on e.id = p.employee_id
   and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and (p_object_id is null or p.object_id = p_object_id)
    and not exists (
      select 1
      from public.payment_receipts receipt
      where receipt.company_id = p.company_id
        and receipt.payment_id = p.id
    )
), missing_day as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'title', coalesce(nullif(btrim(e.fio), ''), 'Сотрудник'),
    'subtitle', trim(to_char(p.amount, 'FM999999990D00'))
      || ' ₽ · ' || to_char(p.payment_date, 'DD.MM.YYYY'),
    'note', concat_ws(
      ' · ',
      nullif(btrim(coalesce(p.payment_type, '')), ''),
      nullif(btrim(coalesce(p.comment, '')), '')
    )
  ) order by p.payment_date desc, e.fio), '[]'::jsonb) as items
  from public.payments p
  join public.employees e
    on e.id = p.employee_id
   and e.company_id = p.company_id
  where p.company_id = p_company_id
    and p.period_year = extract(year from p_report_date)::integer
    and p.period_month = extract(month from p_report_date)::integer
    and p.payment_date = p_report_date
    and (p_object_id is null or p.object_id = p_object_id)
    and not exists (
      select 1
      from public.payment_receipts receipt
      where receipt.company_id = p.company_id
        and receipt.payment_id = p.id
    )
)
select jsonb_build_object(
  'metrics', jsonb_build_object(
    'month_count', payments.month_count,
    'month_amount', payments.month_amount,
    'day_count', payments.day_count,
    -- Старое поле сохраняется, но теперь честно обозначает открытый остаток
    -- за месяц, который показывает текущий интерфейс.
    'missing_receipts', payments.month_missing_receipts,
    'missing_receipts_day', payments.day_missing_receipts,
    'missing_receipts_month', payments.month_missing_receipts
  ),
  'missing_items', missing_month.items,
  'missing_items_day', missing_day.items
)
from payments, missing_month, missing_day;
$$;

revoke all on function private.manager_report_finance_v2(uuid,uuid,date)
  from public, anon, authenticated;

-- Сохраняем проверенную сборку центра как внутреннюю базовую функцию и
-- добавляем совместимый слой, который различает критичные и контрольные
-- вопросы, не меняя RPC-сигнатуру Flutter-клиентов.
alter function public.get_manager_reports_center(uuid,date)
  rename to get_manager_reports_center_base;

revoke all on function public.get_manager_reports_center_base(uuid,date)
  from public, anon, authenticated;

create or replace function public.get_manager_reports_center(
  p_object_id uuid default null,
  p_report_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
  v_critical integer := 0;
  v_attention integer := 0;
  v_issues integer := 0;
begin
  v_result := public.get_manager_reports_center_base(
    p_object_id,
    p_report_date
  );

  v_critical := coalesce(
    (v_result #>> '{metrics,critical_count}')::integer,
    0
  );
  v_attention := coalesce(
    (v_result #>> '{metrics,attention_count}')::integer,
    0
  );
  v_issues := v_critical + v_attention;

  v_result := jsonb_set(
    v_result,
    '{metrics,critical_only_count}',
    to_jsonb(v_critical),
    true
  );
  v_result := jsonb_set(
    v_result,
    '{metrics,issues_count}',
    to_jsonb(v_issues),
    true
  );
  -- Старые клиенты используют critical_count для заголовка
  -- «Требует внимания», поэтому получают полное число вопросов.
  v_result := jsonb_set(
    v_result,
    '{metrics,critical_count}',
    to_jsonb(v_issues),
    true
  );

  return v_result;
end;
$$;

revoke all on function public.get_manager_reports_center(uuid,date)
  from public, anon;
grant execute on function public.get_manager_reports_center(uuid,date)
  to authenticated;
