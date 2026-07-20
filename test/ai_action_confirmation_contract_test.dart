import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('coordinator records proposal before showing confirmation', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );

    final proposed = coordinator.indexOf(
      'AiActionAuditRepository.createProposed(',
    );
    final confirmation = coordinator.indexOf(
      'AiActionConfirmationSheet.show(',
    );
    final confirmed = coordinator.indexOf(
      'AiActionAuditRepository.markConfirmed(',
    );
    final execution = coordinator.indexOf(
      "'create_task_draft' => await _createTask",
    );

    expect(proposed, greaterThanOrEqualTo(0));
    expect(confirmation, greaterThan(proposed));
    expect(confirmed, greaterThan(confirmation));
    expect(execution, greaterThan(confirmed));
    expect(coordinator, contains('AiActionAuditRepository.markCancelled('));
    expect(coordinator, contains('AiActionAuditRepository.markCompleted('));
    expect(coordinator, contains('AiActionAuditRepository.markFailed('));
  });

  test('confirmation sheet shows exact proposal and distinguishes direct write', () {
    final sheet = source(
      'lib/features/ai/presentation/ai_action_confirmation_sheet.dart',
    );

    expect(sheet, contains("'Работы'"));
    expect(sheet, contains("'Оси'"));
    expect(sheet, contains("'Исполнители'"));
    expect(sheet, contains("'Документ'"));
    expect(sheet, contains("'Текущее значение'"));
    expect(sheet, contains("'Новое значение'"));
    expect(sheet, contains("'Текущая ставка'"));
    expect(sheet, contains("'Новая ставка'"));
    expect(sheet, contains("'Получатели'"));
    expect(sheet, contains("action.type == 'prepare_timesheet_correction'"));
    expect(sheet, contains("'Подтвердить и изменить'"));
    expect(sheet, contains("child: const Text('Отмена')"));
    expect(
      sheet,
      contains(
        'В журнале сохранятся предложение ИИ, пользователь и результат действия.',
      ),
    );
  });

  test('audit repository cannot directly update immutable proposal', () {
    final repository = source(
      'lib/features/ai/data/ai_action_audit_repository.dart',
    );

    expect(repository, contains(".from('ai_action_audit')"));
    expect(repository, contains(".insert(<String, dynamic>{"));
    expect(repository, contains("'transition_ai_action_audit'"));
    expect(repository, isNot(contains(".from('ai_action_audit')\n        .update")));
    expect(repository, isNot(contains("'status': 'proposed'")));
  });

  test('each action returns a typed target when completed', () {
    final coordinator = source(
      'lib/features/ai/actions/ai_action_execution_coordinator.dart',
    );

    expect(coordinator, contains("targetEntityType: 'task'"));
    expect(coordinator, contains("targetEntityType: 'document_download'"));
    expect(coordinator, contains("targetEntityType: 'attendance'"));
    expect(coordinator, contains("targetEntityType: 'employee'"));
    expect(coordinator, contains("targetEntityType: 'developer_reminder'"));
  });
}
