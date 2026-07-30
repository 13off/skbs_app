import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('кабинет сотрудника использует общую дизайн-систему AppСтрой', () {
    final main = File('lib/screens/main_screen.dart').readAsStringSync();
    final wrapper = File(
      'lib/features/employee/presentation/employee_platform_with_passport.dart',
    ).readAsStringSync();
    final work = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();

    expect(
      main,
      contains(
        "import '../features/employee/presentation/employee_platform_with_passport.dart';",
      ),
    );
    expect(main, contains('EmployeePlatformWithPassport(profile: profile)'));
    expect(wrapper, contains('PersistentTabShell('));
    expect(wrapper, contains("navigationStorageKey: 'employee-work-simple'"));
    expect(wrapper, contains('ProfessionalBottomNavigationItem('));
    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, isNot(contains("label: 'Табель'")));
    expect(wrapper, isNot(contains("label: 'Документы'")));
    expect(wrapper, isNot(contains("label: 'Команда'")));
    expect(work, contains('AppPage('));
    expect(work, contains('PremiumWorkCard('));
    expect(work, contains('PremiumActionButton('));
    expect(
      main,
      isNot(
        contains(
          "import '../features/employee/presentation/employee_main_screen.dart';",
        ),
      ),
    );
  });

  test('старый кабинет остаётся изолирован и не пишет данные напрямую', () {
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
    expect(employee, isNot(contains('.insert(')));
    expect(employee, isNot(contains('.update(')));
    expect(employee, isNot(contains('.delete(')));
  });

  test('обучение старого кабинета сохраняет точную цель нижнего меню', () {
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
