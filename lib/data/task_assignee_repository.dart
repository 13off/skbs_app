import 'package:supabase_flutter/supabase_flutter.dart';

class TaskAssigneeData {
  final String employeeId;
  final String employeeName;
  final String position;

  const TaskAssigneeData({
    required this.employeeId,
    required this.employeeName,
    required this.position,
  });

  factory TaskAssigneeData.fromSupabase(Map<String, dynamic> json) {
    final employeeRaw = json['employees'];
    final employee = employeeRaw is Map<String, dynamic>
        ? employeeRaw
        : <String, dynamic>{};

    return TaskAssigneeData(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: employee['fio']?.toString() ?? 'Сотрудник',
      position: employee['position']?.toString() ?? '',
    );
  }
}

class TaskAssigneeRepository {
  TaskAssigneeRepository._();

  static final _client = Supabase.instance.client;

  static Future<List<TaskAssigneeData>> fetchAssignees(String taskId) async {
    final rows = await _client
        .from('task_assignees')
        .select('employee_id, employees(fio, position)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);

    return rows
        .map<TaskAssigneeData>((row) => TaskAssigneeData.fromSupabase(row))
        .toList();
  }

  static Future<List<String>> fetchAssigneeIds(String taskId) async {
    final rows = await _client
        .from('task_assignees')
        .select('employee_id')
        .eq('task_id', taskId);

    return rows
        .map<String>((row) => row['employee_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  static Set<String> cleanIdSet(Iterable<String> assigneeIds) {
    return assigneeIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool sameIds(
    Iterable<String> firstIds,
    Iterable<String> secondIds,
  ) {
    final first = cleanIdSet(firstIds);
    final second = cleanIdSet(secondIds);
    if (first.length != second.length) return false;
    return first.every(second.contains);
  }

  static Future<void> saveAssignees({
    required String taskId,
    required Iterable<String> assigneeIds,
  }) async {
    await _client.from('task_assignees').delete().eq('task_id', taskId);

    final cleanIds = cleanIdSet(assigneeIds);
    if (cleanIds.isEmpty) return;

    final rows = cleanIds
        .map((employeeId) => <String, dynamic>{
              'task_id': taskId,
              'employee_id': employeeId,
            })
        .toList();
    await _client.from('task_assignees').insert(rows);
  }

  static Future<void> saveIfChanged({
    required String taskId,
    required Iterable<String> previousAssigneeIds,
    required Iterable<String> nextAssigneeIds,
  }) async {
    if (sameIds(previousAssigneeIds, nextAssigneeIds)) return;

    await saveAssignees(
      taskId: taskId,
      assigneeIds: cleanIdSet(nextAssigneeIds),
    );
  }
}
