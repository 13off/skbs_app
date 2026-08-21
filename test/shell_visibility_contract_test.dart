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

    expect(source, contains("import '../../../navigation/app_page_route.dart';"));
    expect(source, contains('AppPageRoute<void>('));
    expect(
      source,
      contains('return buildRootPage(index, selectedObjectName);'),
    );
    expect(source, contains('return ProfessionalBottomNavigation('));

    expect(
      navigation,
      contains("key: const ValueKey('professional-bottom-navigation')"),
    );
    expect(
      navigation,
      contains('height: AppUi.navigationTotalHeight(context)'),
    );
    expect(navigation, contains('MaterialType.transparency'));
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-panel')"),
    );
    expect(
      navigation,
      contains("ValueKey('professional-bottom-navigation-items')"),
    );
    expect(navigation, contains('LiquidGlassSurface('));
    expect(navigation, isNot(contains('child: Align(')));
  });
}
