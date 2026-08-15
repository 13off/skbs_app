-- AppСтрой: решение руководителя по штрафам за невыход в разделе «Выплаты».
--
-- Подтверждение уже создаёт выплату типа fine только после приложенных документов.
-- Эта миграция добавляет второе решение — отмену без финансового движения —
-- и защищает вручную отменённый штраф от повторного автоматического открытия.

alter table public.absence_fines
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by uuid references auth.users(id) on delete set null;

create index if not exists absence_fines_company_status_idx
  on public.absence_fines(company_id, status, absence_date desc);

-- Автоматическая синхронизация табеля раньше могла вернуть любой cancelled-штраф
-- обратно в pending через upsert. Если решение об отмене принял человек,
-- это решение должно сохраняться. Автоматические отмены имеют cancelled_by = null
-- и по-прежнему могут быть переоткрыты синхронизацией, если источник изменился.
create or replace function private.protect_manual_absence_fine_cancellation()
returns trigger
language plpgsql
set search_path = public, private, pg_temp
as $$
begin
  if old.status = 'cancelled'
     and old.cancelled_by is not null
     and new.status = 'pending' then
    new.status := 'cancelled';
    new.cancelled_at := old.cancelled_at;
    new.cancelled_by := old.cancelled_by;
  end if;

  return new;
end;
$$;

drop trigger if exists absence_fines_protect_manual_cancellation
  on public.absence_fines;
create trigger absence_fines_protect_manual_cancellation
before update on public.absence_fines
for each row
execute function private.protect_manual_absence_fine_cancellation();

create or replace function public.cancel_absence_fine(p_fine_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_fine public.absence_fines%rowtype;
begin
  if auth.uid() is null or v_company_id is null or not public.is_admin() then
    raise exception 'Недостаточно прав';
  end if;

  select *
    into v_fine
  from public.absence_fines
  where id = p_fine_id
    and company_id = v_company_id
  for update;

  if not found then
    raise exception 'Штраф не найден';
  end if;

  -- Повторный запрос безопасен и не создаёт никаких финансовых записей.
  if v_fine.status = 'cancelled' then
    return true;
  end if;

  if v_fine.status <> 'pending' then
    raise exception 'Штраф нельзя отменить';
  end if;

  if v_fine.payment_id is not null then
    raise exception 'Нельзя отменить штраф, уже связанный с выплатой';
  end if;

  update public.absence_fines
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = auth.uid(),
      updated_at = now()
  where id = v_fine.id
    and company_id = v_company_id
    and status = 'pending';

  if not found then
    raise exception 'Штраф уже изменён другим пользователем';
  end if;

  return true;
end;
$$;

revoke all on function public.cancel_absence_fine(uuid) from public;
revoke all on function public.cancel_absence_fine(uuid) from anon;
grant execute on function public.cancel_absence_fine(uuid) to authenticated;

comment on function public.cancel_absence_fine(uuid) is
  'Руководитель отменяет pending-штраф за невыход без создания записи в payments.';
