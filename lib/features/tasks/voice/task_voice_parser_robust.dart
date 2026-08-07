import '../../../models/employee.dart';
import 'task_voice_parser.dart';

/// Усиленный разбор живой диктовки прораба.
///
/// Базовый парсер остаётся источником истины для даты и обычных форматов.
/// Здесь дополнительно нормализуем живые оси и аккуратно сопоставляем слегка
/// искажённые браузером фамилии только с реальными сотрудниками объекта.
TaskVoiceDraft parseForemanTaskVoice({
  required String transcript,
  required DateTime now,
  required List<Employee> employees,
}) {
  final spokenAxes = _extractSpokenAxes(transcript);
  var sanitized = transcript;
  if (spokenAxes != null) {
    sanitized = _removeSpan(sanitized, spokenAxes.start, spokenAxes.end);
  }

  final parsed = parseTaskVoice(
    transcript: sanitized,
    now: now,
    employees: employees,
  );
  final labeledWork = _extractLabeledWork(transcript);
  final fuzzy = _matchFuzzyEmployees(
    transcript,
    employees,
    parsed.assigneeIds.toSet(),
  );

  final assigneeIds = <String>[...parsed.assigneeIds];
  final assigneeNames = <String>[...parsed.assigneeNames];
  for (final employee in fuzzy.employees) {
    final id = employee.id?.trim() ?? '';
    if (id.isEmpty || assigneeIds.contains(id)) continue;
    assigneeIds.add(id);
    assigneeNames.add(employee.name.trim());
  }

  var work = labeledWork.isNotEmpty ? labeledWork : parsed.work;
  if (labeledWork.isEmpty) {
    for (final token in fuzzy.rawTokens) {
      work = _removeLooseWord(work, token);
    }
  }

  return TaskVoiceDraft(
    date: parsed.date,
    axes: spokenAxes?.value ?? parsed.axes,
    work: work,
    assigneeIds: assigneeIds,
    assigneeNames: assigneeNames,
  );
}

class _FuzzyEmployeeResult {
  final List<Employee> employees;
  final List<String> rawTokens;

  const _FuzzyEmployeeResult(this.employees, this.rawTokens);
}

_FuzzyEmployeeResult _matchFuzzyEmployees(
  String source,
  List<Employee> employees,
  Set<String> alreadyMatched,
) {
  final marker = RegExp(
    r'исполнител(?:ь|и|ей|ям|я)?',
    caseSensitive: false,
  ).firstMatch(source);
  final scope = marker == null ? source : source.substring(marker.end);
  final tokens = RegExp(r'[А-Яа-яЁё]{4,}').allMatches(scope).toList();
  if (tokens.isEmpty) return const _FuzzyEmployeeResult([], []);

  final surnameCounts = <String, int>{};
  final candidates = <({Employee employee, String surname})>[];
  for (final employee in employees) {
    final id = employee.id?.trim() ?? '';
    final parts = _normalize(employee.name).split(' ');
    if (id.isEmpty || parts.isEmpty || parts.first.length < 4) continue;
    final surname = parts.first;
    surnameCounts[surname] = (surnameCounts[surname] ?? 0) + 1;
    candidates.add((employee: employee, surname: surname));
  }

  final matched = <Employee>[];
  final rawTokens = <String>[];
  final claimedIds = <String>{...alreadyMatched};
  for (final tokenMatch in tokens) {
    final raw = tokenMatch.group(0) ?? '';
    final token = _normalize(raw);
    if (token.length < 4 || _fuzzyStopWords.contains(token)) continue;

    ({Employee employee, int distance})? best;
    var secondDistance = 999;
    for (final candidate in candidates) {
      final id = candidate.employee.id?.trim() ?? '';
      if (claimedIds.contains(id) || surnameCounts[candidate.surname] != 1) {
        continue;
      }
      final distance = _editDistance(token, candidate.surname);
      if (best == null || distance < best.distance) {
        if (best != null) secondDistance = best.distance;
        best = (employee: candidate.employee, distance: distance);
      } else if (distance < secondDistance) {
        secondDistance = distance;
      }
    }
    if (best == null) continue;

    final surname = _normalize(best.employee.name).split(' ').first;
    final longest = token.length > surname.length ? token.length : surname.length;
    final maxDistance = longest <= 5 ? 1 : (longest <= 9 ? 2 : 3);
    final similarity = longest == 0 ? 0.0 : 1 - (best.distance / longest);
    if (best.distance > maxDistance || similarity < 0.72) continue;
    if (best.distance >= secondDistance) continue;

    final id = best.employee.id?.trim() ?? '';
    if (id.isEmpty) continue;
    claimedIds.add(id);
    matched.add(best.employee);
    rawTokens.add(raw);
  }

  return _FuzzyEmployeeResult(matched, rawTokens);
}

const _fuzzyStopWords = <String>{
  'сегодня',
  'завтра',
  'задача',
  'работа',
  'работы',
  'армирование',
  'арматура',
  'опалубка',
  'бетонирование',
  'бетон',
  'колонна',
  'колонны',
  'стена',
  'стены',
  'перекрытие',
  'плита',
  'фундамент',
  'ростверк',
  'ригель',
  'балка',
  'лестница',
  'захватка',
  'секция',
  'этаж',
  'монтаж',
  'демонтаж',
  'закончить',
  'выполнить',
  'подготовить',
  'исполнитель',
  'исполнители',
};

int _editDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < right.length; j += 1) {
      final substitution = previous[j] + (left[i] == right[j] ? 0 : 1);
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      current[j + 1] = _min3(substitution, insertion, deletion);
    }
    previous = current;
  }
  return previous.last;
}

int _min3(int first, int second, int third) {
  var result = first < second ? first : second;
  if (third < result) result = third;
  return result;
}

String _removeLooseWord(String source, String raw) {
  final word = raw.trim();
  if (word.isEmpty) return source;
  return source
      .replaceAll(
        RegExp(
          '(^|[^А-Яа-яЁё])${RegExp.escape(word)}(?=\$|[^А-Яа-яЁё])',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _SpokenAxes {
  final String value;
  final int start;
  final int end;

  const _SpokenAxes(this.value, this.start, this.end);
}

_SpokenAxes? _extractSpokenAxes(String source) {
  final marker = RegExp(
    r'(?:оси?|по\s+осям)',
    caseSensitive: false,
  ).firstMatch(source);
  if (marker == null) return null;

  final tail = source.substring(marker.end);
  final tokens = RegExp(r'[А-Яа-яЁёA-Za-z0-9]+').allMatches(tail).toList();
  if (tokens.isEmpty) return null;

  final accepted = <_AxisToken>[];
  for (final match in tokens) {
    final raw = match.group(0) ?? '';
    final token = _classifyAxisToken(raw);
    if (token == null) break;
    accepted.add(token.copyWith(raw: raw, start: match.start, end: match.end));
  }
  if (accepted.isEmpty) return null;

  final numbers = <int>[];
  final numberTokenIndexes = <int>[];
  final letters = <String>[];
  for (var index = 0; index < accepted.length; index += 1) {
    final token = accepted[index];
    if (token.number != null) {
      numbers.add(token.number!);
      numberTokenIndexes.add(index);
    }
    if (token.letter != null) letters.add(token.letter!);
  }

  // На iPhone Web Speech очень часто слышит короткую «Б» как цифру «6».
  // Корректируем только узкий безопасный случай: после двух осевых чисел,
  // третьим и последним значимым токеном идёт именно «6», букв ещё нет.
  if (letters.isEmpty && numbers.length == 3 && numberTokenIndexes.length == 3) {
    final lastIndex = numberTokenIndexes.last;
    final last = accepted[lastIndex];
    final hasMeaningfulAfter = accepted
        .skip(lastIndex + 1)
        .any((token) => token.number != null || token.letter != null);
    if (!hasMeaningfulAfter && last.raw.trim() == '6') {
      numbers.removeLast();
      letters.add('Б');
    }
  }

  final value = _formatAxes(numbers, letters);
  if (value.isEmpty) return null;

  final end = marker.end + accepted.last.end;
  return _SpokenAxes(value, marker.start, end);
}

String _formatAxes(List<int> numbers, List<String> letters) {
  String numberPart = '';
  if (numbers.length >= 2) {
    numberPart = '${numbers.first}–${numbers[1]}';
  } else if (numbers.length == 1) {
    numberPart = '${numbers.first}';
  }

  String letterPart = '';
  if (letters.length >= 2) {
    letterPart = '${letters.first}–${letters[1]}';
  } else if (letters.length == 1) {
    letterPart = letters.first;
  }

  if (numberPart.isNotEmpty && letterPart.isNotEmpty) {
    return '$numberPart / $letterPart';
  }
  return numberPart.isNotEmpty ? numberPart : letterPart;
}

class _AxisToken {
  final String raw;
  final int start;
  final int end;
  final int? number;
  final String? letter;

  const _AxisToken({
    this.raw = '',
    this.start = 0,
    this.end = 0,
    this.number,
    this.letter,
  });

  _AxisToken copyWith({String? raw, int? start, int? end}) => _AxisToken(
    raw: raw ?? this.raw,
    start: start ?? this.start,
    end: end ?? this.end,
    number: number,
    letter: letter,
  );
}

_AxisToken? _classifyAxisToken(String raw) {
  final token = raw.toLowerCase().replaceAll('ё', 'е');
  if (const {'с', 'по', 'до', 'от', 'между', 'и'}.contains(token)) {
    return const _AxisToken();
  }

  final direct = int.tryParse(token);
  if (direct != null && direct >= 0 && direct <= 999) {
    return _AxisToken(number: direct);
  }

  final number = _axisNumbers[token];
  if (number != null) return _AxisToken(number: number);

  final letter = _axisLetters[token];
  if (letter != null) return _AxisToken(letter: letter);

  return null;
}

const _axisNumbers = <String, int>{
  'ноль': 0,
  'один': 1,
  'одна': 1,
  'первый': 1,
  'первая': 1,
  'первой': 1,
  'первую': 1,
  'два': 2,
  'две': 2,
  'второй': 2,
  'вторая': 2,
  'вторую': 2,
  'три': 3,
  'третий': 3,
  'третья': 3,
  'третью': 3,
  'четыре': 4,
  'четвертый': 4,
  'четвертая': 4,
  'четвертую': 4,
  'пять': 5,
  'пятый': 5,
  'пятая': 5,
  'пятую': 5,
  'шесть': 6,
  'шестой': 6,
  'шестая': 6,
  'шестую': 6,
  'семь': 7,
  'седьмой': 7,
  'седьмая': 7,
  'седьмую': 7,
  'восемь': 8,
  'восьмой': 8,
  'восьмая': 8,
  'восьмую': 8,
  'девять': 9,
  'девятый': 9,
  'девятая': 9,
  'девятую': 9,
  'десять': 10,
  'десятый': 10,
  'десятая': 10,
  'десятую': 10,
  'одиннадцать': 11,
  'двенадцать': 12,
  'тринадцать': 13,
  'четырнадцать': 14,
  'пятнадцать': 15,
  'шестнадцать': 16,
  'семнадцать': 17,
  'восемнадцать': 18,
  'девятнадцать': 19,
  'двадцать': 20,
};

const _axisLetters = <String, String>{
  'а': 'А',
  'б': 'Б',
  'бэ': 'Б',
  'в': 'В',
  'вэ': 'В',
  'г': 'Г',
  'гэ': 'Г',
  'д': 'Д',
  'дэ': 'Д',
  'е': 'Е',
  'ж': 'Ж',
  'жэ': 'Ж',
  'и': 'И',
  'й': 'Й',
  'к': 'К',
  'ка': 'К',
  'л': 'Л',
  'эль': 'Л',
  'м': 'М',
  'эм': 'М',
  'н': 'Н',
  'эн': 'Н',
  'п': 'П',
  'пэ': 'П',
  'р': 'Р',
  'эр': 'Р',
  'с': 'С',
  'эс': 'С',
  'т': 'Т',
  'тэ': 'Т',
};

String _extractLabeledWork(String source) {
  final marker = RegExp(
    r'вид\s+работ(?:ы)?',
    caseSensitive: false,
  ).firstMatch(source);
  if (marker == null) return '';

  final tail = source.substring(marker.end);
  final assigneeMarker = RegExp(
    r'исполнител(?:ь|и|ей|ям|я)?',
    caseSensitive: false,
  ).firstMatch(tail);
  final raw = assigneeMarker == null
      ? tail
      : tail.substring(0, assigneeMarker.start);
  final clean = raw
      .replaceAll(RegExp(r'^[\s:;,.-]+|[\s:;,.-]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) return '';
  return '${clean[0].toUpperCase()}${clean.substring(1)}';
}

String _removeSpan(String source, int start, int end) {
  if (start < 0 || end <= start || end > source.length) return source;
  return '${source.substring(0, start)} ${source.substring(end)}'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
