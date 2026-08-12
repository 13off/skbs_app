revoke all on function public.get_expenses_center(date, date) from public;
revoke all on function public.get_expenses_center(date, date) from anon;
grant execute on function public.get_expenses_center(date, date) to authenticated;

comment on function public.get_expenses_center(date, date) is
  'Единая выдача расходов текущей компании. Доступ только для аутентифицированных пользователей; роль и компания дополнительно проверяются внутри RPC.';
