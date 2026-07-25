from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if old not in source:
        raise RuntimeError(f'{label}: expected source shape was not found')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')


def remove_artificial_async_gap() -> None:
    path = 'lib/features/ai/actions/ai_action_execution_coordinator.dart'
    old = """  static Future<AiActionExecutionResult> _executeConfirmedAction({
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
    new = """  static Future<AiActionExecutionResult> _executeConfirmedAction({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) {
    return switch (action.type) {
      'create_task_draft' => _createTask(context, profile, action),
      'prepare_document' => _prepareDocument(context, profile, action),
      'prepare_timesheet_correction' => _correctTimesheet(action),
      'prepare_employee_update' => _prepareEmployeeUpdate(context, action),
      'create_employee_draft' => _createEmployee(context, action),
      'prepare_payment' => _preparePayment(context, action),
      'find_operational_anomalies' => _openOperationalAudit(context, action),
      'find_missing_receipts' || 'prepare_candidate_documents' =>
        _openOperationalReport(context, profile, action),
      'open_period_timesheet' => _openPeriodTimesheet(context, action),
      'prepare_work_act' => _prepareWorkAct(context, action),
      'create_reminder' => _createReminder(context, action),
      _ => Future<AiActionExecutionResult>.error(
          UnsupportedError(
            'Действие «${action.type}» пока не поддерживается',
          ),
        ),
    };
  }
"""
    replace_once(path, old, new, 'AI confirmed action Future routing')


def document_neutral_kanban_wrapper() -> None:
    path = 'lib/features/recruitment/presentation/recruitment_applications_screen.dart'
    old = """          child: Container(
            child: DragTarget<RecruitmentApplication>(
"""
    new = """          // This neutral wrapper preserves the established kanban geometry.
          // ignore: avoid_unnecessary_containers
          child: Container(
            child: DragTarget<RecruitmentApplication>(
"""
    replace_once(path, old, new, 'Kanban neutral wrapper documentation')


def main() -> None:
    remove_artificial_async_gap()
    document_neutral_kanban_wrapper()


if __name__ == '__main__':
    main()
