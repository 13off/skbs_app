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

    expect(tools, contains("'AppСтрой Документы'"));
    expect(tools, contains("'Подключить инструмент'"));
    expect(tools, contains("'Открыть инструмент'"));
    expect(tools, contains("title: 'Оформления'"));
    expect(tools, contains("title: 'Генератор документов'"));
    expect(tools, contains("title: 'Пакеты документов'"));
    expect(tools, contains("title: 'Шаблоны'"));
    expect(tools, contains("title: 'Архив'"));
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
