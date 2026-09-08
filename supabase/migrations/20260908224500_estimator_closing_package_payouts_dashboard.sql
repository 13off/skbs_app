-- Estimator production operations: closing package, payout preparation and manager dashboard.
-- Client contract prices and KS forms are intentionally not generated here.

create table if not exists public.estimator_closing_package_entries (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  kind text not null check (kind in ('volume_register', 'supporting_document', 'client_template', 'other')),
  title text not null,
  document_number text not null default '',
  document_date date,
  note text not null default '',
  status text not null default 'attached' check (status in ('attached', 'verified', 'not_required')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  verified_by uuid references auth.users(id) on delete set null,
  verified_by_name text not null default '',
  verified_at timestamptz,
  voided_by uuid references auth.users(id) on delete set null,
  voided_by_name text not null default '',
  voided_at timestamptz,
  void_reason text not null default '',
  constraint estimator_closing_package_title_not_blank check (btrim(title) <> ''),
  constraint estimator_closing_package_void_consistency check (
    (voided_at is null and voided_by is null and void_reason = '') or
    (voided_at is not null and voided_by is not null and btrim(void_reason) <> '')
  )
);

create index if not exists estimator_closing_package_entries_closing_idx
  on public.estimator_closing_package_entries(closing_id, created_at)
  where voided_at is null;

create table if not exists public.estimator_closing_payout_lines (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete restrict,
  employee_name text not null default '',
  period_year integer not null,
  period_month integer not null,
  amount numeric not null check (amount >= 0),
  earning_rows integer not null default 0 check (earning_rows >= 0),
  blocker_count integer not null default 0 check (blocker_count >= 0),
  blocker_note text not null default '',
  status text not null default 'ready' check (status in ('blocked', 'ready', 'paid')),
  payment_id uuid references public.payments(id) on delete set null,
  linked_by uuid references auth.users(id) on delete set null,
  linked_by_name text not null default '',
  linked_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (closing_id, employee_id)
);

create index if not exists estimator_closing_payout_lines_company_status_idx
  on public.estimator_closing_payout_lines(company_id, status, period_year desc, period_month desc);

alter table public.estimator_closing_package_entries enable row level security;
alter table public.estimator_closing_payout_lines enable row level security;

drop policy if exists estimator_closing_package_entries_select_allowed on public.estimator_closing_package_entries;
create policy estimator_closing_package_entries_select_allowed
on public.estimator_closing_package_entries for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator', 'lawyer', 'accountant')
);

drop policy if exists estimator_closing_payout_lines_select_finance on public.estimator_closing_payout_lines;
create policy estimator_closing_payout_lines_select_finance
on public.estimator_closing_payout_lines for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

create or replace function public.add_estimator_closing_package_entry(
  p_closing_id uuid,
  p_kind text,
  p_title text,
  p_document_number text default '',
  p_document_date date default null,
  p_note text default ''
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_name text := '';
  v_status text;
  v_id uuid;
begin
  if v_user_id is null then raise exception 'Требуется вход в аккаунт'; end if;
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Добавлять документы закрытия может инженер-сметчик или руководитель';
  end if;
  if p_kind not in ('volume_register', 'supporting_document', 'client_template', 'other') then
    raise exception 'Недопустимый тип документа';
  end if;
  if btrim(coalesce(p_title, '')) = '' then raise exception 'Укажите название документа'; end if;

  select c.status into v_status
  from public.estimator_period_closings c
  where c.id = p_closing_id and c.company_id = v_company_id;
  if v_status is null then raise exception 'Закрытие не найдено'; end if;
  if v_status in ('sent_to_client', 'paid') then raise exception 'Пакет уже передан заказчику и заблокирован'; end if;

  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  insert into public.estimator_closing_package_entries(
    closing_id, company_id, kind, title, document_number, document_date, note,
    created_by, created_by_name
  ) values (
    p_closing_id, v_company_id, p_kind, btrim(p_title), btrim(coalesce(p_document_number, '')),
    p_document_date, btrim(coalesce(p_note, '')), v_user_id, v_name
  ) returning id into v_id;
  return v_id;
end;
$function$;

create or replace function public.verify_estimator_closing_package_entry(
  p_entry_id uuid,
  p_status text default 'verified'
)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_name text := '';
begin
  if v_role not in ('admin', 'developer', 'lawyer', 'accountant') then
    raise exception 'Проверять пакет может юрист, бухгалтер или руководитель';
  end if;
  if p_status not in ('verified', 'not_required') then raise exception 'Недопустимый статус проверки'; end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_closing_package_entries
  set status = p_status, verified_by = v_user_id, verified_by_name = v_name, verified_at = now()
  where id = p_entry_id and company_id = v_company_id and voided_at is null;
  if not found then raise exception 'Документ пакета не найден'; end if;
end;
$function$;

create or replace function public.void_estimator_closing_package_entry(
  p_entry_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_name text := '';
begin
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Аннулировать запись пакета может инженер-сметчик или руководитель';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then raise exception 'Укажите причину аннулирования'; end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_closing_package_entries
  set voided_by = v_user_id, voided_by_name = v_name, voided_at = now(), void_reason = btrim(p_reason)
  where id = p_entry_id and company_id = v_company_id and voided_at is null;
  if not found then raise exception 'Документ пакета не найден'; end if;
end;
$function$;

create or replace function public.refresh_estimator_closing_payout_lines(p_closing_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_closing public.estimator_period_closings%rowtype;
begin
  if v_role not in ('admin', 'developer', 'estimator', 'accountant') then
    raise exception 'Нет доступа к расчёту выработки';
  end if;
  select * into v_closing from public.estimator_period_closings
  where id = p_closing_id and company_id = v_company_id;
  if not found then raise exception 'Закрытие не найдено'; end if;

  delete from public.estimator_closing_payout_lines
  where closing_id = p_closing_id and payment_id is null;

  insert into public.estimator_closing_payout_lines(
    closing_id, company_id, object_id, employee_id, employee_name,
    period_year, period_month, amount, earning_rows, blocker_count, blocker_note, status
  )
  select
    v_closing.id, v_closing.company_id, v_closing.object_id, e.employee_id,
    max(e.employee_name), v_closing.period_year, v_closing.period_month,
    round(sum(e.amount), 2), count(*)::int, v_closing.earnings_issue_count,
    case when v_closing.earnings_issue_count > 0
      then concat('В закрытии есть нерешённые вопросы расчёта: ', v_closing.earnings_issue_count)
      else '' end,
    case when v_closing.earnings_issue_count > 0 then 'blocked' else 'ready' end
  from public.estimator_closing_earnings e
  where e.closing_id = v_closing.id
  group by e.employee_id
  on conflict (closing_id, employee_id) do update set
    employee_name = excluded.employee_name,
    amount = excluded.amount,
    earning_rows = excluded.earning_rows,
    blocker_count = excluded.blocker_count,
    blocker_note = excluded.blocker_note,
    status = case when public.estimator_closing_payout_lines.payment_id is not null then 'paid' else excluded.status end,
    updated_at = now();
end;
$function$;

create or replace function public.link_estimator_payout_payment(
  p_line_id uuid,
  p_payment_id uuid
)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_name text := '';
  v_line public.estimator_closing_payout_lines%rowtype;
  v_payment public.payments%rowtype;
begin
  if v_role not in ('admin', 'developer', 'accountant') then
    raise exception 'Связывать фактическую выплату может бухгалтер или руководитель';
  end if;
  select * into v_line from public.estimator_closing_payout_lines
  where id = p_line_id and company_id = v_company_id for update;
  if not found then raise exception 'Строка выплаты не найдена'; end if;
  if v_line.status = 'blocked' then raise exception 'Сначала устраните блокеры расчёта'; end if;

  select * into v_payment from public.payments
  where id = p_payment_id and company_id = v_company_id and deleted_at is null;
  if not found then raise exception 'Выплата не найдена'; end if;
  if v_payment.employee_id <> v_line.employee_id
     or v_payment.object_id <> v_line.object_id
     or v_payment.period_year <> v_line.period_year
     or v_payment.period_month <> v_line.period_month then
    raise exception 'Выплата не соответствует сотруднику, объекту или периоду закрытия';
  end if;

  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_closing_payout_lines
  set payment_id = p_payment_id, status = 'paid', linked_by = v_user_id,
      linked_by_name = v_name, linked_at = now(), updated_at = now()
  where id = p_line_id;
end;
$function$;

create or replace function public.unlink_estimator_payout_payment(p_line_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_closing_id uuid;
begin
  if v_role not in ('admin', 'developer', 'accountant') then
    raise exception 'Изменять связь выплаты может бухгалтер или руководитель';
  end if;
  select closing_id into v_closing_id from public.estimator_closing_payout_lines
  where id = p_line_id and company_id = v_company_id;
  if v_closing_id is null then raise exception 'Строка выплаты не найдена'; end if;
  update public.estimator_closing_payout_lines
  set payment_id = null, linked_by = null, linked_by_name = '', linked_at = null,
      status = 'ready', updated_at = now()
  where id = p_line_id;
  perform public.refresh_estimator_closing_payout_lines(v_closing_id);
end;
$function$;

create or replace function public.get_estimator_closing_dashboard(
  p_year integer,
  p_month integer,
  p_object_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_result jsonb;
begin
  if v_role not in ('admin', 'developer', 'accountant') then
    raise exception 'Сводка закрытий доступна руководителю и бухгалтеру';
  end if;
  if p_year not between 2024 and 2100 or p_month not between 1 and 12 then raise exception 'Некорректный период'; end if;

  with scoped as (
    select c.* from public.estimator_period_closings c
    where c.company_id = v_company_id
      and c.period_year = p_year and c.period_month = p_month
      and (p_object_id is null or c.object_id = p_object_id)
  ), status_counts as (
    select coalesce(jsonb_object_agg(status, cnt), '{}'::jsonb) as value
    from (select status, count(*)::int cnt from scoped group by status) s
  )
  select jsonb_build_object(
    'year', p_year,
    'month', p_month,
    'closings', (select count(*)::int from scoped),
    'items', coalesce((select sum(item_count)::int from scoped), 0),
    'manual_items', coalesce((select sum(manual_item_count)::int from scoped), 0),
    'earning_issues', coalesce((select sum(earnings_issue_count)::int from scoped), 0),
    'internal_earnings', coalesce((select sum(earnings_total) from scoped), 0),
    'in_review', (select count(*)::int from scoped where status in ('legal_review','accounting_review','manager_review')),
    'waiting_client', (select count(*)::int from scoped where status = 'ready_for_client'),
    'waiting_payment', (select count(*)::int from scoped where status = 'sent_to_client'),
    'paid', (select count(*)::int from scoped where status = 'paid'),
    'returned', (select count(*)::int from scoped where status = 'returned'),
    'status_counts', (select value from status_counts)
  ) into v_result;
  return v_result;
end;
$function$;

revoke all on public.estimator_closing_package_entries from anon;
revoke all on public.estimator_closing_payout_lines from anon;
revoke insert, update, delete on public.estimator_closing_package_entries from authenticated;
revoke insert, update, delete on public.estimator_closing_payout_lines from authenticated;
grant select on public.estimator_closing_package_entries to authenticated;
grant select on public.estimator_closing_payout_lines to authenticated;

grant execute on function public.add_estimator_closing_package_entry(uuid, text, text, text, date, text) to authenticated;
grant execute on function public.verify_estimator_closing_package_entry(uuid, text) to authenticated;
grant execute on function public.void_estimator_closing_package_entry(uuid, text) to authenticated;
grant execute on function public.refresh_estimator_closing_payout_lines(uuid) to authenticated;
grant execute on function public.link_estimator_payout_payment(uuid, uuid) to authenticated;
grant execute on function public.unlink_estimator_payout_payment(uuid) to authenticated;
grant execute on function public.get_estimator_closing_dashboard(integer, integer, uuid) to authenticated;
