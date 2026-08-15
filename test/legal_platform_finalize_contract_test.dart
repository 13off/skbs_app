import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lawyer base contains only contextual directories', () {
    final source = File(
      'lib/features/legal/presentation/legal_workspace_screen.dart',
    ).readAsStringSync();

    expect(source, contains('DefaultTabController(\n          length: 3'));
    expect(source, contains("Tab(text: 'Сотрудники"));
    expect(source, contains("Tab(text: 'Объекты"));
    expect(source, contains("Tab(text: 'Контрагенты"));
    expect(source, contains('База юриста'));
    expect(source, contains('_EmployeeDossierScreen'));
    expect(source, contains('_ObjectLegalDossierScreen'));
    expect(source, contains('_CounterpartyDossierScreen'));
    expect(source, isNot(contains('length: 9')));
  });

  test('documents keep contracts and acts in one useful registry', () {
    final source = File(
      'lib/features/legal/presentation/adaptive_legal_documents_screen.dart',
    ).readAsStringSync();

    expect(source, contains("DropdownMenuItem(value: 'contract', child: Text('Договоры'))"));
    expect(source, contains("DropdownMenuItem(value: 'act', child: Text('Акты'))"));
    expect(source, contains('documentCategory'));
    expect(source, contains("label: 'Договоры'"));
    expect(source, contains("label: 'Акты'"));
    expect(source, contains("actionLabel: source.isEmpty ? 'Добавить документ' : null"));
  });

  test('court and claim workflow uses legal matters instead of parallel registry', () {
    final migration = File(
      'supabase/migrations/20260815134930_legal_platform_finalize.sql',
    ).readAsStringSync();
    final process = File(
      'lib/features/legal/data/legal_process_repository.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/legal/presentation/legal_matter_editor_part.dart',
    ).readAsStringSync();

    for (final column in <String>[
      'court_case_number',
      'court_name',
      'court_parties',
      'claim_amount',
      'proceeding_stage',
      'next_hearing_at',
      'outgoing_sent_at',
      'response_due_at',
    ]) {
      expect(migration, contains(column));
    }
    expect(migration, contains('alter table public.legal_matters'));
    expect(migration, isNot(contains('create table public.legal_court')));
    expect(process, contains("legalCourtMatterType = 'court'"));
    expect(editor, contains('Судебное дело'));
    expect(editor, contains('Претензионная работа'));
    expect(editor, contains('LegalProcessRepository.saveDetails'));
  });

  test('case registry is one screen with court and claim filters', () {
    final desktop = File(
      'lib/features/legal/presentation/adaptive_legal_matters_screen.dart',
    ).readAsStringSync();
    final mobile = File(
      'lib/features/legal/presentation/legal_matters_screen.dart',
    ).readAsStringSync();

    expect(
      desktop,
      contains("title: managerMode ? 'Решения и риски' : 'Юридические дела'"),
    );
    expect(desktop, contains('legalCourtMatterType'));
    expect(desktop, contains('LegalMatterType.claim'));
    expect(desktop, contains("label: 'Суды'"));
    expect(desktop, contains("label: 'Претензии'"));
    expect(
      mobile,
      contains("title: managerMode ? 'Решения и риски' : 'Дела'"),
    );
    expect(mobile, contains('legalMatterDisplayType'));
  });

  test('matter card shows process details and existing legal history', () {
    final details = File(
      'lib/features/legal/presentation/legal_matter_details_part.dart',
    ).readAsStringSync();

    for (final text in <String>[
      'Суть дела',
      'Основание',
      'Судебное производство',
      'Претензионная работа',
      'Участники и ответственность',
      'Контроль дела',
      'Связанные документы',
      'История дела',
    ]) {
      expect(details, contains(text));
    }
    expect(details, contains('LegalProcessRepository.fetchDetails'));
    expect(details, contains('LegalMatterWorkspaceRepository.fetch'));
  });
}
