from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found in {path}: {old[:120]!r}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/app/app_ui_tokens.dart",
    "  static const double pageBottomPadding = 132;\n",
    "  // The tab shell now reserves the complete floating navigation area.\n"
    "  // Pages only need a small scroll tail above that reserved area.\n"
    "  static const double pageBottomPadding = 32;\n",
)

replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    "import '../../../app/theme_controller.dart';\n",
    "import '../../../app/app_ui_tokens.dart';\n"
    "import '../../../app/theme_controller.dart';\n",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    "    final activeIndex = widget.controller.currentIndex;\n",
    "    final activeIndex = widget.controller.currentIndex;\n"
    "    final mediaQuery = MediaQuery.of(context);\n"
    "    final navigationClearance = AppUi.navigationTotalHeight(context);\n"
    "    final contentMediaQuery = mediaQuery.copyWith(\n"
    "      padding: mediaQuery.padding.copyWith(bottom: 0),\n"
    "      viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),\n"
    "    );\n",
)
replace_once(
    "lib/features/shell/presentation/persistent_tab_shell.dart",
    """            IndexedStack(
              index: activeIndex,
              children: List<Widget>.generate(widget.controller.pageCount, (
                index,
              ) {
                final child = _tabNavigators[index];
                if (child == null) return const SizedBox.shrink();
                return TickerMode(enabled: index == activeIndex, child: child);
              }),
            ),
""",
    """            Padding(
              key: const ValueKey('persistent-tab-content-clearance'),
              padding: EdgeInsets.only(bottom: navigationClearance),
              child: MediaQuery(
                data: contentMediaQuery,
                child: IndexedStack(
                  index: activeIndex,
                  children: List<Widget>.generate(
                    widget.controller.pageCount,
                    (index) {
                      final child = _tabNavigators[index];
                      if (child == null) return const SizedBox.shrink();
                      return TickerMode(
                        enabled: index == activeIndex,
                        child: child,
                      );
                    },
                  ),
                ),
              ),
            ),
""",
)

replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    "import '../../../data/app_cache_coordinator.dart';\n",
    "import '../../../app/app_ui_tokens.dart';\n"
    "import '../../../data/app_cache_coordinator.dart';\n",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    "    final tabItems = buildTabItems();\n",
    "    final tabItems = buildTabItems();\n"
    "    final mediaQuery = MediaQuery.of(context);\n"
    "    final navigationClearance = AppUi.navigationTotalHeight(context);\n"
    "    final contentMediaQuery = mediaQuery.copyWith(\n"
    "      padding: mediaQuery.padding.copyWith(bottom: 0),\n"
    "      viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),\n"
    "    );\n",
)
replace_once(
    "lib/features/shell/presentation/premium_main_screen.dart",
    """            Listener(
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
""",
    """            Padding(
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
                        ? _ConditionalPagePhysics(
                            canSwipe: canSwipeBetweenTabs,
                          )
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: handlePageChanged,
                    itemBuilder: (context, index) {
                      return buildTabNavigator(index);
                    },
                  ),
                ),
              ),
            ),
""",
)

Path("test/global_bottom_navigation_clearance_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all tab shells reserve the floating navigation area', () {
    final persistent = source(
      'lib/features/shell/presentation/persistent_tab_shell.dart',
    );
    final legacy = source(
      'lib/features/shell/presentation/premium_main_screen.dart',
    );
    final tokens = source('lib/app/app_ui_tokens.dart');

    for (final shell in <String>[persistent, legacy]) {
      expect(shell, contains('AppUi.navigationTotalHeight(context)'));
      expect(
        shell,
        contains('padding: EdgeInsets.only(bottom: navigationClearance)'),
      );
      expect(shell, contains('padding: mediaQuery.padding.copyWith(bottom: 0)'));
      expect(
        shell,
        contains('viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0)'),
      );
    }

    expect(
      persistent,
      contains("ValueKey('persistent-tab-content-clearance')"),
    );
    expect(legacy, contains("ValueKey('legacy-tab-content-clearance')"));
    expect(tokens, contains('static const double pageBottomPadding = 32;'));
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
  testWidgets('tab content ends above the floating navigation', (tester) async {
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

    expect(
      find.byKey(const ValueKey('persistent-tab-content-clearance')),
      findsOneWidget,
    );
    expect(contentBottom, lessThanOrEqualTo(navigationTop + 0.1));
    expect(tester.takeException(), isNull);
  });
}
""",
    encoding="utf-8",
)
