import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('secondary employee screens use adaptive desktop bodies', () {
    for (final path in <String>[
      'lib/screens/employee_documents_screen.dart',
      'lib/screens/employee_comments_screen.dart',
      'lib/screens/payment_history_screen.dart',
      'lib/screens/employee_timesheet_screen.dart',
    ]) {
      final value = source(path);
      expect(value, contains('AdaptiveDetailBody('), reason: path);
      expect(value, contains('leading: const BackButton()'), reason: path);
      expect(value, contains('AppAdaptivePalette'), reason: path);
      expect(value, isNot(contains('Colors.grey.shade100')), reason: path);
    }
  });

  test('adaptive detail body switches installed web to desktop at 820px', () {
    final value = source('lib/widgets/adaptive_detail_body.dart');
    expect(value, contains('kIsWeb && constraints.maxWidth >= 820'));
    expect(value, contains('desktopMaxWidth'));
    expect(value, contains('ConstrainedBox('));
  });

  test('individual timesheet and month picker stay dark', () {
    final timesheet = source('lib/screens/employee_timesheet_screen.dart');
    final picker = source(
      'lib/screens/period_timesheet/period_timesheet_period_picker.dart',
    );

    expect(timesheet, contains('AppAdaptivePalette.surfaceElevated'));
    expect(timesheet, contains('AppAdaptivePalette.surfaceSoft'));
    expect(timesheet, contains('Wrap('));
    expect(picker, contains('AppAdaptivePalette.accentStrong'));
    expect(picker, contains('AppAdaptivePalette.onAccent'));
    expect(picker, isNot(contains('color: Colors.white')));
  });

  test('task details use desktop columns and adaptive dark surfaces', () {
    final view = source('lib/screens/task_details/task_details_view.dart');
    final sections = source(
      'lib/screens/task_details/task_details_sections.dart',
    );
    final assignees = source(
      'lib/features/tasks/presentation/task_assignee_controls.dart',
    );
    final milestones = source(
      'lib/features/milestones/presentation/task_milestone_picker.dart',
    );

    expect(view, contains('AdaptiveDetailBody('));
    expect(view, contains('if (constraints.maxWidth < 980)'));
    expect(view, contains('Expanded(flex: 6, child: primary)'));
    expect(view, contains('Expanded(flex: 5, child: media)'));
    expect(view, contains('leading: const BackButton()'));
    expect(sections, contains('AppAdaptivePalette.surfaceSoft'));
    expect(assignees, contains('AppAdaptivePalette.surfaceElevated'));
    expect(milestones, contains('AppAdaptivePalette.surface'));
  });

  test('position filter contains normalized unique job titles', () {
    final value = source('lib/screens/desktop_employees_view.dart');

    expect(value, contains('String _positionLabel(String raw)'));
    expect(
      value,
      contains('.map((employee) => _positionLabel(employee.position))'),
    );
    expect(value, contains('.toSet()'));
    expect(value, contains('_positionLabel(employee.position) != positionFilter'));
    expect(
      value,
      contains('_TextCell(flex: 2, text: _positionLabel(employee.position))'),
    );
    expect(
      value,
      isNot(contains('.map((employee) => employee.position.trim())')),
    );
  });

  test('company and legal desktop pages expose back navigation', () {
    final specialist = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );
    final company = source(
      'lib/features/company/presentation/desktop_company_management_screen.dart',
    );
    final adaptiveLegal = source(
      'lib/features/legal/presentation/adaptive_legal_matters_screen.dart',
    );
    final legal = source(
      'lib/features/legal/presentation/legal_matters_screen.dart',
    );
    final manager = source(
      'lib/features/legal/presentation/legal_manager_summary_screen.dart',
    );

    expect(specialist, contains('specialistDesktopBreakpoint = 820'));
    expect(specialist, contains('final bool showBackButton'));
    expect(company, contains('showBackButton: true'));
    expect(adaptiveLegal, contains('showBackButton: Navigator.of(context).canPop()'));
    expect(legal, contains('showBackButton: Navigator.of(context).canPop()'));
    expect(manager, contains('AdaptiveLegalMattersScreen('));
  });

  test('secondary UI cleanup remains presentation-only', () {
    for (final path in <String>[
      'lib/widgets/adaptive_detail_body.dart',
      'lib/screens/employee_documents_screen.dart',
      'lib/screens/employee_comments_screen.dart',
      'lib/screens/payment_history_screen.dart',
      'lib/screens/employee_timesheet_screen.dart',
      'lib/screens/desktop_employees_view.dart',
      'lib/screens/task_details/task_details_view.dart',
    ]) {
      final value = source(path);
      expect(value, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
      expect(value, isNot(contains(".from('")), reason: path);
      expect(value, isNot(contains('.rpc(')), reason: path);
    }
  });
}
