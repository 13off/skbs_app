import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session_scope.dart';

class OfflineSyncState {
  final int pendingCount;
  final DateTime? lastSyncAt;
  final bool isSyncing;

  const OfflineSyncState({
    this.pendingCount = 0,
    this.lastSyncAt,
    this.isSyncing = false,
  });

  OfflineSyncState copyWith({
    int? pendingCount,
    DateTime? lastSyncAt,
    bool? isSyncing,
    bool clearLastSyncAt = false,
  }) {
    return OfflineSyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class OfflineSyncService {
  OfflineSyncService._();

  static final ValueNotifier<OfflineSyncState> state =
      ValueNotifier<OfflineSyncState>(const OfflineSyncState());

  static const String _prefix = 'appstroy_offline_v1';
  static const int _maxMutationAttempts = 50;
  static SharedPreferences? _preferences;
  static String _userId = '';
  static String _companyId = '';
  static bool _configured = false;
  static bool _flushRunning = false;
  static List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];

  static bool get isConfigured => _configured;
  static int get pendingCount => _queue.length;

  static String get _scope {
    final user = _userId.isEmpty ? '__guest__' : _userId;
    final company = _companyId.isEmpty ? '__no_company__' : _companyId;
    return '$user::$company';
  }

  static String get _queueKey => '$_prefix::queue::$_scope';
  static String get _lastSyncKey => '$_prefix::last_sync::$_scope';
  static String _snapshotKey(String key) => '$_prefix::snapshot::$_scope::$key';
  static String _profileKey(String userId) =>
      '$_prefix::profile::${userId.trim()}';

  static Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  static Future<void> configure({
    required String userId,
    required String companyId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanCompanyId = companyId.trim();
    final unchanged =
        _configured && _userId == cleanUserId && _companyId == cleanCompanyId;
    if (unchanged) return;

    _userId = cleanUserId;
    _companyId = cleanCompanyId;
    _configured = true;

    final prefs = await _prefs();
    _queue = _decodeQueue(prefs.getString(_queueKey));
    final lastSync = DateTime.tryParse(prefs.getString(_lastSyncKey) ?? '');
    state.value = OfflineSyncState(
      pendingCount: _queue.length,
      lastSyncAt: lastSync,
      isSyncing: false,
    );
  }

  static void resetRuntime() {
    _configured = false;
    _userId = '';
    _companyId = '';
    _queue = <Map<String, dynamic>>[];
    _flushRunning = false;
    state.value = const OfflineSyncState();
  }

  static Future<void> saveUserProfileSnapshot(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    final prefs = await _prefs();
    await prefs.setString(_profileKey(cleanUserId), jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> readUserProfileSnapshot(
    String userId,
  ) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    final prefs = await _prefs();
    final raw = prefs.getString(_profileKey(cleanUserId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> clearUserProfileSnapshot(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;
    final prefs = await _prefs();
    await prefs.remove(_profileKey(cleanUserId));
  }

  static Future<void> saveSnapshot(String key, Object? value) async {
    if (!_configured || key.trim().isEmpty) return;
    final prefs = await _prefs();
    await prefs.setString(
      _snapshotKey(key.trim()),
      jsonEncode(<String, dynamic>{
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'value': value,
      }),
    );
  }

  static Future<dynamic> readSnapshot(String key) async {
    if (!_configured || key.trim().isEmpty) return null;
    final prefs = await _prefs();
    final raw = prefs.getString(_snapshotKey(key.trim()));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded['value'];
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> enqueue({
    required String kind,
    required Map<String, dynamic> payload,
    String? dedupeKey,
  }) async {
    if (!_configured) {
      await configure(
        userId: AppSessionScope.userId,
        companyId: AppSessionScope.companyId,
      );
    }

    final cleanDedupe = dedupeKey?.trim() ?? '';
    if (cleanDedupe.isNotEmpty) {
      _queue.removeWhere(
        (item) =>
            item['kind']?.toString() == kind &&
            item['dedupe_key']?.toString() == cleanDedupe,
      );
    }

    _queue.add(<String, dynamic>{
      'id': createLocalId(),
      'kind': kind,
      'dedupe_key': cleanDedupe,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    });
    await _persistQueue();
    _publishState();
  }

  static Future<void> flush() async {
    if (!_configured || _flushRunning || _queue.isEmpty) return;
    if (Supabase.instance.client.auth.currentSession == null) return;

    _flushRunning = true;
    _publishState(isSyncing: true);
    try {
      var index = 0;
      while (index < _queue.length) {
        final item = _queue[index];
        try {
          await _execute(item);
          _queue.removeAt(index);
          await _persistQueue();
        } catch (error) {
          final attempts = (item['attempts'] as num?)?.toInt() ?? 0;
          item['attempts'] = attempts + 1;
          await _persistQueue();

          if (isNetworkFailure(error)) break;
          if ((item['attempts'] as int) >= _maxMutationAttempts) {
            // Не теряем пользовательские данные даже при постоянной серверной
            // ошибке: запись остаётся в очереди для ручного разбора.
            break;
          }
          index += 1;
        }
      }

      if (_queue.isEmpty) {
        await markSynced();
      }
    } finally {
      _flushRunning = false;
      _publishState(isSyncing: false);
    }
  }

  static Future<void> markSynced() async {
    if (!_configured) return;
    final now = DateTime.now();
    final prefs = await _prefs();
    await prefs.setString(_lastSyncKey, now.toUtc().toIso8601String());
    state.value = state.value.copyWith(lastSyncAt: now, pendingCount: _queue.length);
  }

  static Future<void> _execute(Map<String, dynamic> item) async {
    final kind = item['kind']?.toString() ?? '';
    final rawPayload = item['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final client = Supabase.instance.client;

    switch (kind) {
      case 'attendance.upsert':
        final rawRows = payload['rows'];
        final rows = rawRows is List
            ? rawRows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(growable: false)
            : <Map<String, dynamic>>[];
        if (rows.isNotEmpty) {
          await client
              .from('attendance')
              .upsert(rows, onConflict: 'work_date,employee_id');
        }
        return;
      case 'task.create':
        await _executeTaskCreate(payload);
        return;
      case 'task.update':
        final id = payload['id']?.toString().trim() ?? '';
        if (id.isEmpty) return;
        final values = _map(payload['values']);
        await client.from('tasks').update(values).eq('id', id);
        await _saveTaskLink(id, payload);
        return;
      case 'task.delete':
        final id = payload['id']?.toString().trim() ?? '';
        if (id.isEmpty) return;
        await client.from('tasks').delete().eq('id', id);
        return;
      default:
        throw StateError('Неизвестная offline-операция: $kind');
    }
  }

  static Future<void> _executeTaskCreate(Map<String, dynamic> payload) async {
    final client = Supabase.instance.client;
    final id = payload['id']?.toString().trim() ?? '';
    if (id.isEmpty) throw StateError('У offline-задачи отсутствует ID');

    final row = _map(payload['row']);
    row['id'] = id;
    await client.from('tasks').upsert(row, onConflict: 'id');

    await client.from('task_assignees').delete().eq('task_id', id);
    final assigneeIds = (payload['assignee_ids'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (assigneeIds.isNotEmpty) {
      await client.from('task_assignees').insert(
        assigneeIds
            .map(
              (employeeId) => <String, dynamic>{
                'task_id': id,
                'employee_id': employeeId,
              },
            )
            .toList(growable: false),
      );
    }

    await _saveTaskLink(id, payload);

    final photos = payload['photos'];
    if (photos is List && photos.isNotEmpty) {
      for (var index = 0; index < photos.length; index += 1) {
        final raw = photos[index];
        if (raw is! Map) continue;
        final photo = Map<String, dynamic>.from(raw);
        final bytesText = photo['bytes']?.toString() ?? '';
        if (bytesText.isEmpty) continue;
        final bytes = Uint8List.fromList(base64Decode(bytesText));
        final extension = photo['extension']?.toString().trim().isNotEmpty == true
            ? photo['extension'].toString().trim()
            : 'jpg';
        final stage = photo['photo_stage']?.toString() == 'after'
            ? 'after'
            : 'before';
        final path =
            '$id/$stage/${DateTime.now().millisecondsSinceEpoch}_${index + 1}.$extension';
        await client.storage.from('task-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: photo['content_type']?.toString(),
            upsert: false,
          ),
        );
        await client.from('task_photos').insert(<String, dynamic>{
          'task_id': id,
          'storage_path': path,
          'original_name': photo['original_name']?.toString() ?? 'Фото',
          'photo_stage': stage,
        });
      }
    }

    if (row['is_draft'] == true) return;
    await client
        .from('tasks')
        .update(<String, dynamic>{
          'is_draft': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  static Future<void> _saveTaskLink(
    String taskId,
    Map<String, dynamic> payload,
  ) async {
    if (!payload.containsKey('milestone_id') &&
        !payload.containsKey('checklist_item_id')) {
      return;
    }
    final milestoneId = payload['milestone_id']?.toString().trim() ?? '';
    final checklistItemId =
        payload['checklist_item_id']?.toString().trim() ?? '';
    final client = Supabase.instance.client;
    if (milestoneId.isEmpty || checklistItemId.isEmpty) {
      await client.from('task_milestone_links').delete().eq('task_id', taskId);
      return;
    }
    await client.from('task_milestone_links').upsert(<String, dynamic>{
      'task_id': taskId,
      'milestone_id': milestoneId,
      'checklist_item_id': checklistItemId,
    }, onConflict: 'task_id');
  }

  static List<Map<String, dynamic>> _decodeQueue(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Future<void> _persistQueue() async {
    if (!_configured) return;
    final prefs = await _prefs();
    await prefs.setString(_queueKey, jsonEncode(_queue));
  }

  static void _publishState({bool? isSyncing}) {
    state.value = state.value.copyWith(
      pendingCount: _queue.length,
      isSyncing: isSyncing,
    );
  }

  static bool isNetworkFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('clientexception') ||
        text.contains('xmlhttprequest') ||
        text.contains('fetch') && text.contains('failed');
  }

  static String createLocalId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final text = bytes.map(hex).join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }

  static Map<String, dynamic> serializePhoto({
    required String originalName,
    required String contentType,
    required String extension,
    required Uint8List bytes,
    String photoStage = 'before',
  }) {
    return <String, dynamic>{
      'original_name': originalName,
      'content_type': contentType,
      'extension': extension,
      'photo_stage': photoStage,
      'bytes': base64Encode(bytes),
    };
  }
}
