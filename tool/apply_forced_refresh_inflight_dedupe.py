from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} occurrences, found {count}')
    file_path.write_text(text.replace(old, new), encoding='utf-8')


replace_exact(
    'lib/data/employee_repository.dart',
    'if (!forceRefresh && runningRequest != null)',
    'if (runningRequest != null)',
    2,
)
replace_exact(
    'lib/data/object_repository.dart',
    'if (!forceRefresh && runningRequest != null)',
    'if (runningRequest != null)',
    1,
)
replace_exact(
    'lib/data/attendance_repository.dart',
    '''if (!forceRefresh) {
      final running = _shiftValueRequests[key];
      if (running != null) return _copyShiftValues(await running);
    }''',
    '''final running = _shiftValueRequests[key];
    if (running != null) return _copyShiftValues(await running);''',
    1,
)
replace_exact(
    'lib/data/attendance_repository.dart',
    '''if (!forceRefresh) {
      final running = _attendanceReportRequests[key];
      if (running != null) return _copyReportRows(await running);
    }''',
    '''final running = _attendanceReportRequests[key];
    if (running != null) return _copyReportRows(await running);''',
    1,
)
replace_exact(
    'lib/data/attendance_repository.dart',
    '''if (!forceRefresh) {
      final running = _monthlyTimesheetRequests[key];
      if (running != null) return _copyMonthlyRows(await running);
    }''',
    '''final running = _monthlyTimesheetRequests[key];
    if (running != null) return _copyMonthlyRows(await running);''',
    1,
)
replace_exact(
    'lib/data/attendance_repository.dart',
    '''if (!forceRefresh) {
      final running = _employeeMonthlyTimesheetRequests[key];
      if (running != null) return running;
    }''',
    '''final running = _employeeMonthlyTimesheetRequests[key];
    if (running != null) return running;''',
    1,
)
replace_exact(
    'lib/data/attendance_repository.dart',
    '''if (!forceRefresh) {
      final running = _periodTimesheetRequests[key];
      if (running != null) return _copyPeriodRows(await running);
    }''',
    '''final running = _periodTimesheetRequests[key];
    if (running != null) return _copyPeriodRows(await running);''',
    1,
)
replace_exact(
    'lib/data/payment_repository.dart',
    '''if (!forceRefresh) {
      final running = _employeePaymentRequests[key];
      if (running != null) return _copyPayments(await running);
    }''',
    '''final running = _employeePaymentRequests[key];
    if (running != null) return _copyPayments(await running);''',
    1,
)
replace_exact(
    'lib/data/payment_repository.dart',
    '''if (!forceRefresh) {
      final running = _bulkPaymentRequests[key];
      if (running != null) return _copyPayments(await running);
    }''',
    '''final running = _bulkPaymentRequests[key];
    if (running != null) return _copyPayments(await running);''',
    1,
)
replace_exact(
    'lib/data/finance_summary_repository.dart',
    '''    if (forceRefresh) {
      _inFlight.remove(key);
    }

''',
    '',
    1,
)
