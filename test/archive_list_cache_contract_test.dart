import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archived employees use ttl cache and in-flight dedupe', () {
    final source = File(
      'lib/data/employee_archive_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_cacheTtl = Duration(seconds: 30)'));
    expect(source, contains('_cachedEmployees'));
    expect(source, contains('_inFlight'));
    expect(source, contains('if (running != null)'));
    expect(source, contains('if (!forceRefresh && _isCacheFresh)'));
    expect(source, contains('return _copyEmployees'));
  });

  test('archived employee ids reuse the archived employee list', () {
    final source = File(
      'lib/data/employee_archive_repository.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'static Future<Set<String>> fetchArchivedEmployeeIds',
    );
    final end = source.indexOf('static Future<void> archiveEmployee', start);
    final method = source.substring(start, end);

    expect(method, contains('fetchArchivedEmployees('));
    expect(method, isNot(contains(".from('employees')")));
  });

  test('archived objects use the existing object cache lifecycle', () {
    final source = File('lib/data/object_repository.dart').readAsStringSync();

    expect(source, contains('_cachedArchivedObjectNames'));
    expect(source, contains('_cachedArchivedObjectsAt'));
    expect(source, contains('_archivedObjectsInFlight'));
    expect(source, contains('_loadArchivedObjectNames()'));
    expect(
      source,
      contains('DateTime.now().difference(cachedAt) < _objectsCacheTtl'),
    );
    expect(source, contains('_cachedArchivedObjectNames = null;'));
  });

  test('archive mutations and permanent deletion invalidate caches', () {
    final employees = File(
      'lib/data/employee_archive_repository.dart',
    ).readAsStringSync();
    final permanent = File(
      'lib/data/permanent_deletion_repository.dart',
    ).readAsStringSync();

    final archive = employees.substring(
      employees.indexOf('static Future<void> archiveEmployee'),
      employees.indexOf('static Future<void> restoreEmployee'),
    );
    final restore = employees.substring(
      employees.indexOf('static Future<void> restoreEmployee'),
    );
    expect(archive, contains('clearCache();'));
    expect(restore, contains('clearCache();'));
    expect(permanent, contains('EmployeeArchiveRepository.clearCache();'));
    expect(permanent, contains('ObjectRepository.clearCache();'));
  });
}
