create table if not exists public.accounting_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  name text not null default 'Основной счёт',
  balance numeric(18,2) not null default 0,
  balance_updated_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists accounting_bank_accounts_company_name_uidx
  on public.accounting_bank_accounts(company_id, lower(name));

create table if not exists public.accounting_nomenclature (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null default public.current_user_company_id() references public.companies(id) on delete cascade,
  name text not null,
  kind text not null default 'service' check (kind in ('service','material','goods','other')),
  unit text not null default '',
  vat_rate numeric(5,2),
  comment text not null default '',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists accounting_nomenclature_company_name_idx
  on public.accounting_nomenclature(company_id, name);

alter table public.accounting_bank_accounts enable row level security;
alter table public.accounting_nomenclature enable row level security;

do $$
declare t text;
begin
  foreach t in array array['accounting_bank_accounts','accounting_nomenclature'] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format('create policy %I_read on public.%I for select using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))', t, t);
    execute format('drop policy if exists %I_insert on public.%I', t, t);
    execute format('create policy %I_insert on public.%I for insert with check (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))', t, t);
    execute format('drop policy if exists %I_update on public.%I', t, t);
    execute format('create policy %I_update on public.%I for update using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text])) with check (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))', t, t);
    execute format('drop policy if exists %I_delete on public.%I', t, t);
    execute format('create policy %I_delete on public.%I for delete using (company_id = public.current_user_company_id() and public.current_user_role() = any (array[''admin''::text,''developer''::text,''accountant''::text]))', t, t);
  end loop;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'accounting-documents',
  'accounting-documents',
  false,
  20971520,
  array['application/pdf','image/jpeg','image/png','image/webp','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-excel','text/csv']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists accounting_documents_storage_select on storage.objects;
create policy accounting_documents_storage_select on storage.objects
for select using (
  bucket_id = 'accounting-documents'
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  and (storage.foldername(name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.accounting_primary_documents d
    where d.company_id = public.current_user_company_id()
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);

drop policy if exists accounting_documents_storage_insert on storage.objects;
create policy accounting_documents_storage_insert on storage.objects
for insert with check (
  bucket_id = 'accounting-documents'
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  and (storage.foldername(name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.accounting_primary_documents d
    where d.company_id = public.current_user_company_id()
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);

drop policy if exists accounting_documents_storage_delete on storage.objects;
create policy accounting_documents_storage_delete on storage.objects
for delete using (
  bucket_id = 'accounting-documents'
  and public.current_user_role() = any (array['admin'::text,'developer'::text,'accountant'::text])
  and (storage.foldername(name))[1] = public.current_user_company_id()::text
  and exists (
    select 1 from public.accounting_primary_documents d
    where d.company_id = public.current_user_company_id()
      and d.id::text = (storage.foldername(storage.objects.name))[2]
  )
);
