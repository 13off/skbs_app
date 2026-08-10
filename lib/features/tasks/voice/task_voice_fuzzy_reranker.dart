/// Осторожный дополнительный скоринг альтернатив Web Speech.
///
/// Он ничего не исправляет и не подменяет в распознанной фразе: только помогает
/// выбрать одну из уже предложенных браузером альтернатив. Короткие слова не
/// участвуют вообще, поэтому `им`, `их`, `бе`, `ве`, цифры и оси не получают
/// опасных fuzzy-совпадений.
double scoreTaskVoiceFuzzyHints(String transcript, List<String> hints) {
  if (hints.isEmpty) return 0;
  final words = _words(transcript).where((word) => word.length >= 5).toList();
  if (words.isEmpty) return 0;

  var score = 0.0;
  final seen = <String>{};
  for (final rawHint in hints) {
    final hintWords = _words(rawHint).where((word) => word.length >= 5).toList();
    if (hintWords.isEmpty) continue;

    if (hintWords.length == 1) {
      final hint = hintWords.single;
      if (!seen.add(hint)) continue;
      if (words.contains(hint)) continue; // exact scorer already handles this.
      if (_hasNearWord(words, hint)) score += 0.10;
      continue;
    }

    // Для длинной фразы даём бонус только когда все её значимые слова реально
    // присутствуют или очень близки. Это не позволяет одному похожему слову
    // перетянуть целую альтернативу.
    var matched = 0;
    for (final hint in hintWords) {
      if (words.contains(hint) || _hasNearWord(words, hint)) matched += 1;
    }
    if (matched == hintWords.length) score += 0.14;
  }

  return score > 0.30 ? 0.30 : score;
}

bool _hasNearWord(List<String> words, String hint) {
  final maxDistance = hint.length >= 8 ? 2 : 1;
  for (final word in words) {
    if ((word.length - hint.length).abs() > maxDistance) continue;
    if (_boundedEditDistance(word, hint, maxDistance) <= maxDistance) {
      return true;
    }
  }
  return false;
}

int _boundedEditDistance(String left, String right, int maxDistance) {
  if (left == right) return 0;
  if ((left.length - right.length).abs() > maxDistance) {
    return maxDistance + 1;
  }
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;

  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 1; i <= left.length; i += 1) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= right.length; j += 1) {
      final substitution = previous[j - 1] +
          (left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1);
      final insertion = current[j - 1] + 1;
      final deletion = previous[j] + 1;
      final value = substitution < insertion
          ? (substitution < deletion ? substitution : deletion)
          : (insertion < deletion ? insertion : deletion);
      current[j] = value;
      if (value < rowMin) rowMin = value;
    }
    if (rowMin > maxDistance) return maxDistance + 1;
    previous = current;
  }
  return previous[right.length];
}

List<String> _words(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .split(' ')
    .where((word) => word.isNotEmpty)
    .toList(growable: false);
