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

  test('tools center separates connected modules from catalog', () {
    expect(tools, contains("title: 'Инструменты AppСтрой'"));
    expect(tools, contains("label: Text('Подключённые')"));
    expect(tools, contains("label: Text('Каталог')"));
    expect(tools, contains('selectedTab == _CompanyToolsTab.connected'));
  });

  test('employment is one installable tool with internal sections', () {
    expect(tools, contains('AppСтрой Трудоустройство'));
    expect(tools, isNot(contains('AppСтрой Документы')));
    expect(tools, contains("title: 'Оформления'"));
    expect(tools, contains("title: 'Генератор документов'"));
    expect(tools, contains("title: 'Пакеты документов'"));
    expect(tools, contains("title: 'Шаблоны'"));
    expect(tools, contains("title: 'Архив'"));
  });

  test('disabling a tool preserves data and mobile screens stay bounded', () {
    expect(tools, contains('Все данные сохранены'));
    expect(tools, contains('документы и архивы не удалятся'));
    expect(workflow, isNot(contains('return RefreshIndicator(')));
    expect(workflow, contains('onRefresh: refresh'));
  });
}
