import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('индивидуальный табель использует ту же компактную панель выгрузки', () {
    final timesheet = File(
      'lib/screens/employee_timesheet_screen.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/screens/employee_timesheet_download_sheet.dart',
    ).readAsStringSync();

    expect(
      timesheet,
      contains("import 'employee_timesheet_download_sheet.dart';"),
    );
    expect(timesheet, contains('EmployeeTimesheetDownloadSheet.show('));
    expect(timesheet, contains('initialDate: initialDate'));
    expect(timesheet, contains('Set<DateTime> selectedMonths'));
    expect(timesheet, contains('showDateRangePicker('));
    expect(timesheet, isNot(contains('showDialog<void>(')));
    expect(timesheet, isNot(contains('EmployeeTimesheetDownloadScreen(')));
    expect(
      timesheet,
      contains('onPressed: canDownload ? downloadExcel : null'),
    );

    expect(picker, contains('showModalBottomSheet<void>('));
    expect(picker, contains('SafeArea('));
    expect(picker, contains('SingleChildScrollView('));
    expect(picker, contains('margin: const EdgeInsets.all(12)'));
    expect(picker, contains('borderRadius: BorderRadius.circular(28)'));
    expect(picker, contains("label: Text('Месяцы')"));
    expect(picker, contains("label: Text('Даты')"));
    expect(picker, contains("'Скачать табель'"));
    expect(picker, isNot(contains('Scaffold(')));
    expect(picker, isNot(contains('AppBar(')));
    expect(picker, isNot(contains("'Выбрать год'")));
    expect(picker, isNot(contains("'Очистить год'")));
  });
}
