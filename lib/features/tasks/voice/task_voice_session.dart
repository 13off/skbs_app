import '../../../models/employee.dart';
import 'task_voice_employee_matcher.dart';
import 'task_voice_parser.dart';
import 'task_voice_parser_robust.dart';

class TaskVoiceSessionResult {
  final DateTime date;
  final String axes;
  final String work;
  final List<String> assigneeIds;
  final Set<String> changedFields;
  final List<String> missingFields;
  final bool shouldStop;
  final bool resetRequested;
  final String? warning;

  const TaskVoiceSessionResult({
    required this.date,
    required this.axes,
    required this.work,
    required this.assigneeIds,
    required this.changedFields,
    required this.missingFields,
    required this.shouldStop,
    required this.resetRequested,
    this.warning,
  });
}

class _VoiceSegment {
  final String text;
  final bool correction;

  const _VoiceSegment(this.text, this.correction);
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
  final source = _stripStopCommands(transcript);
  final segments = _splitVoiceSegments(source);

  var date = initialDate;
  var axes = initialAxes.trim();
  var work = initialWork.trim();
  var assigneeIds = <String>[...initialAssigneeIds];
  final changed = <String>{};
  var resetRequested = false;
  String? warning;

  for (var index = 0; index < segments.length; index += 1) {
    final segment = segments[index];
    final text = segment.text.trim();
    if (text.isEmpty) continue;

    if (_isResetCommand(text)) {
      date = initialDate;
      axes = '';
      if (!goalTask) work = '';
      assigneeIds = <String>[];
      changed.addAll(<String>{'дата', 'оси', 'задача', 'исполнители'});
      resetRequested = true;
      continue;
    }

    final parsed = parseForemanTaskVoice(
      transcript: text,
      now: now,
      employees: employees,
    );
    final isCorrection = segment.correction || index > 0;

    final asksToKeepDate = RegExp(
      r'оставь\s+дат',
      caseSensitive: false,
    ).hasMatch(text);
    final hasDateIntent = !asksToKeepDate &&
        parsed.date != null &&
        (!isCorrection || _mentionsDate(text));
    if (hasDateIntent) {
      final nextDate = parsed.date!;
      if (allowDateChange || _sameDate(nextDate, initialDate)) {
        date = nextDate;
        changed.add('дата');
      } else {
        warning = 'Дату менять нельзя по правилам объекта.';
      }
    }

    if (_clearsAxes(text)) {
      axes = '';
      changed.add('оси');
    } else if (parsed.axes.isNotEmpty &&
        (!isCorrection || _mentionsAxes(text))) {
      axes = parsed.axes.trim();
      changed.add('оси');
    }

    if (!goalTask) {
      if (_clearsWork(text)) {
        work = '';
        changed.add('задача');
      } else {
        final nextWork = normalizeTaskVoiceWork(
          isCorrection ? _correctionWork(text, parsed.work) : parsed.work,
        );
        final canReplaceWork = nextWork.isNotEmpty &&
            (!isCorrection || _mentionsWork(text));
        if (canReplaceWork) {
          work = nextWork;
          changed.add('задача');
        }
      }
    }

    final assigneeResult = _applyAssigneeSegment(
      text: text,
      employees: employees,
      currentIds: assigneeIds,
      parsedIds: parsed.assigneeIds,
      correction: isCorrection,
    );
    if (assigneeResult.changed) {
      assigneeIds = assigneeResult.ids;
      changed.add('исполнители');
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

class _AssigneeSegmentResult {
  final List<String> ids;
  final bool changed;

  const _AssigneeSegmentResult(this.ids, this.changed);
}

_AssigneeSegmentResult _applyAssigneeSegment({
  required String text,
  required List<Employee> employees,
  required List<String> currentIds,
  required List<String> parsedIds,
  required bool correction,
}) {
  final current = <String>{...currentIds};
  final clearAll = RegExp(
    r'(?:очисти\s+исполнител|убери\s+всех\s+исполнител|удали\s+всех\s+исполнител)',
    caseSensitive: false,
  ).hasMatch(text);
  if (clearAll) {
    return const _AssigneeSegmentResult(<String>[], true);
  }

  final add = RegExp(
    r'(?:добавь|добавить)\s+(?:ещ[её]\s+)?',
    caseSensitive: false,
  ).hasMatch(text);
  if (add && !RegExp(r'добавь\s+задач', caseSensitive: false).hasMatch(text)) {
    final ids = resolveTaskVoiceEmployeeIds(
      transcript: text,
      employees: employees,
      replaceOnExplicitMarker: false,
      scopeAfterLastMarker: false,
    );
    current.addAll(ids);
    return _AssigneeSegmentResult(current.toList(growable: false), ids.isNotEmpty);
  }

  final remove = RegExp(
    r'(?:убери|удали|сними)\s+',
    caseSensitive: false,
  ).hasMatch(text);
  if (remove) {
    final ids = resolveTaskVoiceEmployeeIds(
      transcript: text,
      employees: employees,
      replaceOnExplicitMarker: false,
      scopeAfterLastMarker: false,
    );
    if (ids.isEmpty && taskVoiceAssigneeMarker.hasMatch(text)) {
      return const _AssigneeSegmentResult(<String>[], true);
    }
    final before = current.length;
    current.removeAll(ids);
    return _AssigneeSegmentResult(
      current.toList(growable: false),
      before != current.length,
    );
  }

  final explicit = taskVoiceAssigneeMarker.hasMatch(text);
  if (explicit) {
    final resolved = resolveTaskVoiceEmployeeIds(
      transcript: text,
      employees: employees,
      fallbackIds: parsedIds,
    );
    if (resolved.isNotEmpty) {
      return _AssigneeSegmentResult(resolved, true);
    }
    if (correction) {
      return const _AssigneeSegmentResult(<String>[], true);
    }
  }

  if (!correction && parsedIds.isNotEmpty) {
    final resolved = resolveTaskVoiceEmployeeIds(
      transcript: text,
      employees: employees,
      fallbackIds: parsedIds,
      replaceOnExplicitMarker: false,
      scopeAfterLastMarker: false,
    );
    return _AssigneeSegmentResult(resolved, resolved.isNotEmpty);
  }

  return _AssigneeSegmentResult(currentIds, false);
}

List<TaskVoiceDraft> parseForemanTaskVoiceBatch({
  required String transcript,
  required DateTime now,
  required List<Employee> employees,
}) {
  final source = _stripStopCommands(transcript).trim();
  if (source.isEmpty) return const <TaskVoiceDraft>[];

  final explicitChunks = source
      .split(
        RegExp(
          r'\s+(?:следующая\s+задача|следующая|дальше|затем|потом)\s+',
          caseSensitive: false,
        ),
      )
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty)
      .toList();
  if (explicitChunks.length > 1) {
    final parsed = _parseBatchChunks(explicitChunks, now, employees);
    if (parsed.length > 1) return parsed;
  }

  if (taskVoiceAssigneeMarker.hasMatch(source)) {
    return const <TaskVoiceDraft>[];
  }

  final mentions = findTaskVoiceEmployeeMentions(
    transcript: source,
    employees: employees,
  );
  final uniqueOrdered = <TaskVoiceEmployeeMention>[];
  final seen = <String>{};
  for (final mention in mentions) {
    if (seen.add(mention.employeeId)) uniqueOrdered.add(mention);
  }
  if (uniqueOrdered.length < 2) return const <TaskVoiceDraft>[];

  final chunks = <String>[];
  for (var index = 0; index < uniqueOrdered.length; index += 1) {
    final start = index == 0 ? 0 : uniqueOrdered[index].start;
    final end = index + 1 < uniqueOrdered.length
        ? uniqueOrdered[index + 1].start
        : source.length;
    final chunk = source.substring(start, end).trim();
    if (chunk.isNotEmpty) chunks.add(chunk);
  }
  if (chunks.length < 2) return const <TaskVoiceDraft>[];

  final parsed = _parseBatchChunks(chunks, now, employees);
  if (parsed.length < 2) return const <TaskVoiceDraft>[];

  final firstDate = parsed.first.date;
  return parsed
      .map(
        (draft) => TaskVoiceDraft(
          date: draft.date ?? firstDate,
          axes: draft.axes,
          work: normalizeTaskVoiceWork(draft.work),
          assigneeIds: draft.assigneeIds,
          assigneeNames: draft.assigneeNames,
        ),
      )
      .toList(growable: false);
}

List<TaskVoiceDraft> _parseBatchChunks(
  List<String> chunks,
  DateTime now,
  List<Employee> employees,
) {
  final result = <TaskVoiceDraft>[];
  DateTime? inheritedDate;
  for (final chunk in chunks) {
    final draft = parseForemanTaskVoice(
      transcript: chunk,
      now: now,
      employees: employees,
    );
    final work = normalizeTaskVoiceWork(draft.work);
    if (work.isEmpty || draft.assigneeIds.isEmpty) continue;
    inheritedDate ??= draft.date;
    result.add(
      TaskVoiceDraft(
        date: draft.date ?? inheritedDate,
        axes: draft.axes,
        work: work,
        assigneeIds: draft.assigneeIds,
        assigneeNames: draft.assigneeNames,
      ),
    );
  }
  return result;
}

String normalizeTaskVoiceWork(String source) {
  var value = source
      .replaceAll(
        RegExp(
          r'^(?:там\s+)?(?:короче\s+)?(?:надо|нужно)\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\bкороче\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (value.isEmpty) return '';

  value = value
      .replaceAll(
        RegExp(r'\bдоармировать\b', caseSensitive: false),
        'завершить армирование',
      )
      .replaceAll(
        RegExp(r'\bдобить\s+опалубку\b', caseSensitive: false),
        'завершить опалубку',
      )
      .replaceAllMapped(
        RegExp(
          r'\bзалить\s+(плиту|стену|колонну|колонны|ростверк|ригель|балку)\b',
          caseSensitive: false,
        ),
        (match) => 'забетонировать ${match.group(1) ?? ''}',
      )
      .replaceAll(
        RegExp(r'\bдобить\s+армирование\b', caseSensitive: false),
        'завершить армирование',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (value.isEmpty) return '';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

List<_VoiceSegment> _splitVoiceSegments(String source) {
  final cue = RegExp(
    r'(?:^|[\s,;.])(?:нет(?:\s|,|;|\.)|исправь(?:\s|,|;|\.)|поменяй(?:\s|,|;|\.)|замени(?:\s|,|;|\.)|убери(?:\s|,|;|\.)|удали(?:\s|,|;|\.)|очисти(?:\s|,|;|\.)|оставь(?:\s|,|;|\.)|добавь\s+ещ[её](?:\s|,|;|\.)|начн(?:ем|ём)\s+заново(?:\s|,|;|\.)|сначала(?:\s|,|;|\.))',
    caseSensitive: false,
  );
  final matches = cue.allMatches(source).toList();
  if (matches.isEmpty) return <_VoiceSegment>[_VoiceSegment(source, false)];

  final result = <_VoiceSegment>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      final plain = source.substring(cursor, match.start).trim();
      if (plain.isNotEmpty) result.add(_VoiceSegment(plain, false));
    }
    final start = match.start;
    final nextIndex = matches.indexOf(match) + 1;
    final end = nextIndex < matches.length ? matches[nextIndex].start : source.length;
    final correction = source.substring(start, end).trim();
    if (correction.isNotEmpty) result.add(_VoiceSegment(correction, true));
    cursor = end;
  }
  if (cursor < source.length) {
    final tail = source.substring(cursor).trim();
    if (tail.isNotEmpty) result.add(_VoiceSegment(tail, false));
  }
  return result;
}

bool _mentionsDate(String value) => RegExp(
      r'(?:дат(?:а|у|е|ой)|сегодня|завтра|послезавтра|понедельник|вторник|сред[ау]|четверг|пятниц[ау]|суббот[ау]|воскресенье|\d{1,2}[./-]\d{1,2})',
      caseSensitive: false,
    ).hasMatch(value);

bool _mentionsAxes(String value) => RegExp(
      r'(?:ось|оси|по\s+осям)',
      caseSensitive: false,
    ).hasMatch(value);

bool _mentionsWork(String value) => RegExp(
      r'(?:вид\s+работ(?:ы)?|задач(?:а|у|е)|работ(?:а|у))',
      caseSensitive: false,
    ).hasMatch(value);

bool _clearsAxes(String value) => RegExp(
      r'(?:очисти|убери|удали)\s+(?:ось|оси)',
      caseSensitive: false,
    ).hasMatch(value);

bool _clearsWork(String value) => RegExp(
      r'(?:очисти|убери|удали)\s+(?:задачу|работу|вид\s+работ)',
      caseSensitive: false,
    ).hasMatch(value);

String _correctionWork(String source, String fallback) {
  final marker = RegExp(
    r'(?:вид\s+работ(?:ы)?|задач(?:а|у|е)|работ(?:а|у))\s*(?:поменяй|замени|исправь)?\s*(?:на\s+)?',
    caseSensitive: false,
  ).firstMatch(source);
  if (marker == null) return fallback;
  var tail = source.substring(marker.end);
  final nextField = RegExp(
    r'(?:дат(?:а|у|е|ой)|(?:ось|оси|по\s+осям)|исполнител(?:ь|и|ей|ям|я)?)',
    caseSensitive: false,
  ).firstMatch(tail);
  if (nextField != null) tail = tail.substring(0, nextField.start);
  return tail
      .replaceAll(RegExp(r'^[\s:;,.-]+|[\s:;,.-]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isResetCommand(String value) => RegExp(
      r'(?:начн(?:ем|ём)\s+заново|сначала|очисти\s+(?:все|всё))',
      caseSensitive: false,
    ).hasMatch(value);

bool _hasStopCommand(String value) => RegExp(
      r'(?:вс[её]\s+готово|готово|закончил|стоп)',
      caseSensitive: false,
    ).hasMatch(value);

String _stripStopCommands(String value) => value
    .replaceAll(
      RegExp(
        r'(?:вс[её]\s+готово|готово|закончил|стоп)',
        caseSensitive: false,
      ),
      ' ',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
