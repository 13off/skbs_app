create or replace function public.get_payment_rows_fast(
  p_employee_ids uuid[]
)
returns table (
  id uuid,
  employee_id uuid,
  period_year integer,
  period_month integer,
  payment_date date,
  amount numeric,
  payment_type text,
  comment text,
  updated_at timestamptz,
  receipts jsonb
)
language sql
stable
security invoker
set search_path = public, pg_temp
as $function$
  with visible_payments as materialized (
    select
      payment.id,
      payment.employee_id,
      payment.period_year,
      payment.period_month,
      payment.payment_date,
      payment.amount,
      payment.payment_type,
      payment.comment,
      payment.updated_at
    from public.payments payment
    where (select auth.uid()) is not null
      and cardinality(coalesce(p_employee_ids, '{}'::uuid[])) > 0
      and payment.company_id = (select public.current_user_company_id())
      and payment.deleted_at is null
      and payment.employee_id = any(p_employee_ids)
  ),
  grouped_receipts as materialized (
    select
      receipt.payment_id,
      jsonb_agg(
        jsonb_build_object(
          'id', receipt.id,
          'payment_id', receipt.payment_id,
          'employee_id', receipt.employee_id,
          'file_name', receipt.file_name,
          'file_path', receipt.file_path,
          'content_type', receipt.content_type,
          'created_at', receipt.created_at
        )
        order by receipt.created_at desc
      ) as receipts
    from public.payment_receipts receipt
    join visible_payments payment on payment.id = receipt.payment_id
    group by receipt.payment_id
  )
  select
    payment.id,
    payment.employee_id,
    payment.period_year,
    payment.period_month,
    payment.payment_date,
    payment.amount,
    payment.payment_type,
    payment.comment,
    payment.updated_at,
    coalesce(receipts.receipts, '[]'::jsonb) as receipts
  from visible_payments payment
  left join grouped_receipts receipts on receipts.payment_id = payment.id
  order by payment.payment_date desc, payment.updated_at desc;
$function$;

comment on function public.get_payment_rows_fast(uuid[]) is
  'Возвращает доступные выплаты и их чеки одним RLS-защищённым запросом.';

revoke all on function public.get_payment_rows_fast(uuid[])
  from public, anon;
grant execute on function public.get_payment_rows_fast(uuid[])
  to authenticated;
