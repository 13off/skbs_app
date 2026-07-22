import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/role_permission_matrix.dart';

class RolePermissionRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<RolePermissionCenter> fetchCenter() async {
    final result = await _client.rpc<dynamic>('get_role_permission_center');
    return RolePermissionCenter.fromJson(_map(result));
  }

  static Future<RolePermissionCenter> saveOverride({
    required String roleCode,
    required String permissionCode,
    required bool isAllowed,
    String? objectId,
  }) async {
    final normalizedObjectId = objectId?.trim() ?? '';
    final result = await _client.rpc<dynamic>(
      'save_role_permission_override',
      params: <String, dynamic>{
        'p_scope': normalizedObjectId.isEmpty ? 'company' : 'object',
        'p_role_code': roleCode,
        'p_permission_code': permissionCode,
        'p_is_allowed': isAllowed,
        'p_object_id': normalizedObjectId.isEmpty ? null : normalizedObjectId,
      },
    );
    return RolePermissionCenter.fromJson(_map(result));
  }

  static Future<RolePermissionCenter> resetOverride({
    required String roleCode,
    required String permissionCode,
    String? objectId,
  }) async {
    final normalizedObjectId = objectId?.trim() ?? '';
    final result = await _client.rpc<dynamic>(
      'reset_role_permission_override',
      params: <String, dynamic>{
        'p_scope': normalizedObjectId.isEmpty ? 'company' : 'object',
        'p_role_code': roleCode,
        'p_permission_code': permissionCode,
        'p_object_id': normalizedObjectId.isEmpty ? null : normalizedObjectId,
      },
    );
    return RolePermissionCenter.fromJson(_map(result));
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}
