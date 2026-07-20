import 'dart:io';

const List<String> _taskRepositoryPaths = <String>[
  'lib/data/task_repository.dart',
  'lib/data/task_assignee_repository.dart',
  'lib/data/task_milestone_link_repository.dart',
];

String taskRepositoryFeatureSource() {
  return _taskRepositoryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
