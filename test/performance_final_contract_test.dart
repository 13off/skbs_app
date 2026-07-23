import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('core lists use the optimized server read paths', () {
    expect(
      source('lib/data/employee_repository.dart'),
      contains("'get_employee_rows_fast'"),
    );
    expect(
      source('lib/data/attendance_repository.dart'),
      contains("'get_attendance_rows_fast'"),
    );
    expect(
      source('lib/data/task_repository.dart'),
      contains("'get_task_rows_fast'"),
    );
    expect(
      source('lib/data/payment_repository.dart'),
      contains("'get_payment_rows_fast'"),
    );
    expect(
      source('lib/data/finance_summary_repository.dart'),
      contains("'get_finance_summary_fast'"),
    );
  });

  test('notifications use the fast feed and cached unread check', () {
    final notifications = source('lib/data/notification_repository.dart');

    expect(notifications, contains("'get_notification_feed_fast'"));
    expect(notifications, contains("'has_unread_notifications'"));
    expect(notifications, contains('_unreadCacheTtl'));
    expect(notifications, contains('_unreadInFlight'));
    expect(notifications, contains("row['is_read'] == true"));
  });

  test('repeated and forced reads keep in-flight deduplication', () {
    final employees = source('lib/data/employee_repository.dart');
    final attendance = source('lib/data/attendance_repository.dart');
    final tasks = source('lib/data/task_repository.dart');
    final payments = source('lib/data/payment_repository.dart');
    final objects = source('lib/data/object_repository.dart');

    expect(employees, contains('_employeeRequests'));
    expect(attendance, contains('_periodTimesheetRequests'));
    expect(tasks, contains('final running = _taskRequests[cacheKey];'));
    expect(payments, contains('_bulkPaymentRequests'));
    expect(objects, contains('_objectsInFlight'));
  });

  test('timesheet reports read independent data concurrently', () {
    final attendance = source('lib/data/attendance_repository.dart');

    expect(
      RegExp(r'Future\.wait<dynamic>\(\[').allMatches(attendance).length,
      greaterThanOrEqualTo(4),
    );
    expect(attendance, contains('final paymentRows = data[2] as List<dynamic>;'));
  });

  test('private data and archives invalidate short-lived caches', () {
    final privateData = source(
      'lib/data/employee_private_data_repository.dart',
    );
    final employeeArchive = source(
      'lib/data/employee_archive_repository.dart',
    );
    final objects = source('lib/data/object_repository.dart');

    expect(privateData, contains('_cacheTtl = Duration(seconds: 25)'));
    expect(privateData, contains('Future.wait<List<dynamic>>(requests)'));
    expect(privateData, contains('clearCache();'));
    expect(employeeArchive, contains('_cacheTtl = Duration(seconds: 30)'));
    expect(employeeArchive, contains('clearCache();'));
    expect(objects, contains('_cachedArchivedObjectNames'));
  });

  test('dispatcher optimizations do not reintroduce expensive reads', () {
    final center = source(
      'supabase/migrations/20260723210000_optimize_dispatcher_summary_center.sql',
    );
    final timezone = source(
      'supabase/migrations/20260723230000_optimize_dispatcher_timezone_validation.sql',
    );

    expect(center, contains('select * into v_settings'));
    expect(center, contains('if not found then'));
    expect(center, isNot(contains('on conflict(company_id) do nothing')));
    expect(timezone, contains('pg_catalog.timezone(new.timezone, now())'));
    expect(timezone, isNot(contains('from pg_timezone_names')));
  });

  test('optimized RPCs remain explicitly authenticated', () {
    for (final path in <String>[
      'supabase/migrations/20260723180000_get_employee_rows_fast.sql',
      'supabase/migrations/20260723220000_get_task_rows_fast.sql',
      'supabase/migrations/20260723250000_get_finance_summary_fast.sql',
    ]) {
      final sql = source(path);
      expect(sql, contains('authentication required'));
      expect(sql, contains('current_user_company_id()'));
      expect(sql, contains('from public, anon'));
      expect(sql, contains('to authenticated'));
    }
  });
}
