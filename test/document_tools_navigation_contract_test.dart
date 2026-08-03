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
    expect(tools, contains('Icons.info_outline_rounded'));
    expect(tools, contains('PageView.builder('));
    expect(tools, contains('AnimatedContainer('));
    expect(tools, contains('DocumentToolAvailability.notifyChanged()'));
    expect(tools, contains('class DocumentToolAppShortcut'));
    expect(tools, contains('class _EmploymentToolIcon'));
    expect(tools, contains("title: 'Оформления'"));
    expect(tools, contains("title: 'Генератор документов'"));
    expect(tools, contains("title: 'Пакеты документов'"));
    expect(tools, contains("title: 'Шаблоны'"));
    expect(tools, contains('DocumentToolTemplatesScreen'));
    expect(tools, isNot(contains("title: 'Архив'")));
    expect(tools, contains('общем архиве AppСтрой'));

    expect(tools, isNot(contains("label: const Text('Открыть инструмент')")));
    expect(tools, isNot(contains("Chip(label: Text('HR'))")));
    expect(tools, isNot(contains("Chip(label: Text('Юрист'))")));
  });

  test('only an enabled connected tool appears in profile as an app shortcut', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(profile, contains("sectionTitle('Инструменты')"));
    expect(profile, contains('DocumentToolAppShortcut('));
    expect(profile, contains('DocumentToolWorkspaceScreen('));
    expect(profile, contains('!data.installation.isEnabled'));
    expect(profile, contains('!data.access.canView'));
    expect(profile, contains('return const SizedBox.shrink();'));
  });

  test('tool templates support protected online editing and versioning', () {
    final templates = File(
      'lib/features/documents/presentation/document_tool_templates_screen.dart',
    ).readAsStringSync();
    final editorScreen = File(
      'lib/features/documents/presentation/document_template_online_editor_screen.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/documents/data/document_template_online_editor.dart',
    ).readAsStringSync();

    expect(templates, contains('Редактировать онлайн'));
    expect(templates, contains('DocumentTemplateOnlineEditorScreen'));
    expect(editorScreen, contains('Icons.lock_rounded'));
    expect(editorScreen, contains('Сохранить новую версию'));
    expect(editor, contains('source_version_id'));
    expect(editor, contains('protected_blocks'));
    expect(editor, contains("'source_kind': 'storage'"));
    expect(editor, contains('Сначала нажмите «Новая версия»'));
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