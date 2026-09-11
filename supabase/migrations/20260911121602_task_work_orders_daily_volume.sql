-- Daily physical output is separate from milestone percentages and estimator approval.
create table public.task_work_plans (
  task_id uuid primary key references public.tasks(id) on delete cascade,
  planned_quantity numeric(18,3) check (planned_quantity >= 0 and planned_quantity < 'Infinity'::numeric),
  unit text not null default '' check (length(unit) <= 40),
  updated_at timestamptz not null default now()
);
create table public.task_work_days (
  task_id uuid not null references public.tasks(id) on delete cascade,
  work_date date not null,
  quantity numeric(18,3) not null check (quantity >= 0 and quantity < 'Infinity'::numeric),
  unit text not null check (length(btrim(unit)) between 1 and 40),
  work text not null,
  axes text not null,
  participants jsonb not null check (jsonb_typeof(participants) = 'array' and jsonb_array_length(participants) > 0),
  updated_at timestamptz not null default now(),
  primary key(task_id, work_date)
);
create index task_work_days_date_task_idx on public.task_work_days(work_date, task_id);
alter table public.task_work_plans enable row level security;
alter table public.task_work_days enable row level security;
revoke all on public.task_work_plans, public.task_work_days from anon, authenticated;
grant select, insert, update, delete on public.task_work_plans, public.task_work_days to authenticated;

create policy work_plans_read on public.task_work_plans for select to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_plans_insert on public.task_work_plans for insert to authenticated
  with check (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_plans_update on public.task_work_plans for update to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'))
  with check (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_plans_delete on public.task_work_plans for delete to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_days_read on public.task_work_days for select to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_days_insert on public.task_work_days for insert to authenticated
  with check (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_days_update on public.task_work_days for update to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'))
  with check (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));
create policy work_days_delete on public.task_work_days for delete to authenticated
  using (public.task_is_allowed_for_user(task_id) and public.current_user_role() in ('admin','developer','foreman'));

-- Validate direct REST writes as well as the RPC. Names come from employees,
-- never from the client. Keep historical names for already recorded people.
create function public.validate_task_work_day() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  person jsonb; canonical jsonb := '[]'::jsonb; prior jsonb := '[]'::jsonb;
  person_id uuid; person_name text; weight numeric; total numeric := 0;
  seen uuid[] := '{}'::uuid[]; task_row public.tasks%rowtype;
begin
  if tg_op = 'UPDATE' then
    if new.task_id <> old.task_id or new.work_date <> old.work_date then
      raise exception 'Нельзя переносить сохранённую запись на другую задачу или дату';
    end if;
    prior := old.participants;
  end if;
  if tg_op = 'INSERT' then
    select participants into prior from public.task_work_days
      where task_id=new.task_id and work_date=new.work_date;
    prior := coalesce(prior, '[]'::jsonb);
  end if;
  select * into task_row from public.tasks where id = new.task_id;
  if not found then raise exception 'Задача недоступна'; end if;
  if jsonb_typeof(new.participants) <> 'array' or jsonb_array_length(new.participants) = 0 then
    raise exception 'Укажите исполнителей';
  end if;
  for person in select value from jsonb_array_elements(new.participants) loop
    person_id := (person->>'employee_id')::uuid;
    weight := (person->>'ktu')::numeric;
    if person_id is null or person_id = any(seen) or weight is null or not (weight between 0 and 10000) then
      raise exception 'Некорректный исполнитель или КТУ';
    end if;
    person_name := null;
    select value->>'fio' into person_name from jsonb_array_elements(prior)
      where value->>'employee_id' = person_id::text;
    if person_name is null then
      select e.fio into person_name from public.task_assignees a
        join public.employees e on e.id = a.employee_id
      where a.task_id = new.task_id and a.employee_id = person_id
        and e.company_id = task_row.company_id
        and lower(btrim(e.object_name)) = lower(btrim(task_row.object_name));
    end if;
    if person_name is null then raise exception 'Исполнитель не назначен на эту задачу'; end if;
    seen := array_append(seen, person_id);
    total := total + weight;
    canonical := canonical || jsonb_build_array(jsonb_build_object(
      'employee_id', person_id, 'fio', person_name, 'ktu', weight));
  end loop;
  if total <= 0 then raise exception 'Сумма КТУ должна быть положительной'; end if;
  if exists(select 1 from public.task_work_plans where task_id=new.task_id and unit <> btrim(new.unit)) then
    raise exception 'Единица измерения не совпадает с планом задачи';
  end if;
  new.participants := canonical;
  new.work := coalesce(task_row.work, '');
  new.axes := coalesce(task_row.axes, '');
  new.unit := btrim(new.unit);
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function public.validate_task_work_day() from public, anon, authenticated;
create trigger validate_task_work_day before insert or update on public.task_work_days
  for each row execute function public.validate_task_work_day();

create function public.save_task_work_day(p_task_id uuid, p_planned numeric,
  p_unit text, p_date date, p_quantity numeric, p_participants jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or not public.task_is_allowed_for_user(p_task_id)
      or public.current_user_role() not in ('admin','developer','foreman') then
    raise exception 'Задача недоступна' using errcode = '42501';
  end if;
  -- Serialise unit changes and daily edits for this task without changing it.
  perform pg_advisory_xact_lock(hashtextextended(p_task_id::text, 0));
  if (p_planned is not null or p_quantity is not null) and nullif(btrim(p_unit), '') is null then
    raise exception 'Укажите единицу измерения';
  end if;
  if exists(select 1 from public.task_work_days where task_id=p_task_id and unit <> btrim(p_unit)) then
    raise exception 'Единицу измерения нельзя менять, пока сохранён факт. Сначала исправьте дневные записи';
  end if;
  insert into public.task_work_plans(task_id, planned_quantity, unit)
    values(p_task_id, p_planned, btrim(p_unit))
    on conflict(task_id) do update set planned_quantity=excluded.planned_quantity,
      unit=excluded.unit, updated_at=now();
  if p_quantity is not null then
    insert into public.task_work_days(task_id,work_date,quantity,unit,work,axes,participants)
      values(p_task_id,p_date,p_quantity,btrim(p_unit),'','',p_participants)
      on conflict(task_id,work_date) do update set quantity=excluded.quantity,
        unit=excluded.unit, participants=excluded.participants;
  end if;
end;
$$;
revoke all on function public.save_task_work_day(uuid,numeric,text,date,numeric,jsonb) from public, anon;
grant execute on function public.save_task_work_day(uuid,numeric,text,date,numeric,jsonb) to authenticated;
