import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('карточка сотрудника открывает карту маршрута', () {
    final root = File('lib/screens/employee_details_screen.dart').readAsStringSync();
    final navigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();
    final view = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();

    expect(root, contains("employee_route_map_screen.dart"));
    expect(navigation, contains('Future<void> openRouteMap() async'));
    expect(navigation, contains('EmployeeRepository.fetchEmployees('));
    expect(navigation, contains('includeFired: true'));
    expect(navigation, contains('forceRefresh: true'));
    expect(navigation, contains('employee: routeEmployee'));
    expect(navigation, contains('EmployeeRouteMapScreen('));
    expect(view, contains("title: 'Маршруты смен'"));
    expect(view, contains('onTap: openRouteMap'));
  });
}
