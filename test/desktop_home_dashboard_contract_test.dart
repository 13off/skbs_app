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

  test('desktop controls use overlays and real bottom navigation tabs', () {
    final adaptive = source('lib/screens/adaptive_home_screen.dart');
    final widgets = source('lib/screens/desktop_home_widgets.dart');
    final manager = source(
      'lib/screens/desktop_object_management_dialog.dart',
    );
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(widgets, contains('OverlayEntry('));
    expect(widgets, contains('CompositedTransformFollower('));
    expect(widgets, contains('menuWidth'));
    expect(widgets, isNot(contains('PopupMenuButton<String>')));

    expect(adaptive, contains('required this.onOpenEmployees'));
    expect(adaptive, contains('required this.onOpenTimesheet'));
    expect(adaptive, contains('required this.onOpenTasks'));
    expect(adaptive, contains('required this.onOpenTask'));
    expect(adaptive, contains('required this.onOpenPayments'));
    expect(adaptive, contains('DesktopObjectManagementDialog('));
    expect(adaptive, contains('showFinancePeriodPicker'));

    expect(widgets, contains('onTap: () => onOpenTask(task)'));
    expect(widgets, isNot(contains("label: const Text('Открыть')")));

    expect(shell, contains('int get tasksTabIndex'));
    expect(shell, contains('Future<NavigatorState?> selectTabNavigator'));
    expect(shell, contains('Future<void> openPaymentsFromHome()'));
    expect(shell, contains('Future<void> openTaskFromHome(TaskItemData task)'));
    expect(shell, contains('TaskDetailsScreen(task: task'));
    expect(shell, contains('onOpenTask: openTaskFromHome'));
    expect(shell, contains('onOpenPayments: openPaymentsFromHome'));

    expect(manager, contains('ObjectRepository.renameObject'));
    expect(manager, contains('ObjectRepository.archiveObject'));
    expect(manager, contains('ObjectRepository.restoreObject'));
  });
}
