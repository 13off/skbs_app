import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI shell exposes history and safe diagnostics', () {
    final shell = File(
      'lib/features/ai/presentation/ai_assistant_shell_screen.dart',
    ).readAsStringSync();
    final entry = File(
      'lib/features/ai/presentation/ai_assistant_screen.dart',
    ).readAsStringSync();

    expect(entry, contains("export 'ai_assistant_shell_screen.dart'"));
    expect(shell, contains('AiDiagnosticsScreen('));
    expect(shell, contains('AiActionHistoryScreen('));
    expect(shell, contains("tooltip: 'Диагностика ИИ'"));
    expect(shell, contains("tooltip: 'Журнал действий ИИ'"));
  });

  test('diagnostics reads session and services without executing actions', () {
    final diagnostics = File(
      'lib/features/ai/presentation/ai_diagnostics_screen.dart',
    ).readAsStringSync();

    expect(diagnostics, contains('auth.currentSession'));
    expect(diagnostics, contains('AiActionAuditRepository.fetchHistory('));
    expect(diagnostics, contains('DocumentTemplateRepository.fetchTemplates('));
    expect(diagnostics, contains('AiAssistantRepository.request('));
    expect(diagnostics, contains("expectedActionType: 'create_task_draft'"));
    expect(diagnostics, contains("expectedActionType: 'prepare_document'"));
    expect(diagnostics, contains("expectedActionType: 'open_period_timesheet'"));
    expect(diagnostics, contains('не подтверждает, не сохраняет и не выполняет'));

    expect(diagnostics, isNot(contains('AiActionExecutionCoordinator')));
    expect(diagnostics, isNot(contains('createProposed(')));
    expect(diagnostics, isNot(contains('markConfirmed(')));
    expect(diagnostics, isNot(contains('.insert(')));
    expect(diagnostics, isNot(contains('.update(')));
    expect(diagnostics, isNot(contains('.delete(')));
  });
}
