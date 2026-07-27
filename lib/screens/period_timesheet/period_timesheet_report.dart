import '../../models/employee.dart';
import '../../models/monthly_timesheet_row.dart';

class PeriodTimesheetSummary {
  final int employeeCount;
  final int activeEmployeeCount;
  final int firedEmployeeCount;
  final double accrued;
  final double paid;
  final double balance;

  const PeriodTimesheetSummary({
    required this.employeeCount,
    required this.activeEmployeeCount,
    required this.firedEmployeeCount,
    required this.accrued,
    required this.paid,
    required this.balance,
  });
}

class PeriodTimesheetReport {
  PeriodTimesheetReport._();

  static String normalizedEmployeeKey(Employee employee) {
    final cleanName = employee.name
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');

    if (cleanName.isNotEmpty) return cleanName;

    final cleanId = employee.id?.trim();
    if (cleanId != null && cleanId.isNotEmpty) return cleanId;

    return '${employee.position}_${employee.objectName}'.toLowerCase();
  }

  static List<MonthlyTimesheetRow> collapseDuplicateRows(
    List<MonthlyTimesheetRow> sourceRows, {
    required bool collapseAcrossObjects,
  }) {
    if (!collapseAcrossObjects) return List<MonthlyTimesheetRow>.from(sourceRows);

    final drafts = <String, _TimesheetDisplayDraft>{};

    for (final row in sourceRows) {
      final key = normalizedEmployeeKey(row.employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _TimesheetDisplayDraft(row.employee),
      );
      draft.add(row);
    }

    final result = drafts.values
        .map((draft) => draft.toRow())
        .where((row) => row.employee.name.trim().isNotEmpty)
        .toList();
    result.sort((a, b) => a.employee.name.compareTo(b.employee.name));
    return result;
  }

  static List<MonthlyTimesheetRow> filterRows(
    List<MonthlyTimesheetRow> rows, {
    required String query,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final workedRows = rows
        .where((row) => row.totalShifts > 0)
        .toList(growable: false);

    if (normalizedQuery.isEmpty) return workedRows;

    return workedRows.where((row) {
      final employee = row.employee;
      return employee.name.toLowerCase().contains(normalizedQuery) ||
          employee.position.toLowerCase().contains(normalizedQuery) ||
          employee.objectName.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  static PeriodTimesheetSummary summarize(
    Iterable<MonthlyTimesheetRow> rows,
  ) {
    var employeeCount = 0;
    var activeEmployeeCount = 0;
    var firedEmployeeCount = 0;
    var accrued = 0.0;
    var paid = 0.0;
    var balance = 0.0;

    for (final row in rows) {
      employeeCount++;
      accrued += row.accrued;
      paid += row.paid;
      balance += row.balance;
      if (row.employee.isActive) {
        activeEmployeeCount++;
      } else {
        firedEmployeeCount++;
      }
    }

    return PeriodTimesheetSummary(
      employeeCount: employeeCount,
      activeEmployeeCount: activeEmployeeCount,
      firedEmployeeCount: firedEmployeeCount,
      accrued: accrued,
      paid: paid,
      balance: balance,
    );
  }
}

class _TimesheetDisplayDraft {
  final Employee firstEmployee;
  final Map<int, double> shiftsByDay = <int, double>{};
  final Set<String> objectNames = <String>{};
  double paid = 0;
  bool hasActiveEmployee = false;

  _TimesheetDisplayDraft(this.firstEmployee);

  void add(MonthlyTimesheetRow row) {
    final employee = row.employee;
    final objectName = employee.objectName.trim();
    if (objectName.isNotEmpty) objectNames.add(objectName);
    if (employee.isActive) hasActiveEmployee = true;

    row.shiftsByDay.forEach((day, shifts) {
      shiftsByDay[day] = (shiftsByDay[day] ?? 0.0) + shifts;
    });
    paid += row.paid;
  }

  String get objectTitle {
    final objects = objectNames.toList()..sort();
    if (objects.isEmpty) return firstEmployee.objectName;
    if (objects.length == 1) return objects.first;
    return objects.join(', ');
  }

  MonthlyTimesheetRow toRow() {
    final employee = Employee(
      firstEmployee.name,
      firstEmployee.position,
      firstEmployee.status,
      id: firstEmployee.id,
      phone: firstEmployee.phone,
      objectName: objectTitle,
      dailyRate: firstEmployee.dailyRate,
      isActive: hasActiveEmployee,
      comment: firstEmployee.comment,
    );

    return MonthlyTimesheetRow(
      employee: employee,
      shiftsByDay: Map<int, double>.from(shiftsByDay),
      paid: paid,
    );
  }
}
