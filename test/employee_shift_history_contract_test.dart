import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('история задач выбирается по дате и свернута', () {
    final screen = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('showDatePicker('));
    expect(screen, contains("helpText: 'История задач за дату'"));
    expect(screen, contains('ExpansionTile('));
    expect(screen, contains('initiallyExpanded: false'));
    expect(screen, contains("label: const Text('Открыть карточку задачи')"));
  });
}
