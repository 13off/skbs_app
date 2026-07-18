import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/push_notification_service.dart';
import 'app_data_sync.dart';
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
  final String targetUserId;
  final String targetRole;
  final String sourceRole;
  final bool requiresAction;
  final DateTime? dueAt;
  final String priority;
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
    this.targetUserId = '',
    this.targetRole = '',
    this.sourceRole = 'admin',
    this.requiresAction = false,
    this.dueAt,
    this.priority = 'normal',
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromSupabase(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) {
    final dueText = json['due_at']?.toString().trim() ?? '';
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
      targetUserId: json['target_user_id']?.toString() ?? '',
      targetRole: json['target_role']?.toString() ?? '',
      sourceRole: json['source_role']?.toString() ?? 'admin',
      requiresAction: json['requires_action'] == true,
      dueAt: dueText.isEmpty ? null : DateTime.tryParse(dueText)?.toLocal(),
      priority: json['priority']?.toString() ?? 'normal',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: isRead,
    );
  }
}

class ReminderDefinition {
  final String title;
  final String description;
  final String recipientRole;
  final String defaultTime;

  const ReminderDefinition({
    required this.title,
    required this.description,
    required this.recipientRole,
    required this.defaultTime,
  });
}

class NotificationControlSettings {
  final bool inAppEnabled;
  final bool pushEnabled;
  final Set<String> selectedRoles;
  final Set<String> selectedEventGroups;

  const NotificationControlSettings({
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.selectedRoles,
    required this.selectedEventGroups,
  });

  factory NotificationControlSettings.defaults() {
    return NotificationControlSettings(
      inAppEnabled: true,
      pushEnabled: true,
      selectedRoles: NotificationRepository.allNotificationRoles.toSet(),
      selectedEventGroups: NotificationRepository.allNotificationEventGroups
          .toSet(),
    );
  }

  NotificationControlSettings copyWith({
    bool? inAppEnabled,
    bool? pushEnabled,
    Set<String>? selectedRoles,
    Set<String>? selectedEventGroups,
  }) {
    return NotificationControlSettings(
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      selectedRoles: selectedRoles ?? this.selectedRoles,
      selectedEventGroups: selectedEventGroups ?? this.selectedEventGroups,
    );
  }
}

class ReminderControlSetting {
  final String key;
  final String recipientRole;
  final bool enabled;
  final String localTime;

  const ReminderControlSetting({
    required this.key,
    required this.recipientRole,
    required this.enabled,
    required this.localTime,
  });

  ReminderControlSetting copyWith({
    String? recipientRole,
    bool? enabled,
    String? localTime,
  }) {
    return ReminderControlSetting(
      key: key,
      recipientRole: recipientRole ?? this.recipientRole,
      enabled: enabled ?? this.enabled,
      localTime: localTime ?? this.localTime,
    );
  }
}

class NotificationControlCenterData {
  final NotificationControlSettings settings;
  final List<ReminderControlSetting> reminders;

  const NotificationControlCenterData({
    required this.settings,
    required this.reminders,
  });
}

class NotificationRepository {
  static final _client = Supabase.instance.client;

  static const List<String> foremanAllowedEntityTypes = <String>[
    'attendance',
    'tasks',
    'task_assignees',
    'task_photos',
    'legal_document',
    'legal_matter',
    'foreman_reminder',
    'brigade_photo',
  ];

  static const List<String> allNotificationRoles = <String>[
    'admin',
    'foreman',
    'hr',
    'accountant',
    'lawyer',
  ];

  static const Map<String, String> notificationRoleTitles = <String, String>{
    'admin': 'Руководитель',
    'foreman': 'Прораб',
    'hr': 'HR-менеджер',
    'accountant': 'Бухгалтер',
    'lawyer': 'Юрист',
  };

  static const List<String> allNotificationEventGroups = <String>[
    'tasks',
    'attendance',
    'employees',
    'hr',
    'payments',
    'legal',
    'system',
  ];

  static const Map<String, String> notificationEventGroupTitles =
      <String, String>{
        'tasks': 'Задачи и фотографии работ',
        'attendance': 'Табель и присутствие',
        'employees': 'Сотрудники и личные данные',
        'hr': 'Кандидаты и кадровая работа',
        'payments': 'Выплаты и чеки',
        'legal': 'Юридические события',
        'system': 'Системные и общие события',
      };

  static const Map<String, ReminderDefinition>
  reminderDefinitions = <String, ReminderDefinition>{
    'foreman_brigade_photo': ReminderDefinition(
      title: 'Утреннее фото бригады',
      description: 'Напомнить прорабу сделать и прикрепить фото бригады.',
      recipientRole: 'foreman',
      defaultTime: '07:30',
    ),
    'foreman_fill_tasks': ReminderDefinition(
      title: 'Заполнить задачи на день',
      description:
          'Напомнить прорабу, если на объекте ещё нет задач на сегодня.',
      recipientRole: 'foreman',
      defaultTime: '08:00',
    ),
    'foreman_missing_before': ReminderDefinition(
      title: 'Нет фото «До»',
      description:
          'Проверять задачи без обязательной фотографии до начала работ.',
      recipientRole: 'foreman',
      defaultTime: '09:00',
    ),
    'foreman_missing_after': ReminderDefinition(
      title: 'Нет фото «После»',
      description: 'Напоминать про незакрытые задачи без итоговой фотографии.',
      recipientRole: 'foreman',
      defaultTime: '17:30',
    ),
    'hr_missing_documents': ReminderDefinition(
      title: 'Кандидаты без документов',
      description: 'Сообщать HR о кандидатах без первого комплекта документов.',
      recipientRole: 'hr',
      defaultTime: '09:15',
    ),
    'hr_unanswered_messages': ReminderDefinition(
      title: 'Сообщения кандидатов без ответа',
      description: 'Сообщать HR о переписках, где кандидат ожидает ответа.',
      recipientRole: 'hr',
      defaultTime: '16:00',
    ),
    'accountant_missing_receipts': ReminderDefinition(
      title: 'Выплаты без чеков',
      description: 'Напоминать бухгалтеру о выплатах без прикреплённых чеков.',
      recipientRole: 'accountant',
      defaultTime: '10:00',
    ),
    'lawyer_due_summary': ReminderDefinition(
      title: 'Юридические сроки',
      description: 'Напоминать юристу о ближайших и просроченных сроках.',
      recipientRole: 'lawyer',
      defaultTime: '08:45',
    ),
    'admin_evening_summary': ReminderDefinition(
      title: 'Итоги рабочего дня',
      description: 'Напоминать руководителю проверить незакрытые направления.',
      recipientRole: 'admin',
      defaultTime: '18:00',
    ),
  };

  static String? cleanObjectName(String? objectName) {
    final clean = objectName?.trim();
    return clean == null || clean.isEmpty ? null : clean;
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

  static String? get _currentUserId => UserRepository.currentUser?.id;

  static Future<String> currentActorName() async {
    try {
      final profile = await UserRepository.fetchCurrentProfile();
      final fullName = profile?.fullName.trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final email = profile?.email.trim() ?? '';
      if (email.isNotEmpty) return email;
    } catch (_) {
      // Не ломаем рабочее действие из-за профиля.
    }
    final email = UserRepository.currentUser?.email?.trim() ?? '';
    return email.isEmpty ? 'Пользователь' : email;
  }

  static Future<void> add({
    required String title,
    required String body,
    String? objectName,
    String entityType = '',
    String entityId = '',
    String? targetUserId,
    String? targetRole,
    bool requiresAction = false,
    DateTime? dueAt,
    String priority = 'normal',
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
      final cleanTargetUser = targetUserId?.trim() ?? '';
      final cleanTargetRole = targetRole?.trim() ?? '';

      final inserted = await _client
          .from('app_notifications')
          .insert(<String, dynamic>{
            'title': title.trim(),
            'body': body.trim(),
            'actor_user_id': user?.id,
            'actor_name': actorName,
            'actor_email': actorEmail,
            'object_name': cleanObjectName(objectName) ?? '',
            'entity_type': entityType.trim(),
            'entity_id': entityId.trim(),
            'target_user_id': cleanTargetUser.isEmpty ? null : cleanTargetUser,
            'target_role': cleanTargetRole.isEmpty ? null : cleanTargetRole,
            'requires_action': requiresAction,
            'due_at': dueAt?.toUtc().toIso8601String(),
            'priority':
                <String>{'low', 'normal', 'high', 'critical'}.contains(priority)
                ? priority
                : 'normal',
          })
          .select('id')
          .maybeSingle();

      AppDataSync.notifyLocal(
        const <AppDataDomain>{AppDataDomain.notifications},
        context: <String, dynamic>{
          'table': 'app_notifications',
          'object_name': cleanObjectName(objectName),
        },
      );

      final notificationId = inserted?['id']?.toString().trim() ?? '';
      if (notificationId.isNotEmpty) {
        unawaited(PushNotificationService.dispatchNotification(notificationId));
      }
    } catch (error) {
      if (_isMissingNotificationsTableError(error)) return;
      // Уведомления не должны ломать основное действие.
    }
  }

  static Future<Set<String>> fetchSelectedNotificationRoles() async {
    final data = await _client.rpc('get_my_notification_role_preferences');
    if (data is List) {
      return data
          .map((value) => value.toString())
          .where(allNotificationRoles.contains)
          .toSet();
    }
    return allNotificationRoles.toSet();
  }

  static Future<Set<String>> saveSelectedNotificationRoles(
    Iterable<String> roles,
  ) async {
    final clean = roles
        .map((role) => role.trim())
        .where(allNotificationRoles.contains)
        .toSet()
        .toList();
    final data = await _client.rpc(
      'set_my_notification_role_preferences',
      params: <String, dynamic>{'p_roles': clean},
    );
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.notifications},
      context: const <String, dynamic>{
        'table': 'notification_role_preferences',
      },
    );
    if (data is List) {
      return data
          .map((value) => value.toString())
          .where(allNotificationRoles.contains)
          .toSet();
    }
    return clean.toSet();
  }

  static Set<String> _stringSet(dynamic value, Iterable<String> allowed) {
    final allowedSet = allowed.toSet();
    if (value is! List) return <String>{};
    return value
        .map((item) => item.toString().trim())
        .where(allowedSet.contains)
        .toSet();
  }

  static NotificationControlCenterData _controlCenterFromRpc(dynamic data) {
    if (data is! Map) {
      return NotificationControlCenterData(
        settings: NotificationControlSettings.defaults(),
        reminders: reminderDefinitions.entries
            .map(
              (entry) => ReminderControlSetting(
                key: entry.key,
                recipientRole: entry.value.recipientRole,
                enabled: false,
                localTime: entry.value.defaultTime,
              ),
            )
            .toList(),
      );
    }
    final map = Map<String, dynamic>.from(data);
    final roleSet = _stringSet(map['selected_roles'], allNotificationRoles);
    final eventSet = _stringSet(
      map['selected_event_groups'],
      allNotificationEventGroups,
    );
    final reminderByKey = <String, ReminderControlSetting>{};
    final rawReminders = map['reminders'];
    if (rawReminders is List) {
      for (final item in rawReminders) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final key = row['key']?.toString().trim() ?? '';
        final definition = reminderDefinitions[key];
        if (definition == null) continue;
        reminderByKey[key] = ReminderControlSetting(
          key: key,
          recipientRole:
              row['recipient_role']?.toString().trim().isNotEmpty == true
              ? row['recipient_role'].toString().trim()
              : definition.recipientRole,
          enabled: row['enabled'] == true,
          localTime: row['local_time']?.toString().trim().isNotEmpty == true
              ? row['local_time'].toString().trim()
              : definition.defaultTime,
        );
      }
    }
    final reminders = reminderDefinitions.entries.map((entry) {
      return reminderByKey[entry.key] ??
          ReminderControlSetting(
            key: entry.key,
            recipientRole: entry.value.recipientRole,
            enabled: false,
            localTime: entry.value.defaultTime,
          );
    }).toList();
    return NotificationControlCenterData(
      settings: NotificationControlSettings(
        inAppEnabled: map['in_app_enabled'] != false,
        pushEnabled: map['push_enabled'] != false,
        selectedRoles: roleSet,
        selectedEventGroups: eventSet,
      ),
      reminders: reminders,
    );
  }

  static Future<NotificationControlCenterData>
  fetchNotificationControlCenter() async {
    final data = await _client.rpc('get_my_notification_control_center');
    return _controlCenterFromRpc(data);
  }

  static Future<NotificationControlCenterData> saveNotificationControlCenter({
    required NotificationControlSettings settings,
    required List<ReminderControlSetting> reminders,
  }) async {
    await _client.rpc(
      'set_my_notification_control_preferences',
      params: <String, dynamic>{
        'p_in_app_enabled': settings.inAppEnabled,
        'p_push_enabled': settings.pushEnabled,
        'p_roles': settings.selectedRoles.toList(),
        'p_event_groups': settings.selectedEventGroups.toList(),
      },
    );
    final data = await _client.rpc(
      'set_company_reminder_settings',
      params: <String, dynamic>{
        'p_settings': reminders
            .map(
              (item) => <String, dynamic>{
                'key': item.key,
                'enabled': item.enabled,
                'local_time': item.localTime,
              },
            )
            .toList(),
      },
    );
    AppDataSync.notifyLocal(
      const <AppDataDomain>{AppDataDomain.notifications},
      context: const <String, dynamic>{
        'table': 'notification_role_preferences',
      },
    );
    return _controlCenterFromRpc(data);
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
            'id, title, body, actor_user_id, actor_name, actor_email, object_name, entity_type, entity_id, target_user_id, target_role, source_role, requires_action, due_at, priority, created_at',
          );
      if (visibleObject != null) query = query.eq('object_name', visibleObject);
      if (isForeman)
        query = query.inFilter('entity_type', foremanAllowedEntityTypes);
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
        final map = Map<String, dynamic>.from(row as Map);
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
    final rows = ids
        .map(
          (id) => <String, dynamic>{
            'user_id': userId,
            'notification_id': id,
            'read_at': now,
          },
        )
        .toList();
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
