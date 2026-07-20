import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('home opens AI chat from a fixed bottom-right button', () {
    final home = homeSource();
    final shell = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(home, contains('AiAssistantScreen('));
    expect(home, contains('FloatingActionButton('));
    expect(home, contains("heroTag: 'home-ai-assistant'"));
    expect(home, contains('Positioned('));
    expect(home, contains('right: 18'));
    expect(home, contains('bottom: 18'));
    expect(home, isNot(contains('buildAiAssistantCard')));
    expect(shell, isNot(contains("label: 'ИИ'")));
  });

  test('assistant screen contains only chat without quick requests', () {
    final screen = source(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    );

    expect(screen, contains("'Чем помочь?'"));
    expect(screen, contains('TextField('));
    expect(screen, contains('Expanded('));
    expect(screen, contains("mode: 'chat'"));
    expect(screen, isNot(contains("'Быстрые действия'")));
    expect(screen, isNot(contains("'Проверить табель'")));
    expect(screen, isNot(contains("'Сводка по объекту'")));
    expect(screen, isNot(contains("'Подготовить документ'")));
    expect(screen, isNot(contains('class _AiQuickAction')));
  });

  test('assistant keeps preliminary result and human review', () {
    final screen = source(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    );

    expect(screen, contains("'Предварительный результат'"));
    expect(screen, contains("'Отметить как проверенное'"));
    expect(screen, contains("'Проверено человеком'"));
  });

  test('client calls only the authenticated server function', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );

    expect(repository, contains('functions.invoke('));
    expect(repository, contains("'ai-assistant'"));
    expect(repository, contains("'company_id'"));
    expect(repository, contains("'object_name'"));
    expect(repository, isNot(contains('OPENAI_API_KEY')));
  });

  test('employee timesheet query understands a person and full period', () {
    final edge = source('supabase/functions/ai-assistant/index.ts');

    expect(edge, contains('findEmployeesInPrompt'));
    expect(edge, contains('employeeMatchScore'));
    expect(edge, contains('buildEmployeeTimesheetResult'));
    expect(edge, contains('mode: "employee_timesheet"'));
    expect(edge, contains('.eq("employee_id", employee.id)'));
    expect(edge, contains('.order("work_date", { ascending: true })'));
    expect(edge, contains('Покажи табель за весь период у Филимонова'));
    expect(edge, contains('Сумма смен:'));
  });

  test('edge function is company scoped read only and has no external key', () {
    final edge = source('supabase/functions/ai-assistant/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.eq("company_id", activeCompanyId)'));
    expect(edge, contains('role === "foreman"'));
    expect(edge, contains('assignedObjectName'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('OPENAI_API_KEY')));
    expect(edge, isNot(contains('api.openai.com')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });
}
