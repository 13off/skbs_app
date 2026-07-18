import 'package:supabase_flutter/supabase_flutter.dart';

class DispatcherObjectOption {
  final String id;
  final String name;

  const DispatcherObjectOption({required this.id, required this.name});

  factory DispatcherObjectOption.fromJson(Map<String, dynamic> json) {
    return DispatcherObjectOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class DispatcherSummarySettings {
  final String objectId;
  final String objectName;
  final bool enabled;
  final String localTime;
  final String timezone;
  final Set<int> weekdays;
  final Set<String> recipientRoles;
  final bool inAppEnabled;
  final bool pushEnabled;
  final bool includeTasks;
  final bool includeAttendance;
  final bool includeEmployees;
  final bool includePayments;
  final bool includeRecruitment;
  final bool includeLegal;
  final bool includeMilestones;
  final bool includeEmptySections;
  final bool aiCommentary;

  const DispatcherSummarySettings({
    required this.objectId,
    required this.objectName,
    required this.enabled,
    required this.localTime,
    required this.timezone,
    required this.weekdays,
    required this.recipientRoles,
    required this.inAppEnabled,
    required this.pushEnabled,
    required this.includeTasks,
    required this.includeAttendance,
    required this.includeEmployees,
    required this.includePayments,
    required this.includeRecruitment,
    required this.includeLegal,
    required this.includeMilestones,
    required this.includeEmptySections,
    required this.aiCommentary,
  });

  static const defaults = DispatcherSummarySettings(
    objectId: '',
    objectName: '',
    enabled: false,
    localTime: '18:30',
    timezone: 'Europe/Moscow',
    weekdays: <int>{1, 2, 3, 4, 5, 6, 7},
    recipientRoles: <String>{'admin'},
    inAppEnabled: true,
    pushEnabled: true,
    includeTasks: true,
    includeAttendance: true,
    includeEmployees: true,
    includePayments: true,
    includeRecruitment: true,
    includeLegal: true,
    includeMilestones: true,
    includeEmptySections: false,
    aiCommentary: true,
  );

  DispatcherSummarySettings copyWith({
    String? objectId,
    String? objectName,
    bool? enabled,
    String? localTime,
    String? timezone,
    Set<int>? weekdays,
    Set<String>? recipientRoles,
    bool? inAppEnabled,
    bool? pushEnabled,
    bool? includeTasks,
    bool? includeAttendance,
    bool? includeEmployees,
    bool? includePayments,
    bool? includeRecruitment,
    bool? includeLegal,
    bool? includeMilestones,
    bool? includeEmptySections,
    bool? aiCommentary,
  }) {
    return DispatcherSummarySettings(
      objectId: objectId ?? this.objectId,
      objectName: objectName ?? this.objectName,
      enabled: enabled ?? this.enabled,
      localTime: localTime ?? this.localTime,
      timezone: timezone ?? this.timezone,
      weekdays: weekdays ?? this.weekdays,
      recipientRoles: recipientRoles ?? this.recipientRoles,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      includeTasks: includeTasks ?? this.includeTasks,
      includeAttendance: includeAttendance ?? this.includeAttendance,
      includeEmployees: includeEmployees ?? this.includeEmployees,
      includePayments: includePayments ?? this.includePayments,
      includeRecruitment: includeRecruitment ?? this.includeRecruitment,
      includeLegal: includeLegal ?? this.includeLegal,
      includeMilestones: includeMilestones ?? this.includeMilestones,
      includeEmptySections: includeEmptySections ?? this.includeEmptySections,
      aiCommentary: aiCommentary ?? this.aiCommentary,
    );
  }

  factory DispatcherSummarySettings.fromJson(Map<String, dynamic> json) {
    return DispatcherSummarySettings(
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      enabled: json['enabled'] == true,
      localTime: _time(json['local_time']),
      timezone: json['timezone']?.toString() ?? 'Europe/Moscow',
      weekdays: _intSet(
        json['weekdays'],
        const <int>{1, 2, 3, 4, 5, 6, 7},
      ),
      recipientRoles: _stringSet(
        json['recipient_roles'],
        const <String>{'admin'},
      ),
      inAppEnabled: json['in_app_enabled'] != false,
      pushEnabled: json['push_enabled'] != false,
      includeTasks: json['include_tasks'] != false,
      includeAttendance: json['include_attendance'] != false,
      includeEmployees: json['include_employees'] != false,
      includePayments: json['include_payments'] != false,
      includeRecruitment: json['include_recruitment'] != false,
      includeLegal: json['include_legal'] != false,
      includeMilestones: json['include_milestones'] != false,
      includeEmptySections: json['include_empty_sections'] == true,
      aiCommentary: json['ai_commentary'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'object_id': objectId,
    'enabled': enabled,
    'local_time': localTime,
    'timezone': timezone,
    'weekdays': weekdays.toList()..sort(),
    'recipient_roles': recipientRoles.toList()..sort(),
    'in_app_enabled': inAppEnabled,
    'push_enabled': pushEnabled,
    'include_tasks': includeTasks,
    'include_attendance': includeAttendance,
    'include_employees': includeEmployees,
    'include_payments': includePayments,
    'include_recruitment': includeRecruitment,
    'include_legal': includeLegal,
    'include_milestones': includeMilestones,
    'include_empty_sections': includeEmptySections,
    'ai_commentary': aiCommentary,
  };

  static String _time(dynamic value) {
    final raw = value?.toString() ?? '18:30';
    final parts = raw.split(':');
    if (parts.length < 2) return '18:30';
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  static Set<int> _intSet(dynamic value, Set<int> fallback) {
    if (value is! List) return fallback;
    final result = value
        .map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .toSet();
    return result.isEmpty ? fallback : result;
  }

  static Set<String> _stringSet(dynamic value, Set<String> fallback) {
    if (value is! List) return fallback;
    final result = value
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toSet();
    return result.isEmpty ? fallback : result;
  }
}

class DispatcherSummaryRun {
  final String id;
  final String objectId;
  final String objectName;
  final DateTime? summaryDate;
  final String status;
  final String title;
  final String body;
  final bool aiUsed;
  final String errorText;
  final int attempts;
  final DateTime? sentAt;

  const DispatcherSummaryRun({
    required this.id,
    required this.objectId,
    required this.objectName,
    required this.summaryDate,
    required this.status,
    required this.title,
    required this.body,
    required this.aiUsed,
    required this.errorText,
    required this.attempts,
    required this.sentAt,
  });

  factory DispatcherSummaryRun.fromJson(Map<String, dynamic> json) {
    return DispatcherSummaryRun(
      id: json['id']?.toString() ?? '',
      objectId: json['object_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      summaryDate: DateTime.tryParse(json['summary_date']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'pending',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      aiUsed: json['ai_used'] == true,
      errorText: json['error_text']?.toString() ?? '',
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? ''),
    );
  }
}

class DispatcherSummaryCenter {
  final DispatcherSummarySettings settings;
  final List<DispatcherObjectOption> objects;
  final List<DispatcherSummaryRun> runs;

  const DispatcherSummaryCenter({
    required this.settings,
    required this.objects,
    required this.runs,
  });

  factory DispatcherSummaryCenter.fromJson(Map<String, dynamic> json) {
    final settingsMap = _map(json['settings']);
    final objectRows = json['objects'] is List
        ? json['objects'] as List
        : const <dynamic>[];
    final runRows = json['runs'] is List
        ? json['runs'] as List
        : const <dynamic>[];
    return DispatcherSummaryCenter(
      settings: settingsMap.isEmpty
          ? DispatcherSummarySettings.defaults
          : DispatcherSummarySettings.fromJson(settingsMap),
      objects: objectRows
          .map((item) => DispatcherObjectOption.fromJson(_map(item)))
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(),
      runs: runRows
          .map((item) => DispatcherSummaryRun.fromJson(_map(item)))
          .toList(),
    );
  }
}

class DispatcherSummaryRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const roleTitles = <String, String>{
    'admin': 'Руководитель',
    'foreman': 'Прораб',
    'hr': 'HR-менеджер',
    'accountant': 'Бухгалтер',
    'lawyer': 'Юрист',
  };

  static const timezoneTitles = <String, String>{
    'Europe/Moscow': 'Москва',
    'Europe/Berlin': 'Берлин',
    'Asia/Yekaterinburg': 'Екатеринбург',
    'Asia/Krasnoyarsk': 'Красноярск',
    'Asia/Novosibirsk': 'Новосибирск',
    'Asia/Vladivostok': 'Владивосток',
  };

  static Future<DispatcherSummaryCenter> fetchCenter() async {
    final result = await _client.rpc<dynamic>('get_dispatcher_summary_center');
    return DispatcherSummaryCenter.fromJson(_map(result));
  }

  static Future<DispatcherSummarySettings> save(
    DispatcherSummarySettings settings,
  ) async {
    final result = await _client.rpc<dynamic>(
      'save_dispatcher_summary_settings',
      params: <String, dynamic>{'p_settings': settings.toJson()},
    );
    return DispatcherSummarySettings.fromJson(_map(result));
  }

  static Future<String> runNow() async {
    final result = await _client.rpc<dynamic>('run_dispatcher_summary_now');
    return result?.toString() ?? '';
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
