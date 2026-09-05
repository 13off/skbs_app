import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('wide shell keeps the working navigation at the bottom', () {
    final shell = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );

    expect(
      shell,
      contains('bottomNavigationBar: ProfessionalBottomNavigation('),
    );
    expect(shell, isNot(contains('_DesktopTabRail')));
    expect(shell, isNot(contains('desktopRailWidth')));
  });

  test('candidate cards drag quickly and smoothly on every platform', () {
    final recruitment = source(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    );

    expect(recruitment, contains('bool get _usesImmediatePointerDrag'));
    expect(
      recruitment,
      contains('defaultTargetPlatform == TargetPlatform.windows'),
    );
    expect(
      recruitment,
      contains('defaultTargetPlatform == TargetPlatform.macOS'),
    );
    expect(
      recruitment,
      contains('defaultTargetPlatform == TargetPlatform.linux'),
    );
    expect(recruitment, contains('if (_usesImmediatePointerDrag)'));
    expect(recruitment, contains('return Draggable<RecruitmentApplication>('));
    expect(
      recruitment,
      contains('return LongPressDraggable<RecruitmentApplication>('),
    );
    expect(
      recruitment,
      contains('delay: const Duration(milliseconds: 160)'),
    );
    expect(
      recruitment,
      contains('duration: const Duration(milliseconds: 70)'),
    );
    expect(recruitment, contains('scale: highlighted ? 1.006 : 1'));
    expect(recruitment, contains('duration: const Duration(milliseconds: 90)'));
    expect(recruitment, contains('final feedbackCard = RepaintBoundary('));
    expect(recruitment, contains('elevation: 10'));
    expect(
      recruitment,
      contains("_usesImmediatePointerDrag ? 'Перетащи' : 'Удерживай'"),
    );
  });

  test('native Windows is not forced back to mobile adaptive screens', () {
    const adaptiveFiles = <String>[
      'lib/screens/adaptive_home_base_screen.dart',
      'lib/screens/adaptive_employees_screen.dart',
      'lib/screens/adaptive_tasks_screen.dart',
      'lib/screens/adaptive_timesheet_screen.dart',
      'lib/features/foreman/presentation/foreman_main_screen.dart',
      'lib/features/accounting/presentation/adaptive_accounting_dashboard_screen.dart',
      'lib/features/accounting/presentation/adaptive_accounting_payments_screen.dart',
      'lib/features/accounting/presentation/adaptive_accounting_reports_screen.dart',
    ];

    for (final path in adaptiveFiles) {
      expect(
        source(path),
        isNot(contains('kIsWeb')),
        reason: '$path must choose desktop UI by available width, not web-only',
      );
    }
  });

  test('manager task shortcut remains adaptive', () {
    final manager = source(
      'lib/features/reports/presentation/manager_main_screen.dart',
    );

    expect(manager, contains('AdaptiveTasksScreen('));
    expect(manager, isNot(contains('mobile.TasksScreen(')));
  });

  test('procurement has dedicated desktop workspaces', () {
    final main = source(
      'lib/features/procurement/presentation/procurement_main_screen.dart',
    );

    expect(main, contains('AdaptiveProcurementRequestsScreen'));
    expect(main, contains('AdaptiveProcurementSuppliersScreen'));
    expect(main, contains('AdaptiveProcurementDeliveriesScreen'));

    expect(
      File(
        'lib/features/procurement/presentation/adaptive_procurement_requests_screen.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'lib/features/procurement/presentation/adaptive_procurement_suppliers_screen.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'lib/features/procurement/presentation/adaptive_procurement_deliveries_screen.dart',
      ).existsSync(),
      isTrue,
    );
  });

  test('native Windows release pipeline and installer stay in repository', () {
    final workflow = source('.github/workflows/build-windows-desktop.yml');
    final installer = source('windows/installer/AppStroy.iss');

    expect(workflow, contains('flutter build windows --release'));
    expect(workflow, contains('Native startup smoke test'));
    expect(workflow, contains('AppStroy-Windows-Setup.exe'));
    expect(installer, contains('OutputBaseFilename=AppStroy-Windows-Setup'));
    expect(installer, contains('PrivilegesRequired=lowest'));
  });
}
