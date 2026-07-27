import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/reports/data/manager_reports_repository.dart';
import 'package:skbs_app/features/reports/presentation/manager_report_formatters.dart';

void main() {
  ManagerReportsCenter center({
    required Map<String, dynamic> metrics,
    required Map<String, dynamic> trend,
  }) {
    return ManagerReportsCenter.fromJson(<String, dynamic>{
      'report_date': '2026-07-20',
      'metrics': metrics,
      'trend': trend,
      'details': <String, dynamic>{},
      'objects': <dynamic>[],
      'dispatcher_runs': <dynamic>[],
    });
  }

  test('анализ отчёта формирует понятные отклонения', () {
    final report = center(
      metrics: <String, dynamic>{
        'issues_count': 6,
        'tasks': <String, dynamic>{'total': 10},
        'attendance': <String, dynamic>{'missing': 2},
        'payments': <String, dynamic>{
          'missing_receipts': 3,
          'missing_receipts_day': 1,
          'missing_receipts_month': 3,
        },
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

  test('серверный JSON разбирается в отдельные секции метрик', () {
    final report = center(
      metrics: <String, dynamic>{
        'issues_count': 9,
        'critical_only_count': 4,
        'attention_count': 5,
        'attendance': <String, dynamic>{
          'active': 54,
          'marked': 50,
          'missing': 4,
          'shifts': 48.5,
        },
        'employees': <String, dynamic>{
          'active': 54,
          'added': 2,
          'archived': 1,
        },
        'tasks': <String, dynamic>{
          'total': 12,
          'done': 7,
          'pending': 5,
          'problem': 2,
        },
        'payments': <String, dynamic>{
          'month_count': 76,
          'month_amount': 123456.5,
          'day_count': 3,
          'missing_receipts_day': 1,
          'missing_receipts_month': 11,
        },
        'recruitment': <String, dynamic>{
          'active': 6,
          'new': 2,
          'incoming_messages': 4,
        },
        'legal': <String, dynamic>{
          'open': 3,
          'overdue': 1,
          'high_risk': 2,
          'expiring_documents': 5,
        },
        'milestones': <String, dynamic>{
          'open': 8,
          'overdue': 2,
          'upcoming': 3,
        },
      },
      trend: <String, dynamic>{
        'tasks_done_rate': 58.3,
        'tasks_yesterday_done_rate': 50,
        'tasks_week_done_rate': 61,
        'attendance_missing_yesterday': 6,
      },
    );

    expect(report.metrics.attendance.active, 54);
    expect(report.metrics.attendance.shifts, 48.5);
    expect(report.metrics.tasks.pending, 5);
    expect(report.metrics.payments.monthMissingReceipts, 11);
    expect(report.metrics.payments.dayMissingReceipts, 1);
    expect(report.metrics.recruitment.newCount, 2);
    expect(report.metrics.legal.highRisk, 2);
    expect(report.metrics.milestones.upcoming, 3);
    expect(report.metrics.issuesCount, 9);
    expect(report.metrics.criticalOnlyCount, 4);
    expect(report.metrics.attentionCount, 5);
    expect(report.trend.tasksDoneRate, 58.3);
    expect(report.trend.attendanceMissingYesterday, 6);
  });

  test('форматирование отчёта стабильно для даты, денег и процентов', () {
    expect(managerReportDateText(DateTime(2026, 7, 3)), '03.07.2026');
    expect(managerReportMoney(1234567), '1 234 567 ₽');
    expect(managerReportPercent(87.5), '87.5%');
    expect(managerReportRunStatus('processing'), 'Формируется');
  });
}
