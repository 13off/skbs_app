create table if not exists public.estimator_manual_volumes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  object_name text not null,
  work text not null,
  unit text not null,
  quantity numeric not null check (quantity > 0),
  work_date date not null,
  reason_code text not null check (
    reason_code = any (array[
      'unplanned_work'::text,
      'task_missing'::text,
      'correction'::text,
      'carryover'::text,
      'other'::text
    ])
  ),
  reason_comment text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_by_name text not null default '',
  created_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid references auth.users(id) on delete set null,
  voided_by_name text not null default '',
  void_reason text not null default '',
  updated_at timestamptz not null default now(),
  constraint estimator_manual_volumes_object_name_not_blank
    check (btrim(object_name) <> ''),
  constraint estimator_manual_volumes_work_not_blank
    check (btrim(work) <> ''),
  constraint estimator_manual_volumes_unit_not_blank
    check (btrim(unit) <> ''),
  constraint estimator_manual_volumes_reason_comment_not_blank
    check (btrim(reason_comment) <> ''),
  constraint estimator_manual_volumes_void_consistency check (
    (voided_at is null and voided_by is null and btrim(void_reason) = '')
    or
    (voided_at is not null and btrim(void_reason) <> '')
  )
);

create index if not exists estimator_manual_volumes_company_date_idx
  on public.estimator_manual_volumes (company_id, work_date desc);
create index if not exists estimator_manual_volumes_company_active_idx
  on public.estimator_manual_volumes (company_id, work_date desc)
  where voided_at is null;

alter table public.estimator_manual_volumes enable row level security;

drop policy if exists estimator_manual_volumes_select_allowed
  on public.estimator_manual_volumes;
create policy estimator_manual_volumes_select_allowed
on public.estimator_manual_volumes
for select
to authenticated
using (
  company_id = public.current_user_company_id()
  and public.current_user_role() in ('admin', 'developer', 'estimator')
);

create or replace function public.add_estimator_manual_volume(
  p_object_name text,
  p_work text,
  p_unit text,
  p_quantity numeric,
  p_work_date date,
  p_reason_code text,
  p_reason_comment text
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_user_name text := '';
  v_id uuid;
  v_reason_code text := lower(btrim(coalesce(p_reason_code, '')));
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;
  if v_company_id is null then
    raise exception 'Не выбрана компания';
  end if;
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Добавлять ручные объёмы может только инженер-сметчик или руководитель';
  end if;
  if btrim(coalesce(p_object_name, '')) = '' then
    raise exception 'Выберите объект';
  end if;
  if not exists (
    select 1
      from public.objects o
     where o.company_id = v_company_id
       and lower(btrim(o.name)) = lower(btrim(p_object_name))
  ) then
    raise exception 'Объект не найден в текущей компании';
  end if;
  if btrim(coalesce(p_work, '')) = '' then
    raise exception 'Укажите наименование работы';
  end if;
  if btrim(coalesce(p_unit, '')) = '' then
    raise exception 'Укажите единицу измерения';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Объём должен быть больше нуля';
  end if;
  if p_work_date is null then
    raise exception 'Укажите дату выполнения';
  end if;
  if p_work_date > current_date then
    raise exception 'Дата выполнения не может быть в будущем';
  end if;
  if v_reason_code not in ('unplanned_work', 'task_missing', 'correction', 'carryover', 'other') then
    raise exception 'Выберите причину ручного ввода';
  end if;
  if btrim(coalesce(p_reason_comment, '')) = '' then
    raise exception 'Объясните причину ручного ввода';
  end if;

  select coalesce(profile.full_name, '')
    into v_user_name
    from public.user_profiles profile
   where profile.id = v_user_id;

  insert into public.estimator_manual_volumes (
    company_id,
    object_name,
    work,
    unit,
    quantity,
    work_date,
    reason_code,
    reason_comment,
    created_by,
    created_by_name
  ) values (
    v_company_id,
    btrim(p_object_name),
    btrim(p_work),
    btrim(p_unit),
    p_quantity,
    p_work_date,
    v_reason_code,
    btrim(p_reason_comment),
    v_user_id,
    v_user_name
  )
  returning id into v_id;

  return v_id;
end;
$function$;

create or replace function public.void_estimator_manual_volume(
  p_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_role text := public.current_user_role();
  v_company_id uuid := public.current_user_company_id();
  v_user_name text := '';
  v_row public.estimator_manual_volumes%rowtype;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;
  if v_role not in ('admin', 'developer', 'estimator') then
    raise exception 'Аннулировать ручной объём может только инженер-сметчик или руководитель';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'Укажите причину аннулирования';
  end if;

  select *
    into v_row
    from public.estimator_manual_volumes row_data
   where row_data.id = p_id
     and row_data.company_id = v_company_id
   for update;

  if not found then
    raise exception 'Ручная запись не найдена';
  end if;
  if v_row.voided_at is not null then
    raise exception 'Эта ручная запись уже аннулирована';
  end if;

  select coalesce(profile.full_name, '')
    into v_user_name
    from public.user_profiles profile
   where profile.id = v_user_id;

  update public.estimator_manual_volumes
     set voided_at = now(),
         voided_by = v_user_id,
         voided_by_name = v_user_name,
         void_reason = btrim(p_reason),
         updated_at = now()
   where id = p_id;
end;
$function$;

revoke all on public.estimator_manual_volumes from anon;
revoke insert, update, delete on public.estimator_manual_volumes from authenticated;
grant select on public.estimator_manual_volumes to authenticated;

grant execute on function public.add_estimator_manual_volume(text, text, text, numeric, date, text, text)
  to authenticated;
grant execute on function public.void_estimator_manual_volume(uuid, text)
  to authenticated;
