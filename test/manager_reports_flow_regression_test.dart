import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/reports/data/manager_reports_repository.dart';

void main() {
  test('центр различает критичные и контрольные вопросы', () {
    final center = ManagerReportsCenter.fromJson(<String, dynamic>{
      'report_date': '2026-07-18',
      'objects': <dynamic>[],
      'metrics': <String, dynamic>{
        'critical_count': 49,
        'critical_only_count': 38,
        'attention_count': 11,
        'issues_count': 49,
      },
      'trend': <String, dynamic>{},
      'details': <String, dynamic>{},
      'dispatcher_runs': <dynamic>[],
    });

    expect(center.criticalCount, 49);
    expect(center.criticalOnlyCount, 38);
    expect(center.attentionCount, 11);
  });

  test('выбранный объект разрешается до первого RPC', () {
    final repository = File(
      'lib/features/reports/data/manager_reports_repository.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/reports/presentation/manager_main_screen.dart',
    ).readAsStringSync();

    expect(repository, contains('setPreferredObjectName'));
    expect(repository, contains('_resolvePreferredObjectId'));
    expect(repository, contains('ObjectRepository.fetchObjects'));
    expect(shell, contains('ManagerReportsRepository.setPreferredObjectName(next)'));
    expect(shell, contains("'manager-reports:\${selectedObjectName ?? '__all__'}'"));
  });

  test('дневные чеки не скрывают месячный остаток', () {
    final migration = File(
      'supabase/migrations/20260720153000_report_issue_semantics.sql',
    ).readAsStringSync();

    expect(migration, contains("'missing_receipts_day'"));
    expect(migration, contains("'missing_receipts_month'"));
    expect(migration, contains("'missing_items_day'"));
    expect(migration, contains("'{metrics,critical_only_count}'"));
    expect(migration, contains("'{metrics,issues_count}'"));
    expect(migration, contains('get_manager_reports_center_base'));
  });
}
