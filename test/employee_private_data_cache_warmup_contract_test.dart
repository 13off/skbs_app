import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/data/employee_private_data_repository.dart',
  ).readAsStringSync();

  group('EmployeePrivateDataRepository cache warmup contract', () {
    test('bulk employee lookup passes the requested identifiers', () {
      expect(source, contains('requestedEmployeeIds: ids'));
    });

    test('fresh bulk result warms individual employee cache entries', () {
      expect(source, contains('_warmEmployeeCache'));
      expect(source, contains('_employeeCache[employeeId] ='));
      expect(source, contains('value: values[employeeId]'));
    });

    test('missing private data is cached for the requested employee', () {
      expect(
        source,
        contains(
          '_employeeCache[employeeId] = _PrivateDataEntry(\n'
          '          value: values[employeeId],',
        ),
      );
    });

    test('bulk and individual entries use the same creation time', () {
      expect(source, contains('final createdAt = DateTime.now()'));
      expect(source, contains('createdAt: createdAt'));
    });

    test('upsert still invalidates every private-data cache', () {
      final upsertMethod = RegExp(
        r'static Future<void> upsert\(EmployeePrivateData data\) async \{([\s\S]*?)\n  \}',
      ).firstMatch(source)?.group(1);

      expect(upsertMethod, isNotNull);
      expect(upsertMethod, contains('clearCache()'));
    });
  });
}
