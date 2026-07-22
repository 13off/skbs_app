import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('new task uses adaptive object photo and error surfaces', () {
    final root = source('lib/screens/add_task_screen.dart');
    final sections = source(
      'lib/screens/task_create/task_create_sections.dart',
    );
    final view = source('lib/screens/task_create/task_create_view.dart');
    final actions = source('lib/screens/task_create/task_create_actions.dart');

    expect(root, contains("import '../app/app_adaptive_palette.dart';"));
    expect(sections, contains('AppAdaptivePalette.surfaceSoft'));
    expect(sections, contains('AppAdaptivePalette.border'));
    expect(sections, contains('AppAdaptivePalette.textMuted'));
    expect(view, contains('AppAdaptivePalette.danger'));

    expect(actions, contains('TaskRepository.addTaskWithDetails('));
    expect(actions, contains('requiresBeforePhoto'));
    expect(view, contains("label: const Text('Сохранить задачу')"));
    expect(sections, contains("label: const Text('Добавить фото «До»')"));

    expect(sections, isNot(contains('color: Colors.grey.shade100')));
    expect(sections, isNot(contains('border: Border.all(color: Colors.grey.shade200)')));
    expect(view, isNot(contains('TextStyle(color: Colors.red)')));

    // Белая иконка удаления остаётся только поверх тёмной плашки фотографии.
    expect(sections, contains('color: Colors.black54'));
    expect(sections, contains('color: Colors.white'));
  });

  test('daily task progress dialog follows theme and keeps save semantics', () {
    final screen = source('lib/screens/task_details_screen.dart');

    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.textMuted'));
    expect(screen, contains('TaskProgressRepository.fetchContext('));
    expect(screen, contains('TaskProgressRepository.saveCompletedTask('));
    expect(screen, contains('TaskProgressRepository.saveWithoutCompletion('));
    expect(screen, contains("title: const Text('Что выполнили сегодня?')"));
    expect(screen, contains("label: const Text('Сохранить выполнение')"));
    expect(screen, isNot(contains('Color(0xFFF3F4F5)')));
    expect(screen, isNot(contains('Color(0xFF6B7075)')));
  });

  test('task photo overlays retain intentional high contrast', () {
    final sections = source(
      'lib/screens/task_details/task_details_sections.dart',
    );

    expect(sections, contains('color: Colors.black54'));
    expect(sections, contains('color: Colors.white'));
    expect(sections, contains('AppAdaptivePalette.surface'));
    expect(sections, contains('AppAdaptivePalette.border'));
  });
}
