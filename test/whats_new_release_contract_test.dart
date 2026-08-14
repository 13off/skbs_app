import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'major update is shown once per user and role including employee login',
    () {
      final gate = File(
        'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
      ).readAsStringSync();
      final mainScreen = File(
        'lib/screens/main_screen.dart',
      ).readAsStringSync();
      final employeeGate = File(
        'lib/features/auth/presentation/employee_aware_auth_gate.dart',
      ).readAsStringSync();

      expect(gate, contains('mobile-2026-08-07-role-aware-major-update-v1'));
      expect(gate, contains("'whats_new_seen_release'"));
      expect(gate, contains('widget.profile.id'));
      expect(gate, contains('widget.profile.role'));
      expect(gate, contains('SharedPreferences.getInstance()'));
      expect(gate, contains('widget.profile.isRolePreview'));
      expect(gate, contains('Новый кабинет сотрудника'));
      expect(gate, contains('Геолокация и маршрут работы'));
      expect(gate, contains('Новая платформа снабжения'));
      expect(gate, contains('AppСтрой Трудоустройство'));
      expect(gate, contains('Документы нового уровня'));
      expect(gate, contains('Календарь вылетов HR'));
      expect(gate, contains('Новый стиль AppСтрой'));
      expect(gate, contains('AppСтрой стал быстрее'));
      expect(gate, contains('Исправлены ошибки'));
      expect(gate, contains("label: Text(isLast ? 'Готово' : 'Далее')"));

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
