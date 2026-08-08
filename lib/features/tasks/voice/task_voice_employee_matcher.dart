import '../../../models/employee.dart';

final taskVoiceAssigneeMarker = RegExp(
  r'исполнител(?:ь|и|ей|ям|я)?',
  caseSensitive: false,
);

const taskVoiceNameStopWords = <String>{
  'сегодня',
  'завтра',
  'послезавтра',
  'дата',
  'дату',
  'дате',
  'датой',
  'задача',
  'задачу',
  'задачи',
  'работа',
  'работу',
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
  'добавь',
  'добавить',
  'убери',
  'удали',
  'замени',
  'поменяй',
  'исправь',
  'оставь',
  'очисти',
  'сначала',
  'заново',
  'первый',
  'первая',
  'второй',
  'вторая',
  'третий',
  'третья',
  'четыре',
  'пять',
  'шесть',
  'семь',
  'восемь',
  'девять',
  'десять',
};

List<String> buildTaskVoiceHints(
  List<Employee> employees, {
  Iterable<String> domainHints = const <String>[],
}) {
  final surnames = <String>[];
  final fullNames = <String>[];
  final firstNames = <String>[];
  for (final employee in employees) {
    final name = employee.name.trim();
    if (name.isEmpty) continue;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.length >= 3) surnames.add(parts.first);
    fullNames.add(name);
    if (parts.length > 1 && parts[1].length >= 3) firstNames.add(parts[1]);
  }
  return <String>[
    ...surnames,
    ...fullNames,
    ...domainHints,
    ...firstNames,
  ];
}

class TaskVoiceEmployeeMention {
  final String employeeId;
  final int start;
  final int end;

  const TaskVoiceEmployeeMention({
    required this.employeeId,
    required this.start,
    required this.end,
  });
}

class _VoiceEmployeeCandidate {
  final Employee employee;
  final String surname;
  final String firstName;

  const _VoiceEmployeeCandidate({
    required this.employee,
    required this.surname,
    required this.firstName,
  });
}

class _VoiceEmployeeScore {
  final _VoiceEmployeeCandidate candidate;
  final double score;

  const _VoiceEmployeeScore(this.candidate, this.score);
}

List<String> resolveTaskVoiceEmployeeIds({
  required String transcript,
  required List<Employee> employees,
  List<String> fallbackIds = const <String>[],
  bool replaceOnExplicitMarker = true,
  bool scopeAfterLastMarker = true,
}) {
  final markers = taskVoiceAssigneeMarker.allMatches(transcript).toList();
  final explicitAssignees = markers.isNotEmpty && replaceOnExplicitMarker;
  final scope = markers.isNotEmpty && scopeAfterLastMarker
      ? transcript.substring(markers.last.end)
      : transcript;
  final resolved = <String>{if (!explicitAssignees) ...fallbackIds};
  final candidates = _buildCandidates(employees);
  final surnameCounts = <String, int>{};
  final firstNameCounts = <String, int>{};

  for (final candidate in candidates) {
    surnameCounts[candidate.surname] =
        (surnameCounts[candidate.surname] ?? 0) + 1;
    if (candidate.firstName.isNotEmpty) {
      firstNameCounts[candidate.firstName] =
          (firstNameCounts[candidate.firstName] ?? 0) + 1;
    }
  }

  final rawTokens = RegExp(r'[А-Яа-яЁё]{3,}')
      .allMatches(scope)
      .map((match) => match.group(0) ?? '')
      .where((token) => token.isNotEmpty)
      .toList();
  final tokens = <String>[];
  for (var index = 0; index < rawTokens.length; index += 1) {
    final current = normalizeTaskVoiceName(rawTokens[index]);
    if (current.length >= 3 && !taskVoiceNameStopWords.contains(current)) {
      tokens.add(current);
    }
    if (index + 1 < rawTokens.length) {
      final next = normalizeTaskVoiceName(rawTokens[index + 1]);
      final joined = '$current$next';
      if (current.length >= 3 &&
          next.length >= 2 &&
          joined.length <= 18 &&
          !taskVoiceNameStopWords.contains(next)) {
        tokens.add(joined);
      }
    }
  }

  for (final token in tokens) {
    _VoiceEmployeeScore? best;
    var secondScore = 0.0;
    for (final candidate in candidates) {
      final id = candidate.employee.id?.trim() ?? '';
      if (id.isEmpty || resolved.contains(id)) continue;
      var score = 0.0;
      if (surnameCounts[candidate.surname] == 1) {
        score = taskVoiceNameMatchScore(token, candidate.surname);
      }
      if (candidate.firstName.isNotEmpty &&
          firstNameCounts[candidate.firstName] == 1) {
        final firstScore =
            taskVoiceNameMatchScore(token, candidate.firstName) - 0.05;
        if (firstScore > score) score = firstScore;
      }
      if (best == null || score > best.score) {
        if (best != null) secondScore = best.score;
        best = _VoiceEmployeeScore(candidate, score);
      } else if (score > secondScore) {
        secondScore = score;
      }
    }
    if (best == null) continue;
    final threshold = token.length <= 4 ? 0.88 : 0.76;
    final requiredMargin = best.score >= 0.94 ? 0.025 : 0.07;
    if (best.score < threshold || best.score - secondScore < requiredMargin) {
      continue;
    }
    final id = best.candidate.employee.id?.trim() ?? '';
    if (id.isNotEmpty) resolved.add(id);
  }
  return resolved.toList(growable: false);
}

List<TaskVoiceEmployeeMention> findTaskVoiceEmployeeMentions({
  required String transcript,
  required List<Employee> employees,
}) {
  final candidates = _buildCandidates(employees);
  final surnameCounts = <String, int>{};
  for (final candidate in candidates) {
    surnameCounts[candidate.surname] =
        (surnameCounts[candidate.surname] ?? 0) + 1;
  }

  final mentions = <TaskVoiceEmployeeMention>[];
  for (final candidate in candidates) {
    final id = candidate.employee.id?.trim() ?? '';
    if (id.isEmpty || surnameCounts[candidate.surname] != 1) continue;
    final forms = taskVoiceNameForms(candidate.surname)
        .where((form) => form.length >= 3)
        .toList()
      ..sort((left, right) => right.length.compareTo(left.length));
    if (forms.isEmpty) continue;
    final expression = RegExp(
      '(^|[^А-Яа-яЁё])(${forms.map(RegExp.escape).join('|')})(?=\$|[^А-Яа-яЁё])',
      caseSensitive: false,
    );
    for (final match in expression.allMatches(transcript)) {
      final prefix = match.group(1) ?? '';
      final value = match.group(2) ?? '';
      mentions.add(
        TaskVoiceEmployeeMention(
          employeeId: id,
          start: match.start + prefix.length,
          end: match.start + prefix.length + value.length,
        ),
      );
    }
  }
  mentions.sort((left, right) => left.start.compareTo(right.start));

  final deduped = <TaskVoiceEmployeeMention>[];
  for (final mention in mentions) {
    if (deduped.isNotEmpty) {
      final previous = deduped.last;
      if (previous.employeeId == mention.employeeId &&
          mention.start <= previous.end + 1) {
        continue;
      }
    }
    deduped.add(mention);
  }
  return deduped;
}

List<_VoiceEmployeeCandidate> _buildCandidates(List<Employee> employees) {
  final candidates = <_VoiceEmployeeCandidate>[];
  for (final employee in employees) {
    final id = employee.id?.trim() ?? '';
    final parts = normalizeTaskVoiceName(employee.name).split(' ');
    if (id.isEmpty || parts.isEmpty || parts.first.length < 3) continue;
    candidates.add(
      _VoiceEmployeeCandidate(
        employee: employee,
        surname: parts.first,
        firstName: parts.length > 1 ? parts[1] : '',
      ),
    );
  }
  return candidates;
}

double taskVoiceNameMatchScore(String heard, String expected) {
  var best = 0.0;
  for (final form in taskVoiceNameForms(expected)) {
    final longest = heard.length > form.length ? heard.length : form.length;
    if (longest == 0) continue;
    final rawDistance = taskVoiceEditDistance(heard, form);
    final rawSimilarity = 1 - rawDistance / longest;
    if (rawSimilarity > best) best = rawSimilarity;
    final heardKey = taskVoicePhoneticKey(heard);
    final formKey = taskVoicePhoneticKey(form);
    if (heardKey.length >= 3 && formKey.length >= 3) {
      final phoneticLongest =
          heardKey.length > formKey.length ? heardKey.length : formKey.length;
      final phoneticSimilarity =
          1 - taskVoiceEditDistance(heardKey, formKey) / phoneticLongest;
      final combined = rawSimilarity * 0.30 + phoneticSimilarity * 0.70;
      if (combined > best) best = combined;
      if (heardKey == formKey && rawSimilarity >= 0.55 && best < 0.91) {
        best = 0.91;
      }
    }
    final prefix = taskVoiceCommonPrefix(heard, form);
    if (prefix >= 5 && rawSimilarity >= 0.65) {
      final boosted = rawSimilarity + 0.04;
      if (boosted > best) best = boosted;
    }
  }
  if (best < 0) return 0;
  return best > 1 ? 1 : best;
}

Set<String> taskVoiceNameForms(String value) {
  final clean = normalizeTaskVoiceName(value);
  final forms = <String>{clean};
  if (clean.length < 3) return forms;
  if (clean.endsWith('а')) {
    final stem = clean.substring(0, clean.length - 1);
    forms
      ..add('${stem}у')
      ..add('${stem}ой');
  } else if (clean.endsWith('я')) {
    final stem = clean.substring(0, clean.length - 1);
    forms
      ..add('${stem}ю')
      ..add('${stem}ей');
  } else if (clean.endsWith('ий')) {
    final stem = clean.substring(0, clean.length - 2);
    forms
      ..add('${stem}ия')
      ..add('${stem}ию')
      ..add('${stem}им');
  } else {
    forms
      ..add('${clean}а')
      ..add('${clean}у')
      ..add('${clean}ом')
      ..add('${clean}ым');
  }
  return forms;
}

String taskVoicePhoneticKey(String value) {
  final source = normalizeTaskVoiceName(value).replaceAll(' ', '');
  final buffer = StringBuffer();
  String previous = '';
  for (final rune in source.runes) {
    final char = String.fromCharCode(rune);
    if ('аеёиоуыэюяйьъ'.contains(char)) continue;
    final mapped = switch (char) {
      'б' || 'п' => 'п',
      'в' || 'ф' => 'ф',
      'г' || 'к' || 'х' => 'к',
      'д' || 'т' => 'т',
      'ж' || 'ш' || 'щ' => 'ш',
      'з' || 'с' || 'ц' => 'с',
      _ => char,
    };
    if (mapped == previous) continue;
    buffer.write(mapped);
    previous = mapped;
  }
  return buffer.toString();
}

int taskVoiceEditDistance(String left, String right) {
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
      current[j + 1] = substitution < insertion
          ? (substitution < deletion ? substitution : deletion)
          : (insertion < deletion ? insertion : deletion);
    }
    previous = current;
  }
  return previous.last;
}

int taskVoiceCommonPrefix(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  var count = 0;
  while (count < length && left[count] == right[count]) count += 1;
  return count;
}

String normalizeTaskVoiceName(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-я]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
