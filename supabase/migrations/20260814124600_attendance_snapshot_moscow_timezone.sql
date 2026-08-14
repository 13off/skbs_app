-- current_date внутри снимка посещаемости должен совпадать с рабочим днём
-- приложения, который в AppСтрой считается по Europe/Moscow.
alter function private.manager_attendance_snapshot(uuid, uuid, date)
  set timezone = 'Europe/Moscow';
