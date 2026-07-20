part of '../employees_screen.dart';

extension _EmployeesFiltering on _EmployeesScreenState {
  String duplicateKey(Employee employee) {
    final name = employee.name.trim().toLowerCase();
    final phone = employee.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return phone.isNotEmpty
        ? '$name::$phone'
        : '$name::${employee.position.trim().toLowerCase()}';
  }

  List<Employee> visibleEmployees() {
    final query = searchController.text.trim().toLowerCase();
    var source = query.isEmpty
        ? List<Employee>.from(employees)
        : employees.where((employee) {
            return employee.name.toLowerCase().contains(query) ||
                employee.position.toLowerCase().contains(query) ||
                employee.phone.toLowerCase().contains(query) ||
                employee.objectName.toLowerCase().contains(query);
          }).toList();

    if (objectName != null) return source;

    final groups = <String, List<Employee>>{};
    for (final employee in source) {
      groups.putIfAbsent(duplicateKey(employee), () => <Employee>[]).add(employee);
    }

    source = groups.values.map((group) {
      group.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.objectName.compareTo(b.objectName);
      });
      final main = group.first;
      final objects = group
          .map((employee) => employee.objectName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return Employee(
        main.name,
        main.position,
        main.status,
        id: main.id,
        phone: main.phone,
        objectName: objects.isEmpty ? main.objectName : objects.join(', '),
        dailyRate: main.dailyRate,
        isActive: group.any((employee) => employee.isActive),
        comment: main.comment,
      );
    }).toList();

    source.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return source;
  }
}
