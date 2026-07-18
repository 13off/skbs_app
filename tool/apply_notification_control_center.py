from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding='utf-8')
    if old not in text:
        raise RuntimeError(f'{label}: fragment not found in {path}')
    file_path.write_text(text.replace(old, new, 1), encoding='utf-8')


profile = 'lib/screens/profile_screen.dart'
replace_once(
    profile,
    "import 'push_notification_settings_screen.dart';\n",
    "import 'notification_control_center_screen.dart';\nimport 'push_notification_settings_screen.dart';\n",
    'profile import',
)
replace_once(
    profile,
    """  void openPushSettings(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const PushNotificationSettingsScreen(),
      ),
    );
  }

""",
    """  void openPushSettings(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const PushNotificationSettingsScreen(),
      ),
    );
  }

  void openNotificationControlCenter(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const NotificationControlCenterScreen(),
      ),
    );
  }

""",
    'profile opener',
)
replace_once(
    profile,
    """          buildSectionTitle('Уведомления'),
          buildActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push-уведомления',
""",
    """          buildSectionTitle('Уведомления'),
          if (profile.isAdmin)
            buildActionTile(
              icon: Icons.tune_rounded,
              title: 'Настройка уведомлений',
              subtitle:
                  'Колокольчик, push, роли, типы событий и все напоминания компании',
              onTap: () => openNotificationControlCenter(context),
            ),
          buildActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push-уведомления',
""",
    'profile control button',
)

repo = 'lib/data/notification_repository.dart'
models = r'''
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
      selectedEventGroups:
          NotificationRepository.allNotificationEventGroups.toSet(),
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

'''
replace_once(repo, 'class NotificationRepository {\n', models + 'class NotificationRepository {\n', 'repository models')

constants_old = """  static const Map<String, String> notificationRoleTitles = <String, String>{
    'admin': 'Руководитель',
    'foreman': 'Прораб',
    'hr': 'HR-менеджер',
    'accountant': 'Бухгалтер',
    'lawyer': 'Юрист',
  };

"""
constants_new = constants_old + """  static const List<String> allNotificationEventGroups = <String>[
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

  static const Map<String, ReminderDefinition> reminderDefinitions =
      <String, ReminderDefinition>{
    'foreman_brigade_photo': ReminderDefinition(
      title: 'Утреннее фото бригады',
      description: 'Напомнить прорабу сделать и прикрепить фото бригады.',
      recipientRole: 'foreman',
      defaultTime: '07:30',
    ),
    'foreman_fill_tasks': ReminderDefinition(
      title: 'Заполнить задачи на день',
      description: 'Напомнить прорабу, если на объекте ещё нет задач на сегодня.',
      recipientRole: 'foreman',
      defaultTime: '08:00',
    ),
    'foreman_missing_before': ReminderDefinition(
      title: 'Нет фото «До»',
      description: 'Проверять задачи без обязательной фотографии до начала работ.',
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

"""
replace_once(repo, constants_old, constants_new, 'repository constants')

methods = r'''
  static Set<String> _stringSet(
    dynamic value,
    Iterable<String> allowed,
  ) {
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
    final roleSet = _stringSet(
      map['selected_roles'],
      allNotificationRoles,
    );
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

'''
replace_once(
    repo,
    '  static DateTime? _parseDate(dynamic value) {\n',
    methods + '  static DateTime? _parseDate(dynamic value) {\n',
    'repository control methods',
)

edge = 'supabase/functions/dispatch-push-job/index.ts'
replace_once(
    edge,
    """interface JobRow {
  id: string;
  notification_id: string;
  dispatch_token: string;
  status: string;
  attempts: number;
  updated_at: string;
}

""",
    """interface JobRow {
  id: string;
  notification_id: string;
  dispatch_token: string;
  status: string;
  attempts: number;
  updated_at: string;
}

interface AdminNotificationPreference {
  roles: Set<string>;
  eventGroups: Set<string>;
  pushEnabled: boolean;
}

""",
    'edge preference interface',
)
replace_once(
    edge,
    """function normalizeRole(value: unknown) {
  const role = normalize(value);
  if (role === "owner") return "admin";
  if (role === "accounting") return "accountant";
  return ["admin", "foreman", "hr", "accountant", "lawyer"].includes(role)
    ? role
    : "admin";
}

""",
    """function normalizeRole(value: unknown) {
  const role = normalize(value);
  if (role === "owner") return "admin";
  if (role === "accounting") return "accountant";
  return ["admin", "foreman", "hr", "accountant", "lawyer"].includes(role)
    ? role
    : "admin";
}

function notificationEventGroup(entityType: unknown) {
  const value = clean(entityType);
  if (["tasks", "task_assignees", "task_photos", "brigade_photo", "foreman_reminder"].includes(value)) return "tasks";
  if (value === "attendance") return "attendance";
  if (["employees", "employee_private_data", "employee_documents"].includes(value)) return "employees";
  if (["recruitment_application", "recruitment_applications", "recruitment_message", "recruitment_messages", "recruitment_document", "recruitment_documents", "hr_reminder"].includes(value)) return "hr";
  if (["payments", "payment_receipts", "accountant_reminder"].includes(value)) return "payments";
  if (value.startsWith("legal_") || ["legal_document", "legal_matter", "lawyer_reminder"].includes(value)) return "legal";
  return "system";
}

""",
    'edge event group',
)
replace_once(
    edge,
    """    const { data: preferenceRows, error: preferenceError } = await admin
      .from("notification_role_preferences")
      .select("user_id,selected_roles")
      .eq("company_id", notification.company_id);
    if (preferenceError) throw preferenceError;
    const adminPreferences = new Map<string, Set<string>>();
    for (const row of preferenceRows ?? []) {
      const selected = Array.isArray(row.selected_roles)
        ? row.selected_roles.map(normalizeRole)
        : ["admin", "foreman", "hr", "accountant", "lawyer"];
      adminPreferences.set(String(row.user_id), new Set(selected));
    }

    const sourceRole = normalizeRole(
      notification.source_role || notification.target_role || "admin",
    );
""",
    """    const { data: preferenceRows, error: preferenceError } = await admin
      .from("notification_role_preferences")
      .select("user_id,selected_roles,selected_event_groups,push_enabled")
      .eq("company_id", notification.company_id);
    if (preferenceError) throw preferenceError;
    const adminPreferences = new Map<string, AdminNotificationPreference>();
    for (const row of preferenceRows ?? []) {
      const selectedRoles = Array.isArray(row.selected_roles)
        ? row.selected_roles.map(normalizeRole)
        : ["admin", "foreman", "hr", "accountant", "lawyer"];
      const selectedGroups = Array.isArray(row.selected_event_groups)
        ? row.selected_event_groups.map((value: unknown) => clean(value))
        : ["tasks", "attendance", "employees", "hr", "payments", "legal", "system"];
      adminPreferences.set(String(row.user_id), {
        roles: new Set(selectedRoles),
        eventGroups: new Set(selectedGroups),
        pushEnabled: row.push_enabled !== false,
      });
    }

    const sourceRole = normalizeRole(
      notification.source_role || notification.target_role || "admin",
    );
    const sourceEventGroup = notificationEventGroup(notification.entity_type);
    const adminAllowsPush = (userId: string) => {
      const preference = adminPreferences.get(userId) ?? {
        roles: new Set(["admin", "foreman", "hr", "accountant", "lawyer"]),
        eventGroups: new Set(["tasks", "attendance", "employees", "hr", "payments", "legal", "system"]),
        pushEnabled: true,
      };
      return preference.pushEnabled &&
        preference.roles.has(sourceRole) &&
        preference.eventGroups.has(sourceEventGroup);
    };
""",
    'edge preference query',
)
replace_once(
    edge,
    """      if (notification.target_user_id) {
        if (notification.target_user_id === userId) recipientIds.add(userId);
        continue;
      }

      if (role === "admin") {
        const selected = adminPreferences.get(userId) ??
          new Set(["admin", "foreman", "hr", "accountant", "lawyer"]);
        if (selected.has(sourceRole)) recipientIds.add(userId);
        continue;
      }
""",
    """      if (notification.target_user_id) {
        if (notification.target_user_id === userId) {
          if (role !== "admin" || adminAllowsPush(userId)) {
            recipientIds.add(userId);
          }
        }
        continue;
      }

      if (role === "admin") {
        if (adminAllowsPush(userId)) recipientIds.add(userId);
        continue;
      }
""",
    'edge admin recipient filter',
)

contract = 'test/role_notifications_task_photos_contract_test.dart'
replace_once(
    contract,
    """    expectContains('lib/screens/push_notification_settings_screen.dart', const [
      'Какие роли учитывать',
      'Руководителю по умолчанию доступны все направления',
      'Сохранить роли',
    ]);
""",
    """    expectContains('lib/screens/notification_control_center_screen.dart', const [
      'Какие роли учитывать',
      'Типы событий',
      'Напоминания компании',
      'Сохранить все настройки',
    ]);
""",
    'role test settings screen',
)
