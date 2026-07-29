import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('employee card exports timesheet by months or exact dates', () {
    final detailsScreen = File(
      'lib/screens/employee_details_screen.dart',
    ).readAsStringSync();
    final detailsView = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();
    final downloadScreen = File(
      'lib/screens/employee_timesheet_download_screen.dart',
    ).readAsStringSync();

    expect(
      detailsScreen,
      contains("import 'employee_timesheet_download_screen.dart';"),
    );
    expect(detailsView, contains("title: 'Индивидуальный табель'"));
    expect(detailsView, contains("title: 'Скачать табель'"));
    expect(
      detailsView,
      contains("subtitle: 'Несколько месяцев или точный период по датам'"),
    );
    expect(detailsView, contains('onTap: openTimesheetDownload'));
    expect(navigation, contains('Future<void> openTimesheetDownload()'));
    expect(
      navigation,
      contains('EmployeeTimesheetDownloadScreen(employee: employee)'),
    );

    expect(downloadScreen, contains('SegmentedButton<'));
    expect(downloadScreen, contains("label: Text('По месяцам')"));
    expect(downloadScreen, contains("label: Text('По датам')"));
    expect(downloadScreen, contains('Set<DateTime> selectedMonths'));
    expect(downloadScreen, contains('selectVisibleYear'));
    expect(downloadScreen, contains('clearVisibleYear'));
    expect(downloadScreen, contains('showDateRangePicker('));
    expect(downloadScreen, contains('initialDateRange: selectedRange'));
    expect(downloadScreen, contains('while (!date.isAfter(selectedRange.end))'));

    expect(
      downloadScreen,
      contains('AttendanceRepository.fetchMonthlyTimesheetForEmployee('),
    );
    expect(
      downloadScreen,
      contains('TimesheetExcelExporter.downloadMonthlyTimesheets('),
    );
    expect(downloadScreen, contains('Excel.createExcel()'));
    expect(downloadScreen, contains("TextCellValue('Дата')"));
    expect(downloadScreen, contains("TextCellValue('Смены')"));
    expect(downloadScreen, contains("TextCellValue('Ставка за смену')"));
    expect(downloadScreen, contains("TextCellValue('Начислено')"));
    expect(downloadScreen, contains("TextCellValue('ИТОГО')"));
    expect(downloadScreen, contains("final fileName = '\$baseName.xlsx';"));
  });
}
