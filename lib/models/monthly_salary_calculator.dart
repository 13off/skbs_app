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
