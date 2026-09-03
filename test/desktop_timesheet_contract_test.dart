import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/timesheet_source.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('timesheet switches to desktop table on every wide screen', () {
    final adaptive = source('lib/screens/adaptive_timesheet_screen.dart');
    final mobile = timesheetSource();
    final desktop = source('lib/screens/desktop_timesheet_screen.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(adaptive, contains('desktopBreakpoint = 1050'));
    expect(adaptive, isNot(contains('kIsWeb')));
    expect(adaptive, contains('constraints.maxWidth >= desktopBreakpoint'));
    expect(adaptive, contains('TimesheetScreen('));
    expect(adaptive, contains('DesktopTimesheetScreen('));
    expect(adaptive, contains('TimesheetDownloadSheet.show'));

    expect(mobile, contains('class TimesheetScreen extends StatefulWidget'));
    expect(mobile, contains('child: buildEmployeeRow(employee)'));

    expect(desktop, contains('class DesktopTimesheetScreen'));
    expect(
      desktop,
      matches(
        RegExp(r'BoxConstraints\(\s*maxWidth:\s*double\.infinity\s*,?\s*\)'),
      ),
    );
    expect(desktop, contains('class _TableHeader'));
    expect(desktop, contains('class _TimesheetRow'));
    expect(desktop, contains("'Сотрудник'"));
    expect(desktop, contains("'Объект'"));
    expect(desktop, contains("'Должность'"));
    expect(desktop, contains("'Смена'"));

    expect(
      shell,
      contains("import '../../../screens/adaptive_timesheet_screen.dart';"),
    );
    expect(shell, contains('return AdaptiveTimesheetScreen('));
    expect(
      shell,
      isNot(contains("import '../../../screens/timesheet_screen.dart';")),
    );
  });

  test(
    'desktop timesheet preserves input save realtime and direct download',
    () {
      final desktop = source('lib/screens/desktop_timesheet_screen.dart');
      final adaptive = source('lib/screens/adaptive_timesheet_screen.dart');
      final download = source('lib/screens/timesheet_download_sheet.dart');

      expect(desktop, contains('AppDataSync.changes.listen'));
      expect(desktop, contains('AttendanceRepository.fetchShiftValuesForDate'));
      expect(desktop, contains('AttendanceRepository.saveTimesheet'));
      expect(desktop, contains('originalShiftValuesByEmployeeId'));
      expect(desktop, contains('hasPendingRemoteAttendance'));
      expect(desktop, contains('hasUnsavedChanges'));
      expect(desktop, contains("'Всем 1'"));
      expect(desktop, contains("'Всем 0'"));
      expect(desktop, contains("'Все сотрудники'"));
      expect(desktop, contains("'Только вышедшие'"));
      expect(desktop, contains("'Не вышли'"));
      expect(desktop, contains('showShiftPicker(employee)'));
      expect(desktop, contains('setVisibleShifts(visible, 1)'));
      expect(desktop, contains('setVisibleShifts(visible, 0)'));
      expect(desktop, contains("'Сохранить изменения'"));
      expect(desktop, contains("'Сохранить табель'"));

      // The desktop save card keeps using the shared navigation geometry for
      // compact widths; the wide shell replaces that bottom navigation with
      // the permanent desktop rail.
      expect(desktop, contains('bottom: AppUi.navigationTotalHeight(context)'));
      expect(desktop, isNot(contains('bottom: 112')));

      expect(adaptive, contains("label: const Text('Скачать табель')"));
      expect(download, contains("label: Text('Месяцы')"));
      expect(download, contains("label: Text('Даты')"));
      expect(download, contains('downloadMonthlyTimesheets'));
    },
  );
}
