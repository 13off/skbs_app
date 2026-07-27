import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/object_repository.dart';
import 'manager_report_models.dart';

export 'manager_report_models.dart';

class ManagerReportsRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _cacheTtl = Duration(seconds: 3);
  static final Map<String, _ManagerReportsCacheEntry> _cache =
      <String, _ManagerReportsCacheEntry>{};
  static final Map<String, Future<ManagerReportsCenter>> _requests =
      <String, Future<ManagerReportsCenter>>{};
  static StreamSubscription<AppDataChange>? _dataChangesSubscription;
  static String? _preferredObjectName;
  static int _cacheGeneration = 0;

  static void setPreferredObjectName(String? value) {
    final clean = _cleanObjectName(value);
    if (_sameObjectName(_preferredObjectName, clean)) return;
    _preferredObjectName = clean;
    clearCache();
  }

  static void clearCache() {
    _cache.clear();
    _requests.clear();
    _cacheGeneration++;
  }

  static Future<ManagerReportsCenter> fetch({
    String? objectId,
    required DateTime reportDate,
    bool forceRefresh = false,
  }) async {
    _ensureDataChangesSubscription();
    final directObjectId = _cleanObjectId(objectId);
    final resolvedObjectId =
        directObjectId ?? await _resolvePreferredObjectId();
    final cacheKey = _cacheKey(
      objectId: resolvedObjectId,
      reportDate: reportDate,
    );
    final cached = _cache[cacheKey];
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached.center;
    }

    final runningRequest = _requests[cacheKey];
    if (!forceRefresh && runningRequest != null) return runningRequest;

    final generation = _cacheGeneration;
    final request = _load(
      objectId: resolvedObjectId,
      reportDate: reportDate,
    );
    _requests[cacheKey] = request;

    try {
      final center = await request;
      if (generation == _cacheGeneration) {
        _cache[cacheKey] = _ManagerReportsCacheEntry(
          center: center,
          createdAt: DateTime.now(),
        );
      }
      return center;
    } finally {
      if (identical(_requests[cacheKey], request)) {
        _requests.remove(cacheKey);
      }
    }
  }

  static Future<ManagerReportsCenter> _load({
    required String? objectId,
    required DateTime reportDate,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_manager_reports_center',
      params: <String, dynamic>{
        'p_object_id': objectId,
        'p_report_date': _date(reportDate),
      },
    );
    return ManagerReportsCenter.fromJson(_map(result));
  }

  static Future<String?> _resolvePreferredObjectId() async {
    final preferredName = _preferredObjectName;
    if (preferredName == null) return null;

    final objects = await ObjectRepository.fetchObjects();
    for (final object in objects) {
      if (_sameObjectName(object.name, preferredName)) {
        return _cleanObjectId(object.id);
      }
    }
    return null;
  }

  static void _ensureDataChangesSubscription() {
    _dataChangesSubscription ??= AppDataSync.changes.listen((change) {
      if (change.affectsAny(const <AppDataDomain>{
        AppDataDomain.attendance,
        AppDataDomain.payments,
        AppDataDomain.employees,
        AppDataDomain.tasks,
        AppDataDomain.objects,
        AppDataDomain.notifications,
        AppDataDomain.company,
        AppDataDomain.legal,
        AppDataDomain.recruitment,
      })) {
        clearCache();
      }
    });
  }

  static String? _cleanObjectId(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static String? _cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static bool _sameObjectName(String? first, String? second) {
    return _cleanObjectName(first)?.toLowerCase() ==
        _cleanObjectName(second)?.toLowerCase();
  }

  static String _cacheKey({
    required String? objectId,
    required DateTime reportDate,
  }) {
    final sessionPart =
        _client.auth.currentSession?.accessToken.hashCode.toString() ??
            '__guest__';
    return '$sessionPart::${objectId ?? '__all__'}::${_date(reportDate)}';
  }

  static bool _isFresh(_ManagerReportsCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _cacheTtl;
  }

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _ManagerReportsCacheEntry {
  final ManagerReportsCenter center;
  final DateTime createdAt;

  const _ManagerReportsCacheEntry({
    required this.center,
    required this.createdAt,
  });
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
