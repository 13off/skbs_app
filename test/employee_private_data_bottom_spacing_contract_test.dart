// Runtime branding is intentionally kept on the original logo and animation.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal data save action scrolls above floating navigation', () {
    final source = File(
      'lib/screens/employee_private_data_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import '../app/app_ui_tokens.dart';"));
    expect(
      source,
      contains('AppUi.navigationTotalHeight(context) + 24'),
    );
    expect(
      source,
      contains('EdgeInsets.fromLTRB(18, 18, 18, bottomSpacing)'),
    );
    expect(source, contains("'Сохранить личные данные'"));
    expect(source, contains('height: 54'));
    expect(source, isNot(contains('padding: const EdgeInsets.all(18)')));
  });
}
