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

  test('employment is one installable tool with internal sections', () {
    expect(tools, contains('AppСтрой Трудоустройство'));
    expect(tools, isNot(contains('AppСтрой Документы')));
    expect(tools, contains("title: 'Оформления'"));
    expect(tools, contains("title: 'Генератор документов'"));
    expect(tools, contains("title: 'Пакеты документов'"));
    expect(tools, contains("title: 'Шаблоны'"));
    expect(tools, contains("title: 'Архив'"));
  });

  test('tool information is detailed and contains an animated guide', () {
    expect(tools, contains("title: 'Что умеет инструмент'"));
    expect(tools, contains("title: 'Кто и за что отвечает'"));
    expect(tools, contains("title: 'Как работать с инструментом'"));
    expect(tools, contains('Шаг 8 из 8'));
    expect(tools, contains('AnimationController'));
    expect(tools, contains('PageView.builder'));
    expect(tools, contains('LinearProgressIndicator'));
    expect(tools, contains('Правило общего кадрового архива'));
  });

  test('disabling a tool preserves data and mobile screens stay bounded', () {
    expect(tools, contains('Все данные сохранены'));
    expect(tools, contains('документы и архивы сохранятся'));
    expect(workflow, isNot(contains('return RefreshIndicator(')));
    expect(workflow, contains('onRefresh: refresh'));
  });
}
