import 'dart:io';

const List<String> _taskCreatePaths = <String>[
  'lib/screens/add_task_screen.dart',
  'lib/screens/task_create/task_create_loading.dart',
  'lib/screens/task_create/task_create_actions.dart',
  'lib/screens/task_create/task_create_sections.dart',
  'lib/screens/task_create/task_create_view.dart',
  'lib/features/tasks/task_draft_support.dart',
  'lib/features/tasks/presentation/task_assignee_controls.dart',
  'lib/features/tasks/presentation/task_photo_grid.dart',
];

String taskCreateSource() {
  return _taskCreatePaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
