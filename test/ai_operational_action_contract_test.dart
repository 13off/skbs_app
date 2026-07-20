import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('operational server prepares all supported typed actions', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    expect(edge, contains('return "create_reminder"'));
    expect(edge, contains('return "prepare_timesheet_correction"'));
    expect(edge, contains('return "prepare_employee_update"'));
    expect(edge, contains('type: actionKind'));
    expect(edge, contains('confirmation_required: true'));
    expect(edge, contains('current_daily_rate'));
    expect(edge, contains('daily_rate: dailyRate'));
    expect(edge, contains('recipient_roles: ["admin"]'));
  });

  test('operational server enforces company role and object scope', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.eq("company_id", companyId)'));
    expect(edge, contains('isForeman ? assignedObject : requestedObject'));
    expect(edge, contains('Изменение сотрудника доступно руководителю'));
    expect(
      edge,
      contains('Системные напоминания доступны руководителю или разработчику'),
    );
    expect(edge, contains('Укажи количество смен от 0 до 3'));
  });

  test('operational server is read only and uses user JWT', () {
    final edge = File(
      'supabase/functions/ai-operational-draft/index.ts',
    ).readAsStringSync();

    expect(edge, contains('Authorization: authorization'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });

  test('ordinary forms remain responsible for employee and reminder saves', () {
    final coordinator = File(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    ).readAsStringSync();
    final reminder = File(
      'lib/features/ai/presentation/ai_reminder_draft_screen.dart',
    ).readAsStringSync();

    expect(coordinator, contains('EditEmployeeScreen(employee: proposedEmployee)'));
    expect(coordinator, isNot(contains('EmployeeRepository.updateEmployee(')));
    expect(reminder, contains('DeveloperConstructorRepository.saveReminder('));
    expect(reminder, contains("'Сохранить напоминание'"));
  });
}
