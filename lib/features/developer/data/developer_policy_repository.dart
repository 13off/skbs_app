import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_policy.dart';

class DeveloperPolicyRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Map<String, _PolicyCacheEntry> _cache =
      <String, _PolicyCacheEntry>{};
  static final Map<String, Future<TaskPolicy>> _inFlight =
      <String, Future<TaskPolicy>>{};
  static const Duration _cacheTtl = Duration(minutes: 3);

  static String _key(String objectName) => objectName.trim().toLowerCase();

  static TaskPolicy policyForObjectSync(String objectName) {
    final entry = _cache[_key(objectName)];
    if (entry == null ||
        DateTime.now().difference(entry.loadedAt) > _cacheTtl) {
      return TaskPolicy.defaults;
    }
    return entry.policy;
  }

  static Future<TaskPolicy> ensurePolicy(
    String objectName, {
    bool forceRefresh = false,
  }) async {
    final key = _key(objectName);
    final cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.loadedAt) <= _cacheTtl) {
      return cached.policy;
    }

    if (!forceRefresh) {
      final pending = _inFlight[key];
      if (pending != null) return pending;
    }

    final future = _loadPolicy(objectName, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  static Future<TaskPolicy> _loadPolicy(String objectName, String key) async {
    final result = await _client.rpc<dynamic>(
      'get_effective_task_policy',
      params: <String, dynamic>{'p_object_name': objectName.trim()},
    );
    final policy = TaskPolicy.fromJson(_map(result));
    _cache[key] = _PolicyCacheEntry(policy, DateTime.now());
    return policy;
  }

  static Future<DeveloperTaskPolicyCenter> fetchCenter() async {
    final result = await _client.rpc<dynamic>(
      'get_developer_task_policy_center',
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center);
    return center;
  }

  static Future<DeveloperTaskPolicyCenter> savePolicy({
    String? objectId,
    required TaskPolicy policy,
  }) async {
    final result = await _client.rpc<dynamic>(
      'save_task_policy_setting',
      params: <String, dynamic>{
        'p_object_id': objectId?.trim().isEmpty == true ? null : objectId,
        'p_policy': policy.toJson(),
      },
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center);
    return center;
  }

  static Future<DeveloperTaskPolicyCenter> resetObjectOverride(
    String objectId,
  ) async {
    final result = await _client.rpc<dynamic>(
      'reset_task_policy_override',
      params: <String, dynamic>{'p_object_id': objectId},
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center);
    return center;
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static void _primeCache(DeveloperTaskPolicyCenter center) {
    _cache.clear();
    final now = DateTime.now();
    for (final object in center.objects) {
      _cache[_key(object.name)] = _PolicyCacheEntry(object.policy, now);
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }
}

class _PolicyCacheEntry {
  final TaskPolicy policy;
  final DateTime loadedAt;

  const _PolicyCacheEntry(this.policy, this.loadedAt);
}
