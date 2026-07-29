import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role-aware mobile update summary is shown once per user and role', () {
    final gate = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();
    final guide = File(
      'lib/features/onboarding/presentation/first_run_guide.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.3.1+5'));
    expect(
      gate,
      contains(
        "releaseId =\n      'mobile-2026-07-29-full-since-1.1.0+2-v2-role-aware'",
      ),
    );
    expect(gate, contains("'whats_new_seen_release'"));
    expect(gate, contains('widget.profile.id'));
    expect(gate, contains('widget.profile.role'));
    expect(gate, contains('SharedPreferences.getInstance()'));
    expect(gate, contains('widget.profile.isRolePreview'));
    expect(gate, isNot(contains('FirstRunGuide.showIfNeeded')));
    expect(gate, contains('Изменения после Android 1.1.0+2'));
    expect(gate, contains('Отдельные платформы для каждой роли'));
    expect(gate, contains('ИИ-диспетчер по объектам'));
    expect(gate, contains('Отчёты и контроль показателей'));
    expect(gate, contains('Действия ИИ с подтверждением'));
    expect(gate, contains('Документы и кадровые пакеты'));
    expect(gate, contains('CRM подбора сотрудников'));
    expect(gate, contains('Оформление и выход на объект'));
    expect(gate, contains('Системная платформа разработчика'));
    expect(gate, contains('Задачи, фото и личный вклад'));
    expect(gate, contains('Уведомления по вашей роли'));
    expect(gate, contains('Полноценная тёмная тема'));
    expect(gate, contains('Полноценный кабинет сотрудника'));
    expect(gate, contains("Text(_isLast ? 'Готово' : 'Далее')"));

    // Код обучения сохраняется для возможного возвращения, но не вызывается.
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
