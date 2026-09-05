import 'employee.dart';

class EmployeeTimesheetPeriodRow {
  final Employee employee;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, double> shiftsByDate;
  final double paid;

  const EmployeeTimesheetPeriodRow({
    required this.employee,
    required this.startDate,
    required this.endDate,
    required this.shiftsByDate,
    required this.paid,
  });

  double shiftForDate(String dateKey) => shiftsByDate[dateKey] ?? 0.0;

  double get totalShifts =>
      shiftsByDate.values.fold<double>(0.0, (sum, value) => sum + value);

  double get accrued => employee.monthlySalary.toDouble();

  double get balance => accrued - paid;
}
