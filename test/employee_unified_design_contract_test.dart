import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('кабинет сотрудника использует общую дизайн-систему AppСтрой', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final employee = File(
      'lib/features/employee/presentation/employee_unified_main_screen.dart',
    ).readAsStringSync();

    expect(
      main,
      contains(
        "import '../features/employee/presentation/employee_unified_main_screen.dart';",
      ),
    );
    expect(
      main,
      isNot(
        contains(
          "import '../features/employee/presentation/employee_main_screen.dart';",
        ),
      ),
    );

    expect(employee, contains('PersistentTabShell('));
    expect(employee, contains("navigationStorageKey: 'employee'"));
    expect(employee, contains('ProfessionalBottomNavigationItem('));
    expect(employee, contains('AppPage('));
    expect(employee, contains('PremiumWorkCard('));
    expect(employee, contains('PremiumActionButton('));

    for (final label in <String>[
      "label: 'Главная'",
      "label: 'Задачи'",
      "label: 'Табель'",
      "label: 'Документы'",
      "label: 'Профиль'",
    ]) {
      expect(employee, contains(label));
    }
  });

  test('унификация не меняет данные и рабочие процессы сотрудника', () {
    final employee = File(
      'lib/features/employee/presentation/employee_unified_main_screen.dart',
    ).readAsStringSync();

    expect(employee, contains('EmployeeCabinetRepository.fetch('));
    expect(employee, contains('EmployeeCabinetData.preview('));
    expect(employee, contains('data.attendanceForDay(day)'));
    expect(employee, contains('data.paymentsForMonth'));
    expect(employee, contains('UserRepository.signOut()'));
    expect(employee, contains('RolePreviewController.showAdmin()'));
    expect(employee, contains('changeMonth(-1)'));
    expect(employee, contains('changeMonth(1)'));

    expect(employee, isNot(contains("functions.invoke('")));
    expect(employee, isNot(contains(".insert('")));
    expect(employee, isNot(contains(".update('")));
    expect(employee, isNot(contains(".delete('")));
  });

  test('обучение сотрудника сохраняет точную цель нижнего меню', () {
    final employee = File(
      'lib/features/employee/presentation/employee_unified_main_screen.dart',
    ).readAsStringSync();

    expect(employee, contains('onboardingNavigationMarker'));
    expect(employee, contains('IgnorePointer('));
    expect(employee, contains('ExcludeSemantics('));
    expect(employee, contains('opacity: 0'));
    expect(employee, contains('NavigationBar('));
  });
}
