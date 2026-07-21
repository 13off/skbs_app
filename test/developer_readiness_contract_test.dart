import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer system exposes production readiness diagnostics', () {
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final readiness = File(
      'lib/features/developer/presentation/developer_readiness_screen.dart',
    ).readAsStringSync();

    expect(system, contains('DeveloperReadinessScreen(profile: profile)'));
    expect(system, contains('Готовность и диагностика'));
    expect(readiness, contains("client.auth.currentUser"));
    expect(readiness, contains(".from('objects')"));
    expect(readiness, contains('DeveloperPolicyRepository.fetchCenter()'));
    expect(readiness, contains('DocumentTemplateRepository.fetchTemplates'));
    expect(readiness, contains("'ai-operational-draft'"));
    expect(readiness, contains('Production gate: BLOCKED'));
    expect(readiness, contains('Web/PWA после публикации'));
    expect(readiness, contains('Мобильный релиз'));
  });

  test('readiness checks do not mutate production data', () {
    final readiness = File(
      'lib/features/developer/presentation/developer_readiness_screen.dart',
    ).readAsStringSync();

    expect(readiness, contains('read-only черновик месячного табеля'));
    expect(readiness, isNot(contains('.insert(')));
    expect(readiness, isNot(contains('.update(')));
    expect(readiness, isNot(contains('.upsert(')));
    expect(readiness, isNot(contains('.delete(')));
    expect(readiness, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });

  test('existing object restrictions remain the editing surface', () {
    final panel = File(
      'lib/features/developer/presentation/developer_panel_screen_legacy.dart',
    ).readAsStringSync();

    expect(panel, contains('Обязательно фото «До»'));
    expect(panel, contains('Обязательно фото «После»'));
    expect(panel, contains('Редактировать прошедшие задачи'));
    expect(panel, contains('Удаление задачи'));
    expect(panel, contains('Наследует настройки компании'));
    expect(panel, contains('Журнал изменений'));
  });
}
