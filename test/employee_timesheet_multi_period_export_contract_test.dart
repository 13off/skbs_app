import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('индивидуальный табель сам открывает выбор месяцев или дат', () {
    final detailsScreen = File(
      'lib/screens/employee_details_screen.dart',
    ).readAsStringSync();
    final detailsView = File(
      'lib/screens/employee_details/employee_details_view.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/screens/employee_details/employee_details_navigation.dart',
    ).readAsStringSync();
    final timesheetScreen = File(
      'lib/screens/employee_timesheet_screen.dart',
    ).readAsStringSync();
    final downloadSheet = File(
      'lib/screens/employee_timesheet_download_sheet.dart',
    ).readAsStringSync();

    expect(detailsView, contains("title: 'Индивидуальный табель'"));
    expect(detailsView, contains('onTap: openTimesheet'));
    expect(detailsView, isNot(contains("title: 'Скачать табель'")));
    expect(detailsScreen, isNot(contains('employee_timesheet_download_screen.dart')));
    expect(navigation, isNot(contains('openTimesheetDownload')));

    expect(
      timesheetScreen,
      contains("import 'employee_timesheet_download_sheet.dart';"),
    );
    expect(timesheetScreen, contains('EmployeeTimesheetDownloadSheet.show('));
    expect(timesheetScreen, contains('employee: widget.employee'));

    expect(downloadSheet, contains('SegmentedButton<'));
    expect(downloadSheet, contains("label: Text('Месяцы')"));
    expect(downloadSheet, contains("label: Text('Даты')"));
    expect(downloadSheet, contains('Set<DateTime> selectedMonths'));
    expect(downloadSheet, contains('showDateRangePicker('));
    expect(
      downloadSheet,
      contains('AttendanceRepository.fetchMonthlyTimesheetForEmployee('),
    );
    expect(
      downloadSheet,
      contains('TimesheetExcelExporter.downloadMonthlyTimesheets('),
    );
  });
}
