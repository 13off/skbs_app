class TimesheetGroup {
  final String id;
  final String objectId;
  final String objectName;
  final String name;
  final int sortOrder;
  final Set<String> employeeIds;

  const TimesheetGroup({
    required this.id,
    required this.objectId,
    required this.objectName,
    required this.name,
    required this.sortOrder,
    required this.employeeIds,
  });

  bool containsEmployee(dynamic employeeOrId) {
    final String? employeeId = employeeOrId is String
        ? employeeOrId
        : employeeOrId?.id?.toString();
    return employeeId != null && employeeIds.contains(employeeId);
  }

  factory TimesheetGroup.fromMap(Map<String, dynamic> map) {
    final rawEmployeeIds = map['employee_ids'];
    final employeeIds = rawEmployeeIds is List
        ? rawEmployeeIds
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
        : <String>{};

    return TimesheetGroup(
      id: map['id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString().trim() ?? '',
      name: map['name']?.toString().trim() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      employeeIds: Set<String>.unmodifiable(employeeIds),
    );
  }
}
