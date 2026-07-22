import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_governance.dart';

class TaskGovernanceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<TaskGovernanceCenter> fetchCenter({
    String? objectId,
    int limit = 200,
  }) async {
    final cleanObjectId = objectId?.trim();
    final result = await _client.rpc<dynamic>(
      'get_task_governance_center',
      params: <String, dynamic>{
        'p_object_id': cleanObjectId == null || cleanObjectId.isEmpty
            ? null
            : cleanObjectId,
        'p_limit': limit.clamp(20, 500),
      },
    );
    return TaskGovernanceCenter.fromJson(_map(result));
  }

  static Future<void> restoreTask(String taskId) async {
    final cleanId = taskId.trim();
    if (cleanId.isEmpty) return;
    await _client.rpc<dynamic>(
      'restore_task',
      params: <String, dynamic>{'p_task_id': cleanId},
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
