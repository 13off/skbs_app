import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'September update is shown once per user and role with current release cards',
    () {
      final gate = File(
        'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
      ).readAsStringSync();
      final release = File(
        'lib/features/whats_new/presentation/whats_new_release_data.dart',
      ).readAsStringSync();
      final dialog = File(
        'lib/features/whats_new/presentation/whats_new_dialog.dart',
      ).readAsStringSync();
      final mainScreen = File(
        'lib/screens/main_screen.dart',
      ).readAsStringSync();
      final employeeGate = File(
        'lib/features/auth/presentation/employee_aware_auth_gate.dart',
      ).readAsStringSync();

      expect(gate, contains('mobile-2026-09-26-1.3.10+24-v2'));
      expect(gate, contains("'whats_new_seen_release'"));
      expect(gate, contains('widget.profile.id'));
      expect(gate, contains('widget.profile.role'));
      expect(gate, contains('SharedPreferences.getInstance()'));
      expect(gate, contains('widget.profile.isRolePreview'));

      expect(release, contains('Фото и видео в задачах'));
      expect(release, contains('Копейки — через точку или запятую'));
      expect(release, contains('Аванс 30% в «Оплате»'));
      expect(release, contains('Переплату можно перенести'));
      expect(release, isNot(contains('Дела руководителя')));
      expect(release, isNot(contains('Стабильнее и безопаснее')));
      expect(dialog, contains('С 26 сентября'));
      expect(dialog, contains("label: Text(isLast ? 'Готово' : 'Далее')"));

      expect(
        mainScreen,
        contains(
          "import '../features/whats_new/presentation/role_aware_whats_new_gate.dart';",
        ),
      );
      expect(mainScreen, contains('return WhatsNewGate('));
      expect(mainScreen, contains('profile: widget.profile'));
      expect(mainScreen, contains('child: OfflineSyncHost('));
      expect(mainScreen, contains('child: buildPlatform()'));
      expect(
        employeeGate,
        contains("../../whats_new/presentation/role_aware_whats_new_gate.dart"),
      );
      expect(employeeGate, contains('return WhatsNewGate('));
      expect(employeeGate, contains('profile: profile'));
    },
  );
}
