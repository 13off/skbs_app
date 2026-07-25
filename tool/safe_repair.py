from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if old not in source:
        raise RuntimeError(f'{label}: expected source shape was not found')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')


def repair_ai_execution_context() -> None:
    path = 'lib/features/ai/actions/ai_action_execution_coordinator.dart'
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
    replace_once(path, old_switch, new_switch, 'AI coordinator switch')

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
        path,
        '  static Future<void> _loadCurrentTimesheetValue(',
        helper + '  static Future<void> _loadCurrentTimesheetValue(',
        'AI coordinator helper marker',
    )


def repair_ai_task_navigation_context() -> None:
    replace_once(
        'lib/features/ai/presentation/ai_assistant_action_screen.dart',
        """        return;
      }

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
""",
        """        return;
      }
      if (!mounted) return;

      final draft = await Navigator.of(context).push<TaskCreateDraft>(
""",
        'AI task navigation context',
    )


def repair_document_template_contexts() -> None:
    path = 'lib/screens/template_documents_screen.dart'
    replace_once(
        path,
        """                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
""",
        """                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
""",
        'Document sheet context',
    )
    replace_once(
        path,
        """                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
""",
        """                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
""",
        'Document page context',
    )


def main() -> None:
    repair_ai_execution_context()
    repair_ai_task_navigation_context()
    repair_document_template_contexts()


if __name__ == '__main__':
    main()
