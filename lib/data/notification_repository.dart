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
  });

  factory AppNotification.fromSupabase(Map<String, dynamic> json) {
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
    );
  }
}

class NotificationRepository {
  static final _client = Supabase.instance.client;

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static bool _isMissingNotificationsTableError(Object error) {
    final text = error.toString().toLowerCase();

    return text.contains('42p01') ||
        text.contains('relation') && text.contains('app_notifications') ||
        text.contains('schema cache') && text.contains('app_notifications');
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

      final actorName =
          profile?.fullName.trim().isNotEmpty == true
              ? profile!.fullName.trim()
              : profile?.email.trim().isNotEmpty == true
              ? profile!.email.trim()
              : user?.email?.trim().isNotEmpty == true
              ? user!.email!.trim()
              : 'Пользователь';

      final actorEmail =
          profile?.email.trim().isNotEmpty == true
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

  static Future<List<AppNotification>> fetchLatest({
    String? objectName,
    int limit = 40,
  }) async {
    final cleanObject = cleanObjectName(objectName);

    try {
      final List<dynamic> rows = cleanObject == null
          ? await _client
                .from('app_notifications')
                .select(
                  'id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, created_at',
                )
                .order('created_at', ascending: false)
                .limit(limit)
          : await _client
                .from('app_notifications')
                .select(
                  'id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, created_at',
                )
                .eq('object_name', cleanObject)
                .order('created_at', ascending: false)
                .limit(limit);

      return rows.map<AppNotification>((row) {
        return AppNotification.fromSupabase(row as Map<String, dynamic>);
      }).toList();
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return <AppNotification>[];

      rethrow;
    }
  }
}
