import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global command keeps production intent guards with operational queries', () {
    final index = File(
      'supabase/functions/ai-global-command/index.ts',
    ).readAsStringSync();
    final guards = File(
      'supabase/functions/ai-global-command/workflow_intent_guards.ts',
    ).readAsStringSync();

    expect(index, contains('workflow_intent_guards.ts'));
    expect(index, contains('employeeWorkflowIntentGuard(prompt)'));
    expect(index, contains('chatMessageIntentGuard(prompt)'));
    expect(index, contains('flightWorkflowIntentGuard(prompt)'));
    expect(index, contains('archiveRestoreIntentGuard(prompt)'));
    expect(index, contains('operationalQueryIntent(prompt)'));

    expect(guards, contains('naturalPersonStatus'));
    expect(guards, contains('прилетел|вылетел|улетел'));
    expect(guards, contains('сотрудник|работник|архив'));
  });
}
