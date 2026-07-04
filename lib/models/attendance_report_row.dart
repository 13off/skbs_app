class AttendanceReportRow {
  final String employeeId;
  final String employeeName;
  final String position;
  final int dailyRate;
  final double shifts;

  const AttendanceReportRow({
    required this.employeeId,
    required this.employeeName,
    required this.position,
    required this.dailyRate,
    required this.shifts,
  });

  double get amount {
    return shifts * dailyRate;
  }
}
