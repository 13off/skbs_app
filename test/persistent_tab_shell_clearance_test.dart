import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_theme.dart';
import 'package:skbs_app/features/shell/presentation/persistent_tab_shell.dart';
import 'package:skbs_app/widgets/professional_bottom_navigation.dart';

const navigationItems = <ProfessionalBottomNavigationItem>[
  ProfessionalBottomNavigationItem(
    label: 'Главная',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Профиль',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

void main() {
  testWidgets('tab body physically ends above the floating panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PersistentTabController(
      pageCount: navigationItems.length,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PersistentTabShell(
          controller: controller,
          items: navigationItems,
          tabBuilder: (context, index) => const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(key: ValueKey('tab-content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contentBottom = tester
        .getBottomRight(find.byKey(const ValueKey('tab-content')))
        .dy;
    final navigationTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('professional-bottom-navigation')),
        )
        .dy;

    expect(contentBottom, lessThanOrEqualTo(navigationTop + 0.1));
    expect(tester.takeException(), isNull);
  });
}
