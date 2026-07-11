import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_repository.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String actorUserId;
  final String actorName;
  final String actorEmail;
  final String objectName;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.actorUserId,
    required this.actorName,
    required this.actorEmail,
    required this.objectName,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromSupabase(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Изменение',
      body: json['body']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'Пользователь',
      actorEmail: json['actor_email']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: isRead,
    );
  }
}

class NotificationRepository {
  static final _client = Supabase.instance.client;

  static const List<String> foremanAllowedEntityTypes = [
    'attendance',
    'tasks',
    'task_assignees',
    'task_photos',
  ];

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static bool _isMissingNotificationsTableError(Object error) {
    final text = error.toString().toLowerCase();

    return text.contains('42p01') ||
        text.contains('app_notifications') &&
            (text.contains('relation') || text.contains('schema cache')) ||
        text.contains('app_notification_reads') &&
            (text.contains('relation') || text.contains('schema cache')) ||
        text.contains('app_notification_clears') &&
            (text.contains('relation') || text.contains('schema cache'));
  }

  static String? get _currentUserId {
    return UserRepository.currentUser?.id;
  }

  static Future<String> currentActorName() async {
    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final fullName = profile?.fullName.trim() ?? '';

      if (fullName.isNotEmpty) return fullName;

      final email = profile?.email.trim() ?? '';

      if (email.isNotEmpty) return email;
    } catch (_) {
      // Не ломаем основное действие из-за профиля пользователя.
    }

    final email = UserRepository.currentUser?.email?.trim() ?? '';

    if (email.isNotEmpty) return email;

    return 'Пользователь';
  }

  static Future<void> add({
    required String title,
    required String body,
    String? objectName,
    String entityType = '',
    String entityId = '',
  }) async {
    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final user = UserRepository.currentUser;

      final actorName = profile?.fullName.trim().isNotEmpty == true
          ? profile!.fullName.trim()
          : profile?.email.trim().isNotEmpty == true
          ? profile!.email.trim()
          : user?.email?.trim().isNotEmpty == true
          ? user!.email!.trim()
          : 'Пользователь';

      final actorEmail = profile?.email.trim().isNotEmpty == true
          ? profile!.email.trim()
          : user?.email?.trim() ?? '';

      await _client.from('app_notifications').insert({
        'title': title.trim(),
        'body': body.trim(),
        'actor_user_id': user?.id,
        'actor_name': actorName,
        'actor_email': actorEmail,
        'object_name': cleanObjectName(objectName) ?? '',
        'entity_type': entityType.trim(),
        'entity_id': entityId.trim(),
      });
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return;

      // Уведомления не должны ломать сохранение табеля, выплат или сотрудников.
      return;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  static DateTime? _maxDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;

    return first.isAfter(second) ? first : second;
  }

  static Future<DateTime?> _fetchClearDate(String? objectName) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) return null;

    try {
      final globalRow = await _client
          .from('app_notification_clears')
          .select('cleared_at')
          .eq('user_id', userId)
          .eq('object_name', '')
          .maybeSingle();

      DateTime? clearDate = _parseDate(globalRow?['cleared_at']);
      final cleanObject = cleanObjectName(objectName);

      if (cleanObject != null) {
        final objectRow = await _client
            .from('app_notification_clears')
            .select('cleared_at')
            .eq('user_id', userId)
            .eq('object_name', cleanObject)
            .maybeSingle();

        clearDate = _maxDate(clearDate, _parseDate(objectRow?['cleared_at']));
      }

      return clearDate;
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return null;

      rethrow;
    }
  }

  static Future<Set<String>> _fetchReadNotificationIds(List<String> ids) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty || ids.isEmpty) return <String>{};

    try {
      final rows = await _client
          .from('app_notification_reads')
          .select('notification_id')
          .eq('user_id', userId)
          .inFilter('notification_id', ids);

      return rows
          .map<String>((row) => row['notification_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return <String>{};

      rethrow;
    }
  }

  static Future<List<AppNotification>> fetchLatest({
    String? objectName,
    int limit = 40,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final isForeman = profile?.isForeman == true && profile?.isAdmin != true;
      final profileObject = cleanObjectName(profile?.objectName);
      final visibleObject = isForeman
          ? cleanObject ?? profileObject
          : cleanObject;
      final clearDate = await _fetchClearDate(visibleObject);

      dynamic query = _client
          .from('app_notifications')
          .select(
            'id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, created_at',
          );

      if (visibleObject != null) {
        query = query.eq('object_name', visibleObject);
      }

      if (isForeman) {
        query = query.inFilter('entity_type', foremanAllowedEntityTypes);
      }

      if (clearDate != null) {
        query = query.gt('created_at', clearDate.toUtc().toIso8601String());
      }

      final List<dynamic> rows = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final ids = rows
          .map<String>((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final readIds = await _fetchReadNotificationIds(ids);

      return rows.map<AppNotification>((row) {
        final map = row as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';

        return AppNotification.fromSupabase(
          map,
          isRead: id.isNotEmpty && readIds.contains(id),
        );
      }).toList();
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return <AppNotification>[];

      rethrow;
    }
  }

  static Future<bool> hasUnread({String? objectName}) async {
    final notifications = await fetchLatest(objectName: objectName, limit: 30);

    return notifications.any((notification) => !notification.isRead);
  }

  static Future<void> markAsRead(List<String> notificationIds) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    final ids = notificationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = ids.map((id) {
      return {'user_id': userId, 'notification_id': id, 'read_at': now};
    }).toList();

    try {
      await _client
          .from('app_notification_reads')
          .upsert(rows, onConflict: 'user_id,notification_id');
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return;

      rethrow;
    }
  }

  static Future<void> clearNotifications({String? objectName}) async {
    final userId = _currentUserId;

    if (userId == null || userId.isEmpty) return;

    final cleanObject = cleanObjectName(objectName) ?? '';

    try {
      await _client.rpc(
        'clear_current_company_notifications',
        params: <String, dynamic>{'p_object_name': cleanObject},
      );
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return;

      rethrow;
    }
  }
}
