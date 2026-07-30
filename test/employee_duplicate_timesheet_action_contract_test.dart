import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('в карточке сотрудника остаётся только индивидуальный табель', () {
    final view = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();

    expect(view, contains("title: 'Индивидуальный табель'"));
    expect(view, isNot(contains("title: 'Скачать табель'")));
    expect(view, isNot(contains('openTimesheetDownload')));
  });
}
