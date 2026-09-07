/// Monthly salary is a monthly fund, never a per-shift rate.
///
/// All timesheet-based accruals must go through this helper so legacy
/// `daily_rate` compatibility data can never be multiplied by shifts again.
const double monthlySalaryShiftNorm = 30.0;

double calculateMonthlySalaryAccrued({
  required num monthlySalary,
  required num countedShifts,
  bool ignoreTimesheet = false,
}) {
  final salary = monthlySalary.toDouble();
  if (salary <= 0) return 0.0;
  if (ignoreTimesheet) return salary;

  final shifts = countedShifts.toDouble();
  if (shifts <= 0) return 0.0;

  return salary / monthlySalaryShiftNorm * shifts;
}
