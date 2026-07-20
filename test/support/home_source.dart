import 'dart:io';

const List<String> _homePaths = <String>[
  'lib/screens/home_screen.dart',
  'lib/screens/home/home_loading.dart',
  'lib/screens/home/home_object_actions.dart',
  'lib/screens/home/home_actions.dart',
  'lib/screens/home/home_sections.dart',
  'lib/screens/home/home_view.dart',
  'lib/screens/home/home_widgets.dart',
];

String homeSource() {
  return _homePaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
