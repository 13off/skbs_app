import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('отчёт по табелю использует цвета активной темы', () {
    final sections = File(
      'lib/screens/period_timesheet/period_timesheet_sections.dart',
    ).readAsStringSync();

    expect(sections, contains('scheme.surfaceContainerHighest'));
    expect(sections, contains('scheme.outlineVariant'));
    expect(sections, contains('scheme.onSurface'));
    expect(sections, contains('scheme.onSurfaceVariant'));
    expect(sections, contains('Theme.of(context).colorScheme.error'));
    expect(sections, isNot(contains('Colors.grey.shade100')));
    expect(sections, isNot(contains('color: shift > 0 ? Colors.black')));
  });

  test('текстовые колонки табеля не налезают друг на друга', () {
    final sections = File(
      'lib/screens/period_timesheet/period_timesheet_sections.dart',
    ).readAsStringSync();

    expect(sections, contains('width: 170'));
    expect(sections, contains('width: 150'));
    expect(sections, contains('maxLines: 2'));
    expect(sections, contains('overflow: TextOverflow.ellipsis'));
    expect(sections, contains('columnSpacing: 24'));
  });
}
