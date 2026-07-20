create unique index if not exists employees_one_active_assignment_per_object_key
  on public.employees(company_id, person_id, object_id)
  where is_active and archived_at is null;

create or replace function private.sync_employee_personal_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.person_id is null then
    return new;
  end if;

  update private.people p
  set
    fio = coalesce(nullif(btrim(new.fio), ''), p.fio),
    phone = case
      when btrim(coalesce(new.phone, '')) <> '' then btrim(new.phone)
      else p.phone
    end,
    updated_at = now()
  where p.id = new.person_id;

  -- ФИО и непустой телефон относятся к человеку, а не к его назначению.
  -- Должность, ставка, статус и объект остаются независимыми для каждой карточки.
  update public.employees sibling
  set
    fio = new.fio,
    phone = case
      when btrim(coalesce(new.phone, '')) <> '' then new.phone
      else sibling.phone
    end,
    updated_at = now()
  where sibling.person_id = new.person_id
    and sibling.id <> new.id
    and (
      sibling.fio is distinct from new.fio
      or (
        btrim(coalesce(new.phone, '')) <> ''
        and sibling.phone is distinct from new.phone
      )
    );

  return new;
end;
$$;

revoke all on function private.sync_employee_personal_fields()
  from public, anon, authenticated;

drop trigger if exists employees_sync_personal_fields_after_write
  on public.employees;
create trigger employees_sync_personal_fields_after_write
after insert or update of fio, phone
on public.employees
for each row execute function private.sync_employee_personal_fields();
