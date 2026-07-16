import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('PWA uses a desktop rail while mobile keeps the existing bottom bar', () {
    final navigation = source(
      'lib/widgets/professional_bottom_navigation.dart',
    );
    final main = source('lib/main.dart');

    expect(navigation, contains('desktopBreakpoint = 1100'));
    expect(navigation, contains('NavigationRail('));
    expect(navigation, contains("kIsWeb && screenWidth >= ProfessionalDesktopShell.desktopBreakpoint"));
    expect(navigation, contains("ValueKey('professional-bottom-navigation')"));
    expect(navigation, contains('ProfessionalBottomNavigation extends StatefulWidget'));
    expect(navigation, contains('NavigationSession.writeTabIndex'));
    expect(main, contains('ProfessionalDesktopShell('));
  });
}
