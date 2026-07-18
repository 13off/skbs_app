import 'package:supabase_flutter/supabase_flutter.dart';

class DeveloperReminderRule {
  final String id;
  final String name;
  final String body;
  final bool enabled;
  final String scheduleType;
  final String localTime;
  final String timezone;
  final Set<int> weekdays;
  final DateTime? runOnceAt;
  final Set<String> recipientRoles;
  final bool inAppEnabled;
  final bool pushEnabled;
  final String priority;
  final String objectName;
  final int sortOrder;
  final DateTime? lastScheduledAt;

  const DeveloperReminderRule({
    this.id = '',
    required this.name,
    this.body = '',
    this.enabled = true,
    this.scheduleType = 'daily',
    this.localTime = '09:00',
    this.timezone = 'Europe/Moscow',
    this.weekdays = const <int>{1, 2, 3, 4, 5, 6, 7},
    this.runOnceAt,
    this.recipientRoles = const <String>{'admin'},
    this.inAppEnabled = true,
    this.pushEnabled = true,
    this.priority = 'normal',
    this.objectName = '',
    this.sortOrder = 0,
    this.lastScheduledAt,
  });

  factory DeveloperReminderRule.empty() {
    return const DeveloperReminderRule(name: 'Новое напоминание');
  }

  factory DeveloperReminderRule.fromJson(Map<String, dynamic> json) {
    final rawDays = json['weekdays'];
    final rawRoles = json['recipient_roles'];
    return DeveloperReminderRule(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Напоминание',
      body: json['body']?.toString() ?? '',
      enabled: json['enabled'] != false,
      scheduleType: json['schedule_type']?.toString() ?? 'daily',
      localTime: _timeText(json['local_time']),
      timezone: json['timezone']?.toString() ?? 'Europe/Moscow',
      weekdays: rawDays is List
          ? rawDays.map((item) => int.tryParse(item.toString()) ?? 0).where((day) => day > 0).toSet()
          : const <int>{1, 2, 3, 4, 5, 6, 7},
      runOnceAt: DateTime.tryParse(json['run_once_at']?.toString() ?? '')?.toLocal(),
      recipientRoles: rawRoles is List
          ? rawRoles.map((item) => item.toString()).toSet()
          : const <String>{'admin'},
      inAppEnabled: json['in_app_enabled'] != false,
      pushEnabled: json['push_enabled'] != false,
      priority: json['priority']?.toString() ?? 'normal',
      objectName: json['object_name']?.toString() ?? '',
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      lastScheduledAt: DateTime.tryParse(json['last_scheduled_at']?.toString() ?? '')?.toLocal(),
    );
  }

  static String _timeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.length >= 5) return text.substring(0, 5);
    return '09:00';
  }

  DeveloperReminderRule copyWith({
    String? id,
    String? name,
    String? body,
    bool? enabled,
    String? scheduleType,
    String? localTime,
    String? timezone,
    Set<int>? weekdays,
    DateTime? runOnceAt,
    bool clearRunOnceAt = false,
    Set<String>? recipientRoles,
    bool? inAppEnabled,
    bool? pushEnabled,
    String? priority,
    String? objectName,
    int? sortOrder,
    DateTime? lastScheduledAt,
  }) {
    return DeveloperReminderRule(
      id: id ?? this.id,
      name: name ?? this.name,
      body: body ?? this.body,
      enabled: enabled ?? this.enabled,
      scheduleType: scheduleType ?? this.scheduleType,
      localTime: localTime ?? this.localTime,
      timezone: timezone ?? this.timezone,
      weekdays: weekdays ?? this.weekdays,
      runOnceAt: clearRunOnceAt ? null : runOnceAt ?? this.runOnceAt,
      recipientRoles: recipientRoles ?? this.recipientRoles,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      priority: priority ?? this.priority,
      objectName: objectName ?? this.objectName,
      sortOrder: sortOrder ?? this.sortOrder,
      lastScheduledAt: lastScheduledAt ?? this.lastScheduledAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'name': name.trim(),
        'body': body.trim(),
        'enabled': enabled,
        'schedule_type': scheduleType,
        'local_time': localTime,
        'timezone': timezone,
        'weekdays': weekdays.toList()..sort(),
        'run_once_at': scheduleType == 'once' ? runOnceAt?.toUtc().toIso8601String() : null,
        'recipient_roles': recipientRoles.toList()..sort(),
        'in_app_enabled': inAppEnabled,
        'push_enabled': pushEnabled,
        'priority': priority,
        'object_name': objectName.trim(),
        'sort_order': sortOrder,
      };
}

class DeveloperCustomSetting {
  final String id;
  final String key;
  final String name;
  final String description;
  final String category;
  final String valueType;
  final dynamic value;
  final bool enabled;
  final int sortOrder;

  const DeveloperCustomSetting({
    this.id = '',
    required this.key,
    required this.name,
    this.description = '',
    this.category = 'Общие',
    this.valueType = 'text',
    this.value = '',
    this.enabled = true,
    this.sortOrder = 0,
  });

  factory DeveloperCustomSetting.empty() {
    return const DeveloperCustomSetting(
      key: 'custom.setting',
      name: 'Новый параметр',
    );
  }

  factory DeveloperCustomSetting.fromJson(Map<String, dynamic> json) {
    return DeveloperCustomSetting(
      id: json['id']?.toString() ?? '',
      key: json['setting_key']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Параметр',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Общие',
      valueType: json['value_type']?.toString() ?? 'text',
      value: json['value'],
      enabled: json['enabled'] != false,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  DeveloperCustomSetting copyWith({
    String? id,
    String? key,
    String? name,
    String? description,
    String? category,
    String? valueType,
    dynamic value,
    bool? enabled,
    int? sortOrder,
  }) {
    return DeveloperCustomSetting(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      valueType: valueType ?? this.valueType,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        'setting_key': key.trim().toLowerCase(),
        'name': name.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'value_type': valueType,
        'value': value,
        'enabled': enabled,
        'sort_order': sortOrder,
      };
}

class DeveloperConstructorData {
  final List<DeveloperReminderRule> reminders;
  final List<DeveloperCustomSetting> settings;

  const DeveloperConstructorData({
    required this.reminders,
    required this.settings,
  });
}

class DeveloperConstructorRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const Map<String, String> roleTitles = <String, String>{
    'admin': 'Руководитель',
    'developer': 'Разработчик',
    'foreman': 'Прораб',
    'hr': 'HR-менеджер',
    'accountant': 'Бухгалтер',
    'lawyer': 'Юрист',
  };

  static DeveloperConstructorData _parse(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final reminderRows = map['reminders'];
    final settingRows = map['settings'];
    return DeveloperConstructorData(
      reminders: reminderRows is List
          ? reminderRows.whereType<Map>().map((row) => DeveloperReminderRule.fromJson(Map<String, dynamic>.from(row))).toList()
          : <DeveloperReminderRule>[],
      settings: settingRows is List
          ? settingRows.whereType<Map>().map((row) => DeveloperCustomSetting.fromJson(Map<String, dynamic>.from(row))).toList()
          : <DeveloperCustomSetting>[],
    );
  }

  static Future<DeveloperConstructorData> fetch() async {
    return _parse(await _client.rpc('get_developer_constructor_center'));
  }

  static Future<DeveloperReminderRule> saveReminder(DeveloperReminderRule rule) async {
    final raw = await _client.rpc(
      'save_developer_reminder_rule',
      params: <String, dynamic>{'p_rule': rule.toJson()},
    );
    return DeveloperReminderRule.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<void> deleteReminder(String id) async {
    await _client.rpc('delete_developer_reminder_rule', params: <String, dynamic>{'p_rule_id': id});
  }

  static Future<int> testReminder(String id) async {
    final raw = await _client.rpc('test_developer_reminder_rule', params: <String, dynamic>{'p_rule_id': id});
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static Future<DeveloperCustomSetting> saveSetting(DeveloperCustomSetting setting) async {
    final raw = await _client.rpc(
      'save_developer_custom_setting',
      params: <String, dynamic>{'p_setting': setting.toJson()},
    );
    return DeveloperCustomSetting.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static Future<void> deleteSetting(String id) async {
    await _client.rpc('delete_developer_custom_setting', params: <String, dynamic>{'p_setting_id': id});
  }
}
