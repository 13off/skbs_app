import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main shell keeps the stable nested route that renders tab screens', () {
    final source = File(
      'lib/features/shell/presentation/premium_main_screen.dart',
    ).readAsStringSync();
    final navigation = File(
      'lib/widgets/professional_bottom_navigation.dart',
    ).readAsStringSync();

    expect(source, contains("show CupertinoPageRoute"));
    expect(source, contains('return CupertinoPageRoute<void>('));
    expect(source, contains('return buildRootPage(index, selectedObjectName);'));
    expect(source, contains('return ProfessionalBottomNavigation('));

    expect(navigation, contains("key: const ValueKey('professional-bottom-navigation')"));
    expect(navigation, contains('height: totalHeight'));
    expect(navigation, contains('final totalHeight ='));
    expect(navigation, isNot(contains('child: Align(')));
  });
}
