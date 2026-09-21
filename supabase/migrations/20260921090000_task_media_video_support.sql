alter table public.task_photos
  add column if not exists media_type text not null default 'photo',
  add column if not exists content_type text,
  add column if not exists duration_seconds integer,
  add column if not exists size_bytes bigint;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'task_photos_media_type_check'
      and conrelid = 'public.task_photos'::regclass
  ) then
    alter table public.task_photos
      add constraint task_photos_media_type_check
      check (media_type in ('photo', 'video'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'task_photos_duration_seconds_check'
      and conrelid = 'public.task_photos'::regclass
  ) then
    alter table public.task_photos
      add constraint task_photos_duration_seconds_check
      check (duration_seconds is null or (duration_seconds >= 0 and duration_seconds <= 60));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'task_photos_size_bytes_check'
      and conrelid = 'public.task_photos'::regclass
  ) then
    alter table public.task_photos
      add constraint task_photos_size_bytes_check
      check (size_bytes is null or size_bytes >= 0);
  end if;
end
$$;

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
  'video/quicktime',
  'video/webm'
]::text[]
where id = 'task-photos';
