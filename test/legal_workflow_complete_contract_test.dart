import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lawyer shell uses the completed five-part workflow', () {
    final source = File(
      'lib/features/legal/presentation/legal_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains('LegalTodayCompleteScreen'));
    expect(source, contains('LegalBaseCompleteScreen'));
    expect(source, contains('LegalDocumentsCompleteScreen'));
    expect(source, contains('LegalMattersCompleteScreen'));
    for (final label in <String>['Сегодня', 'База', 'Документы', 'Дела', 'Профиль']) {
      expect(source, contains("label: '$label'"));
    }
  });

  test('employee dossier has completeness and all legal groups', () {
    final source = File(
      'lib/features/legal/presentation/legal_employee_complete_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Комплект документов'));
    for (final title in <String>[
      'Личные данные',
      'Договоры',
      'Заявления и согласия',
      'Личные документы',
      'Акты и объяснительные',
      'Взыскания',
      'Юридические дела',
      'Прочие документы',
    ]) {
      expect(source, contains(title));
    }
    expect(source, contains('LegalOperationsRepository.fetchEmployeeCompleteness'));
  });

  test('object and counterparty dossiers keep all related legal work', () {
    final source = File(
      'lib/features/legal/presentation/legal_base_complete_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Юридический профиль объекта'));
    expect(source, contains('Основной договор'));
    expect(source, contains('Договоры и допсоглашения'));
    expect(source, contains('Претензии'));
    expect(source, contains('Судебные дела'));
    expect(source, contains('Связанные объекты'));
  });

  test('document flow has lifecycle, versions, audit and archive import', () {
    final lifecycle = File(
      'supabase/migrations/20260817095900_legal_document_lifecycle_versions.sql',
    ).readAsStringSync();
    final details = File(
      'lib/features/legal/presentation/legal_document_complete_screen.dart',
    ).readAsStringSync();
    final importer = File(
      'lib/features/legal/presentation/legal_archive_import_screen.dart',
    ).readAsStringSync();

    expect(lifecycle, contains('legal_document_events'));
    expect(lifecycle, contains('version_no'));
    expect(lifecycle, contains("'active'::text"));
    expect(lifecycle, contains("'expired'::text"));
    expect(details, contains('Файлы и версии'));
    expect(details, contains('История документа'));
    expect(details, contains('На согласовании'));
    expect(details, contains('На подписи'));
    expect(details, contains('Действует'));
    expect(importer, contains('Импорт существующих документов'));
    expect(importer, contains('Файл не будет импортирован без привязки'));
  });

  test('today is automatic and court/claim process is a timeline', () {
    final migration = File(
      'supabase/migrations/20260817100100_legal_process_timeline_and_today.sql',
    ).readAsStringSync();
    final today = File(
      'lib/features/legal/presentation/legal_today_complete_screen.dart',
    ).readAsStringSync();
    final matter = File(
      'lib/features/legal/presentation/legal_matter_complete_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('legal_matter_process_events'));
    expect(migration, contains('legal_today_items'));
    expect(migration, contains('missing_documents'));
    expect(migration, contains('process_event'));
    expect(today, contains('Только то, что требует действия'));
    expect(today, contains('Контроль базы'));
    expect(matter, contains('Процессуальная лента'));
    expect(matter, contains('Судебное заседание'));
    expect(matter, contains('Исполнение'));
  });

  test('quality report catches broken and unlinked legal records', () {
    final migration = File(
      'supabase/migrations/20260817100200_legal_quality_report.sql',
    ).readAsStringSync();
    final screen = File(
      'lib/features/legal/presentation/legal_quality_screen.dart',
    ).readAsStringSync();

    expect(migration, contains('document_without_file'));
    expect(migration, contains('unlinked_document'));
    expect(migration, contains('broken_legal_file'));
    expect(migration, contains('broken_employee_file'));
    expect(migration, contains('matter_without_responsible'));
    expect(screen, contains('Контроль качества'));
  });
}
