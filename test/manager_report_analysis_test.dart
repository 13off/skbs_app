import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/reports/data/manager_reports_repository.dart';
import 'package:skbs_app/features/reports/presentation/manager_report_formatters.dart';

void main() {
  ManagerReportsCenter center({
    required Map<String, dynamic> metrics,
    required Map<String, dynamic> trend,
  }) {
    return ManagerReportsCenter(
      reportDate: DateTime(2026, 7, 20),
      selectedObject: null,
      objects: const <ManagerReportObjectOption>[],
      metrics: metrics,
      trend: trend,
      details: const <String, List<ManagerReportDetailItem>>{},
      dispatcherRuns: const [],
    );
  }

  test('анализ отчёта формирует понятные отклонения', () {
    final report = center(
      metrics: <String, dynamic>{
        'issues_count': 6,
        'tasks': <String, dynamic>{'total': 10},
        'attendance': <String, dynamic>{'missing': 2},
        'payments': <String, dynamic>{'missing_receipts': 3},
        'legal': <String, dynamic>{'overdue': 1, 'high_risk': 0},
        'milestones': <String, dynamic>{'overdue': 0},
      },
      trend: <String, dynamic>{
        'tasks_done_rate': 80,
        'tasks_yesterday_done_rate': 70,
        'tasks_week_done_rate': 75,
        'attendance_missing_yesterday': 4,
      },
    );

    final lines = ManagerReportAnalysis.lines(report);

    expect(lines, contains('Выполнение задач выросло: 80% против 70% вчера.'));
    expect(lines, contains('Без отметки в табеле: 2 — меньше, чем вчера.'));
    expect(lines, contains('Выплаты без прикреплённых чеков: 3.'));
    expect(
      lines,
      contains('Юридических просрочек и вопросов высокого риска: 1.'),
    );
    expect(
      lines,
      isNot(contains('Критичных отклонений в выбранных разделах нет.')),
    );
  });

  test('анализ показывает спокойное состояние без проблем', () {
    final report = center(
      metrics: <String, dynamic>{
        'issues_count': 0,
        'tasks': <String, dynamic>{'total': 0},
        'attendance': <String, dynamic>{'missing': 0},
        'payments': <String, dynamic>{'missing_receipts': 0},
        'legal': <String, dynamic>{'overdue': 0, 'high_risk': 0},
        'milestones': <String, dynamic>{'overdue': 0},
      },
      trend: <String, dynamic>{
        'tasks_done_rate': 0,
        'tasks_yesterday_done_rate': 0,
        'tasks_week_done_rate': 0,
        'attendance_missing_yesterday': 0,
      },
    );

    final lines = ManagerReportAnalysis.lines(report);

    expect(lines, contains('На выбранную дату задачи не заведены.'));
    expect(lines, contains('Табель заполнен по всем активным сотрудникам.'));
    expect(lines, contains('Критичных отклонений в выбранных разделах нет.'));
  });

  test('форматирование отчёта стабильно для даты, денег и процентов', () {
    expect(managerReportDateText(DateTime(2026, 7, 3)), '03.07.2026');
    expect(managerReportMoney(1234567), '1 234 567 ₽');
    expect(managerReportPercent(87.5), '87.5%');
    expect(managerReportRunStatus('processing'), 'Формируется');
  });
}
