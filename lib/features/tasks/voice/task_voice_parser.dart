import '../../../models/employee.dart';

class TaskVoiceDraft {
  final DateTime? date;
  final String axes;
  final String work;
  final List<String> assigneeIds;
  final List<String> assigneeNames;

  const TaskVoiceDraft({
    required this.date,
    required this.axes,
    required this.work,
    required this.assigneeIds,
    required this.assigneeNames,
  });
}

class _TextSpanValue<T> {
  final T value;
  final int start;
  final int end;

  const _TextSpanValue(this.value, this.start, this.end);
}

TaskVoiceDraft parseTaskVoice({
  required String transcript,
  required DateTime now,
  required List<Employee> employees,
}) {
  var remaining = transcript.trim();

  final date = _extractDate(remaining, now);
  if (date != null) {
    remaining = _removeSpan(remaining, date.start, date.end);
  }

  final axes = _extractAxes(remaining);
  if (axes != null) {
    remaining = _removeSpan(remaining, axes.start, axes.end);
  }

  final matched = _matchEmployees(remaining, employees);
  for (final employee in matched) {
    remaining = _removeEmployeeName(remaining, employee);
  }

  final work = _cleanupWork(remaining);

  return TaskVoiceDraft(
    date: date?.value,
    axes: axes?.value ?? '',
    work: work,
    assigneeIds: matched
        .map((employee) => employee.id?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false),
    assigneeNames: matched
        .map((employee) => employee.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false),
  );
}

_TextSpanValue<DateTime>? _extractDate(String source, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final lower = source.toLowerCase().replaceAll('ё', 'е');

  for (final entry in const <String, int>{
    'послезавтра': 2,
    'завтра': 1,
    'сегодня': 0,
  }.entries) {
    final phrase = entry.key;
    final withPreposition = 'на $phrase';
    var index = lower.indexOf(withPreposition);
    var length = withPreposition.length;
    if (index < 0) {
      index = lower.indexOf(phrase);
      length = phrase.length;
    }
    if (index >= 0) {
      return _TextSpanValue<DateTime>(
        today.add(Duration(days: entry.value)),
        index,
        index + length,
      );
    }
  }

  final numeric = RegExp(
    r'(?:на\s+)?(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?',
    caseSensitive: false,
  ).firstMatch(source);
  if (numeric != null) {
    final day = int.tryParse(numeric.group(1) ?? '');
    final month = int.tryParse(numeric.group(2) ?? '');
    var year = int.tryParse(numeric.group(3) ?? '') ?? today.year;
    if (year < 100) year += 2000;
    final value = _validDate(year, month, day);
    if (value != null) {
      return _TextSpanValue<DateTime>(value, numeric.start, numeric.end);
    }
  }

  const months = <String, int>{
    'января': 1,
    'февраля': 2,
    'марта': 3,
    'апреля': 4,
    'мая': 5,
    'июня': 6,
    'июля': 7,
    'августа': 8,
    'сентября': 9,
    'октября': 10,
    'ноября': 11,
    'декабря': 12,
  };
  final monthPattern = months.keys.join('|');
  final spokenDate = RegExp(
    '(?:на\\s+)?(\\d{1,2})\\s+($monthPattern)',
    caseSensitive: false,
  ).firstMatch(source);
  if (spokenDate != null) {
    final day = int.tryParse(spokenDate.group(1) ?? '');
    final month = months[(spokenDate.group(2) ?? '').toLowerCase()];
    var value = _validDate(today.year, month, day);
    if (value != null && value.isBefore(today)) {
      value = _validDate(today.year + 1, month, day);
    }
    if (value != null) {
      return _TextSpanValue<DateTime>(
        value,
        spokenDate.start,
        spokenDate.end,
      );
    }
  }

  const weekDays = <String, int>{
    'понедельник': DateTime.monday,
    'понедельника': DateTime.monday,
    'вторник': DateTime.tuesday,
    'вторника': DateTime.tuesday,
    'среду': DateTime.wednesday,
    'среда': DateTime.wednesday,
    'четверг': DateTime.thursday,
    'четверга': DateTime.thursday,
    'пятницу': DateTime.friday,
    'пятница': DateTime.friday,
    'субботу': DateTime.saturday,
    'суббота': DateTime.saturday,
    'воскресенье': DateTime.sunday,
  };
  for (final entry in weekDays.entries) {
    final phrase = entry.key;
    final withPreposition = 'на $phrase';
    var index = lower.indexOf(withPreposition);
    var length = withPreposition.length;
    if (index < 0) {
      index = lower.indexOf(phrase);
      length = phrase.length;
    }
    if (index < 0) continue;

    var days = (entry.value - today.weekday + 7) % 7;
    if (days == 0) days = 7;
    return _TextSpanValue<DateTime>(
      today.add(Duration(days: days)),
      index,
      index + length,
    );
  }

  return null;
}

DateTime? _validDate(int? year, int? month, int? day) {
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}

_TextSpanValue<String>? _extractAxes(String source) {
  final patterns = <RegExp>[
    RegExp(
      r'(?:оси?|по\s+осям)\s*[:,-]?\s*(?:с\s+)?(\d{1,3})\s+(?:по|до)\s+(\d{1,3})\s+(?:от\s+)?([а-яa-z])\s+(?:по|до)\s+([а-яa-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:оси?|по\s+осям)\s*[:,-]?\s*(\d{1,3})\s+(\d{1,3})\s+([а-яa-z])\s+([а-яa-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:оси?|по\s+осям)?\s*[:,-]?\s*(\d{1,3}\s*(?:-|–|—|по)\s*\d{1,3})\s*(?:[/,]\s*)?([а-яa-z]\s*(?:-|–|—|по)\s*[а-яa-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:оси?|по\s+осям)\s*[:,-]?\s*(\d{1,3}\s*(?:-|–|—|по)\s*\d{1,3})',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:оси?|по\s+осям)\s*[:,-]?\s*([а-яa-z]\s*(?:-|–|—|по)\s*[а-яa-z])',
      caseSensitive: false,
    ),
  ];

  for (var index = 0; index < patterns.length; index += 1) {
    final match = patterns[index].firstMatch(source);
    if (match == null) continue;

    String value;
    if (index <= 1) {
      value = '${match.group(1)}–${match.group(2)} / '
          '${(match.group(3) ?? '').toUpperCase()}–'
          '${(match.group(4) ?? '').toUpperCase()}';
    } else if (index == 2) {
      value = '${_normalizeRange(match.group(1) ?? '')} / '
          '${_normalizeRange(match.group(2) ?? '', uppercase: true)}';
    } else {
      value = _normalizeRange(
        match.group(1) ?? '',
        uppercase: index == 4,
      );
    }

    return _TextSpanValue<String>(value, match.start, match.end);
  }

  return null;
}

String _normalizeRange(String value, {bool uppercase = false}) {
  var clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  clean = clean.replaceAll(RegExp(r'\s*(?:-|–|—|по)\s*'), '–');
  if (uppercase) clean = clean.toUpperCase();
  return clean;
}

List<Employee> _matchEmployees(String source, List<Employee> employees) {
  final normalizedSource = _normalizeWords(source);
  final sourceTokens = normalizedSource
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toSet();

  final surnameCounts = <String, int>{};
  final firstNameCounts = <String, int>{};
  for (final employee in employees) {
    final parts = _normalizeWords(employee.name)
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) continue;
    surnameCounts[parts.first] = (surnameCounts[parts.first] ?? 0) + 1;
    if (parts.length > 1) {
      firstNameCounts[parts[1]] = (firstNameCounts[parts[1]] ?? 0) + 1;
    }
  }

  final matched = <Employee>[];
  for (final employee in employees) {
    final id = employee.id?.trim() ?? '';
    if (id.isEmpty) continue;
    final parts = _normalizeWords(employee.name)
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) continue;

    final fullName = parts.join(' ');
    var isMatched = normalizedSource.contains(fullName);

    final surname = parts.first;
    if (!isMatched && surnameCounts[surname] == 1) {
      isMatched = _variants(surname).any(sourceTokens.contains);
    }

    if (!isMatched && parts.length > 1) {
      final firstName = parts[1];
      if (firstNameCounts[firstName] == 1) {
        isMatched = _variants(firstName).any(sourceTokens.contains);
      }
    }

    if (isMatched) matched.add(employee);
  }

  return matched;
}

Set<String> _variants(String word) {
  final clean = _normalizeWords(word);
  final values = <String>{clean};
  if (clean.isEmpty) return values;

  if (clean.endsWith('а')) {
    final stem = clean.substring(0, clean.length - 1);
    values
      ..add('$stemу')
      ..add('$stemой');
  } else if (clean.endsWith('я')) {
    final stem = clean.substring(0, clean.length - 1);
    values
      ..add('$stemю')
      ..add('$stemей');
  } else if (clean.endsWith('ий')) {
    final stem = clean.substring(0, clean.length - 2);
    values
      ..add('$stemию')
      ..add('$stemия');
  } else if (clean.length >= 3) {
    values
      ..add('$cleanу')
      ..add('$cleanа');
  }
  return values;
}

String _removeEmployeeName(String source, Employee employee) {
  var result = source;
  final parts = _normalizeWords(employee.name)
      .split(' ')
      .where((part) => part.length >= 3)
      .toList();
  for (final part in parts) {
    for (final variant in _variants(part)) {
      result = _removeWord(result, variant);
    }
  }
  return result;
}

String _removeWord(String source, String word) {
  final escaped = RegExp.escape(word);
  final expression = RegExp(
    '(^|[^А-Яа-яЁёA-Za-z0-9])$escaped(?=\$|[^А-Яа-яЁёA-Za-z0-9])',
    caseSensitive: false,
  );
  return source.replaceAllMapped(expression, (match) => match.group(1) ?? '');
}

String _cleanupWork(String source) {
  var value = source
      .replaceAll(RegExp(r'[,;]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final phrases = <RegExp>[
    RegExp(r'^создай\s+задачу\s*', caseSensitive: false),
    RegExp(r'^создать\s+задачу\s*', caseSensitive: false),
    RegExp(r'^поставь\s+задачу\s*', caseSensitive: false),
    RegExp(r'^поставить\s+задачу\s*', caseSensitive: false),
    RegExp(r'^добавь\s+задачу\s*', caseSensitive: false),
    RegExp(r'^задача\s*[:,-]?\s*', caseSensitive: false),
    RegExp(r'^нужно\s+', caseSensitive: false),
    RegExp(r'^надо\s+', caseSensitive: false),
  ];
  for (final phrase in phrases) {
    value = value.replaceFirst(phrase, '');
  }

  value = value
      .replaceAll(
        RegExp(
          r'\b(?:исполнители?|назначить|назначь|назначаем|для)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  value = value
      .replaceFirst(RegExp(r'^(?:на|и)\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s+(?:и|на)$', caseSensitive: false), '')
      .trim();

  if (value.isEmpty) return '';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _normalizeWords(String value) {
  return value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _removeSpan(String source, int start, int end) {
  if (start < 0 || end > source.length || start >= end) return source;
  return '${source.substring(0, start)} ${source.substring(end)}';
}
