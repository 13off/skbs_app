-- Engineer-estimator V2: real role support, period closing and explicit internal rates.

create or replace function public.normalize_estimator_unit(p_unit text)
returns text
language sql
immutable
set search_path to 'public', 'pg_temp'
as $function$
  select case lower(replace(replace(btrim(coalesce(p_unit, '')), ' ', ''), '.', ''))
    when 'м3' then 'м³'
    when 'м^3' then 'м³'
    when 'm3' then 'м³'
    when 'м²' then 'м²'
    when 'м2' then 'м²'
    when 'м^2' then 'м²'
    when 'm2' then 'м²'
    when 'мп' then 'м.п.'
    when 'мпог' then 'м.п.'
    when 'мпогонный' then 'м.п.'
    when 'мпогонных' then 'м.п.'
    when 'кг' then 'кг'
    when 'т' then 'т'
    when 'шт' then 'шт.'
    when 'шт' then 'шт.'
    when 'компл' then 'компл.'
    when 'комплект' then 'компл.'
    else btrim(coalesce(p_unit, ''))
  end;
$function$;

create table if not exists public.estimator_period_closings (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  object_name text not null,
  period_year integer not null check (period_year between 2024 and 2100),
  period_month integer not null check (period_month between 1 and 12),
  status text not null default 'draft' check (
    status = any (array[
      'draft'::text,
      'legal_review'::text,
      'accounting_review'::text,
      'manager_review'::text,
      'ready_for_client'::text,
      'sent_to_client'::text,
      'paid'::text,
      'returned'::text
    ])
  ),
  submission_round integer not null default 0 check (submission_round >= 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_by_name text not null default '',
  submitted_at timestamptz,
  legal_approved_by uuid references auth.users(id) on delete set null,
  legal_approved_by_name text not null default '',
  legal_approved_at timestamptz,
  accounting_approved_by uuid references auth.users(id) on delete set null,
  accounting_approved_by_name text not null default '',
  accounting_approved_at timestamptz,
  manager_approved_by uuid references auth.users(id) on delete set null,
  manager_approved_by_name text not null default '',
  manager_approved_at timestamptz,
  returned_by uuid references auth.users(id) on delete set null,
  returned_by_name text not null default '',
  returned_by_role text not null default '',
  return_comment text not null default '',
  returned_at timestamptz,
  sent_to_client_by uuid references auth.users(id) on delete set null,
  sent_to_client_by_name text not null default '',
  sent_to_client_at timestamptz,
  paid_by uuid references auth.users(id) on delete set null,
  paid_by_name text not null default '',
  paid_at timestamptz,
  item_count integer not null default 0 check (item_count >= 0),
  task_item_count integer not null default 0 check (task_item_count >= 0),
  manual_item_count integer not null default 0 check (manual_item_count >= 0),
  earnings_total numeric not null default 0 check (earnings_total >= 0),
  earnings_count integer not null default 0 check (earnings_count >= 0),
  earnings_issue_count integer not null default 0 check (earnings_issue_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (company_id, object_id, period_year, period_month),
  constraint estimator_period_closings_object_name_not_blank check (btrim(object_name) <> '')
);

create table if not exists public.estimator_period_closing_items (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  source_type text not null check (source_type in ('task_report', 'manual')),
  source_id uuid not null,
  task_id uuid references public.tasks(id) on delete set null,
  work text not null,
  unit text not null,
  quantity numeric not null check (quantity > 0),
  work_date date not null,
  work_location text not null default '',
  source_author_name text not null default '',
  source_comment text not null default '',
  created_at timestamptz not null default now(),
  unique (closing_id, source_type, source_id),
  constraint estimator_period_closing_items_work_not_blank check (btrim(work) <> ''),
  constraint estimator_period_closing_items_unit_not_blank check (btrim(unit) <> '')
);

create table if not exists public.estimator_period_closing_reviews (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  submission_round integer not null check (submission_round > 0),
  stage text not null check (stage in ('legal', 'accounting', 'manager')),
  decision text not null check (decision in ('approved', 'returned')),
  comment text not null default '',
  reviewed_by uuid not null references auth.users(id) on delete restrict,
  reviewed_by_name text not null default '',
  reviewed_by_role text not null,
  reviewed_at timestamptz not null default now()
);

create table if not exists public.estimator_piece_rates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete cascade,
  work text not null,
  work_key text not null,
  unit text not null,
  unit_key text not null,
  rate_amount numeric not null check (rate_amount > 0),
  valid_from date not null,
  valid_to date,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_by_name text not null default '',
  updated_at timestamptz not null default now(),
  constraint estimator_piece_rates_work_not_blank check (btrim(work) <> ''),
  constraint estimator_piece_rates_unit_not_blank check (btrim(unit) <> ''),
  constraint estimator_piece_rates_dates_valid check (valid_to is null or valid_to >= valid_from)
);

create unique index if not exists estimator_piece_rates_active_key_idx
  on public.estimator_piece_rates (company_id, object_id, work_key, unit_key)
  where is_active;

create table if not exists public.estimator_closing_earnings (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  closing_item_id uuid not null references public.estimator_period_closing_items(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete restrict,
  task_id uuid not null references public.tasks(id) on delete restrict,
  employee_id uuid not null references public.employees(id) on delete restrict,
  employee_name text not null default '',
  work text not null,
  unit text not null,
  approved_quantity numeric not null check (approved_quantity > 0),
  contribution_percent integer not null check (contribution_percent between 1 and 100),
  allocated_quantity numeric not null check (allocated_quantity > 0),
  rate_id uuid not null references public.estimator_piece_rates(id) on delete restrict,
  rate_amount numeric not null check (rate_amount > 0),
  amount numeric not null check (amount >= 0),
  created_at timestamptz not null default now(),
  unique (closing_item_id, employee_id)
);

create table if not exists public.estimator_closing_earning_issues (
  id uuid primary key default gen_random_uuid(),
  closing_id uuid not null references public.estimator_period_closings(id) on delete cascade,
  closing_item_id uuid not null references public.estimator_period_closing_items(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  issue_code text not null check (issue_code in ('missing_rate', 'missing_contributions', 'manual_requires_allocation')),
  message text not null,
  created_at timestamptz not null default now(),
  unique (closing_item_id, issue_code)
);

create index if not exists estimator_period_closings_company_status_idx
  on public.estimator_period_closings (company_id, status, period_year desc, period_month desc);
create index if not exists estimator_period_closing_items_closing_idx
  on public.estimator_period_closing_items (closing_id, work_date, work);
create index if not exists estimator_period_closing_reviews_closing_idx
  on public.estimator_period_closing_reviews (closing_id, submission_round, reviewed_at);
create index if not exists estimator_closing_earnings_closing_idx
  on public.estimator_closing_earnings (closing_id, employee_id);
create index if not exists estimator_closing_earning_issues_closing_idx
  on public.estimator_closing_earning_issues (closing_id);

alter table public.estimator_period_closings enable row level security;
alter table public.estimator_period_closing_items enable row level security;
alter table public.estimator_period_closing_reviews enable row level security;
alter table public.estimator_piece_rates enable row level security;
alter table public.estimator_closing_earnings enable row level security;
alter table public.estimator_closing_earning_issues enable row level security;

drop policy if exists estimator_period_closings_select_allowed on public.estimator_period_closings;
create policy estimator_period_closings_select_allowed
on public.estimator_period_closings for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator', 'lawyer', 'accountant')
);

drop policy if exists estimator_period_closing_items_select_allowed on public.estimator_period_closing_items;
create policy estimator_period_closing_items_select_allowed
on public.estimator_period_closing_items for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator', 'lawyer', 'accountant')
);

drop policy if exists estimator_period_closing_reviews_select_allowed on public.estimator_period_closing_reviews;
create policy estimator_period_closing_reviews_select_allowed
on public.estimator_period_closing_reviews for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator', 'lawyer', 'accountant')
);

drop policy if exists estimator_piece_rates_select_finance on public.estimator_piece_rates;
create policy estimator_piece_rates_select_finance
on public.estimator_piece_rates for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists estimator_closing_earnings_select_finance on public.estimator_closing_earnings;
create policy estimator_closing_earnings_select_finance
on public.estimator_closing_earnings for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'accountant')
);

drop policy if exists estimator_closing_earning_issues_select_allowed on public.estimator_closing_earning_issues;
create policy estimator_closing_earning_issues_select_allowed
on public.estimator_closing_earning_issues for select to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator', 'accountant')
);

create or replace function public.create_or_refresh_estimator_period_closing(
  p_object_id uuid,
  p_period_year integer,
  p_period_month integer
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
  v_user_name text := '';
  v_object_name text := '';
  v_closing_id uuid;
  v_status text;
  v_start date;
  v_end date;
  v_item record;
  v_rate record;
  v_contribution record;
  v_has_contributions boolean;
begin
  if v_user_id is null then raise exception 'Требуется вход в аккаунт'; end if;
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Формировать закрытие может только инженер-сметчик или руководитель';
  end if;
  if p_period_year not between 2024 and 2100 or p_period_month not between 1 and 12 then
    raise exception 'Некорректный период';
  end if;

  select o.name into v_object_name
  from public.objects o
  where o.id = p_object_id
    and o.company_id = v_company_id
    and o.is_active = true;
  if coalesce(v_object_name, '') = '' then raise exception 'Объект не найден'; end if;

  select coalesce(up.full_name, '') into v_user_name
  from public.user_profiles up where up.id = v_user_id;

  v_start := make_date(p_period_year, p_period_month, 1);
  v_end := (v_start + interval '1 month')::date;

  select c.id, c.status into v_closing_id, v_status
  from public.estimator_period_closings c
  where c.company_id = v_company_id
    and c.object_id = p_object_id
    and c.period_year = p_period_year
    and c.period_month = p_period_month
  for update;

  if v_closing_id is null then
    insert into public.estimator_period_closings (
      company_id, object_id, object_name, period_year, period_month,
      created_by, created_by_name
    ) values (
      v_company_id, p_object_id, v_object_name, p_period_year, p_period_month,
      v_user_id, v_user_name
    ) returning id into v_closing_id;
  elsif v_status not in ('draft', 'returned') then
    raise exception 'Период уже передан по цепочке проверки и не может быть пересобран';
  end if;

  delete from public.estimator_closing_earnings where closing_id = v_closing_id;
  delete from public.estimator_closing_earning_issues where closing_id = v_closing_id;
  delete from public.estimator_period_closing_items where closing_id = v_closing_id;

  insert into public.estimator_period_closing_items (
    closing_id, company_id, object_id, source_type, source_id, task_id,
    work, unit, quantity, work_date, work_location, source_author_name, source_comment
  )
  select
    v_closing_id,
    v_company_id,
    p_object_id,
    'task_report',
    r.id,
    t.id,
    btrim(t.work),
    public.normalize_estimator_unit(r.unit),
    r.approved_quantity,
    t.task_date,
    btrim(coalesce(r.work_location, '')),
    btrim(coalesce(r.submitted_by_name, '')),
    btrim(coalesce(r.review_comment, ''))
  from public.task_completion_reports r
  join public.tasks t on t.id = r.task_id
  where t.company_id = v_company_id
    and t.object_id = p_object_id
    and t.deleted_at is null
    and r.review_status = 'approved'
    and r.approved_quantity is not null
    and r.approved_quantity > 0
    and btrim(coalesce(r.unit, '')) <> ''
    and t.task_date >= v_start
    and t.task_date < v_end;

  insert into public.estimator_period_closing_items (
    closing_id, company_id, object_id, source_type, source_id, task_id,
    work, unit, quantity, work_date, work_location, source_author_name, source_comment
  )
  select
    v_closing_id,
    v_company_id,
    p_object_id,
    'manual',
    m.id,
    null,
    btrim(m.work),
    public.normalize_estimator_unit(m.unit),
    m.quantity,
    m.work_date,
    'Вручную',
    btrim(coalesce(m.created_by_name, '')),
    concat(btrim(m.reason_code), ': ', btrim(m.reason_comment))
  from public.estimator_manual_volumes m
  where m.company_id = v_company_id
    and lower(btrim(m.object_name)) = lower(btrim(v_object_name))
    and m.voided_at is null
    and m.work_date >= v_start
    and m.work_date < v_end;

  for v_item in
    select i.* from public.estimator_period_closing_items i
    where i.closing_id = v_closing_id
  loop
    if v_item.source_type = 'manual' then
      insert into public.estimator_closing_earning_issues (
        closing_id, closing_item_id, company_id, issue_code, message
      ) values (
        v_closing_id, v_item.id, v_company_id, 'manual_requires_allocation',
        'Ручной объём не связан с задачей и сотрудниками. Распределение заработка выполняется бухгалтером вручную.'
      ) on conflict do nothing;
      continue;
    end if;

    select r.* into v_rate
    from public.estimator_piece_rates r
    where r.company_id = v_company_id
      and r.object_id = p_object_id
      and r.is_active = true
      and r.work_key = lower(btrim(v_item.work))
      and r.unit_key = lower(public.normalize_estimator_unit(v_item.unit))
      and r.valid_from <= v_item.work_date
      and (r.valid_to is null or r.valid_to >= v_item.work_date)
    order by r.valid_from desc, r.created_at desc
    limit 1;

    if not found then
      insert into public.estimator_closing_earning_issues (
        closing_id, closing_item_id, company_id, issue_code, message
      ) values (
        v_closing_id, v_item.id, v_company_id, 'missing_rate',
        concat('Не настроена внутренняя расценка: ', v_item.work, ' · ', v_item.unit)
      ) on conflict do nothing;
    end if;

    v_has_contributions := false;
    for v_contribution in
      select c.employee_id, c.contribution_percent, e.fio
      from public.task_employee_contributions c
      join public.employees e on e.id = c.employee_id
      where c.company_id = v_company_id
        and c.task_id = v_item.task_id
        and c.contribution_percent > 0
    loop
      v_has_contributions := true;
      if v_rate.id is not null then
        insert into public.estimator_closing_earnings (
          closing_id, closing_item_id, company_id, object_id, task_id,
          employee_id, employee_name, work, unit, approved_quantity,
          contribution_percent, allocated_quantity, rate_id, rate_amount, amount
        ) values (
          v_closing_id, v_item.id, v_company_id, p_object_id, v_item.task_id,
          v_contribution.employee_id, coalesce(v_contribution.fio, ''),
          v_item.work, v_item.unit, v_item.quantity,
          v_contribution.contribution_percent,
          v_item.quantity * v_contribution.contribution_percent / 100.0,
          v_rate.id, v_rate.rate_amount,
          round(v_item.quantity * v_contribution.contribution_percent / 100.0 * v_rate.rate_amount, 2)
        ) on conflict (closing_item_id, employee_id) do update set
          contribution_percent = excluded.contribution_percent,
          allocated_quantity = excluded.allocated_quantity,
          rate_id = excluded.rate_id,
          rate_amount = excluded.rate_amount,
          amount = excluded.amount;
      end if;
    end loop;

    if not v_has_contributions then
      insert into public.estimator_closing_earning_issues (
        closing_id, closing_item_id, company_id, issue_code, message
      ) values (
        v_closing_id, v_item.id, v_company_id, 'missing_contributions',
        concat('По задаче «', v_item.work, '» не распределён вклад сотрудников.')
      ) on conflict do nothing;
    end if;
  end loop;

  update public.estimator_period_closings c
  set object_name = v_object_name,
      status = 'draft',
      submitted_at = null,
      legal_approved_by = null,
      legal_approved_by_name = '',
      legal_approved_at = null,
      accounting_approved_by = null,
      accounting_approved_by_name = '',
      accounting_approved_at = null,
      manager_approved_by = null,
      manager_approved_by_name = '',
      manager_approved_at = null,
      returned_by = null,
      returned_by_name = '',
      returned_by_role = '',
      return_comment = '',
      returned_at = null,
      item_count = (select count(*) from public.estimator_period_closing_items i where i.closing_id = v_closing_id),
      task_item_count = (select count(*) from public.estimator_period_closing_items i where i.closing_id = v_closing_id and i.source_type = 'task_report'),
      manual_item_count = (select count(*) from public.estimator_period_closing_items i where i.closing_id = v_closing_id and i.source_type = 'manual'),
      earnings_total = coalesce((select sum(e.amount) from public.estimator_closing_earnings e where e.closing_id = v_closing_id), 0),
      earnings_count = (select count(*) from public.estimator_closing_earnings e where e.closing_id = v_closing_id),
      earnings_issue_count = (select count(*) from public.estimator_closing_earning_issues e where e.closing_id = v_closing_id),
      updated_at = now()
  where c.id = v_closing_id;

  return v_closing_id;
end;
$function$;

create or replace function public.submit_estimator_period_closing(p_closing_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_user_name text := '';
  v_row public.estimator_period_closings%rowtype;
  v_source_role text;
begin
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Передавать закрытие может только инженер-сметчик или руководитель';
  end if;
  select * into v_row from public.estimator_period_closings
  where id = p_closing_id and company_id = v_company_id for update;
  if not found then raise exception 'Закрытие не найдено'; end if;
  if v_row.status not in ('draft', 'returned') then raise exception 'Закрытие уже передано'; end if;
  if v_row.item_count <= 0 then raise exception 'В периоде нет подтверждённых объёмов'; end if;
  select coalesce(full_name, '') into v_user_name from public.user_profiles where id = v_user_id;
  update public.estimator_period_closings
  set status = 'legal_review', submission_round = submission_round + 1,
      submitted_at = now(), returned_by = null, returned_by_name = '',
      returned_by_role = '', return_comment = '', returned_at = null, updated_at = now()
  where id = p_closing_id;
  v_source_role := case when v_role = 'developer' then 'admin' else v_role end;
  insert into public.app_notifications (
    title, body, actor_user_id, actor_name, object_name, entity_type, entity_id,
    company_id, target_role, requires_action, priority, source_role
  ) values (
    'Закрытие периода: проверка документов',
    concat(v_row.object_name, ' · ', lpad(v_row.period_month::text, 2, '0'), '.', v_row.period_year),
    v_user_id, v_user_name, v_row.object_name, 'estimator_period_closing', p_closing_id::text,
    v_company_id, 'lawyer', true, 'high', v_source_role
  );
end;
$function$;

create or replace function public.review_estimator_period_closing(
  p_closing_id uuid,
  p_decision text,
  p_comment text default ''
)
returns text
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_user_name text := '';
  v_row public.estimator_period_closings%rowtype;
  v_stage text;
  v_next_status text;
  v_next_role text;
  v_source_role text;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
begin
  if v_decision not in ('approved', 'returned') then raise exception 'Недопустимое решение'; end if;
  if v_decision = 'returned' and btrim(coalesce(p_comment, '')) = '' then
    raise exception 'Для возврата обязателен комментарий';
  end if;
  select * into v_row from public.estimator_period_closings
  where id = p_closing_id and company_id = v_company_id for update;
  if not found then raise exception 'Закрытие не найдено'; end if;

  if v_row.status = 'legal_review' then
    if v_role not in ('lawyer', 'admin', 'developer') then raise exception 'Ожидается проверка юриста'; end if;
    v_stage := 'legal'; v_next_status := 'accounting_review'; v_next_role := 'accountant';
  elsif v_row.status = 'accounting_review' then
    if v_role not in ('accountant', 'admin', 'developer') then raise exception 'Ожидается проверка бухгалтера'; end if;
    v_stage := 'accounting'; v_next_status := 'manager_review'; v_next_role := 'admin';
  elsif v_row.status = 'manager_review' then
    if v_role not in ('admin', 'developer') then raise exception 'Ожидается решение руководителя'; end if;
    v_stage := 'manager'; v_next_status := 'ready_for_client'; v_next_role := 'estimator';
  else
    raise exception 'Закрытие сейчас не ожидает проверки';
  end if;

  select coalesce(full_name, '') into v_user_name from public.user_profiles where id = v_user_id;
  insert into public.estimator_period_closing_reviews (
    closing_id, company_id, submission_round, stage, decision, comment,
    reviewed_by, reviewed_by_name, reviewed_by_role
  ) values (
    p_closing_id, v_company_id, v_row.submission_round, v_stage, v_decision,
    btrim(coalesce(p_comment, '')), v_user_id, v_user_name, v_role
  );

  if v_decision = 'returned' then
    update public.estimator_period_closings
    set status = 'returned', returned_by = v_user_id, returned_by_name = v_user_name,
        returned_by_role = v_role, return_comment = btrim(p_comment), returned_at = now(), updated_at = now()
    where id = p_closing_id;
    v_next_role := 'estimator';
  else
    update public.estimator_period_closings set status = v_next_status, updated_at = now() where id = p_closing_id;
    if v_stage = 'legal' then
      update public.estimator_period_closings set legal_approved_by = v_user_id, legal_approved_by_name = v_user_name, legal_approved_at = now() where id = p_closing_id;
    elsif v_stage = 'accounting' then
      update public.estimator_period_closings set accounting_approved_by = v_user_id, accounting_approved_by_name = v_user_name, accounting_approved_at = now() where id = p_closing_id;
    else
      update public.estimator_period_closings set manager_approved_by = v_user_id, manager_approved_by_name = v_user_name, manager_approved_at = now() where id = p_closing_id;
    end if;
  end if;

  v_source_role := case when v_role = 'developer' then 'admin' else v_role end;
  insert into public.app_notifications (
    title, body, actor_user_id, actor_name, object_name, entity_type, entity_id,
    company_id, target_role, requires_action, priority, source_role
  ) values (
    case when v_decision = 'returned' then 'Закрытие периода возвращено' else 'Закрытие периода: следующий этап' end,
    concat(v_row.object_name, ' · ', lpad(v_row.period_month::text, 2, '0'), '.', v_row.period_year,
      case when btrim(coalesce(p_comment, '')) = '' then '' else concat(' · ', btrim(p_comment)) end),
    v_user_id, v_user_name, v_row.object_name, 'estimator_period_closing', p_closing_id::text,
    v_company_id, v_next_role, true, 'high', v_source_role
  );

  return case when v_decision = 'returned' then 'returned' else v_next_status end;
end;
$function$;

create or replace function public.mark_estimator_period_closing_sent(p_closing_id uuid)
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
  if v_role not in ('admin', 'developer') then raise exception 'Отметить отправку заказчику может только руководитель'; end if;
  if not exists (select 1 from public.estimator_period_closings where id = p_closing_id and company_id = v_company_id and status = 'ready_for_client') then
    raise exception 'Закрытие ещё не готово к отправке заказчику';
  end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_period_closings
  set status = 'sent_to_client', sent_to_client_by = v_user_id,
      sent_to_client_by_name = v_name, sent_to_client_at = now(), updated_at = now()
  where id = p_closing_id;
end;
$function$;

create or replace function public.mark_estimator_period_closing_paid(p_closing_id uuid)
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
  if v_role not in ('admin', 'developer', 'accountant') then raise exception 'Подтвердить оплату может бухгалтер или руководитель'; end if;
  if not exists (select 1 from public.estimator_period_closings where id = p_closing_id and company_id = v_company_id and status = 'sent_to_client') then
    raise exception 'Сначала отметьте передачу закрытия заказчику';
  end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_period_closings
  set status = 'paid', paid_by = v_user_id, paid_by_name = v_name,
      paid_at = now(), updated_at = now()
  where id = p_closing_id;
end;
$function$;

create or replace function public.upsert_estimator_piece_rate(
  p_object_id uuid,
  p_work text,
  p_unit text,
  p_rate_amount numeric,
  p_valid_from date,
  p_valid_to date default null
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
  v_work text := btrim(coalesce(p_work, ''));
  v_unit text := public.normalize_estimator_unit(p_unit);
  v_id uuid;
begin
  if v_role not in ('admin', 'developer', 'accountant') then raise exception 'Внутренние расценки настраивает бухгалтер или руководитель'; end if;
  if v_work = '' or v_unit = '' then raise exception 'Укажите работу и единицу измерения'; end if;
  if p_rate_amount is null or p_rate_amount <= 0 then raise exception 'Расценка должна быть больше нуля'; end if;
  if p_valid_from is null or (p_valid_to is not null and p_valid_to < p_valid_from) then raise exception 'Проверьте период действия расценки'; end if;
  if not exists (select 1 from public.objects where id = p_object_id and company_id = v_company_id) then raise exception 'Объект не найден'; end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_piece_rates
  set is_active = false, updated_by = v_user_id, updated_by_name = v_name, updated_at = now()
  where company_id = v_company_id and object_id = p_object_id and is_active = true
    and work_key = lower(v_work) and unit_key = lower(v_unit);
  insert into public.estimator_piece_rates (
    company_id, object_id, work, work_key, unit, unit_key, rate_amount,
    valid_from, valid_to, created_by, created_by_name
  ) values (
    v_company_id, p_object_id, v_work, lower(v_work), v_unit, lower(v_unit),
    p_rate_amount, p_valid_from, p_valid_to, v_user_id, v_name
  ) returning id into v_id;
  return v_id;
end;
$function$;

create or replace function public.deactivate_estimator_piece_rate(p_rate_id uuid)
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
  if v_role not in ('admin', 'developer', 'accountant') then raise exception 'Внутренние расценки настраивает бухгалтер или руководитель'; end if;
  select coalesce(full_name, '') into v_name from public.user_profiles where id = v_user_id;
  update public.estimator_piece_rates
  set is_active = false, updated_by = v_user_id, updated_by_name = v_name, updated_at = now()
  where id = p_rate_id and company_id = v_company_id;
  if not found then raise exception 'Расценка не найдена'; end if;
end;
$function$;

-- Keep the existing member-access semantics but allow estimator as a company-wide specialist.
create or replace function public.update_company_member_access(
  p_company_id uuid,
  p_user_id uuid,
  p_role text,
  p_profession text default '',
  p_object_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth', 'pg_temp'
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_object_name text;
  v_person_id uuid;
  v_profile_name text;
  v_profile_phone text;
  v_profession text := btrim(coalesce(p_profession, ''));
begin
  if v_actor_id is null then raise exception 'Требуется вход в аккаунт' using errcode = '42501'; end if;
  select m.role into v_actor_role
  from public.company_memberships m
  join public.companies c on c.id = m.company_id
  where m.company_id = p_company_id and m.user_id = v_actor_id and m.is_active = true
    and m.role in ('owner', 'admin', 'developer') and c.status = 'active';
  if v_actor_role is null then raise exception 'Изменять пользователей может только администратор или разработчик компании' using errcode = '42501'; end if;
  if p_user_id = v_actor_id then raise exception 'Нельзя изменить собственную роль через управление командой' using errcode = '42501'; end if;
  if p_role not in ('admin', 'developer', 'foreman', 'lawyer', 'accountant', 'hr', 'procurement', 'estimator') then
    raise exception 'Недопустимая роль' using errcode = '22023';
  end if;
  select m.role, m.person_id into v_target_role, v_person_id
  from public.company_memberships m where m.company_id = p_company_id and m.user_id = p_user_id for update;
  if v_target_role is null then raise exception 'Пользователь не найден в компании'; end if;
  if v_target_role = 'owner' then raise exception 'Нельзя изменить роль владельца компании' using errcode = '42501'; end if;
  if p_role = 'foreman' then
    select o.name into v_object_name from public.objects o
    where o.company_id = p_company_id and o.id = p_object_id and o.is_active = true;
    if v_object_name is null then raise exception 'Для прораба выберите действующий объект'; end if;
  else
    p_object_id := null; v_object_name := null;
  end if;
  if v_person_id is null then
    select up.full_name, up.phone into v_profile_name, v_profile_phone
    from public.user_profiles up where up.id = p_user_id;
    v_person_id := private.resolve_company_person_identity(p_company_id, v_profile_name, v_profile_phone);
  end if;
  update public.company_memberships m
  set role = p_role, person_id = coalesce(m.person_id, v_person_id), is_active = true, updated_at = now()
  where m.company_id = p_company_id and m.user_id = p_user_id;
  delete from public.object_memberships a where a.company_id = p_company_id and a.user_id = p_user_id;
  if p_role = 'foreman' then
    insert into public.object_memberships(company_id, object_id, user_id, created_by)
    values (p_company_id, p_object_id, p_user_id, v_actor_id);
  end if;
  update public.user_profiles p
  set profession = v_profession,
      role = case when p.active_company_id = p_company_id then p_role else p.role end,
      object_name = case when p.active_company_id = p_company_id then case when p_role = 'foreman' then v_object_name else null end else p.object_name end,
      updated_at = now()
  where p.id = p_user_id;
  if not found then raise exception 'Профиль пользователя не найден'; end if;
  if v_person_id is not null then
    update public.employees e set position = v_profession, updated_at = now()
    where e.company_id = p_company_id and e.person_id = v_person_id and e.archived_at is null and e.position is distinct from v_profession;
    perform private.sync_person_to_user_profiles(p_company_id, v_person_id, coalesce(v_profile_name, ''), coalesce(v_profile_phone, ''));
    perform private.sync_employee_profession_to_user_profiles(p_company_id, v_person_id);
  end if;
  return jsonb_build_object(
    'updated', true, 'company_id', p_company_id, 'user_id', p_user_id,
    'role', p_role, 'object_id', p_object_id, 'object_name', coalesce(v_object_name, ''),
    'person_id', v_person_id, 'profession', v_profession
  );
end;
$function$;

revoke all on public.estimator_period_closings from anon;
revoke all on public.estimator_period_closing_items from anon;
revoke all on public.estimator_period_closing_reviews from anon;
revoke all on public.estimator_piece_rates from anon;
revoke all on public.estimator_closing_earnings from anon;
revoke all on public.estimator_closing_earning_issues from anon;
revoke insert, update, delete on public.estimator_period_closings from authenticated;
revoke insert, update, delete on public.estimator_period_closing_items from authenticated;
revoke insert, update, delete on public.estimator_period_closing_reviews from authenticated;
revoke insert, update, delete on public.estimator_piece_rates from authenticated;
revoke insert, update, delete on public.estimator_closing_earnings from authenticated;
revoke insert, update, delete on public.estimator_closing_earning_issues from authenticated;
grant select on public.estimator_period_closings to authenticated;
grant select on public.estimator_period_closing_items to authenticated;
grant select on public.estimator_period_closing_reviews to authenticated;
grant select on public.estimator_piece_rates to authenticated;
grant select on public.estimator_closing_earnings to authenticated;
grant select on public.estimator_closing_earning_issues to authenticated;
grant execute on function public.normalize_estimator_unit(text) to authenticated;
grant execute on function public.create_or_refresh_estimator_period_closing(uuid, integer, integer) to authenticated;
grant execute on function public.submit_estimator_period_closing(uuid) to authenticated;
grant execute on function public.review_estimator_period_closing(uuid, text, text) to authenticated;
grant execute on function public.mark_estimator_period_closing_sent(uuid) to authenticated;
grant execute on function public.mark_estimator_period_closing_paid(uuid) to authenticated;
grant execute on function public.upsert_estimator_piece_rate(uuid, text, text, numeric, date, date) to authenticated;
grant execute on function public.deactivate_estimator_piece_rate(uuid) to authenticated;
grant execute on function public.update_company_member_access(uuid, uuid, text, text, uuid) to authenticated;
