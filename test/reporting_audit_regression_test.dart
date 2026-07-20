import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/reports/data/manager_reports_repository.dart';

void main() {
  test('центр отчётов различает критичные вопросы и внимание', () {
    final center = ManagerReportsCenter.fromJson(<String, dynamic>{
      'report_date': '2026-07-20',
      'objects': <dynamic>[],
      'metrics': <String, dynamic>{
        'critical_count': 2,
        'attention_count': 7,
        'payments': <String, dynamic>{
          'missing_receipts': 1,
          'missing_receipts_day': 1,
          'missing_receipts_month': 6,
        },
      },
      'trend': <String, dynamic>{},
      'details': <String, dynamic>{},
      'dispatcher_runs': <dynamic>[],
    });

    expect(center.criticalCount, 2);
    expect(center.attentionCount, 7);
    expect(center.metric('payments', 'missing_receipts_day'), 1);
    expect(center.metric('payments', 'missing_receipts_month'), 6);
  });

  test('миграция сохраняет совместимость и закрывает аудит', () {
    final migration = File(
      'supabase/migrations/20260720124500_stabilize_reporting_and_audit.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists marked_by_user_id'));
    expect(migration, contains('attendance_set_actor_before_write'));
    expect(migration, contains("'missing_receipts_day'"));
    expect(migration, contains("'missing_receipts_month'"));
    expect(migration, contains("'attention_count'"));
    expect(
      migration,
      contains('revoke all on function public.validate_task_milestone_link()'),
    );
  });

  test('realtime знает о сводках и этапах', () {
    final sync = File('lib/data/app_data_sync.dart').readAsStringSync();

    expect(sync, contains("case 'dispatcher_summary_runs':"));
    expect(sync, contains("case 'dispatcher_summary_settings':"));
    expect(sync, contains("case 'task_milestone_links':"));
    expect(sync, contains("case 'project_milestones':"));
    expect(sync, contains("case 'milestone_checklist_items':"));
  });
}
