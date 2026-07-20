import 'dart:io';

const List<String> _taskDetailsEditorPaths = <String>[
  'lib/screens/task_details/task_details_editor_screen.dart',
  'lib/screens/task_details/task_details_loading.dart',
  'lib/screens/task_details/task_details_actions.dart',
  'lib/screens/task_details/task_details_sections.dart',
  'lib/screens/task_details/task_details_view.dart',
  'lib/features/tasks/task_draft_support.dart',
  'lib/features/tasks/presentation/task_assignee_controls.dart',
  'lib/features/tasks/presentation/task_photo_grid.dart',
];

String taskDetailsEditorSource() {
  return _taskDetailsEditorPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}

String taskDetailsFeatureSource() {
  return <String>[
    File('lib/screens/task_details_screen.dart').readAsStringSync(),
    taskDetailsEditorSource(),
  ].join('\n');
}
