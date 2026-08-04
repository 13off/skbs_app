import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String settings;
  late String tools;
  late String workflow;

  setUpAll(() {
    settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    tools = File(
      'lib/features/tools/presentation/company_tools_screen.dart',
    ).readAsStringSync();
    workflow = File(
      'lib/features/documents/presentation/document_workflow_screen.dart',
    ).readAsStringSync();
  });

  test('company tools remain outside notification controls', () {
    final notifications = settings.indexOf("sectionTitle('Уведомления')");
    final toolsSection = settings.indexOf("sectionTitle('Инструменты')");
    final profession = settings.indexOf("sectionTitle('Настройки профессии')");

    expect(notifications, greaterThanOrEqualTo(0));
    expect(toolsSection, greaterThan(notifications));
    expect(profession, greaterThan(toolsSection));
    expect(settings, contains('CompanyToolsScreen(profile: profile)'));
    expect(settings, isNot(contains('DocumentWorkflowSettingsEntry')));
  });

  test('tools screen is one simple list without a catalog', () {
    expect(tools, contains("title: 'Инструменты'"));
    expect(tools, isNot(contains("label: Text('Подключённые')")));
    expect(tools, isNot(contains("label: Text('Каталог')")));
    expect(tools, isNot(contains('_CompanyToolsTab')));
    expect(tools, contains("tooltip: 'Подробно об инструменте'"));
    expect(tools, contains('Switch.adaptive'));
  });

  test(
    'employment tool contains workflow functions but not a second archive',
    () {
      expect(tools, contains('AppСтрой Трудоустройство'));
      expect(tools, isNot(contains('AppСтрой Документы')));
      expect(tools, contains("title: 'Оформления'"));
      expect(tools, contains("title: 'Генератор документов'"));
      expect(tools, contains("title: 'Пакеты документов'"));
      expect(tools, contains("title: 'Шаблоны'"));
      expect(tools, contains('DocumentToolTemplatesScreen'));
      expect(tools, isNot(contains("title: 'Архив'")));
      expect(
        tools,
        contains('Отдельный второй архив внутри инструмента не создаётся'),
      );
    },
  );

  test('tool information contains the online editor and animated guide', () {
    expect(tools, contains('Что умеет инструмент'));
    expect(tools, contains('Как работать'));
    expect(tools, contains('Онлайн-редактор'));
    expect(tools, contains("'8 из 8'"));
    expect(tools, contains('AnimationController'));
    expect(tools, contains('PageView.builder'));
    expect(tools, contains('AnimatedContainer'));
    expect(tools, contains('общем архиве AppСтрой'));
  });

  test('disabling a tool preserves data and mobile screens stay bounded', () {
    expect(tools, contains('Все данные сохранены'));
    expect(tools, contains('Общий архив AppСтрой также не изменится'));
    expect(workflow, isNot(contains('return RefreshIndicator(')));
    expect(workflow, contains('onRefresh: refresh'));
  });
}
