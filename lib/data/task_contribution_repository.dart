import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_assignee_repository.dart';

class TaskContributionEntry {
  final String employeeId;
  final String employeeName;
  final String position;
  final int percent;

  const TaskContributionEntry({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.percent,
  });

  TaskContributionEntry copyWith({int? percent}) {
    return TaskContributionEntry(
      employeeId: employeeId,
      employeeName: employeeName,
      position: position,
      percent: percent ?? this.percent,
    );
  }
}

class TaskContributionDraft {
  final List<TaskContributionEntry> entries;
  final bool hasSavedExactDistribution;

  const TaskContributionDraft({
    required this.entries,
    required this.hasSavedExactDistribution,
  });
}

class EmployeeContributionHistoryRow {
  final String taskId;
  final DateTime date;
  final String objectName;
  final String axes;
  final String work;
  final int percent;

  const EmployeeContributionHistoryRow({
    required this.taskId,
    required this.date,
    required this.objectName,
    required this.axes,
    required this.work,
    required this.percent,
  });

  factory EmployeeContributionHistoryRow.fromMap(Map<String, dynamic> map) {
    return EmployeeContributionHistoryRow(
      taskId: map['task_id']?.toString() ?? '',
      date:
          DateTime.tryParse(map['task_date']?.toString() ?? '') ??
          DateTime.now(),
      objectName: map['object_name']?.toString().trim() ?? '',
      axes: map['axes']?.toString().trim() ?? '',
      work: map['work']?.toString().trim() ?? '',
      percent: _intValue(map['percent']),
    );
  }
}

class EmployeeContributionSummary {
  final int taskCount;
  final int totalPercent;
  final double equivalentTasks;
  final double averagePercent;
  final int objectTaskCount;
  final double objectSharePercent;
  final List<EmployeeContributionHistoryRow> history;

  const EmployeeContributionSummary({
    required this.taskCount,
    required this.totalPercent,
    required this.equivalentTasks,
    required this.averagePercent,
    required this.objectTaskCount,
    required this.objectSharePercent,
    required this.history,
  });

  const EmployeeContributionSummary.empty()
    : taskCount = 0,
      totalPercent = 0,
      equivalentTasks = 0,
      averagePercent = 0,
      objectTaskCount = 0,
      objectSharePercent = 0,
      history = const <EmployeeContributionHistoryRow>[];

  factory EmployeeContributionSummary.fromMap(Map<String, dynamic> map) {
    final rawHistory = map['history'];
    return EmployeeContributionSummary(
      taskCount: _intValue(map['task_count']),
      totalPercent: _intValue(map['total_percent']),
      equivalentTasks: _doubleValue(map['equivalent_tasks']),
      averagePercent: _doubleValue(map['average_percent']),
      objectTaskCount: _intValue(map['object_task_count']),
      objectSharePercent: _doubleValue(map['object_share_percent']),
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (row) => EmployeeContributionHistoryRow.fromMap(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <EmployeeContributionHistoryRow>[],
    );
  }
}

abstract final class TaskContributionRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<TaskContributionDraft> fetchDraft(String taskId) async {
    final results = await Future.wait<dynamic>([
      TaskAssigneeRepository.fetchAssignees(taskId),
      _client.rpc<dynamic>(
        'get_task_contributions',
        params: <String, dynamic>{'p_task_id': taskId},
      ),
    ]);
    final assignees = results[0] as List<TaskAssigneeData>;
    final rawSaved = results[1];
    final saved = <String, int>{};
    if (rawSaved is List) {
      for (final raw in rawSaved.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final employeeId = row['employee_id']?.toString().trim() ?? '';
        if (employeeId.isNotEmpty) {
          saved[employeeId] = _intValue(row['contribution_percent']);
        }
      }
    }

    final assigneeIds = assignees.map((item) => item.employeeId).toSet();
    final savedTotal = saved.values.fold<int>(0, (sum, value) => sum + value);
    final exact =
        assignees.isNotEmpty &&
        saved.length == assignees.length &&
        saved.keys.toSet().containsAll(assigneeIds) &&
        assigneeIds.containsAll(saved.keys) &&
        savedTotal == 100;
    final equal = equalPercents(assignees.length);
    final entries = <TaskContributionEntry>[
      for (var index = 0; index < assignees.length; index++)
        TaskContributionEntry(
          employeeId: assignees[index].employeeId,
          employeeName: assignees[index].employeeName,
          position: assignees[index].position,
          percent: exact ? saved[assignees[index].employeeId]! : equal[index],
        ),
    ];
    return TaskContributionDraft(
      entries: entries,
      hasSavedExactDistribution: exact,
    );
  }

  static List<int> equalPercents(int count) {
    if (count <= 0) return const <int>[];
    final base = 100 ~/ count;
    final remainder = 100 % count;
    return List<int>.generate(
      count,
      (index) => base + (index < remainder ? 1 : 0),
      growable: false,
    );
  }

  static Future<void> save({
    required String taskId,
    required List<TaskContributionEntry> entries,
  }) {
    return _client.rpc<void>(
      'save_task_contributions',
      params: <String, dynamic>{
        'p_task_id': taskId,
        'p_contributions': <Map<String, dynamic>>[
          for (final entry in entries)
            <String, dynamic>{
              'employee_id': entry.employeeId,
              'percent': entry.percent,
            },
        ],
      },
    );
  }

  static Future<void> clear(String taskId) {
    return _client.rpc<void>(
      'clear_task_contributions',
      params: <String, dynamic>{'p_task_id': taskId},
    );
  }

  static Future<EmployeeContributionSummary> fetchEmployeeSummary({
    required String employeeId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final raw = await _client.rpc<dynamic>(
      'get_employee_contribution_summary',
      params: <String, dynamic>{
        'p_employee_id': employeeId,
        'p_date_from': dateFrom == null ? null : _dateKey(dateFrom),
        'p_date_to': dateTo == null ? null : _dateKey(dateTo),
      },
    );
    if (raw is Map) {
      return EmployeeContributionSummary.fromMap(
        Map<String, dynamic>.from(raw),
      );
    }
    return const EmployeeContributionSummary.empty();
  }

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
