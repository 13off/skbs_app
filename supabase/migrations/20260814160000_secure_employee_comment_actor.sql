alter table public.employee_comments
  add column if not exists created_by_user_id uuid
  references auth.users(id) on delete set null;

create index if not exists employee_comments_created_by_user_id_idx
  on public.employee_comments(created_by_user_id);

create or replace function private.set_employee_comment_actor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_actor_name text;
begin
  if tg_op = 'UPDATE' then
    new.created_by_user_id := old.created_by_user_id;
    new.created_by := old.created_by;
    return new;
  end if;

  if v_user_id is null then
    raise exception 'Пользователь не авторизован';
  end if;

  select nullif(btrim(up.full_name), '')
    into v_actor_name
  from public.user_profiles up
  where up.id = v_user_id;

  v_actor_name := coalesce(
    v_actor_name,
    nullif(btrim(coalesce(auth.jwt() ->> 'email', '')), ''),
    'Пользователь'
  );

  new.created_by_user_id := v_user_id;
  new.created_by := v_actor_name;
  return new;
end;
$$;

revoke all on function private.set_employee_comment_actor() from public;
revoke all on function private.set_employee_comment_actor() from anon;
revoke all on function private.set_employee_comment_actor() from authenticated;

drop trigger if exists set_employee_comment_actor_before_write
  on public.employee_comments;

create trigger set_employee_comment_actor_before_write
before insert or update of created_by, created_by_user_id
on public.employee_comments
for each row
execute function private.set_employee_comment_actor();

comment on column public.employee_comments.created_by_user_id is
  'Автор комментария, установленный сервером из auth.uid().';

comment on function private.set_employee_comment_actor() is
  'Серверно устанавливает автора комментария и запрещает его подмену при обновлении.';
