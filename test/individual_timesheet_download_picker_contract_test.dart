import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('индивидуальный табель открывает выбор месяцев или дат', () {
    final timesheet = File(
      'lib/screens/employee_timesheet_screen.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/screens/employee_timesheet_download_screen.dart',
    ).readAsStringSync();

    expect(timesheet, contains("import 'employee_timesheet_download_screen.dart';"));
    expect(timesheet, contains('Future<void> downloadExcel() async'));
    expect(timesheet, contains('showModalBottomSheet<void>('));
    expect(timesheet, contains('showDialog<void>('));
    expect(timesheet, contains('EmployeeTimesheetDownloadScreen('));
    expect(timesheet, contains('onPressed: canDownload ? downloadExcel : null'));
    expect(timesheet, isNot(contains('TimesheetExcelExporter.downloadMonthlyTimesheets')));

    expect(picker, contains("label: Text('По месяцам')"));
    expect(picker, contains("label: Text('По датам')"));
    expect(picker, contains("'Выберите месяцы'"));
    expect(picker, contains("'Точный период по датам'"));
  });
}
