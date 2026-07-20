import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';

String source(String path) => File(path).readAsStringSync();

String assistantScreenSource() => <String>[
  'lib/features/ai/presentation/ai_assistant_screen.dart',
  'lib/features/ai/presentation/ai_assistant_action_screen.dart',
].map(source).join('\n');

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

  test('assistant screen remains a chat without quick requests', () {
    final screen = assistantScreenSource();

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
    final screen = assistantScreenSource();

    expect(screen, contains("'Предварительный результат'"));
    expect(screen, contains("'Отметить как проверенное'"));
    expect(screen, contains("'Проверено человеком'"));
    expect(
      screen,
      contains("'Помощник ничего не изменяет без твоего участия.'"),
    );
  });

  test('task proposal opens ordinary form and saves only after it returns', () {
    final screen = assistantScreenSource();
    final taskScreen = source('lib/screens/add_task_screen.dart');
    final taskActions = source(
      'lib/screens/task_create/task_create_actions.dart',
    );

    expect(screen, contains("action.type == 'create_task_draft'"));
    expect(screen, contains('AddTaskScreen('));
    expect(screen, contains('initialAxes:'));
    expect(screen, contains('initialWork:'));
    expect(screen, contains('initialAssigneeIds:'));
    expect(screen, contains('initialRequireBeforePhoto:'));
    expect(screen, contains('if (draft == null) return;'));
    expect(screen, contains('TaskRepository.addTaskWithDetails('));
    expect(screen.indexOf('if (draft == null) return;'),
        lessThan(screen.indexOf('TaskRepository.addTaskWithDetails(')));
    expect(screen, contains("'Задача создана'"));

    expect(taskScreen, contains('final String initialAxes;'));
    expect(taskScreen, contains('final String initialWork;'));
    expect(taskScreen, contains('final List<String> initialAssigneeIds;'));
    expect(taskScreen, contains('axesController.text = widget.initialAxes'));
    expect(taskScreen, contains('workController.text = widget.initialWork'));
    expect(taskScreen, contains('requiresBeforePhoto'));
    expect(taskActions, contains('required: requiresBeforePhoto'));
    expect(taskActions, contains('minimumCount: minimumBeforePhotos'));
    expect(taskActions, contains("'Сохранить задачу'"));
  });

  test('client routes task commands to authenticated action function', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );
    final model = source(
      'lib/features/ai/models/ai_assistant_result.dart',
    );

    expect(repository, contains('functions.invoke('));
    expect(repository, contains("'ai-action-draft'"));
    expect(repository, contains("'ai-assistant'"));
    expect(repository, contains("'ai-search'"));
    expect(repository, contains('functionNameFor('));
    expect(repository, contains("'company_id'"));
    expect(repository, contains("'object_name'"));
    expect(repository, isNot(contains('OPENAI_API_KEY')));

    expect(model, contains('class AiAssistantAction'));
    expect(model, contains('confirmationRequired'));
    expect(model, contains("map['confirmation_required'] != false"));
    expect(model, contains('Map<String, dynamic> payload'));
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

  test('existing assistant stays company scoped and read only', () {
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

  test('action proposal server validates access and remains read only', () {
    final edge = source('supabase/functions/ai-action-draft/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.from("user_profiles")'));
    expect(edge, contains('.from("company_memberships")'));
    expect(edge, contains('.eq("company_id", companyId)'));
    expect(edge, contains('confirmation_required: true'));
    expect(edge, contains('type: "create_task_draft"'));
    expect(edge, contains('Открыть черновик задачи'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });
}
