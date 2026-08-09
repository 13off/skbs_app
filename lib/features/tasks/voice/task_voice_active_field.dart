import 'task_voice_axis_hearing.dart';

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
  final effectiveCurrent = reset.hasMatch(source) ? null : currentField;
  RegExpMatch? resetMatch;
  for (final match in reset.allMatches(source)) {
    resetMatch = match;
  }
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
  if (source.isEmpty) return transcript;
  if (_isTaskVoiceControlOnly(source)) return transcript;

  final markers = _findTaskVoiceFieldMarkers(source);
  if (markers.isNotEmpty) {
    if (markers.length == 1) {
      final marker = markers.first;
      final prefix = source.substring(0, marker.start).trim();
      final value = source.substring(marker.end).trim();

      // Когда пользователь начинает фразу сразу с разговорного названия поля,
      // превращаем его в канонический маркер строгого роутера.
      if (prefix.isEmpty) {
        if (marker.field == TaskVoiceField.axes) {
          final normalized = normalizeTaskVoiceAxesValue(value);
          return normalized.isEmpty ? 'оси' : 'оси $normalized';
        }
        final canonical = taskVoiceFieldMarker(marker.field);
        return value.isEmpty ? canonical : '$canonical $value';
      }
    }
    return transcript;
  }

  if (activeField == null) return transcript;
  if (activeField == TaskVoiceField.axes) {
    final normalized = normalizeTaskVoiceAxesValue(source);
    return 'оси ${normalized.isEmpty ? source : normalized}';
  }
  return '${taskVoiceFieldMarker(activeField)} $source';
}

class _TaskVoiceFieldMarker {
  final TaskVoiceField field;
  final int start;
  final int end;

  const _TaskVoiceFieldMarker(this.field, this.start, this.end);
}

List<_TaskVoiceFieldMarker> _findTaskVoiceFieldMarkers(String source) {
  final markers = <_TaskVoiceFieldMarker>[];

  void collect(TaskVoiceField field, RegExp expression) {
    for (final match in expression.allMatches(source)) {
      final prefix = match.group(1) ?? '';
      final value = match.group(2) ?? '';
      final start = match.start + prefix.length;
      markers.add(_TaskVoiceFieldMarker(field, start, start + value.length));
    }
  }

  collect(
    TaskVoiceField.date,
    RegExp(
      r'(^|[^А-Яа-яЁё])(дата|дату|когда)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.axes,
    RegExp(
      r'(^|[^А-Яа-яЁё])(ось|оси|по\s+осям)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.work,
    RegExp(
      r'(^|[^А-Яа-яЁё])(вид\s+работ(?:ы)?|работа|задача)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    TaskVoiceField.assignees,
    RegExp(
      r'(^|[^А-Яа-яЁё])(исполнитель|исполнители|кто\s+делает)(?=$|[^А-Яа-яЁё])',
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
