import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/estimator/models/estimator_manual_volume.dart';
import 'package:skbs_app/features/estimator/models/estimator_volume_summary.dart';
import 'package:skbs_app/features/estimator/models/task_completion_report.dart';

EstimatorManualVolume manual({
  required String id,
  required DateTime date,
  required double quantity,
  DateTime? voidedAt,
  String objectName = 'Мурманск',
  String work = 'Бетонирование стен',
  String unit = 'м³',
}) {
  return EstimatorManualVolume(
    id: id,
    objectName: objectName,
    work: work,
    unit: unit,
    quantity: quantity,
    workDate: date,
    reasonCode: 'task_missing',
    reasonComment: 'Работа выполнена без задачи мастера',
    createdByName: 'Сметчик',
    createdAt: date,
    voidedAt: voidedAt,
    voidedByName: voidedAt == null ? '' : 'Сметчик',
    voidReason: voidedAt == null ? '' : 'Дубль',
  );
}

TaskCompletionReport taskReport({
  required String id,
  required DateTime date,
  required double quantity,
}) {
  return TaskCompletionReport(
    id: id,
    taskId: 'task-$id',
    reportedQuantity: quantity,
    unit: 'м³',
    workLocation: '',
    completionComment: '',
    reviewStatus: 'approved',
    approvedQuantity: quantity,
    reviewComment: '',
    submittedByName: 'Мастер',
    submittedAt: date,
    reviewedByName: 'Сметчик',
    reviewedAt: date,
    taskDate: date,
    objectName: 'Мурманск',
    axes: '',
    work: 'Бетонирование стен',
  );
}

void main() {
  test('active manual volume joins cumulative task quantity', () {
    final summaries = EstimatorVolumeSummary.build(
      period: DateTime(2026, 9),
      reports: <TaskCompletionReport>[
        taskReport(id: 'task', date: DateTime(2026, 9, 2), quantity: 10),
      ],
      manualVolumes: <EstimatorManualVolume>[
        manual(id: 'manual', date: DateTime(2026, 9, 3), quantity: 2.5),
      ],
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.periodQuantity, 12.5);
    expect(summaries.single.sourceCount, 2);
    expect(summaries.single.manualSourceCount, 1);
  });

  test('voided manual volume never affects cumulative quantity', () {
    final summaries = EstimatorVolumeSummary.build(
      period: DateTime(2026, 9),
      reports: const <TaskCompletionReport>[],
      manualVolumes: <EstimatorManualVolume>[
        manual(
          id: 'voided',
          date: DateTime(2026, 9, 3),
          quantity: 8,
          voidedAt: DateTime(2026, 9, 4),
        ),
      ],
    );

    expect(summaries, isEmpty);
  });

  test('manual volume backend is append-only with reasoned voiding', () {
    final migration = File(
      'supabase/migrations/20260908103000_add_estimator_manual_volumes.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/estimator/data/estimator_manual_volume_repository.dart',
    ).readAsStringSync();
    final approvedFeed = File(
      'lib/features/estimator/data/task_completion_report_repository.dart',
    ).readAsStringSync();

    expect(migration, contains('create table if not exists public.estimator_manual_volumes'));
    expect(migration, contains('reason_comment text not null'));
    expect(migration, contains('void_reason text not null'));
    expect(migration, contains('create or replace function public.add_estimator_manual_volume'));
    expect(migration, contains('create or replace function public.void_estimator_manual_volume'));
    expect(migration, contains('revoke insert, update, delete'));
    expect(repository, contains("'void_estimator_manual_volume'"));
    expect(approvedFeed, contains("cleanStatus == 'approved'"));
    expect(approvedFeed, contains('if (manual.isVoided) continue;'));
    expect(approvedFeed, contains("id: 'manual:\${manual.id}'"));
  });
}
