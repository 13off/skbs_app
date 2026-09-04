import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/offline_sync_service.dart';
import '../models/task_policy.dart';

class DeveloperPolicyRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Map<String, _PolicyCacheEntry> _cache =
      <String, _PolicyCacheEntry>{};
  static final Map<String, Future<TaskPolicy>> _inFlight =
      <String, Future<TaskPolicy>>{};
  static const Duration _cacheTtl = Duration(minutes: 3);
  static const Duration _fieldNetworkDeadline = Duration(seconds: 3);
  static int _cacheGeneration = 0;

  static String _key(String objectName) => objectName.trim().toLowerCase();
  static String _snapshotKey(String key) => 'task_policy::$key';

  static TaskPolicy policyForObjectSync(String objectName) {
    final entry = _cache[_key(objectName)];
    // Для обычного online-refresh TTL по-прежнему применяется в ensurePolicy.
    // Синхронный fallback намеренно держит последнюю известную политику дольше,
    // чтобы при пропавшей связи не ослаблять уже загруженные правила объекта.
    return entry?.policy ?? TaskPolicy.defaults;
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

    final generation = _cacheGeneration;
    final future = _loadPolicy(objectName, key, generation);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  static Future<TaskPolicy> _loadPolicy(
    String objectName,
    String key,
    int generation,
  ) async {
    try {
      final result = await _client
          .rpc<dynamic>(
            'get_effective_task_policy',
            params: <String, dynamic>{'p_object_name': objectName.trim()},
          )
          .timeout(_fieldNetworkDeadline);
      final policy = TaskPolicy.fromJson(_map(result));
      if (generation == _cacheGeneration) {
        _cache[key] = _PolicyCacheEntry(policy, DateTime.now());
      }
      await OfflineSyncService.saveSnapshot(_snapshotKey(key), policy.toJson());
      return policy;
    } catch (error) {
      if (!OfflineSyncService.isNetworkFailure(error)) rethrow;
      final raw = await OfflineSyncService.readSnapshot(_snapshotKey(key));
      if (raw is! Map) rethrow;
      final policy = TaskPolicy.fromJson(Map<String, dynamic>.from(raw));
      if (generation == _cacheGeneration) {
        _cache[key] = _PolicyCacheEntry(policy, DateTime.now());
      }
      return policy;
    }
  }

  static Future<DeveloperTaskPolicyCenter> fetchCenter() async {
    final generation = _cacheGeneration;
    final result = await _client.rpc<dynamic>(
      'get_developer_task_policy_center',
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center, generation);
    await _persistCenterPolicies(center);
    return center;
  }

  static Future<DeveloperTaskPolicyCenter> savePolicy({
    String? objectId,
    required TaskPolicy policy,
  }) async {
    final generation = _cacheGeneration;
    final result = await _client.rpc<dynamic>(
      'save_task_policy_setting',
      params: <String, dynamic>{
        'p_object_id': objectId?.trim().isEmpty == true ? null : objectId,
        'p_policy': policy.toJson(),
      },
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center, generation);
    await _persistCenterPolicies(center);
    return center;
  }

  static Future<DeveloperTaskPolicyCenter> resetObjectOverride(
    String objectId,
  ) async {
    final generation = _cacheGeneration;
    final result = await _client.rpc<dynamic>(
      'reset_task_policy_override',
      params: <String, dynamic>{'p_object_id': objectId},
    );
    final center = DeveloperTaskPolicyCenter.fromJson(_map(result));
    _primeCache(center, generation);
    await _persistCenterPolicies(center);
    return center;
  }

  static void clearCache() {
    _cacheGeneration++;
    _cache.clear();
    _inFlight.clear();
  }

  static void _primeCache(DeveloperTaskPolicyCenter center, int generation) {
    if (generation != _cacheGeneration) return;
    _cache.clear();
    final now = DateTime.now();
    for (final object in center.objects) {
      _cache[_key(object.name)] = _PolicyCacheEntry(object.policy, now);
    }
  }

  static Future<void> _persistCenterPolicies(
    DeveloperTaskPolicyCenter center,
  ) async {
    for (final object in center.objects) {
      await OfflineSyncService.saveSnapshot(
        _snapshotKey(_key(object.name)),
        object.policy.toJson(),
      );
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
