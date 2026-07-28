import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('рабочие экраны не возвращают старые неадаптивные нейтральные цвета', () {
    final roots = <Directory>[
      Directory('lib/screens'),
      Directory('lib/features'),
    ];
    const forbidden = <String>[
      'Colors.grey.shade100',
      'Colors.grey.shade200',
      'Colors.grey.shade700',
      'Color(0xFFF7F8FA)',
      'Color(0xFFF0F1F3)',
      'Color(0xFFF1F2F3)',
      'Color(0xFFF1F2F4)',
      'Color(0xFFF2F3F5)',
      'Color(0xFF1F2328)',
      'Color(0xFF34383D)',
      'Color(0xFF3D4146)',
      'Color(0xFF5F646A)',
      'Color(0xFF6B7075)',
      'Color(0xFF6F747A)',
      'Color(0xFF8A8F94)',
      'Color(0xFFD7D9DC)',
      'Color(0xFFE1E2DF)',
      'Color(0xFFE3E5E8)',
      'Color(0xFFE5E7EA)',
    ];
    final violations = <String>[];

    // Проверяем весь рабочий интерфейс, а не только экраны из присланных снимков.
    // Декоративные тени, фотооверлеи и белые иконки на цветных кнопках не запрещаем.
    for (final root in roots) {
      for (final file in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final token in forbidden) {
          if (source.contains(token)) {
            violations.add('${file.path}: $token');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('ключевые формы используют адаптивную палитру без изменения данных', () {
    final addEmployee = File(
      'lib/features/employees/presentation/screens/add_employee_screen.dart',
    ).readAsStringSync();
    final editEmployee = File(
      'lib/screens/edit_employee_screen.dart',
    ).readAsStringSync();
    final monthly = File(
      'lib/screens/monthly_timesheet_screen.dart',
    ).readAsStringSync();

    expect(addEmployee, contains('AppAdaptivePalette.surfaceElevated'));
    expect(addEmployee, contains('EmployeeRepository.addEmployee'));
    expect(editEmployee, contains('AppAdaptivePalette.surfaceElevated'));
    expect(editEmployee, contains('EmployeeRepository.updateEmployee'));
    expect(monthly, contains('AppAdaptivePalette.textPrimary'));
    expect(monthly, contains('AttendanceRepository.fetchMonthlyTimesheet'));
  });
}
