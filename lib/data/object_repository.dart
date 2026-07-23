import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/construction_object.dart';
import 'app_data_sync.dart';

class ObjectRepository {
  static final _client = Supabase.instance.client;

  static const Duration _objectsCacheTtl = Duration(seconds: 60);

  static List<ConstructionObject>? _cachedObjects;
  static DateTime? _cachedObjectsAt;
  static Future<List<ConstructionObject>>? _objectsInFlight;
  static List<String>? _cachedArchivedObjectNames;
  static DateTime? _cachedArchivedObjectsAt;
  static Future<List<String>>? _archivedObjectsInFlight;
  static int _cacheGeneration = 0;

  static String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static String _normalizedName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static void clearCache() {
    _cachedObjects = null;
    _cachedObjectsAt = null;
    _objectsInFlight = null;
    _cachedArchivedObjectNames = null;
    _cachedArchivedObjectsAt = null;
    _archivedObjectsInFlight = null;
    _cacheGeneration++;
  }

  static void _notifyObjectsChanged({String? objectName}) {
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.objects},
      context: <String, dynamic>{'table': 'objects', 'object_name': objectName},
    );
  }

  static bool get _isObjectsCacheFresh {
    final cachedAt = _cachedObjectsAt;

    if (_cachedObjects == null || cachedAt == null) return false;

    return DateTime.now().difference(cachedAt) < _objectsCacheTtl;
  }

  static bool _isMissingObjectsTableError(Object error) {
    final text = error.toString().toLowerCase();

    return text.contains('42p01') ||
        text.contains('relation') && text.contains('objects') ||
        text.contains('schema cache') && text.contains('objects');
  }

  static Future<bool> _hasObjectRow(String objectName) async {
    final rows = await _client
        .from('objects')
        .select('id')
        .eq('name', objectName)
        .limit(1);

    return rows.isNotEmpty;
  }

  static Future<bool> _hasObjectNameInTable({
    required String table,
    required String selectColumn,
    required String objectName,
  }) async {
    final rows = await _client
        .from(table)
        .select(selectColumn)
        .eq('object_name', objectName)
        .limit(1);

    return rows.isNotEmpty;
  }

  static Future<bool> _objectNameExistsAnywhere(String objectName) async {
    final results = await Future.wait<bool>([
      _hasObjectRow(objectName),
      _hasObjectNameInTable(
        table: 'employees',
        selectColumn: 'id',
        objectName: objectName,
      ),
      _hasObjectNameInTable(
        table: 'attendance',
        selectColumn: 'employee_id',
        objectName: objectName,
      ),
      _hasObjectNameInTable(
        table: 'tasks',
        selectColumn: 'id',
        objectName: objectName,
      ),
      _hasObjectNameInTable(
        table: 'user_profiles',
        selectColumn: 'id',
        objectName: objectName,
      ),
    ]);

    return results.any((exists) => exists);
  }

  static Future<List<ConstructionObject>> fetchObjects({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isObjectsCacheFresh) {
      return List<ConstructionObject>.from(_cachedObjects!);
    }

    final runningRequest = _objectsInFlight;

    if (runningRequest != null) {
      final objects = await runningRequest;
      return List<ConstructionObject>.from(objects);
    }

    final generation = _cacheGeneration;
    final request = _loadObjects();
    _objectsInFlight = request;

    try {
      final objects = await request;

      if (generation == _cacheGeneration) {
        _cachedObjects = List<ConstructionObject>.from(objects);
        _cachedObjectsAt = DateTime.now();
      }

      return List<ConstructionObject>.from(objects);
    } finally {
      if (identical(_objectsInFlight, request)) {
        _objectsInFlight = null;
      }
    }
  }

  static Future<List<ConstructionObject>> _loadObjects() async {
    try {
      final rows = await _client
          .from('objects')
          .select('id, name, address, comment, is_active')
          .eq('is_active', true)
          .order('name', ascending: true);

      return rows
          .map<ConstructionObject>((row) {
            return ConstructionObject.fromSupabase(row);
          })
          .where((object) => object.name.trim().isNotEmpty)
          .toList();
    } catch (error) {
      if (_isMissingObjectsTableError(error)) {
        return <ConstructionObject>[];
      }

      rethrow;
    }
  }

  static Future<List<String>> fetchObjectNames({
    bool forceRefresh = false,
  }) async {
    final objects = await fetchObjects(forceRefresh: forceRefresh);

    final names = objects
        .map((object) => object.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    names.sort();

    return names;
  }

  static Future<List<String>> fetchArchivedObjectNames({
    bool forceRefresh = false,
  }) async {
    final cachedAt = _cachedArchivedObjectsAt;
    if (!forceRefresh &&
        _cachedArchivedObjectNames != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _objectsCacheTtl) {
      return List<String>.from(_cachedArchivedObjectNames!);
    }

    final running = _archivedObjectsInFlight;
    if (running != null) return List<String>.from(await running);

    final generation = _cacheGeneration;
    final request = _loadArchivedObjectNames();
    _archivedObjectsInFlight = request;
    try {
      final result = await request;
      if (generation == _cacheGeneration) {
        _cachedArchivedObjectNames = List<String>.from(result);
        _cachedArchivedObjectsAt = DateTime.now();
      }
      return List<String>.from(result);
    } finally {
      if (identical(_archivedObjectsInFlight, request)) {
        _archivedObjectsInFlight = null;
      }
    }
  }

  static Future<List<String>> _loadArchivedObjectNames() async {
    final rows = await _client
        .from('objects')
        .select('name')
        .eq('is_active', false)
        .order('name', ascending: true);

    return rows
        .map<String>((row) => row['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  static Future<String> addObject({
    required String name,
    String address = '',
    String comment = '',
  }) async {
    final cleanName = cleanObjectName(name);

    if (cleanName == null) {
      throw Exception('Введите название объекта');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final currentUserId = _client.auth.currentUser?.id;

    try {
      final existing = await _client
          .from('objects')
          .select('name, is_active')
          .eq('name', cleanName)
          .maybeSingle();

      if (existing != null) {
        if (existing['is_active'] != true) {
          await restoreObject(name: cleanName);
        }

        clearCache();
        _notifyObjectsChanged(objectName: cleanName);
        return existing['name']?.toString() ?? cleanName;
      }

      final row = await _client
          .from('objects')
          .insert({
            'name': cleanName,
            'address': address.trim(),
            'comment': comment.trim(),
            'is_active': true,
            'created_by': currentUserId,
            'updated_at': now,
          })
          .select('name')
          .single();

      clearCache();
      _notifyObjectsChanged(objectName: cleanName);

      return row['name']?.toString() ?? cleanName;
    } catch (error) {
      if (_isMissingObjectsTableError(error)) {
        throw Exception(
          'В Supabase ещё нет таблицы objects. Сначала выполни SQL из файла OBJECTS_01_SUPABASE_SQL.sql.',
        );
      }

      rethrow;
    }
  }

  static Future<String> renameObject({
    required String oldName,
    required String newName,
  }) async {
    final cleanOldName = cleanObjectName(oldName);
    final cleanNewName = cleanObjectName(newName);

    if (cleanOldName == null) {
      throw Exception('Не найден старый объект');
    }

    if (cleanNewName == null) {
      throw Exception('Введите новое название объекта');
    }

    if (_normalizedName(cleanOldName) == _normalizedName(cleanNewName)) {
      return cleanOldName;
    }

    if (await _objectNameExistsAnywhere(cleanNewName)) {
      throw Exception('Объект "$cleanNewName" уже существует или используется');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final hasObjectRow = await _hasObjectRow(cleanOldName);

    if (hasObjectRow) {
      await _client
          .from('objects')
          .update({'name': cleanNewName, 'is_active': true, 'updated_at': now})
          .eq('name', cleanOldName);
    } else {
      await addObject(name: cleanNewName);
    }

    await Future.wait<dynamic>([
      _client
          .from('employees')
          .update({'object_name': cleanNewName, 'updated_at': now})
          .eq('object_name', cleanOldName),
      _client
          .from('attendance')
          .update({'object_name': cleanNewName, 'updated_at': now})
          .eq('object_name', cleanOldName),
      _client
          .from('tasks')
          .update({'object_name': cleanNewName, 'updated_at': now})
          .eq('object_name', cleanOldName),
      _client
          .from('user_profiles')
          .update({'object_name': cleanNewName})
          .eq('object_name', cleanOldName),
    ]);

    clearCache();
    _notifyObjectsChanged(objectName: cleanNewName);

    return cleanNewName;
  }

  static Future<void> archiveObject({required String name}) async {
    final cleanName = cleanObjectName(name);

    if (cleanName == null) {
      throw Exception('Не найден объект');
    }

    await _client.rpc('archive_object', params: {'p_name': cleanName});
    clearCache();
    _notifyObjectsChanged(objectName: cleanName);
  }

  static Future<void> deleteObject({required String name}) async {
    await archiveObject(name: name);
  }

  static Future<void> restoreObject({required String name}) async {
    final cleanName = cleanObjectName(name);

    if (cleanName == null) {
      throw Exception('Не найден объект');
    }

    await _client.rpc('restore_object', params: {'p_name': cleanName});
    clearCache();
    _notifyObjectsChanged(objectName: cleanName);
  }

  static Future<void> ensureObjectNameExists(String objectName) async {
    final cleanName = cleanObjectName(objectName);

    if (cleanName == null) return;

    final normalizedName = _normalizedName(cleanName);
    final cachedObjects = _cachedObjects;

    if (cachedObjects != null &&
        cachedObjects.any(
          (object) => _normalizedName(object.name) == normalizedName,
        )) {
      return;
    }

    try {
      final existing = await _client
          .from('objects')
          .select('name, is_active')
          .eq('name', cleanName)
          .maybeSingle();

      if (existing != null) {
        if (existing['is_active'] != true) {
          await restoreObject(name: cleanName);
        }
        return;
      }

      await addObject(name: cleanName);
    } catch (error) {
      if (_isMissingObjectsTableError(error)) return;

      final text = error.toString();

      if (text.contains('таблицы objects')) return;

      rethrow;
    }
  }
}
