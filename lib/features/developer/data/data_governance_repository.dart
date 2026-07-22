import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/data_governance.dart';

class DataGovernanceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<DataGovernanceCenter> fetchCenter({
    String? objectId,
    String? entityType,
    int limit = 250,
  }) async {
    final normalizedObjectId = objectId?.trim() ?? '';
    final normalizedEntityType = entityType?.trim() ?? '';
    final result = await _client.rpc<dynamic>(
      'get_data_governance_center',
      params: <String, dynamic>{
        'p_object_id': normalizedObjectId.isEmpty ? null : normalizedObjectId,
        'p_entity_type': normalizedEntityType.isEmpty
            ? null
            : normalizedEntityType,
        'p_limit': limit,
      },
    );
    return DataGovernanceCenter.fromJson(_map(result));
  }

  static Future<DataGovernanceCenter> restore({
    required String entityType,
    required String entityId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'restore_governance_entity',
      params: <String, dynamic>{
        'p_entity_type': entityType,
        'p_entity_id': entityId,
      },
    );
    return DataGovernanceCenter.fromJson(_map(result));
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
