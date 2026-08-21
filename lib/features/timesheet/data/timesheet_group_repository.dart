import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/timesheet_group.dart';

class TimesheetGroupRepository {
  TimesheetGroupRepository._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const Duration _cacheTtl = Duration(seconds: 30);
  static final Map<String, _TimesheetGroupCacheEntry> _cache =
      <String, _TimesheetGroupCacheEntry>{};
  static final Map<String, Future<List<TimesheetGroup>>> _inFlight =
      <String, Future<List<TimesheetGroup>>>{};
  static int _cacheGeneration = 0;

  static String? _cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static List<TimesheetGroup> _sortGroups(Iterable<TimesheetGroup> groups) {
    final result = groups.toList(growable: false);
    result.sort((first, second) {
      final objectCompare = first.objectName.compareTo(second.objectName);
      if (objectCompare != 0) return objectCompare;
      final orderCompare = first.sortOrder.compareTo(second.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return result;
  }

  static Future<List<TimesheetGroup>> fetchGroups({
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final cleanObject = _cleanObjectName(objectName);
    final key = cleanObject ?? '__all__';
    final cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return List<TimesheetGroup>.from(cached.groups);
    }

    final running = _inFlight[key];
    if (running != null) return List<TimesheetGroup>.from(await running);

    final generation = _cacheGeneration;
    final request = _loadGroups(cleanObject);
    _inFlight[key] = request;
    try {
      final groups = await request;
      if (generation == _cacheGeneration) {
        _cache[key] = _TimesheetGroupCacheEntry(
          groups: List<TimesheetGroup>.from(groups),
          createdAt: DateTime.now(),
        );
      }
      return List<TimesheetGroup>.from(groups);
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  static Future<List<TimesheetGroup>> _loadGroups(String? objectName) async {
    final result = await _client.rpc(
      'list_timesheet_groups',
      params: <String, dynamic>{'p_object_name': objectName},
    );
    if (result is! List) return const <TimesheetGroup>[];
    return _sortGroups(
      result.whereType<Map>().map(
        (row) => TimesheetGroup.fromMap(Map<String, dynamic>.from(row)),
      ),
    );
  }

  static void clearCache() {
    _cacheGeneration++;
    _cache.clear();
    _inFlight.clear();
  }

  static Future<String> saveGroup({
    String? groupId,
    required String objectName,
    required String name,
    required Iterable<String> employeeIds,
  }) async {
    final cleanObject = _cleanObjectName(objectName);
    final cleanName = name.trim();
    if (cleanObject == null) throw Exception('Выберите объект');
    if (cleanName.isEmpty) throw Exception('Введите название группы');
    if (cleanName.length > 80) {
      throw Exception('Название группы должно быть короче 80 символов');
    }

    final cleanIds = employeeIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final cleanGroupId = groupId?.trim();
    final result = await _client.rpc(
      'save_timesheet_group',
      params: <String, dynamic>{
        'p_group_id': cleanGroupId == null || cleanGroupId.isEmpty
            ? null
            : cleanGroupId,
        'p_object_name': cleanObject,
        'p_name': cleanName,
        'p_employee_ids': cleanIds,
      },
    );

    clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.employees},
      context: <String, dynamic>{
        'table': 'timesheet_groups',
        'object_name': cleanObject,
      },
    );
    return result?.toString() ?? '';
  }

  static Future<void> deleteGroup(String groupId) async {
    final cleanId = groupId.trim();
    if (cleanId.isEmpty) return;
    await _client.rpc(
      'delete_timesheet_group',
      params: <String, dynamic>{'p_group_id': cleanId},
    );
    clearCache();
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.employees},
      context: const <String, dynamic>{'table': 'timesheet_groups'},
    );
  }
}

class _TimesheetGroupCacheEntry {
  final List<TimesheetGroup> groups;
  final DateTime createdAt;

  const _TimesheetGroupCacheEntry({
    required this.groups,
    required this.createdAt,
  });
}
