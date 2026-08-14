-- AppСтрой: акт о нарушении для подтверждённого невыхода.
--
-- Логика:
-- 1. Явный attendance.status = 'no_show' создаёт ожидающий штраф 10 000 ₽.
-- 2. Вместе со штрафом автоматически создаётся акт о нарушении.
-- 3. Акт хранит основание и сумму до подтверждения штрафа.
-- 4. Штраф по-прежнему нельзя подтвердить без скана объяснительной.
-- 5. При подтверждении штрафа акт подтверждается и связывается с payments.
-- 6. Если no_show исправили до подтверждения, и штраф, и акт отменяются.

create table if not exists public.employee_violation_acts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  object_id uuid references public.objects(id) on delete set null,
  object_name text not null default '',
  source_type text not null default 'absence_fine',
  source_id uuid not null,
  act_number text not null,
  violation_date date not null,
  violation_code text not null,
  violation_title text not null,
  description text not null default '',
  penalty_amount numeric(14,2) not null default 10000 check (penalty_amount >= 0),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  payment_id uuid references public.payments(id) on delete set null,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, source_type, source_id),
  unique(company_id, act_number)
);

create index if not exists employee_violation_acts_employee_date_idx
  on public.employee_violation_acts(company_id, employee_id, violation_date desc);
create index if not exists employee_violation_acts_status_idx
  on public.employee_violation_acts(company_id, status, violation_date desc);

alter table public.employee_violation_acts enable row level security;
revoke all on public.employee_violation_acts from anon, authenticated;

comment on table public.employee_violation_acts is
  'Акты о нарушениях сотрудников. Для no_show акт создаётся автоматически вместе с ожидающим штрафом.';

create or replace function private.absence_violation_act_number(
  p_fine_id uuid,
  p_absence_date date
)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select 'НВ-' || to_char(p_absence_date, 'YYYYMMDD') || '-' ||
    upper(left(replace(p_fine_id::text, '-', ''), 12));
$$;

revoke all on function private.absence_violation_act_number(uuid, date)
  from public, anon, authenticated;

create or replace function private.sync_absence_fine_for_day(
  p_company_id uuid,
  p_employee_id uuid,
  p_work_date date
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_has_no_show boolean;
  v_has_positive boolean;
  v_fine_id uuid;
  v_fine_status text;
  v_payment_id uuid;
  v_object_id uuid;
  v_object_name text;
begin
  if p_company_id is null or p_employee_id is null or p_work_date is null then
    return;
  end if;

  select exists(
    select 1
    from public.attendance a
    where a.company_id = p_company_id
      and a.employee_id = p_employee_id
      and a.work_date = p_work_date
      and a.deleted_at is null
      and lower(btrim(coalesce(a.status, ''))) = 'no_show'
      and coalesce(a.shifts, 0) = 0
  ) into v_has_no_show;

  select exists(
    select 1
    from public.attendance a
    where a.company_id = p_company_id
      and a.employee_id = p_employee_id
      and a.work_date = p_work_date
      and a.deleted_at is null
      and coalesce(a.shifts, 0) > 0
  ) into v_has_positive;

  if v_has_no_show and not v_has_positive then
    insert into public.absence_fines(
      company_id,
      employee_id,
      absence_date,
      amount,
      status,
      updated_at
    ) values (
      p_company_id,
      p_employee_id,
      p_work_date,
      10000,
      'pending',
      now()
    )
    on conflict(company_id, employee_id, absence_date)
    do update
    set status = case
          when public.absence_fines.status = 'confirmed' then 'confirmed'
          else 'pending'
        end,
        amount = 10000,
        updated_at = now()
    returning id, status, payment_id
      into v_fine_id, v_fine_status, v_payment_id;

    select e.object_id, coalesce(nullif(btrim(e.object_name), ''), 'Без объекта')
      into v_object_id, v_object_name
    from public.employees e
    where e.id = p_employee_id
      and e.company_id = p_company_id;

    insert into public.employee_violation_acts(
      company_id,
      employee_id,
      object_id,
      object_name,
      source_type,
      source_id,
      act_number,
      violation_date,
      violation_code,
      violation_title,
      description,
      penalty_amount,
      status,
      payment_id,
      updated_at
    ) values (
      p_company_id,
      p_employee_id,
      v_object_id,
      coalesce(v_object_name, 'Без объекта'),
      'absence_fine',
      v_fine_id,
      private.absence_violation_act_number(v_fine_id, p_work_date),
      p_work_date,
      'no_show',
      'Невыход на смену',
      format(
        'Зафиксирован невыход сотрудника на смену %s. Штраф по акту — 10 000 ₽.',
        to_char(p_work_date, 'DD.MM.YYYY')
      ),
      10000,
      v_fine_status,
      v_payment_id,
      now()
    )
    on conflict(company_id, source_type, source_id)
    do update
    set employee_id = excluded.employee_id,
        object_id = excluded.object_id,
        object_name = excluded.object_name,
        violation_date = excluded.violation_date,
        violation_code = excluded.violation_code,
        violation_title = excluded.violation_title,
        description = excluded.description,
        penalty_amount = excluded.penalty_amount,
        status = case
          when public.employee_violation_acts.status = 'confirmed' then 'confirmed'
          else excluded.status
        end,
        payment_id = coalesce(public.employee_violation_acts.payment_id, excluded.payment_id),
        updated_at = now();
  else
    update public.absence_fines
    set status = 'cancelled',
        updated_at = now()
    where company_id = p_company_id
      and employee_id = p_employee_id
      and absence_date = p_work_date
      and status = 'pending'
    returning id into v_fine_id;

    if v_fine_id is not null then
      update public.employee_violation_acts
      set status = 'cancelled',
          updated_at = now()
      where company_id = p_company_id
        and source_type = 'absence_fine'
        and source_id = v_fine_id
        and status = 'pending';
    end if;
  end if;
end;
$$;

-- Делаем акты для уже существующих штрафов за невыход.
insert into public.employee_violation_acts(
  company_id,
  employee_id,
  object_id,
  object_name,
  source_type,
  source_id,
  act_number,
  violation_date,
  violation_code,
  violation_title,
  description,
  penalty_amount,
  status,
  payment_id,
  confirmed_at,
  confirmed_by,
  created_at,
  updated_at
)
select
  fine.company_id,
  fine.employee_id,
  employee.object_id,
  coalesce(nullif(btrim(employee.object_name), ''), 'Без объекта'),
  'absence_fine',
  fine.id,
  private.absence_violation_act_number(fine.id, fine.absence_date),
  fine.absence_date,
  'no_show',
  'Невыход на смену',
  format(
    'Зафиксирован невыход сотрудника на смену %s. Штраф по акту — 10 000 ₽.',
    to_char(fine.absence_date, 'DD.MM.YYYY')
  ),
  fine.amount,
  fine.status,
  fine.payment_id,
  fine.confirmed_at,
  fine.confirmed_by,
  fine.created_at,
  now()
from public.absence_fines fine
join public.employees employee
  on employee.id = fine.employee_id
 and employee.company_id = fine.company_id
on conflict(company_id, source_type, source_id)
do update
set penalty_amount = excluded.penalty_amount,
    status = excluded.status,
    payment_id = excluded.payment_id,
    confirmed_at = excluded.confirmed_at,
    confirmed_by = excluded.confirmed_by,
    updated_at = now();

-- V2 оставляет старый RPC нетронутым и добавляет сведения об акте.
create or replace function public.get_pending_absence_fines_v2()
returns table(
  id uuid,
  employee_id uuid,
  employee_name text,
  object_name text,
  absence_date date,
  amount numeric,
  status text,
  explanation_file_name text,
  explanation_file_path text,
  explanation_content_type text,
  explanation_uploaded_at timestamptz,
  created_at timestamptz,
  violation_act_id uuid,
  violation_act_number text,
  violation_act_status text,
  violation_title text,
  violation_description text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    fine.id,
    fine.employee_id,
    coalesce(nullif(btrim(employee.fio), ''), 'Сотрудник'),
    coalesce(nullif(btrim(employee.object_name), ''), 'Без объекта'),
    fine.absence_date,
    fine.amount,
    fine.status,
    fine.explanation_file_name,
    fine.explanation_file_path,
    fine.explanation_content_type,
    fine.explanation_uploaded_at,
    fine.created_at,
    act.id,
    act.act_number,
    act.status,
    act.violation_title,
    act.description
  from public.absence_fines fine
  join public.employees employee
    on employee.id = fine.employee_id
   and employee.company_id = fine.company_id
  left join public.employee_violation_acts act
    on act.company_id = fine.company_id
   and act.source_type = 'absence_fine'
   and act.source_id = fine.id
  where auth.uid() is not null
    and public.is_admin()
    and fine.company_id = public.current_user_company_id()
    and fine.status = 'pending'
  order by fine.absence_date desc, employee.fio;
$$;

revoke all on function public.get_pending_absence_fines_v2() from public, anon;
grant execute on function public.get_pending_absence_fines_v2() to authenticated;

create or replace function public.confirm_absence_fine(p_fine_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_fine public.absence_fines%rowtype;
  v_act public.employee_violation_acts%rowtype;
  v_payment_id uuid;
  v_object_id uuid;
  v_object_name text;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав';
  end if;

  select * into v_fine
  from public.absence_fines
  where id = p_fine_id
    and company_id = v_company_id
  for update;

  if not found then
    raise exception 'Штраф не найден';
  end if;

  if v_fine.status = 'confirmed' and v_fine.payment_id is not null then
    return v_fine.payment_id;
  end if;

  if v_fine.status <> 'pending' then
    raise exception 'Штраф нельзя подтвердить';
  end if;

  if btrim(coalesce(v_fine.explanation_file_path, '')) = '' then
    raise exception 'Сначала прикрепите скан объяснительной';
  end if;

  if not exists(
    select 1
    from storage.objects
    where bucket_id = 'absence-explanations'
      and name = v_fine.explanation_file_path
  ) then
    raise exception 'Скан объяснительной не найден';
  end if;

  select e.object_id, coalesce(nullif(btrim(e.object_name), ''), 'Без объекта')
    into v_object_id, v_object_name
  from public.employees e
  where e.id = v_fine.employee_id
    and e.company_id = v_fine.company_id;

  insert into public.employee_violation_acts(
    company_id,
    employee_id,
    object_id,
    object_name,
    source_type,
    source_id,
    act_number,
    violation_date,
    violation_code,
    violation_title,
    description,
    penalty_amount,
    status,
    updated_at
  ) values (
    v_fine.company_id,
    v_fine.employee_id,
    v_object_id,
    coalesce(v_object_name, 'Без объекта'),
    'absence_fine',
    v_fine.id,
    private.absence_violation_act_number(v_fine.id, v_fine.absence_date),
    v_fine.absence_date,
    'no_show',
    'Невыход на смену',
    format(
      'Зафиксирован невыход сотрудника на смену %s. Штраф по акту — 10 000 ₽.',
      to_char(v_fine.absence_date, 'DD.MM.YYYY')
    ),
    10000,
    'pending',
    now()
  )
  on conflict(company_id, source_type, source_id)
  do update
  set penalty_amount = 10000,
      updated_at = now();

  select * into v_act
  from public.employee_violation_acts
  where company_id = v_fine.company_id
    and source_type = 'absence_fine'
    and source_id = v_fine.id
  for update;

  insert into public.payments(
    company_id,
    employee_id,
    period_year,
    period_month,
    payment_date,
    amount,
    payment_type,
    comment,
    updated_at
  ) values (
    v_fine.company_id,
    v_fine.employee_id,
    extract(year from v_fine.absence_date)::integer,
    extract(month from v_fine.absence_date)::integer,
    current_date,
    10000,
    'fine',
    format(
      'Штраф по акту %s за невыход %s. Объяснительная приложена.',
      v_act.act_number,
      to_char(v_fine.absence_date, 'DD.MM.YYYY')
    ),
    now()
  ) returning id into v_payment_id;

  update public.absence_fines
  set status = 'confirmed',
      payment_id = v_payment_id,
      confirmed_at = now(),
      confirmed_by = auth.uid(),
      updated_at = now()
  where id = v_fine.id;

  update public.employee_violation_acts
  set status = 'confirmed',
      payment_id = v_payment_id,
      confirmed_at = now(),
      confirmed_by = auth.uid(),
      updated_at = now()
  where id = v_act.id;

  return v_payment_id;
end;
$$;

revoke all on function public.confirm_absence_fine(uuid) from public, anon;
grant execute on function public.confirm_absence_fine(uuid) to authenticated;
