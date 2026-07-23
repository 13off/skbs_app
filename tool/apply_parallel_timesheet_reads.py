from pathlib import Path

path = Path('lib/data/attendance_repository.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    '''    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final employeesById = <String, Employee>{};

    for (final employee in employees) {
      if (employee.id != null) {
        employeesById[employee.id!] = employee;
      }
    }

    final rows = await _fetchAttendanceRows(
      startDate: startDate,
      endDate: endDate,
      objectName: cleanObject,
      workedOnly: true,
    );''',
    '''    final data = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: cleanObject,
        includeFired: includeFired,
      ),
      _fetchAttendanceRows(
        startDate: startDate,
        endDate: endDate,
        objectName: cleanObject,
        workedOnly: true,
      ),
    ]);
    final employees = data[0] as List<Employee>;
    final rows = data[1] as List<Map<String, dynamic>>;

    final employeesById = <String, Employee>{};

    for (final employee in employees) {
      if (employee.id != null) {
        employeesById[employee.id!] = employee;
      }
    }''',
    'attendance report',
)

replace_once(
    '''    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month + 1, 0);

    final attendanceRows = await _fetchAttendanceRows(
      startDate: firstDate,
      endDate: lastDate,
      objectName: cleanObject,
    );''',
    '''    final firstDate = DateTime(year, month, 1);
    final lastDate = DateTime(year, month + 1, 0);
    final data = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: cleanObject,
        includeFired: includeFired,
      ),
      _fetchAttendanceRows(
        startDate: firstDate,
        endDate: lastDate,
        objectName: cleanObject,
      ),
      _client
          .from('payments')
          .select('employee_id, amount')
          .eq('period_year', year)
          .eq('period_month', month),
    ]);
    final employees = data[0] as List<Employee>;
    final attendanceRows = data[1] as List<Map<String, dynamic>>;
    final paymentRows = data[2] as List<dynamic>;''',
    'monthly timesheet reads',
)

replace_once(
    '''    final paymentRows = await _client
        .from('payments')
        .select('employee_id, amount')
        .eq('period_year', year)
        .eq('period_month', month);

''',
    '',
    'monthly timesheet serial payments',
)

replace_once(
    '''    final attendanceRows = await _fetchAttendanceRows(
      startDate: firstDate,
      endDate: lastDate,
      employeeIds: <String>[employeeId],
    );''',
    '''    final data = await Future.wait<dynamic>([
      _fetchAttendanceRows(
        startDate: firstDate,
        endDate: lastDate,
        employeeIds: <String>[employeeId],
      ),
      _client
          .from('payments')
          .select('amount')
          .eq('period_year', year)
          .eq('period_month', month)
          .eq('employee_id', employeeId),
    ]);
    final attendanceRows = data[0] as List<Map<String, dynamic>>;
    final paymentRows = data[1] as List<dynamic>;''',
    'employee monthly reads',
)

replace_once(
    '''    final paymentRows = await _client
        .from('payments')
        .select('amount')
        .eq('period_year', year)
        .eq('period_month', month)
        .eq('employee_id', employeeId);

''',
    '',
    'employee monthly serial payments',
)

replace_once(
    '''    final employees = await EmployeeRepository.fetchEmployees(
      objectName: cleanObject,
      includeFired: includeFired,
    );

    final rows = await _fetchAttendanceRows(
      startDate: startDate,
      endDate: endDate,
      objectName: cleanObject,
    );''',
    '''    final data = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: cleanObject,
        includeFired: includeFired,
      ),
      _fetchAttendanceRows(
        startDate: startDate,
        endDate: endDate,
        objectName: cleanObject,
      ),
    ]);
    final employees = data[0] as List<Employee>;
    final rows = data[1] as List<Map<String, dynamic>>;''',
    'period timesheet reads',
)

path.write_text(text, encoding='utf-8')
