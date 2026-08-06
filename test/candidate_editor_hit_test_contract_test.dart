import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('candidate editor lift preserves the real hit-test area', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(source, contains('useRootNavigator: true'));
    expect(source, contains('final lift = keyboardInset > 0 ? 0.0 : 112.0;'));
    expect(source, contains('return Padding('));
    expect(source, contains('padding: EdgeInsets.only(bottom: lift)'));
    expect(source, isNot(contains('return Transform.translate(')));
  });
}
