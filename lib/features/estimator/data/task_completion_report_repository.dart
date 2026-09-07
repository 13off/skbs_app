import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_completion_report.dart';

abstract final class TaskCompletionReportRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const String _reportFields =
      'id, task_id, reported_quantity, unit, work_location, completion_comment, '
      'review_status, approved_quantity, review_comment, submitted_by_name, '
      'submitted_at, reviewed_by_name, reviewed_at';

  static const String _queueFields =
      '$_reportFields, tasks!inner(id, task_date, object_name, axes, work, status)';

  static Future<TaskCompletionReport?> fetchForTask(String taskId) async {
    final cleanId = taskId.trim();
    if (cleanId.isEmpty) return null;
    final row = await _client
        .from('task_completion_reports')
        .select(_reportFields)
        .eq('task_id', cleanId)
        .maybeSingle();
    if (row == null) return null;
    return TaskCompletionReport.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<List<TaskCompletionReport>> fetchQueue({
    String? status,
  }) async {
    final cleanStatus = status?.trim() ?? '';
    final rows = cleanStatus.isEmpty
        ? await _client
              .from('task_completion_reports')
              .select(_queueFields)
              .order('submitted_at', ascending: false)
        : await _client
              .from('task_completion_reports')
              .select(_queueFields)
              .eq('review_status', cleanStatus)
              .order('submitted_at', ascending: false);
    return rows
        .map<TaskCompletionReport>(
          (row) => TaskCompletionReport.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  static Future<void> submit({
    required String taskId,
    double? reportedQuantity,
    String unit = '',
    String workLocation = '',
    String completionComment = '',
  }) async {
    await _client.rpc(
      'submit_task_completion_report',
      params: <String, dynamic>{
        'p_task_id': taskId.trim(),
        'p_reported_quantity': reportedQuantity,
        'p_unit': unit.trim(),
        'p_work_location': workLocation.trim(),
        'p_completion_comment': completionComment.trim(),
      },
    );
  }

  static Future<void> approve({
    required String reportId,
    double? approvedQuantity,
    String comment = '',
  }) async {
    await _client.rpc(
      'review_task_completion_report',
      params: <String, dynamic>{
        'p_report_id': reportId.trim(),
        'p_action': 'approved',
        'p_approved_quantity': approvedQuantity,
        'p_comment': comment.trim(),
      },
    );
  }

  static Future<void> returnToForeman({
    required String reportId,
    required String comment,
  }) async {
    await _client.rpc(
      'review_task_completion_report',
      params: <String, dynamic>{
        'p_report_id': reportId.trim(),
        'p_action': 'returned',
        'p_approved_quantity': null,
        'p_comment': comment.trim(),
      },
    );
  }
}
