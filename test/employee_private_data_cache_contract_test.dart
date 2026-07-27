import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single private-data reads use ttl and in-flight dedupe', () {
    final source = File(
      'lib/data/employee_private_data_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_cacheTtl = Duration(seconds: 25)'));
    expect(source, contains('_employeeCache'));
    expect(source, contains('_employeeRequests'));
    expect(source, contains('if (running != null) return running;'));
    expect(source, contains('if (!forceRefresh && cached != null'));
  });

  test('bulk private-data reads use keyed cache and parallel chunks', () {
    final source = File(
      'lib/data/employee_private_data_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_mapCache'));
    expect(source, contains('_mapRequests'));
    expect(source, contains('ids.join(\'|\')'));
    expect(source, contains('final requests = <Future<List<dynamic>>>[];'));
    expect(source, contains('Future.wait<List<dynamic>>(requests)'));
    expect(source, contains(".inFilter('employee_id', chunk)"));
  });

  test('private-data caches cannot leak mutable maps', () {
    final source = File(
      'lib/data/employee_private_data_repository.dart',
    ).readAsStringSync();

    expect(source, contains('Map<String, EmployeePrivateData>.from(value)'));
    expect(source, contains('return _copyMap(cached.value)'));
    expect(source, contains('return _copyMap(result)'));
  });

  test('saving private data invalidates every cache', () {
    final source = File(
      'lib/data/employee_private_data_repository.dart',
    ).readAsStringSync();
    final upsert = source.substring(source.indexOf('static Future<void> upsert'));

    expect(upsert, contains(".upsert(data.toSupabaseMap(), onConflict: 'employee_id')"));
    expect(upsert, contains('clearCache();'));
    expect(source, contains('_employeeCache.clear();'));
    expect(source, contains('_employeeRequests.clear();'));
    expect(source, contains('_mapCache.clear();'));
    expect(source, contains('_mapRequests.clear();'));
  });
}
