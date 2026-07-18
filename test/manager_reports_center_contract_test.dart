import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('руководитель получает единый центр отчётов вместо вкладки табеля', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final shell = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();
    final reports = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/reports/data/manager_reports_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260718162000_manager_reports_center.sql',
    ).readAsStringSync();
    final compactNotifications = File(
      'supabase/migrations/20260718163000_compact_dispatcher_notifications.sql',
    ).readAsStringSync();

    expect(main, contains('ManagerMainScreen'));
    expect(main, contains('if (profile.isAdmin)'));
    expect(shell, contains("label: 'Отчёты'"));
    expect(shell, contains('ManagerReportsScreen'));
    expect(reports, contains('Все отчёты'));
    expect(reports, contains('Оперативные сводки'));
    expect(reports, contains('Табель и начисления'));
    expect(reports, contains('Сотрудники'));
    expect(reports, contains('Задачи и выполнение'));
    expect(reports, contains('Выплаты и бухгалтерия'));
    expect(reports, contains('Подбор и HR'));
    expect(reports, contains('Юридическое'));
    expect(reports, contains('Объекты и этапы'));
    expect(reports, contains('Только проблемные разделы'));
    expect(repository, contains('get_manager_reports_center'));
    expect(migration, contains('get_manager_reports_center'));
    expect(migration, contains("'dispatcher_runs'"));
    expect(compactNotifications, contains('Открой отчёт'));
    expect(compactNotifications, contains('v_full_body'));
  });
}
