import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_ui_tokens.dart';
import 'package:skbs_app/widgets/professional_bottom_navigation.dart';

void main() {
  testWidgets('native bottom glass reaches the bottom safe-area edge', (
    tester,
  ) async {
    const bottomInset = 34.0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: ProfessionalBottomNavigation(
              items: const [
                ProfessionalBottomNavigationItem(
                  label: 'Главная',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                ),
                ProfessionalBottomNavigationItem(
                  label: 'Задачи',
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment_rounded,
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final navigation = find.byKey(
      const ValueKey('professional-bottom-navigation'),
    );
    final panel = find.byKey(
      const ValueKey('professional-bottom-navigation-panel'),
    );

    expect(navigation, findsOneWidget);
    expect(panel, findsOneWidget);

    final navigationBottom = tester.getBottomRight(navigation).dy;
    final panelBottom = tester.getBottomRight(panel).dy;
    expect(panelBottom, closeTo(navigationBottom, 0.01));

    final navigationHeight = tester.getSize(navigation).height;
    expect(
      navigationHeight,
      closeTo(
        AppUi.mobileNavigationPanelHeight +
            AppUi.mobileNavigationTopSpacing +
            bottomInset,
        0.01,
      ),
    );
  });
}
