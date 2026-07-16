import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/task_repository.dart';
import '../../../models/task_item_data.dart';

class ForemanTaskMeta {
  final List<TaskAssigneeData> assignees;
  final int photoCount;

  const ForemanTaskMeta({
    this.assignees = const <TaskAssigneeData>[],
    this.photoCount = 0,
  });

  String get assigneeTitle {
    if (assignees.isEmpty) return 'Не назначены';
    return assignees.map((item) => item.employeeName).join(', ');
  }
}

abstract final class ForemanWorkspaceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static String _dateKey(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String? _cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static List<String> _cleanTaskIds(Iterable<String?> values) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<List<TaskItemData>> fetchOverdueTasks({
    required DateTime beforeDate,
    String? objectName,
    int limit = 40,
  }) async {
    final cleanObject = _cleanObjectName(objectName);
    final rows = cleanObject == null
        ? await _client
              .from('tasks')
              .select(
                'id, task_date, object_name, axes, work, status, not_done_comment',
              )
              .lt('task_date', _dateKey(beforeDate))
              .neq('status', 'Выполнено')
              .order('task_date', ascending: false)
              .limit(limit)
        : await _client
              .from('tasks')
              .select(
                'id, task_date, object_name, axes, work, status, not_done_comment',
              )
              .lt('task_date', _dateKey(beforeDate))
              .eq('object_name', cleanObject)
              .neq('status', 'Выполнено')
              .order('task_date', ascending: false)
              .limit(limit);

    return rows
        .map<TaskItemData>((row) => TaskItemData.fromSupabase(row))
        .toList();
  }

  static Future<Map<String, ForemanTaskMeta>> fetchTaskMeta(
    Iterable<String?> taskIds,
  ) async {
    final ids = _cleanTaskIds(taskIds);
    if (ids.isEmpty) return const <String, ForemanTaskMeta>{};

    final results = await Future.wait<dynamic>([
      _client
          .from('task_assignees')
          .select('task_id, employee_id, employees(fio, position)')
          .inFilter('task_id', ids),
      _client
          .from('task_photos')
          .select('task_id')
          .inFilter('task_id', ids),
    ]);

    final assigneesByTask = <String, List<TaskAssigneeData>>{};
    for (final raw in results[0] as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final taskId = row['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) continue;
      assigneesByTask
          .putIfAbsent(taskId, () => <TaskAssigneeData>[])
          .add(TaskAssigneeData.fromSupabase(row));
    }

    final photoCounts = <String, int>{};
    for (final raw in results[1] as List<dynamic>) {
      final row = Map<String, dynamic>.from(raw as Map);
      final taskId = row['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) continue;
      photoCounts[taskId] = (photoCounts[taskId] ?? 0) + 1;
    }

    return <String, ForemanTaskMeta>{
      for (final id in ids)
        id: ForemanTaskMeta(
          assignees: List<TaskAssigneeData>.unmodifiable(
            assigneesByTask[id] ?? const <TaskAssigneeData>[],
          ),
          photoCount: photoCounts[id] ?? 0,
        ),
    };
  }
}
