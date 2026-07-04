import 'employee.dart';

class MonthlyTimesheetRow {
  final Employee employee;
  final Map<int, double> shiftsByDay;
  final double paid;

  const MonthlyTimesheetRow({
    required this.employee,
    required this.shiftsByDay,
    required this.paid,
  });

  double shiftForDay(int day) {
    return shiftsByDay[day] ?? 0.0;
  }

  double get totalShifts {
    return shiftsByDay.values.fold<double>(0.0, (sum, value) => sum + value);
  }

  double get accrued {
    return totalShifts * employee.dailyRate;
  }

  double get balance {
    return accrued - paid;
  }
}
