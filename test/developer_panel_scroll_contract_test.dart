import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('developer panel routes desktop pointer scrolling to its columns', () {
    final wrapper = File(
      'lib/features/developer/presentation/developer_panel_screen.dart',
    ).readAsStringSync();
    final legacy = File(
      'lib/features/developer/presentation/developer_panel_screen_legacy.dart',
    );

    expect(legacy.existsSync(), isTrue);
    expect(wrapper, contains("import 'package:flutter/gestures.dart';"));
    expect(wrapper, contains("import 'developer_panel_screen_legacy.dart' as legacy;"));
    expect(wrapper, contains('constraints.maxWidth >= 1000'));
    expect(wrapper, contains('PointerScrollEvent'));
    expect(wrapper, contains('ScrollableState'));
    expect(wrapper, contains('position.jumpTo(target)'));
    expect(wrapper, contains('legacy.DeveloperPanelScreen(profile: widget.profile)'));
  });
}
