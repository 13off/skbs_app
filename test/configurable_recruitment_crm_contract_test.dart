import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_models.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('HR can configure kanban columns without creating another candidate base', () {
    final migration = source(
      'supabase/migrations/20260723270000_configurable_recruitment_crm.sql',
    );
    final settings = source(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    );
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(migration, contains('recruitment_pipeline_stages'));
    expect(migration, contains("'recruitment.crm.configure'"));
    expect(migration, contains("('owner'), ('admin'), ('developer'), ('hr')"));
    expect(migration, contains('sync_recruitment_pipeline_stage'));
    expect(migration, contains('move_recruitment_application_stage'));
    expect(migration, contains('Сначала переместите кандидатов из этой колонки'));
    expect(settings, contains("title: 'Настройка CRM'"));
    expect(settings, contains("Text('Добавить колонку')"));
    expect(settings, contains('reorderPipelineStages'));
    expect(settings, contains('setPipelineStageActive'));
    expect(repository, contains(".from('recruitment_applications')"));
    expect(repository, isNot(contains(".from('crm_candidates')")));
  });

  test('custom candidate fields support Bitrix-like data types', () {
    final settings = source(
      'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
    );
    final applications = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );
    final migration = source(
      'supabase/migrations/20260723270000_configurable_recruitment_crm.sql',
    );

    expect(
      recruitmentCustomFieldTypes,
      containsAll(<String>[
        'text',
        'multiline',
        'number',
        'money',
        'phone',
        'email',
        'date',
        'boolean',
        'select',
        'multiselect',
      ]),
    );
    expect(settings, contains("Text('Добавить поле')"));
    expect(settings, contains('isRequired'));
    expect(settings, contains('showOnCard'));
    expect(settings, contains('optionsController'));
    expect(applications, contains('customFieldWidget'));
    expect(applications, contains('validateCustomValues'));
    expect(applications, contains('configuration.customSearchText'));
    expect(migration, contains("custom_values jsonb not null default '{}'::jsonb"));
  });

  test('dynamic CRM remains synchronized through realtime and history', () {
    final sync = source('lib/data/app_data_sync.dart');
    final repository = source(
      'lib/features/recruitment/data/recruitment_repository.dart',
    );

    expect(sync, contains("case 'recruitment_pipeline_stages':"));
    expect(sync, contains("case 'recruitment_custom_fields':"));
    expect(repository, contains("'move_recruitment_application_stage'"));
    expect(repository, contains(".from('recruitment_status_history')"));
    expect(repository, contains("'stage_title': stageTitle"));
  });
}
