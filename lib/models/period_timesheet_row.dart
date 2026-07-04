import 'employee.dart';

class PeriodTimesheetRow {
  final Employee employee;
  final Map<String, double> shiftsByDate;

  const PeriodTimesheetRow({
    required this.employee,
    required this.shiftsByDate,
  });

  double shiftForDate(String dateKey) {
    return shiftsByDate[dateKey] ?? 0.0;
  }

  double get totalShifts {
    return shiftsByDate.values.fold<double>(0.0, (sum, value) => sum + value);
  }

  double get accrued {
    return totalShifts * employee.dailyRate;
  }
}
