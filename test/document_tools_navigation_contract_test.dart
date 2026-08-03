import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('document module is exposed only through company tools', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final tools = File(
      'lib/features/tools/presentation/company_tools_screen.dart',
    ).readAsStringSync();

    expect(settings, contains("sectionTitle('Инструменты')"));
    expect(settings, contains("title: 'Инструменты'"));
    expect(settings, contains('CompanyToolsScreen(profile: profile)'));
    expect(settings, isNot(contains('DocumentWorkflowSettingsEntry')));

    expect(tools, contains("'AppСтрой Трудоустройство'"));
    expect(tools, isNot(contains("'AppСтрой Документы'")));
    expect(tools, contains('Switch.adaptive('));
    expect(tools, contains("enabled ? 'Включён' : 'Отключён'"));
    expect(tools, contains("title: const Text('Отключить инструмент?')"));
    expect(tools, contains('Все данные сохранены'));
    expect(tools, contains("'Открыть инструмент'"));
    expect(tools, contains("title: 'Оформления'"));
    expect(tools, contains("title: 'Генератор документов'"));
    expect(tools, contains("title: 'Пакеты документов'"));
    expect(tools, contains("title: 'Шаблоны'"));
    expect(tools, contains("title: 'Архив'"));
  });

  test('onboarding list is a section of the connected tool', () {
    final workflow = File(
      'lib/features/documents/presentation/document_workflow_screen.dart',
    ).readAsStringSync();

    expect(workflow, contains("title: 'Оформления'"));
    expect(workflow, isNot(contains('class _InstallationCard')));
    expect(workflow, isNot(contains('toggleInstallation(')));
    expect(workflow, contains('onRefresh: refresh'));
  });

  test('document screens do not nest a vertical ListView inside AppPage', () {
    const paths = <String>[
      'lib/features/documents/presentation/document_workflow_screen.dart',
      'lib/features/documents/presentation/document_generation_screen.dart',
      'lib/features/documents/presentation/document_onboarding_screen.dart',
      'lib/features/documents/presentation/document_package_management_screen.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('return RefreshIndicator(\n')),
        reason: '$path must use the AppPage scroll container',
      );
      expect(source, contains('onRefresh:'));
    }
  });
}
