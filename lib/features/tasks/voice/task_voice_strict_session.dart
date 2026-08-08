import '../../../models/employee.dart';
import 'task_voice_employee_matcher.dart';
import 'task_voice_parser.dart';
import 'task_voice_session.dart'
    hide applyForemanVoiceSession, parseForemanTaskVoiceBatch;

export 'task_voice_session.dart'
    hide applyForemanVoiceSession, parseForemanTaskVoiceBatch;

class _StrictVoiceMarker {
  final String field;
  final int start;
  final int end;

  const _StrictVoiceMarker({
    required this.field,
    required this.start,
    required this.end,
  });
}

TaskVoiceSessionResult applyForemanVoiceSession({
  required String transcript,
  required DateTime now,
  required List<Employee> employees,
  required DateTime initialDate,
  required String initialAxes,
  required String initialWork,
  required List<String> initialAssigneeIds,
  required bool allowDateChange,
  required bool goalTask,
}) {
  final shouldStop = _hasStopCommand(transcript);
  var source = _stripStopCommands(transcript).trim();

  var date = initialDate;
  var axes = initialAxes.trim();
  var work = initialWork.trim();
  var assigneeIds = <String>[...initialAssigneeIds];
  final changed = <String>{};
  var resetRequested = false;
  String? warning;

  final resetMatch = _lastResetMatch(source);
  if (resetMatch != null) {
    date = initialDate;
    axes = '';
    if (!goalTask) work = '';
    assigneeIds = <String>[];
    changed.addAll(<String>{'дата', 'оси', 'задача', 'исполнители'});
    resetRequested = true;
    source = source.substring(resetMatch.end).trim();
  }

  final markers = _findStrictMarkers(source);
  if (markers.isEmpty && source.isNotEmpty) {
    warning =
        'Сначала выберите поле голосом: «оси», «вид работ», «исполнитель» или «дата».';
  }

  for (var index = 0; index < markers.length; index += 1) {
    final marker = markers[index];
    final valueEnd = index + 1 < markers.length
        ? markers[index + 1].start
        : source.length;
    final value = _cleanFieldValue(source.substring(marker.end, valueEnd));
    if (value.isEmpty) continue;

    switch (marker.field) {
      case 'дата':
        if (_isKeepCommand(value)) break;
        final parsed = parseForemanTaskVoice(
          transcript: 'дата $value',
          now: now,
          employees: const <Employee>[],
        );
        final nextDate = parsed.date;
        if (nextDate == null) break;
        if (allowDateChange || _sameDate(nextDate, initialDate)) {
          date = nextDate;
          changed.add('дата');
        } else {
          warning = 'Дату менять нельзя по правилам объекта.';
        }
        break;
      case 'оси':
        if (_isKeepCommand(value)) break;
        if (_isClearCommand(value)) {
          axes = '';
          changed.add('оси');
          break;
        }
        final parsed = parseForemanTaskVoice(
          transcript: 'оси $value',
          now: now,
          employees: const <Employee>[],
        );
        if (parsed.axes.trim().isNotEmpty) {
          axes = parsed.axes.trim();
          changed.add('оси');
        }
        break;
      case 'задача':
        if (goalTask || _isKeepCommand(value)) break;
        if (_isClearCommand(value)) {
          work = '';
          changed.add('задача');
          break;
        }
        final nextWork = normalizeTaskVoiceWork(_stripCorrectionPrefix(value));
        if (nextWork.isNotEmpty) {
          work = nextWork;
          changed.add('задача');
        }
        break;
      case 'исполнители':
        final next = _applyStrictAssignees(
          value: value,
          employees: employees,
          currentIds: assigneeIds,
        );
        if (next.changed) {
          assigneeIds = next.ids;
          changed.add('исполнители');
        }
        break;
    }
  }

  final missing = <String>[];
  if (axes.trim().isEmpty) missing.add('оси');
  if (!goalTask && work.trim().isEmpty) missing.add('задача');
  if (assigneeIds.isEmpty) missing.add('исполнители');

  return TaskVoiceSessionResult(
    date: date,
    axes: axes,
    work: work,
    assigneeIds: assigneeIds,
    changedFields: changed,
    missingFields: missing,
    shouldStop: shouldStop,
    resetRequested: resetRequested,
    warning: warning,
  );
}

class _StrictAssigneeResult {
  final List<String> ids;
  final bool changed;

  const _StrictAssigneeResult(this.ids, this.changed);
}

_StrictAssigneeResult _applyStrictAssignees({
  required String value,
  required List<Employee> employees,
  required List<String> currentIds,
}) {
  if (_isKeepCommand(value)) {
    return _StrictAssigneeResult(currentIds, false);
  }
  if (_isClearCommand(value)) {
    return const _StrictAssigneeResult(<String>[], true);
  }

  final command = _normalize(value);
  final current = <String>{...currentIds};
  final add = RegExp(r'^(?:добавь|добавить)(?:\s+ещ[её])?\s+').hasMatch(command);
  final remove = RegExp(r'^(?:убери|удали|сними)\s+').hasMatch(command);
  final lookupValue = _stripAssigneeCommandPrefix(value);
  final ids = resolveTaskVoiceEmployeeIds(
    transcript: 'исполнитель $lookupValue',
    employees: employees,
  );

  if (add) {
    current.addAll(ids);
    return _StrictAssigneeResult(
      current.toList(growable: false),
      ids.isNotEmpty,
    );
  }
  if (remove) {
    final before = current.length;
    current.removeAll(ids);
    return _StrictAssigneeResult(
      current.toList(growable: false),
      before != current.length,
    );
  }
  if (ids.isNotEmpty) {
    return _StrictAssigneeResult(ids, true);
  }
  return _StrictAssigneeResult(currentIds, false);
}

List<TaskVoiceDraft> parseForemanTaskVoiceBatch({
  required String transcript,
  required DateTime now,
  required List<Employee> employees,
}) {
  final source = _stripStopCommands(transcript).trim();
  final chunks = source
      .split(
        RegExp(
          r'\s*(?:следующая\s+задача|следующая|дальше|затем|потом)\s*[:,-]?\s*',
          caseSensitive: false,
        ),
      )
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty)
      .toList();
  if (chunks.length < 2) return const <TaskVoiceDraft>[];

  final result = <TaskVoiceDraft>[];
  var inheritedDate = DateTime(now.year, now.month, now.day);
  for (final chunk in chunks) {
    final parsed = applyForemanVoiceSession(
      transcript: chunk,
      now: now,
      employees: employees,
      initialDate: inheritedDate,
      initialAxes: '',
      initialWork: '',
      initialAssigneeIds: const <String>[],
      allowDateChange: true,
      goalTask: false,
    );
    if (parsed.work.trim().isEmpty || parsed.assigneeIds.isEmpty) continue;
    inheritedDate = parsed.date;
    final names = employees
        .where((employee) => parsed.assigneeIds.contains(employee.id))
        .map((employee) => employee.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    result.add(
      TaskVoiceDraft(
        date: parsed.date,
        axes: parsed.axes,
        work: parsed.work,
        assigneeIds: parsed.assigneeIds,
        assigneeNames: names,
      ),
    );
  }
  return result.length > 1 ? result : const <TaskVoiceDraft>[];
}

List<_StrictVoiceMarker> _findStrictMarkers(String source) {
  final markers = <_StrictVoiceMarker>[];
  void collect(String field, RegExp expression) {
    for (final match in expression.allMatches(source)) {
      final prefix = match.group(1) ?? '';
      final value = match.group(2) ?? '';
      markers.add(
        _StrictVoiceMarker(
          field: field,
          start: match.start + prefix.length,
          end: match.start + prefix.length + value.length,
        ),
      );
    }
  }

  collect(
    'дата',
    RegExp(
      r'(^|[^А-Яа-яЁё])(дат(?:а|у|е|ой))(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    'оси',
    RegExp(
      r'(^|[^А-Яа-яЁё])(по\s+осям|оси|ось)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    'задача',
    RegExp(
      r'(^|[^А-Яа-яЁё])(вид\s+работ(?:ы)?)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  collect(
    'исполнители',
    RegExp(
      r'(^|[^А-Яа-яЁё])(исполнител(?:ь|и|ей|ям|я)?)(?=$|[^А-Яа-яЁё])',
      caseSensitive: false,
    ),
  );
  markers.sort((left, right) => left.start.compareTo(right.start));
  return markers;
}

RegExpMatch? _lastResetMatch(String source) {
  RegExpMatch? result;
  final expression = RegExp(
    r'(?:начн[её]м\s+заново|начать\s+заново|сначала)',
    caseSensitive: false,
  );
  for (final match in expression.allMatches(source)) {
    result = match;
  }
  return result;
}

bool _hasStopCommand(String source) => RegExp(
      r'(?:вс[её]\s+готово|готово|стоп|закончил(?:а|и)?)',
      caseSensitive: false,
    ).hasMatch(source);

String _stripStopCommands(String source) => source
    .replaceAll(
      RegExp(
        r'(?:вс[её]\s+готово|готово|стоп|закончил(?:а|и)?)',
        caseSensitive: false,
      ),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _cleanFieldValue(String source) => source
    .replaceAll(RegExp(r'^[\s,.:;—–-]+'), '')
    .replaceAll(RegExp(r'[\s,.:;—–-]+$'), '')
    .trim();

String _stripCorrectionPrefix(String source) => source
    .replaceFirst(
      RegExp(
        r'^(?:поменяй|замени|исправь)(?:\s+на)?\s+',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

String _stripAssigneeCommandPrefix(String source) => source
    .replaceFirst(
      RegExp(
        r'^(?:добавь|добавить)(?:\s+ещ[её])?\s+|^(?:убери|удали|сними)\s+',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

bool _isClearCommand(String source) => RegExp(
      r'^(?:очисти|очистить|убери\s+вс[её]|удали\s+вс[её])(?:\s|$)',
      caseSensitive: false,
    ).hasMatch(source.trim());

bool _isKeepCommand(String source) => RegExp(
      r'^(?:оставь|оставить)(?:\s|$)',
      caseSensitive: false,
    ).hasMatch(source.trim());

String _normalize(String source) => source
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;
