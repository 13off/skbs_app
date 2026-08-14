import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerWeeklyContributionEmployee {
  final String employeeId;
  final String employeeName;
  final String position;
  final String objectId;
  final String objectName;
  final int taskCount;
  final int totalPercent;
  final double equivalentTasks;
  final double averagePercent;
  final double teamSharePercent;

  const ManagerWeeklyContributionEmployee({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.objectId,
    required this.objectName,
    required this.taskCount,
    required this.totalPercent,
    required this.equivalentTasks,
    required this.averagePercent,
    required this.teamSharePercent,
  });

  factory ManagerWeeklyContributionEmployee.fromJson(
    Map<String, dynamic> json,
  ) {
    return ManagerWeeklyContributionEmployee(
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? 'Сотрудник',
      position: json['position']?.toString() ?? '',
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      taskCount: _asInt(json['task_count']),
      totalPercent: _asInt(json['total_percent']),
      equivalentTasks: _asDouble(json['equivalent_tasks']),
      averagePercent: _asDouble(json['average_percent']),
      teamSharePercent: _asDouble(json['team_share_percent']),
    );
  }
}

class ManagerWeeklyContributionReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int completedTasks;
  final int participants;
  final int objectsCount;
  final List<ManagerWeeklyContributionEmployee> rows;

  const ManagerWeeklyContributionReport({
    required this.weekStart,
    required this.weekEnd,
    required this.completedTasks,
    required this.participants,
    required this.objectsCount,
    required this.rows,
  });

  factory ManagerWeeklyContributionReport.fromJson(Map<String, dynamic> json) {
    return ManagerWeeklyContributionReport(
      weekStart:
          DateTime.tryParse(json['week_start']?.toString() ?? '') ??
          DateTime.now(),
      weekEnd:
          DateTime.tryParse(json['week_end']?.toString() ?? '') ??
          DateTime.now(),
      completedTasks: _asInt(json['completed_tasks']),
      participants: _asInt(json['participants']),
      objectsCount: _asInt(json['objects_count']),
      rows: _asList(json['rows'])
          .map(
            (item) => ManagerWeeklyContributionEmployee.fromJson(_asMap(item)),
          )
          .where((item) => item.employeeId.isNotEmpty)
          .toList(growable: false),
    );
  }
}

abstract final class ManagerWeeklyContributionRepository {
  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, _WeeklyContributionCacheEntry> _cache =
      <String, _WeeklyContributionCacheEntry>{};
  static final Map<String, Future<ManagerWeeklyContributionReport>> _requests =
      <String, Future<ManagerWeeklyContributionReport>>{};
  static int _cacheGeneration = 0;

  static Future<ManagerWeeklyContributionReport> fetch({
    required String companyId,
    String? objectId,
    bool forceRefresh = false,
  }) async {
    final cleanCompanyId = companyId.trim();
    final cleanObjectId = _clean(objectId);
    final key = _cacheKey(companyId: cleanCompanyId, objectId: cleanObjectId);
    final cached = _cache[key];
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached.report;
    }

    final running = _requests[key];
    if (!forceRefresh && running != null) return running;

    final generation = _cacheGeneration;
    final request = _load(objectId: cleanObjectId);
    _requests[key] = request;
    try {
      final report = await request;
      if (generation == _cacheGeneration) {
        _cache[key] = _WeeklyContributionCacheEntry(
          report: report,
          createdAt: DateTime.now(),
        );
      }
      return report;
    } finally {
      if (identical(_requests[key], request)) _requests.remove(key);
    }
  }

  static void clearCache() {
    _cacheGeneration++;
    _cache.clear();
    _requests.clear();
  }

  static Future<ManagerWeeklyContributionReport> _load({
    required String? objectId,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_manager_weekly_team_contribution',
      params: <String, dynamic>{'p_object_id': objectId},
    );
    return ManagerWeeklyContributionReport.fromJson(_asMap(result));
  }

  static String _cacheKey({
    required String companyId,
    required String? objectId,
  }) {
    final sessionPart =
        _client.auth.currentSession?.accessToken.hashCode.toString() ??
        '__guest__';
    return '$sessionPart::$companyId::${objectId ?? '__all__'}';
  }

  static bool _isFresh(_WeeklyContributionCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) < _cacheTtl;
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class _WeeklyContributionCacheEntry {
  final ManagerWeeklyContributionReport report;
  final DateTime createdAt;

  const _WeeklyContributionCacheEntry({
    required this.report,
    required this.createdAt,
  });
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
