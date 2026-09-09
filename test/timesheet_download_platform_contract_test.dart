import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('timesheet downloads use the cross-platform file saver', () {
    final exporter = source('lib/data/timesheet_excel_exporter.dart');
    expect(exporter, contains("import 'package:file_saver/file_saver.dart';"));
    expect(exporter, contains('FileSaver.instance.saveFile('));
    expect(exporter, contains("fileExtension: 'xlsx'"));
    expect(exporter, isNot(contains('universal_html')));

    for (final path in <String>[
      'lib/screens/employee_timesheet_download_sheet.dart',
      'lib/screens/employee_timesheet_download_screen.dart',
    ]) {
      final contents = source(path);
      expect(contents, contains('TimesheetExcelExporter.saveWorkbookBytes('));
      expect(contents, isNot(contains('universal_html')));
    }
  });
}
