import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRM reorder and candidate save use atomic RPCs', () {
    final repository = File(
      'lib/features/recruitment/data/recruitment_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724010000_harden_recruitment_crm_operations.sql',
    ).readAsStringSync();

    expect(repository, contains("'reorder_recruitment_pipeline_stages'"));
    expect(repository, contains("'reorder_recruitment_custom_fields'"));
    expect(repository, contains("'save_recruitment_application_from_crm'"));
    expect(repository, isNot(contains('Future.wait<void>(<Future<void>>[')));
    expect(migration, contains('security invoker'));
    expect(migration, contains('for update'));
    expect(migration, contains('recruitment_status_history'));
  });

  test('custom CRM fields support HR descriptions', () {
    final model = File(
      'lib/features/recruitment/models/recruitment_models.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    ).readAsStringSync();
    final editor = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(model, contains('final String description;'));
    expect(settings, contains('Описание / подсказка'));
    expect(settings, contains('description: result.description'));
    expect(editor, contains('field.description'));
  });
}
