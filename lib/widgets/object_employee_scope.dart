const String allObjectsScopeValue = '__all_objects__';

bool isAllObjectsScope(String? value) => value == allObjectsScopeValue;

String? selectedObjectNameFromScope(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty || isAllObjectsScope(clean)) return null;
  return clean;
}

List<T> filterEmployeesByObject<T>({
  required List<T> employees,
  required String? selectedObject,
  required String Function(T employee) objectNameOf,
}) {
  final cleanScope = selectedObject?.trim();
  if (cleanScope == null || cleanScope.isEmpty) return <T>[];
  if (isAllObjectsScope(cleanScope)) return List<T>.from(employees);

  final normalizedScope = cleanScope.toLowerCase();
  return employees.where((employee) {
    return objectNameOf(employee).trim().toLowerCase() == normalizedScope;
  }).toList();
}
