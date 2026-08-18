import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'August 12+ update is shown once per user and role including employee login',
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

      expect(gate, contains('mobile-2026-08-18-since-2026-08-12-v1'));
      expect(gate, contains("'whats_new_seen_release'"));
      expect(gate, contains('widget.profile.id'));
      expect(gate, contains('widget.profile.role'));
      expect(gate, contains('SharedPreferences.getInstance()'));
      expect(gate, contains('widget.profile.isRolePreview'));
      expect(release, contains('Дела руководителя'));
      expect(release, contains('Штрафы и невыходы под контролем'));
      expect(release, contains('Полноценная платформа юриста'));
      expect(release, contains('Единый стеклянный интерфейс'));
      expect(release, contains('Новые фото «До» и «После»'));
      expect(release, contains('Стабильнее и безопаснее'));
      expect(dialog, contains('С 12 августа'));
      expect(dialog, contains("label: Text(isLast ? 'Готово' : 'Далее')"));

      expect(
        mainScreen,
        contains(
          "import '../features/whats_new/presentation/role_aware_whats_new_gate.dart';",
        ),
      );
      expect(
        mainScreen,
        contains(
          'WhatsNewGate(profile: widget.profile, child: buildPlatform())',
        ),
      );
      expect(
        employeeGate,
        contains("../../whats_new/presentation/role_aware_whats_new_gate.dart"),
      );
      expect(employeeGate, contains('return WhatsNewGate('));
      expect(employeeGate, contains('profile: profile'));
      expect(
        employeeGate,
        contains('child: _EmployeeSessionPlatform(profile: profile)'),
      );
      expect(
        employeeGate,
        contains('EmployeePlatformWithPassport(profile: widget.profile)'),
      );
    },
  );
}
