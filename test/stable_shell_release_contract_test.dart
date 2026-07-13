import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published shell uses the last known-good visible structure', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();

    expect(source, contains("show CupertinoPageRoute"));
    expect(source, contains('PageView.builder'));
    expect(source, contains('return CupertinoPageRoute<void>('));
    expect(source, contains('return buildRootPage(index, selectedObjectName);'));
    expect(source, isNot(contains('final isDesktop = screenWidth >= 760')));
  });
}
