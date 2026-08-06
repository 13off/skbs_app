from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found in {path}: {old[:160]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    "import '../../../app/app_ui_tokens.dart';\n",
    "",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """    final activeIndex = widget.controller.currentIndex;
    final mediaQuery = MediaQuery.of(context);
    final navigationClearance = AppUi.navigationTotalHeight(context);
    final contentMediaQuery = mediaQuery.copyWith(
      padding: mediaQuery.padding.copyWith(bottom: 0),
      viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
    );
""",
    """    final activeIndex = widget.controller.currentIndex;
""",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              key: const ValueKey('persistent-tab-content-clearance'),
              padding: EdgeInsets.only(bottom: navigationClearance),
              child: MediaQuery(
                data: contentMediaQuery,
                child: IndexedStack(
                  index: activeIndex,
                  children: List<Widget>.generate(widget.controller.pageCount, (
                    index,
                  ) {
                    final child = _tabNavigators[index];
                    if (child == null) return const SizedBox.shrink();
                    return TickerMode(
                      enabled: index == activeIndex,
                      child: child,
                    );
                  }),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ProfessionalBottomNavigation(
                items: widget.items,
                selectedIndex: activeIndex,
                storageKey: widget.navigationStorageKey,
                onSelected: widget.controller.select,
              ),
            ),
          ],
        ),
      ),
""",
    """      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: activeIndex,
          children: List<Widget>.generate(widget.controller.pageCount, (index) {
            final child = _tabNavigators[index];
            if (child == null) return const SizedBox.shrink();
            return TickerMode(enabled: index == activeIndex, child: child);
          }),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
          items: widget.items,
          selectedIndex: activeIndex,
          storageKey: widget.navigationStorageKey,
          onSelected: widget.controller.select,
        ),
      ),
""",
)

replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    "import '../../../app/app_ui_tokens.dart';\n",
    "",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """    final tabItems = buildTabItems();
    final mediaQuery = MediaQuery.of(context);
    final navigationClearance = AppUi.navigationTotalHeight(context);
    final contentMediaQuery = mediaQuery.copyWith(
      padding: mediaQuery.padding.copyWith(bottom: 0),
      viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
    );
""",
    """    final tabItems = buildTabItems();
""",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              key: const ValueKey('legacy-tab-content-clearance'),
              padding: EdgeInsets.only(bottom: navigationClearance),
              child: MediaQuery(
                data: contentMediaQuery,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: handlePointerDown,
                  onPointerUp: handlePointerUp,
                  onPointerCancel: (_) => topTapStart = null,
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: pageCount,
                    allowImplicitScrolling: false,
                    physics: supportsAppSwipes
                        ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: handlePageChanged,
                    itemBuilder: (context, index) {
                      return buildTabNavigator(index);
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PremiumBottomBar(
                items: tabItems,
                selectedIndex: activeIndex,
                storageKey: widget.profile.isAdmin
                    ? 'admin'
                    : widget.profile.isForeman
                    ? 'foreman'
                    : 'worker',
                onSelected: selectTab,
              ),
            ),
          ],
        ),
      ),
""",
    """      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: handlePointerDown,
          onPointerUp: handlePointerUp,
          onPointerCancel: (_) => topTapStart = null,
          child: PageView.builder(
            controller: pageController,
            itemCount: pageCount,
            allowImplicitScrolling: false,
            physics: supportsAppSwipes
                ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)
                : const NeverScrollableScrollPhysics(),
            onPageChanged: handlePageChanged,
            itemBuilder: (context, index) {
              return buildTabNavigator(index);
            },
          ),
        ),
        bottomNavigationBar: _PremiumBottomBar(
          items: tabItems,
          selectedIndex: activeIndex,
          storageKey: widget.profile.isAdmin
              ? 'admin'
              : widget.profile.isForeman
              ? 'foreman'
              : 'worker',
          onSelected: selectTab,
        ),
      ),
""",
)

Path("test/global_bottom_navigation_clearance_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all tab shells place navigation outside the screen body', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );

    expect(
      persistent,
      contains('bottomNavigationBar: ProfessionalBottomNavigation('),
    );
    expect(legacy, contains('bottomNavigationBar: _PremiumBottomBar('));

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, isNot(contains('extendBody: true')));
      expect(shell, isNot(contains('navigationClearance')));
      expect(shell, isNot(contains('content-clearance')));
    }
  });
}
""",
    encoding="utf-8",
)

Path("test/persistent_tab_shell_clearance_test.dart").write_text(
    """import 'package:flutter/material.dart';
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
  testWidgets('tab body physically ends above the floating panel', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PersistentTabController(pageCount: navigationItems.length);
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
""",
    encoding="utf-8",
)
