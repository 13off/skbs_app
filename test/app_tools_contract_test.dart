import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String settings;
  late String profile;
  late String tools;
  late String employment;

  setUpAll(() {
    settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    tools = File(
      'lib/features/tools/presentation/app_tools_screen.dart',
    ).readAsStringSync();
    employment = File(
      'lib/features/documents/presentation/document_workflow_screen.dart',
    ).readAsStringSync();
  });

  test('tools are not rendered inside notification settings', () {
    expect(settings, contains('AppToolsSettingsEntry(profile: profile)'));
    expect(settings, isNot(contains('DocumentWorkflowSettingsEntry')));
    expect(
      settings.indexOf("sectionTitle('Уведомления')"),
      lessThan(settings.indexOf("sectionTitle('Настройки профессии')")),
    );
    expect(
      settings.indexOf("sectionTitle('Настройки профессии')"),
      lessThan(settings.indexOf('AppToolsSettingsEntry(profile: profile)')),
    );
  });

  test('connected employment tool appears as a profile work tool', () {
    expect(profile, contains('ConnectedAppToolsSection(profile: profile)'));
    expect(tools, contains('Инструменты AppСтрой'));
    expect(tools, contains('Подключённые'));
    expect(tools, contains('Каталог'));
    expect(tools, contains('AppСтрой Трудоустройство'));
  });

  test('generator and packages stay inside the installed tool', () {
    expect(employment, contains("title: 'AppСтрой Трудоустройство'"));
    expect(employment, contains("label: const Text('Генератор')"));
    expect(employment, contains("label: const Text('Пакеты')"));
    expect(employment, contains("label: const Text('Шаблоны')"));
  });
}
