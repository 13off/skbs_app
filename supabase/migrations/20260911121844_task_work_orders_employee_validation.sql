create or replace function public.validate_task_work_day() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  person jsonb; canonical jsonb := '[]'::jsonb; prior jsonb := '[]'::jsonb;
  v_employee_id uuid; person_name text; weight numeric; total numeric := 0;
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
    v_employee_id := (person->>'employee_id')::uuid;
    weight := (person->>'ktu')::numeric;
    if v_employee_id is null or v_employee_id = any(seen) or weight is null or not (weight between 0 and 10000) then
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

