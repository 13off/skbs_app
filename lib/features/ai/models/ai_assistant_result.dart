class AiAssistantResult {
  final String title;
  final String summary;
  final List<String> highlights;
  final List<String> warnings;
  final List<String> nextSteps;
  final String scopeLabel;
  final bool preliminary;
  final bool aiUsed;

  const AiAssistantResult({
    required this.title,
    required this.summary,
    required this.highlights,
    required this.warnings,
    required this.nextSteps,
    required this.scopeLabel,
    required this.preliminary,
    required this.aiUsed,
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
    );
  }
}
