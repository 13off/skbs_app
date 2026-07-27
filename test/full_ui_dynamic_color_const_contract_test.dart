import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptive UI colors are not trapped inside const expressions', () {
    final archive = File(
      'lib/features/recruitment/presentation/recruitment_archive_screen.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
    ).readAsStringSync();
    final timesheet = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();
    final objects = File(
      'lib/screens/object_management_screen.dart',
    ).readAsStringSync();

    expect(
      archive,
      isNot(contains("const Text(\n                    'Не удалось загрузить архив'")),
    );
    expect(dashboard, contains('Color color = AppAdaptivePalette.telegramBlue'));
    expect(
      dashboard,
      isNot(contains("const Text(\n                    'Не удалось загрузить HR-сводку'")),
    );
    expect(
      timesheet,
      contains('this.accent = AppAdaptivePalette.telegramBlue'),
    );
    expect(
      objects,
      isNot(contains("const Text(\n            'Объекты'")),
    );
    expect(
      objects,
      isNot(contains("child: const Text(\n                  'Объекты пока не найдены'")),
    );
  });
}
