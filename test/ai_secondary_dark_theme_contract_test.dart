import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('secondary AI screens do not keep light-only colors', () {
    final history = source(
      'lib/features/ai/presentation/ai_action_history_screen.dart',
    );
    final diagnostics = source(
      'lib/features/ai/presentation/ai_diagnostics_screen.dart',
    );
    final documentDraft = source(
      'lib/features/ai/presentation/ai_document_draft_screen.dart',
    );
    final reminder = source(
      'lib/features/ai/presentation/ai_reminder_draft_screen.dart',
    );

    expect(history, contains('Theme.of(context).colorScheme'));
    expect(history, contains('scheme.surface'));
    expect(history, contains('scheme.onSurfaceVariant'));
    expect(history, contains('scheme.errorContainer'));
    expect(history, isNot(contains('AppColors.')));
    expect(history, isNot(contains('color: Colors.white')));

    expect(diagnostics, contains('scheme.primary'));
    expect(diagnostics, contains('scheme.tertiary'));
    expect(diagnostics, contains('scheme.error'));
    expect(diagnostics, isNot(contains('Color(0xFF236A45)')));
    expect(diagnostics, isNot(contains('Color(0xFF874540)')));

    expect(documentDraft, contains('scheme.tertiaryContainer'));
    expect(documentDraft, contains('scheme.onTertiaryContainer'));
    expect(documentDraft, contains('scheme.error'));
    expect(documentDraft, isNot(contains('Color(0xFFFFF4E5)')));
    expect(documentDraft, isNot(contains('Colors.red')));

    expect(reminder, contains('Theme.of(context).colorScheme'));
    expect(reminder, contains('scheme.error'));
    expect(reminder, isNot(contains('Colors.red')));
  });
}
