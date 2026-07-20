import '../../dispatcher/data/dispatcher_summary_repository.dart';

class ManagerReportObjectOption {
  final String id;
  final String name;
  final String address;

  const ManagerReportObjectOption({
    required this.id,
    required this.name,
    required this.address,
  });

  factory ManagerReportObjectOption.fromJson(Map<String, dynamic> json) {
    return ManagerReportObjectOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class ManagerReportDetailItem {
  final String id;
  final String title;
  final String subtitle;
  final String note;

  const ManagerReportDetailItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.note,
  });

  factory ManagerReportDetailItem.fromJson(Map<String, dynamic> json) {
    return ManagerReportDetailItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Запись',
      subtitle: json['subtitle']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class ManagerAttendanceMetrics {
  final int active;
  final int marked;
  final int missing;
  final double shifts;

  const ManagerAttendanceMetrics({
    required this.active,
    required this.marked,
    required this.missing,
    required this.shifts,
  });

  factory ManagerAttendanceMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerAttendanceMetrics(
      active: _asInt(json['active']),
      marked: _asInt(json['marked']),
      missing: _asInt(json['missing']),
      shifts: _asDouble(json['shifts']),
    );
  }
}

class ManagerEmployeeMetrics {
  final int active;
  final int added;
  final int archived;

  const ManagerEmployeeMetrics({
    required this.active,
    required this.added,
    required this.archived,
  });

  factory ManagerEmployeeMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerEmployeeMetrics(
      active: _asInt(json['active']),
      added: _asInt(json['added']),
      archived: _asInt(json['archived']),
    );
  }
}

class ManagerTaskMetrics {
  final int total;
  final int done;
  final int pending;
  final int problem;

  const ManagerTaskMetrics({
    required this.total,
    required this.done,
    required this.pending,
    required this.problem,
  });

  factory ManagerTaskMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerTaskMetrics(
      total: _asInt(json['total']),
      done: _asInt(json['done']),
      pending: _asInt(json['pending']),
      problem: _asInt(json['problem']),
    );
  }
}

class ManagerPaymentMetrics {
  final int monthCount;
  final double monthAmount;
  final int dayCount;
  final int dayMissingReceipts;
  final int monthMissingReceipts;

  const ManagerPaymentMetrics({
    required this.monthCount,
    required this.monthAmount,
    required this.dayCount,
    required this.dayMissingReceipts,
    required this.monthMissingReceipts,
  });

  factory ManagerPaymentMetrics.fromJson(Map<String, dynamic> json) {
    final legacyMissing = _asInt(json['missing_receipts']);
    return ManagerPaymentMetrics(
      monthCount: _asInt(json['month_count']),
      monthAmount: _asDouble(json['month_amount']),
      dayCount: _asInt(json['day_count']),
      dayMissingReceipts: json.containsKey('missing_receipts_day')
          ? _asInt(json['missing_receipts_day'])
          : legacyMissing,
      monthMissingReceipts: json.containsKey('missing_receipts_month')
          ? _asInt(json['missing_receipts_month'])
          : legacyMissing,
    );
  }
}

class ManagerRecruitmentMetrics {
  final int active;
  final int newCount;
  final int incomingMessages;

  const ManagerRecruitmentMetrics({
    required this.active,
    required this.newCount,
    required this.incomingMessages,
  });

  factory ManagerRecruitmentMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerRecruitmentMetrics(
      active: _asInt(json['active']),
      newCount: _asInt(json['new']),
      incomingMessages: _asInt(json['incoming_messages']),
    );
  }
}

class ManagerLegalMetrics {
  final int open;
  final int overdue;
  final int highRisk;
  final int expiringDocuments;

  const ManagerLegalMetrics({
    required this.open,
    required this.overdue,
    required this.highRisk,
    required this.expiringDocuments,
  });

  factory ManagerLegalMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerLegalMetrics(
      open: _asInt(json['open']),
      overdue: _asInt(json['overdue']),
      highRisk: _asInt(json['high_risk']),
      expiringDocuments: _asInt(json['expiring_documents']),
    );
  }
}

class ManagerMilestoneMetrics {
  final int open;
  final int overdue;
  final int upcoming;

  const ManagerMilestoneMetrics({
    required this.open,
    required this.overdue,
    required this.upcoming,
  });

  factory ManagerMilestoneMetrics.fromJson(Map<String, dynamic> json) {
    return ManagerMilestoneMetrics(
      open: _asInt(json['open']),
      overdue: _asInt(json['overdue']),
      upcoming: _asInt(json['upcoming']),
    );
  }
}

class ManagerReportMetrics {
  final ManagerAttendanceMetrics attendance;
  final ManagerEmployeeMetrics employees;
  final ManagerTaskMetrics tasks;
  final ManagerPaymentMetrics payments;
  final ManagerRecruitmentMetrics recruitment;
  final ManagerLegalMetrics legal;
  final ManagerMilestoneMetrics milestones;
  final int issuesCount;
  final int criticalOnlyCount;
  final int attentionCount;

  const ManagerReportMetrics({
    required this.attendance,
    required this.employees,
    required this.tasks,
    required this.payments,
    required this.recruitment,
    required this.legal,
    required this.milestones,
    required this.issuesCount,
    required this.criticalOnlyCount,
    required this.attentionCount,
  });

  factory ManagerReportMetrics.fromJson(Map<String, dynamic> json) {
    final legacyCritical = _asInt(json['critical_count']);
    return ManagerReportMetrics(
      attendance: ManagerAttendanceMetrics.fromJson(_map(json['attendance'])),
      employees: ManagerEmployeeMetrics.fromJson(_map(json['employees'])),
      tasks: ManagerTaskMetrics.fromJson(_map(json['tasks'])),
      payments: ManagerPaymentMetrics.fromJson(_map(json['payments'])),
      recruitment: ManagerRecruitmentMetrics.fromJson(
        _map(json['recruitment']),
      ),
      legal: ManagerLegalMetrics.fromJson(_map(json['legal'])),
      milestones: ManagerMilestoneMetrics.fromJson(_map(json['milestones'])),
      issuesCount: json.containsKey('issues_count')
          ? _asInt(json['issues_count'])
          : legacyCritical,
      criticalOnlyCount: json.containsKey('critical_only_count')
          ? _asInt(json['critical_only_count'])
          : legacyCritical,
      attentionCount: _asInt(json['attention_count']),
    );
  }

  int legacyIntValue(String sectionKey, String valueKey) {
    return switch ((sectionKey, valueKey)) {
      ('attendance', 'active') => attendance.active,
      ('attendance', 'marked') => attendance.marked,
      ('attendance', 'missing') => attendance.missing,
      ('employees', 'active') => employees.active,
      ('employees', 'added') => employees.added,
      ('employees', 'archived') => employees.archived,
      ('tasks', 'total') => tasks.total,
      ('tasks', 'done') => tasks.done,
      ('tasks', 'pending') => tasks.pending,
      ('tasks', 'problem') => tasks.problem,
      ('payments', 'month_count') => payments.monthCount,
      ('payments', 'day_count') => payments.dayCount,
      ('payments', 'missing_receipts') => payments.monthMissingReceipts,
      ('payments', 'missing_receipts_day') => payments.dayMissingReceipts,
      ('payments', 'missing_receipts_month') => payments.monthMissingReceipts,
      ('recruitment', 'active') => recruitment.active,
      ('recruitment', 'new') => recruitment.newCount,
      ('recruitment', 'incoming_messages') => recruitment.incomingMessages,
      ('legal', 'open') => legal.open,
      ('legal', 'overdue') => legal.overdue,
      ('legal', 'high_risk') => legal.highRisk,
      ('legal', 'expiring_documents') => legal.expiringDocuments,
      ('milestones', 'open') => milestones.open,
      ('milestones', 'overdue') => milestones.overdue,
      ('milestones', 'upcoming') => milestones.upcoming,
      _ => 0,
    };
  }

  double legacyDecimalValue(String sectionKey, String valueKey) {
    return switch ((sectionKey, valueKey)) {
      ('attendance', 'shifts') => attendance.shifts,
      ('payments', 'month_amount') => payments.monthAmount,
      _ => legacyIntValue(sectionKey, valueKey).toDouble(),
    };
  }
}

class ManagerReportTrend {
  final double tasksDoneRate;
  final double tasksYesterdayDoneRate;
  final double tasksWeekDoneRate;
  final int attendanceMissingYesterday;

  const ManagerReportTrend({
    required this.tasksDoneRate,
    required this.tasksYesterdayDoneRate,
    required this.tasksWeekDoneRate,
    required this.attendanceMissingYesterday,
  });

  factory ManagerReportTrend.fromJson(Map<String, dynamic> json) {
    return ManagerReportTrend(
      tasksDoneRate: _asDouble(json['tasks_done_rate']),
      tasksYesterdayDoneRate: _asDouble(
        json['tasks_yesterday_done_rate'],
      ),
      tasksWeekDoneRate: _asDouble(json['tasks_week_done_rate']),
      attendanceMissingYesterday: _asInt(
        json['attendance_missing_yesterday'],
      ),
    );
  }

  double legacyValue(String key) {
    return switch (key) {
      'tasks_done_rate' => tasksDoneRate,
      'tasks_yesterday_done_rate' => tasksYesterdayDoneRate,
      'tasks_week_done_rate' => tasksWeekDoneRate,
      'attendance_missing_yesterday' =>
        attendanceMissingYesterday.toDouble(),
      _ => 0,
    };
  }
}

class ManagerReportsCenter {
  final DateTime reportDate;
  final ManagerReportObjectOption? selectedObject;
  final List<ManagerReportObjectOption> objects;
  final ManagerReportMetrics metrics;
  final ManagerReportTrend trend;
  final Map<String, List<ManagerReportDetailItem>> details;
  final List<DispatcherSummaryRun> dispatcherRuns;

  const ManagerReportsCenter({
    required this.reportDate,
    required this.selectedObject,
    required this.objects,
    required this.metrics,
    required this.trend,
    required this.details,
    required this.dispatcherRuns,
  });

  factory ManagerReportsCenter.fromJson(Map<String, dynamic> json) {
    final selected = _map(json['selected_object']);
    final rawDetails = _map(json['details']);
    final parsedDetails = <String, List<ManagerReportDetailItem>>{};
    for (final entry in rawDetails.entries) {
      parsedDetails[entry.key] = _list(entry.value)
          .map((item) => ManagerReportDetailItem.fromJson(_map(item)))
          .toList();
    }

    return ManagerReportsCenter(
      reportDate:
          DateTime.tryParse(json['report_date']?.toString() ?? '') ??
              DateTime.now(),
      selectedObject: selected.isEmpty
          ? null
          : ManagerReportObjectOption.fromJson(selected),
      objects: _list(json['objects'])
          .map((item) => ManagerReportObjectOption.fromJson(_map(item)))
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(),
      metrics: ManagerReportMetrics.fromJson(_map(json['metrics'])),
      trend: ManagerReportTrend.fromJson(_map(json['trend'])),
      details: parsedDetails,
      dispatcherRuns: _list(json['dispatcher_runs'])
          .map((item) => DispatcherSummaryRun.fromJson(_map(item)))
          .toList(),
    );
  }

  int get criticalCount => metrics.issuesCount;

  int get criticalOnlyCount => metrics.criticalOnlyCount;

  int get attentionCount => metrics.attentionCount;

  @Deprecated('Используйте типизированное поле metrics.')
  int metric(String sectionKey, String valueKey) {
    return metrics.legacyIntValue(sectionKey, valueKey);
  }

  @Deprecated('Используйте типизированное поле metrics.')
  double decimalMetric(String sectionKey, String valueKey) {
    return metrics.legacyDecimalValue(sectionKey, valueKey);
  }

  @Deprecated('Используйте типизированное поле trend.')
  double trendValue(String key) => trend.legacyValue(key);

  @Deprecated('Используйте типизированное поле trend.')
  int trendInt(String key) => trend.legacyValue(key).round();

  List<ManagerReportDetailItem> detailItems(String key) {
    return details[key] ?? const <ManagerReportDetailItem>[];
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
