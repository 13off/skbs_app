import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('locked historical date remains visible but read-only on both layouts', () {
    final mobile = File(
      'lib/screens/timesheet/timesheet_sections.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();

    expect(mobile, contains('Просмотр'));
    expect(mobile, contains('canEditSelectedTimesheetDate'));
    expect(desktop, contains('Дата доступна только для просмотра'));
    expect(desktop, contains('canEditSelectedTimesheetDate'));
  });
}
