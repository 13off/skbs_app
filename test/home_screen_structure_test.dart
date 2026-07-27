import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';

void main() {
  test('главный экран разделён по ответственности', () {
    final shell = File('lib/screens/home_screen.dart').readAsStringSync();
    final loading = File('lib/screens/home/home_loading.dart').readAsStringSync();
    final objects = File(
      'lib/screens/home/home_object_actions.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/screens/home/home_sections.dart',
    ).readAsStringSync();
    final view = File('lib/screens/home/home_view.dart').readAsStringSync();
    final widgets = File('lib/screens/home/home_widgets.dart').readAsStringSync();

    expect(shell, contains("part 'home/home_loading.dart';"));
    expect(shell, contains("part 'home/home_object_actions.dart';"));
    expect(shell, contains("part 'home/home_sections.dart';"));
    expect(shell, contains("part 'home/home_view.dart';"));
    expect(shell, contains("part 'home/home_widgets.dart';"));
    expect(shell.split('\n').length, lessThan(120));

    expect(loading, contains('Future<_HomeDashboardData> loadDashboardData'));
    expect(objects, contains('Future<void> handleArchiveObject'));
    expect(sections, contains('Widget buildDashboard'));
    expect(view, contains('Widget buildHomeView'));
    expect(widgets, contains('class _FinanceSummaryCard'));
  });

  test('главная сохраняет объекты архив финансы и помощника', () {
    final source = homeSource();
    for (final fragment in const <String>[
      "'Главная'",
      "'Все объекты'",
      "'Архив объектов'",
      "'Архивировать объект'",
      "'Выполненные задачи'",
      "'Выплаты \${financePeriod.title()}'",
      'MilestoneHomeSection(',
      "tooltip: 'ИИ-помощник'",
    ]) {
      expect(source, contains(fragment));
    }
  });

  test('очистка кешей главной проходит через координатор', () {
    final loading = File('lib/screens/home/home_loading.dart').readAsStringSync();

    expect(loading, contains('AppCacheCoordinator.invalidate('));
    expect(loading, contains('AppDataDomain.objects'));
    expect(loading, isNot(contains('ObjectRepository.clearCache()')));
    expect(loading, isNot(contains('EmployeeRepository.clearCache()')));
    expect(loading, isNot(contains('AttendanceRepository.clearCache()')));
    expect(loading, isNot(contains('TaskRepository.clearTaskListCache()')));
    expect(loading, isNot(contains('FinanceSummaryRepository.clearCache()')));
  });
}
