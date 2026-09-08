import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('прораб и сотрудник не блокируются пока справочники загружаются', () {
    final selector = File(
      'lib/features/role_preview/role_preview_screen.dart',
    ).readAsStringSync();

    expect(selector, isNot(contains('ConnectionState.waiting')));
    expect(selector, contains('await objectNamesFuture'));
    expect(selector, contains('await employeesFuture'));
    expect(selector, contains("'Не удалось загрузить объекты: \$error'"));
    expect(selector, contains("'Не удалось загрузить сотрудников: \$error'"));
  });
}
