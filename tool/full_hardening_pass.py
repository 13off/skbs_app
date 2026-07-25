from __future__ import annotations

from pathlib import Path


PART_STATE_FILES = [
    'lib/screens/employee_details/employee_details_copy.dart',
    'lib/screens/employee_details/employee_details_navigation.dart',
    'lib/screens/employee_details/employee_details_status.dart',
    'lib/screens/employees/employees_sections.dart',
    'lib/screens/home/home_actions.dart',
    'lib/screens/home/home_loading.dart',
    'lib/screens/period_timesheet/period_timesheet_export.dart',
    'lib/screens/period_timesheet/period_timesheet_loading.dart',
    'lib/screens/period_timesheet/period_timesheet_period_picker.dart',
    'lib/screens/period_timesheet/period_timesheet_view.dart',
    'lib/screens/task_create/task_create_actions.dart',
    'lib/screens/task_create/task_create_loading.dart',
    'lib/screens/task_details/task_details_actions.dart',
    'lib/screens/task_details/task_details_loading.dart',
    'lib/screens/timesheet/timesheet_actions.dart',
    'lib/screens/timesheet/timesheet_loading.dart',
    'lib/screens/timesheet/timesheet_sections.dart',
    'lib/screens/timesheet/timesheet_sync.dart',
]


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if old not in source:
        raise RuntimeError(f'{label}: expected source shape was not found')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')


def remove_once(path: str, block: str, label: str) -> None:
    replace_once(path, block, '', label)


def document_part_state_access() -> None:
    notice = (
        '// State helpers below are part of the owning screen library and '
        'intentionally\n'
        '// update that exact State instance.\n'
        '// ignore_for_file: invalid_use_of_protected_member\n\n'
    )
    for raw_path in PART_STATE_FILES:
        path = Path(raw_path)
        source = path.read_text(encoding='utf-8')
        if 'ignore_for_file: invalid_use_of_protected_member' in source:
            continue
        if not source.startswith('part of '):
            raise RuntimeError(f'Unexpected part-file header: {raw_path}')
        path.write_text(notice + source, encoding='utf-8')


def repair_async_contexts() -> None:
    coordinator = 'lib/features/ai/actions/ai_action_execution_coordinator.dart'
    old_switch = """      final result = switch (action.type) {
        'create_task_draft' => await _createTask(context, profile, action),
        'prepare_document' => await _prepareDocument(context, profile, action),
        'prepare_timesheet_correction' => await _correctTimesheet(action),
        'prepare_employee_update' =>
          await _prepareEmployeeUpdate(context, action),
        'create_employee_draft' => await _createEmployee(context, action),
        'prepare_payment' => await _preparePayment(context, action),
        'find_operational_anomalies' =>
          await _openOperationalAudit(context, action),
        'find_missing_receipts' || 'prepare_candidate_documents' =>
          await _openOperationalReport(context, profile, action),
        'open_period_timesheet' => await _openPeriodTimesheet(context, action),
        'prepare_work_act' => await _prepareWorkAct(context, action),
        'create_reminder' => await _createReminder(context, action),
        _ => throw UnsupportedError(
            'Действие «${action.type}» пока не поддерживается',
          ),
      };
"""
    new_switch = """      final result = await _executeConfirmedAction(
        context: context,
        profile: profile,
        action: action,
      );
"""
    replace_once(coordinator, old_switch, new_switch, 'AI coordinator switch')

    helper = """
  static Future<AiActionExecutionResult> _executeConfirmedAction({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    return switch (action.type) {
      'create_task_draft' => await _createTask(context, profile, action),
      'prepare_document' => await _prepareDocument(context, profile, action),
      'prepare_timesheet_correction' => await _correctTimesheet(action),
      'prepare_employee_update' => await _prepareEmployeeUpdate(context, action),
      'create_employee_draft' => await _createEmployee(context, action),
      'prepare_payment' => await _preparePayment(context, action),
      'find_operational_anomalies' => await _openOperationalAudit(context, action),
      'find_missing_receipts' || 'prepare_candidate_documents' =>
        await _openOperationalReport(context, profile, action),
      'open_period_timesheet' => await _openPeriodTimesheet(context, action),
      'prepare_work_act' => await _prepareWorkAct(context, action),
      'create_reminder' => await _createReminder(context, action),
      _ => throw UnsupportedError(
          'Действие «${action.type}» пока не поддерживается',
        ),
    };
  }

"""
    replace_once(
        coordinator,
        '  static Future<void> _loadCurrentTimesheetValue(',
        helper + '  static Future<void> _loadCurrentTimesheetValue(',
        'AI coordinator helper marker',
    )

    replace_once(
        'lib/features/ai/presentation/ai_assistant_action_screen.dart',
        """        showMessage('Для этой даты у текущей роли нет права создавать задачу');
        return;
      }

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
""",
        """        showMessage('Для этой даты у текущей роли нет права создавать задачу');
        return;
      }
      if (!mounted) return;

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
""",
        'AI task navigation mounted guard',
    )

    replace_once(
        'lib/screens/template_documents_screen.dart',
        """                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
""",
        """                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
""",
        'Template sheet context guard',
    )
    replace_once(
        'lib/screens/template_documents_screen.dart',
        """                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
""",
        """                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
""",
        'Template page context guard',
    )


def remove_confirmed_dead_code() -> None:
    remove_once(
        'lib/data/finance_summary_repository.dart',
        """  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

""",
        'Unused finance date key',
    )
    remove_once(
        'lib/features/recruitment/presentation/recruitment_dashboard_screen.dart',
        """Color get _success => AppAdaptivePalette.success;
Color get _warning => AppAdaptivePalette.warning;
Color get _danger => AppAdaptivePalette.danger;
""",
        'Unused recruitment dashboard colors',
    )
    remove_once(
        'lib/screens/employee_details/employee_details_sections.dart',
        """  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final cleanValue = value.trim();
    return Card(
      elevation: 0,
      color: AppAdaptivePalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon),
        title: Text(title),
        subtitle: cleanValue.isEmpty
            ? null
            : Text(
                cleanValue,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

""",
        'Unused employee info tile',
    )
    remove_once(
        'lib/screens/employees/employees_filtering.dart',
        """  String duplicateKey(Employee employee) =>
      EmployeeDirectoryLogic.duplicateKey(employee);

""",
        'Unused employee duplicate key wrapper',
    )


def migrate_reorder_callbacks() -> None:
    replace_once(
        'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
        """              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                if (newIndex == oldIndex) return;
""",
        """              onReorderItem: (oldIndex, newIndex) {
                if (newIndex == oldIndex) return;
""",
        'Kanban order dialog callback',
    )
    replace_once(
        'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
        '            onReorder: (oldIndex, newIndex) =>\n',
        '            onReorderItem: (oldIndex, newIndex) =>\n',
        'CRM settings reorder callback',
    )
    remove_once(
        'lib/features/recruitment/presentation/recruitment_crm_settings_screen.dart',
        '    if (newIndex > oldIndex) newIndex -= 1;\n',
        'Legacy reorder index correction',
    )


def remove_legacy_column_highlight() -> None:
    path = 'lib/features/recruitment/presentation/recruitment_applications_screen.dart'
    remove_once(path, '        const stageHighlighted = false;\n', 'Legacy stage highlight flag')
    replace_once(
        path,
        '          scale: stageHighlighted ? 1.018 : 1,\n',
        '          scale: 1,\n',
        'Legacy stage highlight scale',
    )
    remove_once(
        path,
        """            decoration: stageHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppUi.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppAdaptivePalette.accent.withValues(
                          alpha: 0.22,
                        ),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
""",
        'Legacy stage highlight decoration',
    )
    replace_once(
        path,
        """                      color: stageHighlighted
                          ? AppAdaptivePalette.accent.withValues(alpha: 0.09)
                          : highlighted
                          ? color.withValues(alpha: 0.12)
                          : AppAdaptivePalette.surfaceSoft.withValues(
                              alpha: 0.62,
                            ),
""",
        """                      color: highlighted
                          ? color.withValues(alpha: 0.12)
                          : AppAdaptivePalette.surfaceSoft.withValues(
                              alpha: 0.62,
                            ),
""",
        'Legacy stage highlight surface',
    )
    replace_once(
        path,
        """                        color: stageHighlighted
                            ? AppAdaptivePalette.accent.withValues(alpha: 0.70)
                            : highlighted
                            ? color.withValues(alpha: 0.62)
                            : AppAdaptivePalette.border,
                        width: stageHighlighted || highlighted ? 2 : 1,
""",
        """                        color: highlighted
                            ? color.withValues(alpha: 0.62)
                            : AppAdaptivePalette.border,
                        width: highlighted ? 2 : 1,
""",
        'Legacy stage highlight border',
    )
    replace_once(
        path,
        """                                highlighted
                                    ? 'Отпусти кандидата здесь'
                                    : stageHighlighted
                                    ? 'Отпусти колонку здесь'
                                    : 'Нет кандидатов',
""",
        """                                highlighted
                                    ? 'Отпусти кандидата здесь'
                                    : 'Нет кандидатов',
""",
        'Legacy stage highlight empty text',
    )
    replace_once(
        path,
        """                                  color: highlighted
                                      ? color
                                      : stageHighlighted
                                      ? AppAdaptivePalette.accent
                                      : _muted,
""",
        """                                  color: highlighted ? color : _muted,
""",
        'Legacy stage highlight empty color',
    )


def migrate_back_navigation() -> None:
    persistent = 'lib/features/shell/presentation/persistent_tab_shell.dart'
    replace_once(
        persistent,
        """class _PersistentTabShellState extends State<PersistentTabShell> {
  final Map<int, Widget> _tabNavigators = <int, Widget>{};
""",
        """class _PersistentTabShellState extends State<PersistentTabShell> {
  final Map<int, Widget> _tabNavigators = <int, Widget>{};
  bool _allowOuterPop = false;
""",
        'Persistent tab pop state',
    )
    replace_once(
        persistent,
        """    return WillPopScope(
      onWillPop: () => widget.controller.handleBack(
        returnToFirstTab: widget.returnToFirstTabOnBack,
      ),
      child: Scaffold(
""",
        """    return PopScope<void>(
      canPop: _allowOuterPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allowOuterPop = await widget.controller.handleBack(
          returnToFirstTab: widget.returnToFirstTabOnBack,
        );
        if (!mounted || !allowOuterPop) return;
        setState(() => _allowOuterPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      },
      child: Scaffold(
""",
        'Persistent tab PopScope migration',
    )

    premium = 'lib/features/shell/presentation/premium_main_screen.dart'
    replace_once(
        premium,
        """  Offset? topTapStart;

  int get pageCount""",
        """  Offset? topTapStart;
  bool _allowOuterPop = false;

  int get pageCount""",
        'Premium main pop state',
    )
    replace_once(
        premium,
        """    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: Scaffold(
""",
        """    return PopScope<void>(
      canPop: _allowOuterPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handledInsideApp = await handleBackRequest();
        if (!mounted || handledInsideApp) return;
        setState(() => _allowOuterPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      },
      child: Scaffold(
""",
        'Premium main PopScope migration',
    )


def migrate_web_edge_swipe() -> None:
    path = Path('lib/navigation/web_edge_swipe_platform_web.dart')
    source = """import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef EdgeSwipeBackCallback = void Function();

class WebEdgeSwipePlatform {
  static const int _minimumEventGapMs = 450;
  static const String _eventName = 'appstroy-swipe-back';

  static EdgeSwipeBackCallback? _onBack;
  static web.EventListener? _listener;
  static DateTime? _lastBackAt;

  static void initialize(EdgeSwipeBackCallback onBack) {
    _onBack = onBack;
    if (_listener != null) return;

    final listener = ((web.Event _) {
      final now = DateTime.now();
      final lastBackAt = _lastBackAt;

      if (lastBackAt != null &&
          now.difference(lastBackAt).inMilliseconds < _minimumEventGapMs) {
        return;
      }

      _lastBackAt = now;
      _onBack?.call();
    }).toJS;
    _listener = listener;
    web.window.addEventListener(_eventName, listener);
  }

  static void dispose() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener(_eventName, listener);
    }
    _listener = null;
    _onBack = null;
    _lastBackAt = null;
  }
}
"""
    path.write_text(source, encoding='utf-8')

    pubspec = Path('pubspec.yaml')
    text = pubspec.read_text(encoding='utf-8')
    if '  web: ^1.1.1\n' not in text:
        marker = '  url_launcher: ^6.3.2\n'
        if marker not in text:
            raise RuntimeError('pubspec dependency marker changed')
        text = text.replace(marker, marker + '  web: ^1.1.1\n', 1)
        pubspec.write_text(text, encoding='utf-8')


def preserve_pinned_cache_api() -> None:
    replacements = {
        'lib/features/payments/presentation/screens/payments_screen.dart':
            '                cacheExtent: 700,\n',
        'lib/screens/employees/employees_view.dart':
            '                cacheExtent: 700,\n',
        'lib/screens/timesheet/timesheet_view.dart':
            '                            cacheExtent: 700,\n',
        'lib/widgets/app_page.dart':
            '      cacheExtent: cacheExtent,\n',
    }
    for raw_path, line in replacements.items():
        replace_once(
            raw_path,
            line,
            (
                line.split('cacheExtent:', 1)[0]
                + '// Flutter 3.44 deprecates this field before exposing its '
                'replacement.\n'
                + line.split('cacheExtent:', 1)[0]
                + '// ignore: deprecated_member_use\n'
                + line
            ),
            f'Pinned cache API compatibility in {raw_path}',
        )


def main() -> None:
    document_part_state_access()
    repair_async_contexts()
    remove_confirmed_dead_code()
    migrate_reorder_callbacks()
    remove_legacy_column_highlight()
    migrate_back_navigation()
    migrate_web_edge_swipe()
    preserve_pinned_cache_api()


if __name__ == '__main__':
    main()
