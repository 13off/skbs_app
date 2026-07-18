import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer panel scrolls independently on desktop', () {
    final source = File(
      'lib/features/developer/presentation/developer_panel_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_buildSelector(scrollable: desktop)'));
    expect(source, contains('_buildEditor(scrollable: desktop)'));
    expect(source, contains('primary: false'));
    expect(source, contains('shrinkWrap: !scrollable'));
    expect(source, contains('AlwaysScrollableScrollPhysics'));
    expect(
      RegExp(r'NeverScrollableScrollPhysics').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
  });
}
