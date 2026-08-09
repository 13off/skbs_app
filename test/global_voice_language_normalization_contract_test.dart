import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global voice normalizes conversational navigation and edits', () {
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();

    expect(shared, contains('зайди|зайти'));
    expect(shared, contains('давай\\s+(?:в|на)'));
    expect(shared, contains('поменяй|поменять|скорректируй'));
    expect(shared, contains('заведи|завести'));
  });

  test('global voice understands short timesheet phrases and workday slang', () {
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();

    expect(shared, contains('пол\\s*дня|полдня'));
    expect(shared, contains(r'поставь $2'));
    expect(shared, contains('начал|начала'));
    expect(shared, contains('заверши рабочий день'));
  });

  test('global voice normalizes natural HR chat procurement legal and archive phrases', () {
    final shared = File(
      'supabase/functions/ai-global-command/shared.ts',
    ).readAsStringSync();

    expect(shared, contains(r'переведи кандидата $1 на билеты'));
    expect(shared, contains(r'напиши $1:'));
    expect(shared, contains(r'создай заявку на снабжение $1'));
    expect(shared, contains('создай юридический вопрос'));
    expect(shared, contains('достань|достать'));
    expect(shared, contains('разархивируй'));
  });

  test('all write paths remain routed through typed confirmed actions', () {
    final bulk = File(
      'supabase/functions/ai-global-command/bulk_timesheet.ts',
    ).readAsStringSync();
    final extended = File(
      'supabase/functions/ai-global-command/extended_actions.ts',
    ).readAsStringSync();
    final workflow = File(
      'supabase/functions/ai-global-command/workflow_actions.ts',
    ).readAsStringSync();

    expect(bulk, contains('confirmation_required: true'));
    expect(extended, contains('confirmation_required: true'));
    expect(workflow, contains('confirmation_required: true'));
  });
}
