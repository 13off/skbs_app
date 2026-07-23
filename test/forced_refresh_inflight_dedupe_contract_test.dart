import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('employee and object forced refreshes reuse running requests', () {
    final employees = source('lib/data/employee_repository.dart');
    final objects = source('lib/data/object_repository.dart');

    expect(employees, contains('final runningRequest = _employeeRequests[cacheKey];'));
    expect(employees, contains('if (runningRequest != null)'));
    expect(employees, contains('final runningRequest = _objectNamesRequest;'));
    expect(
      employees,
      isNot(contains('if (!forceRefresh && runningRequest != null)')),
    );
    expect(objects, contains('final runningRequest = _objectsInFlight;'));
    expect(objects, contains('if (runningRequest != null)'));
  });

  test('attendance and payment wrappers deduplicate forced refreshes', () {
    final attendance = source('lib/data/attendance_repository.dart');
    final payments = source('lib/data/payment_repository.dart');

    for (final requestMap in <String>[
      '_shiftValueRequests',
      '_attendanceReportRequests',
      '_monthlyTimesheetRequests',
      '_employeeMonthlyTimesheetRequests',
      '_periodTimesheetRequests',
    ]) {
      expect(attendance, contains('final running = $requestMap[key];'));
    }
    expect(
      RegExp(r'if \(!forceRefresh\) \{\s+final running = _').allMatches(attendance),
      isEmpty,
    );
    expect(payments, contains('final running = _employeePaymentRequests[key];'));
    expect(payments, contains('final running = _bulkPaymentRequests[key];'));
    expect(
      RegExp(r'if \(!forceRefresh\) \{\s+final running = _').allMatches(payments),
      isEmpty,
    );
  });

  test('finance refresh never evicts a request that is still running', () {
    final finance = source('lib/data/finance_summary_repository.dart');

    expect(finance, contains('final running = _inFlight[key];'));
    expect(finance, contains('if (running != null) return running;'));
    expect(finance, isNot(contains('_inFlight.remove(key);\n    }')));
  });

  test('forced refresh still bypasses completed value caches', () {
    final employees = source('lib/data/employee_repository.dart');
    final objects = source('lib/data/object_repository.dart');
    final attendance = source('lib/data/attendance_repository.dart');
    final payments = source('lib/data/payment_repository.dart');

    expect(employees, contains('if (!forceRefresh && cached != null'));
    expect(objects, contains('if (!forceRefresh && _isObjectsCacheFresh)'));
    expect(attendance, contains('if (!forceRefresh &&'));
    expect(payments, contains('if (!forceRefresh &&'));
  });
}
