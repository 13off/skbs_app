import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stage automation can create tasks and send Telegram messages once', () {
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_automation_settings_panel.dart',
    ).readAsStringSync();
    final models = File(
      'lib/features/recruitment/models/recruitment_crm_workspace_models.dart',
    ).readAsStringSync();
    final function = File(
      'supabase/functions/run-recruitment-crm-automations/index.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724073000_recruitment_crm_workspace.sql',
    ).readAsStringSync();

    expect(screen, contains('Автоматические действия'));
    expect(screen, contains('recruitmentAutomationActionTypes'));
    expect(models, contains("'create_task_and_message'"));
    expect(models, contains('Создать дело и отправить сообщение'));
    expect(function, contains('recruitment_crm_automation_runs'));
    expect(function, contains('sendTelegramMessage'));
    expect(function, contains('recruitment_crm_tasks'));
    expect(
      migration,
      contains('recruitment_crm_automation_runs_idempotency_unique'),
    );
  });
}
