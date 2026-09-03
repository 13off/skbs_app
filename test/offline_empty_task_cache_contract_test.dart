import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('пустой сохранённый список задач остаётся валидным offline-снимком', () {
    final source = File('lib/data/task_repository.dart').readAsStringSync();

    expect(
      source,
      contains('final cached = await OfflineSyncService.readSnapshot('),
    );
    expect(source, contains('if (cached is! List) rethrow;'));
    expect(source, isNot(contains('if (tasks.isEmpty) rethrow;')));
  });
}
