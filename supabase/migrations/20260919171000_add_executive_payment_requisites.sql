-- Compact payment requisites for executive payout summaries.
-- Keep employee_private_data itself protected; expose only transfer fields
-- through a narrowly scoped read-only RPC.

alter table public.employee_private_data
  add column if not exists bank_transfer_phone text not null default '',
  add column if not exists bank_recipient_name text not null default '';

create or replace function public.get_executive_payment_requisites(
  p_employee_ids uuid[]
)
returns table (
  employee_id uuid,
  bank_transfer_phone text,
  bank_name text,
  bank_recipient_name text,
  bank_card text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
begin
  if auth.uid() is null or v_company_id is null then
    raise exception 'Требуется вход в аккаунт' using errcode = '42501';
  end if;

  if v_role not in ('admin', 'developer', 'accountant', 'executive') then
    raise exception 'Недостаточно прав для просмотра реквизитов выплат'
      using errcode = '42501';
  end if;

  if not public.document_tool_is_enabled(v_company_id) then
    raise exception 'Работа с личными данными недоступна'
      using errcode = '42501';
  end if;

  return query
  select
    private_row.employee_id,
    coalesce(private_row.bank_transfer_phone, ''),
    coalesce(private_row.bank_name, ''),
    coalesce(private_row.bank_recipient_name, ''),
    coalesce(private_row.bank_card, '')
  from public.employee_private_data private_row
  join public.employees employee_row
    on employee_row.id = private_row.employee_id
   and employee_row.company_id = v_company_id
  where private_row.company_id = v_company_id
    and private_row.employee_id = any(coalesce(p_employee_ids, array[]::uuid[]));
end;
$function$;

revoke all on function public.get_executive_payment_requisites(uuid[])
  from public, anon;
grant execute on function public.get_executive_payment_requisites(uuid[])
  to authenticated;
