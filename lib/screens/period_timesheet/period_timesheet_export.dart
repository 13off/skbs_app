part of '../period_timesheet_screen.dart';

extension _PeriodTimesheetExport on _PeriodTimesheetScreenState {
  Future<void> exportExcel({
    required List<DateTime> months,
    required String fileNamePrefix,
    MonthlyTimesheetRow? employeeRow,
  }) async {
    if (isExporting) return;

    setState(() => isExporting = true);
    try {
      final rowsByMonth = <List<MonthlyTimesheetRow>>[];
      final employeeKey = employeeRow == null
          ? null
          : PeriodTimesheetReport.normalizedEmployeeKey(employeeRow.employee);

      for (final month in months) {
        var monthRows = await fetchRowsForMonth(month);
        if (employeeKey != null) {
          monthRows = monthRows.where((row) {
            return PeriodTimesheetReport.normalizedEmployeeKey(row.employee) ==
                employeeKey;
          }).toList(growable: false);
        }
        rowsByMonth.add(monthRows);
      }

      await TimesheetExcelExporter.downloadMonthlyTimesheets(
        months: months,
        rowsByMonth: rowsByMonth,
        fileNamePrefix: fileNamePrefix,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel-файл создан')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания Excel: $error')),
      );
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> downloadAllEmployeesExcel() async {
    final months = await pickMonthsForDownload(
      title: 'Скачать общий табель',
      subtitle: 'Выберите один или несколько месяцев',
    );
    if (!mounted || months == null || months.isEmpty) return;

    await exportExcel(
      months: months,
      fileNamePrefix: 'Табель_${fileObjectPart}_всех_сотрудников',
    );
  }

  Future<void> downloadEmployeeExcel(MonthlyTimesheetRow row) async {
    final months = await pickMonthsForDownload(
      title: 'Скачать табель сотрудника',
      subtitle: row.employee.name,
    );
    if (!mounted || months == null || months.isEmpty) return;

    await exportExcel(
      months: months,
      fileNamePrefix: 'Табель_${fileObjectPart}_${row.employee.name}',
      employeeRow: row,
    );
  }

  Future<void> openAddPaymentScreen() async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: monthTitle,
        ),
      ),
    );

    if (!mounted || saved != true) return;
    await loadReport();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выплата сохранена, отчёт обновлён')),
    );
  }

  Future<void> toggleIncludeFired(bool value) async {
    if (includeFiredEmployees == value) return;
    setState(() => includeFiredEmployees = value);
    await loadReport();
  }
}
