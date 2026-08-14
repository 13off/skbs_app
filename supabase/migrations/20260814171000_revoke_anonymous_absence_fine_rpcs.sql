do $$
begin
  if to_regprocedure(
    'public.attach_absence_fine_explanation(uuid,text,text,text)'
  ) is not null then
    execute 'revoke execute on function '
      'public.attach_absence_fine_explanation(uuid,text,text,text) from anon';
  end if;

  if to_regprocedure(
    'public.can_access_absence_fine_storage(text,text,boolean)'
  ) is not null then
    execute 'revoke execute on function '
      'public.can_access_absence_fine_storage(text,text,boolean) from anon';
  end if;
end;
$$;

comment on function public.can_access_absence_fine_storage(text,text,boolean) is
  'Проверяет доступ авторизованного пользователя к файлам штрафа за отсутствие.';
