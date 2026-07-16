create or replace function public.current_operational_date()
returns date
language sql
stable
set search_path = public, pg_temp
as $$
  select (now() at time zone 'Europe/Moscow')::date;
$$;

create or replace function public.task_is_mutable_for_user(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.tasks t
    where t.id = p_task_id
      and t.company_id = public.current_user_company_id()
      and public.can_access_object(t.object_name)
      and public.is_active_object(t.object_name)
      and (
        public.is_admin()
        or (
          public.is_foreman()
          and t.task_date = public.current_operational_date()
        )
      )
  );
$$;

revoke all on function public.current_operational_date() from public, anon;
revoke all on function public.task_is_mutable_for_user(uuid) from public, anon;
grant execute on function public.current_operational_date() to authenticated, service_role;
grant execute on function public.task_is_mutable_for_user(uuid) to authenticated, service_role;

drop policy if exists tasks_insert_company_object on public.tasks;
create policy tasks_insert_company_object
on public.tasks
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    public.is_admin()
    or (
      public.is_foreman()
      and task_date = public.current_operational_date()
    )
  )
);

drop policy if exists tasks_update_company_object on public.tasks;
create policy tasks_update_company_object
on public.tasks
for update
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    public.is_admin()
    or (
      public.is_foreman()
      and task_date = public.current_operational_date()
    )
  )
)
with check (
  company_id = (select public.current_user_company_id())
  and public.can_access_object(object_name)
  and public.is_active_object(object_name)
  and (
    public.is_admin()
    or (
      public.is_foreman()
      and task_date = public.current_operational_date()
    )
  )
);

drop policy if exists task_assignees_delete_company_task on public.task_assignees;
create policy task_assignees_delete_company_task
on public.task_assignees
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_mutable_for_user(task_id)
);

drop policy if exists task_assignees_insert_company_task on public.task_assignees;
create policy task_assignees_insert_company_task
on public.task_assignees
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.task_is_mutable_for_user(task_id)
  and exists (
    select 1
    from public.tasks t
    join public.employees e
      on e.id = task_assignees.employee_id
     and e.company_id = t.company_id
     and lower(btrim(e.object_name)) = lower(btrim(t.object_name))
    where t.id = task_assignees.task_id
      and t.company_id = task_assignees.company_id
  )
);

drop policy if exists task_photos_delete_company_task on public.task_photos;
create policy task_photos_delete_company_task
on public.task_photos
for delete
to authenticated
using (
  company_id = (select public.current_user_company_id())
  and public.task_is_mutable_for_user(task_id)
);

drop policy if exists task_photos_insert_company_task on public.task_photos;
create policy task_photos_insert_company_task
on public.task_photos
for insert
to authenticated
with check (
  company_id = (select public.current_user_company_id())
  and public.task_is_mutable_for_user(task_id)
);

drop policy if exists task_photos_storage_delete_company_task on storage.objects;
create policy task_photos_storage_delete_company_task
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'task-photos'
  and exists (
    select 1
    from public.tasks t
    where t.company_id = public.current_user_company_id()
      and t.id::text = (storage.foldername(storage.objects.name))[1]
      and public.task_is_mutable_for_user(t.id)
  )
);

drop policy if exists task_photos_storage_insert_company_task on storage.objects;
create policy task_photos_storage_insert_company_task
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'task-photos'
  and exists (
    select 1
    from public.tasks t
    where t.company_id = public.current_user_company_id()
      and t.id::text = (storage.foldername(storage.objects.name))[1]
      and public.task_is_mutable_for_user(t.id)
  )
);
