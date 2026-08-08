import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edge owns employee flight chat and archive workflow intents', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final workflow = File(
      'supabase/functions/ai-global-command/workflow_actions.ts',
    ).readAsStringSync();

    expect(index, contains('employeeWorkflowIntent'));
    expect(index, contains('flightWorkflowIntent'));
    expect(index, contains('chatMessageIntent'));
    expect(index, contains('archiveRestoreIntent'));
    expect(workflow, contains('employee_workday'));
    expect(workflow, contains('employee_task_action'));
    expect(workflow, contains('manage_flight'));
    expect(workflow, contains('send_company_chat_message'));
    expect(workflow, contains('restore_archive_item'));
  });

  test('employee commands resolve only the current linked employee', () {
    final workflow = File(
      'supabase/functions/ai-global-command/workflow_actions.ts',
    ).readAsStringSync();

    expect(workflow, contains('company_memberships'));
    expect(workflow, contains('person_id'));
    expect(workflow, contains('employee_account_links'));
    expect(workflow, contains('role !== "employee"'));
  });

  test('employee photos always go through the normal file picker', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_workflow_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('TaskRepository.pickPhotoFiles'));
    expect(coordinator, contains('EmployeeShiftActionRepository.uploadTaskPhotos'));
    expect(coordinator, contains('Сам файл голос не выбирает'));
  });

  test('workflow writes are confirmed and audited', () {
    final coordinator = File(
      'lib/features/ai/actions/global_voice_workflow_action_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, contains('AiActionAuditRepository.createProposed'));
    expect(coordinator, contains('markConfirmed'));
    expect(coordinator, contains('EmployeeShiftRuntime.instance'));
    expect(coordinator, contains('RecruitmentFlightRepository.sendReminder'));
    expect(coordinator, contains('CompanyChatRepository.createMessage'));
    expect(coordinator, contains('EmployeeArchiveRepository.restoreEmployee'));
  });

  test('permanent archive deletion is not exposed by workflow voice actions', () {
    final workflow = File(
      'supabase/functions/ai-global-command/workflow_actions.ts',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/ai/actions/global_voice_workflow_action_coordinator.dart',
    ).readAsStringSync();

    expect(workflow, isNot(contains('delete_forever')));
    expect(coordinator, isNot(contains('PermanentDeletionRepository')));
    expect(workflow, contains('Окончательное удаление голосом недоступно'));
  });
}
