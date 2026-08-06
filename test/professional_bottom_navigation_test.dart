import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/app/app_theme.dart';
import 'package:skbs_app/widgets/professional_bottom_navigation.dart';

const items = <ProfessionalBottomNavigationItem>[
  ProfessionalBottomNavigationItem(
    label: 'Главная',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Люди',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Табель',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Задачи',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Профиль',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

const hrItems = <ProfessionalBottomNavigationItem>[
  ProfessionalBottomNavigationItem(
    label: 'Сегодня',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Кандидаты',
    icon: Icons.view_kanban_outlined,
    selectedIcon: Icons.view_kanban_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Оформление',
    icon: Icons.assignment_ind_outlined,
    selectedIcon: Icons.assignment_ind_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Вылеты',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  ProfessionalBottomNavigationItem(
    label: 'Профиль',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

Future<void> pumpNavigation(
  WidgetTester tester,
  Size size, {
  required ValueChanged<int> onSelected,
  List<ProfessionalBottomNavigationItem> navigationItems = items,
  double textScaleFactor = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: const ColoredBox(
          key: ValueKey('screen-body'),
          color: Colors.white,
          child: SizedBox.expand(),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: navigationItems,
          selectedIndex: 0,
          onSelected: onSelected,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop navigation never consumes the screen body', (
    tester,
  ) async {
    var selected = -1;
    await pumpNavigation(
      tester,
      const Size(1440, 900),
      onSelected: (value) => selected = value,
    );

    final bodyHeight = tester
        .getSize(find.byKey(const ValueKey('screen-body')))
        .height;
    final navigationHeight = tester
        .getSize(find.byKey(const ValueKey('professional-bottom-navigation')))
        .height;

    expect(bodyHeight, greaterThan(780));
    expect(navigationHeight, lessThan(110));
    for (final item in items) {
      expect(find.text(item.label), findsOneWidget);
    }

    await tester.tap(find.text('Задачи'));
    await tester.pumpAndSettle();
    expect(selected, 3);
  });

  testWidgets(
    'mobile navigation uses one glass panel and keeps all tabs visible',
    (tester) async {
      await pumpNavigation(tester, const Size(390, 844), onSelected: (_) {});

      final bodyHeight = tester
          .getSize(find.byKey(const ValueKey('screen-body')))
          .height;
      final itemsHeight = tester
          .getSize(
            find.byKey(const ValueKey('professional-bottom-navigation-items')),
          )
          .height;

      expect(bodyHeight, greaterThanOrEqualTo(750));
      expect(itemsHeight, 62);
      expect(
        find.byKey(const ValueKey('professional-bottom-navigation-panel')),
        findsOneWidget,
      );
      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile navigation never overflows on a narrow screen with large text',
    (tester) async {
      await pumpNavigation(
        tester,
        const Size(320, 640),
        navigationItems: hrItems,
        textScaleFactor: 2,
        onSelected: (_) {},
      );

      for (final item in hrItems) {
        expect(find.text(item.label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
