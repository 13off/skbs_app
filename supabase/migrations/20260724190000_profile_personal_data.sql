alter table public.user_profiles
  add column if not exists phone text not null default '',
  add column if not exists avatar_path text not null default '';

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile avatars select own" on storage.objects;
drop policy if exists "profile avatars insert own" on storage.objects;
drop policy if exists "profile avatars update own" on storage.objects;
drop policy if exists "profile avatars delete own" on storage.objects;

create policy "profile avatars select own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile avatars insert own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile avatars update own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "profile avatars delete own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create or replace function public.update_current_user_profile(
  p_full_name text,
  p_phone text,
  p_avatar_path text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  v_user_id uuid := auth.uid();
  v_full_name text := btrim(coalesce(p_full_name, ''));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_avatar_path text := btrim(coalesce(p_avatar_path, ''));
begin
  if v_user_id is null then
    raise exception 'Пользователь не авторизован';
  end if;

  if char_length(v_full_name) < 2 then
    raise exception 'Укажите ФИО';
  end if;

  if char_length(v_full_name) > 160 then
    raise exception 'ФИО слишком длинное';
  end if;

  if char_length(v_phone) > 40 then
    raise exception 'Номер телефона слишком длинный';
  end if;

  if v_avatar_path <> ''
     and v_avatar_path not like v_user_id::text || '/%' then
    raise exception 'Недопустимый путь фотографии';
  end if;

  update public.user_profiles
  set
    full_name = v_full_name,
    phone = v_phone,
    avatar_path = v_avatar_path
  where id = v_user_id;

  if not found then
    raise exception 'Профиль пользователя не найден';
  end if;
end;
$$;

revoke all on function public.update_current_user_profile(text, text, text)
from public, anon;
grant execute on function public.update_current_user_profile(text, text, text)
to authenticated;
