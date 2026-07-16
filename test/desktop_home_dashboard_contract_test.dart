import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('desktop home uses a wide web dashboard and preserves mobile home', () {
    final adaptive = source('lib/screens/adaptive_home_screen.dart');
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );

    expect(adaptive, contains('desktopBreakpoint = 1050'));
    expect(adaptive, contains('kIsWeb && constraints.maxWidth'));
    expect(adaptive, contains('return HomeScreen('));
    expect(adaptive, contains('BoxConstraints(maxWidth: 1240)'));
    expect(adaptive, contains('AppDataSync.changes.listen'));
    expect(adaptive, contains('EmployeeRepository.fetchEmployees'));
    expect(adaptive, contains('TaskRepository.fetchTasksForDate'));
    expect(adaptive, contains('FinanceSummaryRepository.fetchSummary'));

    expect(shell, contains("import '../../../screens/adaptive_home_screen.dart';"));
    expect(shell, contains('return AdaptiveHomeScreen('));
    expect(shell, isNot(contains("import '../../../screens/home_screen.dart';")));

    expect(navigation, contains('ProfessionalBottomNavigation'));
    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(navigation, isNot(contains('NavigationRail(')));
  });

  test('desktop controls open stable overlays and real work screens', () {
    final adaptive = source('lib/screens/adaptive_home_screen.dart');

    expect(adaptive, contains('OverlayEntry('));
    expect(adaptive, contains('CompositedTransformFollower('));
    expect(adaptive, contains('menuWidth'));
    expect(adaptive, isNot(contains('PopupMenuButton<String>')));

    expect(adaptive, contains('EmployeesScreen('));
    expect(adaptive, contains('TimesheetScreen('));
    expect(adaptive, contains('TasksScreen('));
    expect(adaptive, contains('PaymentsScreen('));
    expect(adaptive, contains('_ObjectManagementDialog('));
    expect(adaptive, contains('showFinancePeriodPicker'));
    expect(adaptive, isNot(contains('openClassicHome')));

    expect(adaptive, contains('required this.onTap'));
    expect(adaptive, contains('onOpenTasks: openTasks'));
    expect(adaptive, contains('onOpenPayments: openPayments'));
  });
}
