import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee_private_data.dart';
import 'app_session_scope.dart';

class EmployeePrivateDataRepository {
  static final _client = Supabase.instance.client;

  static const Duration _cacheTtl = Duration(seconds: 25);
  static const int _chunkSize = 80;

  static final Map<String, _PrivateDataEntry?> _employeeCache = {};
  static final Map<String, Future<EmployeePrivateData?>> _employeeRequests = {};
  static final Map<String, _PrivateDataMapEntry> _mapCache = {};
  static final Map<String, Future<Map<String, EmployeePrivateData>>>
  _mapRequests = {};
  static int _cacheGeneration = 0;

  static bool _isFresh(DateTime createdAt) {
    return DateTime.now().difference(createdAt) < _cacheTtl;
  }

  static Map<String, EmployeePrivateData> _copyMap(
    Map<String, EmployeePrivateData> value,
  ) {
    return Map<String, EmployeePrivateData>.from(value);
  }

  static void clearCache() {
    _cacheGeneration++;
    _employeeCache.clear();
    _employeeRequests.clear();
    _mapCache.clear();
    _mapRequests.clear();
  }

  static Future<EmployeePrivateData?> fetchByEmployeeId(
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    final id = employeeId.trim();
    if (id.isEmpty) return null;
    final key = AppSessionScope.cacheKey(id);

    final cached = _employeeCache[key];
    if (!forceRefresh && cached != null && _isFresh(cached.createdAt)) {
      return cached.value;
    }

    final running = _employeeRequests[key];
    if (running != null) return running;

    final cacheGeneration = _cacheGeneration;
    final sessionGeneration = AppSessionScope.generation;
    final request = _loadByEmployeeId(id);
    _employeeRequests[key] = request;
    try {
      final result = await request;
      if (cacheGeneration == _cacheGeneration &&
          AppSessionScope.isCurrent(sessionGeneration)) {
        _employeeCache[key] = _PrivateDataEntry(
          value: result,
          createdAt: DateTime.now(),
        );
      }
      return result;
    } finally {
      if (identical(_employeeRequests[key], request)) {
        _employeeRequests.remove(key);
      }
    }
  }

  static Future<EmployeePrivateData?> _loadByEmployeeId(
    String employeeId,
  ) async {
    final row = await _client
        .from('employee_private_data')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (row == null) return null;
    return EmployeePrivateData.fromMap(row);
  }

  static Future<Map<String, EmployeePrivateData>> fetchAllMap({
    bool forceRefresh = false,
  }) {
    return _fetchMap(
      key: '__all__',
      forceRefresh: forceRefresh,
      loader: () async {
        final rows = await _client.from('employee_private_data').select();
        return _mapRows(rows);
      },
    );
  }

  static Future<Map<String, EmployeePrivateData>> fetchMapByEmployeeIds(
    List<String> employeeIds, {
    bool forceRefresh = false,
  }) async {
    final ids =
        employeeIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (ids.isEmpty) return <String, EmployeePrivateData>{};

    return _fetchMap(
      key: ids.join('|'),
      forceRefresh: forceRefresh,
      requestedEmployeeIds: ids,
      loader: () => _loadMapByEmployeeIds(ids),
    );
  }

  static Future<Map<String, EmployeePrivateData>> _fetchMap({
    required String key,
    required bool forceRefresh,
    required Future<Map<String, EmployeePrivateData>> Function() loader,
    List<String>? requestedEmployeeIds,
  }) async {
    final scopedKey = AppSessionScope.cacheKey(key);
    final cached = _mapCache[scopedKey];
    if (!forceRefresh && cached != null && _isFresh(cached.createdAt)) {
      return _copyMap(cached.value);
    }

    final running = _mapRequests[scopedKey];
    if (running != null) return _copyMap(await running);

    final cacheGeneration = _cacheGeneration;
    final sessionGeneration = AppSessionScope.generation;
    final request = loader();
    _mapRequests[scopedKey] = request;
    try {
      final result = await request;
      final createdAt = DateTime.now();
      if (cacheGeneration == _cacheGeneration &&
          AppSessionScope.isCurrent(sessionGeneration)) {
        _mapCache[scopedKey] = _PrivateDataMapEntry(
          value: _copyMap(result),
          createdAt: createdAt,
        );
        _warmEmployeeCache(
          result,
          createdAt: createdAt,
          requestedEmployeeIds: requestedEmployeeIds,
        );
      }
      return _copyMap(result);
    } finally {
      if (identical(_mapRequests[scopedKey], request)) {
        _mapRequests.remove(scopedKey);
      }
    }
  }

  static void _warmEmployeeCache(
    Map<String, EmployeePrivateData> values, {
    required DateTime createdAt,
    List<String>? requestedEmployeeIds,
  }) {
    final ids = requestedEmployeeIds;
    if (ids != null) {
      for (final employeeId in ids) {
        _employeeCache[AppSessionScope.cacheKey(employeeId)] =
            _PrivateDataEntry(value: values[employeeId], createdAt: createdAt);
      }
      return;
    }

    for (final entry in values.entries) {
      _employeeCache[AppSessionScope.cacheKey(entry.key)] = _PrivateDataEntry(
        value: entry.value,
        createdAt: createdAt,
      );
    }
  }

  static Future<Map<String, EmployeePrivateData>> _loadMapByEmployeeIds(
    List<String> ids,
  ) async {
    final requests = <Future<List<dynamic>>>[];

    for (var start = 0; start < ids.length; start += _chunkSize) {
      final end = math.min(start + _chunkSize, ids.length);
      final chunk = ids.sublist(start, end);
      requests.add(
        _client
            .from('employee_private_data')
            .select()
            .inFilter('employee_id', chunk),
      );
    }

    final chunks = await Future.wait<List<dynamic>>(requests);
    return _mapRows(chunks.expand((rows) => rows));
  }

  static Map<String, EmployeePrivateData> _mapRows(Iterable<dynamic> rows) {
    final result = <String, EmployeePrivateData>{};

    for (final rawRow in rows) {
      final data = EmployeePrivateData.fromMap(
        Map<String, dynamic>.from(rawRow as Map),
      );
      if (data.employeeId.isEmpty) continue;
      result[data.employeeId] = data;
    }

    return result;
  }

  static Future<void> upsert(EmployeePrivateData data) async {
    await _client
        .from('employee_private_data')
        .upsert(data.toSupabaseMap(), onConflict: 'employee_id');
    clearCache();
  }
}

class _PrivateDataEntry {
  final EmployeePrivateData? value;
  final DateTime createdAt;

  const _PrivateDataEntry({required this.value, required this.createdAt});
}

class _PrivateDataMapEntry {
  final Map<String, EmployeePrivateData> value;
  final DateTime createdAt;

  const _PrivateDataMapEntry({required this.value, required this.createdAt});
}
