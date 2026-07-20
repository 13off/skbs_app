part of '../employees_screen.dart';

extension _EmployeesFiltering on _EmployeesScreenState {
  String duplicateKey(Employee employee) =>
      EmployeeDirectoryLogic.duplicateKey(employee);

  List<Employee> visibleEmployees() {
    return directoryController.preparedEmployees(
      query: searchController.text,
      sortSelectedObject: false,
      sortDuplicateGroupsByObject: true,
      caseInsensitiveNameSort: false,
    );
  }
}
