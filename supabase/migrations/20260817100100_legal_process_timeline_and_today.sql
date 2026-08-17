-- Процессуальный календарь дел и автоматическая рабочая очередь «Сегодня».

create table if not exists public.legal_matter_process_events (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  matter_id uuid not null references public.legal_matters(id) on delete cascade,
  event_kind text not null check (event_kind = any (array[
    'hearing','deadline','filing','incoming','outgoing','decision','enforcement','note'
  ]::text[])),
  title text not null,
  event_at timestamptz,
  due_at timestamptz,
  status text not null default 'scheduled' check (status = any (array['scheduled','completed','cancelled']::text[])),
  result text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_matter_process_events_matter_idx
  on public.legal_matter_process_events(matter_id, created_at desc);
create index if not exists legal_matter_process_events_company_due_idx
  on public.legal_matter_process_events(company_id, status, due_at);

alter table public.legal_matter_process_events enable row level security;
revoke all on public.legal_matter_process_events from public, anon;
grant select, insert, update, delete on public.legal_matter_process_events to authenticated;

drop policy if exists legal_process_events_select on public.legal_matter_process_events;
create policy legal_process_events_select
on public.legal_matter_process_events
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.legal_matter_allowed_for_user(matter_id)
);

drop policy if exists legal_process_events_insert on public.legal_matter_process_events;
create policy legal_process_events_insert
on public.legal_matter_process_events
for insert
to authenticated
with check (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
);

drop policy if exists legal_process_events_update on public.legal_matter_process_events;
create policy legal_process_events_update
on public.legal_matter_process_events
for update
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
)
with check (company_id = public.current_user_company_id());

drop policy if exists legal_process_events_delete on public.legal_matter_process_events;
create policy legal_process_events_delete
on public.legal_matter_process_events
for delete
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_has_permission('legal.matters.edit')
  and public.legal_matter_allowed_for_user(matter_id)
);

create or replace function public.guard_legal_process_event_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.legal_matters m
    where m.id = new.matter_id and m.company_id = new.company_id
  ) then
    raise exception 'Дело не принадлежит компании';
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
  end if;
  return new;
end;
$$;

revoke all on function public.guard_legal_process_event_tenant() from public, anon, authenticated;

drop trigger if exists legal_process_event_tenant_guard on public.legal_matter_process_events;
create trigger legal_process_event_tenant_guard
before insert or update on public.legal_matter_process_events
for each row execute function public.guard_legal_process_event_tenant();

create or replace function public.sync_legal_process_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_matter_id uuid;
  v_company uuid;
  v_title text;
  v_result text;
  v_next_hearing timestamptz;
begin
  if tg_op = 'DELETE' then
    v_matter_id := old.matter_id;
    v_company := old.company_id;
    v_title := old.title;
    v_result := old.result;
  else
    v_matter_id := new.matter_id;
    v_company := new.company_id;
    v_title := new.title;
    v_result := new.result;
  end if;

  select min(coalesce(e.event_at, e.due_at))
    into v_next_hearing
  from public.legal_matter_process_events e
  where e.matter_id = v_matter_id
    and e.event_kind = 'hearing'
    and e.status = 'scheduled'
    and coalesce(e.event_at, e.due_at) >= now();

  update public.legal_matters
     set next_hearing_at = v_next_hearing,
         updated_at = now()
   where id = v_matter_id and company_id = v_company;

  if tg_op = 'INSERT' then
    insert into public.legal_matter_events(
      company_id, matter_id, event_type, title, body, actor_user_id
    ) values (
      v_company,
      v_matter_id,
      'note',
      'Процесс: ' || coalesce(v_title, ''),
      coalesce(v_result, ''),
      auth.uid()
    );
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.sync_legal_process_event() from public, anon, authenticated;

drop trigger if exists legal_process_event_sync on public.legal_matter_process_events;
create trigger legal_process_event_sync
after insert or update or delete on public.legal_matter_process_events
for each row execute function public.sync_legal_process_event();

create or replace function public.legal_today_items()
returns table(
  item_type text,
  entity_type text,
  entity_id uuid,
  title text,
  subtitle text,
  due_at timestamptz,
  severity text,
  employee_id uuid,
  object_id uuid,
  action_code text,
  sort_key integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company uuid := public.current_user_company_id();
begin
  if auth.uid() is null or v_company is null or not (
    public.current_user_has_permission('legal.directory.view')
    or public.current_user_has_permission('legal.documents.view')
    or public.current_user_has_permission('legal.matters.view')
    or public.is_admin()
  ) then
    raise exception 'Нет доступа к рабочей очереди юриста';
  end if;

  return query
  with missing as (
    select
      e.id as employee_id,
      e.object_id,
      e.fio,
      count(*) filter (where c.is_required and c.applicable and not c.present) as missing_count,
      string_agg(c.requirement_title, ', ' order by c.sort_order)
        filter (where c.is_required and c.applicable and not c.present) as missing_titles,
      min(c.priority) filter (where c.is_required and c.applicable and not c.present) as min_priority
    from public.employees e
    cross join lateral public.legal_employee_completeness(e.id) c
    where e.company_id = v_company
      and coalesce(e.is_active, true)
      and e.archived_at is null
    group by e.id, e.object_id, e.fio
  )
  select
    'missing_documents'::text,
    'employee'::text,
    m.employee_id,
    m.fio || ': неполный комплект',
    m.missing_count::text || ' • ' || coalesce(m.missing_titles, ''),
    null::timestamptz,
    case when coalesce(m.min_priority, 100) <= 15 then 'warning' else 'info' end,
    m.employee_id,
    m.object_id,
    'open_employee'::text,
    40
  from missing m
  where m.missing_count > 0

  union all

  select
    'document_attention',
    'legal_document',
    d.id,
    d.title,
    trim(both ' • ' from concat_ws(' • ',
      case d.status
        when 'awaiting_signature' then 'Ожидает подписи'
        when 'needs_correction' then 'Требует исправления'
        when 'expired' then 'Истёк'
        else null
      end,
      case when d.expires_on < current_date then 'Срок действия истёк'
           when d.expires_on <= current_date + 30 then 'Срок действия подходит'
           else null end,
      case when d.next_action_due_at < now() then 'Следующее действие просрочено'
           when d.next_action_due_at <= now() + interval '7 days' then coalesce(nullif(d.next_action,''), 'Ближайшее действие')
           else null end
    )),
    nullif(least(
      coalesce(d.next_action_due_at, 'infinity'::timestamptz),
      coalesce(d.expires_on::timestamptz, 'infinity'::timestamptz)
    ), 'infinity'::timestamptz),
    case
      when d.status in ('needs_correction','expired')
        or d.expires_on < current_date
        or d.next_action_due_at < now() then 'danger'
      else 'warning'
    end,
    d.employee_id,
    d.object_id,
    'open_document',
    10
  from public.legal_documents d
  where d.company_id = v_company
    and d.archived_at is null
    and (
      d.status in ('awaiting_signature','needs_correction','expired')
      or d.approval_status = 'pending'
      or d.expires_on <= current_date + 30
      or d.next_action_due_at <= now() + interval '7 days'
    )

  union all

  select
    'matter_attention',
    'legal_matter',
    m.id,
    m.title,
    trim(both ' • ' from concat_ws(' • ',
      case when m.due_at < now() then 'Срок просрочен' end,
      case when m.risk_level in ('high','critical') then 'Высокий риск' end,
      case when m.requires_manager_decision and m.decision_status = 'pending' then 'Ждёт решения руководителя' end,
      case when m.matter_type = 'court' and m.next_hearing_at <= now() + interval '14 days' then 'Ближайшее заседание' end,
      case when m.matter_type = 'claim' and m.response_due_at <= now() + interval '7 days' then 'Срок ответа по претензии' end
    )),
    nullif(least(
      coalesce(m.due_at, 'infinity'::timestamptz),
      coalesce(m.next_hearing_at, 'infinity'::timestamptz),
      coalesce(m.response_due_at, 'infinity'::timestamptz)
    ), 'infinity'::timestamptz),
    case
      when m.risk_level = 'critical'
        or m.due_at < now()
        or (m.matter_type = 'claim' and m.response_due_at < now()) then 'danger'
      else 'warning'
    end,
    m.employee_id,
    m.object_id,
    'open_matter',
    5
  from public.legal_matters m
  where m.company_id = v_company
    and m.status not in ('resolved','closed')
    and (
      m.due_at <= now() + interval '7 days'
      or m.risk_level in ('high','critical')
      or (m.requires_manager_decision and m.decision_status = 'pending')
      or (m.matter_type = 'court' and m.next_hearing_at <= now() + interval '14 days')
      or (m.matter_type = 'claim' and m.response_due_at <= now() + interval '7 days')
    )

  union all

  select
    'process_event',
    'legal_matter',
    e.matter_id,
    e.title,
    case e.event_kind
      when 'hearing' then 'Судебное заседание'
      when 'deadline' then 'Процессуальный срок'
      when 'filing' then 'Подача документа'
      when 'incoming' then 'Ожидаемый входящий документ'
      when 'outgoing' then 'Исходящий документ'
      when 'decision' then 'Решение'
      when 'enforcement' then 'Исполнение'
      else 'Событие дела'
    end,
    coalesce(e.due_at, e.event_at),
    case when coalesce(e.due_at, e.event_at) < now() then 'danger' else 'warning' end,
    m.employee_id,
    m.object_id,
    'open_matter',
    3
  from public.legal_matter_process_events e
  join public.legal_matters m on m.id = e.matter_id and m.company_id = e.company_id
  where e.company_id = v_company
    and e.status = 'scheduled'
    and coalesce(e.due_at, e.event_at) <= now() + interval '14 days'

  union all

  select
    'recovery',
    'absence_fine',
    f.id,
    coalesce(emp.fio, 'Сотрудник') || ': взыскание ' || round(f.amount)::text || ' ₽',
    concat_ws(' • ',
      case when coalesce(f.act_file_path, '') = '' then 'нет акта' else 'акт есть' end,
      case when coalesce(f.explanation_file_path, '') = '' then 'нет объяснительной' else 'объяснительная есть' end,
      'ожидает решения руководителя'
    ),
    null::timestamptz,
    case when coalesce(f.act_file_path, '') = '' or coalesce(f.explanation_file_path, '') = '' then 'danger' else 'warning' end,
    f.employee_id,
    emp.object_id,
    'open_employee',
    20
  from public.absence_fines f
  left join public.employees emp on emp.id = f.employee_id and emp.company_id = f.company_id
  where f.company_id = v_company and f.status = 'pending';
end;
$$;

revoke all on function public.legal_today_items() from public, anon;
grant execute on function public.legal_today_items() to authenticated;
