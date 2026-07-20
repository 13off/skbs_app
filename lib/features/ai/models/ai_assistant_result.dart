class AiAssistantAction {
  final String id;
  final String type;
  final String title;
  final String buttonLabel;
  final bool confirmationRequired;
  final Map<String, dynamic> payload;

  const AiAssistantAction({
    required this.id,
    required this.type,
    required this.title,
    required this.buttonLabel,
    required this.confirmationRequired,
    required this.payload,
  });

  factory AiAssistantAction.fromMap(Map<String, dynamic> map) {
    final rawPayload = map['payload'];
    return AiAssistantAction(
      id: map['id']?.toString().trim() ?? '',
      type: map['type']?.toString().trim() ?? '',
      title: map['title']?.toString().trim() ?? '',
      buttonLabel: map['button_label']?.toString().trim().isNotEmpty == true
          ? map['button_label'].toString().trim()
          : 'Проверить действие',
      confirmationRequired: map['confirmation_required'] != false,
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const <String, dynamic>{},
    );
  }

  String text(String key) => payload[key]?.toString().trim() ?? '';

  bool boolean(String key) => payload[key] == true;

  num number(String key) {
    final value = payload[key];
    if (value is num) return value;
    return num.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  List<String> stringList(String key) {
    final value = payload[key];
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  DateTime? date(String key) {
    final value = text(key);
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}

class AiAssistantResult {
  final String title;
  final String summary;
  final List<String> highlights;
  final List<String> warnings;
  final List<String> nextSteps;
  final String scopeLabel;
  final bool preliminary;
  final bool aiUsed;
  final AiAssistantAction? action;

  const AiAssistantResult({
    required this.title,
    required this.summary,
    required this.highlights,
    required this.warnings,
    required this.nextSteps,
    required this.scopeLabel,
    required this.preliminary,
    required this.aiUsed,
    this.action,
  });

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  factory AiAssistantResult.fromMap(Map<String, dynamic> map) {
    final scope = map['scope'];
    final scopeMap = scope is Map
        ? Map<String, dynamic>.from(scope)
        : const <String, dynamic>{};
    final objectName = scopeMap['object_name']?.toString().trim() ?? '';
    final date = scopeMap['date']?.toString().trim() ?? '';
    final scopeParts = <String>[
      if (objectName.isNotEmpty) objectName else 'Все доступные объекты',
      if (date.isNotEmpty) date,
    ];
    final rawAction = map['action'];

    return AiAssistantResult(
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title'].toString().trim()
          : 'Результат помощника',
      summary: map['summary']?.toString().trim() ?? '',
      highlights: _stringList(map['highlights']),
      warnings: _stringList(map['warnings']),
      nextSteps: _stringList(map['next_steps']),
      scopeLabel: scopeParts.join(' • '),
      preliminary: map['preliminary'] != false,
      aiUsed: map['ai_used'] == true,
      action: rawAction is Map
          ? AiAssistantAction.fromMap(Map<String, dynamic>.from(rawAction))
          : null,
    );
  }
}
