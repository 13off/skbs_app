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
    final reportHeader = File(
      'lib/features/reports/presentation/manager_report_header_widgets.dart',
    ).readAsStringSync();
    final reportSections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();
    final reportUi = '$reports\n$reportHeader\n$reportSections';
    final repository = File(
      'lib/features/reports/data/manager_reports_repository.dart',
    ).readAsStringSync();
    final centerMigration = File(
      'supabase/migrations/20260718162600_manager_reports_center.sql',
    ).readAsStringSync();
    final tasksMigration = File(
      'supabase/migrations/20260718162000_manager_reports_tasks.sql',
    ).readAsStringSync();
    final compactNotifications = File(
      'supabase/migrations/20260718163000_compact_dispatcher_notifications.sql',
    ).readAsStringSync();

    expect(main, contains('ManagerMainScreen'));
    expect(main, contains('if (profile.isAdmin)'));
    expect(shell, contains("label: 'Отчёты'"));
    expect(shell, contains('ManagerReportsScreen'));
    expect(reportUi, contains('Все отчёты'));
    expect(reportUi, contains('Оперативные сводки'));
    expect(reportUi, contains('Табель и начисления'));
    expect(reportUi, contains('Сотрудники'));
    expect(reportUi, contains('Задачи и выполнение'));
    expect(reportUi, contains('Выплаты и бухгалтерия'));
    expect(reportUi, contains('Подбор и HR'));
    expect(reportUi, contains('Юридическое'));
    expect(reportUi, contains('Объекты и этапы'));
    expect(reportUi, contains('Только проблемные разделы'));
    expect(reports.split('\n').length, lessThan(260));
    expect(reports, contains('ManagerReportFilters'));
    expect(reports, contains('ManagerReportOverview'));
    expect(reports, contains('ManagerReportSections'));
    expect(reportSections, contains('final metrics = center.metrics'));
    expect(reportSections, contains('metrics.attendance'));
    expect(reportSections, contains('metrics.payments'));
    expect(reportSections, isNot(contains('center.metric(')));
    expect(reportSections, isNot(contains('center.decimalMetric(')));
    expect(reportSections, isNot(contains('center.trendValue(')));
    expect(reports, contains('forceRefresh: true'));
    expect(repository, contains('get_manager_reports_center'));
    expect(centerMigration, contains('get_manager_reports_center'));
    expect(centerMigration, contains("'dispatcher_runs'"));
    expect(tasksMigration, contains('manager_report_tasks'));
    expect(compactNotifications, contains('Открой отчёт'));
    expect(compactNotifications, contains('v_full_body'));
  });
}
