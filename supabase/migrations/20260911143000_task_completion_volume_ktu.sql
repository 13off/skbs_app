-- Carry the plan entered during local-first task creation into the work-order
-- contour after the queued task reaches the database. These two task columns
-- are transport fields; task_work_plans remains the source used by the UI.
alter table public.tasks
  add column if not exists initial_planned_quantity numeric(18,3)
    check (initial_planned_quantity is null or initial_planned_quantity >= 0),
  add column if not exists initial_work_unit text not null default ''
    check (length(initial_work_unit) <= 40);

comment on column public.tasks.initial_planned_quantity is
  'Transport value used to create task_work_plans for local-first task creation.';
comment on column public.tasks.initial_work_unit is
  'Transport unit used to create task_work_plans for local-first task creation.';

create or replace function public.sync_initial_task_work_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.initial_planned_quantity is null then
    return new;
  end if;
  if nullif(btrim(new.initial_work_unit), '') is null then
    raise exception 'Укажите единицу измерения планового объёма';
  end if;

  insert into public.task_work_plans(task_id, planned_quantity, unit, updated_at)
  values(new.id, new.initial_planned_quantity, btrim(new.initial_work_unit), now())
  on conflict(task_id) do update
    set planned_quantity = excluded.planned_quantity,
        unit = excluded.unit,
        updated_at = now();
  return new;
end;
$$;
revoke all on function public.sync_initial_task_work_plan() from public, anon, authenticated;

drop trigger if exists sync_initial_task_work_plan on public.tasks;
create trigger sync_initial_task_work_plan
after insert or update on public.tasks
for each row execute function public.sync_initial_task_work_plan();

-- KTU is an independent per-person rating selected by the foreman. The UI and
-- database both accept only 0..200. The existing validator still checks that
-- participants belong to the task and that at least one KTU is positive.
create or replace function public.enforce_task_work_day_ktu_200()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  person jsonb;
  weight numeric;
begin
  if jsonb_typeof(new.participants) <> 'array' then
    raise exception 'Укажите исполнителей';
  end if;
  for person in select value from jsonb_array_elements(new.participants) loop
    weight := (person->>'ktu')::numeric;
    if weight is null or not (weight between 0 and 200) then
      raise exception 'КТУ должен быть от 0 до 200';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.enforce_task_work_day_ktu_200() from public, anon, authenticated;

drop trigger if exists enforce_task_work_day_ktu_200 on public.task_work_days;
create trigger enforce_task_work_day_ktu_200
before insert or update on public.task_work_days
for each row execute function public.enforce_task_work_day_ktu_200();
