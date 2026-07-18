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

    expect(main, contains('DeveloperMainScreen(profile: profile)'));
    expect(main, contains('profile.isDeveloper && !profile.isRolePreview'));
    expect(platform, contains("label: 'Система'"));
    expect(platform, contains("label: 'Диспетчер'"));
    expect(platform, contains("label: 'Ограничения'"));
    expect(system, contains('Общие настройки AppСтрой без правок в коде'));
    expect(system, contains('NotificationControlCenterScreen'));
  });

  test('dispatcher has configurable schedule, sections and delivery', () {
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
    expect(screen, contains('Проверить сейчас'));
  });

  test('server migration schedules one daily company summary', () {
    final migration = File(
      'supabase/migrations/20260718133000_ai_dispatcher_developer_platform.sql',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/daily-dispatcher-summary/index.ts',
    ).readAsStringSync();

    expect(migration, contains('dispatcher_summary_settings'));
    expect(migration, contains('dispatcher_summary_runs'));
    expect(migration, contains('process_due_dispatcher_summaries'));
    expect(migration, contains('appstroy-dispatcher-daily-summary'));
    expect(migration, contains('unique(company_id, summary_date)'));
    expect(edge, contains('ИИ-диспетчер AppСтрой'));
    expect(edge, contains('OPENAI_API_KEY'));
    expect(edge, contains('push_requested'));
  });
}
