import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('основные навигационные карточки показывают только название', () {
    final reports = File(
      'lib/features/reports/presentation/manager_report_tile.dart',
    ).readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final rolePreview = File(
      'lib/features/role_preview/role_preview_screen.dart',
    ).readAsStringSync();

    expect(reports, isNot(contains('cleanMeta')));
    expect(reports, isNot(contains('Text(\n                          cleanMeta')));
    expect(reports, contains('trailingLabel'));

    expect(settings, isNot(contains('final String subtitle;')));
    expect(settings, isNot(contains('required String subtitle')));
    expect(settings, isNot(contains('subtitle: const Text(\'Применяется')));
    expect(settings, contains('class _SettingsActionTile'));

    expect(profile, contains('hint: subtitle'));
    expect(profile, isNot(contains('Text(\n                      subtitle')));
    expect(profile, contains('infoTile('));

    expect(rolePreview, isNot(contains('required String subtitle')));
    expect(rolePreview, isNot(contains('Обычная платформа администратора')));
    expect(rolePreview, contains('final details = <String>['));
    expect(rolePreview, contains('badge: preview.isForemanMode'));
    expect(rolePreview, contains('badge: preview.isEmployeeMode'));
  });

  test('панели профессий не возвращают описания в кнопки', () {
    const paths = <String>[
      'lib/features/developer/presentation/developer_system_screen.dart',
      'lib/features/legal/presentation/legal_dashboard_screen.dart',
      'lib/features/accounting/presentation/accounting_dashboard_screen.dart',
      'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('required String subtitle')),
        reason: path,
      );
    }
  });
}
