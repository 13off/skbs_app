import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('PWA and desktop keep the existing bottom navigation', () {
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );
    final main = source('lib/main.dart');

    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(navigation, contains('ProfessionalBottomNavigation extends StatefulWidget'));
    expect(navigation, contains('NavigationSession.writeTabIndex'));
    expect(navigation, isNot(contains('NavigationRail(')));
    expect(navigation, isNot(contains('ProfessionalDesktopShell')));
    expect(main, isNot(contains('ProfessionalDesktopShell(')));
    expect(main, isNot(contains("widgets/professional_bottom_navigation.dart")));
  });
}
