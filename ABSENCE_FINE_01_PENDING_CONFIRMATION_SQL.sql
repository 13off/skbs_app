-- AppСтрой: подтверждаемый штраф за невыход.
-- Невыход создаёт ожидающий штраф 10 000 ₽. До загрузки объяснительной
-- и явного подтверждения запись НЕ попадает в public.payments.

create table if not exists public.absence_fines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  absence_date date not null,
  amount numeric(14,2) not null default 10000 check (amount = 10000),
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled')),
  explanation_file_name text,
  explanation_file_path text,
  explanation_content_type text,
  explanation_uploaded_at timestamptz,
  explanation_uploaded_by uuid references auth.users(id) on delete set null,
  payment_id uuid references public.payments(id) on delete set null,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_id, absence_date)
);

create index if not exists absence_fines_pending_idx
  on public.absence_fines(company_id, status, absence_date desc);

alter table public.absence_fines enable row level security;
revoke all on public.absence_fines from anon, authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'absence-explanations',
  'absence-explanations',
  false,
  20971520,
  array['application/pdf','image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update
set file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Путь: <employee_id>/<absence_fine_id>/<filename>
drop policy if exists absence_explanations_select_admin on storage.objects;
create policy absence_explanations_select_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'absence-explanations'
  and public.is_admin()
  and exists (
    select 1
    from public.absence_fines fine
    where fine.company_id = public.current_user_company_id()
      and fine.employee_id::text = (storage.foldername(objects.name))[1]
      and fine.id::text = (storage.foldername(objects.name))[2]
  )
);

drop policy if exists absence_explanations_insert_admin on storage.objects;
create policy absence_explanations_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'absence-explanations'
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

drop policy if exists absence_explanations_delete_admin on storage.objects;
create policy absence_explanations_delete_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'absence-explanations'
  and public.is_admin()
  and exists (
    select 1
    from public.absence_fines fine
    where fine.company_id = public.current_user_company_id()
      and fine.employee_id::text = (storage.foldername(objects.name))[1]
      and fine.id::text = (storage.foldername(objects.name))[2]
  )
);

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
    select 1 from public.attendance a
    where a.company_id = p_company_id
      and a.employee_id = p_employee_id
      and a.work_date = p_work_date
      and a.deleted_at is null
      and lower(btrim(coalesce(a.status,''))) = 'no_show'
      and coalesce(a.shifts,0) = 0
  ) into v_has_no_show;

  select exists (
    select 1 from public.attendance a
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

create or replace function private.sync_absence_fine_from_attendance()
returns trigger
language plpgsql
security definer
set search_path to 'public','private','pg_temp'
as $$
declare
  v_company_id uuid;
  v_employee_id uuid;
  v_work_date date;
begin
  v_company_id := coalesce(new.company_id, old.company_id);
  v_employee_id := coalesce(new.employee_id, old.employee_id);
  v_work_date := coalesce(new.work_date, old.work_date);
  perform private.sync_absence_fine_for_day(v_company_id, v_employee_id, v_work_date);
  return coalesce(new, old);
end;
$$;

drop trigger if exists attendance_sync_absence_fine on public.attendance;
create trigger attendance_sync_absence_fine
after insert or update of status, shifts, deleted_at, work_date, employee_id or delete
on public.attendance
for each row execute function private.sync_absence_fine_from_attendance();

create or replace function public.get_pending_absence_fines()
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
    fine.created_at
  from public.absence_fines fine
  join public.employees employee
    on employee.id = fine.employee_id and employee.company_id = fine.company_id
  where auth.uid() is not null
    and public.is_admin()
    and fine.company_id = public.current_user_company_id()
    and fine.status = 'pending'
  order by fine.absence_date desc, employee.fio;
$$;

create or replace function public.attach_absence_fine_explanation(
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
    raise exception 'Не указан файл объяснительной';
  end if;

  if not exists (
    select 1 from storage.objects object_row
    join public.absence_fines fine on fine.id = p_fine_id
    where object_row.bucket_id = 'absence-explanations'
      and object_row.name = p_file_path
      and fine.company_id = v_company_id
      and fine.status = 'pending'
  ) then
    raise exception 'Файл объяснительной не найден в хранилище';
  end if;

  update public.absence_fines
  set explanation_file_name = left(btrim(coalesce(p_file_name,'')), 300),
      explanation_file_path = btrim(p_file_path),
      explanation_content_type = left(btrim(coalesce(p_content_type,'')), 120),
      explanation_uploaded_at = now(),
      explanation_uploaded_by = auth.uid(),
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
  where id = p_fine_id and company_id = v_company_id
  for update;

  if not found then raise exception 'Штраф не найден'; end if;
  if v_fine.status = 'confirmed' and v_fine.payment_id is not null then
    return v_fine.payment_id;
  end if;
  if v_fine.status <> 'pending' then raise exception 'Штраф нельзя подтвердить'; end if;
  if btrim(coalesce(v_fine.explanation_file_path,'')) = '' then
    raise exception 'Сначала прикрепите скан объяснительной';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'absence-explanations'
      and name = v_fine.explanation_file_path
  ) then
    raise exception 'Скан объяснительной не найден';
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
    format('Штраф за невыход %s. Объяснительная приложена.', to_char(v_fine.absence_date,'DD.MM.YYYY')),
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

revoke all on function public.get_pending_absence_fines() from public;
revoke all on function public.attach_absence_fine_explanation(uuid,text,text,text) from public;
revoke all on function public.confirm_absence_fine(uuid) from public;
grant execute on function public.get_pending_absence_fines() to authenticated;
grant execute on function public.attach_absence_fine_explanation(uuid,text,text,text) to authenticated;
grant execute on function public.confirm_absence_fine(uuid) to authenticated;
