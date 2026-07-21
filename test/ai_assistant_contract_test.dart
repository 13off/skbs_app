import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/ai_operational_source.dart';
import 'support/home_source.dart';

String source(String path) => File(path).readAsStringSync();

String assistantScreenSource() => <String>[
  'lib/features/ai/presentation/ai_assistant_screen.dart',
  'lib/features/ai/presentation/ai_assistant_confirmed_screen.dart',
].map(source).join('\n');

String actionExecutionSource() => <String>[
  'lib/features/ai/actions/ai_action_execution_coordinator.dart',
  'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
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

  test('assistant remains a chat and keeps human review', () {
    final screen = assistantScreenSource();

    expect(screen, contains("'Чем помочь?'"));
    expect(screen, contains('TextField('));
    expect(screen, contains("mode: 'chat'"));
    expect(screen, contains("'Предварительный результат'"));
    expect(screen, contains("'Отметить как проверенное'"));
    expect(screen, contains("'Проверено человеком'"));
    expect(
      screen,
      contains("'Помощник ничего не изменяет без твоего участия.'"),
    );
    expect(screen, isNot(contains("'Быстрые действия'")));
  });

  test('all typed actions use one execution coordinator', () {
    final screen = assistantScreenSource();
    final coordinator = actionExecutionSource();

    expect(screen, contains('AiActionExecutionCoordinator.execute('));
    expect(screen, contains('completedActionIds.add(action.id)'));
    expect(coordinator, contains("'create_task_draft'"));
    expect(coordinator, contains("'prepare_document'"));
    expect(coordinator, contains("'prepare_timesheet_correction'"));
    expect(coordinator, contains("'prepare_employee_update'"));
    expect(coordinator, contains("'create_reminder'"));
    expect(coordinator, contains('AiActionConfirmationSheet.show('));
  });

  test('task proposal opens ordinary form and saves only after it returns', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );
    final taskScreen = source('lib/screens/add_task_screen.dart');
    final taskActions = source(
      'lib/screens/task_create/task_create_actions.dart',
    );
    final taskView = source('lib/screens/task_create/task_create_view.dart');

    expect(coordinator, contains('AddTaskScreen('));
    expect(coordinator, contains('initialAxes:'));
    expect(coordinator, contains('initialWork:'));
    expect(coordinator, contains('initialAssigneeIds:'));
    expect(coordinator, contains('initialRequireBeforePhoto:'));
    expect(coordinator, contains('if (draft == null)'));
    expect(coordinator, contains('TaskRepository.addTaskWithDetails('));
    expect(
      coordinator.indexOf('if (draft == null)'),
      lessThan(coordinator.indexOf('TaskRepository.addTaskWithDetails(')),
    );

    expect(taskScreen, contains('final String initialAxes;'));
    expect(taskScreen, contains('final String initialWork;'));
    expect(taskScreen, contains('final List<String> initialAssigneeIds;'));
    expect(taskScreen, contains('axesController.text = widget.initialAxes'));
    expect(taskScreen, contains('workController.text = widget.initialWork'));
    expect(taskActions, contains('required: requiresBeforePhoto'));
    expect(taskView, contains("'Сохранить задачу'"));
  });

  test('document proposal keeps editable preview and connects source form', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );
    final wrapper = source(
      'lib/features/ai/presentation/ai_document_template_screen.dart',
    );
    final preview = source(
      'lib/features/ai/presentation/ai_document_draft_screen.dart',
    );

    expect(coordinator, contains('AiDocumentTemplateScreen('));
    expect(coordinator, contains('if (completed != true)'));
    expect(wrapper, contains('AiDocumentDraftScreen('));
    expect(wrapper, contains("'Исходная форма'"));
    expect(wrapper, contains('DocumentTemplateRepository.fetchTemplates'));
    expect(wrapper, contains('DocumentTemplateRepository.downloadVersion'));
    expect(preview, contains("labelText: 'Текст документа'"));
    expect(preview, contains("label: const Text('Скачать Word')"));
    expect(preview, contains("label: const Text('Готово')"));
  });

  test('timesheet correction writes only after explicit confirmation', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );
    final confirmation = source(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    );

    expect(coordinator, contains('_loadCurrentTimesheetValue(action)'));
    expect(coordinator, contains('AiActionConfirmationSheet.show('));
    expect(coordinator, contains('if (!confirmed)'));
    expect(coordinator, contains('AttendanceRepository.saveTimesheet('));
    expect(
      coordinator.indexOf('if (!confirmed)'),
      lessThan(coordinator.indexOf('AttendanceRepository.saveTimesheet(')),
    );
    expect(confirmation, contains("'Текущее значение'"));
    expect(confirmation, contains("'Новое значение'"));
    expect(confirmation, contains("'Подтвердить и изменить'"));
  });

  test('employee and reminder actions preserve ordinary edit forms', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );
    final reminder = source(
      'lib/features/ai/presentation/ai_reminder_draft_screen.dart',
    );

    expect(
      coordinator,
      contains('EditEmployeeScreen(employee: proposedEmployee)'),
    );
    expect(coordinator, contains('AiReminderDraftScreen(action: action)'));
    expect(reminder, contains('DeveloperConstructorRepository.saveReminder('));
    expect(reminder, contains("'Сохранить напоминание'"));
  });

  test('client routes typed commands to authenticated functions', () {
    final repository = source(
      'lib/features/ai/data/ai_assistant_repository.dart',
    );
    final model = source(
      'lib/features/ai/models/ai_assistant_result.dart',
    );

    expect(repository, contains('functions.invoke('));
    expect(repository, contains("'ai-action-draft'"));
    expect(repository, contains("'ai-document-draft'"));
    expect(repository, contains("'ai-operational-draft'"));
    expect(repository, contains("'ai-assistant'"));
    expect(repository, contains("'ai-search'"));
    expect(repository, isNot(contains('OPENAI_API_KEY'));

    expect(model, contains('class AiAssistantAction'));
    expect(model, contains('confirmationRequired'));
    expect(model, contains('num number(String key)'));
    expect(model, contains('Map<String, dynamic> payload'));
  });

  test('all proposal servers validate access and remain read only', () {
    final sources = <String, String>{
      'ai-action-draft': source('supabase/functions/ai-action-draft/index.ts'),
      'ai-document-draft': source(
        'supabase/functions/ai-document-draft/index.ts',
      ),
      'ai-operational-draft': aiOperationalSource(),
    };

    for (final entry in sources.entries) {
      final edge = entry.value;
      expect(edge, contains('auth.getUser()'), reason: entry.key);
      expect(edge, contains('.from("user_profiles")'), reason: entry.key);
      expect(edge, contains('.from("company_memberships")'), reason: entry.key);
      expect(edge, contains('confirmation_required: true'), reason: entry.key);
      expect(
        edge,
        isNot(contains('SUPABASE_SERVICE_ROLE_KEY')),
        reason: entry.key,
      );
      expect(edge, isNot(contains('.insert(')), reason: entry.key);
      expect(edge, isNot(contains('.update(')), reason: entry.key);
      expect(edge, isNot(contains('.upsert(')), reason: entry.key);
      expect(edge, isNot(contains('.delete(')), reason: entry.key);
    }
  });

  test('existing structured assistant stays company scoped and read only', () {
    final edge = source('supabase/functions/ai-assistant/index.ts');

    expect(edge, contains('auth.getUser()'));
    expect(edge, contains('.eq("company_id", activeCompanyId)'));
    expect(edge, contains('role === "foreman"'));
    expect(edge, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, isNot(contains('.insert(')));
    expect(edge, isNot(contains('.update(')));
    expect(edge, isNot(contains('.upsert(')));
    expect(edge, isNot(contains('.delete(')));
  });
}
