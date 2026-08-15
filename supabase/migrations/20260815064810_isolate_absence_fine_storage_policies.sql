drop policy if exists absence_fine_acts_insert_admin on storage.objects;
create policy absence_fine_acts_insert_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'absence-fine-acts'
  and public.can_access_absence_fine_storage(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    true
  )
);

drop policy if exists absence_fine_acts_select_admin on storage.objects;
create policy absence_fine_acts_select_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'absence-fine-acts'
  and public.can_access_absence_fine_storage(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    false
  )
);

drop policy if exists absence_fine_acts_delete_admin on storage.objects;
create policy absence_fine_acts_delete_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'absence-fine-acts'
  and public.can_access_absence_fine_storage(
    (storage.foldername(name))[1],
    (storage.foldername(name))[2],
    false
  )
);
