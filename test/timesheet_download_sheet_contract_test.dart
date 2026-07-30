import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('скачивание табеля открывает выбор месяцев или дат на текущей странице', () {
    final adaptive = File(
      'lib/screens/adaptive_timesheet_screen.dart',
    ).readAsStringSync();
    final sheet = File(
      'lib/screens/timesheet_download_sheet.dart',
    ).readAsStringSync();

    expect(adaptive, contains('TimesheetDownloadSheet.show'));
    expect(adaptive, contains("label: const Text('Скачать табель')"));
    expect(sheet, contains("label: Text('Месяцы')"));
    expect(sheet, contains("label: Text('Даты')"));
    expect(sheet, contains('showDateRangePicker'));
    expect(sheet, contains('selectedMonths'));
    expect(sheet, contains('downloadMonthlyTimesheets'));
  });
}
