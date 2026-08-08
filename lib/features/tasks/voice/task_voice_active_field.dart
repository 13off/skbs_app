enum TaskVoiceField { date, axes, work, assignees }

String taskVoiceFieldTitle(TaskVoiceField field) => switch (field) {
      TaskVoiceField.date => 'Дата',
      TaskVoiceField.axes => 'Оси',
      TaskVoiceField.work => 'Вид работ',
      TaskVoiceField.assignees => 'Исполнитель',
    };

String taskVoiceFieldMarker(TaskVoiceField field) => switch (field) {
      TaskVoiceField.date => 'дата',
      TaskVoiceField.axes => 'оси',
      TaskVoiceField.work => 'вид работ',
      TaskVoiceField.assignees => 'исполнитель',
    };

TaskVoiceField? resolveTaskVoiceActiveField({
  required String transcript,
  required TaskVoiceField? currentField,
}) {
  final source = transcript.trim();
  if (source.isEmpty) return currentField;

  final reset = RegExp(
    r'(?:начн[её]м\s+заново|начать\s+заново)',
    caseSensitive: false,
  );
  var effectiveCurrent = reset.hasMatch(source) ? null : currentField;
  final resetMatch = reset.allMatches(source).lastOrNull;
  final searchSource = resetMatch == null
      ? source
      : source.substring(resetMatch.end).trim();

  final markers = _findTaskVoiceFieldMarkers(searchSource);
  if (markers.isEmpty) return effectiveCurrent;
  return markers.last.field;
}

String routeTaskVoiceTranscript({
  required String transcript,
  required TaskVoiceField? activeField,
}) {
  final source = transcript.trim();
  if (source.isEmpty || activeField == null) return transcript;
  if (_findTaskVoiceFieldMarkers(source).isNotEmpty) return transcript;
  if (_isTaskVoiceControlOnly(source)) return transcript;
  return '${taskVoiceFieldMarker(activeField)} $source';
}

class _TaskVoiceFieldMarker {
  final TaskVoiceField field;
  final int start;

  const _TaskVoiceFieldMarker(this.field, this.start);
}

List<_TaskVoiceFieldMarker> _findTaskVoiceFieldMarkers(String source) {
  final markers = <_TaskVoiceFieldMarker>[];

  void collect(TaskVoiceField field, RegExp expression) {
    for (final match in expression.allMatches(source)) {
      final prefix = match.group(1) ?? '';
      markers.add(_TaskVoiceFieldMarker(field, match.start + prefix.length));
    }
  }

  collect(
    TaskVoiceField.date,
    RegExp(
      r'(^|[^А-Яа-яЁё])(дата|дату)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.axes,
    RegExp(
      r'(^|[^А-Яа-яЁё])(оси)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.work,
    RegExp(
      r'(^|[^А-Яа-яЁё])(вид\s+работ(?:ы)?)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.assignees,
    RegExp(
      r'(^|[^А-Яа-яЁё])(исполнитель|исполнители)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  markers.sort((left, right) => left.start.compareTo(right.start));
  return markers;
}

bool _isTaskVoiceControlOnly(String source) {
  final normalized = source
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return RegExp(
    r'^(?:все\s+готово|готово|стоп|закончил(?:а|и)?|начнем\s+заново|начать\s+заново)$',
  ).hasMatch(normalized);
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
