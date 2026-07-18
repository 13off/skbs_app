import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer role opens a dedicated system platform', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final platform = File(
      'lib/features/developer/presentation/developer_main_screen.dart',
    ).readAsStringSync();
    final system = File(
      'lib/features/developer/presentation/developer_system_screen.dart',
    ).readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(main, contains('DeveloperMainScreen(profile: profile)'));
    expect(main, contains('if (profile.isDeveloper)'));
    expect(
      main,
      isNot(contains('profile.isDeveloper && !profile.isRolePreview')),
    );
    expect(platform, contains("label: 'Система'"));
    expect(platform, contains("label: 'Диспетчер'"));
    expect(platform, contains("label: 'Ограничения'"));
    expect(system, contains('Общие настройки AppСтрой без правок в коде'));
    expect(system, contains('DeveloperConstructorScreen'));
    expect(profile, isNot(contains("title: 'Панель разработчика'")));
    expect(profile, isNot(contains("'Для разработчика'")));
  });

  test('developer constructor manages reminders and custom settings', () {
    final repository = File(
      'lib/features/developer/data/developer_constructor_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/developer/presentation/developer_constructor_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260718150000_developer_constructor.sql',
    ).readAsStringSync();

    expect(repository, contains('get_developer_constructor_center'));
    expect(repository, contains('save_developer_reminder_rule'));
    expect(repository, contains('delete_developer_reminder_rule'));
    expect(repository, contains('test_developer_reminder_rule'));
    expect(repository, contains('save_developer_custom_setting'));
    expect(repository, contains('delete_developer_custom_setting'));
    expect(screen, contains('Новое напоминание'));
    expect(screen, contains('Системные параметры'));
    expect(screen, contains('Получатели'));
    expect(screen, contains('Время напоминания'));
    expect(migration, contains('developer_reminder_rules'));
    expect(migration, contains('developer_custom_settings'));
    expect(migration, contains('populate_developer_custom_reminders'));
  });

  test('dispatcher requires one object and keeps object-specific history', () {
    final repository = File(
      'lib/features/dispatcher/data/dispatcher_summary_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/dispatcher/presentation/dispatcher_settings_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260718151000_object_dispatcher_summary.sql',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/daily-dispatcher-summary/index.ts',
    ).readAsStringSync();

    expect(repository, contains('DispatcherObjectOption'));
    expect(repository, contains("'object_id': objectId"));
    expect(repository, contains('objectName'));
    expect(screen, contains('Объект сводки'));
    expect(screen, contains('только объект'));
    expect(screen, contains('Проверить сейчас'));
    expect(migration, contains('object_id uuid references public.objects'));
    expect(
      migration,
      contains('dispatcher_summary_runs_company_object_date_key'),
    );
    expect(migration, contains('prepare_dispatcher_object_summary'));
    expect(migration, contains('Объект: %s'));
    expect(edge, contains('prepare_dispatcher_object_summary'));
    expect(edge, contains('object_name'));
    expect(edge, contains('OPENAI_API_KEY'));
  });

  test('dispatcher keeps configurable schedule, sections and delivery', () {
    final repository = File(
      'lib/features/dispatcher/data/dispatcher_summary_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/dispatcher/presentation/dispatcher_settings_screen.dart',
    ).readAsStringSync();

    expect(repository, contains('get_dispatcher_summary_center'));
    expect(repository, contains('save_dispatcher_summary_settings'));
    expect(repository, contains('run_dispatcher_summary_now'));
    expect(screen, contains('Время ежедневной сводки'));
    expect(screen, contains('Содержание сводки'));
    expect(screen, contains('Получатели'));
    expect(screen, contains('Комментарий ИИ'));
  });
}
