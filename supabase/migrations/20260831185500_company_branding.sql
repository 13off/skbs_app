alter table public.companies
  add column if not exists logo_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'company-branding',
  'company-branding',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "company branding insert admins" on storage.objects;
create policy "company branding insert admins"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'company-branding'
  and public.is_company_admin(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "company branding update admins" on storage.objects;
create policy "company branding update admins"
on storage.objects for update
to authenticated
using (
  bucket_id = 'company-branding'
  and public.is_company_admin(((storage.foldername(name))[1])::uuid)
)
with check (
  bucket_id = 'company-branding'
  and public.is_company_admin(((storage.foldername(name))[1])::uuid)
);

drop policy if exists "company branding delete admins" on storage.objects;
create policy "company branding delete admins"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'company-branding'
  and public.is_company_admin(((storage.foldername(name))[1])::uuid)
);

comment on column public.companies.logo_path is 'Storage path of the company logo in the company-branding bucket.';
