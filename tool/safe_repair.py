from __future__ import annotations

from pathlib import Path
import re


PROTECTED_CALLS: dict[str, list[int]] = {
    'lib/screens/employee_details/employee_details_copy.dart': [153, 173],
    'lib/screens/employee_details/employee_details_navigation.dart': [13],
    'lib/screens/employee_details/employee_details_status.dart': [
        30,
        41,
        86,
        97,
        102,
        111,
        140,
    ],
    'lib/screens/employees/employees_sections.dart': [83, 92],
    'lib/screens/home/home_actions.dart': [114],
    'lib/screens/home/home_loading.dart': [16, 121],
    'lib/screens/period_timesheet/period_timesheet_export.dart': [11, 45, 98],
    'lib/screens/period_timesheet/period_timesheet_loading.dart': [25, 39, 45],
    'lib/screens/period_timesheet/period_timesheet_period_picker.dart': [108],
    'lib/screens/period_timesheet/period_timesheet_view.dart': [72, 82],
    'lib/screens/task_create/task_create_actions.dart': [
        17,
        30,
        38,
        46,
        51,
        56,
        64,
        76,
    ],
    'lib/screens/task_create/task_create_loading.dart': [32, 38, 46, 57, 64, 69],
    'lib/screens/task_details/task_details_actions.dart': [
        16,
        29,
        47,
        63,
        75,
        77,
        121,
        129,
        138,
        140,
        160,
        173,
        254,
        283,
        285,
    ],
    'lib/screens/task_details/task_details_loading.dart': [38, 62, 83],
    'lib/screens/timesheet/timesheet_actions.dart': [33, 56, 87, 183, 197, 210, 213],
    'lib/screens/timesheet/timesheet_loading.dart': [25, 38, 43, 46],
    'lib/screens/timesheet/timesheet_sections.dart': [183, 205],
    'lib/screens/timesheet/timesheet_sync.dart': [26],
}


def replace_protected_set_state_calls() -> None:
    parents: dict[Path, set[str]] = {}

    for raw_path, line_numbers in PROTECTED_CALLS.items():
        path = Path(raw_path)
        text = path.read_text(encoding='utf-8')
        lines = text.splitlines(keepends=True)

        for line_number in line_numbers:
            index = line_number - 1
            if index >= len(lines) or 'setState(' not in lines[index]:
                raise RuntimeError(
                    f'Expected setState at {raw_path}:{line_number}; source changed'
                )
            lines[index] = lines[index].replace('setState(', '_updateState(', 1)

        updated = ''.join(lines)
        path.write_text(updated, encoding='utf-8')

        part_match = re.search(r"part of '([^']+)';", updated)
        state_match = re.search(
            r'extension\s+\w+\s+on\s+(_\w+State)\s*\{',
            updated,
        )
        if not part_match or not state_match:
            raise RuntimeError(f'Unable to resolve parent state for {raw_path}')

        parent_path = (path.parent / part_match.group(1)).resolve()
        parents.setdefault(parent_path, set()).add(state_match.group(1))

    root = Path.cwd().resolve()
    for parent_path, state_names in parents.items():
        if root not in parent_path.parents:
            raise RuntimeError(f'Parent path escaped repository: {parent_path}')

        text = parent_path.read_text(encoding='utf-8')
        for state_name in state_names:
            if re.search(r'void\s+_updateState\s*\(', text):
                continue

            pattern = re.compile(
                rf'(class\s+{re.escape(state_name)}\s+extends\s+State<[^>]+>'
                rf'(?:\s+with\s+[^{{]+)?\s*\{{)'
            )
            replacement = (
                r'\1\n'
                '  void _updateState(VoidCallback callback) => setState(callback);\n'
            )
            text, count = pattern.subn(replacement, text, count=1)
            if count != 1:
                raise RuntimeError(
                    f'Unable to insert state boundary into '
                    f'{parent_path}:{state_name}'
                )

        parent_path.write_text(text, encoding='utf-8')


def repair_ai_execution_context() -> None:
    path = Path('lib/features/ai/actions/ai_action_execution_coordinator.dart')
    source = path.read_text(encoding='utf-8')

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
    if old_switch not in source:
        raise RuntimeError('AI coordinator switch shape changed')
    source = source.replace(old_switch, new_switch, 1)

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
    marker = '  static Future<void> _loadCurrentTimesheetValue('
    if marker not in source:
        raise RuntimeError('AI coordinator helper marker changed')
    source = source.replace(marker, helper + marker, 1)
    path.write_text(source, encoding='utf-8')


def repair_ai_task_navigation_context() -> None:
    path = Path('lib/features/ai/presentation/ai_assistant_action_screen.dart')
    source = path.read_text(encoding='utf-8')
    marker = """        return;
      }

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
"""
    replacement = """        return;
      }
      if (!mounted) return;

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
"""
    if marker not in source:
        raise RuntimeError('AI task draft navigation marker changed')
    path.write_text(source.replace(marker, replacement, 1), encoding='utf-8')


def repair_document_template_contexts() -> None:
    path = Path('lib/screens/template_documents_screen.dart')
    source = path.read_text(encoding='utf-8')
    old_sheet = """                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
"""
    new_sheet = """                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
"""
    old_page = """                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
"""
    new_page = """                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
"""
    if old_sheet not in source or old_page not in source:
        raise RuntimeError('Document template async context shape changed')
    source = source.replace(old_sheet, new_sheet, 1)
    source = source.replace(old_page, new_page, 1)
    path.write_text(source, encoding='utf-8')


def main() -> None:
    replace_protected_set_state_calls()
    repair_ai_execution_context()
    repair_ai_task_navigation_context()
    repair_document_template_contexts()


if __name__ == '__main__':
    main()
