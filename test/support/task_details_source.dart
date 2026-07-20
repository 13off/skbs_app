import 'dart:io';

const List<String> _taskDetailsEditorPaths = <String>[
  'lib/screens/task_details_legacy_screen.dart',
  'lib/screens/task_details/task_details_loading.dart',
  'lib/screens/task_details/task_details_actions.dart',
  'lib/screens/task_details/task_details_sections.dart',
  'lib/screens/task_details/task_details_view.dart',
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
