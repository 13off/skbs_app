-- Runtime rules for AppСтрой Документооборот v3.

insert into storage.buckets (id, name, public, file_size_limit)
values ('employee-documents', 'employee-documents', false, 31457280)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit;

create or replace function public.document_onboarding_blockers(p_onboarding_id uuid)
returns table(code text, message text)
language sql
security definer
set search_path = public
as $$
  with process as (
    select id, company_id
    from public.employee_onboardings
    where id = p_onboarding_id
  ), required_steps as (
    select step_code
    from public.employee_onboarding_steps s
    join process p on p.id = s.onboarding_id
    where s.is_required and s.status <> 'completed'
  ), required_signed as (
    select count(*)::integer as amount
    from public.employee_document_files f
    join process p on p.id = f.onboarding_id
    where f.file_kind = 'signed'
      and f.verification_status = 'accepted'
  ), required_scans as (
    select count(*)::integer as amount
    from public.employee_document_files f
    join process p on p.id = f.onboarding_id
    where f.file_kind = 'final_scan'
      and f.verification_status = 'accepted'
  )
  select 'step:' || step_code, 'Не завершён обязательный этап: ' || step_code
  from required_steps
  union all
  select 'signed_documents', 'Нет проверенного подписанного документа'
  from required_signed where amount = 0
  union all
  select 'final_scans', 'Нет проверенного финального скана'
  from required_scans where amount = 0;
$$;

revoke all on function public.document_onboarding_blockers(uuid) from public, anon;
grant execute on function public.document_onboarding_blockers(uuid) to authenticated;

create or replace function public.seed_default_document_packages(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.document_packages
    (company_id, code, title, description, onboarding_type, is_active, created_by)
  values
    (p_company_id, 'employment', 'Приём по трудовому договору', 'Трудовой договор, заявления, согласие и анкета', 'employment', true, auth.uid()),
    (p_company_id, 'gph', 'Оформление по ГПХ', 'Договор ГПХ/оказания услуг, согласие, заявление и анкета исполнителя', 'gph', true, auth.uid()),
    (p_company_id, 'transfer', 'Перевод или изменение условий', 'Дополнительное соглашение, заявление и уведомление', 'transfer', true, auth.uid())
  on conflict (company_id, code) do nothing;
end;
$$;

revoke all on function public.seed_default_document_packages(uuid) from public, anon;
grant execute on function public.seed_default_document_packages(uuid) to authenticated;

create or replace function public.touch_document_workflow_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'document_tool_installations_touch') then
    create trigger document_tool_installations_touch
    before update on public.document_tool_installations
    for each row execute function public.touch_document_workflow_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'document_packages_touch') then
    create trigger document_packages_touch
    before update on public.document_packages
    for each row execute function public.touch_document_workflow_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'employee_onboardings_touch') then
    create trigger employee_onboardings_touch
    before update on public.employee_onboardings
    for each row execute function public.touch_document_workflow_updated_at();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'employee_onboarding_steps_touch') then
    create trigger employee_onboarding_steps_touch
    before update on public.employee_onboarding_steps
    for each row execute function public.touch_document_workflow_updated_at();
  end if;
end $$;

-- Storage policies rely on company id being the first path segment.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'employee_documents_read') then
    create policy employee_documents_read on storage.objects
      for select to authenticated
      using (
        bucket_id = 'employee-documents'
        and exists (
          select 1 from public.company_members cm
          where cm.company_id::text = (storage.foldername(name))[1]
            and cm.user_id = auth.uid()
        )
      );
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'employee_documents_write') then
    create policy employee_documents_write on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'employee-documents'
        and exists (
          select 1 from public.company_members cm
          where cm.company_id::text = (storage.foldername(name))[1]
            and cm.user_id = auth.uid()
        )
      );
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'employee_documents_update') then
    create policy employee_documents_update on storage.objects
      for update to authenticated
      using (
        bucket_id = 'employee-documents'
        and exists (
          select 1 from public.company_members cm
          where cm.company_id::text = (storage.foldername(name))[1]
            and cm.user_id = auth.uid()
        )
      );
  end if;
end $$;
