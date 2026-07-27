import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('browser history always receives a non-null document title', () {
    final repository = File(
      'lib/features/auth/data/user_repository.dart',
    ).readAsStringSync();

    expect(repository, contains('static String get _browserDocumentTitle'));
    expect(repository, contains("html.document.title?.trim() ?? ''"));
    expect(repository, contains("return title.isEmpty ? 'AppСтрой' : title;"));
    expect(
      RegExp(r'replaceState\(\s*null,\s*_browserDocumentTitle,').allMatches(
        repository,
      ).length,
      2,
    );
    expect(
      repository,
      isNot(contains('null,\n      html.document.title,\n')),
    );
  });
}
