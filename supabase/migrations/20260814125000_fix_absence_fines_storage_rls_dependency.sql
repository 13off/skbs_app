-- Исправление: политики Storage для объяснительных штрафов не должны
-- напрямую читать public.absence_fines от имени authenticated.
-- Таблица штрафов остаётся закрытой, проверка выполняется через SECURITY DEFINER.

create or replace function public.can_access_absence_fine_storage(
  p_employee_id text,
  p_fine_id text,
  p_require_pending boolean default false
)
returns boolean
language sql
stable
security definer
set search_path to 'public','pg_temp'
as $$
  select
    auth.uid() is not null
    and public.is_admin()
    and public.current_user_company_id() is not null
    and exists (
      select 1
      from public.absence_fines fine
      where fine.company_id = public.current_user_company_id()
        and fine.employee_id::text = btrim(coalesce(p_employee_id, ''))
        and fine.id::text = btrim(coalesce(p_fine_id, ''))
        and (not p_require_pending or fine.status = 'pending')
    );
$$;

revoke all on function public.can_access_absence_fine_storage(text,text,boolean) from public;
grant execute on function public.can_access_absence_fine_storage(text,text,boolean) to authenticated;

drop policy if exists absence_explanations_select_admin on storage.objects;
create policy absence_explanations_select_admin
on storage.objects for select to authenticated
using (
  bucket_id = 'absence-explanations'
  and public.can_access_absence_fine_storage(
    (storage.foldername(objects.name))[1],
    (storage.foldername(objects.name))[2],
    false
  )
);

drop policy if exists absence_explanations_insert_admin on storage.objects;
create policy absence_explanations_insert_admin
on storage.objects for insert to authenticated
with check (
  bucket_id = 'absence-explanations'
  and public.can_access_absence_fine_storage(
    (storage.foldername(objects.name))[1],
    (storage.foldername(objects.name))[2],
    true
  )
);

drop policy if exists absence_explanations_delete_admin on storage.objects;
create policy absence_explanations_delete_admin
on storage.objects for delete to authenticated
using (
  bucket_id = 'absence-explanations'
  and public.can_access_absence_fine_storage(
    (storage.foldername(objects.name))[1],
    (storage.foldername(objects.name))[2],
    false
  )
);
