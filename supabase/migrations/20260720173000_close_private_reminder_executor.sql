-- Функция вызывается только закрытым серверным агрегатором
-- private.populate_role_operational_reminders(). У клиентов нет USAGE на
-- схему private, но явные EXECUTE-права также не нужны.
revoke all on function private.populate_developer_custom_reminders()
  from public, anon, authenticated;
