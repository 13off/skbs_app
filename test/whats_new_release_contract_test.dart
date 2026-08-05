import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('August update is shown once per user and role', () {
    final gate = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();
    final guide = File(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(
      gate,
      contains(
        "releaseId =\n      'mobile-2026-08-05-employee-workspace-and-procurement-v1'",
      ),
    );
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('widget.profile.id'));
    expect(gate, contains('widget.profile.role'));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('widget.profile.isRolePreview'));
    expect(gate, isNot(contains('FirstRunGuide.showIfNeeded')));
    expect(gate, contains('Обновление августа 2026'));
    expect(gate, contains('Новый кабинет сотрудника'));
    expect(gate, contains('Маршруты, геозоны и работа без связи'));
    expect(gate, contains('Вход сотрудника через MAX'));
    expect(gate, contains('Реальные задачи и фотографии'));
    expect(gate, contains('Табели и выплаты без лишних переходов'));
    expect(gate, contains('Команда объекта'));
    expect(gate, contains('Новая платформа снабжения'));
    expect(gate, contains('Инструменты с анимированным гидом'));
    expect(gate, contains('Новый интерфейс PWA и нижняя панель'));
    expect(gate, contains('Быстрее и надёжнее'));
    expect(gate, isNot(contains('Паспорт специалиста')));
    expect(gate, contains("label: Text(_isLast ? 'Готово' : 'Далее')"));

    expect(guide, contains('OverlayEntry('));
    expect(guide, contains('_SpotlightPainter'));
    expect(
      mainScreen,
      contains(
        "import '../features/whats_new/presentation/role_aware_whats_new_gate.dart';",
      ),
    );
    expect(
      mainScreen,
      contains('WhatsNewGate(profile: widget.profile, child: buildPlatform())'),
    );
  });
}
