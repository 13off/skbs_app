class TaskVoiceAxisNormalization {
  final String normalized;
  final int numbers;
  final int letters;
  final int ignored;

  const TaskVoiceAxisNormalization({
    required this.normalized,
    required this.numbers,
    required this.letters,
    required this.ignored,
  });
}

TaskVoiceAxisNormalization normalizeTaskVoiceAxes(String source) {
  final clean = source
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(
        RegExp(r'(^|\s)(?:ось|оси|по\s+осям)(?=\s|$)', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'[^а-яa-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.isEmpty) {
    return const TaskVoiceAxisNormalization(
      normalized: '',
      numbers: 0,
      letters: 0,
      ignored: 0,
    );
  }

  final output = <String>[];
  var numberCount = 0;
  var letterCount = 0;
  var ignored = 0;

  for (final rawToken in clean.split(' ')) {
    if (_axisConnectors.contains(rawToken) || _axisFillers.contains(rawToken)) {
      continue;
    }

    final glued = _splitKnownAxisLetters(rawToken);
    if (glued.isNotEmpty) {
      output.addAll(glued);
      letterCount += glued.length;
      continue;
    }

    final letter = _axisLetterAliases[rawToken];
    if (letter != null) {
      output.add(letter);
      letterCount += 1;
      continue;
    }

    if (_isAxisNumber(rawToken)) {
      // В контексте осей после двух числовых координат короткая «Б» часто
      // приходит из Web Speech как цифра 6. Третье число формат осей не ждёт,
      // поэтому здесь безопаснее трактовать такой 6 как «Б».
      if (rawToken == '6' && numberCount >= 2 && letterCount == 0) {
        output.add('бэ');
        letterCount += 1;
      } else {
        output.add(rawToken);
        numberCount += 1;
      }
      continue;
    }

    // В активном поле «Оси» допускаем до двух посторонних слов/обрывков.
    // Это закрывает шум, «эээ» и случайные вставки распознавателя.
    if (ignored < 2) {
      ignored += 1;
      continue;
    }
    break;
  }

  return TaskVoiceAxisNormalization(
    normalized: output.join(' '),
    numbers: numberCount,
    letters: letterCount,
    ignored: ignored,
  );
}

String normalizeTaskVoiceAxesValue(String source) =>
    normalizeTaskVoiceAxes(source).normalized;

double scoreTaskVoiceAxesCandidate(String source) {
  final parsed = normalizeTaskVoiceAxes(source);
  if (parsed.normalized.isEmpty) return 0;

  var score = 0.0;
  if (parsed.numbers >= 2) {
    score += 0.55;
  } else if (parsed.numbers == 1) {
    score += 0.15;
  }
  if (parsed.letters >= 2) {
    score += 0.65;
  } else if (parsed.letters == 1) {
    score += 0.28;
  }
  if (parsed.numbers >= 2 && parsed.letters >= 2) score += 0.35;
  if (_axisMarker.hasMatch(source)) score += 0.12;
  score -= parsed.ignored * 0.04;
  return score < 0 ? 0 : score;
}

final RegExp _axisMarker = RegExp(
  r'(^|[^а-яё])(?:ось|оси|по\s+осям)(?=$|[^а-яё])',
  caseSensitive: false,
);

const _axisConnectors = <String>{
  'с',
  'по',
  'до',
  'от',
  'между',
  'и',
  'тире',
  'дефис',
};

const _axisFillers = <String>{
  'ээ',
  'эээ',
  'мм',
  'ну',
  'так',
  'короче',
  'значит',
  'вот',
};

bool _isAxisNumber(String token) {
  final direct = int.tryParse(token);
  if (direct != null && direct >= 0 && direct <= 999) return true;
  return _axisNumberWords.contains(token);
}

List<String> _splitKnownAxisLetters(String token) {
  final known = _knownGluedAxisErrors[token];
  if (known != null) return known;

  // Слепленные браузером «бэгэ», «беге», «вэдэ» и т.п. разбираем как
  // две произнесённые буквы. Однобуквенные алиасы сюда не допускаем, чтобы
  // не начать резать обычные русские слова.
  for (var split = 2; split <= token.length - 2; split += 1) {
    final left = token.substring(0, split);
    final right = token.substring(split);
    final first = _longAxisLetterAliases[left];
    final second = _longAxisLetterAliases[right];
    if (first != null && second != null) {
      return <String>[first, second];
    }
  }
  return const <String>[];
}

const _knownGluedAxisErrors = <String, List<String>>{
  'беги': <String>['бэ', 'гэ'],
  'бэги': <String>['бэ', 'гэ'],
  'веги': <String>['вэ', 'гэ'],
  'вэги': <String>['вэ', 'гэ'],
  'беде': <String>['бэ', 'дэ'],
};

const _longAxisLetterAliases = <String, String>{
  'бэ': 'бэ',
  'бе': 'бэ',
  'би': 'бэ',
  'вэ': 'вэ',
  'ве': 'вэ',
  'гэ': 'гэ',
  'ге': 'гэ',
  'дэ': 'дэ',
  'де': 'дэ',
  'жэ': 'жэ',
  'же': 'жэ',
  'ка': 'ка',
  'эль': 'эль',
  'эл': 'эль',
  'эм': 'эм',
  'эн': 'эн',
  'пэ': 'пэ',
  'пе': 'пэ',
  'эр': 'эр',
  'эс': 'эс',
  'тэ': 'тэ',
  'те': 'тэ',
};

const _axisLetterAliases = <String, String>{
  'а': 'а',
  'эй': 'а',
  'б': 'бэ',
  'бэ': 'бэ',
  'бе': 'бэ',
  'би': 'бэ',
  'бэй': 'бэ',
  'в': 'вэ',
  'вэ': 'вэ',
  'ве': 'вэ',
  'ви': 'вэ',
  'г': 'гэ',
  'гэ': 'гэ',
  'ге': 'гэ',
  'ги': 'гэ',
  'д': 'дэ',
  'дэ': 'дэ',
  'де': 'дэ',
  'ди': 'дэ',
  'е': 'е',
  'ж': 'жэ',
  'жэ': 'жэ',
  'же': 'жэ',
  'и': 'и',
  'й': 'й',
  'к': 'ка',
  'ка': 'ка',
  'л': 'эль',
  'эль': 'эль',
  'эл': 'эль',
  'м': 'эм',
  'эм': 'эм',
  'н': 'эн',
  'эн': 'эн',
  'п': 'пэ',
  'пэ': 'пэ',
  'пе': 'пэ',
  'р': 'эр',
  'эр': 'эр',
  'с': 'эс',
  'эс': 'эс',
  'т': 'тэ',
  'тэ': 'тэ',
  'те': 'тэ',
};

const _axisNumberWords = <String>{
  'ноль',
  'один',
  'одна',
  'первый',
  'первая',
  'первой',
  'первую',
  'два',
  'две',
  'второй',
  'вторая',
  'вторую',
  'три',
  'третий',
  'третья',
  'третью',
  'четыре',
  'четвертый',
  'четвертая',
  'четвертую',
  'пять',
  'пятый',
  'пятая',
  'пятую',
  'шесть',
  'шестой',
  'шестая',
  'шестую',
  'семь',
  'седьмой',
  'седьмая',
  'седьмую',
  'восемь',
  'восьмой',
  'восьмая',
  'восьмую',
  'девять',
  'девятый',
  'девятая',
  'девятую',
  'десять',
  'десятый',
  'десятая',
  'десятую',
  'одиннадцать',
  'двенадцать',
  'тринадцать',
  'четырнадцать',
  'пятнадцать',
  'шестнадцать',
  'семнадцать',
  'восемнадцать',
  'девятнадцать',
  'двадцать',
};
