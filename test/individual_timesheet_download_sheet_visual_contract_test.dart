import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('общий и индивидуальный выбор периода используют одну композицию', () {
    final common = File(
      'lib/screens/timesheet_download_sheet.dart',
    ).readAsStringSync();
    final individual = File(
      'lib/screens/employee_timesheet_download_sheet.dart',
    ).readAsStringSync();

    for (final token in <String>[
      'showModalBottomSheet<void>(',
      'backgroundColor: Colors.transparent',
      'margin: const EdgeInsets.all(12)',
      'padding: const EdgeInsets.fromLTRB(18, 12, 18, 18)',
      'borderRadius: BorderRadius.circular(28)',
      "label: Text('Месяцы')",
      "label: Text('Даты')",
      'crossAxisCount: 3',
      'childAspectRatio: 2.35',
    ]) {
      expect(common, contains(token), reason: token);
      expect(individual, contains(token), reason: token);
    }
  });
}
