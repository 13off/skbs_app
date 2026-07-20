import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';
import 'support/timesheet_source.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('archive bottom actions never hide archived items', () {
    final archive = source(
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
    );

    expect(archive, contains('buildTopPanel()'));
    expect(archive, contains('buildContent()'));
    expect(archive, contains('heightFactor: 1'));
    expect(archive, contains('height: 54'));
    expect(
      archive,
      isNot(contains('child: Center(\n            child: ConstrainedBox')),
    );
  });

  test('payment flow selects object before employee', () {
    final payment = source('lib/screens/add_payment_screen.dart');
    final objectField = payment.indexOf("labelText: 'Объект'");
    final employeeField = payment.indexOf("labelText: 'Сотрудник'");

    expect(objectField, greaterThan(-1));
    expect(employeeField, greaterThan(objectField));
    expect(payment, contains('employeesForSelectedObject()'));
    expect(payment, contains("errorText = 'Сначала выберите объект'"));
    expect(payment, contains('selectedEmployeeId = null'));
  });

  test('all work pages use the same plain header as home', () {
    final appPage = source('lib/widgets/app_page.dart');
    expect(appPage, contains('class AppPageHeader'));
    expect(appPage, contains('fontSize: 20'));
    expect(appPage, isNot(contains('APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ')));
    expect(appPage, isNot(contains('PremiumBrandMark(')));

    final home = homeSource();
    expect(home, contains("'Главная'"));
    expect(home, contains('MilestoneHomeSection('));
    expect(home, isNot(contains("subtitle: 'Рабочая сводка")));

    for (final path in <String>[
      'lib/screens/employees_screen.dart',
      'lib/screens/timesheet_screen.dart',
      'lib/screens/tasks_screen.dart',
      'lib/screens/profile_screen.dart',
    ]) {
      final screen = path == 'lib/screens/timesheet_screen.dart'
          ? timesheetSource()
          : source(path);
      expect(
        screen,
        anyOf(contains('AppPageHeader('), contains('return AppPage(')),
        reason: '$path должен использовать единую простую шапку',
      );
    }
  });

  test('timesheet date uses the same premium press motion as tasks', () {
    final timesheet = timesheetSource();
    expect(timesheet, contains('Widget buildDateArrow'));
    expect(timesheet, contains('PremiumPressable('));
    expect(timesheet, contains('borderRadius: BorderRadius.circular(20)'));
  });
}
