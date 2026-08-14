-- AppСтрой: корректный контур штрафа за отсутствие.
--
-- 1. Убираем электронный акт о нарушении из приложения.
-- 2. Акт — бумажный документ, который сотрудник подписывает; в систему загружается его скан/фото.
-- 3. Неподтверждённый штраф 10 000 ₽ создаётся автоматически для отсутствовавшего сотрудника.
-- 4. Подтвердить штраф можно только когда приложены И объяснительная, И подписанный акт.
-- 5. Только после подтверждения создаётся запись public.payments(payment_type = 'fine').

alter table public.absence_fines
  add column if not exists act_file_name text,
  add column if not exists act_file_path text,
  add column if not exists act_content_type text,
  add column if not exists act_uploaded_at timestamptz,
  add column if not exists act_uploaded_by uuid references auth.users(id) on delete set null;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'absence-fine-acts',
  'absence-fine-acts',
  false,
  20971520,
  array['application/pdf','image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update
set file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Путь: <employee_id>/<absence_fine_id>/<filename>
drop policy if exists absence_fine_acts_select_admin on storage.objects;
create policy absence_fine_acts_select_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'absence-fine-acts'
  and public.is_admin()
  and exists (
    select 1
    from public.absence_fines fine
    where fine.company_id = public.current_user_company_id()
      and fine.employee_id::text = (storage.foldername(objects.name))[1]
      and fine.id::text = (storage.foldername(objects.name))[2]
  )
);

drop policy if exists absence_fine_acts_insert_admin on storage.objects;
create policy absence_fine_acts_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'absence-fine-acts'
  and public.is_admin()
  and exists (
    select 1
    from public.absence_fines fine
    where fine.company_id = public.current_user_company_id()
      and fine.status = 'pending'
      and fine.employee_id::text = (storage.foldername(objects.name))[1]
      and fine.id::text = (storage.foldername(objects.name))[2]
  )
);

drop policy if exists absence_fine_acts_delete_admin on storage.objects;
create policy absence_fine_acts_delete_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'absence-fine-acts'
  and public.is_admin()
  and exists (
    select 1
    from public.absence_fines fine
    where fine.company_id = public.current_user_company_id()
      and fine.employee_id::text = (storage.foldername(objects.name))[1]
      and fine.id::text = (storage.foldername(objects.name))[2]
  )
);

-- Убираем ошибочную модель электронного акта из предыдущей миграции.
drop function if exists public.get_pending_absence_fines_v2();
drop table if exists public.employee_violation_acts cascade;
drop function if exists private.absence_violation_act_number(uuid, date);

-- Явный status=no_show по-прежнему создаёт pending-штраф сразу.
create or replace function private.sync_absence_fine_for_day(
  p_company_id uuid,
  p_employee_id uuid,
  p_work_date date
)
returns void
language plpgsql
security definer
set search_path to 'public','private','pg_temp'
as $$
declare
  v_has_no_show boolean;
  v_has_positive boolean;
begin
  if p_company_id is null or p_employee_id is null or p_work_date is null then
    return;
  end if;

  select exists (
    select 1
    from public.attendance a
    where a.company_id = p_company_id
      and a.employee_id = p_employee_id
      and a.work_date = p_work_date
      and a.deleted_at is null
      and lower(btrim(coalesce(a.status,''))) = 'no_show'
      and coalesce(a.shifts,0) = 0
  ) into v_has_no_show;

  select exists (
    select 1
    from public.attendance a
    where a.company_id = p_company_id
      and a.employee_id = p_employee_id
      and a.work_date = p_work_date
      and a.deleted_at is null
      and coalesce(a.shifts,0) > 0
  ) into v_has_positive;

  if v_has_no_show and not v_has_positive then
    insert into public.absence_fines(
      company_id, employee_id, absence_date, amount, status, updated_at
    ) values (
      p_company_id, p_employee_id, p_work_date, 10000, 'pending', now()
    )
    on conflict (company_id, employee_id, absence_date) do update
    set status = case
          when public.absence_fines.status = 'confirmed' then 'confirmed'
          else 'pending'
        end,
        amount = 10000,
        updated_at = now();
  else
    update public.absence_fines
    set status = 'cancelled', updated_at = now()
    where company_id = p_company_id
      and employee_id = p_employee_id
      and absence_date = p_work_date
      and status = 'pending';
  end if;
end;
$$;

-- Возвращаем простой список pending-штрафов, но уже с двумя бумажными вложениями.
drop function if exists public.get_pending_absence_fines();
create function public.get_pending_absence_fines()
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
  act_file_name text,
  act_file_path text,
  act_content_type text,
  act_uploaded_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public','pg_temp'
as $$
  select
    fine.id,
    fine.employee_id,
    coalesce(nullif(btrim(employee.fio),''),'Сотрудник'),
    coalesce(nullif(btrim(employee.object_name),''),'Без объекта'),
    fine.absence_date,
    fine.amount,
    fine.status,
    fine.explanation_file_name,
    fine.explanation_file_path,
    fine.explanation_content_type,
    fine.explanation_uploaded_at,
    fine.act_file_name,
    fine.act_file_path,
    fine.act_content_type,
    fine.act_uploaded_at,
    fine.created_at
  from public.absence_fines fine
  join public.employees employee
    on employee.id = fine.employee_id
   and employee.company_id = fine.company_id
  where auth.uid() is not null
    and public.is_admin()
    and fine.company_id = public.current_user_company_id()
    and fine.status = 'pending'
  order by fine.absence_date desc, employee.fio;
$$;

create or replace function public.attach_absence_fine_act(
  p_fine_id uuid,
  p_file_name text,
  p_file_path text,
  p_content_type text
)
returns boolean
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_count integer;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав';
  end if;

  if btrim(coalesce(p_file_path,'')) = '' then
    raise exception 'Не указан файл акта';
  end if;

  if not exists (
    select 1
    from storage.objects object_row
    join public.absence_fines fine on fine.id = p_fine_id
    where object_row.bucket_id = 'absence-fine-acts'
      and object_row.name = p_file_path
      and fine.company_id = v_company_id
      and fine.status = 'pending'
  ) then
    raise exception 'Файл акта не найден в хранилище';
  end if;

  update public.absence_fines
  set act_file_name = left(btrim(coalesce(p_file_name,'')), 300),
      act_file_path = btrim(p_file_path),
      act_content_type = left(btrim(coalesce(p_content_type,'')), 120),
      act_uploaded_at = now(),
      act_uploaded_by = auth.uid(),
      updated_at = now()
  where id = p_fine_id
    and company_id = v_company_id
    and status = 'pending';

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

create or replace function public.confirm_absence_fine(p_fine_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_fine public.absence_fines%rowtype;
  v_payment_id uuid;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав';
  end if;

  select * into v_fine
  from public.absence_fines
  where id = p_fine_id
    and company_id = v_company_id
  for update;

  if not found then raise exception 'Штраф не найден'; end if;
  if v_fine.status = 'confirmed' and v_fine.payment_id is not null then
    return v_fine.payment_id;
  end if;
  if v_fine.status <> 'pending' then raise exception 'Штраф нельзя подтвердить'; end if;

  if btrim(coalesce(v_fine.explanation_file_path,'')) = '' then
    raise exception 'Сначала прикрепите скан объяснительной';
  end if;
  if btrim(coalesce(v_fine.act_file_path,'')) = '' then
    raise exception 'Сначала прикрепите подписанный акт о нарушении';
  end if;

  if not exists (
    select 1 from storage.objects
    where bucket_id = 'absence-explanations'
      and name = v_fine.explanation_file_path
  ) then
    raise exception 'Скан объяснительной не найден';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'absence-fine-acts'
      and name = v_fine.act_file_path
  ) then
    raise exception 'Скан подписанного акта не найден';
  end if;

  insert into public.payments(
    company_id, employee_id, period_year, period_month,
    payment_date, amount, payment_type, comment, updated_at
  ) values (
    v_fine.company_id,
    v_fine.employee_id,
    extract(year from v_fine.absence_date)::integer,
    extract(month from v_fine.absence_date)::integer,
    current_date,
    10000,
    'fine',
    format(
      'Штраф за невыход %s. Объяснительная и подписанный акт приложены.',
      to_char(v_fine.absence_date,'DD.MM.YYYY')
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

  return v_payment_id;
end;
$$;

-- На следующий день после 08:00 МСК snapshot посещаемости становится источником истины:
-- если табель по объекту был начат, но у сотрудника нет положительной смены,
-- ему автоматически создаётся pending-штраф 10 000 ₽.
create or replace function private.populate_manager_absence_todos()
returns void
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $$
declare
  v_today date := (now() at time zone 'Europe/Moscow')::date;
  v_yesterday date := (now() at time zone 'Europe/Moscow')::date - 1;
  v_now_local timestamp := now() at time zone 'Europe/Moscow';
  v_due_at timestamptz := (
    (now() at time zone 'Europe/Moscow')::date + time '08:00'
  ) at time zone 'Europe/Moscow';
  v_company record;
  v_snapshot jsonb;
  v_absent_count integer;
  v_employee_names text;
begin
  if v_now_local < v_today + time '08:00' then
    return;
  end if;

  for v_company in
    select company.id
    from public.companies company
    where company.status = 'active'
  loop
    v_snapshot := private.manager_attendance_snapshot(
      v_company.id,
      null,
      v_yesterday
    );
    v_absent_count := coalesce((v_snapshot ->> 'absent')::integer, 0);

    -- Сначала синхронизируем неподтверждённые штрафы с фактическим snapshot.
    update public.absence_fines fine
    set status = 'cancelled',
        updated_at = now()
    where fine.company_id = v_company.id
      and fine.absence_date = v_yesterday
      and fine.status = 'pending'
      and not exists (
        select 1
        from jsonb_array_elements(
          coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
        ) item
        where nullif(item ->> 'employee_id', '')::uuid = fine.employee_id
      );

    insert into public.absence_fines(
      company_id,
      employee_id,
      absence_date,
      amount,
      status,
      updated_at
    )
    select
      v_company.id,
      nullif(item ->> 'employee_id', '')::uuid,
      v_yesterday,
      10000,
      'pending',
      now()
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
    ) item
    where nullif(item ->> 'employee_id', '') is not null
    on conflict(company_id, employee_id, absence_date)
    do update
    set amount = 10000,
        status = case
          when public.absence_fines.status = 'confirmed' then 'confirmed'
          else 'pending'
        end,
        updated_at = now();

    if v_absent_count = 0 then
      update public.manager_todos todo
      set status = 'cancelled',
          updated_at = now()
      where todo.company_id = v_company.id
        and todo.source_type = 'attendance_no_show'
        and todo.source_date = v_yesterday
        and todo.status = 'open';
      continue;
    end if;

    select string_agg(item ->> 'title', ', ' order by item ->> 'title')
      into v_employee_names
    from jsonb_array_elements(
      coalesce(v_snapshot -> 'absent_items', '[]'::jsonb)
    ) item;

    insert into public.manager_todos(
      company_id,
      title,
      body,
      status,
      due_at,
      reminder_at,
      priority,
      source_type,
      source_key,
      source_date,
      metadata,
      recipient_user_id,
      target_role,
      created_by
    ) values (
      v_company.id,
      'Взять объяснительные',
      format(
        'За %s отсутствовали: %s. Взять объяснительную и подписать акт о нарушении у каждого сотрудника.',
        to_char(v_yesterday, 'DD.MM.YYYY'),
        coalesce(v_employee_names, 'сотрудники')
      ),
      'open',
      v_due_at,
      v_due_at,
      'high',
      'attendance_no_show',
      'attendance-no-show:' || v_yesterday::text,
      v_yesterday,
      jsonb_build_object(
        'absence_date', v_yesterday,
        'absent_count', v_absent_count,
        'employees', coalesce(v_snapshot -> 'absent_items', '[]'::jsonb),
        'pending_fine_amount', 10000,
        'fine_requires_explanation', true,
        'fine_requires_signed_act', true,
        'source', 'attendance_snapshot'
      ),
      null,
      'admin',
      null
    )
    on conflict (company_id, source_type, source_key)
      where source_key is not null
    do update
    set body = excluded.body,
        metadata = excluded.metadata,
        due_at = excluded.due_at,
        reminder_at = excluded.reminder_at,
        updated_at = now()
    where public.manager_todos.status = 'open';
  end loop;
end;
$$;

revoke all on function public.get_pending_absence_fines() from public, anon;
revoke all on function public.attach_absence_fine_act(uuid,text,text,text) from public, anon;
revoke all on function public.confirm_absence_fine(uuid) from public, anon;
grant execute on function public.get_pending_absence_fines() to authenticated;
grant execute on function public.attach_absence_fine_act(uuid,text,text,text) to authenticated;
grant execute on function public.confirm_absence_fine(uuid) to authenticated;
