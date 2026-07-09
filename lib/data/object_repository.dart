import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/construction_object.dart';

class ObjectRepository {
  static final _client = Supabase.instance.client;

  static const Duration _objectsCacheTtl = Duration(seconds: 60);

  static List<ConstructionObject>? _cachedObjects;
  static DateTime? _cachedObjectsAt;

  static String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static void clearCache() {
    _cachedObjects = null;
    _cachedObjectsAt = null;
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

  static Future<List<ConstructionObject>> fetchObjects({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isObjectsCacheFresh) {
      return List<ConstructionObject>.from(_cachedObjects!);
    }

    try {
      final rows = await _client
          .from('objects')
          .select('id, name, address, comment, is_active')
          .eq('is_active', true)
          .order('name', ascending: true);

      final objects = rows
          .map<ConstructionObject>((row) {
            return ConstructionObject.fromSupabase(row);
          })
          .where((object) => object.name.trim().isNotEmpty)
          .toList();

      _cachedObjects = List<ConstructionObject>.from(objects);
      _cachedObjectsAt = DateTime.now();

      return List<ConstructionObject>.from(objects);
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
          .select('name')
          .eq('name', cleanName)
          .maybeSingle();

      if (existing != null) {
        clearCache();

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

  static Future<void> ensureObjectNameExists(String objectName) async {
    final cleanName = cleanObjectName(objectName);

    if (cleanName == null) return;

    try {
      final existing = await _client
          .from('objects')
          .select('name')
          .eq('name', cleanName)
          .maybeSingle();

      if (existing != null) return;

      await addObject(name: cleanName);
    } catch (error) {
      if (_isMissingObjectsTableError(error)) return;

      final text = error.toString();

      if (text.contains('таблицы objects')) return;

      rethrow;
    }
  }
}
