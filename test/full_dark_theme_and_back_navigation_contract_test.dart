import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared AppPage supports explicit back navigation', () {
    final source = File('lib/widgets/app_page.dart').readAsStringSync();

    expect(source, contains('final bool showBackButton;'));
    expect(source, contains('final VoidCallback? onBack;'));
    expect(source, contains('if (showBackButton)'));
    expect(source, contains('BackButton('));
    expect(source, contains('Navigator.of(context).maybePop()'));
  });

  test('secondary AppPage screens request a visible back button', () {
    const targets = <String>[
      'lib/features/dispatcher/presentation/dispatcher_settings_screen.dart',
      'lib/features/dispatcher/presentation/dispatcher_summary_details_screen.dart',
      'lib/features/developer/presentation/developer_system_screen.dart',
      'lib/features/developer/presentation/developer_role_acceptance_screen.dart',
      'lib/features/developer/presentation/developer_readiness_screen.dart',
      'lib/features/developer/presentation/developer_demo_center_screen.dart',
      'lib/features/developer/presentation/developer_constructor_screen.dart',
      'lib/features/role_preview/role_preview_screen.dart',
      'lib/features/recruitment/presentation/recruitment_archive_screen.dart',
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
      'lib/features/recruitment/presentation/recruitment_onboarding_screen.dart',
      'lib/features/recruitment/presentation/recruitment_mobilization_screen.dart',
      'lib/features/ai/presentation/operational_audit_launcher_screen.dart',
      'lib/features/compliance/presentation/company_compliance_screen.dart',
    ];

    for (final path in targets) {
      final source = File(path).readAsStringSync();
      expect(source, contains('showBackButton: true'), reason: path);
    }
  });

  test('secondary Scaffold screens expose an explicit AppBar back button', () {
    const targets = <String>[
      'lib/screens/object_management_screen.dart',
      'lib/screens/employee_details/employee_details_view.dart',
      'lib/screens/employee_documents_screen.dart',
      'lib/screens/employee_private_data_screen.dart',
      'lib/screens/employee_comments_screen.dart',
      'lib/screens/employee_timesheet_screen.dart',
      'lib/screens/payment_history_screen.dart',
      'lib/screens/pwa_install_screen.dart',
      'lib/features/company/presentation/company_plans_screen.dart',
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
    ];

    for (final path in targets) {
      final source = File(path).readAsStringSync();
      expect(source, contains('appBar: AppBar('), reason: path);
      expect(source, contains('leading: const BackButton()'), reason: path);
    }
  });

  test('audited dark screens use adaptive palette instead of legacy light text', () {
    const targets = <String>[
      'lib/screens/desktop_timesheet_screen.dart',
      'lib/screens/object_management_screen.dart',
      'lib/screens/desktop_object_management_dialog.dart',
      'lib/screens/pwa_install_screen.dart',
      'lib/screens/employee_details/employee_details_sections.dart',
      'lib/features/company/presentation/company_plans_screen.dart',
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
      'lib/features/recruitment/presentation/recruitment_archive_screen.dart',
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
      'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
      'lib/widgets/notification_bell.dart',
      'lib/widgets/task_tile.dart',
    ];

    for (final path in targets) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AppAdaptivePalette'), reason: path);
      expect(
        source,
        isNot(contains('const Color _text = Color(0xFF1F2328)')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('const Color _muted = Color(0xFF6B7075)')),
        reason: path,
      );
    }
  });

  test('screens from visual report no longer contain known light surfaces', () {
    final objectDialog = File(
      'lib/screens/desktop_object_management_dialog.dart',
    ).readAsStringSync();
    final employeeDetails = File(
      'lib/screens/employee_details/employee_details_sections.dart',
    ).readAsStringSync();
    final pwa = File('lib/screens/pwa_install_screen.dart').readAsStringSync();
    final plans = File(
      'lib/features/company/presentation/company_plans_screen.dart',
    ).readAsStringSync();
    final archive = File(
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
    ).readAsStringSync();

    expect(objectDialog, contains('AppAdaptivePalette.surfaceElevated'));
    expect(employeeDetails, contains('AppAdaptivePalette.surface'));
    expect(employeeDetails, contains('AppAdaptivePalette.textPrimary'));
    expect(pwa, contains('AppAdaptivePalette.textPrimary'));
    expect(pwa, contains('AppAdaptivePalette.textMuted'));
    expect(plans, contains('AppAdaptivePalette.background'));
    expect(archive, contains('AppAdaptivePalette.background'));
  });

  test('presentation audit does not introduce direct database access', () {
    const targets = <String>[
      'lib/widgets/app_page.dart',
      'lib/screens/pwa_install_screen.dart',
      'lib/screens/object_management_screen.dart',
      'lib/screens/employee_details/employee_details_sections.dart',
      'lib/features/company/presentation/company_plans_screen.dart',
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
    ];

    for (final path in targets) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
      expect(source, isNot(contains('Supabase.instance.client')), reason: path);
      expect(source, isNot(contains(".from('")), reason: path);
      expect(source, isNot(contains('.rpc(')), reason: path);
    }
  });
}
