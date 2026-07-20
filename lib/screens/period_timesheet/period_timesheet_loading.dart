part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetLoading on _PeriodTimesheetScreenState {
  Future<List<MonthlyTimesheetRow>> fetchRowsForMonth(DateTime month) async {
    final sourceRows = isSameMonth(month, selectedMonth) && errorText == null
        ? rows
        : await AttendanceRepository.fetchMonthlyTimesheet(
            year: month.year,
            month: month.month,
            objectName: widget.selectedObjectName,
            includeFired: includeFiredEmployees,
          );

    return collapseDuplicateRows(sourceRows)
        .where((row) => row.totalShifts > 0)
        .toList(growable: false);
  }

  Future<void> loadReport() async {
    final requestId = ++loadRequestId;
    final month = selectedMonth;
    final selectedObjectName = widget.selectedObjectName;
    final includeFired = includeFiredEmployees;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await AttendanceRepository.fetchMonthlyTimesheet(
        year: month.year,
        month: month.month,
        objectName: selectedObjectName,
        includeFired: includeFired,
      );

      if (!mounted || requestId != loadRequestId) return;
      setState(() {
        rows = collapseDuplicateRows(result);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != loadRequestId) return;
      setState(() {
        errorText = 'Ошибка загрузки табеля: $error';
        isLoading = false;
      });
    }
  }
}
