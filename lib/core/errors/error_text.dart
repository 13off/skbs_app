abstract final class ErrorText {
  static String from(Object error, {String prefix = 'Ошибка'}) {
    final clean = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();

    if (clean.isEmpty) return prefix;

    return '$prefix: $clean';
  }
}
