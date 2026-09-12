-- A task may participate in the work order through its assignees and KTU
-- without carrying planned or actual physical output.
alter table public.task_work_plans
  add column without_volume boolean not null default false;

alter table public.task_work_plans
  add constraint task_work_plans_without_volume_shape_check check (
    not without_volume
    or (planned_quantity is null and btrim(unit) = '')
  );

alter table public.task_work_days
  alter column quantity drop not null;
alter table public.task_work_days
  drop constraint if exists task_work_days_unit_check;
alter table public.task_work_days
  add constraint task_work_days_quantity_positive_check
    check (quantity is null or (quantity > 0 and quantity < 'Infinity'::numeric)),
  add constraint task_work_days_unit_length_check
    check (length(btrim(unit)) <= 40);

create or replace function public.validate_task_work_day() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  person jsonb; canonical jsonb := '[]'::jsonb; prior jsonb := '[]'::jsonb;
  v_employee_id uuid; person_name text; weight numeric; total numeric := 0;
  seen uuid[] := '{}'::uuid[]; task_row public.tasks%rowtype;
  plan_without_volume boolean; plan_unit text;
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
  select without_volume, unit into plan_without_volume, plan_unit
    from public.task_work_plans where task_id = new.task_id;
  if not found then raise exception 'План наряда для задачи не найден'; end if;
  if coalesce(plan_without_volume, false) then
    if new.quantity is not null or btrim(new.unit) <> '' then
      raise exception 'Для задачи без объёма количество и единица измерения не указываются';
    end if;
  elsif new.quantity is null or new.quantity <= 0
      or btrim(new.unit) = '' or plan_unit <> btrim(new.unit) then
    raise exception 'Укажите положительный объём в единице плана задачи';
  end if;
  if jsonb_typeof(new.participants) <> 'array' or jsonb_array_length(new.participants) = 0 then
    raise exception 'Укажите исполнителей';
  end if;
  for person in select value from jsonb_array_elements(new.participants) loop
    v_employee_id := (person->>'employee_id')::uuid;
    weight := (person->>'ktu')::numeric;
    if v_employee_id is null or v_employee_id = any(seen) or weight is null or not (weight between 0 and 200) then
      raise exception 'Некорректный исполнитель или КТУ';
    end if;
    person_name := null;
    select value->>'fio' into person_name from jsonb_array_elements(prior)
      where value->>'employee_id' = v_employee_id::text;
    if person_name is null then
      select e.fio into person_name from public.task_assignees a
        join public.employees e on e.id = a.employee_id
      where a.task_id = new.task_id and a.employee_id = v_employee_id
        and e.company_id = task_row.company_id
        and lower(btrim(e.object_name)) = lower(btrim(task_row.object_name));
    end if;
    if person_name is null then raise exception 'Исполнитель не назначен на эту задачу'; end if;
    seen := array_append(seen, v_employee_id);
    total := total + weight;
    canonical := canonical || jsonb_build_array(jsonb_build_object(
      'employee_id', v_employee_id, 'fio', person_name, 'ktu', weight));
  end loop;
  if total <= 0 then raise exception 'Сумма КТУ должна быть положительной'; end if;
  new.participants := canonical;
  new.work := coalesce(task_row.work, '');
  new.axes := coalesce(task_row.axes, '');
  new.unit := btrim(new.unit);
  new.updated_at := now();
  return new;
end;
$$;

-- Keep the six-argument RPC for already installed clients. New clients call
-- this overload with the explicit task mode.
create function public.save_task_work_day(p_task_id uuid, p_planned numeric,
  p_unit text, p_date date, p_quantity numeric, p_participants jsonb,
  p_without_volume boolean)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  existing_without_volume boolean;
begin
  if auth.uid() is null or not public.task_is_allowed_for_user(p_task_id)
      or public.current_user_role() not in ('admin','developer','foreman') then
    raise exception 'Задача недоступна' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_task_id::text, 0));

  if coalesce(p_without_volume, false) then
    if p_planned is not null or nullif(btrim(p_unit), '') is not null
        or p_quantity is not null then
      raise exception 'Для задачи без объёма количество и единица измерения не указываются';
    end if;
  elsif (p_planned is not null or p_quantity is not null)
      and nullif(btrim(p_unit), '') is null then
    raise exception 'Укажите единицу измерения';
  end if;

  select without_volume into existing_without_volume
    from public.task_work_plans where task_id = p_task_id;
  if found and existing_without_volume is distinct from coalesce(p_without_volume, false)
      and exists(select 1 from public.task_work_days where task_id = p_task_id) then
    raise exception 'Режим объёма нельзя менять после сохранения результата задачи';
  end if;
  if not coalesce(p_without_volume, false) and exists(
      select 1 from public.task_work_days
      where task_id=p_task_id and unit <> btrim(p_unit)) then
    raise exception 'Единицу измерения нельзя менять, пока сохранён факт. Сначала исправьте дневные записи';
  end if;

  insert into public.task_work_plans(task_id, planned_quantity, unit, without_volume)
    values(p_task_id, p_planned,
      case when coalesce(p_without_volume, false) then '' else btrim(p_unit) end,
      coalesce(p_without_volume, false))
    on conflict(task_id) do update set
      planned_quantity=excluded.planned_quantity,
      unit=excluded.unit,
      without_volume=excluded.without_volume,
      updated_at=now();

  if jsonb_typeof(coalesce(p_participants, '[]'::jsonb)) = 'array'
      and jsonb_array_length(coalesce(p_participants, '[]'::jsonb)) > 0 then
    insert into public.task_work_days(task_id,work_date,quantity,unit,work,axes,participants)
      values(p_task_id,p_date,
        case when coalesce(p_without_volume, false) then null else p_quantity end,
        case when coalesce(p_without_volume, false) then '' else btrim(p_unit) end,
        '','',p_participants)
      on conflict(task_id,work_date) do update set
        quantity=excluded.quantity,
        unit=excluded.unit,
        participants=excluded.participants;
  end if;
end;
$$;
revoke all on function public.save_task_work_day(uuid,numeric,text,date,numeric,jsonb,boolean)
  from public, anon;
grant execute on function public.save_task_work_day(uuid,numeric,text,date,numeric,jsonb,boolean)
  to authenticated;
