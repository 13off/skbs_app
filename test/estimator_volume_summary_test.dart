import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/estimator/models/estimator_volume_summary.dart';
import 'package:skbs_app/features/estimator/models/task_completion_report.dart';

TaskCompletionReport report({
  required String id,
  required DateTime taskDate,
  required double? quantity,
  String objectName = 'Мурманск',
  String work = 'Бетонирование стен',
  String unit = 'м³',
}) {
  return TaskCompletionReport(
    id: id,
    taskId: 'task-$id',
    reportedQuantity: quantity,
    unit: unit,
    workLocation: '',
    completionComment: '',
    reviewStatus: 'approved',
    approvedQuantity: quantity,
    reviewComment: '',
    submittedByName: 'Мастер',
    submittedAt: taskDate,
    reviewedByName: 'Сметчик',
    reviewedAt: taskDate,
    taskDate: taskDate,
    objectName: objectName,
    axes: '',
    work: work,
  );
}

void main() {
  test('normalizes common construction units', () {
    expect(EstimatorVolumeSummary.normalizeUnit('м3'), 'м³');
    expect(EstimatorVolumeSummary.normalizeUnit(' м^2 '), 'м²');
    expect(EstimatorVolumeSummary.normalizeUnit('мп'), 'м.п.');
    expect(EstimatorVolumeSummary.normalizeUnit('тонны'), 'т');
    expect(EstimatorVolumeSummary.normalizeUnit('шт'), 'шт.');
  });

  test('builds previous, period and cumulative quantities', () {
    final summaries = EstimatorVolumeSummary.build(
      period: DateTime(2026, 9),
      reports: <TaskCompletionReport>[
        report(
          id: '1',
          taskDate: DateTime(2026, 8, 20),
          quantity: 2,
          unit: 'м3',
        ),
        report(
          id: '2',
          taskDate: DateTime(2026, 9, 2),
          quantity: 3.5,
          unit: 'м³',
        ),
        report(
          id: '3',
          taskDate: DateTime(2026, 10, 1),
          quantity: 4,
          unit: 'м³',
        ),
      ],
    );

    expect(summaries, hasLength(1));
    final summary = summaries.single;
    expect(summary.previousQuantity, 2);
    expect(summary.periodQuantity, 3.5);
    expect(summary.totalQuantity, 5.5);
    expect(summary.sourceCount, 2);
    expect(summary.unit, 'м³');
  });

  test('keeps different work names and units as separate positions', () {
    final summaries = EstimatorVolumeSummary.build(
      period: DateTime(2026, 9),
      reports: <TaskCompletionReport>[
        report(
          id: '1',
          taskDate: DateTime(2026, 9, 1),
          quantity: 10,
          work: 'Армирование стен',
          unit: 'т',
        ),
        report(
          id: '2',
          taskDate: DateTime(2026, 9, 2),
          quantity: 12,
          work: 'Бетонирование стен',
          unit: 'м³',
        ),
      ],
    );

    expect(summaries, hasLength(2));
  });

  test('filters cumulative statement by object', () {
    final summaries = EstimatorVolumeSummary.build(
      period: DateTime(2026, 9),
      objectFilter: 'Мурманск',
      reports: <TaskCompletionReport>[
        report(
          id: '1',
          taskDate: DateTime(2026, 9, 1),
          quantity: 10,
          objectName: 'Мурманск',
        ),
        report(
          id: '2',
          taskDate: DateTime(2026, 9, 2),
          quantity: 12,
          objectName: 'Талнах',
        ),
      ],
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.objectName, 'Мурманск');
  });
}
