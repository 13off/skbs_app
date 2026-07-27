import '../data/manager_reports_repository.dart';

String managerReportDateText(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

String managerReportMoney(num value) {
  final integer = value.round().toString();
  final chunks = <String>[];
  for (var index = integer.length; index > 0; index -= 3) {
    final start = index - 3 < 0 ? 0 : index - 3;
    chunks.insert(0, integer.substring(start, index));
  }
  return '${chunks.join(' ')} ₽';
}

String managerReportPercent(double value) {
  final rounded = value.roundToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$rounded%';
}

String managerReportRunStatus(String status) {
  return switch (status) {
    'sent' => 'Готов',
    'processing' => 'Формируется',
    'failed' => 'Ошибка',
    'pending' => 'Ожидает',
    _ => status,
  };
}

class ManagerReportAnalysis {
  const ManagerReportAnalysis._();

  static List<String> lines(ManagerReportsCenter center) {
    final lines = <String>[];
    final metrics = center.metrics;
    final trend = center.trend;
    final taskRate = trend.tasksDoneRate;
    final yesterdayRate = trend.tasksYesterdayDoneRate;
    final weekRate = trend.tasksWeekDoneRate;
    final attendanceMissing = metrics.attendance.missing;
    final yesterdayMissing = trend.attendanceMissingYesterday;
    final missingReceipts = metrics.payments.monthMissingReceipts;
    final legalAttention = metrics.legal.overdue + metrics.legal.highRisk;
    final milestoneOverdue = metrics.milestones.overdue;

    if (metrics.tasks.total == 0) {
      lines.add('На выбранную дату задачи не заведены.');
    } else if (taskRate < yesterdayRate) {
      lines.add(
        'Выполнение задач снизилось: ${managerReportPercent(taskRate)} '
        'против ${managerReportPercent(yesterdayRate)} вчера.',
      );
    } else if (taskRate > yesterdayRate) {
      lines.add(
        'Выполнение задач выросло: ${managerReportPercent(taskRate)} '
        'против ${managerReportPercent(yesterdayRate)} вчера.',
      );
    } else {
      lines.add(
        'Выполнение задач: ${managerReportPercent(taskRate)}; '
        'среднее за 7 дней — ${managerReportPercent(weekRate)}.',
      );
    }

    if (attendanceMissing == 0) {
      lines.add('Табель заполнен по всем активным сотрудникам.');
    } else {
      final direction = attendanceMissing < yesterdayMissing
          ? 'меньше, чем вчера'
          : attendanceMissing > yesterdayMissing
              ? 'больше, чем вчера'
              : 'столько же, сколько вчера';
      lines.add('Без отметки в табеле: $attendanceMissing — $direction.');
    }

    if (missingReceipts > 0) {
      lines.add('Выплаты без прикреплённых чеков: $missingReceipts.');
    }
    if (legalAttention > 0) {
      lines.add(
        'Юридических просрочек и вопросов высокого риска: $legalAttention.',
      );
    }
    if (milestoneOverdue > 0) {
      lines.add('Просроченных этапов объекта: $milestoneOverdue.');
    }
    if (center.criticalCount == 0) {
      lines.add('Критичных отклонений в выбранных разделах нет.');
    }
    return lines;
  }
}
