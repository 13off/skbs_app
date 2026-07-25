import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly contribution summary stays inside manager reports', () {
    final reports = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final managerShell = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();
    final section = File(
      'lib/features/reports/presentation/manager_weekly_contribution_section.dart',
    ).readAsStringSync();

    expect(reports, contains('ManagerWeeklyContributionSection('));
    expect(reports, contains('ManagerWeeklyContributionRepository.fetch('));
    expect(reports, contains('companyId: widget.profile.activeCompanyId'));
    expect(section, contains("'Вклад команды за неделю'"));
    expect(section, contains('обновляется после завершения недели'));
    expect(section, contains('EmployeeContributionScreen'));
    expect(managerShell, contains('static const int pageCount = 5;'));
    expect(managerShell, isNot(contains("label: 'Вклад команды'")));
  });

  test('foreman never receives the manager weekly contribution summary', () {
    final foreman = File(
      'lib/features/foreman/presentation/foreman_main_screen.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260725130000_manager_weekly_team_contribution.sql',
    ).readAsStringSync();

    expect(foreman, isNot(contains('ManagerWeeklyContributionSection')));
    expect(foreman, isNot(contains('get_manager_weekly_team_contribution')));
    expect(migration, contains('if not public.is_admin()'));
    expect(migration, contains("raise exception 'manager report is not available'"));
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
  });

  test('summary uses the last completed week and no ranking', () {
    final migration = File(
      'supabase/migrations/20260725130000_manager_weekly_team_contribution.sql',
    ).readAsStringSync();
    final section = File(
      'lib/features/reports/presentation/manager_weekly_contribution_section.dart',
    ).readAsStringSync();

    expect(
      migration,
      contains('v_week_end := v_today - extract(isodow from v_today)::integer'),
    );
    expect(migration, contains('v_week_start := v_week_end - 6'));
    expect(
      migration,
      contains('order by lower(employee_totals.object_name), lower(employee_totals.employee_name)'),
    );
    expect(section, isNot(contains('Лучший')));
    expect(section, isNot(contains('Худший')));
    expect(section, isNot(contains('Рейтинг')));
  });
}
