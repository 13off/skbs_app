import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI chat uses adaptive contrast and sends with plain Enter', () {
    final screen = File(
      'lib/features/ai/presentation/ai_assistant_confirmed_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("import 'package:flutter/services.dart';"));
    expect(screen, contains('Theme.of(context).colorScheme'));
    expect(screen, contains('colorScheme.onSurface'));
    expect(screen, contains('colorScheme.onSurfaceVariant'));
    expect(screen, contains('colorScheme.surfaceContainerHighest'));
    expect(screen, isNot(contains('AppColors.textPrimary')));
    expect(screen, isNot(contains('AppColors.textMuted')));

    expect(screen, contains('CallbackShortcuts('));
    expect(
      screen,
      contains('SingleActivator(LogicalKeyboardKey.enter)'),
    );
    expect(
      screen,
      contains('SingleActivator(LogicalKeyboardKey.numpadEnter)'),
    );
    expect(
      screen,
      contains('Enter — отправить · Shift+Enter — новая строка'),
    );
    expect(screen, contains('textInputAction: TextInputAction.newline'));
  });
}
