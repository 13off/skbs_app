part of '../employees_screen.dart';

extension _EmployeesFiltering on _EmployeesScreenState {
  List<Employee> visibleEmployees() {
    return directoryController.preparedEmployees(
      query: searchController.text,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: true,
      caseInsensitiveNameSort: false,
    );
  }
}
