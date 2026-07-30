import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('маршруты открываются из отчётов, а не из карточки сотрудника', () {
    final reports = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final selector = File(
      'lib/features/reports/presentation/employee_routes_report_screen.dart',
    ).readAsStringSync();
    final map = File(
      'lib/features/employee/presentation/employee_route_map_screen.dart',
    ).readAsStringSync();
    final employeeView = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();

    expect(reports, contains("'Маршруты сотрудников'"));
    expect(reports, contains('EmployeeRoutesReportScreen('));
    expect(selector, contains("label: 'Показать маршрут'"));
    expect(selector, contains('EmployeeRouteMapScreen('));
    expect(map, contains("title: 'Маршрут сотрудника'"));
    expect(map, contains('PolylineLayer('));
    expect(map, isNot(contains('Настроить точку объекта')));
    expect(map, isNot(contains('Контрольная точка объекта')));
    expect(employeeView, isNot(contains("title: 'Маршруты смен'")));
    expect(employeeView, isNot(contains("title: 'Скачать табель'")));
    expect(employeeView, contains("title: 'Индивидуальный табель'"));
  });
}
